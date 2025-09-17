// lib/game_logic/online_controller.dart

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
  bool? _xReady;
  bool? _oReady;

  // String? _createdBy;
  String? _leftBy;            // who left (if any)

  String? _systemMessage;     // one-shot system notice
  String? _lastLeftBy;        // to avoid repeating the same message
  String? _penaltyBy;         // 'x' or 'o' — one-shot penalty marker

  bool? _pendingPresence;     // queue presence until we know our seat

  /// Who am I on this device?
  Player? get _myRoleOrNull {
    if (_xUid == _myUid) return Player.x;
    if (_oUid == _myUid) return Player.o;
    return null;
  }

  @override
  Player? get localPlayer => _myRoleOrNull;

  // Ready = both seats assigned AND both players present in this page
  @override
  bool get isReady =>
      _xUid != null &&
      _oUid != null &&
      _xReady == true &&
      _oReady == true;

  /// True if the game ended due to a player leaving
  bool get endedByLeave => _leftBy != null;

  /// One-shot penalty marker for UI ('x'|'o' or null)
  String? get penaltyBy => _penaltyBy;

  /// UI calls this after showing the penalty banner
  Future<void> ackPenalty() async {
    _penaltyBy = null;
    // best-effort clear on the doc so both sides stop showing it
    try {
      await _gameRef.update({'penaltyBy': null});
    } catch (_) {}
    notifyListeners();
  }

  @override
  String? get systemMessage => _systemMessage;

  @override
  void clearSystemMessage() {
    _systemMessage = null;
  }

  /// Creator: make a new room and get a code to share (seats empty; presence false)
  static Future<(OnlineController, String)> createRoom() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = FirebaseFirestore.instance.collection('games').doc();
    final code = _code(6);

    await doc.set({
      'code': code,
      'xUid': null,
      'oUid': null,
      'xReady': false,
      'oReady': false,
      'createdBy': uid,
      'board': List<int>.filled(9, 0),
      'turn': 'x', // placeholder; randomized at seating
      'ended': false,
      'winner': null,
      'lastMove': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'randomizedStart': false,
      'leftBy': null,
      'penaltyBy': null,
    });

    final c = OnlineController._(doc, uid);
    c.setState(GameState.initial());
    return (c, code);
  }

  /// Joiner: enter the code; transaction assigns BOTH seats randomly (once) and randomizes first turn.
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
      if (!snap.exists) throw Exception('Room closed');
      final d = snap.data()!;
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      final String creator = (d['createdBy'] as String?) ?? '';

      // Seats must be both empty to start; assign both seats & randomize turn ONCE
      if (xUid == null && oUid == null) {
        if (creator.isEmpty) throw Exception('Room corrupt (missing creator).');
        if (creator == uid) throw Exception('Open this room on another device to play.');

        final rng = Random.secure();
        final bool heads = rng.nextBool();
        final String seatX = heads ? creator : uid;
        final String seatO = heads ? uid : creator;
        final String nextTurn = rng.nextBool() ? 'x' : 'o';

        tx.update(ref, {
          'xUid': seatX,
          'oUid': seatO,
          'xReady': false,
          'oReady': false,
          'turn': nextTurn,
          'randomizedStart': true,
          'updatedAt': FieldValue.serverTimestamp(),
          'leftBy': null,
          'penaltyBy': null,
        });
      } else {
        // Any seat already taken => treat as full (no reseating/new joiners)
        throw Exception('Room is full');
      }
    });

    final c = OnlineController._(ref, uid);
    return c;
  }

  /// Call when entering/leaving the match page to mark presence.
  Future<void> setPresence(bool present) async {
    _pendingPresence = present;
    _tryApplyPresence();
  }

  void _tryApplyPresence() {
    if (_pendingPresence == null) return;
    final role = _myRoleOrNull;
    if (role == null) return; // wait until seats are known via snapshot
    final field = (role == Player.x) ? 'xReady' : 'oReady';
    final val = _pendingPresence!;
    _pendingPresence = null;
    _gameRef.update({
      field: val,
      'updatedAt': FieldValue.serverTimestamp(),
    }).catchError((_) {});
  }

  @override
  void play(int index) async {
    // Local guards
    if (!isReady) return;
    if (value.ended || index < 0 || index > 8 || value.board[index] != Cell.empty) return;
    if (_myRoleOrNull == null || value.turn != _myRoleOrNull) return;

    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      final d = snap.data();
      if (d == null) return;

      // Seats + readiness must be present
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      final bool xReady = (d['xReady'] as bool?) ?? false;
      final bool oReady = (d['oReady'] as bool?) ?? false;
      if (xUid == null || oUid == null || !xReady || !oReady) return;

      // Only current turn's UID may write the move
      final String turnStr = d['turn'] as String; // 'x'|'o'
      final String? turnUid = (turnStr == 'x') ? xUid : oUid;
      if (turnUid != _myUid) return;

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
        // no penalty in normal move
        'penaltyBy': null,
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

      final bool xReady = (d['xReady'] as bool?) ?? false;
      final bool oReady = (d['oReady'] as bool?) ?? false;
      if (!xReady || !oReady) return;

      final String turnStr = d['turn'] as String; // 'x' or 'o'
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;

      final String? turnUid = (turnStr == 'x') ? xUid : oUid;
      if (turnUid != _myUid) return; // only mover can forfeit

      final String nextTurn = (turnStr == 'x') ? 'o' : 'x';
      tx.update(_gameRef, {
        'turn': nextTurn,
        'lastMove': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'penaltyBy': turnStr, // <- announce penalty (x/o) so both clients show banner
      });
    });
  }

  @override
  void reset() async {
    // Only after game end and NOT when someone left; enforce server-side via transaction
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      final d = snap.data();
      if (d == null) return;

      final bool ended = (d['ended'] as bool?) ?? false;
      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      final String? leftBy = d['leftBy'] as String?;
      if (!ended) return;
      if (leftBy != null) return; // block reset after a leave
      if (_myUid != xUid && _myUid != oUid) return;

      tx.update(_gameRef, {
        'board': List<int>.filled(9, 0),
        'turn': 'x', // keep simple; randomizedStart=false means not randomized for next
        'ended': false,
        'winner': null,
        'lastMove': null,
        'updatedAt': FieldValue.serverTimestamp(),
        'leftBy': null,
        'randomizedStart': false,
        'penaltyBy': null,
      });
    });
  }

  @override
  Future<void> leave() async {
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(_gameRef);
      if (!snap.exists) return;
      final d = snap.data();
      if (d == null) return;

      final String? xUid = d['xUid'] as String?;
      final String? oUid = d['oUid'] as String?;
      final String? createdBy = d['createdBy'] as String?;
      final List<int> rawBoard = (d['board'] as List).cast<int>();
      final bool hasAnyMove = rawBoard.any((v) => v != 0);
      final bool ended = (d['ended'] as bool?) ?? false;

      final bool meIsX = xUid == _myUid;
      final bool meIsO = oUid == _myUid;
      final bool meIsCreator = createdBy == _myUid;

      // Update my presence to false (best-effort)
      final myReadyField = meIsX ? 'xReady' : meIsO ? 'oReady' : null;
      if (myReadyField != null) {
        tx.update(_gameRef, { myReadyField: false });
      }

      // A) Waiting room (no seats yet): only creator present -> delete the room
      if (xUid == null && oUid == null && meIsCreator && !hasAnyMove && !ended) {
        tx.delete(_gameRef);
        return;
      }

      // B) If seats assigned and game not ended -> leaving means opponent wins (no reseating)
      if (!ended && (meIsX || meIsO)) {
        final winner = meIsX ? 'o' : 'x';
        tx.update(_gameRef, {
          'ended': true,
          'winner': winner,
          'leftBy': _myUid,
          'updatedAt': FieldValue.serverTimestamp(),
          'penaltyBy': null,
        });
        return;
      }

      // C) Already ended -> just note who left (freeze board)
      tx.update(_gameRef, {
        'leftBy': _myUid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }).catchError((_) {});
  }

  void _onRemote(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) {
      _systemMessage = 'Room closed.';
      notifyListeners();
      return;
    }
    final d = snap.data();
    if (d == null) return;

    _xUid = d['xUid'] as String?;
    _oUid = d['oUid'] as String?;
    _xReady = d['xReady'] as bool?;
    _oReady = d['oReady'] as bool?;
    // _createdBy = d['createdBy'] as String?;
    _leftBy = d['leftBy'] as String?;
    _penaltyBy = d['penaltyBy'] as String?;

    final gs = GameState(
      board: (d['board'] as List).cast<int>().map(_cellFromInt).toList(),
      turn: _playerFromStr(d['turn'] as String),
      ended: d['ended'] as bool,
      winner: (d['winner'] as String?)?.let(_playerFromStr),
      lastMove: d['lastMove'] as int?,
    );
    setState(gs); // notifies listeners

    // Apply any queued presence update once we know our seat.
    _tryApplyPresence();

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
            : 'Opponent left — game canceled.';
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
