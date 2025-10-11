import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:invisitactoe/widgets/paper_jitter.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/screens/bot_player.dart';
import 'package:invisitactoe/screens/two_player.dart';
import 'package:invisitactoe/screens/rules_page.dart';
import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/screens/online_lobby_page.dart';

class HomePage extends StatefulWidget {
  final String title;

  const HomePage({required this.title});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late Timer _timer;



  @override
  void dispose() {
    // Cancel the timer when the widget is disposed to prevent memory leaks
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Precache the background so Hero switches are seamless
    precacheImage(AssetImage(BackgroundManager.current), context);
    precacheImage(const AssetImage('assets/images/btn_bot_mode.png'), context);
    precacheImage(const AssetImage('assets/images/btn_two_player.png'), context);
    precacheImage(const AssetImage('assets/images/question_mark.png'), context);
    precacheImage(const AssetImage('assets/images/back_arrow_handwritten.png'), context);
    precacheImage(const AssetImage('assets/images/title_handwritten.png'), context);

    final screenWidth = MediaQuery.of(context).size.width;
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Stack(
        children: [
          // Persistent-feeling background (shared Hero across pages)
           Positioned.fill(
            child: Hero(
              tag: '__notebook_bg__',
              child: Image.asset( BackgroundManager.current,
      fit: BoxFit.cover,)
            ),
          ),


          // Foreground content (center buttons)
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/title_handwritten.png',
                  width: screenWidth * 0.6, // responsive sizing
                  fit: BoxFit.contain,
                ),
                 SizedBox(height: screenWidth * 0.12), // spacing
                // Two-player button with animation
                PaperButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TwoPlayerPage()),
                    );
                  },
                  child: PaperJitter(
                        active: true,                // always jitter on Home
    amplitude: 1.5,              // ~±2px like before
    period: const Duration(milliseconds: 301),
                    child: Image.asset(
                      'assets/images/btn_two_player.png',
                      width: screenWidth * 0.45,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                 SizedBox(height: screenWidth * 0.07),

                // Bot mode button with animation
                PaperButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => TicTacToePage()),
                    );
                  },
                  child: PaperJitter(
                    active: true,                // always jitter on Home
                    amplitude: 1.5,              // ~±2px like before
                    period: const Duration(milliseconds: 300),
                    child: Image.asset(
                      'assets/images/btn_bot_mode.png',
                      width: screenWidth * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: screenWidth * 0.07),
                PaperButton(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => OnlineLobbyPage()),
                    );
                  },
                  child: PaperJitter(
                        active: true,                // always jitter on Home
    amplitude: 1.5,              // ~±2px like before
    period: const Duration(milliseconds: 299),
                    child: Image.asset(
                      'assets/images/online_mode.png',
                      width: screenWidth * 0.36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Question mark (top-right → rules page)
          Positioned(
            top: safeTop + 12,
            right: 20,
            child: PaperButton(
              onTap: () {
                HapticFeedback.lightImpact();
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RulesPage()),
                );
              },
              child: Image.asset(
                'assets/images/question_mark.png',
                width: 50,
                height: 50,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
