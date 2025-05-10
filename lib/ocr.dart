import 'package:audioplayers/audioplayers.dart';

final AudioPlayer _player = AudioPlayer();

Future<void> playRightBeep() async {
  await _player.play(AssetSource('true.mp3'));
}

Future<void> playWrongBeep() async {
  await _player.play(AssetSource('false.mp3'));
}
