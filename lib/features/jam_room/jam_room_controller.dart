import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/audio_handler.dart';

final jamRoomProvider = NotifierProvider<JamRoomController, JamRoomState>(JamRoomController.new);
class JamRoomState {
  final String? roomId;
  final bool isPlaying;
  final int positionMs;
  final String? currentVideoId;
  
  JamRoomState({
    this.roomId,
    this.isPlaying = false,
    this.positionMs = 0,
    this.currentVideoId,
  });

  JamRoomState copyWith({
    String? roomId,
    bool? isPlaying,
    int? positionMs,
    String? currentVideoId,
  }) {
    return JamRoomState(
      roomId: roomId ?? this.roomId,
      isPlaying: isPlaying ?? this.isPlaying,
      positionMs: positionMs ?? this.positionMs,
      currentVideoId: currentVideoId ?? this.currentVideoId,
    );
  }
}

class JamRoomController extends Notifier<JamRoomState> {
  StreamSubscription? _subscription;

  @override
  JamRoomState build() {
    // Automatically keeps the provider alive so we don't disconnect from Jam Room when switching tabs
    ref.keepAlive();
    
    ref.onDispose(() {
      _subscription?.cancel();
    });
    return JamRoomState();
  }
  
  final FirebaseDatabase _db = FirebaseDatabase.instance;
  
  void joinRoom(String roomId) {
    _subscription?.cancel();
    state = state.copyWith(roomId: roomId);
    
    _subscription = _db.ref('jam_rooms/$roomId/playbackState').onValue.listen((event) {
      if (event.snapshot.value != null) {
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);
        final isPlaying = data['isPlaying'] as bool? ?? false;
        final positionMs = data['positionMs'] as int? ?? 0;
        final currentVideoId = data['currentVideoId'] as String?;
        
        state = state.copyWith(
          isPlaying: isPlaying,
          positionMs: positionMs,
          currentVideoId: currentVideoId,
        );
        
        final audioHandler = ref.read(audioHandlerProvider);
        audioHandler.seek(Duration(milliseconds: positionMs));
        if (isPlaying) {
          audioHandler.play();
        } else {
          audioHandler.pause();
        }
      }
    });
  }
  
  Future<void> updatePlaybackState(bool isPlaying, int positionMs, String videoId) async {
    if (state.roomId != null) {
      await _db.ref('jam_rooms/${state.roomId}/playbackState').update({
        'isPlaying': isPlaying,
        'positionMs': positionMs,
        'currentVideoId': videoId,
        'updatedAt': ServerValue.timestamp,
      });
    }
  }
}
