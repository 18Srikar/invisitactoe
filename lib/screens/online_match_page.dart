import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:math';
import 'package:audioplayers/audioplayers.dart';
import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';

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
  int textVisibleDuration = 500;
  List<double> tileOpacities = List.generate(9, (index) => 0.0);
  List<String?> tileImages = List.generate(9, (index) => null);

  final List<String> xImages = [
    'assets/images/x1.png','assets/images/x2.png','assets/images/x3.png','assets/images/x4.png','assets/images/x5.png',
  ];
  final List<String> oImages = [
    'assets/images/o1.png','assets/images/o2.png','assets/images/o3.png','assets/images/o4.png',
  ];
  // NOTE: keep the same relative paths that work in your local mode
  final List<String> xSounds = ['audio/x_scribble_1.wav','audio/x_scribble_2.wav'];
  final List<String> oSounds = ['audio/o_scribble_1.wav','audio/o_scribble_2.wav'];

  final Random _random = Random(); // pick sound variant
  String? statusImagePath;         // temporary image banner (win/draw/penalty)
  String? statusTextMessage;       // persistent text (opponent left / errors)
  double statusOpacity = 1.0;      // fade only the status area (not the turn banner)

  @override
  void initState() {
    super.initState();
    controller = widget.controller;

    _prev = controller.value;
    _stateListener = _onStateChanged;
    controller.addListener(_stateListener);
  }

  @override
  void dispose() {
    controller.removeListener(_stateListener);
    controller.dispose();
    super.dispose();
  }

  bool _boardHasAny(List<Cell> b) => b.any((c) => c != Cell.empty);

  void _onStateChanged() {
    final cur = controller.value;
    final prev = _prev;

    // Detect remote reset -> clear local UI
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

    // Draw last move (deterministic art per cell index to avoid mismatch/flicker)
    final lm = cur.lastMove;
    if (lm != null && (prev == null || prev.lastMove != lm)) {
      if (cur.board[lm] != Cell.empty) {
        setState(() {
          tileImages[lm] ??= (cur.board[lm] == Cell.x)
              ? xImages[lm % xImages.length]
              : oImages[lm % oImages.length];
          tileOpacities[lm] = 1.0;
        });
        _fadeTileLater(lm);
      }
    }

    // Remote game end -> show ending banner, reveal tiles
    if ((prev == null || !prev.ended) && cur.ended) {
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

    // One-shot system notice (opponent left etc.) — persistent
    final notice = controller.systemMessage;
    if (notice != null) {
      setState(() {
        statusTextMessage = notice;
        statusImagePath = null;
        statusOpacity = 1.0;
      });
      controller.clearSystemMessage();
    }

    _prev = cur;
  }

  // === helpers ===
  void _showTempStatusImage(String asset) {
    setState(() {
      statusImagePath = asset;
      statusTextMessage = null;
      statusOpacity = 1.0;
    });
    // auto-fade away; (does NOT affect the turn banner)
    Timer(Duration(milliseconds: textVisibleDuration), () {
      if (!mounted) return;
      setState(() {
        statusOpacity = 0.0;
        statusImagePath = null;
      });
    });
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

  // Same sound strategy as your local page (works on your devices)
  void _playXSound() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource(xSounds[_random.nextInt(xSounds.length)]));
      Timer(const Duration(seconds: 2), () => p.dispose());
    } catch (_) {}
  }

  void _playOSound() async {
    try {
      final p = AudioPlayer();
      await p.play(AssetSource(oSounds[_random.nextInt(oSounds.length)]));
      Timer(const Duration(seconds: 2), () => p.dispose());
    } catch (_) {}
  }

  void buttonPress(int index) {
    final s = controller.value;

    // must be ready (both joined) AND my turn
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
      _showTempStatusImage(
        s.turn == Player.x
            ? 'assets/images/invalid_move_x_loses_a_turn.png'
            : 'assets/images/invalid_move_o_loses_a_turn.png',
      );
      controller.forfeitTurn();
      return;
    }

    // valid move
    if (s.turn == Player.x) {
      _playXSound();
    } else {
      _playOSound();
    }

    setState(() {
      tileOpacities[index] = 1.0;
      // deterministic art to match both devices
      tileImages[index] = s.turn == Player.x
          ? xImages[index % xImages.length]
          : oImages[index % oImages.length];
    });
    _fadeTileLater(index);

    controller.play(index);
  }

  void _onPressReset() {
    // Only visible when s.ended; controller.reset() is async void by design
    setState(() {
      statusTextMessage = 'Resetting…';
      statusImagePath = null;
      statusOpacity = 1.0;
    });
    controller.reset();
    // Snapshot listener will clear tiles when the board becomes empty.
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final s = controller.value;
        final isReady = controller.isReady;
        final me = controller.localPlayer;
        final isMyTurn = (me != null && me == s.turn);
        final isXTurn = s.turn == Player.x;

        // Turn banner: derived ONLY from state (no shared opacity flags)
        final showBanner = isReady && isMyTurn;

        final screenWidth = MediaQuery.of(context).size.width;
        final boardSize = screenWidth * 0.90;
        final tileSize = boardSize / 3;
        final safeTop = MediaQuery.of(context).padding.top;

        final showReset = s.ended; // Option A: only after end

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
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  SizedBox(height: screenWidth * 0.02),

                  // Turn banner (never blocked by status messages)
                  AnimatedOpacity(
                    opacity: showBanner ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeInOut,
                    child: Image.asset(
                      isXTurn ? 'assets/images/your_move_x.png' : 'assets/images/your_move_o.png',
                      height: screenWidth * 0.08,
                    ),
                  ),

                  SizedBox(height: screenWidth * 0.02),

                  // Status area: image OR persistent text
                  AnimatedOpacity(
                    opacity: (statusImagePath != null || statusTextMessage != null) ? statusOpacity : 0.0,
                    duration: Duration(milliseconds: textVisibleDuration * 2),
                    curve: Curves.ease,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Builder(
                        builder: (_) {
                          if (statusImagePath != null) {
                            return Image.asset(statusImagePath!, height: screenWidth * 0.08);
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
                          return SizedBox(height: screenWidth * 0.08);
                        },
                      ),
                    ),
                  ),

                  SizedBox(height: screenWidth * 0.02),

                  // Board
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

                  SizedBox(height: screenWidth * 0.03),

                  if (showReset)
                    PaperButton(
                      onTap: _onPressReset,
                      child: Image.asset('assets/images/reset.png', height: screenWidth * 0.1),
                    ),
                ],
              ),
            ),

            // Waiting overlay until both players join — blocks taps
            if (!isReady)
              Positioned.fill(
                child: AbsorbPointer(
                  absorbing: true,
                  child: Container(
                    color: Colors.black.withOpacity(0.15),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          SizedBox(height: 8),
                          CircularProgressIndicator(),
                          SizedBox(height: 12),
                          Text(
                            'Waiting for the other player to join…',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 2, color: Colors.black45)],
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
