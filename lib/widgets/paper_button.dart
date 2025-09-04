import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PaperButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const PaperButton({
    super.key,
    required this.child,
    required this.onTap,
  });

  @override
  State<PaperButton> createState() => _PaperButtonState();
}

class _PaperButtonState extends State<PaperButton>
    with SingleTickerProviderStateMixin {
  double _scale = 1.0;
  bool _pressed = false;

  void _onTapDown(TapDownDetails details) {
    setState(() {
      _scale = 0.9; // shrink a bit
      _pressed = true; // fade
    });
  }

  void _onTapUp(TapUpDetails details) {
    setState(() {
      _scale = 1.0;
      _pressed = false;
    });
    HapticFeedback.lightImpact(); // vibration feedback
    widget.onTap();
  }

  void _onTapCancel() {
    setState(() {
      _scale = 1.0;
      _pressed = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: AnimatedOpacity(
          opacity: _pressed ? 0.6 : 1.0,
          duration: const Duration(milliseconds: 120),
          child: widget.child,
        ),
      ),
    );
  }
}
