// lib/game_logic/two_local_controller.dart
import 'controller.dart';
import 'game_engine.dart';

class TwoLocalController extends GameController {
  @override
  void play(int index) {
    final next = GameEngine.place(value, index);
    if (!identical(next, value)) setState(next);
  }

  /// For invalid move penalty: lose the current turn.
  void forfeitTurn() {
    if (value.ended) return;
    final nextTurn = value.turn == Player.x ? Player.o : Player.x;
    setState(value.copyWith(turn: nextTurn));
  }
}
