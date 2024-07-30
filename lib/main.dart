import 'package:flutter/material.dart';
import 'package:invisitactoe/screens/home_page.dart';
import 'package:flutter/services.dart';
void main() {
  WidgetsFlutterBinding.ensureInitialized(); 
  SystemChrome.setPreferredOrientations( 
    [DeviceOrientation.portraitUp]); 
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:'InvisiTacToe',
      themeMode: ThemeMode.dark,
      theme: ThemeData.dark(
        useMaterial3: true,
      ),
      home: const HomePage(title:'InvisiTacToe'),
      debugShowCheckedModeBanner: false,
      
    );
  }
}

