// lib/screens/bot_player.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';

import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/widgets/paper_jitter.dart';
import 'package:invisitactoe/widgets/win_strike.dart'; // ← ADDED

import 'package:invisitactoe/audio/sfx.dart'; // <- Soundpool / audioplayers SFX

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
  int textVisibleDuration = 750;
  double turnMessageOpacity = 1.0;
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  // Assets (scribbles)
  final List<String> xImages = [
    'assets/images/x1.png','assets/images/x2.png','assets/images/x3.png','assets/images/x4.png','assets/images/x5.png', 'assets/images/x7.png','assets/images/x6.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png','assets/images/o2.png','assets/images/o3.png','assets/images/o4.png','assets/images/o6.png',
  ];

  final _rng = Random();
  String? statusImagePath;

  // Timers (robustness)
  Timer? _statusTimer;              // for transient status opacity
  final List<Timer> _fadeTimers = []; // per-tile fade timers

  // NEW: dots banner timer state (no layout shift)
  Timer? _dotsTimer;
  int _dotsStep = 0;   // 0..2 => 1..3 dots visible

  // Precaching guard
  bool _cached = false;

  @override
  void initState() {
    super.initState();
    controller = BotController();
    controller.addListener(_onControllerChange);

    // Warm up audio (safe if already initialized elsewhere)
    Future.microtask(() {
      try { Sfx.init(); } catch (_) {}
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_cached) return;

    // Precache images used on this screen (prevents first-use jank)
    final toCache = <String>[
      ...xImages,
      ...oImages,
      'assets/images/grid.png',
      'assets/images/back_arrow_handwritten.png',
      'assets/images/reset.png',
      'assets/images/the_only_way_to_win.png',
      'assets/images/your_move.png',
      'assets/images/my_move.png', // kept even if not shown when bot turn
      'assets/images/you_win.png',
      'assets/images/i_win.png',
      'assets/images/its_a_draw.png',
      'assets/images/invalid_move_x_loses_a_turn.png',
      // dots used for the bot-turn banner
      'assets/images/dot1.png',
      'assets/images/dot2.png',
      'assets/images/dot3.png',
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
    _dotsTimer?.cancel();

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
      Sfx.o();
      setState(() {
        tileOpacities[idx] = 1.0;
        tileImages[idx] = oImages[_rng.nextInt(oImages.length)];
      });
      final t = Timer(const Duration(milliseconds: 600), () {
        if (!mounted || controller.value.ended) return;
        setState(() => tileOpacities[idx] = 0.0);
      });
      _fadeTimers.add(t);
    }

    // If game ended, reveal all tiles and show status banner
    if (s.ended) {
      // Lock in the end banner; ensure no earlier status timer can hide it
      _statusTimer?.cancel();
      // Stop dots when game is over
      _dotsTimer?.cancel();
      _dotsTimer = null;

      setState(() {
        statusImagePath = s.winner == Player.x
            ? 'assets/images/you_win.png'
            : s.winner == Player.o
                ? 'assets/images/i_win.png'
                : 'assets/images/you_win.png';
        turnMessageOpacity = 0.0;
        for (int i = 0; i < tileOpacities.length; i++) {
          tileOpacities[i] = 1.0;
        }
        opacity = 1.0; // keep the end banner visible
        _dotsStep = 0; 
      });
    } else {
      // Keep the dots animating only while it's the bot's turn
      final isHumanTurn = s.turn == Player.x;
      _ensureDotsRunning(run: !isHumanTurn);
    }
  }

  // Ensure three-dot banner is ticking when bot's turn; pause otherwise
  void _ensureDotsRunning({required bool run}) {
    if (run) {
      if (_dotsTimer == null) {
        _dotsTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
          if (!mounted) return;
          setState(() => _dotsStep = (_dotsStep + 1) % 3);
        });
      }
    } else {
      _dotsTimer?.cancel();
      _dotsTimer = null;
    }
  }

  void buttonPress(int index) {
    final s = controller.value;

    // ignore if game ended or it's AI's turn
    if (s.ended || s.turn == Player.o) return;

    // invalid move -> human loses a turn and AI moves
    if (s.board[index] != Cell.empty) {
      HapticFeedback.vibrate();

      // Cancel any existing status timer so it can't override later states
      _statusTimer?.cancel();

      setState(() {
        statusImagePath = 'assets/images/invalid_move_x_loses_a_turn.png';
        opacity = 1.0;
      });

      _statusTimer = Timer(Duration(milliseconds: textVisibleDuration), () {
        if (!mounted || controller.value.ended) return;
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
    final t = Timer(const Duration(milliseconds: 600), () {
      if (!mounted || controller.value.ended) return;
      setState(() => tileOpacities[index] = 0.0);
    });
    _fadeTimers.add(t);

    controller.playHuman(index);
  }

  void resetGame() {
    // Clean up any queued animations/timers so they can't flip the new round's UI
    _statusTimer?.cancel();
    for (final t in _fadeTimers) {
      t.cancel();
    }
    _fadeTimers.clear();
    _dotsTimer?.cancel();
    _dotsTimer = null;

    controller.reset();
    setState(() {
      tileOpacities = List.generate(9, (_) => 0.0);
      tileImages = List.generate(9, (_) => null);
      statusImagePath = null;
      turnMessageOpacity = 1.0;
      opacity = 1.0;
      _dotsStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.value;
        final isHumanTurn = s.turn == Player.x; // human is X

        // Ensure dots run only on bot turn while not ended
        _ensureDotsRunning(run: !isHumanTurn && !s.ended);

        // Responsive sizes
        final screenWidth = MediaQuery.of(context).size.width;
        final boardSize = screenWidth * 0.9;
        final tileSize = boardSize / 3;
        final safeTop = MediaQuery.of(context).padding.top;

        // Fixed banner height to avoid layout shift
        final bannerH = screenWidth * 0.09;

        // ← ADDED: compute winning strike (if any)
        final win = s.ended ? findWin(s.board) : null;

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
                  width: 35,
                  height: 35,
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

                  // Turn banner (fixed-height slot → NO LAYOUT SHIFT)
                  SizedBox(
                    height: bannerH,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: isHumanTurn
                          ? Align(
                              key: const ValueKey('human-turn'),
                              alignment: Alignment.center,
                              child: AnimatedOpacity(
                                opacity: turnMessageOpacity,
                                duration: const Duration(milliseconds: 750),
                                curve: Curves.easeIn,
                                child: Image.asset(
                                  'assets/images/your_move.png',
                                  height: bannerH,
                                ),
                              ),
                            )
                          : _DotsBanner(
                              key: const ValueKey('bot-dots'),
                              height: bannerH,
                              step: _dotsStep, // 0..2 -> shows 1..3 dots
                            ),
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
                      // ← ADDED: handwritten strike overlay (fades in to match tiles)
                      if (win != null)
                        WinStrike(
                          info: win,
                          boardSize: boardSize,
                          durationMs: textVisibleDuration, // match reveal timing
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

// Lightweight three-dot banner for bot turn; fixed height → no layout shift.
class _DotsBanner extends StatelessWidget {
  const _DotsBanner({super.key, required this.height, required this.step});

  final double height;
  final int step; // 0..2 -> number of dots = step+1

  @override
  Widget build(BuildContext context) {
    final visibleDots = step + 1; // 1..3
    final dotSize = height * 0.15; // ~15% of banner height
    const spacing = 6.0;

    Widget dot(String asset, bool on) => AnimatedOpacity(
          opacity: on ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeInOut,
          child: Image.asset(asset, height: dotSize),
        );

    return SizedBox(
      height: height,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          dot('assets/images/dot1.png', visibleDots >= 1),
          SizedBox(width: spacing),
          dot('assets/images/dot2.png', visibleDots >= 2),
          SizedBox(width: spacing),
          dot('assets/images/dot3.png', visibleDots >= 3),
        ],
      ),
    );
  }
}
