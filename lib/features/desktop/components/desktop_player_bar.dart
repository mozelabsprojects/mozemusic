import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/audio_handler.dart';
import '../../../services/firestore_service.dart';
import '../../../models/song.dart';
import '../../../common_widgets/song_cover_image.dart';
import 'desktop_queue_panel.dart';
import 'desktop_lyrics_panel.dart';
import '../../player/widgets/device_connect_modal.dart';

class DesktopPlayerBar extends ConsumerStatefulWidget {
  const DesktopPlayerBar({super.key});

  @override
  ConsumerState<DesktopPlayerBar> createState() => _DesktopPlayerBarState();
}

class _DesktopPlayerBarState extends ConsumerState<DesktopPlayerBar> {
  bool _isHoveringSeek = false;
  double? _dragValue;

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snapshot) {
        final mediaItem = snapshot.data;

        return Container(
          height: 88,
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF181818)
                : const Color(0xFFFFFFFF),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              // LEFT: Track Info
              SizedBox(
                width: 280,
                child: _buildTrackInfo(mediaItem, isDark),
              ),

              // CENTER: Playback Controls + Seek Bar
              Expanded(
                child: _buildCenterControls(audioHandler, mediaItem, isDark),
              ),

              // RIGHT: Volume + Extras
              SizedBox(
                width: 280,
                child: _buildRightControls(audioHandler, isDark),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTrackInfo(MediaItem? mediaItem, bool isDark) {
    if (mediaItem == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            Container(
              width: 56, height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.05),
              ),
              child: Icon(Icons.music_note_rounded,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.2),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          // Album Art
          SongCoverImage(
            imageUrl: mediaItem.artUri?.toString(),
            videoId: mediaItem.id,
            width: 56,
            height: 56,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 14),
          // Track Info
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  mediaItem.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  mediaItem.artist ?? 'Unknown',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.55)
                        : Colors.black.withValues(alpha: 0.55),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Heart / Favorite
          Consumer(
            builder: (context, ref, _) {
              final isLiked = ref.watch(likedSongsProvider).value?.any((s) => s.videoId == mediaItem.id) ?? false;
              final song = Song(
                videoId: mediaItem.id,
                title: mediaItem.title,
                author: mediaItem.artist ?? 'Unknown',
                thumbnailUrl: mediaItem.artUri?.toString() ?? '',
                durationMs: mediaItem.duration?.inMilliseconds ?? 0,
              );

              return _buildSmallIconButton(
                isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                isDark,
                customColor: isLiked ? AppTheme.redAccent : null,
                onTap: () {
                  HapticFeedback.lightImpact();
                  ref.read(firestoreServiceProvider).toggleLikeSong(song, isLiked);
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCenterControls(MozeAudioHandler handler, MediaItem? mediaItem, bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Playback Buttons Row
        StreamBuilder<PlaybackState>(
          stream: handler.playbackState,
          builder: (context, stateSnap) {
            final playing = stateSnap.data?.playing ?? false;
            final processingState = stateSnap.data?.processingState;
            final isLoading = processingState == AudioProcessingState.loading ||
                processingState == AudioProcessingState.buffering;

            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Shuffle
                StreamBuilder<bool>(
                  stream: handler.shuffleModeEnabledStream,
                  builder: (context, snap) {
                    final shuffled = snap.data ?? false;
                    return _buildSmallIconButton(
                      Icons.shuffle_rounded,
                      isDark,
                      isActive: shuffled,
                      onTap: () => handler.setShuffleMode(
                        shuffled
                            ? AudioServiceShuffleMode.none
                            : AudioServiceShuffleMode.all,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 12),
                // Previous
                _buildSmallIconButton(
                  Icons.skip_previous_rounded,
                  isDark,
                  size: 28,
                  onTap: mediaItem == null ? null : () => handler.skipToPrevious(),
                ),
                const SizedBox(width: 8),
                // Play/Pause
                Material(
                  color: mediaItem == null
                      ? (isDark ? Colors.white24 : Colors.black26)
                      : (isDark ? Colors.white : Colors.black),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: mediaItem == null
                        ? null
                        : () {
                            HapticFeedback.lightImpact();
                            playing ? handler.pause() : handler.play();
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: (isLoading && !playing)
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isDark ? Colors.black : Colors.white,
                              ),
                            )
                          : Icon(
                              playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                              size: 24,
                              color: isDark ? Colors.black : Colors.white,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Next
                _buildSmallIconButton(
                  Icons.skip_next_rounded,
                  isDark,
                  size: 28,
                  onTap: mediaItem == null ? null : () => handler.skipToNext(),
                ),
                const SizedBox(width: 12),
                // Repeat
                StreamBuilder<LoopMode>(
                  stream: handler.loopModeStream,
                  builder: (context, snap) {
                    final loopMode = snap.data ?? LoopMode.off;
                    IconData icon;
                    bool active;
                    switch (loopMode) {
                      case LoopMode.off:
                        icon = Icons.repeat_rounded;
                        active = false;
                        break;
                      case LoopMode.one:
                        icon = Icons.repeat_one_rounded;
                        active = true;
                        break;
                      case LoopMode.all:
                        icon = Icons.repeat_rounded;
                        active = true;
                        break;
                    }
                    return _buildSmallIconButton(
                      icon,
                      isDark,
                      isActive: active,
                      onTap: () {
                        final next = loopMode == LoopMode.off
                            ? AudioServiceRepeatMode.all
                            : loopMode == LoopMode.all
                                ? AudioServiceRepeatMode.one
                                : AudioServiceRepeatMode.none;
                        handler.setRepeatMode(next);
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 4),
        // Seek Bar
        SizedBox(
          height: 20,
          child: StreamBuilder<Duration>(
            stream: handler.positionStream,
            builder: (context, posSnap) {
              final position = posSnap.data ?? Duration.zero;
              final duration = mediaItem?.duration ?? const Duration(seconds: 1);
              final progress = duration.inMilliseconds > 0
                  ? (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0)
                  : 0.0;
              final effectiveProgress = _dragValue ?? progress;
              final effectivePosition = _dragValue != null
                  ? Duration(milliseconds: (_dragValue! * duration.inMilliseconds).round())
                  : position;

              return Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text(
                      _formatDuration(effectivePosition),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.5),
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isHoveringSeek = true),
                      onExit: (_) => setState(() => _isHoveringSeek = false),
                      child: SliderTheme(
                        data: SliderThemeData(
                          trackHeight: _isHoveringSeek ? 5 : 3,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: _isHoveringSeek ? 6 : 0,
                          ),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                          activeTrackColor: _isHoveringSeek
                              ? AppTheme.neonGreen
                              : (isDark ? Colors.white : Colors.black),
                          inactiveTrackColor: isDark
                              ? Colors.white.withValues(alpha: 0.12)
                              : Colors.black.withValues(alpha: 0.1),
                          thumbColor: isDark ? Colors.white : Colors.black,
                        ),
                        child: Slider(
                          value: effectiveProgress,
                          onChangeStart: (v) {
                            setState(() => _dragValue = v);
                          },
                          onChanged: (v) {
                            setState(() => _dragValue = v);
                          },
                          onChangeEnd: (v) {
                            final newPos = Duration(
                              milliseconds: (v * duration.inMilliseconds).round(),
                            );
                            handler.seek(newPos);
                            setState(() => _dragValue = null);
                          },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _formatDuration(duration),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.5)
                            : Colors.black.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRightControls(MozeAudioHandler handler, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Up Next Preview Pill (Desktop)
          StreamBuilder<List<MediaItem>>(
            stream: handler.queue,
            builder: (context, qSnap) {
              final next = handler.nextMediaItem;
              if (next == null) return const SizedBox.shrink();

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () {
                    if (!ref.read(desktopQueueVisibleProvider)) {
                      ref.read(desktopLyricsVisibleProvider.notifier).set(false);
                      ref.read(desktopQueueVisibleProvider.notifier).set(true);
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.skip_next_rounded, size: 14, color: AppTheme.neonGreen),
                        const SizedBox(width: 4),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 120),
                          child: Text(
                            'Sırada: ${next.title}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          // Queue with Badge
          StreamBuilder<List<MediaItem>>(
            stream: handler.queue,
            builder: (context, snap) {
              final count = (snap.data ?? []).length;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  _buildSmallIconButton(
                    Icons.queue_music_rounded,
                    isDark,
                    isActive: ref.watch(desktopQueueVisibleProvider),
                    onTap: () {
                      if (!ref.read(desktopQueueVisibleProvider)) {
                        ref.read(desktopLyricsVisibleProvider.notifier).set(false);
                      }
                      ref.read(desktopQueueVisibleProvider.notifier).toggle();
                    },
                  ),
                  if (count > 0)
                    Positioned(
                      top: 2,
                      right: 2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: AppTheme.redAccent,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 14,
                          minHeight: 14,
                        ),
                        child: Text(
                          '$count',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 4),
          // Lyrics
          _buildSmallIconButton(
            Icons.lyrics_rounded,
            isDark,
            isActive: ref.watch(desktopLyricsVisibleProvider),
            onTap: () {
              if (!ref.read(desktopLyricsVisibleProvider)) {
                ref.read(desktopQueueVisibleProvider.notifier).set(false);
              }
              ref.read(desktopLyricsVisibleProvider.notifier).toggle();
            },
          ),
          const SizedBox(width: 4),
          // Devices / Moze Connect
          _buildSmallIconButton(
            Icons.devices_rounded,
            isDark,
            onTap: () => DeviceConnectModal.show(context),
          ),
          const SizedBox(width: 8),
          // Volume
          StreamBuilder<double>(
            stream: handler.volumeStream,
            builder: (context, snap) {
              final volume = snap.data ?? 1.0;
              IconData volumeIcon;
              if (volume <= 0) {
                volumeIcon = Icons.volume_off_rounded;
              } else if (volume < 0.5) {
                volumeIcon = Icons.volume_down_rounded;
              } else {
                volumeIcon = Icons.volume_up_rounded;
              }

              return Row(
                children: [
                  _buildSmallIconButton(
                    volumeIcon,
                    isDark,
                    onTap: () {
                      handler.setVolume(volume > 0 ? 0.0 : 1.0);
                    },
                  ),
                  SizedBox(
                    width: 100,
                    child: SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
                        activeTrackColor: isDark ? Colors.white : Colors.black,
                        inactiveTrackColor: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : Colors.black.withValues(alpha: 0.1),
                        thumbColor: isDark ? Colors.white : Colors.black,
                      ),
                      child: Slider(
                        value: volume,
                        onChanged: (v) => handler.setVolume(v),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSmallIconButton(
    IconData icon,
    bool isDark, {
    double size = 20,
    bool isActive = false,
    Color? customColor,
    VoidCallback? onTap,
  }) {
    final color = customColor ??
        (isActive
            ? AppTheme.neonGreen
            : isDark
                ? Colors.white.withValues(alpha: 0.6)
                : Colors.black.withValues(alpha: 0.6));

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: onTap,
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.black.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: size, color: color),
        ),
      ),
    );
  }
}
