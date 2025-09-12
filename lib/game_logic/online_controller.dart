import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'controller.dart';
import 'game_engine.dart';

// Converters between your enums and Firestore-friendly primitives
Cell _cellFromInt(int v) => v == 1 ? Cell.x : v == 2 ? Cell.o : Cell.empty;
int _cellToInt(Cell c) => c == Cell.x ? 1 : c == Cell.o ? 2 : 0;
Player _playerFromStr(String s) => s == 'o' ? Player.o : Player.x;
String _playerToStr(Player p) => p == Player.o ? 'o' : 'x';

class OnlineController extends GameController {
  OnlineController._(this._gameRef, this._myUid) {
    _sub = _gameRef.snapshots().listen(_onRemote);
  }

  final DocumentReference<Map<String, dynamic>> _gameRef;
  final String _myUid;
  late final StreamSubscription _sub;

  String? _xUid;
  String? _oUid;

  String? _systemMessage;     // one-shot system notice
  String? _lastLeftBy;        // to avoid repeating the same message

  /// Who am I on this device?
  Player? get _myRoleOrNull {
    if (_xUid == _myUid) return Player.x;
    if (_oUid == _myUid) return Player.o;
    return null;
  }

  @override
  Player? get localPlayer => _myRoleOrNull;

  @override
  bool get isReady => _xUid != null && _oUid != null;

  @override
  String? get systemMessage => _systemMessage;

  @override
  void clearSystemMessage() {
    _systemMessage = null;
  }

  /// Creator: make a new room and get a code to share
  static Future<(OnlineController, String)> createRoom() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = FirebaseFirestore.instance.collection('games').doc();
    final code = _code(6);

    await doc.set({
      'code': code,
      'xUid': uid,
      'oUid': null,
      'board': List<int>.filled(9, 0),
      'turn': 'x',
      'ended': false,
      'winner': null,
      'lastMove': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'randomizedStart': false,
      'leftBy': null,
    });

    final c = OnlineController._(doc, uid);
    // Know our role immediately; still not "ready" until O joins
    c._xUid = uid;
    c.setState(GameState.initial()); // local initial state
    return (c, code);
  }

  /// Joiner: enter the code to sit as O (and coin-flip starting turn once)
  static Future<OnlineController> joinWithCode(String code) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final q = await FirebaseFirestore.instance
        .collection('games')
        .where('code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (q.docs.isEmpty) throw Exception('Room not found');
    final ref = q.docs.first.reference;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final d = snap.data()!;
      if (d['oUid'] != null) throw Exception('Room is full');

      final alreadyRandomized = d['randomizedStart'] == true;
      final String nextTurn = alreadyRandomized
          ? (d['turn'] as String)
          : (Random.secure().nextBool() ? 'x' : 'o');

      tx.update(ref, {
        'oUid': uid,
        'turn': nextTurn,
        'randomizedStart': true,
        'updatedAt': FieldValue.serverTimestamp(),
        'leftBy': null,
      });
    });

    final c = OnlineController._(ref, uid);
    // Know our role immediately; readiness flips true when X & O are both set by snapshot
    c._oUid = uid;
    return c; // state arrives via snapshot
  }

  @override
  void play(int index) async {
    // Local guards: no input until BOTH players are seated and it's my turn
    if (!isReady) return;
    if (value.ended || index < 0 || index > 8 || value.board[index] != Cell.empty) return;
    if (_myRoleOrNull == null || value.turn != _myRoleOrNull) return;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      final d = snap.data();
      if (d == null) return;

      // 🚫 Server-side guard: both seats must be present in the latest state
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      if (xUid == null || oUid == null) return;

      // Rebuild latest remote state to validate
      final s = GameState(
        board: (d['board'] as List).cast<int>().map(_cellFromInt).toList(),
        turn: _playerFromStr(d['turn'] as String),
        ended: d['ended'] as bool,
        winner: (d['winner'] as String?)?.let(_playerFromStr),
        lastMove: d['lastMove'] as int?,
      );

      if (s.ended || s.board[index] != Cell.empty) return;

      final next = GameEngine.place(s, index);

      tx.update(_gameRef, {
        'board': next.board.map(_cellToInt).toList(),
        'turn': _playerToStr(next.turn),
        'ended': next.ended,
        'winner': next.winner == null ? null : _playerToStr(next.winner!),
        'lastMove': next.lastMove,
        'updatedAt': FieldValue.serverTimestamp(),
        'leftBy': null,
      });
    });
  }

  /// On invalid move penalty: skip your turn.
  @override
  void forfeitTurn() async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      final d = snap.data();
      if (d == null) return;
      if (d['ended'] == true) return;

      final String turnStr = d['turn'] as String; // 'x' or 'o'
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;

      final String? turnUid = (turnStr == 'x') ? xUid : oUid;
      if (turnUid != _myUid) return;       // only mover can forfeit
      if (xUid == null || oUid == null) return; // wait until both seated

      final String nextTurn = (turnStr == 'x') ? 'o' : 'x';
      tx.update(_gameRef, {
        'turn': nextTurn,
        'lastMove': null,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  @override
  void reset() async {
    // Either player may reset only after game end (option A). Adjust if you want different.
    if (!value.ended) return;
    if (_myUid != _xUid && _myUid != _oUid) return;
    await _gameRef.update({
      'board': List<int>.filled(9, 0),
      'turn': 'x', // or Random.secure().nextBool() ? 'x' : 'o'
      'ended': false,
      'winner': null,
      'lastMove': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'leftBy': null,
      'randomizedStart': false,
    });
  }

  @override
  Future<void> leave() async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      final d = snap.data();
      if (d == null) return;

      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      final List<int> rawBoard = (d['board'] as List).cast<int>();
      final bool hasAnyMove = rawBoard.any((v) => v != 0);
      final bool ended = (d['ended'] as bool?) ?? false;

      final bool meIsX = xUid == _myUid;
      final bool meIsO = oUid == _myUid;

      // 1) Waiting room: only X present -> delete the room
      if (meIsX && oUid == null && !hasAnyMove && !ended) {
        tx.delete(_gameRef);
        return;
      }

      // 2) O leaves before game starts -> free seat, reset to X's turn
      if (meIsO && !hasAnyMove && !ended) {
        tx.update(_gameRef, {
          'oUid': null,
          'turn': 'x',
          'randomizedStart': false,
          'leftBy': _myUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        return;
      }

      // 3) In-progress (or even ended) -> mark forfeit end / note quitter
      if (!ended) {
        final winner = meIsX ? 'o' : 'x';
        tx.update(_gameRef, {
          'ended': true,
          'winner': winner,
          'leftBy': _myUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        tx.update(_gameRef, {
          'leftBy': _myUid,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }).catchError((_) {});
  }

  void _onRemote(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data();
    if (d == null) return;

    _xUid = d['xUid'] as String?;
    _oUid = d['oUid'] as String?;

    final gs = GameState(
      board: (d['board'] as List).cast<int>().map(_cellFromInt).toList(),
      turn: _playerFromStr(d['turn'] as String),
      ended: d['ended'] as bool,
      winner: (d['winner'] as String?)?.let(_playerFromStr),
      lastMove: d['lastMove'] as int?,
    );
    setState(gs); // notifies listeners

    // Detect opponent-left event and raise a one-shot system message
    final leftBy = d['leftBy'] as String?;
    if (leftBy != null && leftBy != _myUid && leftBy != _lastLeftBy) {
      _lastLeftBy = leftBy;

      final bool ended = (d['ended'] as bool?) ?? false;
      final hasAnyMove =
          ((d['board'] as List).cast<int>()).any((v) => v != 0);

      if (ended) {
        _systemMessage = 'Opponent left — you win by forfeit.';
      } else {
        _systemMessage = hasAnyMove
            ? 'Opponent left — game stopped.'
            : 'Opponent left — waiting for another player…';
      }
      notifyListeners(); // prompt UI to read systemMessage
    }
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  static String _code(int n) {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final r = Random.secure();
    return List.generate(n, (_) => chars[r.nextInt(chars.length)]).join();
  }
}

extension<T> on T? {
  R? let<R>(R Function(T v) f) => this == null ? null : f(this as T);
}
