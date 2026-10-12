import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mozemusic/features/player/widgets/cross_device_handoff_banner.dart';
import 'package:mozemusic/services/device_playback_sync_service.dart';

void main() {
  testWidgets('CrossDeviceHandoffBanner displays when remote device is playing', (WidgetTester tester) async {
    final mockRemoteState = RemotePlaybackState(
      deviceId: 'remote-phone-id',
      deviceName: 'Pixel 8 Pro',
      deviceType: 'mobile',
      videoId: 'sampleVideo123',
      title: 'Starboy',
      artist: 'The Weeknd',
      thumbnailUrl: '',
      durationMs: 230000,
      positionMs: 45000,
      clientTimestampMs: DateTime.now().millisecondsSinceEpoch,
      isPlaying: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePlaybackStateProvider.overrideWith((ref) => Stream.value(mockRemoteState)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CrossDeviceHandoffBanner(isDesktop: true),
          ),
        ),
      ),
    );

    await tester.pump();

    // Verify banner text
    expect(find.text("Pixel 8 Pro'de Çalıyor"), findsOneWidget);
    expect(find.text('Starboy'), findsOneWidget);
    expect(find.text('The Weeknd'), findsOneWidget);
    expect(find.text('Buradan Devam Et'), findsOneWidget);
  });

  testWidgets('CrossDeviceHandoffBanner renders nothing when no remote playback', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          remotePlaybackStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: CrossDeviceHandoffBanner(isDesktop: true),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Buradan Devam Et'), findsNothing);
  });
}
