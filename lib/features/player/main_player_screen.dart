import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:just_audio/just_audio.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:marquee/marquee.dart';
import '../../services/audio_handler.dart';
import '../../services/firestore_service.dart';
import '../../models/song.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../library/song_menu_bottom_sheet.dart';
import 'lyrics_sheet.dart';
import 'sleep_timer_sheet.dart';
import 'queue_screen.dart';
import 'widgets/device_connect_modal.dart';
import 'widgets/up_next_preview_card.dart';

class MainPlayerScreen extends ConsumerStatefulWidget {
  const MainPlayerScreen({super.key});

  @override
  ConsumerState<MainPlayerScreen> createState() => _MainPlayerScreenState();
}

class _MainPlayerScreenState extends ConsumerState<MainPlayerScreen> with SingleTickerProviderStateMixin {
  Color? _bgColor;
  String? _lastImgUrl;
  double? _dragPositionMs;
  late AnimationController _playPauseAnim;

  @override
  void initState() {
    super.initState();
    _playPauseAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void dispose() {
    _playPauseAnim.dispose();
    super.dispose();
  }

  Future<void> _updatePalette(String url) async {
    if (url == _lastImgUrl) return;
    _lastImgUrl = url;
    try {
      final palette = await PaletteGenerator.fromImageProvider(CachedNetworkImageProvider(url));
      if (mounted) setState(() => _bgColor = palette.dominantColor?.color ?? palette.darkMutedColor?.color);
    } catch (e) {
      debugPrint('Palette generation error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaItem = ref.watch(audioHandlerProvider).mediaItem.value;
    if (mediaItem == null) return const Scaffold(backgroundColor: AppTheme.backgroundBlack);

    final song = Song(
      videoId: mediaItem.id,
      title: mediaItem.title,
      author: mediaItem.artist ?? 'Unknown',
      thumbnailUrl: mediaItem.artUri?.toString() ?? '',
      durationMs: mediaItem.duration?.inMilliseconds ?? 0,
    );

    _updatePalette(song.thumbnailUrl);

    final loc = ref.watch(locProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    final screenSize = MediaQuery.of(context).size;
    final maxArtFromHeight = screenSize.height * 0.30;
    final maxArtFromWidth = screenSize.width - 64;
    final artSize = (maxArtFromWidth > maxArtFromHeight ? maxArtFromHeight : maxArtFromWidth).clamp(180.0, 340.0);

    return Scaffold(
      backgroundColor: AppTheme.backgroundBlack,
      body: Stack(
        children: [
          // Dynamic Blurred Background
          AnimatedContainer(
            duration: const Duration(seconds: 1),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  _bgColor?.withValues(alpha: 0.8) ?? AppTheme.surfaceLight,
                  AppTheme.backgroundBlack,
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                children: [
                  // AppBar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down, size: 32, color: Colors.white),
                          onPressed: () => Navigator.pop(context),
                        ),
                        Text(loc.get('now_playing'), style: const TextStyle(fontSize: 12, letterSpacing: 2, color: Colors.white70)),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white), 
                          onPressed: () => showModalBottomSheet(
                            context: context, backgroundColor: Colors.transparent,
                            builder: (_) => SongMenuBottomSheet(song: song, showQueueOption: true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),

                  // Album Art (Animated Scale)
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, snapshot) {
                      final playing = snapshot.data?.playing ?? false;
                      return AnimatedScale(
                        scale: playing ? 1.0 : 0.85,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutBack,
                        child: Hero(
                          tag: 'album_cover_${song.videoId}',
                          child: SongCoverImage.fromSong(
                            song: song,
                            width: artSize,
                            height: artSize,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // Info & Like
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                height: 30,
                                child: song.title.length > 25
                                    ? Marquee(
                                        text: song.title,
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                        blankSpace: 40,
                                        velocity: 30,
                                      )
                                    : Text(
                                        song.title,
                                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(song.author, style: const TextStyle(fontSize: 16, color: Colors.white70), maxLines: 1),
                            ],
                          ),
                        ),
                        Consumer(
                          builder: (context, ref, child) {
                            final isLiked = ref.watch(likedSongsProvider).value?.any((s) => s.videoId == song.videoId) ?? false;
                            return IconButton(
                              icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? AppTheme.redAccent : Colors.white),
                              iconSize: 28,
                              onPressed: () {
                                HapticFeedback.selectionClick();
                                ref.read(firestoreServiceProvider).toggleLikeSong(song, isLiked);
                              },
                            ).animate(target: isLiked ? 1 : 0).scale(begin: const Offset(1,1), end: const Offset(1.3,1.3)).then().scale(begin: const Offset(1.3,1.3), end: const Offset(1,1));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Slider
                  StreamBuilder<Duration>(
                    stream: audioHandler.positionStream,
                    builder: (context, posSnapshot) {
                      final position = posSnapshot.data ?? Duration.zero;
                      final duration = mediaItem.duration;
                      final safeDurationMs = (duration != null && duration.inMilliseconds > 0) ? duration.inMilliseconds.toDouble() : 1.0;
                      final safePositionMs = (_dragPositionMs ?? position.inMilliseconds.toDouble()).clamp(0.0, safeDurationMs);
                      final displayPosition = _dragPositionMs != null
                          ? Duration(milliseconds: _dragPositionMs!.round())
                          : position;

                      String formatDur(Duration d) => "${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}";

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                              activeTrackColor: Colors.white, inactiveTrackColor: Colors.white24, thumbColor: Colors.white,
                            ),
                            child: Slider(
                              value: safePositionMs, max: safeDurationMs,
                              onChangeStart: (val) => setState(() => _dragPositionMs = val),
                              onChanged: (val) => setState(() => _dragPositionMs = val),
                              onChangeEnd: (val) {
                                audioHandler.seek(Duration(milliseconds: val.toInt()));
                                setState(() => _dragPositionMs = null);
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(formatDur(displayPosition), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                Text(formatDur(duration ?? Duration.zero), style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),

                  // Controls
                  StreamBuilder<PlaybackState>(
                    stream: audioHandler.playbackState,
                    builder: (context, snapshot) {
                      final state = snapshot.data;
                      final playing = state?.playing ?? false;
                      if (playing) {
                        _playPauseAnim.forward();
                      } else {
                        _playPauseAnim.reverse();
                      }

                      return Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<bool>(
                            stream: audioHandler.shuffleModeEnabledStream,
                            builder: (context, shufSnap) {
                              final isShuf = shufSnap.data ?? false;
                              return IconButton(icon: Icon(Icons.shuffle, color: isShuf ? AppTheme.redAccent : Colors.white70), onPressed: () => audioHandler.setShuffleMode(isShuf ? AudioServiceShuffleMode.none : AudioServiceShuffleMode.all));
                            },
                          ),
                          IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: () { HapticFeedback.lightImpact(); audioHandler.skipToPrevious(); }),
                          Container(
                            height: 72, width: 72,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.1)),
                            child: IconButton(
                              icon: AnimatedIcon(icon: AnimatedIcons.play_pause, progress: _playPauseAnim, color: Colors.white, size: 40),
                              onPressed: () {
                                HapticFeedback.mediumImpact();
                                playing ? audioHandler.pause() : audioHandler.play();
                              },
                            ),
                          ),
                          IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: () { HapticFeedback.lightImpact(); audioHandler.skipToNext(); }),
                          StreamBuilder<LoopMode>(
                            stream: audioHandler.loopModeStream,
                            builder: (context, loopSnap) {
                              final loopMode = loopSnap.data ?? LoopMode.off;
                              IconData icon = Icons.repeat;
                              Color col = Colors.white70;
                              if (loopMode == LoopMode.one) { 
                                icon = Icons.repeat_one; 
                                col = AppTheme.redAccent; 
                              } else if (loopMode == LoopMode.all) { 
                                col = AppTheme.redAccent; 
                              }
                              return IconButton(
                                icon: Icon(icon, color: col),
                                onPressed: () {
                                  if (loopMode == LoopMode.off) {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.all);
                                  } else if (loopMode == LoopMode.all) {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.one);
                                  } else {
                                    audioHandler.setRepeatMode(AudioServiceRepeatMode.none);
                                  }
                                },
                              );
                            },
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 14),
                  const UpNextPreviewCard(),
                  const SizedBox(height: 14),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: loc.get('devices'),
                          icon: const Icon(Icons.devices_rounded, color: Colors.white70),
                          onPressed: () => DeviceConnectModal.show(context),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          tooltip: loc.get('sleep_timer'),
                          icon: const Icon(Icons.bedtime, color: Colors.white70),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            builder: (_) => const SleepTimerSheet(),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          tooltip: loc.get('lyrics'),
                          icon: const Icon(Icons.lyrics, color: Colors.white70),
                          onPressed: () => showModalBottomSheet(
                            context: context,
                            backgroundColor: Colors.transparent,
                            isScrollControlled: true,
                            builder: (_) => LyricsSheet(title: song.title, artist: song.author),
                          ),
                        ),
                        const SizedBox(width: 24),
                        IconButton(
                          tooltip: loc.get('queue'),
                          icon: const Icon(Icons.queue_music, color: Colors.white70),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const QueueScreen()),
                          ),
                        ),
                      ],
                    ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
