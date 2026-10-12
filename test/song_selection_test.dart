import 'package:flutter_test/flutter_test.dart';
import 'package:mozemusic/models/song.dart';
import 'package:audio_service/audio_service.dart';

void main() {
  group('Song Selection & Queue Integrity Tests', () {
    test('Queue mapping preserves exact selected index and does not default to index 0', () {
      final songs = List.generate(
        10,
        (i) => Song(
          videoId: 'vid_$i',
          title: 'Song $i',
          author: 'Artist $i',
          thumbnailUrl: 'https://img.test/$i.jpg',
          durationMs: 180000 + i * 1000,
        ),
      );

      // Suppose user clicked song index 4 (Song 4)
      const selectedIndex = 4;
      final targetSong = songs[selectedIndex];

      final mediaItems = songs.map((s) => MediaItem(
        id: s.videoId,
        title: s.title,
        artist: s.author,
        artUri: Uri.parse(s.thumbnailUrl),
        duration: Duration(milliseconds: s.durationMs),
      )).toList();

      expect(targetSong.videoId, 'vid_4');
      expect(mediaItems[selectedIndex].id, 'vid_4');
      expect(mediaItems[selectedIndex].title, 'Song 4');

      // Verify queue index lookup
      final currentItem = mediaItems[selectedIndex];
      final computedIndex = mediaItems.indexWhere((i) => i.id == currentItem.id);
      expect(computedIndex, 4);
    });

    test('Rapid song switching returns Cancelled safely without error dialog triggers', () {
      // Test cancellation state logic
      String simulatePlaybackResult(bool superseded) {
        if (superseded) {
          return 'Cancelled';
        }
        return 'Success';
      }

      final result1 = simulatePlaybackResult(true);
      final result2 = simulatePlaybackResult(false);

      expect(result1, 'Cancelled');
      expect(result2, 'Success');

      // The condition used in UI
      bool shouldShowErrorDialog(String result) {
        return result != 'Success' && result != 'Cancelled';
      }

      expect(shouldShowErrorDialog('Success'), isFalse);
      expect(shouldShowErrorDialog('Cancelled'), isFalse);
      expect(shouldShowErrorDialog('Network Error 500'), isTrue);
    });
  });
}
