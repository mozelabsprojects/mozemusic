import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';

import '../../core/localization/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../services/history_service.dart';
import '../../services/audio_handler.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../models/song.dart';
import '../library/song_menu_bottom_sheet.dart';

class ListeningHistoryScreen extends ConsumerWidget {
  const ListeningHistoryScreen({super.key});

  Future<void> _playSong(BuildContext context, WidgetRef ref, Song song, {List<Song>? historyList, int? index}) async {
    final handler = ref.read(audioHandlerProvider);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Loading ${song.title}...'),
        duration: const Duration(seconds: 2),
        backgroundColor: Theme.of(context).cardColor,
      ),
    );

    final String result;
    if (historyList != null && historyList.isNotEmpty && index != null) {
      result = await handler.playSongList(historyList, initialIndex: index);
    } else {
      final mediaItem = MediaItem(
        id: song.videoId,
        title: song.title,
        artist: song.author,
        artUri: Uri.parse(song.thumbnailUrl),
        duration: Duration(milliseconds: song.durationMs),
      );
      result = await handler.playFromVideoId(
        song.videoId,
        mediaItem: mediaItem,
      );
    }

    if (result != 'Success' && result != 'Cancelled' && context.mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Playback Error'),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locProvider);
    final history = ref.watch(historyProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.get('listening_history'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (history.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppTheme.textSecondary),
              onPressed: () {
                ref.read(historyProvider.notifier).clear();
              },
            )
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Text(
                loc.get('recent_listening_history_appear_here'),
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            )
          : ListView.builder(
              itemCount: history.length,
              itemBuilder: (context, index) {
                final song = history[index];
                return ListTile(
                  leading: SongCoverImage.fromSong(
                    song: song,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    song.author,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SongMenuBottomSheet(song: song),
                      );
                    },
                  ),
                  onTap: () => _playSong(context, ref, song, historyList: history, index: index),
                );
              },
            ),
    );
  }
}
