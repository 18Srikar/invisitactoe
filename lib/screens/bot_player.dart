// lib/screens/bot_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/widgets/paper_jitter.dart';

import 'package:invisitactoe/audio/sfx.dart';            // <- shared SFX

// Shared logic
import 'package:invisitactoe/game_logic/game_engine.dart';
import 'package:invisitactoe/game_logic/bot_controller.dart';

class TicTacToePage extends StatefulWidget {
  final String title = 'Tic Tac Toe';
  @override
  _TicTacToePageState createState() => _TicTacToePageState();
}

class _TicTacToePageState extends State<TicTacToePage> {
  late final BotController controller;

  // UI state
  double opacity = 1;
  int textVisibleDuration = 500;
  double turnMessageOpacity = 1.0;
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  // Assets (scribbles)
  final List<String> xImages = [
    'assets/images/x1.png','assets/images/x2.png','assets/images/x3.png','assets/images/x4.png','assets/images/x5.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png','assets/images/o2.png','assets/images/o3.png','assets/images/o4.png',
  ];

  final _rng = Random();
  String? statusImagePath;

  @override
  void initState() {
    super.initState();
    controller = BotController();
    controller.addListener(_onControllerChange);
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChange);
    controller.dispose();
    super.dispose();
  }

  // Listen for AI moves & end-of-game to drive UI effects (and O sound)
  void _onControllerChange() {
    if (!mounted) return;
    final s = controller.value;

    // If AI just moved, paint its scribble, play O sound, schedule fade
    final idx = s.lastMove;
    if (idx != null && s.board[idx] == Cell.o && tileImages[idx] == null) {
      Sfx.o(); // play O sound exactly when first rendering the AI mark
      setState(() {
        tileOpacities[idx] = 1.0;
        tileImages[idx] = oImages[_rng.nextInt(oImages.length)];
      });
      Timer(const Duration(milliseconds: 500), () {
        if (!mounted || controller.value.ended) return;
        setState(() => tileOpacities[idx] = 0.0);
      });
    }

    // If game ended, reveal all tiles and show status banner
    if (s.ended) {
      setState(() {
        statusImagePath = s.winner == Player.x
            ? 'assets/images/x_wins_o_loses.png'
            : s.winner == Player.o
                ? 'assets/images/o_wins_x_loses.png'
                : 'assets/images/its_a_draw.png';
        turnMessageOpacity = 0.0;
        for (int i = 0; i < tileOpacities.length; i++) {
          tileOpacities[i] = 1.0;
        }
      });
    }
  }

  void buttonPress(int index) {
    final s = controller.value;

    // ignore if game ended or it's AI's turn
    if (s.ended || s.turn == Player.o) return;

    // invalid move -> human loses a turn and AI moves
    if (s.board[index] != Cell.empty) {
      HapticFeedback.vibrate();
      setState(() {
        statusImagePath = 'assets/images/invalid_move_x_loses_a_turn.png';
        opacity = 1.0;
      });
      Timer(Duration(milliseconds: textVisibleDuration), () {
        if (!mounted) return;
        setState(() => opacity = 0.0);
      });
      controller.forfeitHumanTurnAndAiMove();
      return;
    }

    // valid human move: play X sound, show scribble, fade, then apply move
    Sfx.x();
    setState(() {
      tileOpacities[index] = 1.0;
      tileImages[index] = xImages[_rng.nextInt(xImages.length)];
    });
    Timer(const Duration(milliseconds: 500), () {
      if (!mounted || controller.value.ended) return;
      setState(() => tileOpacities[index] = 0.0);
    });

    controller.playHuman(index);
  }

  void resetGame() {
    controller.reset();
    setState(() {
      tileOpacities = List.generate(9, (_) => 0.0);
      tileImages = List.generate(9, (_) => null);
      statusImagePath = null;
      turnMessageOpacity = 1.0;
      opacity = 1.0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.value;
        final isHumanTurn = s.turn == Player.x; // human is X

        // Responsive sizes
        final screenWidth = MediaQuery.of(context).size.width;
        final boardSize = screenWidth * 0.9;
        final tileSize = boardSize / 3;
        final safeTop = MediaQuery.of(context).padding.top;

        return Stack(
          children: <Widget>[
            // Background (Hero)
            Positioned.fill(
              child: Hero(
                tag: '__notebook_bg__',
                child: SizedBox.expand(
                  child: Image.asset(
                    BackgroundManager.current,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),

            // Back arrow
            Positioned(
              top: safeTop + 12,
              left: 25,
              child: PaperButton(
                onTap: () => Navigator.pop(context),
                child: Image.asset(
                  'assets/images/back_arrow_handwritten.png',
                  width: 40,
                  height: 40,
                ),
              ),
            ),

            // Main content
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Image.asset(
                    'assets/images/the_only_way_to_win.png',
                    height: screenWidth * 0.2,
                  ),
                  SizedBox(height: screenWidth * 0.05),

                  // Turn banner
                  AnimatedOpacity(
                    opacity: turnMessageOpacity,
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeIn,
                    child: Image.asset(
                      isHumanTurn
                          ? 'assets/images/your_move.png'
                          : 'assets/images/my_move.png',
                      height: screenWidth * 0.09,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.03),

                  // Status banner
                  AnimatedOpacity(
                    opacity: opacity,
                    duration: Duration(milliseconds: textVisibleDuration * 2),
                    curve: Curves.ease,
                    child: statusImagePath != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Image.asset(
                              statusImagePath!,
                              height: screenWidth * 0.08,
                            ),
                          )
                        : Container(height: screenWidth * 0.08),
                  ),
                  SizedBox(height: screenWidth * 0.04),

                  // Board
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/images/grid.png',
                        width: boardSize,
                        height: boardSize,
                      ),
                      SizedBox(
                        width: boardSize,
                        height: boardSize,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          primary: false,
                          padding: EdgeInsets.zero,
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                          ),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: s.ended || !isHumanTurn
                                  ? null
                                  : () => buttonPress(index),
                              child: Container(
                                color: Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (tileImages[index] != null)
                                      AnimatedOpacity(
                                        opacity: tileOpacities[index],
                                        duration: Duration(
                                            milliseconds: textVisibleDuration),
                                        child: Image.asset(
                                          tileImages[index]!,
                                          width: tileSize * 0.3,
                                          height: tileSize * 0.3,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: screenWidth * 0.04),

                  // Reset (jiggles only when ended)
                  PaperButton(
                    onTap: resetGame,
                    child: PaperJitter(
                      active: s.ended,
                      child: Image.asset(
                        'assets/images/reset.png',
                        height: screenWidth * 0.1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
