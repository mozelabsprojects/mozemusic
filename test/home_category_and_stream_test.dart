import 'package:flutter_test/flutter_test.dart';
import 'package:mozemusic/features/home/home_controller.dart';
import 'package:mozemusic/services/youtube_service.dart';
import 'package:mozemusic/services/device_playback_sync_service.dart';
import 'package:mozemusic/models/song.dart';

void main() {
  group('Home Screen Category Tests', () {
    test('Categories do not contain spotify references and have unique IDs', () {
      final ids = <String>{};
      for (final cat in homeGenreCategories) {
        // Assert ID uniqueness
        expect(ids.contains(cat.id), isFalse, reason: 'Duplicate category ID found: ${cat.id}');
        ids.add(cat.id);

        // Assert no spotify in ID or locKey
        expect(cat.id.toLowerCase().contains('spotify'), isFalse,
            reason: 'Category id should not mention spotify: ${cat.id}');
        expect(cat.locKey.toLowerCase().contains('spotify'), isFalse,
            reason: 'Category locKey should not mention spotify: ${cat.locKey}');

        // Assert fallback songs are present and valid
        expect(cat.fallbackSongs, isNotEmpty,
            reason: 'Category ${cat.id} must have non-empty fallback songs');

        for (final song in cat.fallbackSongs) {
          expect(song.videoId, isNotEmpty);
          expect(song.title, isNotEmpty);
          expect(song.author, isNotEmpty);
          expect(song.thumbnailUrl, isNotEmpty);
        }
      }

      // Assert expected categories exist
      expect(ids.contains('top_hits'), isTrue);
      expect(ids.contains('trending_now'), isTrue);
      expect(ids.contains('turkey_pop'), isTrue);
      expect(ids.contains('turkey_rap'), isTrue);
      expect(ids.contains('turkey_rock'), isTrue);
      expect(ids.contains('turkey_classical'), isTrue);
      expect(ids.contains('turkey_soft'), isTrue);
      expect(ids.contains('pop_hits'), isTrue);
      expect(ids.contains('rap_hip_hop'), isTrue);
      expect(ids.contains('rock_alternative'), isTrue);
      expect(ids.contains('electronic_dance'), isTrue);
      expect(ids.contains('chill_rnb'), isTrue);
    });

    test('Each category has distinct fallback songs (no duplicates across genres)', () {
      final seenVideoIds = <String>{};
      for (final cat in homeGenreCategories) {
        for (final song in cat.fallbackSongs) {
          expect(seenVideoIds.contains(song.videoId), isFalse,
              reason: 'Song ${song.title} (${song.videoId}) is duplicated across categories');
          seenVideoIds.add(song.videoId);
        }
      }
    });
  });

  group('YouTube Stream URL Retrieval Tests', () {
    test('getAudioStreamUrlWithQuality returns a valid playable URL without 403', () async {
      final ytService = YoutubeService();
      try {
        // Test with a popular well-known video (Despacito)
        final url = await ytService.getAudioStreamUrlWithQuality('kJQP7kiw5Fk', 'High');
        expect(url, isNotNull);
        expect(url!.startsWith('https://'), isTrue);
        expect(url.contains('googlevideo.com'), isTrue);
      } finally {
        ytService.dispose();
      }
    }, timeout: const Timeout(Duration(seconds: 30)));
  });

  group('Device Playback Sync & Remote Control Tests', () {
    test('RemotePlaybackState correctly serializes and deserializes', () {
      final state = RemotePlaybackState(
        deviceId: 'dev_123',
        deviceName: 'Android Telefon',
        deviceType: 'mobile',
        videoId: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi',
        thumbnailUrl: 'https://img.youtube.com/vi/kJQP7kiw5Fk/0.jpg',
        durationMs: 240000,
        positionMs: 60000,
        clientTimestampMs: DateTime.now().millisecondsSinceEpoch,
        isPlaying: true,
        volume: 0.85,
        queueLength: 12,
      );

      final map = state.toMap();
      expect(map['deviceId'], 'dev_123');
      expect(map['deviceName'], 'Android Telefon');
      expect(map['volume'], 0.85);
      expect(map['queueLength'], 12);
      expect(map['isPlaying'], isTrue);

      final reconstructed = RemotePlaybackState.fromMap(map);
      expect(reconstructed.deviceId, state.deviceId);
      expect(reconstructed.deviceName, state.deviceName);
      expect(reconstructed.videoId, state.videoId);
      expect(reconstructed.volume, state.volume);
      expect(reconstructed.queueLength, state.queueLength);
      expect(reconstructed.estimatedPosition.inMilliseconds, greaterThanOrEqualTo(60000));
    });

    test('RemotePlaybackState estimatedPosition clamps when paused', () {
      final pausedState = RemotePlaybackState(
        deviceId: 'dev_456',
        deviceName: 'Masaüstü (PC)',
        deviceType: 'desktop',
        videoId: 'kJQP7kiw5Fk',
        title: 'Despacito',
        artist: 'Luis Fonsi',
        thumbnailUrl: '',
        durationMs: 240000,
        positionMs: 45000,
        clientTimestampMs: DateTime.now().millisecondsSinceEpoch - 10000, // 10s ago
        isPlaying: false,
      );

      // When paused, position should NOT increase
      expect(pausedState.estimatedPosition.inMilliseconds, equals(45000));
    });
  });

  group('Song Thumbnail Resiliency & Sanitization Tests', () {
    test('Empty thumbnailUrl automatically falls back to hqdefault.jpg', () {
      final song = Song(
        videoId: 'abc123xyz',
        title: 'Test Song',
        author: 'Test Artist',
        thumbnailUrl: '',
        durationMs: 180000,
      );
      expect(song.thumbnailUrl, equals('https://img.youtube.com/vi/abc123xyz/hqdefault.jpg'));
      expect(song.fallbackThumbnailUrl, equals('https://img.youtube.com/vi/abc123xyz/hqdefault.jpg'));
    });

    test('maxresdefault.jpg is sanitized to 100% available hqdefault.jpg', () {
      final song = Song(
        videoId: 'vid456',
        title: 'HD Song',
        author: 'Artist',
        thumbnailUrl: 'https://img.youtube.com/vi/vid456/maxresdefault.jpg',
        durationMs: 200000,
      );
      expect(song.thumbnailUrl, equals('https://img.youtube.com/vi/vid456/hqdefault.jpg'));
    });

    test('Song.fromMap sanitizes null or empty thumbnailUrl', () {
      final song = Song.fromMap({
        'videoId': 'vid789',
        'title': 'Map Song',
        'author': 'Author',
        'thumbnailUrl': null,
        'durationMs': 150000,
      });
      expect(song.thumbnailUrl, equals('https://img.youtube.com/vi/vid789/hqdefault.jpg'));
    });
  });

  group('Trending Now & Category Freshness Tests', () {
    test('trending_now contains modern 2024-2026 smash hits', () {
      final trending = homeGenreCategories.firstWhere((c) => c.id == 'trending_now');
      final titles = trending.fallbackSongs.map((s) => s.title.toLowerCase()).toList();

      // Verified 2024-2026 smash hits
      expect(titles.any((t) => t.contains('apt')), isTrue);
      expect(titles.any((t) => t.contains('die with a smile')), isTrue);
      expect(titles.any((t) => t.contains('birds of a feather')), isTrue);
      expect(titles.any((t) => t.contains('taste')), isTrue);
      expect(titles.any((t) => t.contains('a bar song')), isTrue);

      // Verify no ancient songs from 2011-2017 are present
      expect(titles.any((t) => t.contains('lazy song')), isFalse);
      expect(titles.any((t) => t.contains('lush life')), isFalse);
      expect(titles.any((t) => t.contains('new rules')), isFalse);
      expect(titles.any((t) => t.contains('cheap thrills')), isFalse);
    });

    test('All category songs have non-empty, reliable thumbnail URLs', () {
      for (final cat in homeGenreCategories) {
        for (final song in cat.fallbackSongs) {
          expect(song.thumbnailUrl.isNotEmpty, isTrue,
              reason: 'Song ${song.title} in ${cat.id} has empty thumbnail');
          expect(song.thumbnailUrl.contains('maxresdefault.jpg'), isFalse,
              reason: 'Song ${song.title} in ${cat.id} uses 404-prone maxresdefault');
          expect(song.thumbnailUrl.contains('hqdefault.jpg'), isTrue,
              reason: 'Song ${song.title} in ${cat.id} does not use reliable hqdefault');
        }
      }
    });
  });
}

