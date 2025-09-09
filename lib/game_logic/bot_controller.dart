// lib/game_logic/bot_controller.dart
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'game_engine.dart';

class BotController extends ChangeNotifier implements ValueListenable<GameState> {
  GameState _state = GameState.initial();
  @override GameState get value => _state;

  bool _busy = false; // prevent overlapping AI turns

  void reset() {
    _state = GameState.initial();
    _busy = false;
    notifyListeners();
  }

  /// Human (X) attempts to play at [index].
  bool playHuman(int index) {
    if (_busy || _state.ended || _state.turn != Player.x) return false;
    if (_state.board[index] != Cell.empty) return false;

    final afterHuman = GameEngine.place(_state, index);
    if (identical(afterHuman, _state)) return false;

    _state = afterHuman;
    notifyListeners();

    if (!_state.ended) {
      _aiTurn();
    }
    return true;
  }

  /// Human made an invalid move -> forfeits turn, AI moves.
  void forfeitHumanTurnAndAiMove() {
    if (_busy || _state.ended || _state.turn != Player.x) return;
    _state = _state.copyWith(turn: Player.o);
    notifyListeners();
    _aiTurn();
  }

  Future<void> _aiTurn() async {
    _busy = true;
    await Future<void>.delayed(const Duration(milliseconds: 500));

    final idx = _bestMove(_state.board);
    final afterAi = GameEngine.place(_state, idx);
    _state = afterAi;
    _busy = false;
    notifyListeners();
  }

  int _bestMove(List<Cell> board) {
    final b = board.toList();
    int bestScore = -9999;
    int bestIdx = -1;

    for (int i = 0; i < 9; i++) {
      if (b[i] != Cell.empty) continue;
      b[i] = Cell.o; // AI plays O
      final score = _minimax(b, maximizing: false, depth: 0);
      b[i] = Cell.empty;
      if (score > bestScore) {
        bestScore = score; bestIdx = i;
      }
    }
    return bestIdx;
  }

  int _scoreWinner(List<Cell> b, int depth) {
    final w = GameEngine.winnerOn(b);
    if (w == null) return 0;
    return w == Player.o ? (10 - depth) : (-10 + depth);
  }

  int _minimax(List<Cell> b, {required bool maximizing, required int depth}) {
    final w = GameEngine.winnerOn(b);
    if (w != null) return _scoreWinner(b, depth);
    if (GameEngine.isFull(b)) return 0;

    if (maximizing) {
      int best = -9999;
      for (int i = 0; i < 9; i++) {
        if (b[i] != Cell.empty) continue;
        b[i] = Cell.o;
        best = math.max(best, _minimax(b, maximizing: false, depth: depth + 1));
        b[i] = Cell.empty;
      }
      return best;
    } else {
      int best = 9999;
      for (int i = 0; i < 9; i++) {
        if (b[i] != Cell.empty) continue;
        b[i] = Cell.x;
        best = math.min(best, _minimax(b, maximizing: true, depth: depth + 1));
        b[i] = Cell.empty;
      }
      return best;
    }
  }
}
