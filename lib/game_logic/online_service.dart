import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'models.dart';

class OnlineService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  CollectionReference<Map<String, dynamic>> get _matches => _db.collection('matches');
  String get _uid => _auth.currentUser!.uid;

  String _code6() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random.secure();
    return List.generate(6, (_) => alphabet[rnd.nextInt(alphabet.length)]).join();
  }

  Future<MatchDoc> createMatch({
    required Map<String, dynamic> initialState,
    required String hostName,
    String initialTurn = 'host',
  }) async {
    final ref = await _matches.add({
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'status': 'waiting',
      'hostUid': _uid,
      'guestUid': null,
      'hostName': hostName,
      'guestName': null,
      'code': _code6(),
      'nextSeq': 1,
      'turn': initialTurn,
      'winner': null,
      'state': initialState,
      'version': 1,
    });
    final snap = await ref.get();
    return MatchDoc.fromSnap(snap);
  }

  Future<MatchDoc?> findByCode(String code) async {
    final q = await _matches.where('code', isEqualTo: code).limit(1).get();
    if (q.docs.isEmpty) return null;
    return MatchDoc.fromSnap(q.docs.first);
  }

  Future<MatchDoc> joinMatch({required String code, required String guestName}) async {
    final found = await findByCode(code);
    if (found == null) { throw StateError('Room not found'); }
    final ref = _matches.doc(found.id);
    await _db.runTransaction((tx) async {
      final snap = await tx.get(ref);
      final m = MatchDoc.fromSnap(snap);
      if (!m.isWaiting) throw StateError('Room not joinable');
      if (m.guestUid != null) throw StateError('Room full');
      tx.update(ref, {
        'guestUid': _uid,
        'guestName': guestName,
        'status': 'active',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
    final updated = await ref.get();
    return MatchDoc.fromSnap(updated);
  }

  Stream<MatchDoc> watchMatch(String id) => _matches.doc(id).snapshots().map(MatchDoc.fromSnap);

  CollectionReference<Map<String, dynamic>> _actions(String matchId) =>
      _matches.doc(matchId).collection('actions');

  Future<void> submitMove({
    required String matchId,
    required Map<String, dynamic> nextState,
    required String nextTurn, // 'host' | 'guest' | 'none'
    String? winner, // 'host' | 'guest' | 'draw' | null
    Map<String, dynamic>? action,
  }) async {
    final matchRef = _matches.doc(matchId);
    final uid = _uid;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(matchRef);
      final m = MatchDoc.fromSnap(snap);
      if (!m.isActive) throw StateError('Not active');
      final seat = uid == m.hostUid ? 'host' : (uid == m.guestUid ? 'guest' : null);
      if (seat == null) throw StateError('Not a participant');
      if (m.winner != null) throw StateError('Finished');

      final seq = m.nextSeq;
      if (action != null) {
        tx.set(_actions(matchRef.id).doc(seq.toString()), {
          'seq': seq,
          'actorUid': uid,
          'action': action,
          'ts': FieldValue.serverTimestamp(),
        });
      }

      tx.update(matchRef, {
        'updatedAt': FieldValue.serverTimestamp(),
        'state': nextState,
        'turn': nextTurn,
        'winner': winner,
        'nextSeq': seq + 1,
        if (winner != null) 'status': 'finished',
      });
    });
  }
}
