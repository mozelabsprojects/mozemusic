import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/download_service.dart';
import '../../services/audio_handler.dart';
import '../../common_widgets/song_cover_image.dart';

class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadedSongs = ref.watch(downloadedSongsProvider);
    final loc = ref.watch(locProvider);
    final audioHandler = ref.watch(audioHandlerProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(loc.get('downloads'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: downloadedSongs.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.download_done, size: 64, color: AppTheme.textSecondary),
                  const SizedBox(height: 16),
                  Text(
                    loc.get('no_downloads_yet'),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: downloadedSongs.length,
              itemBuilder: (context, index) {
                final song = downloadedSongs[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: SongCoverImage.fromSong(
                    song: song,
                    width: 50,
                    height: 50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  title: Text(song.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(song.author, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color), maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: AppTheme.redAccent),
                    onPressed: () async {
                      await ref.read(downloadedSongsProvider.notifier).delete(song.videoId);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('deleted_download')), backgroundColor: AppTheme.redAccent));
                      }
                    },
                  ),
                  onTap: () {
                    audioHandler.playSongList(downloadedSongs, initialIndex: index);
                  },
                );
              },
            ),
    );
  }
}
