// lib/game_logic/controller.dart
import 'package:flutter/foundation.dart';
import 'game_engine.dart';

abstract class GameController extends ChangeNotifier
    implements ValueListenable<GameState> {
  GameState _state = GameState.initial();

  @override
  GameState get value => _state;

  /// Who is "me" on this device? (null = local 2P / no identity)
  Player? get localPlayer => null;

  /// Ready means "both players seated" (always true for local mode).
  bool get isReady => true;

  /// Optional one-shot system notice for the UI (e.g., "Opponent left…").
  String? get systemMessage => null;

  /// UI should call this after showing the message, so it doesn’t repeat.
  void clearSystemMessage() {}

  /// Called when the game screen is closing. Default: no-op.
  Future<void> leave() async {}

  void reset() {
    _state = GameState.initial();
    notifyListeners();
  }

  @protected
  void setState(GameState s) {
    _state = s;
    notifyListeners();
  }

  void play(int index);
  void forfeitTurn();
}
