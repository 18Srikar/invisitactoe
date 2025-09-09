import 'package:flutter/material.dart';
import 'package:invisitactoe/screens/home_page.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Let your SFX mix with Spotify/YouTube Music instead of stopping them
  AudioPlayer.global.setAudioContext(AudioContext(
    android: const AudioContextAndroid(
      // “UI sounds” usage helps Android route/volume correctly
      usageType: AndroidUsageType.game,
      contentType: AndroidContentType.sonification,
      // Don’t take audio focus so other apps keep playing
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      // Plays even if the mute switch is on; change to .ambient to respect mute
      category: AVAudioSessionCategory.playback,
      // The key bit: mix with other apps (don’t interrupt)
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  ));

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'InvisiTacToe',
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,),
      home: const HomePage(title:'InvisiTacToe'),
      debugShowCheckedModeBanner: false,
      
    );
  }
}

