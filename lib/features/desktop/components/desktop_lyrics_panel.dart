import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/audio_handler.dart';
import '../../../services/lyrics_service.dart';

final desktopLyricsVisibleProvider = NotifierProvider<DesktopLyricsVisibleNotifier, bool>(
  DesktopLyricsVisibleNotifier.new,
);

class DesktopLyricsVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

class DesktopLyricsPanel extends ConsumerStatefulWidget {
  const DesktopLyricsPanel({super.key});

  @override
  ConsumerState<DesktopLyricsPanel> createState() => _DesktopLyricsPanelState();
}

class _DesktopLyricsPanelState extends ConsumerState<DesktopLyricsPanel> {
  final ScrollController _scrollController = ScrollController();
  int _activeLine = 0;
  StreamSubscription<Duration>? _posSub;
  List<LyricLine>? _currentLines;

  @override
  void dispose() {
    _posSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startPositionListener(List<LyricLine> lines) {
    _posSub?.cancel();
    final handler = ref.read(audioHandlerProvider);
    _posSub = handler.positionStream.listen((pos) {
      int newActive = 0;
      for (int i = lines.length - 1; i >= 0; i--) {
        if (pos >= lines[i].timestamp) {
          newActive = i;
          break;
        }
      }
      if (newActive != _activeLine && mounted) {
        setState(() => _activeLine = newActive);
        _scrollToLine(newActive);
      }
    });
  }

  void _scrollToLine(int index) {
    if (!_scrollController.hasClients) return;
    final targetOffset = (index * 56.0) - 120;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<MediaItem?>(
      stream: audioHandler.mediaItem,
      builder: (context, snap) {
        final currentSong = snap.data;

        return Container(
          width: 340,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0A0A0A) : const Color(0xFFF7F7F7),
            border: Border(
              left: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.08),
                width: 1,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
                child: Row(
                  children: [
                    const Icon(Icons.lyrics_rounded, size: 20, color: AppTheme.neonGreen),
                    const SizedBox(width: 8),
                    Text(
                      'Lyrics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const Spacer(),
                    Material(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () {
                          ref.read(desktopLyricsVisibleProvider.notifier).set(false);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 18,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.6)
                                : Colors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              if (currentSong != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentSong.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentSong.artist ?? 'Unknown Artist',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.5)
                              : Colors.black.withValues(alpha: 0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  child: Divider(
                    height: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
              ],

              // Lyrics Content
              Expanded(
                child: currentSong == null
                    ? Center(
                        child: Text(
                          'No song playing',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.3)
                                : Colors.black.withValues(alpha: 0.3),
                          ),
                        ),
                      )
                    : Consumer(
                        builder: (context, ref, _) {
                          final lyricsAsync = ref.watch(lyricsProvider((
                            title: currentSong.title,
                            artist: currentSong.artist ?? '',
                          )));

                          return lyricsAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.neonGreen,
                              ),
                            ),
                            error: (e, _) => Center(
                              child: Text(
                                'Could not load lyrics',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.4)
                                      : Colors.black.withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            data: (lyrics) {
                              if (!lyrics.hasAny) {
                                return Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.music_off_rounded,
                                        size: 32,
                                        color: isDark
                                            ? Colors.white.withValues(alpha: 0.2)
                                            : Colors.black.withValues(alpha: 0.2),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No lyrics available',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.4)
                                              : Colors.black.withValues(alpha: 0.4),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }

                              if (lyrics.hasSynced) {
                                WidgetsBinding.instance.addPostFrameCallback((_) {
                                  if (_currentLines != lyrics.syncedLines) {
                                    _currentLines = lyrics.syncedLines;
                                    _startPositionListener(lyrics.syncedLines);
                                  }
                                });

                                return ListView.builder(
                                  controller: _scrollController,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                  itemCount: lyrics.syncedLines.length,
                                  itemBuilder: (context, index) {
                                    final isActive = index == _activeLine;
                                    return InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () {
                                        ref.read(audioHandlerProvider).seek(lyrics.syncedLines[index].timestamp);
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                        child: AnimatedDefaultTextStyle(
                                          duration: const Duration(milliseconds: 250),
                                          style: TextStyle(
                                            fontSize: isActive ? 18 : 14,
                                            fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                                            color: isActive
                                                ? (isDark ? Colors.white : Colors.black)
                                                : (isDark
                                                    ? Colors.white.withValues(alpha: 0.35)
                                                    : Colors.black.withValues(alpha: 0.35)),
                                            height: 1.5,
                                          ),
                                          child: Text(lyrics.syncedLines[index].text),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              // Plain lyrics
                              return SingleChildScrollView(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                                child: SelectableText(
                                  lyrics.plainLyrics ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    height: 1.8,
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : Colors.black.withValues(alpha: 0.75),
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
