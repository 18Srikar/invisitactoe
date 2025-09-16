import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Hand-drawn "waiting..." banner with animated dots: 1 → 2 → 3 → reset → repeat.
/// Pass a phrase image (no dots) and three unique dot PNGs (dot1, dot2, dot3).
class EllipsisBanner extends StatefulWidget {
  final String phraseAsset;
  final List<String> dotAssets; // exactly 3
  final double height;          // target height for the phrase image
  final Duration step;          // time per dot step (e.g., 300ms)
  final double dotScale;        // dot height relative to phrase height (e.g., 0.20)
  final double spacing;         // px between dots
  final bool dotsBelow;         // false = inline to the right; true = centered below

  const EllipsisBanner({
    super.key,
    required this.phraseAsset,
    required this.dotAssets,
    this.height = 44,
    this.step = const Duration(milliseconds: 300),
    this.dotScale = 0.20,
    this.spacing = 6,
    this.dotsBelow = false,
  });

  @override
  State<EllipsisBanner> createState() => _EllipsisBannerState();
}

class _EllipsisBannerState extends State<EllipsisBanner> {
  int _count = 0; // 0..3 (0 = no dots, 1..3 = number of dots showing)
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(widget.step, (_) {
      if (!mounted) return;
      setState(() => _count = (_count + 1) % 4); // 0 → 1 → 2 → 3 → 0 …
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

@override
Widget build(BuildContext context) {
  final dotH = max(1.0, widget.height * widget.dotScale);
  final visibleDots = List<Widget>.generate(_count.clamp(0, 3), (i) {
    final r = Random(i * 97 + 13);
    final rot = (r.nextDouble() * 2 - 1) * 1.5 * pi / 180;
    final dx = (r.nextDouble() * 2 - 1) * 0.6;
    final dy = (r.nextDouble() * 2 - 1) * 0.6;

    return Padding(
      padding: EdgeInsets.only(right: (i == _count - 1) ? 0 : widget.spacing),
      child: Transform.translate(
        offset: Offset(dx, dy),
        child: Transform.rotate(
          angle: rot,
          child: Image.asset(widget.dotAssets[i], height: dotH, filterQuality: FilterQuality.high),
        ),
      ),
    );
  });

  // Reserve a fixed lane for up to 3 dots so the phrase position never shifts.
  final maxDotsWidth = (3 * dotH) + (2 * widget.spacing);

  final phrase = Image.asset(
    widget.phraseAsset,
    height: widget.height,
    filterQuality: FilterQuality.high,
  );

  if (widget.dotsBelow) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        phrase,
        const SizedBox(height: 6),
        SizedBox(
          width: maxDotsWidth,
          child: Row(mainAxisSize: MainAxisSize.min, children: visibleDots),
        ),
      ],
    );
  } else {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        phrase,
        const SizedBox(width: 8),
        SizedBox(
          width: maxDotsWidth,
          child: Row(mainAxisSize: MainAxisSize.min, children: visibleDots),
        ),
      ],
    );
  }
}

}
