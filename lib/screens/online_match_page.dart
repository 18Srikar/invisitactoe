// lib/screens/online_match_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';

import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/widgets/ellipsis_banner.dart';
import 'package:invisitactoe/widgets/paper_jitter.dart';
import 'package:invisitactoe/audio/sfx.dart';

// online controller + shared logic
import 'package:invisitactoe/game_logic/online_controller.dart';
import 'package:invisitactoe/game_logic/game_engine.dart';

class OnlineMatchPage extends StatefulWidget {
  final String title;
  final OnlineController controller;

  const OnlineMatchPage({
    super.key,
    this.title = 'Online Match',
    required this.controller,
  });

  @override
  State<OnlineMatchPage> createState() => _OnlineMatchPageState();
}

class _OnlineMatchPageState extends State<OnlineMatchPage> {
  late final OnlineController controller;

  GameState? _prev;
  late final VoidCallback _stateListener;

  // UI state
  int textVisibleDuration = 900; // linger status/penalty a bit longer
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  final List<String> xImages = [
    'assets/images/x1.png','assets/images/x2.png','assets/images/x3.png','assets/images/x4.png','assets/images/x5.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png','assets/images/o2.png','assets/images/o3.png','assets/images/o4.png',
  ];

  String? statusImagePath;
  String? statusTextMessage;
  double statusOpacity = 1.0;

  // Once both were present at least once, never show the "waiting" overlay again
  bool _everReady = false;

  // Opponent-turn dots animation (…)
  Timer? _dotsTimer;
  int _dotsStep = 0;     // 0,1,2 -> shows 1,2,3 dots
  bool _dotsActive = false;

  void _setDotsActive(bool active) {
    if (_dotsActive == active) return;
    _dotsActive = active;
    _dotsTimer?.cancel();
    if (active) {
      _dotsTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
        if (!mounted) return;
        setState(() {
          _dotsStep = (_dotsStep + 1) % 3;
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    controller = widget.controller;

    _prev = controller.value;
    _stateListener = _onStateChanged;
    controller.addListener(_stateListener);

    // Mark presence when entering this page
    controller.setPresence(true);
  }

  @override
  void dispose() {
    controller.removeListener(_stateListener);
    controller.setPresence(false); // best-effort
    _dotsTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  bool _boardHasAny(List<Cell> b) => b.any((c) => c != Cell.empty);

  void _onStateChanged() {
    final cur = controller.value;
    final prev = _prev;

    // Latch: if we ever reach "ready", remember it
    if (controller.isReady) {
      _everReady = true;
    }

    // If the game ended (any reason), stop dots immediately
    if (cur.ended) {
      _setDotsActive(false);
    }

    // Detect remote reset -> clear local UI (but don't reset _everReady)
    if (prev != null) {
      final prevHadAny = _boardHasAny(prev.board);
      final nowHasAny = _boardHasAny(cur.board);
      final resetDetected = (prevHadAny && !nowHasAny) ||
          ((prev.ended && !cur.ended) && !nowHasAny);

      if (resetDetected) {
        setState(() {
          tileOpacities = List.generate(9, (_) => 0.0);
          tileImages = List.generate(9, (_) => null);
          statusImagePath = null;
          statusTextMessage = null;
          statusOpacity = 1.0;
        });
      }
    }

    // Draw last move + play sound via Sfx helper
    final lm = cur.lastMove;
    if (lm != null && (prev == null || prev.lastMove != lm)) {
      if (cur.board[lm] != Cell.empty) {
        setState(() {
          tileImages[lm] ??= (cur.board[lm] == Cell.x)
              ? xImages[lm % xImages.length]
              : oImages[lm % oImages.length];
          tileOpacities[lm] = 1.0;
        });
        // Play scribble SFX (randomized inside Sfx)
        if (cur.board[lm] == Cell.x) {
          Sfx.x();
        } else if (cur.board[lm] == Cell.o) {
          Sfx.o();
        }
        _fadeTileLater(lm);
      }
    }

    // Normal game end -> banner (leave-case handled by early-return in build)
    if ((prev == null || !prev.ended) && cur.ended && !controller.endedByLeave) {
      _revealAllTiles();
      setState(() {
        statusImagePath = cur.winner == Player.x
            ? 'assets/images/x_wins_o_loses.png'
            : cur.winner == Player.o
                ? 'assets/images/o_wins_x_loses.png'
                : 'assets/images/its_a_draw.png';
        statusTextMessage = null;
        statusOpacity = 1.0;
      });
    }

    // One-shot system notice (we still let build() decide what to show)
    final notice = controller.systemMessage;
    if (notice != null) {
      setState(() {
        statusTextMessage = notice;
        statusImagePath = null;
        statusOpacity = 1.0;
      });
      controller.clearSystemMessage();
    }

    // One-shot penalty banner from Firestore (appears on BOTH phones)
    final p = controller.penaltyBy;
    if (p != null) {
      setState(() {
        statusImagePath = (p == 'x')
            ? 'assets/images/invalid_move_x_loses_a_turn.png'
            : 'assets/images/invalid_move_o_loses_a_turn.png';
        statusTextMessage = null;
        statusOpacity = 1.0;
      });
      // Keep penalty a little longer than generic messages
      const penaltyHoldMs = 1100;
      Timer(const Duration(milliseconds: penaltyHoldMs), () {
        if (!mounted) return;
        setState(() {
          statusOpacity = 0.0;
          statusImagePath = null;
        });
      });
      controller.ackPenalty();
    }

    _prev = cur;
  }

  void _fadeTileLater(int index) {
    Timer(const Duration(milliseconds: 500), () {
      if (!mounted || controller.value.ended) return;
      setState(() => tileOpacities[index] = 0.0);
    });
  }

  void _revealAllTiles() {
    setState(() { for (var i=0;i<tileOpacities.length;i++) tileOpacities[i] = 1.0; });
  }

  void buttonPress(int index) {
    final s = controller.value;

    // must be ready (both joined & present) AND my turn
    final isReady = controller.isReady;
    final me = controller.localPlayer;
    final isMyTurn = (me != null && me == s.turn);

    if (!isReady || !isMyTurn) {
      HapticFeedback.vibrate();
      return;
    }
    if (s.ended) { HapticFeedback.vibrate(); return; }

    // invalid move -> penalty
    if (s.board[index] != Cell.empty) {
      HapticFeedback.vibrate();
      controller.forfeitTurn();
      return;
    }

    // valid move: optimistic fade-in; sound will play on snapshot
    setState(() {
      tileOpacities[index] = 1.0;
      tileImages[index] = s.turn == Player.x
          ? xImages[index % xImages.length]
          : oImages[index % oImages.length];
    });
    _fadeTileLater(index);

    controller.play(index);
  }

  void _onPressReset() {
    controller.reset(); // no "Resetting..." text
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.value;
        final isReady = controller.isReady;

        // Treat as "opponent left" if:
        // 1) ended-by-leave, OR 2) room closed message, OR
        // 3) we were ready at least once and are NOT ready now (covers race/flicker).
        final systemMsg = (controller.systemMessage ?? '').toLowerCase();
        final bool opponentLeft =
            controller.endedByLeave ||
            systemMsg.contains('room closed') ||
            (_everReady && !isReady);

        if (opponentLeft) {
          final screenWidth = MediaQuery.of(context).size.width;
          final safeTop = MediaQuery.of(context).padding.top;
          _setDotsActive(false); // stop dots
          return Stack(
            children: [
              Positioned.fill(
                child: Hero(
                  tag: '__notebook_bg__',
                  child: SizedBox.expand(
                    child: Image.asset(BackgroundManager.current, fit: BoxFit.cover),
                  ),
                ),
              ),
              Center(
                child: Image.asset(
                  'assets/images/opponent_left.png',
                  height: screenWidth * 0.10,
                ),
              ),
              // BACK BUTTON LAST → always on top (works even over overlays)
              Positioned(
                top: safeTop + 12,
                left: 25,
                child: PaperButton(
                  onTap: () async {
                    try { await controller.leave(); } catch (_) {}
                    if (mounted) Navigator.pop(context);
                  },
                  child: Image.asset('assets/images/back_arrow_handwritten.png', width: 40, height: 40),
                ),
              ),
            ],
          );
        }

        // Waiting overlay only BEFORE both have ever been ready
        final waiting = (!_everReady && !isReady && !s.ended && controller.systemMessage == null);
        final gridOpacity = waiting ? 0.35 : 1.0;

        final me = controller.localPlayer;
        final isMyTurn = (me != null && me == s.turn);
        final isXTurn = s.turn == Player.x;

        final screenWidth = MediaQuery.of(context).size.width;
        final boardSize = screenWidth * 0.90;
        final tileSize = boardSize / 3;
        final safeTop = MediaQuery.of(context).padding.top;

        // Fixed heights to prevent layout shift
        final bannerH = screenWidth * 0.08;
        final resetH = screenWidth * 0.10;

        // Show banner ONLY when ready, not ended, and it's my turn.
        final showBanner = isReady && !s.ended && isMyTurn;

        // Dots animate only when ready, not ended, and it's opponent's turn
        final showOpponentDots = isReady && !s.ended && !isMyTurn;
        _setDotsActive(showOpponentDots && mounted);

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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: screenWidth * 0.02),

                  // Turn banner slot:
                  SizedBox(
                    height: bannerH,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: showBanner
                          ? Align(
                              key: const ValueKey('banner-my-turn'),
                              alignment: Alignment.center,
                              child: Image.asset(
                                isXTurn ? 'assets/images/your_move_x.png' : 'assets/images/your_move_o.png',
                                height: bannerH,
                              ),
                            )
                          : showOpponentDots
                              ? _DotsBanner(
                                  key: const ValueKey('banner-opponent-dots'),
                                  height: bannerH,
                                  step: _dotsStep, // 0..2
                                )
                              : const SizedBox(key: ValueKey('banner-empty')),
                    ),
                  ),

                  SizedBox(height: screenWidth * 0.02),

                  // Status area
                  AnimatedOpacity(
                    opacity: (statusImagePath != null || statusTextMessage != null) ? statusOpacity : 0.0,
                    duration: Duration(milliseconds: textVisibleDuration * 2),
                    curve: Curves.ease,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Builder(
                        builder: (_) {
                          if (statusImagePath != null) {
                            return Image.asset(statusImagePath!, height: bannerH);
                          }
                          if (statusTextMessage != null) {
                            return Text(
                              statusTextMessage!,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: screenWidth * 0.045,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                                shadows: const [Shadow(blurRadius: 2, color: Colors.white)],
                              ),
                            );
                          }
                          return SizedBox(height: bannerH);
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: screenWidth * 0.02),

                  // Board (dims while waiting)
                  AnimatedOpacity(
                    opacity: gridOpacity,
                    duration: const Duration(milliseconds: 200),
                    child: Stack(
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
                                onTap: (s.ended || !isReady || !isMyTurn) ? null : () => buttonPress(index),
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
                  ),

                  SizedBox(height: screenWidth * 0.03),

                  // Reset area — fixed-height slot (prevents layout shift when it appears)
                  SizedBox(
                    height: resetH,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: (s.ended && !controller.endedByLeave)
                          ? Center(
                              key: const ValueKey('reset-visible'),
                              child: PaperButton(
                                onTap: _onPressReset,
                                child: PaperJitter(
                                  active: s.ended && !controller.endedByLeave,
                                  child: Image.asset('assets/images/reset.png', height: resetH),
                                ),
                              ),
                            )
                          : const SizedBox(
                              key: ValueKey('reset-hidden'),
                            ),
                    ),
                  ),
                ],
              ),
            ),

            // Waiting overlay — only before the first time both are ready
            if (waiting)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.15),
                    child: Center(
                      child: EllipsisBanner(
                        phraseAsset: 'assets/images/waiting_for_player.png',
                        dotAssets: const [
                          'assets/images/dot1.png',
                          'assets/images/dot2.png',
                          'assets/images/dot3.png',
                        ],
                        height: screenWidth * 0.1,
                        step: const Duration(milliseconds: 300),
                        dotScale: 0.20,
                        spacing: 6,
                        dotsBelow: false,
                      ),
                    ),
                  ),
                ),
              ),

            // BACK BUTTON LAST → rendered on top of everything (including overlay)
            Positioned(
              top: safeTop + 12,
              left: 25,
              child: PaperButton(
                onTap: () async {
                  try { await controller.leave(); } catch (_) {}
                  if (mounted) Navigator.pop(context);
                },
                child: Image.asset('assets/images/back_arrow_handwritten.png', width: 40, height: 40),
              ),
            ),
          ],
        );
      },
    );
  }
}

// Lightweight, self-contained dots banner used in the turn-banner slot.
// Shows 1, 2, 3 hand-drawn dots in a loop without shifting layout.
class _DotsBanner extends StatelessWidget {
  const _DotsBanner({super.key, required this.height, required this.step});

  final double height;
  final int step; // 0..2 -> number of dots = step+1

  @override
  Widget build(BuildContext context) {
    final visibleDots = step + 1; // 1..3
    final dotSize = height * 0.22; // ~22% of banner height
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
