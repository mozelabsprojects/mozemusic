// ignore_for_file: deprecated_member_use, use_super_parameters, experimental_member_use

import 'dart:async';
import 'dart:io';
import 'dart:developer';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'youtube_service.dart';
import 'history_service.dart';
import '../models/song.dart';
import 'package:isar/isar.dart';
import '../models/isar_models.dart';
import '../main.dart';

final audioHandlerProvider = Provider<MozeAudioHandler>((ref) {
  throw UnimplementedError('audioHandlerProvider must be overridden');
});

// Sleep timer provider
final sleepTimerProvider = NotifierProvider<SleepTimerNotifier, SleepTimerState>(SleepTimerNotifier.new);

class SleepTimerState {
  final Duration? remaining;
  final bool isActive;
  final bool endOfTrack; // stop after current track ends
  SleepTimerState({this.remaining, this.isActive = false, this.endOfTrack = false});
}

class SleepTimerNotifier extends Notifier<SleepTimerState> {
  Timer? _timer;
  Timer? _fadeTimer;

  @override
  SleepTimerState build() => SleepTimerState();

  MozeAudioHandler get _handler => ref.read(audioHandlerProvider);

  void startTimer(Duration duration) {
    cancel();
    var remaining = duration;
    state = SleepTimerState(remaining: remaining, isActive: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      remaining -= const Duration(seconds: 1);
      if (remaining <= Duration.zero) {
        _fadeOutAndStop();
        return;
      }
      state = SleepTimerState(remaining: remaining, isActive: true);
    });
  }

  void setEndOfTrack() {
    cancel();
    state = SleepTimerState(isActive: true, endOfTrack: true);
    // Listen for track completion
    _handler.player.processingStateStream.listen((ps) {
      if (ps == ProcessingState.completed && state.endOfTrack) {
        _handler.pause();
        cancel();
      }
    });
  }

  void _fadeOutAndStop() async {
    // Gradually reduce volume over 5 seconds
    double vol = _handler.player.volume;
    final step = vol / 10;
    _fadeTimer = Timer.periodic(const Duration(milliseconds: 500), (t) async {
      vol -= step;
      if (vol <= 0) {
        t.cancel();
        await _handler.pause();
        await _handler.setVolume(1.0); // restore for next session
        cancel();
        return;
      }
      await _handler.setVolume(vol.clamp(0.0, 1.0));
    });
  }

  void cancel() {
    _timer?.cancel();
    _fadeTimer?.cancel();
    _timer = null;
    _fadeTimer = null;
    state = SleepTimerState();
  }
}


class MozeAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final YoutubeService _youtubeService;
  final SharedPreferences _prefs;
  final HistoryService _historyService;
  bool _isAutoplayInProgress = false;
  bool _isLoadingTrack = false;
  int _playRequestId = 0;
  final Set<String> _playedShuffleIds = {};

  MozeAudioHandler(this._youtubeService, this._prefs, this._historyService) {
    _init();
  }

  AudioPlayer get player => _player;

  Future<void> _init() async {
    if (!Platform.isWindows) {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.music());

      // Handle phone calls, alarms, and audio focus transitions
      session.interruptionEventStream.listen((event) {
        if (event.begin) {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(0.5);
              break;
            case AudioInterruptionType.pause:
            case AudioInterruptionType.unknown:
              pause();
              break;
          }
        } else {
          switch (event.type) {
            case AudioInterruptionType.duck:
              _player.setVolume(1.0);
              break;
            case AudioInterruptionType.pause:
              play();
              break;
            case AudioInterruptionType.unknown:
              break;
          }
        }
      });

      // Pause playback when headphones or Bluetooth devices disconnect
      session.becomingNoisyEventStream.listen((_) {
        pause();
      });
    }

    _player.playbackEventStream.listen(_broadcastState);
    _player.playerStateStream.listen((playerState) {
      _broadcastState(_player.playbackEvent);
    });

    // Advance to next song when current track finishes playing
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        if (!_isAutoplayInProgress && !_isLoadingTrack) {
          final pos = _player.position;
          final dur = _player.duration;
          // Guard: Advance to next song if track played and reached natural completion
          if (dur != null && pos >= const Duration(seconds: 1)) {
            skipToNext();
          }
        }
      }
    });
  }

  /// Broadcasts the current state to all clients.
  void _broadcastState(PlaybackEvent event) {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
        MediaAction.setShuffleMode,
        MediaAction.play,
        MediaAction.pause,
        MediaAction.stop,
        MediaAction.skipToNext,
        MediaAction.skipToPrevious,
      },
      androidCompactActionIndices: const [0, 1, 3],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: () {
        final currentId = mediaItem.value?.id;
        if (currentId == null || queue.value.isEmpty) return event.currentIndex ?? 0;
        final idx = queue.value.indexWhere((i) => i.id == currentId);
        return idx >= 0 ? idx : 0;
      }(),
    ));
  }

  Future<void> _handleAutoplay() async {
    final autoplay = _prefs.getBool('autoplay') ?? true;
    if (!autoplay || mediaItem.value == null) return;

    _isAutoplayInProgress = true;
    try {
      final related = await _youtubeService.getRelatedVideos(mediaItem.value!.id);
      if (related.isNotEmpty) {
        final nextSong = related.first;
        final nextMediaItem = MediaItem(
          id: nextSong.videoId,
          title: nextSong.title,
          artist: nextSong.author,
          artUri: Uri.parse(nextSong.thumbnailUrl),
          duration: Duration(milliseconds: nextSong.durationMs),
        );
        await addQueueItem(nextMediaItem);
        // Autoplay: Immediately start playing the next song
        final res = await playFromVideoId(nextMediaItem.id, mediaItem: nextMediaItem);
        if (res != 'Success' && res != 'Cancelled' && related.length > 1) {
          final secondSong = related[1];
          final secondItem = MediaItem(
            id: secondSong.videoId,
            title: secondSong.title,
            artist: secondSong.author,
            artUri: Uri.parse(secondSong.thumbnailUrl),
            duration: Duration(milliseconds: secondSong.durationMs),
          );
          await addQueueItem(secondItem);
          await playFromVideoId(secondItem.id, mediaItem: secondItem);
        }
      } else {
        // Fallback: replay history or stop gracefully
        log('Autoplay: No related videos found, stopping.');
      }
    } catch (e) {
      log('Autoplay error: $e');
    } finally {
      _isAutoplayInProgress = false;
    }
  }

  @override
  Future<void> play() async {
    playbackState.add(playbackState.value.copyWith(playing: true));
    try {
      await _player.play();
    } catch (e) {
      playbackState.add(playbackState.value.copyWith(playing: false));
      rethrow;
    }
  }

  @override
  Future<void> pause() async {
    playbackState.add(playbackState.value.copyWith(playing: false));
    await _player.pause();
  }

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  @override
  Future<void> skipToNext() async {
    final currentList = queue.value;
    final current = mediaItem.value;
    final loopMode = _player.loopMode;
    final isShuffle = _player.shuffleModeEnabled;

    if (currentList.isEmpty || current == null) {
      await _handleAutoplay();
      return;
    }

    // Repeat one: replay current track
    if (loopMode == LoopMode.one) {
      await _player.seek(Duration.zero);
      await _player.play();
      return;
    }

    final currentIndex = currentList.indexWhere((i) => i.id == current.id);

    // Shuffle (Mix) mode: always pick next unplayed song from the current playlist queue!
    if (isShuffle && currentList.length > 1) {
      _playedShuffleIds.add(current.id);
      var unplayed = currentList.where((i) => i.id != current.id && !_playedShuffleIds.contains(i.id)).toList();
      if (unplayed.isEmpty) {
        // All tracks in playlist were played in shuffle mode; reset cycle and keep current
        _playedShuffleIds.clear();
        _playedShuffleIds.add(current.id);
        unplayed = currentList.where((i) => i.id != current.id).toList();
      }
      if (unplayed.isNotEmpty) {
        unplayed.shuffle();
        final next = unplayed.first;
        _playedShuffleIds.add(next.id);
        final res = await playFromVideoId(next.id, mediaItem: next, updateQueue: false);
        if (res != 'Success' && res != 'Cancelled') {
          await skipToNext();
        }
        return;
      }
    }

    // Normal sequential mode: advance to the next song in the active playlist
    if (currentIndex >= 0 && currentIndex + 1 < currentList.length) {
      final next = currentList[currentIndex + 1];
      _playedShuffleIds.add(next.id);
      final res = await playFromVideoId(next.id, mediaItem: next, updateQueue: false);
      if (res != 'Success' && res != 'Cancelled') {
        log('skipToNext: Error playing ${next.id} ($res), skipping forward...');
        await skipToNext();
      }
    } else if (currentList.length > 1) {
      // Reached the end of playlist: loop back to beginning of the active playlist!
      final first = currentList.first;
      _playedShuffleIds.clear();
      _playedShuffleIds.add(first.id);
      final res = await playFromVideoId(first.id, mediaItem: first, updateQueue: false);
      if (res != 'Success' && res != 'Cancelled') {
        log('skipToNext: Error playing loop head ($res), skipping forward...');
        await skipToNext();
      }
    } else {
      await _handleAutoplay();
    }
  }

  @override
  Future<void> skipToPrevious() async {
    // If playing for more than 3 seconds, seek to beginning (Spotify standard)
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
      return;
    }
    final currentList = queue.value;
    final current = mediaItem.value;
    if (currentList.isEmpty || current == null) return;
    final index = currentList.indexWhere((i) => i.id == current.id);
    if (index > 0) {
      final prev = currentList[index - 1];
      await playFromVideoId(prev.id, mediaItem: prev, updateQueue: false);
    } else if (currentList.length > 1) {
      // Loop to end of playlist
      final last = currentList.last;
      await playFromVideoId(last.id, mediaItem: last, updateQueue: false);
    } else {
      await _player.seek(Duration.zero);
    }
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    switch (repeatMode) {
      case AudioServiceRepeatMode.none:
        await _player.setLoopMode(LoopMode.off);
        break;
      case AudioServiceRepeatMode.one:
        await _player.setLoopMode(LoopMode.one);
        break;
      case AudioServiceRepeatMode.all:
      case AudioServiceRepeatMode.group:
        await _player.setLoopMode(LoopMode.all);
        break;
    }
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final enabled = shuffleMode == AudioServiceShuffleMode.all || shuffleMode == AudioServiceShuffleMode.group;
    await _player.setShuffleModeEnabled(enabled);
  }

  Future<void> seekForward15() async {
    final target = _player.position + const Duration(seconds: 15);
    final duration = _player.duration ?? target;
    await _player.seek(target > duration ? duration : target);
  }

  Future<void> seekBackward15() async {
    final target = _player.position - const Duration(seconds: 15);
    await _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  Future<AudioSource> _createAudioSource(String videoId, MediaItem item) async {
    // 1. Check if song has been downloaded locally for offline playback
    try {
      final downloadEntry = isar.downloadEntrys.where().videoIdEqualTo(videoId).findFirstSync();
      if (downloadEntry != null) {
        final localFile = File(downloadEntry.filePath);
        if (localFile.existsSync()) {
          log('AudioHandler: Playing downloaded song from local file: ${localFile.path}');
          return AudioSource.uri(
            Uri.file(localFile.path),
            tag: item,
          );
        }
      }
    } catch (e) {
      log('AudioHandler: Checking local download error: $e');
    }

    // 2. Fall back to online streaming from YouTube
    final quality = _prefs.getString('audioQuality') ?? 'High';
    final streamUrl = await _youtubeService.getAudioStreamUrlWithQuality(videoId, quality);
    if (streamUrl == null || streamUrl.isEmpty) {
      throw Exception('Could not retrieve audio stream from YouTube for $videoId');
    }
    return AudioSource.uri(
      Uri.parse(streamUrl),
      tag: item,
      headers: const {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
    );
  }

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value)..add(mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> insertQueueItem(int index, MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value);
    final clampedIndex = index.clamp(0, newQueue.length);
    newQueue.insert(clampedIndex, mediaItem);
    queue.add(newQueue);
  }

  @override
  Future<void> removeQueueItem(MediaItem mediaItem) async {
    final newQueue = List<MediaItem>.from(queue.value)
      ..removeWhere((i) => i.id == mediaItem.id);
    queue.add(newQueue);
  }

  Future<void> clearQueue() async {
    queue.add([]);
  }

  /// Sets an entire list of songs as the active queue and starts playing from the specified index.
  Future<String> playSongList(List<Song> songs, {int initialIndex = 0}) async {
    if (songs.isEmpty) return 'No songs';
    final targetIndex = initialIndex.clamp(0, songs.length - 1);
    final mediaItems = songs.map((s) => MediaItem(
      id: s.videoId,
      title: s.title,
      artist: s.author,
      artUri: Uri.parse(s.thumbnailUrl),
      duration: Duration(milliseconds: s.durationMs),
    )).toList();

    // Reset shuffle history for newly chosen playlist
    _playedShuffleIds.clear();

    // Replace queue with full playlist
    queue.add(mediaItems);

    final targetSong = songs[targetIndex];
    final targetItem = mediaItems[targetIndex];
    _playedShuffleIds.add(targetItem.id);
    return playFromVideoId(targetSong.videoId, mediaItem: targetItem, updateQueue: false);
  }

  /// Main method to play a song by its YouTube video ID.
  Future<String> playFromVideoId(
    String videoId, {
    MediaItem? mediaItem,
    bool updateQueue = true,
    Duration? initialPosition,
  }) async {
    final currentRequestId = ++_playRequestId;
    _isLoadingTrack = true;
    try {
      final item = mediaItem ?? MediaItem(
        id: videoId,
        title: 'Unknown Title',
        artist: 'Unknown Artist',
      );

      // Immediately set mediaItem in UI so user gets instant visual confirmation
      this.mediaItem.add(item);
      _playedShuffleIds.add(item.id);
      if (updateQueue) {
        final currentQueue = List<MediaItem>.from(queue.value);
        if (!currentQueue.any((i) => i.id == item.id)) {
          currentQueue.add(item);
          queue.add(currentQueue);
        }
      }

      // Add to history
      final song = Song(
        videoId: item.id,
        title: item.title,
        author: item.artist ?? 'Unknown',
        thumbnailUrl: item.artUri?.toString() ?? '',
        durationMs: item.duration?.inMilliseconds ?? 0,
      );
      _historyService.addToHistory(song);

      // Broadcast loading state
      playbackState.add(playbackState.value.copyWith(
        processingState: AudioProcessingState.loading,
        playing: false,
        updatePosition: initialPosition ?? Duration.zero,
      ));

      // Stop previous playback to prevent old track from emitting completion
      await _player.stop();

      if (_playRequestId != currentRequestId) return 'Cancelled';

      final source = await _createAudioSource(videoId, item);

      if (_playRequestId != currentRequestId) return 'Cancelled';

      await _player.setAudioSource(source, initialPosition: initialPosition);

      if (_playRequestId != currentRequestId) return 'Cancelled';

      await _player.play();

      // Update mediaItem with actual duration from player
      final actualDuration = _player.duration;
      if (actualDuration != null && actualDuration != item.duration) {
        final updatedItem = item.copyWith(duration: actualDuration);
        this.mediaItem.add(updatedItem);
      }

      return 'Success';
    } catch (e, stack) {
      log('Error playing video $videoId: $e\n$stack');
      if (_playRequestId == currentRequestId) {
        playbackState.add(playbackState.value.copyWith(
          processingState: AudioProcessingState.idle,
          playing: false,
        ));
      }
      return e.toString().replaceFirst('Exception: ', '');
    } finally {
      if (_playRequestId == currentRequestId) {
        _isLoadingTrack = false;
      }
    }
  }

  Future<void> moveQueueItem(int oldIndex, int newIndex) async {
    if (oldIndex < 0 || oldIndex >= queue.value.length ||
        newIndex < 0 || newIndex > queue.value.length) {
      return;
    }
    
    // adjust newIndex for reorder logic
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    if (newIndex < 0 || newIndex >= queue.value.length) return;

    final currentQueue = List<MediaItem>.from(queue.value);
    final item = currentQueue.removeAt(oldIndex);
    currentQueue.insert(newIndex, item);
    
    queue.add(currentQueue);
  }

  MediaItem? get nextMediaItem {
    final currentList = queue.value;
    final current = mediaItem.value;
    if (currentList.isEmpty || current == null) return null;

    if (_player.shuffleModeEnabled && currentList.length > 1) {
      final unplayed = currentList.where((i) => i.id != current.id && !_playedShuffleIds.contains(i.id)).toList();
      if (unplayed.isNotEmpty) {
        return unplayed.first;
      }
      return currentList.firstWhere((i) => i.id != current.id, orElse: () => current);
    }

    final idx = currentList.indexWhere((i) => i.id == current.id);
    if (idx >= 0 && idx + 1 < currentList.length) {
      return currentList[idx + 1];
    }
    if (currentList.length > 1) {
      return currentList.first;
    }
    return null;
  }

  @override
  Future<void> removeQueueItemAt(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final currentQueue = List<MediaItem>.from(queue.value);
    currentQueue.removeAt(index);
    queue.add(currentQueue);
  }

  Future<void> playQueueItemAt(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    final target = queue.value[index];
    await playFromVideoId(target.id, mediaItem: target, updateQueue: false);
  }

  // Expose player streams for UI
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeEnabledStream => _player.shuffleModeEnabledStream;
  Stream<double> get volumeStream => _player.volumeStream;

  Future<void> setVolume(double volume) async {
    await _player.setVolume(volume);
  }
}


/// Custom StreamAudioSource — NEVER caches the URL.
/// Always fetches a fresh stream URL for each request to prevent 403 expired-URL errors.
/// On 403, automatically retries with a brand new URL.
class YoutubeAudioSource extends StreamAudioSource {
  final String videoId;
  final Future<String?> Function(String) getStreamUrl;
  
  String? _resolvedUrl;
  DateTime? _resolvedAt;
  // URL expiry window: refresh if older than 4 hours
  static const _urlTtl = Duration(hours: 4);

  YoutubeAudioSource(this.videoId, this.getStreamUrl, {dynamic tag}) : super(tag: tag);

  bool get _isUrlExpired =>
      _resolvedUrl == null ||
      _resolvedAt == null ||
      DateTime.now().difference(_resolvedAt!) > _urlTtl;

  Future<String> _freshUrl() async {
    _resolvedUrl = await getStreamUrl(videoId);
    _resolvedAt = DateTime.now();
    if (_resolvedUrl == null) throw Exception('Stream URL could not be resolved for $videoId');
    return _resolvedUrl!;
  }

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    // Get a fresh or cached (non-expired) URL
    final url = _isUrlExpired ? await _freshUrl() : _resolvedUrl!;

    start ??= 0;
    try {
      return await _doRequest(url, start, end);
    } catch (e) {
      // On any 403/410, force refresh URL and retry once
      if (e.toString().contains('403') || e.toString().contains('410')) {
        log('YoutubeAudioSource: Got 403/410, refreshing stream URL for $videoId');
        final freshUrl = await _freshUrl();
        return await _doRequest(freshUrl, start, end);
      }
      rethrow;
    }
  }

  Future<StreamAudioResponse> _doRequest(String url, int start, int? end) async {
    final httpClient = HttpClient();
    final request = await httpClient.getUrl(Uri.parse(url));
    
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=$start-${end ?? ''}');
    request.headers.set(HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');

    final response = await request.close();
    
    if (response.statusCode >= 400) {
      // Drain and throw to allow retry logic
      await response.drain<void>();
      throw Exception('YouTube returned HTTP ${response.statusCode}');
    }
  
    int? sourceLength;
    final contentRange = response.headers.value(HttpHeaders.contentRangeHeader);
    if (contentRange != null && contentRange.contains('/')) {
      final parts = contentRange.split('/');
      if (parts.length == 2) {
        sourceLength = int.tryParse(parts[1]);
      }
    }
    
    return StreamAudioResponse(
      sourceLength: sourceLength,
      contentLength: response.contentLength == -1 ? null : response.contentLength,
      offset: start,
      stream: response,
      contentType: response.headers.contentType?.mimeType ?? 'audio/webm',
    );
  }
}

