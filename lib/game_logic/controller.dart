// lib/game_logic/controller.dart
import 'package:flutter/foundation.dart';
import 'game_engine.dart';

abstract class GameController extends ChangeNotifier implements ValueListenable<GameState> {
  GameState _state = GameState.initial();
  @override GameState get value => _state;

  void reset() {
    _state = GameState.initial();
    notifyListeners();
  }

  @protected
  void setState(GameState s) {
    _state = s;
    notifyListeners();
  }

  /// Implement this to perform a move for the side-to-move.
  void play(int index);
}
