// lib/widgets/paper_jitter.dart
import 'dart:async';
import 'dart:math';
import 'package:flutter/widgets.dart';

class PaperJitter extends StatefulWidget {
  const PaperJitter({
    super.key,
    required this.active,
    required this.child,
    this.amplitude = 1.5,              // ~±2 px like your other buttons
    this.period = const Duration(milliseconds: 300),
  });

  final bool active;
  final Widget child;
  final double amplitude;
  final Duration period;

  @override
  State<PaperJitter> createState() => _PaperJitterState();
}

class _PaperJitterState extends State<PaperJitter> {
  final _rnd = Random();
  Timer? _t;
  double _dx = 0, _dy = 0;

  @override
  void initState() {
    super.initState();
    _maybeStart();
  }

  @override
  void didUpdateWidget(PaperJitter old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active || old.period != widget.period || old.amplitude != widget.amplitude) {
      _stop();
      _maybeStart();
    }
  }

  @override
  void dispose() {
    _stop();
    super.dispose();
  }

  void _maybeStart() {
    if (!widget.active) {
      setState(() { _dx = 0; _dy = 0; });
      return;
    }
    _t = Timer.periodic(widget.period, (_) {
      if (!mounted) return;
      setState(() {
        _dx = _rnd.nextDouble() * (widget.amplitude * 2) - widget.amplitude;
        _dy = _rnd.nextDouble() * (widget.amplitude * 2) - widget.amplitude;
      });
    });
  }

  void _stop() {
    _t?.cancel();
    _t = null;
    _dx = 0; _dy = 0;
  }

  @override
  Widget build(BuildContext context) {
    // Transform only -> no layout shift
    return Transform.translate(offset: Offset(_dx, _dy), child: widget.child);
  }
}
