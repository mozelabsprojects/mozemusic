import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/jam_service.dart';
import '../../services/audio_handler.dart';
import '../../models/song.dart';
import 'package:audio_service/audio_service.dart';
import '../../services/auth_service.dart';

class CurrentRoomIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;
  void update(String? id) => state = id;
}

final currentRoomIdProvider = NotifierProvider<CurrentRoomIdNotifier, String?>(() => CurrentRoomIdNotifier());

final jamControllerProvider = Provider<JamController>((ref) {
  final jamService = ref.watch(jamServiceProvider);
  final audioHandler = ref.watch(audioHandlerProvider);
  final authState = ref.watch(authStateProvider).value;
  return JamController(jamService, audioHandler, authState?.uid, ref);
});

class JamController {
  final JamService _jamService;
  final MozeAudioHandler _audioHandler;
  final String? _uid;
  final Ref _ref;

  StreamSubscription? _roomSubscription;
  StreamSubscription? _playbackSubscription;
  String? _roomId;
  bool _isHost = false;

  JamController(this._jamService, this._audioHandler, this._uid, this._ref);

  Future<void> joinRoom(String roomId) async {
    _roomId = roomId;
    _ref.read(currentRoomIdProvider.notifier).update(roomId);
    
    // Check if we are host
    final doc = await FirebaseFirestore.instance.collection('jam_rooms').doc(roomId).get();
    _isHost = doc.data()?['hostId'] == _uid;

    if (!_isHost) {
      await _jamService.joinRoom(roomId);
    }

    _listenToRoom();
    
    if (_isHost) {
      _startBroadcasting();
    }
  }

  void _listenToRoom() {
    _roomSubscription?.cancel();
    _roomSubscription = _jamService.streamRoom(_roomId!).listen((snapshot) {
      if (!snapshot.exists) {
        leaveRoom();
        return;
      }
      
      final data = snapshot.data() as Map<String, dynamic>;
      
      if (!_isHost) {
        // Sync listener player
        final currentSongMap = data['currentSong'] as Map<String, dynamic>?;
        final positionMs = data['positionMs'] as int?;
        final isPlaying = data['isPlaying'] as bool? ?? true;

        if (currentSongMap != null) {
          final song = Song.fromMap(currentSongMap);
          final currentMediaItem = _audioHandler.mediaItem.value;
          
          if (currentMediaItem?.id != song.videoId) {
            // Play new song
            _audioHandler.playFromVideoId(song.videoId, mediaItem: MediaItem(
              id: song.videoId,
              title: song.title,
              artist: song.author,
              artUri: Uri.parse(song.thumbnailUrl),
              duration: Duration(milliseconds: song.durationMs),
            ));
          }

          // Sync position if difference > 3 seconds
          if (positionMs != null) {
            final currentPos = _audioHandler.player.position.inMilliseconds;
            if ((currentPos - positionMs).abs() > 3000) {
               _audioHandler.seek(Duration(milliseconds: positionMs));
            }
          }

          if (isPlaying && !_audioHandler.player.playing) {
            _audioHandler.play();
          } else if (!isPlaying && _audioHandler.player.playing) {
            _audioHandler.pause();
          }
        }
      }
    });
  }

  void _startBroadcasting() {
    _playbackSubscription?.cancel();
    // Broadcast every 5 seconds or when song changes
    _playbackSubscription = Stream.periodic(const Duration(seconds: 5)).listen((_) {
      if (_roomId == null || !_isHost) return;
      final mediaItem = _audioHandler.mediaItem.value;
      if (mediaItem != null) {
        final song = Song(
          videoId: mediaItem.id,
          title: mediaItem.title,
          author: mediaItem.artist ?? 'Unknown',
          thumbnailUrl: mediaItem.artUri?.toString() ?? '',
          durationMs: mediaItem.duration?.inMilliseconds ?? 0,
        );
        _jamService.updateCurrentSong(_roomId!, song, _audioHandler.player.position);
      }
    });
  }

  Future<void> leaveRoom() async {
    if (_roomId != null) {
      await _jamService.leaveRoom(_roomId!);
    }
    _roomSubscription?.cancel();
    _playbackSubscription?.cancel();
    _roomId = null;
    _isHost = false;
    _ref.read(currentRoomIdProvider.notifier).update(null);
  }
}
