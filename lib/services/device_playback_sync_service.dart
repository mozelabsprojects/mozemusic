import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:audio_service/audio_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'audio_handler.dart';
import '../models/song.dart';

class RemotePlaybackState {
  final String deviceId;
  final String deviceName;
  final String deviceType; // 'mobile' | 'desktop'
  final String videoId;
  final String title;
  final String artist;
  final String thumbnailUrl;
  final int durationMs;
  final int positionMs;
  final int clientTimestampMs;
  final bool isPlaying;
  final double volume;
  final int queueLength;

  RemotePlaybackState({
    required this.deviceId,
    required this.deviceName,
    required this.deviceType,
    required this.videoId,
    required this.title,
    required this.artist,
    required this.thumbnailUrl,
    required this.durationMs,
    required this.positionMs,
    required this.clientTimestampMs,
    required this.isPlaying,
    this.volume = 1.0,
    this.queueLength = 0,
  });

  Duration get estimatedPosition {
    if (!isPlaying) return Duration(milliseconds: positionMs.clamp(0, 86400000));
    final now = DateTime.now().millisecondsSinceEpoch;
    final delta = (now - clientTimestampMs).clamp(0, 1000 * 60 * 60);
    final maxMs = durationMs > 0 ? durationMs : (positionMs + delta + 10000);
    final currentMs = (positionMs + delta).clamp(0, maxMs);
    return Duration(milliseconds: currentMs);
  }

  factory RemotePlaybackState.fromMap(Map<String, dynamic> map) {
    return RemotePlaybackState(
      deviceId: map['deviceId'] as String? ?? '',
      deviceName: map['deviceName'] as String? ?? 'Diğer Cihaz',
      deviceType: map['deviceType'] as String? ?? 'mobile',
      videoId: map['videoId'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown',
      artist: map['artist'] as String? ?? '',
      thumbnailUrl: map['thumbnailUrl'] as String? ?? '',
      durationMs: (map['durationMs'] as num?)?.toInt() ?? 0,
      positionMs: (map['positionMs'] as num?)?.toInt() ?? 0,
      clientTimestampMs: (map['clientTimestampMs'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch,
      isPlaying: map['isPlaying'] as bool? ?? false,
      volume: (map['volume'] as num?)?.toDouble() ?? 1.0,
      queueLength: (map['queueLength'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'deviceName': deviceName,
      'deviceType': deviceType,
      'videoId': videoId,
      'title': title,
      'artist': artist,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
      'positionMs': positionMs,
      'clientTimestampMs': clientTimestampMs,
      'isPlaying': isPlaying,
      'volume': volume,
      'queueLength': queueLength,
    };
  }
}

final devicePlaybackSyncServiceProvider = Provider<DevicePlaybackSyncService>((ref) {
  final service = DevicePlaybackSyncService(ref);
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});

final dismissedRemoteVideoIdProvider =
    NotifierProvider<DismissedRemoteVideoIdNotifier, String?>(
        DismissedRemoteVideoIdNotifier.new);

class DismissedRemoteVideoIdNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void dismiss(String? id) => state = id;
}

final remotePlaybackStateProvider = StreamProvider<RemotePlaybackState?>((ref) {
  final service = ref.watch(devicePlaybackSyncServiceProvider);
  return service.remotePlaybackStream;
});

class DevicePlaybackSyncService {
  final Ref ref;
  Timer? _heartbeatTimer;
  String? _deviceId;
  String? _deviceName;
  String? _deviceType;

  final _remotePlaybackController = StreamController<RemotePlaybackState?>.broadcast();
  Stream<RemotePlaybackState?> get remotePlaybackStream => _remotePlaybackController.stream;

  StreamSubscription? _playbackSub;
  StreamSubscription? _remoteDocSub;

  DevicePlaybackSyncService(this.ref);

  String get deviceId => _deviceId ?? 'unknown';
  String get deviceName => _deviceName ?? 'Moze Device';
  String get deviceType => _deviceType ?? 'mobile';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _deviceId = prefs.getString('moze_device_id');
    if (_deviceId == null) {
      _deviceId = const Uuid().v4();
      await prefs.setString('moze_device_id', _deviceId!);
    }

    if (kIsWeb) {
      _deviceName = 'Web Tarayıcı';
      _deviceType = 'web';
    } else if (Platform.isWindows) {
      _deviceName = 'Masaüstü (PC)';
      _deviceType = 'desktop';
    } else if (Platform.isMacOS) {
      _deviceName = 'MacBook';
      _deviceType = 'desktop';
    } else if (Platform.isLinux) {
      _deviceName = 'Linux PC';
      _deviceType = 'desktop';
    } else if (Platform.isAndroid) {
      _deviceName = 'Android Telefon';
      _deviceType = 'mobile';
    } else if (Platform.isIOS) {
      _deviceName = 'iPhone';
      _deviceType = 'mobile';
    } else {
      _deviceName = 'Moze Cihazı';
      _deviceType = 'other';
    }

    _listenToLocalPlayback();
    _listenToRemoteDoc();
  }

  void _listenToLocalPlayback() {
    final handler = ref.read(audioHandlerProvider);

    _playbackSub = handler.playbackState.listen((state) {
      final isPlaying = state.playing;
      final mediaItem = handler.mediaItem.value;

      if (isPlaying && mediaItem != null) {
        _broadcastCurrentPlayback(isPlaying: true);
        _startHeartbeat();
      } else {
        _stopHeartbeat();
        if (mediaItem != null) {
          _broadcastCurrentPlayback(isPlaying: false);
        }
      }
    });
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      final handler = ref.read(audioHandlerProvider);
      if (handler.playbackState.value.playing) {
        _broadcastCurrentPlayback(isPlaying: true);
      } else {
        _stopHeartbeat();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  Future<void> _broadcastCurrentPlayback({required bool isPlaying}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _deviceId == null) return;

    final handler = ref.read(audioHandlerProvider);
    final mediaItem = handler.mediaItem.value;
    if (mediaItem == null) return;

    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('active_playback')
          .doc('status');

      await docRef.set({
        'deviceId': _deviceId,
        'deviceName': _deviceName,
        'deviceType': _deviceType,
        'videoId': mediaItem.id,
        'title': mediaItem.title,
        'artist': mediaItem.artist ?? '',
        'thumbnailUrl': mediaItem.artUri?.toString() ?? '',
        'durationMs': mediaItem.duration?.inMilliseconds ?? 0,
        'positionMs': handler.player.position.inMilliseconds,
        'clientTimestampMs': DateTime.now().millisecondsSinceEpoch,
        'isPlaying': isPlaying,
        'volume': handler.player.volume,
        'queueLength': handler.queue.value.length,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error broadcasting device playback: $e');
    }
  }

  void _listenToRemoteDoc() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _remoteDocSub?.cancel();
      if (user == null) {
        _remotePlaybackController.add(null);
        return;
      }

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('active_playback')
          .doc('status');

      _remoteDocSub = docRef.snapshots().listen((snapshot) {
        if (!snapshot.exists || snapshot.data() == null) {
          _remotePlaybackController.add(null);
          return;
        }

        final data = snapshot.data()!;
        final remoteDeviceId = data['deviceId'] as String?;

        // 1. Check for incoming remote control command for this device
        final pendingCmd = data['pendingCommand'] as Map<String, dynamic>?;
        if (pendingCmd != null) {
          final targetId = pendingCmd['targetDeviceId'] as String?;
          final timestamp = (pendingCmd['timestamp'] as num?)?.toInt() ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;
          if (targetId == _deviceId && (now - timestamp).abs() < 25000) {
            _executeRemoteCommand(pendingCmd);
            docRef.update({'pendingCommand': FieldValue.delete()}).catchError((_) {});
          }
        }

        // 2. If remote device instructed us to pause
        final pauseTarget = data['requestRemotePauseFor'] as String?;
        if (pauseTarget != null && pauseTarget == _deviceId) {
          final handler = ref.read(audioHandlerProvider);
          if (handler.playbackState.value.playing) {
            handler.pause();
          }
          // Clear request flag
          docRef.update({'requestRemotePauseFor': FieldValue.delete()}).catchError((_) {});
        }

        // 3. Only emit if the update came from another device
        if (remoteDeviceId != null && remoteDeviceId != _deviceId) {
          final isPlaying = data['isPlaying'] as bool? ?? false;
          final clientTimestampMs = (data['clientTimestampMs'] as num?)?.toInt() ?? 0;
          final now = DateTime.now().millisecondsSinceEpoch;

          // Consider active if updated within the last 60 seconds (with +/- 15s clock drift tolerance)
          final age = now - clientTimestampMs;
          if (isPlaying && age > -15000 && age < 60000) {
            final state = RemotePlaybackState.fromMap(data);
            _remotePlaybackController.add(state);
          } else {
            _remotePlaybackController.add(null);
          }
        } else {
          _remotePlaybackController.add(null);
        }
      }, onError: (e) {
        debugPrint('Remote playback stream error: $e');
        _remotePlaybackController.add(null);
      });
    });
  }

  Future<void> _executeRemoteCommand(Map<String, dynamic> cmd) async {
    final action = cmd['action'] as String?;
    final handler = ref.read(audioHandlerProvider);
    try {
      switch (action) {
        case 'play':
          await handler.play();
          break;
        case 'pause':
          await handler.pause();
          break;
        case 'toggle':
          if (handler.playbackState.value.playing) {
            await handler.pause();
          } else {
            await handler.play();
          }
          break;
        case 'skipNext':
          await handler.skipToNext();
          break;
        case 'skipPrevious':
          await handler.skipToPrevious();
          break;
        case 'seek':
          final pos = (cmd['value'] as num?)?.toInt();
          if (pos != null) {
            await handler.seek(Duration(milliseconds: pos));
          }
          break;
        case 'setVolume':
          final vol = (cmd['value'] as num?)?.toDouble();
          if (vol != null) {
            await handler.setVolume(vol.clamp(0.0, 1.0));
          }
          break;
        case 'playSong':
          final songData = cmd['song'] as Map<String, dynamic>?;
          final posMs = (cmd['value'] as num?)?.toInt() ?? 0;
          if (songData != null) {
            final song = Song.fromMap(songData);
            await handler.playFromVideoId(
              song.videoId,
              mediaItem: MediaItem(
                id: song.videoId,
                title: song.title,
                artist: song.author,
                artUri: Uri.tryParse(song.thumbnailUrl),
                duration: Duration(milliseconds: song.durationMs),
              ),
              initialPosition: Duration(milliseconds: posMs),
            );
          }
          break;
        case 'addToQueue':
          final songData = cmd['song'] as Map<String, dynamic>?;
          if (songData != null) {
            final song = Song.fromMap(songData);
            await handler.addQueueItem(MediaItem(
              id: song.videoId,
              title: song.title,
              artist: song.author,
              artUri: Uri.tryParse(song.thumbnailUrl),
              duration: Duration(milliseconds: song.durationMs),
            ));
          }
          break;
        case 'clearQueue':
          await handler.clearQueue();
          break;
        case 'reorderQueue':
          final map = cmd['value'] is Map<String, dynamic> ? cmd['value'] as Map<String, dynamic> : null;
          final oldIdx = (cmd['oldIndex'] as num?)?.toInt() ?? (map?['oldIndex'] as num?)?.toInt();
          final newIdx = (cmd['newIndex'] as num?)?.toInt() ?? (map?['newIndex'] as num?)?.toInt();
          if (oldIdx != null && newIdx != null) {
            await handler.moveQueueItem(oldIdx, newIdx);
          }
          break;
        case 'removeFromQueue':
          final idx = (cmd['value'] as num?)?.toInt();
          if (idx != null) {
            await handler.removeQueueItemAt(idx);
          }
          break;
      }
    } catch (e) {
      debugPrint('Error executing remote command: $e');
    }
  }

  /// Sends a remote control command (Spotify Connect style) to the target device
  Future<void> sendRemoteCommand({
    required String targetDeviceId,
    required String action,
    dynamic value,
    Song? song,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('active_playback')
          .doc('status');

      await docRef.set({
        'pendingCommand': {
          'targetDeviceId': targetDeviceId,
          'senderDeviceId': _deviceId,
          'action': action,
          'value': ?value,
          'song': ?song?.toMap(),
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error sending remote command: $e');
    }
  }

  /// Teleports local playback to the remote device and pauses locally
  Future<void> sendCurrentPlaybackToRemote(RemotePlaybackState remote) async {
    final handler = ref.read(audioHandlerProvider);
    final currentItem = handler.mediaItem.value;
    if (currentItem == null) return;

    final song = Song(
      videoId: currentItem.id,
      title: currentItem.title,
      author: currentItem.artist ?? '',
      thumbnailUrl: currentItem.artUri?.toString() ?? '',
      durationMs: currentItem.duration?.inMilliseconds ?? 0,
    );

    final currentPos = handler.player.position.inMilliseconds;

    await sendRemoteCommand(
      targetDeviceId: remote.deviceId,
      action: 'playSong',
      value: currentPos,
      song: song,
    );

    // Pause locally after transferring
    await handler.pause();
  }

  /// Takes over playback from remote device (Handoff)
  Future<void> takeoverPlayback(RemotePlaybackState remote) async {
    final handler = ref.read(audioHandlerProvider);
    final targetPosition = remote.estimatedPosition;

    final item = MediaItem(
      id: remote.videoId,
      title: remote.title,
      artist: remote.artist,
      artUri: remote.thumbnailUrl.isNotEmpty ? Uri.parse(remote.thumbnailUrl) : null,
      duration: Duration(milliseconds: remote.durationMs),
    );

    // Tell the other device to pause
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('active_playback')
            .doc('status')
            .update({
          'requestRemotePauseFor': remote.deviceId,
        });
      } catch (_) {}
    }

    // Play locally from exact position
    await handler.playFromVideoId(
      remote.videoId,
      mediaItem: item,
      initialPosition: targetPosition,
    );
  }

  void dispose() {
    _stopHeartbeat();
    _playbackSub?.cancel();
    _remoteDocSub?.cancel();
    _remotePlaybackController.close();
  }
}
