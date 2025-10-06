// lib/screens/two_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/widgets/paper_jitter.dart';

import 'package:invisitactoe/audio/sfx.dart';                 // shared SFX
// Shared logic
import 'package:invisitactoe/game_logic/game_engine.dart';
import 'package:invisitactoe/game_logic/two_local_controller.dart';

class TwoPlayerPage extends StatefulWidget {
  final String title = 'Two Player Mode';
  @override
  State<TwoPlayerPage> createState() => _TwoPlayerPageState();
}

class _TwoPlayerPageState extends State<TwoPlayerPage> {
  late final TwoLocalController controller;

  // UI state
  double opacity = 1;
  int textVisibleDuration = 750;
  double turnMessageOpacity = 1.0;
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  final List<String> xImages = [
    'assets/images/x1.png','assets/images/x2.png','assets/images/x3.png','assets/images/x4.png','assets/images/x5.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png','assets/images/o2.png','assets/images/o3.png','assets/images/o4.png',
  ];

  final Random _random = Random();
  String? statusImagePath;
  String? statusTextMessage; // left intact though unused (no behavior change)

  // Timers to make status logic robust
  Timer? _statusTimer;
  final List<Timer> _fadeTimers = [];

  // Precaching guard
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    controller = TwoLocalController();

    // Warm up audio (non-blocking; safe if already initialized elsewhere)
    // This reduces the chance of the very first tap stuttering.
    // No behavior change if init already ran.
    Future.microtask(() {
      try { Sfx.init(); } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cached) return;

    // Precache images to avoid first-use jank
    final toCache = <String>[
      ...xImages,
      ...oImages,
      'assets/images/grid.png',
      'assets/images/back_arrow_handwritten.png',
      'assets/images/reset.png',
      'assets/images/your_move_x.png',
      'assets/images/your_move_o.png',
      'assets/images/x_wins_o_loses.png',
      'assets/images/o_wins_x_loses.png',
      'assets/images/its_a_draw.png',
      'assets/images/invalid_move_x_loses_a_turn.png',
      'assets/images/invalid_move_o_loses_a_turn.png',
      BackgroundManager.current,
    ];
    for (final p in toCache) {
      precacheImage(AssetImage(p), context);
    }
    _cached = true;
  }

  @override
  void dispose() {
    // Cancel any pending timers to avoid late UI flips
    _statusTimer?.cancel();
    for (final t in _fadeTimers) {
      t.cancel();
    }
    controller.dispose();
    super.dispose();
  }

  // tiny helpers to DRY UI effects
  void _showStatusAndHideTurn(String asset) {
    // Cancel any existing status timer so it can't override later states (e.g., endgame banner)
    _statusTimer?.cancel();

    setState(() {
      statusImagePath = asset;
      turnMessageOpacity = 0.0;
      opacity = 1.0;
    });

    _statusTimer = Timer(Duration(milliseconds: textVisibleDuration), () {
      // If the game ended while the timer was pending, do nothing.
      if (!mounted || controller.value.ended) return;
      setState(() {
        opacity = 0.0;
        turnMessageOpacity = 1.0;
      });
    });
  }

  void _fadeTileLater(int index) {
    final t = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || controller.value.ended) return;
      setState(() => tileOpacities[index] = 0.0);
    });
    _fadeTimers.add(t);
  }

  void _revealAllTiles() {
    setState(() {
      for (var i = 0; i < tileOpacities.length; i++) {
        tileOpacities[i] = 1.0;
      }
    });
  }

  void buttonPress(int index) {
    final s = controller.value;
    if (s.ended) {
      // onTap is disabled when ended, so this path normally won't run.
      return;
    }

    // invalid move -> penalty
    if (s.board[index] != Cell.empty) {
      HapticFeedback.vibrate(); // invalid-move only (as you wanted)
      _showStatusAndHideTurn(
        s.turn == Player.x
          ? 'assets/images/invalid_move_x_loses_a_turn.png'
          : 'assets/images/invalid_move_o_loses_a_turn.png',
      );
      controller.forfeitTurn();
      return;
    }

    // valid move (play SFX based on current turn)
    if (s.turn == Player.x) { Sfx.x(); } else { Sfx.o(); }

    setState(() {
      tileOpacities[index] = 1.0;
      // local mode: keep your random art choice (stable after set)
      tileImages[index] = s.turn == Player.x
        ? xImages[_random.nextInt(xImages.length)]
        : oImages[_random.nextInt(oImages.length)];
    });
    _fadeTileLater(index);

    controller.play(index);

    final s2 = controller.value;
    if (s2.ended) {
      // Lock in the end banner; ensure no earlier status timer can hide it
      _statusTimer?.cancel();
      _revealAllTiles();
      setState(() {
        statusImagePath = s2.winner == Player.x
          ? 'assets/images/x_wins_o_loses.png'
          : s2.winner == Player.o
            ? 'assets/images/o_wins_x_loses.png'
            : 'assets/images/its_a_draw.png';
        turnMessageOpacity = 0.0;
        opacity = 1.0; // keep the end banner visible
      });
    }
  }

  void resetGame() {
    // Clean up any queued animations/timers so they can't flip the new round's UI
    _statusTimer?.cancel();
    for (final t in _fadeTimers) {
      t.cancel();
    }
    _fadeTimers.clear();

    controller.reset();
    setState(() {
      tileOpacities = List.generate(9, (_) => 0.0);
      tileImages = List.generate(9, (_) => null);
      statusImagePath = null;
      statusTextMessage = null;
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
        final isXTurn = s.turn == Player.x;

        final screenWidth = MediaQuery.of(context).size.width;
        final boardSize = screenWidth * 0.90;
        final tileSize = boardSize / 3;
        final safeTop = MediaQuery.of(context).padding.top;

        return Stack(
          children: <Widget>[
            Positioned.fill(
              child: Hero(
                tag: '__notebook_bg__',
                child: SizedBox.expand(
                  child: Image.asset(BackgroundManager.current, fit: BoxFit.cover),
                ),
              ),
            ),
            Positioned(
              top: safeTop + 12, left: 25,
              child: PaperButton(
                onTap: () => Navigator.pop(context),
                child: Image.asset('assets/images/back_arrow_handwritten.png', width: 40, height: 40),
              ),
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: screenWidth * 0.04),
                  AnimatedOpacity(
                    opacity: turnMessageOpacity,
                    duration: const Duration(milliseconds: 750),
                    curve: Curves.easeIn,
                    child: Image.asset(
                      isXTurn ? 'assets/images/your_move_x.png' : 'assets/images/your_move_o.png',
                      height: screenWidth * 0.08,
                    ),
                  ),
                  SizedBox(height: screenWidth * 0.04),
                  AnimatedOpacity(
                    opacity: opacity,
                    duration: Duration(milliseconds: textVisibleDuration * 2),
                    curve: Curves.ease,
                    child: statusImagePath != null
                        ? Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            child: Image.asset(statusImagePath!, height: screenWidth * 0.08),
                          )
                        : Container(height: screenWidth * 0.08),
                  ),
                  SizedBox(height: screenWidth * 0.04),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset('assets/images/grid.png', width: boardSize, height: boardSize),
                      SizedBox(
                        width: boardSize, height: boardSize,
                        child: GridView.builder(
                          physics: const NeverScrollableScrollPhysics(),
                          primary: false,
                          padding: EdgeInsets.zero,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3),
                          itemCount: 9,
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: s.ended ? null : () => buttonPress(index),
                              child: Container(
                                color: Colors.transparent,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    if (tileImages[index] != null)
                                      AnimatedOpacity(
                                        opacity: tileOpacities[index],
                                        duration: Duration(milliseconds: textVisibleDuration),
                                        child: Image.asset(
                                          tileImages[index]!,
                                          width: tileSize * 0.3, height: tileSize * 0.3,
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
                  PaperButton(
                    onTap: resetGame,
                    child: PaperJitter(
                      active: s.ended, // jiggle only after game ends
                      child: Image.asset('assets/images/reset.png', height: screenWidth * 0.1),
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
