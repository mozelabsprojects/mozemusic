import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import 'auth_service.dart';

final jamServiceProvider = Provider<JamService>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return JamService(FirebaseFirestore.instance, authState?.uid);
});

class JamService {
  final FirebaseFirestore _db;
  final String? _uid;

  /// Cached server-time offset (server - local) in milliseconds
  int _serverOffsetMs = 0;
  bool _offsetCalibrated = false;

  JamService(this._db, this._uid);

  /// Calibrates local clock against Firestore server timestamp.
  /// Call once when joining/creating a room.
  Future<void> calibrateServerOffset() async {
    if (_offsetCalibrated) return;
    try {
      final localBefore = DateTime.now().millisecondsSinceEpoch;
      final tempDoc = _db.collection('_clock_sync').doc();
      await tempDoc.set({'t': FieldValue.serverTimestamp()});
      final snap = await tempDoc.get();
      final localAfter = DateTime.now().millisecondsSinceEpoch;
      final serverTime = (snap.data()?['t'] as Timestamp).millisecondsSinceEpoch;
      // Estimate: serverTime ≈ midpoint of local before/after
      final localMid = (localBefore + localAfter) ~/ 2;
      _serverOffsetMs = serverTime - localMid;
      _offsetCalibrated = true;
      await tempDoc.delete();
      log('JamService: Server offset calibrated: ${_serverOffsetMs}ms');
    } catch (e) {
      log('JamService: Offset calibration failed: $e');
    }
  }

  /// Returns estimated current server time
  int get _serverNowMs => DateTime.now().millisecondsSinceEpoch + _serverOffsetMs;

  // Creates a new room and returns its ID
  Future<String?> createRoom({String? roomName}) async {
    if (_uid == null) return null;
    await calibrateServerOffset();
    
    final docRef = await _db.collection('jam_rooms').add({
      'hostId': _uid,
      'roomName': roomName ?? 'Jam Room',
      'createdAt': FieldValue.serverTimestamp(),
      'isActive': true,
      'listeners': [_uid],
    });
    
    return docRef.id;
  }

  // Joins an existing room
  Future<void> joinRoom(String roomId) async {
    if (_uid == null) return;
    await calibrateServerOffset();
    
    await _db.collection('jam_rooms').doc(roomId).update({
      'listeners': FieldValue.arrayUnion([_uid]),
    });
  }

  // Streams room data
  Stream<DocumentSnapshot> streamRoom(String roomId) {
    return _db.collection('jam_rooms').doc(roomId).snapshots();
  }

  /// Updates current playing song in room — NTP-synced.
  /// Stores the absolute server timestamp when the track should be at `position`.
  /// Listeners compute: seekTo = position + (now_server - anchorTimestamp)
  Future<void> updateCurrentSong(String roomId, Song song, Duration position) async {
    if (_uid == null) return;
    
    await _db.collection('jam_rooms').doc(roomId).update({
      'currentSong': song.toMap(),
      'positionMs': position.inMilliseconds,
      'anchorServerMs': _serverNowMs, // absolute server time when position was recorded
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Calculates the seek position a listener should use, compensating for network delay.
  /// Returns the adjusted Duration.
  Duration calculateSyncedPosition(Map<String, dynamic> roomData) {
    final positionMs = roomData['positionMs'] as int? ?? 0;
    final anchorServerMs = roomData['anchorServerMs'] as int? ?? 0;
    if (anchorServerMs == 0) return Duration(milliseconds: positionMs);

    final elapsed = _serverNowMs - anchorServerMs;
    final adjustedMs = positionMs + elapsed;
    return Duration(milliseconds: adjustedMs.clamp(0, 999999999));
  }

  // Leaves a room
  Future<void> leaveRoom(String roomId) async {
    if (_uid == null) return;
    
    await _db.collection('jam_rooms').doc(roomId).update({
      'listeners': FieldValue.arrayRemove([_uid]),
    });
  }

  // Closes a room (host only)
  Future<void> closeRoom(String roomId) async {
    if (_uid == null) return;
    await _db.collection('jam_rooms').doc(roomId).update({
      'isActive': false,
    });
  }
}
