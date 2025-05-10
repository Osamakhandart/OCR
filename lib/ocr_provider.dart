// ocr_provider.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import "package:vibration/vibration.dart";

class OCRProvider extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();

  CameraController? _cameraController;
  CameraController? get cameraController => _cameraController;
  late Future<void> initializeControllerFuture;

  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  bool _isContinuousMode = false;
  bool get isContinuousMode => _isContinuousMode;

  String _statusMessage = 'Press Start';
  String get statusMessage => _statusMessage;

  Set<String> _matchingQuestions = {};
  Set<String> get matchingQuestions => _matchingQuestions;

  Timer? _continuousTimer;
  DateTime? _lastProcessTime;

  Future<void> initializeCamera() async {
    final cameras = await availableCameras();
    _cameraController = CameraController(
      cameras.first,
      ResolutionPreset.ultraHigh,
    );
    initializeControllerFuture = _cameraController!.initialize();
    notifyListeners();
  }

  void toggleContinuousMode() {
    _isContinuousMode = !_isContinuousMode;
    notifyListeners();

    if (_isContinuousMode) {
      _startContinuousDetection();
    } else {
      _stopContinuousDetection();
    }
  }

  void _startContinuousDetection() {
    _continuousTimer?.cancel();
    _continuousTimer = Timer.periodic(Duration(seconds: 2), (_) {
      if (!_isProcessing) {
        captureAndProcessImage();
      }
    });
  }

  void _stopContinuousDetection() {
    _continuousTimer?.cancel();
    _continuousTimer = null;
  }

  Future<void> captureAndProcessImage() async {
    if (_isProcessing) return;
    if (_lastProcessTime != null &&
        DateTime.now().difference(_lastProcessTime!) < Duration(seconds: 1)) {
      return;
    }

    _lastProcessTime = DateTime.now();
    _isProcessing = true;
    _statusMessage = 'Retry';
    _matchingQuestions.clear();
    notifyListeners();

    try {
      await initializeControllerFuture;
      if (!_cameraController!.value.isInitialized) return;

      final image = await _cameraController!.takePicture();
      final recognizedText = await _processImage(image.path);

      if (recognizedText.isEmpty) {
        _statusMessage = "Retry";
        await vibrate(vibrateCount: 1);
      } else {
        await _checkTextInDatabaseSimpleQuick(recognizedText);
      }
    } catch (e) {
      // _statusMessage = 'Error: ${e.toString()}';
    } finally {
      _isProcessing = false;
      notifyListeners();
    }
  }

  Future<String> _processImage(String imagePath) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      textRecognizer.close();
    }
  }

  Future<void> _checkTextInDatabaseSimpleQuick(String recognizedText) async {
    final lines = recognizedText
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && line.split(' ').length >= 5)
        .toList();

    if (lines.isEmpty) {
      _statusMessage = 'Retry';
      await Future.delayed(Duration(milliseconds: 200));
      await vibrate(vibrateCount: 1);
      notifyListeners();
      return;
    }

    final db = await openDatabaseConnection();
    _matchingQuestions.clear();

    double highestSimilarity = 0.0;
    String bestMatchQuestion = '';
    String bestMatchAnswer = '';
    bool foundTrueAnswer = false;

    for (var line in lines) {
      final normalizedLine = line.toLowerCase();
      final words = normalizedLine.split(' ');
      final String searchTerm = words.length >= 5
          ? words.sublist(words.length - 5, words.length - 2).join(' ')
          : normalizedLine;

      final candidateResults = await db.query(
        'Question',
        where:
            'Question LIKE ? OR Question LIKE ? OR Question LIKE ? COLLATE NOCASE',
        whereArgs: [
          '%$searchTerm',
          '%${searchTerm.substring(1)}%',
          '%${searchTerm.substring(0, searchTerm.length - 1)}%'
        ],
        limit: 100,
      );

      for (var row in candidateResults) {
        final dbQuestion = row['Question'].toString().toLowerCase().trim();
        final dbAnswer = row['Answer'].toString().toLowerCase().trim();
        final sim = normalizedLine.similarityTo(dbQuestion);

        if (sim >= 0.5 && sim > highestSimilarity) {
          highestSimilarity = sim;
          bestMatchQuestion = dbQuestion;
          bestMatchAnswer = dbAnswer;
          foundTrueAnswer = !(dbAnswer == 'f' || dbAnswer == 'false');
        }
      }
    }

    if (highestSimilarity > 0) {
      _matchingQuestions.add('$bestMatchQuestion (Answer: $bestMatchAnswer)');
    }

    _statusMessage = highestSimilarity > 0
        ? (foundTrueAnswer ? 'True' : 'False')
        : 'False';

    await vibrate(vibrateCount: foundTrueAnswer ? 2 : 1);
    notifyListeners();
  }

  static Future<void> copyDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "Questions.db");
    if (!await File(path).exists()) {
      final data = await rootBundle.load('assets/Questions.db');
      await File(path).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
  }

  static Future<Database> openDatabaseConnection() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, "Questions.db");
    return await openDatabase(path, readOnly: true);
  }

  Future<void> vibrate({int vibrateCount = 1}) async {
    try {
      final canVibrate = await Vibration.hasVibrator() ?? false;
      if (!canVibrate) return;

      if (Platform.isIOS) {
        if (vibrateCount == 1) {
          await HapticFeedback.mediumImpact();
        } else {
          await HapticFeedback.heavyImpact();
          await Future.delayed(Duration(milliseconds: 200));
          await HapticFeedback.heavyImpact();
        }
      } else {
        if (vibrateCount == 1) {
          playWrongBeep();
          await Vibration.vibrate(duration: 500);

        } else {
          playRightBeep();
          await Vibration.vibrate(pattern: [0, 500, 100, 500]);
        }
      }
    } catch (e) {
      print("Vibration error: $e");
    }
  }


Future<void> playRightBeep() async {
  await _player.play(AssetSource('true.mp3'));
}

Future<void> playWrongBeep() async {
  await _player.play(AssetSource('false.mp3'));
}


}

extension StringSimilarity on String {
  double similarityTo(String other) {
    final a = this.toLowerCase();
    final b = other.toLowerCase();
    final lev = levenshtein(a, b);
    final maxLen = max(a.length, b.length);
    return maxLen == 0 ? 1.0 : 1.0 - (lev / maxLen);
  }
}

int levenshtein(String a, String b) {
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  if (a.length > b.length) {
    final temp = a;
    a = b;
    b = temp;
  }

  final currentRow = List<int>.generate(a.length + 1, (i) => i);

  for (int i = 1; i <= b.length; i++) {
    int previous = currentRow[0];
    currentRow[0] = i;

    for (int j = 1; j <= a.length; j++) {
      final cost = (b[i - 1] == a[j - 1]) ? 0 : 1;
      final newValue = min(
        min(currentRow[j] + 1, currentRow[j - 1] + 1),
        previous + cost,
      );
      previous = currentRow[j];
      currentRow[j] = newValue;
    }
  }

  return currentRow[a.length];
  
}
