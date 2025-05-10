// main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'ocr_screen.dart';
import 'ocr_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await OCRProvider.copyDatabase();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OCRProvider()..initializeCamera(),
      child: MaterialApp(
        title: 'OCR App',
        theme: ThemeData(primarySwatch: Colors.blue),
        home: OCRScreen(),
      ),
    );
  }
}
