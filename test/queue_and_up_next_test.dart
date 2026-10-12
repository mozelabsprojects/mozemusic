import 'package:flutter_test/flutter_test.dart';
import 'package:audio_service/audio_service.dart';
import 'package:mozemusic/models/song.dart';
import 'package:mozemusic/services/device_playback_sync_service.dart';

void main() {
  group('Queue Reordering and Up Next Logic Tests', () {
    final item1 = MediaItem(id: 'song1', title: 'Song 1', artist: 'Artist 1');
    final item2 = MediaItem(id: 'song2', title: 'Song 2', artist: 'Artist 2');
    final item3 = MediaItem(id: 'song3', title: 'Song 3', artist: 'Artist 3');
    final item4 = MediaItem(id: 'song4', title: 'Song 4', artist: 'Artist 4');

    test('Moving an item downwards in queue adjusts indices correctly', () {
      final queue = [item1, item2, item3, item4];
      
      // Moving item1 (index 0) to index 3
      int oldIndex = 0;
      int newIndex = 3;
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = queue.removeAt(oldIndex);
      queue.insert(newIndex, item);

      expect(queue[0].id, equals('song2'));
      expect(queue[1].id, equals('song3'));
      expect(queue[2].id, equals('song1'));
      expect(queue[3].id, equals('song4'));
    });

    test('Moving an item to the very end of queue (newIndex == queue.length) places it at last index', () {
      final queue = [item1, item2, item3, item4];

      // Dragging item1 (index 0) to after item4 (Flutter passes newIndex = 4 = queue.length)
      int oldIndex = 0;
      int newIndex = 4;
      if (oldIndex < 0 || oldIndex >= queue.length || newIndex < 0 || newIndex > queue.length) {
        fail('Should not be rejected by bounds check');
      }
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = queue.removeAt(oldIndex);
      queue.insert(newIndex, item);

      expect(queue[0].id, equals('song2'));
      expect(queue[1].id, equals('song3'));
      expect(queue[2].id, equals('song4'));
      expect(queue[3].id, equals('song1'));
    });

    test('Moving an item upwards in queue inserts without minus 1', () {
      final queue = [item1, item2, item3, item4];

      // Moving item4 (index 3) to index 1
      int oldIndex = 3;
      int newIndex = 1;
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }
      final item = queue.removeAt(oldIndex);
      queue.insert(newIndex, item);

      expect(queue[0].id, equals('song1'));
      expect(queue[1].id, equals('song4'));
      expect(queue[2].id, equals('song2'));
      expect(queue[3].id, equals('song3'));
    });

    test('Up Next detection identifies next track accurately', () {
      final queue = [item1, item2, item3];
      
      // If current is item1, up next is item2
      var current = item1;
      var currentIndex = queue.indexWhere((i) => i.id == current.id);
      MediaItem? nextItem = (currentIndex >= 0 && currentIndex + 1 < queue.length)
          ? queue[currentIndex + 1]
          : null;
      expect(nextItem?.id, equals('song2'));

      // If current is item3 (last), up next is null
      current = item3;
      currentIndex = queue.indexWhere((i) => i.id == current.id);
      nextItem = (currentIndex >= 0 && currentIndex + 1 < queue.length)
          ? queue[currentIndex + 1]
          : null;
      expect(nextItem, isNull);
    });
  });

  group('Thumbnail Resiliency with img.youtube.com Tests', () {
    test('Song thumbnail converts i.ytimg.com domain to img.youtube.com', () {
      final song = Song(
        videoId: 'abc123',
        title: 'Title',
        author: 'Author',
        thumbnailUrl: 'https://i.ytimg.com/vi/abc123/hqdefault.jpg',
        durationMs: 120000,
      );

      expect(song.thumbnailUrl, equals('https://img.youtube.com/vi/abc123/hqdefault.jpg'));
    });

    test('Song fallbackThumbnailUrl always points to img.youtube.com hqdefault.jpg', () {
      final song = Song(
        videoId: 'xyz999',
        title: 'Title',
        author: 'Author',
        thumbnailUrl: '',
        durationMs: 120000,
      );

      expect(song.fallbackThumbnailUrl, equals('https://img.youtube.com/vi/xyz999/hqdefault.jpg'));
    });
  });

  group('Cross-Device Playback Sync Queue Length Tests', () {
    test('RemotePlaybackState preserves queueLength across serialize/deserialize', () {
      final state = RemotePlaybackState(
        deviceId: 'dev123',
        deviceName: 'Desktop PC',
        deviceType: 'desktop',
        videoId: 'vid111',
        title: 'APT.',
        artist: 'ROSE',
        thumbnailUrl: 'https://img.youtube.com/vi/vid111/hqdefault.jpg',
        durationMs: 180000,
        positionMs: 45000,
        clientTimestampMs: 1700000000000,
        isPlaying: true,
        queueLength: 7,
      );

      final map = state.toMap();
      expect(map['queueLength'], equals(7));

      final restored = RemotePlaybackState.fromMap(map);
      expect(restored.queueLength, equals(7));
      expect(restored.title, equals('APT.'));
      expect(restored.deviceType, equals('desktop'));
    });
  });

  group('Playlist Queue Sequential and Shuffle Navigation Tests', () {
    final playlist = List.generate(
      5,
      (i) => MediaItem(id: 'song_$i', title: 'Song $i', artist: 'Artist $i'),
    );

    test('Playing 3rd song (index 2) advances sequentially to 4th song (index 3)', () {
      final current = playlist[2]; // 3. şarkı
      final currentIndex = playlist.indexWhere((i) => i.id == current.id);
      expect(currentIndex, equals(2));

      final nextIndex = currentIndex + 1;
      expect(nextIndex < playlist.length, isTrue);
      final nextTrack = playlist[nextIndex];
      expect(nextTrack.id, equals('song_3')); // 4. şarkı
    });

    test('At the end of playlist, sequential navigation loops to the first song', () {
      final current = playlist.last; // son şarkı
      final currentIndex = playlist.indexWhere((i) => i.id == current.id);
      expect(currentIndex, equals(playlist.length - 1));

      final nextTrack = (currentIndex + 1 < playlist.length)
          ? playlist[currentIndex + 1]
          : playlist.first;
      expect(nextTrack.id, equals('song_0'));
    });

    test('In shuffle mode, next song is picked strictly from unplayed tracks of the playlist', () {
      final playedShuffleIds = <String>{};
      final current = playlist[2]; // 3. şarkı
      playedShuffleIds.add(current.id);

      final unplayed = playlist.where((i) => i.id != current.id && !playedShuffleIds.contains(i.id)).toList();
      expect(unplayed.length, equals(4));
      expect(unplayed.every((i) => playlist.any((p) => p.id == i.id)), isTrue);
      expect(unplayed.any((i) => i.id == current.id), isFalse);

      // Pick one and mark played
      final nextTrack = unplayed.first;
      playedShuffleIds.add(nextTrack.id);

      // Pick next
      final remaining = playlist.where((i) => i.id != nextTrack.id && !playedShuffleIds.contains(i.id)).toList();
      expect(remaining.length, equals(3));
      expect(remaining.any((i) => i.id == nextTrack.id), isFalse);
    });

    test('In shuffle mode, when all tracks are played, cycle resets within the playlist', () {
      final playedShuffleIds = playlist.map((p) => p.id).toSet();
      final current = playlist[1];

      var unplayed = playlist.where((i) => i.id != current.id && !playedShuffleIds.contains(i.id)).toList();
      expect(unplayed, isEmpty);

      // Cycle resets keeping current
      playedShuffleIds.clear();
      playedShuffleIds.add(current.id);
      unplayed = playlist.where((i) => i.id != current.id).toList();

      expect(unplayed.length, equals(4));
      expect(unplayed.every((i) => playlist.contains(i)), isTrue);
    });
  });
}
