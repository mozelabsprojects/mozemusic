import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../services/device_playback_sync_service.dart';
import '../../../services/audio_handler.dart';

class CrossDeviceHandoffBanner extends ConsumerWidget {
  final bool isDesktop;

  const CrossDeviceHandoffBanner({super.key, this.isDesktop = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remoteStateAsync = ref.watch(remotePlaybackStateProvider);

    return remoteStateAsync.when(
      data: (remote) {
        if (remote == null) return const SizedBox.shrink();

        final dismissedId = ref.watch(dismissedRemoteVideoIdProvider);
        if (dismissedId == remote.videoId) return const SizedBox.shrink();

        try {
          final audioHandler = ref.watch(audioHandlerProvider);
          final localItem = audioHandler.mediaItem.value;
          final isLocalPlaying = audioHandler.playbackState.value.playing;
          if (isLocalPlaying && localItem?.id == remote.videoId) {
            return const SizedBox.shrink();
          }
        } catch (_) {}

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24.0 : 12.0,
            vertical: 4.0,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E).withValues(alpha: 0.92)
                      : Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Device Icon + Pulse Dot
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            remote.deviceType == 'mobile'
                                ? Icons.phone_android_rounded
                                : Icons.laptop_mac_rounded,
                            size: 22,
                            color: const Color(0xFF1DB954),
                          ),
                        ),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1DB954),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),

                    // Song Thumbnail
                    if (remote.thumbnailUrl.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: remote.thumbnailUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (_, err, trace) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.grey[800],
                            child: const Icon(Icons.music_note, size: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],

                    // Device Name & Song Title
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Text(
                                '${remote.deviceName}\'de Çalıyor',
                                style: const TextStyle(
                                  color: Color(0xFF1DB954),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _formatDuration(remote.estimatedPosition),
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            remote.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (remote.artist.isNotEmpty)
                            Text(
                              remote.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Continue Playback Button
                    ElevatedButton.icon(
                      onPressed: () async {
                        ref.read(dismissedRemoteVideoIdProvider.notifier).dismiss(remote.videoId);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('▶ Oynatma ${remote.deviceName}\'den devralındı'),
                            backgroundColor: const Color(0xFF1DB954),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        await ref
                            .read(devicePlaybackSyncServiceProvider)
                            .takeoverPlayback(remote);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1DB954),
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          horizontal: isDesktop ? 16 : 12,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: Text(
                        isDesktop ? 'Buradan Devam Et' : 'Devam Et',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 4),

                    // Dismiss Button
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      tooltip: 'Kapat',
                      onPressed: () {
                        ref.read(dismissedRemoteVideoIdProvider.notifier).dismiss(remote.videoId);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, errorTrace) => const SizedBox.shrink(),
    );
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
