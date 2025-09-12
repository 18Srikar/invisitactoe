import 'package:cloud_firestore/cloud_firestore.dart';

class MatchDoc {
  final String id, code, hostUid, hostName, status, turn;
  final String? guestUid, guestName, winner;
  final int nextSeq, version;
  final Map<String, dynamic> state;
  final Timestamp createdAt, updatedAt;

  MatchDoc({
    required this.id, required this.code,
    required this.hostUid, required this.guestUid,
    required this.hostName, required this.guestName,
    required this.status, required this.turn, required this.winner,
    required this.nextSeq, required this.state, required this.version,
    required this.createdAt, required this.updatedAt,
  });

  bool get isWaiting => status == 'waiting';
  bool get isActive  => status == 'active';
  String? seatFor(String uid) => uid == hostUid ? 'host' : (uid == guestUid ? 'guest' : null);

  static MatchDoc fromSnap(DocumentSnapshot<Map<String, dynamic>> snap) {
    final d = snap.data()!;
    return MatchDoc(
      id: snap.id,
      code: d['code'],
      hostUid: d['hostUid'],
      guestUid: d['guestUid'],
      hostName: d['hostName'],
      guestName: d['guestName'],
      status: d['status'],
      turn: d['turn'],
      winner: d['winner'],
      nextSeq: d['nextSeq'],
      state: Map<String, dynamic>.from(d['state'] as Map),
      version: d['version'],
      createdAt: d['createdAt'],
      updatedAt: d['updatedAt'],
    );
  }
}

class MoveDoc {
  final int seq;
  final String actorUid;
  final Map<String, dynamic> action;
  final Timestamp ts;
  MoveDoc({required this.seq, required this.actorUid, required this.action, required this.ts});
  Map<String, dynamic> toMap() => {'seq': seq, 'actorUid': actorUid, 'action': action, 'ts': ts};
}
