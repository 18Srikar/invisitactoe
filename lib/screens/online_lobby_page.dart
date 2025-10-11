// lib/screens/online_lobby_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:invisitactoe/widgets/paper_button.dart';
import 'package:invisitactoe/widgets/background_manager.dart';
import 'package:invisitactoe/game_logic/online_controller.dart';
import 'package:invisitactoe/screens/online_match_page.dart';

class OnlineLobbyPage extends StatefulWidget {
  const OnlineLobbyPage({super.key});

  @override
  State<OnlineLobbyPage> createState() => _OnlineLobbyPageState();
}

class _OnlineLobbyPageState extends State<OnlineLobbyPage> with SingleTickerProviderStateMixin {
  static const int _codeLen = 6;

  String? shareCode; // not rendered (avoids layout shift)
  bool busy = false;

  final joinCtrl = TextEditingController();
  final _focus = FocusNode();

  // caret blink
  Timer? _caretTimer;
  bool _caretOn = true;

  bool _assetsPrecached = false;

  // ---- Jitter (same style as HomePage) ----
  final _rnd = Random();
  late Timer _jitterTimer;
  double _createDX = 0, _createDY = 0;
  double _joinDX = 0, _joinDY = 0; // jitters ONLY when code length == 6

  // ---- Shake animation for Join button ----
  late final AnimationController _shake;
  late final Animation<double> _shakeOffset; // pixels left-right

  @override
  void initState() {
    super.initState();

    // Uppercase mapping for glyphs + react to length changes (to gate join jitter)
    joinCtrl.addListener(() {
      final up = joinCtrl.text.toUpperCase();
      if (up != joinCtrl.text) {
        final sel = joinCtrl.selection;
        joinCtrl.value = TextEditingValue(text: up, selection: sel);
      }
      setState(() {}); // refresh glyph/caret & join jitter gating
    });

    _caretTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _caretOn = !_caretOn);
    });

    // Jitter timer — create always jitters; join jitters only when length==6 and not busy
    _jitterTimer = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      final canJoinJitter = !busy && joinCtrl.text.length == _codeLen;
      setState(() {
        _createDX = _rnd.nextDouble() * 4 - 2;
        _createDY = _rnd.nextDouble() * 4 - 2;

        if (canJoinJitter) {
          _joinDX = -_createDX;                // mirrored X
          _joinDY = _rnd.nextDouble() * 4 - 2; // independent Y
        } else {
          _joinDX = 0;
          _joinDY = 0;
        }
      });
    });

    // Shake controller for Join button (used on wrong code / failure)
    _shake = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
    _shakeOffset = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -8), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -8, end: 8), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 8, end: -6), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -6, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _shake, curve: Curves.easeInOut));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_assetsPrecached) return;
    _assetsPrecached = true;

    // Pre-cache heavier overlay assets so the post-it opens cleanly
    final ctx = context;
    Future.microtask(() async {
      final assets = const [
        AssetImage('assets/images/postit_code_1.jpg'),
        AssetImage('assets/images/postit_code_2.jpg'),
        AssetImage('assets/images/share_code.png'),
        AssetImage('assets/images/copy.png'),
        AssetImage('assets/images/ok.png'),
        AssetImage('assets/images/enter_code_here.png'),
        AssetImage('assets/images/caret.png'),
        AssetImage('assets/images/dot1.png'),
        AssetImage('assets/images/dot2.png'),
        AssetImage('assets/images/dot3.png'),
        AssetImage('assets/images/create_room.png'),
        AssetImage('assets/images/join_room.png'),
        AssetImage('assets/images/back_arrow_handwritten.png'),
      ];
      for (final a in assets) {
        try { await precacheImage(a, ctx); } catch (_) {}
      }
    });
  }

  @override
  void dispose() {
    _caretTimer?.cancel();
    _jitterTimer.cancel();
    _shake.dispose();
    _focus.dispose();
    joinCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureAuthed() async {
    final auth = FirebaseAuth.instance;
    if (auth.currentUser == null) {
      await auth.signInAnonymously();
    }
  }

  Future<void> _createRoomFlow() async {
    setState(() { busy = true; });
    late final OnlineController controller;
    try {
      await _ensureAuthed();
      final (c, code) = await OnlineController.createRoom();
      controller = c;
      shareCode = code; // not rendered

      if (!mounted) return;
      final bool proceed = await _showShareOverlay(code); // only OK returns true
      if (!mounted) return;

      if (!proceed) {
        // User canceled (outside/back) → DON'T navigate. Clean up the room.
        try { await controller.leave(); } catch (_) {}
        controller.dispose();
        setState(() { shareCode = null; joinCtrl.clear(); });
        return;
      }

      // OK pressed → go to the match
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineMatchPage(title: 'Online', controller: controller),
        ),
      );

      if (!mounted) return;
      setState(() { shareCode = null; joinCtrl.clear(); });
    } finally {
      if (mounted) setState(() { busy = false; });
    }
  }

  Future<void> _joinRoomFlow() async {
    final code = joinCtrl.text.trim().toUpperCase();
    if (code.length != _codeLen) {
      _bumpJoin(); // not enough valid chars
      return;
    }

    setState(() { busy = true; });
    try {
      await _ensureAuthed();
      final controller = await OnlineController.joinWithCode(code);

      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => OnlineMatchPage(title: 'Online', controller: controller),
        ),
      );

      if (!mounted) return;
      setState(() { shareCode = null; joinCtrl.clear(); });
    } catch (_) {
      // Wrong code / room not found / full → shake + vibrate
      _bumpJoin();
    } finally {
      if (mounted) setState(() { busy = false; });
    }
  }

void _bumpJoin() {
  HapticFeedback.vibrate();

  // 🔽 ensure the hidden TextField is focused AND the keyboard is visible
  if (!_focus.hasFocus) {
    FocusScope.of(context).requestFocus(_focus);
    // Give the framework a beat to attach focus, then show the keyboard
    Future.microtask(() {
      SystemChannels.textInput.invokeMethod('TextInput.show');
    });
  } else {
    // It already has focus (common after back gesture) → force-show IME
    SystemChannels.textInput.invokeMethod('TextInput.show');
  }

  if (_shake.status == AnimationStatus.forward || _shake.status == AnimationStatus.reverse) {
    _shake.stop();
  }
  _shake.forward(from: 0);
}


  // Returns true only when user taps OK. Back/outside => false.
  Future<bool> _showShareOverlay(String code) async {
    final rnd = Random.secure();
    final postIts = [
      'assets/images/postit_code_1.jpg',
      'assets/images/postit_code_2.jpg',
    ];
    final chosen = postIts[rnd.nextInt(postIts.length)];

    final result = await showGeneralDialog<bool>(
      context: context,
      barrierLabel: 'share',
      barrierDismissible: true, // back/outside -> null
      barrierColor: Colors.black.withOpacity(0.35),
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogCtx, __, ___) {
        return Center(
          child: _ShareCodeCard(
            code: code,
            postItAsset: chosen,
            onCopy: () async {
              await Clipboard.setData(ClipboardData(text: code));
              HapticFeedback.selectionClick();
            },
            onProceed: () => Navigator.of(dialogCtx).pop(true),   // ONLY this proceeds
            onCancel:  () => Navigator.of(dialogCtx).pop(false),
          ),
        );
      },
    );

    return result == true; // treat null/false as cancel
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;
    final screenW = MediaQuery.of(context).size.width;

    final buttonH = screenW * 0.10;
    final maxW = 560.0;

    // Reserve space for loader always → no layout shift when busy toggles
    final double busyH = (screenW * 0.06);

    return Scaffold(
      resizeToAvoidBottomInset: false, // background stays static
      body: Stack(
        children: [
          // Background (static)
          Positioned.fill(
            child: Hero(
              tag: '__notebook_bg__',
              child: Image.asset(BackgroundManager.current, fit: BoxFit.cover),
            ),
          ),

          // Back
          Positioned(
            top: safeTop + 12,
            left: 25,
            child: PaperButton(
              onTap: () => Navigator.pop(context),
              child: Image.asset('assets/images/back_arrow_handwritten.png', width: 35, height: 35),
            ),
          ),

          // Content
          Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxW),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: screenW * 0.02),

                    // Create room (hand-drawn) — always jitter
                    PaperButton(
                      onTap: () { if (!busy) _createRoomFlow(); },
                      child: Transform.translate(
                        offset: Offset(_createDX, _createDY),
                        child: Image.asset('assets/images/create_room.png', height: buttonH/1.5),
                      ),
                    ),

                    SizedBox(height: screenW * 0.1),

                    // Invisible TextField + custom glyph/caret
                    GestureDetector(
                      onTap: () => FocusScope.of(context).requestFocus(_focus),
                      child: _CodeInputArea(
                        controller: joinCtrl,
                        focusNode: _focus,
                        caretOn: _caretOn,
                        height: (screenW * 0.09).clamp(48.0, 72.0),
                        maxLen: _codeLen,
                      ),
                    ),

                    SizedBox(height: screenW * 0.1),

                    // Join (hand-drawn)
                    // - Jitters ONLY when code length==6 (from _joinDX/_joinDY)
                    // - Shakes on invalid with _shakeOffset (composed with jitter)
                    PaperButton(
                      onTap: () { if (!busy) _joinRoomFlow(); },
                      child: AnimatedBuilder(
                        animation: _shake,
                        builder: (_, child) => Transform.translate(
                          offset: Offset(_joinDX + _shakeOffset.value, _joinDY),
                          child: child,
                        ),
                        child: Image.asset('assets/images/join_room.png', height: buttonH/1.5),
                      ),
                    ),

                    SizedBox(height: screenW * 0.1),

                    // Reserved loader area (no add/remove → no layout shift)
                    SizedBox(
                      height: busyH,
                      child: AnimatedOpacity(
                        opacity: busy ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 150),
                        curve: Curves.easeInOut,
                        child: const _BusyDotsFixed(dotSize: 5, gap: 4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A transparent TextField layered with a glyph-rendered preview + hand-drawn caret.
/// - Native text & cursor are hidden; we render glyph sprites + caret.
/// - Placeholder centers; caret overlays without pushing layout.
/// - Caret only blinks when keyboard is open.
/// - Input capped at [maxLen] and only allows A-H J K M N P-Z + 2-9.
class _CodeInputArea extends StatelessWidget {
  const _CodeInputArea({
    required this.controller,
    required this.focusNode,
    required this.caretOn,
    required this.height,
    required this.maxLen,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool caretOn;
  final double height;
  final int maxLen;

  @override
  Widget build(BuildContext context) {
    final text = controller.text.toUpperCase();
    final glyphH = height * 0.65;
    const spacing = 1.0;
    const double placeholderOpacity = 0.4;

    final keyboardVisible = MediaQuery.of(context).viewInsets.bottom > 0;
    final bool showCaret = keyboardVisible && focusNode.hasFocus && caretOn;

    return SizedBox(
      height: height,
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
Align(
  alignment: Alignment.center,
  child: Builder(
    builder: (_) {
      if (text.isEmpty) {
        return Center(
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Opacity(
                opacity: placeholderOpacity,
                child: Image.asset(
                  'assets/images/enter_code_here.png',
                  height: glyphH * 0.75,
                ),
              ),
              if (showCaret)
                Positioned(
                  left: -30,
                  child: Opacity(
                    opacity: placeholderOpacity,
                    child: Image.asset(
                      'assets/images/caret.png',
                      height: glyphH,
                    ),
                  ),
                ),
            ],
          ),
        );
      }

final caretH = glyphH ;
// Pick a stable caret width. If your caret is ~1:4 (w:h), 0.22–0.26*h looks right.
final caretW = caretH ;

return Row(
  mainAxisSize: MainAxisSize.min,
  mainAxisAlignment: MainAxisAlignment.center,
  children: [
    _GlyphRow(text: text, height: glyphH, spacing: spacing),
    const SizedBox(width: spacing),
    SizedBox(
      height: caretH,
      width: caretW,
      child: AnimatedOpacity(
        opacity: showCaret ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeInOut,
        child: FittedBox(
          fit: BoxFit.contain,
          child: Image.asset('assets/images/caret.png'),
        ),
      ),
    ),
  ],
);

    },
  ),
),

          TextField(
            controller: controller,
            focusNode: focusNode,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.done,
            showCursor: false,
            enableInteractiveSelection: false,
            contextMenuBuilder: (context, state) => const SizedBox.shrink(), // no copy/paste menu
            magnifierConfiguration: TextMagnifierConfiguration.disabled,
            onSubmitted: (_) => FocusScope.of(context).unfocus(),
            style: const TextStyle(color: Colors.transparent, height: 1.0),
            cursorColor: Colors.transparent,
            decoration: const InputDecoration(
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            ),
            inputFormatters: [
              // Allow only A-H J K M N P-Z and digits 2-9 (case-insensitive)
              FilteringTextInputFormatter.allow(
                RegExp(r'[A-HJKMNP-Z2-9]', caseSensitive: false),
              ),
              LengthLimitingTextInputFormatter(maxLen), // cap at 6 valid chars
            ],
          ),
        ],
      ),
    );
  }
}

/// Renders a string using glyph sprites.
class _GlyphRow extends StatelessWidget {
  const _GlyphRow({
    required this.text,
    required this.height,
    this.spacing = 5,
  });

  final String text;
  final double height;
  final double spacing;

  String? _assetFor(String ch) {
    final c = ch.toUpperCase();
    if (RegExp(r'^[A-Z]$').hasMatch(c)) return 'assets/images/glyphs/glyph_$c.png';
    if (RegExp(r'^[2-9]$').hasMatch(c)) return 'assets/images/glyphs/glyph_$c.png';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final chars = text.trim().toUpperCase().split('');
    final widgets = <Widget>[];
    for (int i = 0; i < chars.length; i++) {
      final a = _assetFor(chars[i]);
      if (a != null) {
        widgets.add(Image.asset(a, height: height));
        if (i < chars.length - 1) widgets.add(SizedBox(width: spacing));
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }
}

/// Hand-drawn share overlay using a random post-it image and glyph code.
class _ShareCodeCard extends StatelessWidget {
  const _ShareCodeCard({
    required this.code,
    required this.postItAsset,
    required this.onCopy,
    required this.onProceed,
    required this.onCancel,
  });

  final String code;
  final String postItAsset;
  final VoidCallback onCopy;
  final VoidCallback onProceed;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;
    final cardW = (screenW * 0.82).clamp(320.0, 560.0);
    final headerH = screenW * 0.08;

    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Container(
          width: cardW,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Image.asset(postItAsset, width: cardW, fit: BoxFit.contain),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/share_code.png', height: headerH),
                    SizedBox(height: screenW * 0.11),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: _GlyphRow(text: code, height: screenW * 0.11, spacing: 8),
                    ),
                    SizedBox(height: screenW * 0.11),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PaperButton(
                          onTap: onCopy,
                          child: Image.asset('assets/images/copy.png', height: screenW * 0.16),
                        ),
                        SizedBox(width: screenW * 0.2),
                        PaperButton(
                          onTap: onProceed,
                          child: Image.asset('assets/images/ok.png', height: screenW * 0.16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Three-dot indicator with fixed canvas (no layout shift) and centered dots.
class _BusyDotsFixed extends StatefulWidget {
  const _BusyDotsFixed({this.dotSize = 8, this.gap = 5});
  final double dotSize;
  final double gap;

  @override
  State<_BusyDotsFixed> createState() => _BusyDotsFixedState();
}

class _BusyDotsFixedState extends State<_BusyDotsFixed> {
  int _count = 1;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (!mounted) return;
      setState(() => _count = _count % 3 + 1);
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalWidth = widget.dotSize * 3 + widget.gap * 2;
    final totalHeight = widget.dotSize;

    // dot 2 centered; 1 and 3 symmetric
    final centerX = totalWidth / 2 - widget.dotSize / 2;
    final x1 = centerX - (widget.dotSize + widget.gap);
    final x2 = centerX;
    final x3 = centerX + (widget.dotSize + widget.gap);

    Widget dot(int index, double x) {
      final visible = index <= _count;
      return Positioned(
        left: x,
        top: 0,
        width: widget.dotSize,
        height: widget.dotSize,
        child: AnimatedOpacity(
          opacity: visible ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeInOut,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Image.asset('assets/images/dot$index.png',),
          ),
        ),
      );
    }

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [dot(1, x1), dot(2, x2), dot(3, x3)],
      ),
    );
  }
}