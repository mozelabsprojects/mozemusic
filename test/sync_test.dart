import 'package:flutter_test/flutter_test.dart';
import 'package:mozemusic/services/device_playback_sync_service.dart';

void main() {
  group('RemotePlaybackState & Sync Unit Tests', () {
    test('toMap and fromMap preserves all fields correctly', () {
      final state = RemotePlaybackState(
        deviceId: 'device-123',
        deviceName: 'Android Telefon',
        deviceType: 'mobile',
        videoId: 'abcXYZ123',
        title: 'Bohemian Rhapsody',
        artist: 'Queen',
        thumbnailUrl: 'https://img.youtube.com/vi/abcXYZ123/hqdefault.jpg',
        durationMs: 354000,
        positionMs: 45000,
        clientTimestampMs: 1700000000000,
        isPlaying: true,
      );

      final map = state.toMap();
      final parsed = RemotePlaybackState.fromMap(map);

      expect(parsed.deviceId, 'device-123');
      expect(parsed.deviceName, 'Android Telefon');
      expect(parsed.deviceType, 'mobile');
      expect(parsed.videoId, 'abcXYZ123');
      expect(parsed.title, 'Bohemian Rhapsody');
      expect(parsed.artist, 'Queen');
      expect(parsed.thumbnailUrl, 'https://img.youtube.com/vi/abcXYZ123/hqdefault.jpg');
      expect(parsed.durationMs, 354000);
      expect(parsed.positionMs, 45000);
      expect(parsed.clientTimestampMs, 1700000000000);
      expect(parsed.isPlaying, true);
    });

    test('estimatedPosition returns exact position when not playing', () {
      final state = RemotePlaybackState(
        deviceId: 'device-123',
        deviceName: 'Masaüstü (PC)',
        deviceType: 'desktop',
        videoId: 'abcXYZ123',
        title: 'Song',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 200000,
        positionMs: 60000,
        clientTimestampMs: DateTime.now().millisecondsSinceEpoch - 10000,
        isPlaying: false,
      );

      expect(state.estimatedPosition, const Duration(milliseconds: 60000));
    });

    test('estimatedPosition calculates time elapsed while playing', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = RemotePlaybackState(
        deviceId: 'device-123',
        deviceName: 'Android Telefon',
        deviceType: 'mobile',
        videoId: 'abcXYZ123',
        title: 'Song',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 200000,
        positionMs: 30000,
        clientTimestampMs: now - 5000, // 5 seconds ago
        isPlaying: true,
      );

      // Estimated position should be around 35000 ms (allowing ~100ms test execution drift)
      final posMs = state.estimatedPosition.inMilliseconds;
      expect(posMs, greaterThanOrEqualTo(34900));
      expect(posMs, lessThanOrEqualTo(35500));
    });

    test('estimatedPosition clamps to total duration when song ends', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = RemotePlaybackState(
        deviceId: 'device-123',
        deviceName: 'Android Telefon',
        deviceType: 'mobile',
        videoId: 'abcXYZ123',
        title: 'Song',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 60000, // 1 minute song
        positionMs: 50000,
        clientTimestampMs: now - 20000, // 20 seconds later (would be 70s without clamp)
        isPlaying: true,
      );

      expect(state.estimatedPosition.inMilliseconds, 60000);
    });

    test('estimatedPosition handles zero durationMs safely without negative overflow', () {
      final now = DateTime.now().millisecondsSinceEpoch;
      final state = RemotePlaybackState(
        deviceId: 'device-123',
        deviceName: 'Android Telefon',
        deviceType: 'mobile',
        videoId: 'abcXYZ123',
        title: 'Live Stream',
        artist: 'Artist',
        thumbnailUrl: '',
        durationMs: 0, // Unknown/Live stream
        positionMs: 15000,
        clientTimestampMs: now - 3000,
        isPlaying: true,
      );

      expect(state.estimatedPosition.isNegative, false);
      expect(state.estimatedPosition.inMilliseconds, greaterThanOrEqualTo(17900));
    });
  });
}
