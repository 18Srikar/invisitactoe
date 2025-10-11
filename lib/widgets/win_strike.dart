// lib/widgets/win_strike.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:invisitactoe/game_logic/game_engine.dart';

enum _StrikeKind { row, col, diagMain, diagAnti }

class _StrikeInfo {
  final _StrikeKind kind;
  final int index; // 0..2 for row/col; ignored for diags
  const _StrikeInfo(this.kind, this.index);
}

// Public: find a winning line (or null)
_StrikeInfo? findWin(List<Cell> b) {
  // rows
  for (var r = 0; r < 3; r++) {
    final i = r * 3;
    if (b[i] != Cell.empty && b[i] == b[i + 1] && b[i] == b[i + 2]) {
      return _StrikeInfo(_StrikeKind.row, r);
    }
  }
  // cols
  for (var c = 0; c < 3; c++) {
    if (b[c] != Cell.empty && b[c] == b[c + 3] && b[c] == b[c + 6]) {
      return _StrikeInfo(_StrikeKind.col, c);
    }
  }
  // diags
  if (b[0] != Cell.empty && b[0] == b[4] && b[0] == b[8]) {
    return const _StrikeInfo(_StrikeKind.diagMain, 0);
  }
  if (b[2] != Cell.empty && b[2] == b[4] && b[2] == b[6]) {
    return const _StrikeInfo(_StrikeKind.diagAnti, 0);
  }
  return null;
}

/// Draws a single handwritten strike line (one PNG, rotated as needed),
/// placed with precise pixel offsets so it lines up with any row/column,
/// and fades in to match tile reveal timing.
class WinStrike extends StatelessWidget {
  const WinStrike({
    super.key,
    required this.info,
    required this.boardSize,
    this.lineAsset = 'assets/images/strike.png',
    this.durationMs = 750,                  // ← match your textVisibleDuration
    this.curve = Curves.linear,             // tiles use default (linear); keep it consistent
  });

  final _StrikeInfo info;
  final double boardSize;
  final String lineAsset;
  final int durationMs;
  final Curve curve;

  @override
  Widget build(BuildContext context) {
    final lineW = boardSize * 0.90;         // span most of board
    final tile  = boardSize / 3.0;          // cell size

    Offset offsetForRow(int r) => Offset(0, (r - 1) * tile);
    Offset offsetForCol(int c) => Offset((c - 1) * tile, 0);

    Widget _strike({required double angle, required Offset offset}) {
      final child = Positioned.fill(
        child: Center(
          child: Transform.translate(
            offset: offset,
            child: Transform.rotate(
              angle: angle,
              child: Image.asset(lineAsset, width: lineW),
            ),
          ),
        ),
      );

      // Fade in once when inserted; no layout shift (opacity only)
      return TweenAnimationBuilder<double>(
        key: ValueKey('${info.kind}-${info.index}'),
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: durationMs),
        curve: curve,
        builder: (context, value, _) => Opacity(opacity: value, child: child),
      );
    }

    switch (info.kind) {
      case _StrikeKind.row:
        return _strike(angle: 0,        offset: offsetForRow(info.index));
      case _StrikeKind.col:
        return _strike(angle: pi / 2,   offset: offsetForCol(info.index));
      case _StrikeKind.diagMain:        // TL → BR
        return _strike(angle: pi / 4,   offset: Offset.zero);
      case _StrikeKind.diagAnti:        // TR → BL
        return _strike(angle: -pi / 4,  offset: Offset.zero);
    }
  }
}
