import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:invisitactoe/audio/sfx.dart';
import 'package:invisitactoe/screens/home_page.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Anonymous sign-in for online mode
  await FirebaseAuth.instance.signInAnonymously();

  // Lock to portrait
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // ✅ Correct audioplayers 6.x global audio context
  AudioPlayer.global.setAudioContext(
     AudioContext(
      android: AudioContextAndroid(
        usageType: AndroidUsageType.game,                 // right enum
        contentType: AndroidContentType.sonification,     // right enum
        audioFocus: AndroidAudioFocus.none,               // mix with other apps
      ),
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,        // right enum
        options: { AVAudioSessionOptions.mixWithOthers }, // set<enum> literal
      ),
    ),
  );
await Sfx.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvisiTacToe',
      themeMode: ThemeMode.dark,
      theme: ThemeData(useMaterial3: true),
      debugShowCheckedModeBanner: false,
      home: const HomePage(title: 'InvisiTacToe'),
    );
  }
}
