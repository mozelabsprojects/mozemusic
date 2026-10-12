import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'main_player_screen.dart';
import '../../services/audio_handler.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final loc = ref.watch(locProvider);

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;
        if (mediaItem == null) return const SizedBox.shrink();

        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const MainPlayerScreen()));
          },
          onHorizontalDragEnd: (details) {
            if (details.primaryVelocity! < 0) {
              HapticFeedback.lightImpact();
              audioHandler.skipToNext();
            } else if (details.primaryVelocity! > 0) {
              HapticFeedback.lightImpact();
              audioHandler.skipToPrevious();
            }
          },
          child: Container(
            height: 64,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor.withValues(alpha: 0.95),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Progress indicator at top
                  StreamBuilder<Duration>(
                    stream: audioHandler.positionStream,
                    builder: (context, posSnapshot) {
                      final position = posSnapshot.data ?? Duration.zero;
                      final duration = mediaItem.duration ?? const Duration(seconds: 1);
                      final progress = duration.inMilliseconds > 0
                          ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                          : 0.0;
                      return LinearProgressIndicator(
                        value: progress,
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.redAccent),
                      );
                    },
                  ),
                  // Content
                  Expanded(
                    child: Row(
                      children: [
                        Hero(
                          tag: 'album_cover_${mediaItem.id}',
                          child: SongCoverImage(
                            imageUrl: mediaItem.artUri?.toString(),
                            videoId: mediaItem.id,
                            width: 62,
                            height: 62,
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(mediaItem.title, style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Text(mediaItem.artist ?? loc.get('unknown'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
                            ],
                          ),
                        ),
                        StreamBuilder<PlaybackState>(
                          stream: audioHandler.playbackState,
                          builder: (context, stateSnapshot) {
                            final playing = stateSnapshot.data?.playing ?? false;
                            final processingState = stateSnapshot.data?.processingState;
                            final isInitialLoading = processingState == AudioProcessingState.loading && !playing;

                            if (isInitialLoading) {
                              return const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: SizedBox(
                                  width: 24, height: 24,
                                  child: CircularProgressIndicator(color: AppTheme.redAccent, strokeWidth: 2),
                                ),
                              );
                            }

                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Theme.of(context).textTheme.bodyLarge?.color, size: 28),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    playing ? audioHandler.pause() : audioHandler.play();
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.skip_next_rounded, color: Theme.of(context).textTheme.bodyLarge?.color, size: 26),
                                  tooltip: loc.get('up_next'),
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    audioHandler.skipToNext();
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],
                            );
                          },
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
