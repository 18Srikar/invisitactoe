import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import 'dart:async';

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
  // Random number generator for the jittering motion
  final _random = Random();
  late Timer _timer;

  // Variables to hold the current random offsets for the two-player button
  double _twoPlayerXOffset = 0.0;
  double _twoPlayerYOffset = 0.0;
  
  // Variables to hold the current random offsets for the bot button
  // double _botXOffset = 0.0;
  // double _botYOffset = 0.0;

  @override
  void initState() {
    super.initState();
    // Start a periodic timer to update the button positions
    _timer = Timer.periodic(const Duration(milliseconds: 300), (timer) {
      setState(() {
        // Generate new random offsets for the two-player button
        _twoPlayerXOffset = _random.nextDouble() * 4 - 2; // Random value between -2 and 2
        _twoPlayerYOffset = _random.nextDouble() * 4 - 2;

        // // Generate new random offsets for the bot button
        // _botXOffset = _random.nextDouble() * 4 - 2; // Random value between -2 and 2
        // _botYOffset = _random.nextDouble() * 4 - 2;
      });
    });
  }

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
                  child: Transform.translate(
                    offset: Offset(_twoPlayerXOffset, _twoPlayerYOffset),
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
                  child: Transform.translate(
                    offset: Offset(-_twoPlayerXOffset, -_twoPlayerYOffset), // Opposite animation
                    child: Image.asset(
                      'assets/images/btn_bot_mode.png',
                      width: screenWidth * 0.35,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                PaperButton(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const OnlineLobbyPage()),
                          );
                        },
                        child: const Text('Play Online'),
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
