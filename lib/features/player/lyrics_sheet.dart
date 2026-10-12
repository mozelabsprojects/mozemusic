import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/lyrics_service.dart';
import '../../services/audio_handler.dart';
import '../../core/theme/app_theme.dart';

class LyricsSheet extends ConsumerStatefulWidget {
  final String title;
  final String artist;
  const LyricsSheet({super.key, required this.title, required this.artist});

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  final ScrollController _scrollController = ScrollController();
  int _activeLine = 0;
  StreamSubscription<Duration>? _posSub;
  List<LyricLine>? _currentLines;

  @override
  void initState() {
    super.initState();
    // Will start listening once lyrics are loaded
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
    final targetOffset = (index * 52.0) - 100; // approximate line height
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lyricsAsync = ref.watch(lyricsProvider((title: widget.title, artist: widget.artist)));

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Lyrics', style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            )),
          ),
          Expanded(
            child: lyricsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load lyrics', style: TextStyle(color: AppTheme.textSecondary))),
              data: (lyrics) {
                if (!lyrics.hasAny) {
                  return const Center(child: Text(
                    'No lyrics available',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                  ));
                }

                if (lyrics.hasSynced) {
                  // Start syncing only if lines changed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (_currentLines != lyrics.syncedLines) {
                      _currentLines = lyrics.syncedLines;
                      _startPositionListener(lyrics.syncedLines);
                    }
                  });

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    itemCount: lyrics.syncedLines.length,
                    itemBuilder: (context, index) {
                      final isActive = index == _activeLine;
                      return GestureDetector(
                        onTap: () {
                          // Seek to this line's timestamp
                          ref.read(audioHandlerProvider).seek(lyrics.syncedLines[index].timestamp);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 250),
                            style: TextStyle(
                              fontSize: isActive ? 22 : 18,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w400,
                              color: isActive ? Colors.white : Colors.white38,
                              height: 1.4,
                            ),
                            child: Text(lyrics.syncedLines[index].text),
                          ),
                        ),
                      );
                    },
                  );
                }

                // Plain lyrics fallback
                return SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    lyrics.plainLyrics ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 16, height: 1.8),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
