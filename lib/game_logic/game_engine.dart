// lib/game_logic/game_engine.dart
enum Cell { empty, x, o }
enum Player { x, o }

class GameState {
  final List<Cell> board;   // length 9
  final Player turn;        // whose turn it is
  final bool ended;         // game over?
  final Player? winner;     // null = none/draw
  final int? lastMove;      // last index played (0..8)

  const GameState({
    required this.board,
    required this.turn,
    required this.ended,
    this.winner,
    this.lastMove,
  });

  GameState copyWith({
    List<Cell>? board,
    Player? turn,
    bool? ended,
    Player? winner,
    int? lastMove,
  }) {
    return GameState(
      board: board ?? this.board,
      turn: turn ?? this.turn,
      ended: ended ?? this.ended,
      winner: winner,
      lastMove: lastMove,
    );
  }

  static GameState initial() => GameState(
        board: List<Cell>.filled(9, Cell.empty),
        turn: Player.x,   // X always starts
        ended: false,
      );
}

class GameEngine {
  static const wins = [
    [0,1,2],[3,4,5],[6,7,8],
    [0,3,6],[1,4,7],[2,5,8],
    [0,4,8],[2,4,6],
  ];

  static Player? winnerOn(List<Cell> b) {
    for (final w in wins) {
      final a = b[w[0]], c = b[w[1]], d = b[w[2]];
      if (a != Cell.empty && a == c && c == d) {
        return a == Cell.x ? Player.x : Player.o;
      }
    }
    return null;
  }

  static bool isFull(List<Cell> b) => !b.contains(Cell.empty);

  /// Apply a move at [i] for the current [turn]. If illegal/ended, returns [s] unchanged.
  static GameState place(GameState s, int i) {
    if (s.ended || s.board[i] != Cell.empty) return s;

    final next = List<Cell>.from(s.board);
    next[i] = s.turn == Player.x ? Cell.x : Cell.o;

    final w = winnerOn(next);
    final ended = w != null || isFull(next);
    final nextTurn = s.turn == Player.x ? Player.o : Player.x;

    return s.copyWith(
      board: next,
      ended: ended,
      winner: w,
      lastMove: i,
      turn: ended ? s.turn : nextTurn,
    );
  }
}
