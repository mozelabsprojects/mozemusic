import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:audio_service/audio_service.dart';

import '../../models/song.dart';
import '../../services/audio_handler.dart';
import '../../services/firestore_service.dart';
import '../../services/download_service.dart';
import '../../features/settings/controllers/settings_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/playlist.dart';
import '../player/queue_screen.dart';

class SongMenuBottomSheet extends ConsumerWidget {
  final Song song;
  final bool showQueueOption;

  const SongMenuBottomSheet({super.key, required this.song, this.showQueueOption = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final firestore = ref.watch(firestoreServiceProvider);
    final likedSongsStream = ref.watch(likedSongsProvider);
    final isLiked = likedSongsStream.value?.any((s) => s.videoId == song.videoId) ?? false;
    final downloadedSongs = ref.watch(downloadedSongsProvider);
    final isDownloaded = downloadedSongs.any((s) => s.videoId == song.videoId);
    final loc = ref.watch(locProvider);
    final settings = ref.watch(settingsProvider);

    return Container(
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CachedNetworkImage(
                  imageUrl: song.thumbnailUrl,
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: Theme.of(context).dividerColor,
                    child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: Theme.of(context).dividerColor,
                    child: const Icon(Icons.music_note, color: Colors.grey, size: 24),
                  ),
                ),
              ),
              title: Text(song.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold), maxLines: 1),
              subtitle: Text(song.author, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color), maxLines: 1),
            ),
            const Divider(color: Colors.grey),
            if (showQueueOption)
              ListTile(
                leading: const Icon(Icons.queue_music, color: AppTheme.textSecondary),
                title: Text(loc.get('up_next'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const QueueScreen()));
                },
              ),
            ListTile(
              leading: const Icon(Icons.playlist_play, color: AppTheme.textSecondary),
              title: Text(loc.get('play_next'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () async {
                final item = MediaItem(
                  id: song.videoId,
                  title: song.title,
                  artist: song.author,
                  artUri: Uri.parse(song.thumbnailUrl),
                  duration: Duration(milliseconds: song.durationMs),
                );
                // Insert right after current item
                final queue = audioHandler.queue.value;
                int currentIndex = 0;
                final currentItem = audioHandler.mediaItem.value;
                if (currentItem != null) {
                  final idx = queue.indexWhere((q) => q.id == currentItem.id);
                  if (idx >= 0) currentIndex = idx;
                }
                await audioHandler.insertQueueItem(currentIndex + 1, item);
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('will_play_next')), backgroundColor: AppTheme.redAccent));
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music, color: AppTheme.textSecondary),
              title: Text(loc.get('add_to_queue'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () {
                final item = MediaItem(
                  id: song.videoId,
                  title: song.title,
                  artist: song.author,
                  artUri: Uri.parse(song.thumbnailUrl),
                  duration: Duration(milliseconds: song.durationMs),
                );
                audioHandler.addQueueItem(item);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('added_to_queue')), backgroundColor: AppTheme.redAccent));
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add, color: AppTheme.textSecondary),
              title: Text(loc.get('add_to_playlist'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  isScrollControlled: true,
                  builder: (context) => _PlaylistSelectionSheet(song: song),
                );
              },
            ),
            ListTile(
              leading: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: AppTheme.redAccent),
              title: Text(isLiked ? loc.get('remove_from_liked_songs') : loc.get('add_to_liked_songs'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () async {
                Navigator.pop(context);
                await firestore.toggleLikeSong(song, isLiked);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(isLiked ? '${loc.get('remove_from_liked_songs')}: "${song.title}"' : '${loc.get('add_to_liked_songs')}: "${song.title}"'), backgroundColor: AppTheme.redAccent));
              },
            ),
            ListTile(
              leading: Icon(isDownloaded ? Icons.download_done : Icons.download, color: isDownloaded ? AppTheme.neonGreen : AppTheme.textSecondary),
              title: Text(isDownloaded ? loc.get('downloaded') : loc.get('download'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () async {
                Navigator.pop(context);
                if (isDownloaded) {
                  // already downloaded
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('already_downloaded')), backgroundColor: AppTheme.neonGreen));
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('downloading')), backgroundColor: AppTheme.textSecondary));
                try {
                  await ref.read(downloadedSongsProvider.notifier).download(song, settings.downloadQuality);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('download_complete')), backgroundColor: AppTheme.neonGreen));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.get('download_failed')} $e'), backgroundColor: AppTheme.redAccent));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.share, color: AppTheme.textSecondary),
              title: Text(loc.get('share'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('https://youtube.com/watch?v=${song.videoId}'), backgroundColor: AppTheme.redAccent));
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaylistSelectionSheet extends ConsumerWidget {
  final Song song;
  const _PlaylistSelectionSheet({required this.song});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firestore = ref.watch(firestoreServiceProvider);
    final loc = ref.watch(locProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          color: Theme.of(context).cardColor,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(loc.get('add_to_playlist'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                    IconButton(
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) {
                            final controller = TextEditingController();
                            return AlertDialog(
                              backgroundColor: Theme.of(context).cardColor,
                              title: Text(loc.get('new_playlist'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                              content: TextField(
                                controller: controller,
                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                                decoration: InputDecoration(
                                  hintText: loc.get('playlist_name'),
                                  hintStyle: const TextStyle(color: AppTheme.textSecondary),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: Text(loc.get('cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    final name = controller.text.trim();
                                    if (name.isNotEmpty) {
                                      await firestore.createPlaylist(name, '');
                                      if (context.mounted) Navigator.pop(context);
                                    }
                                  },
                                  child: Text(loc.get('create'), style: const TextStyle(color: AppTheme.redAccent)),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: StreamBuilder<List<Playlist>>(
                  stream: firestore.getUserPlaylists(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator(color: AppTheme.redAccent));
                    }
                    final playlists = snapshot.data ?? [];
                    if (playlists.isEmpty) {
                      return Center(child: Text(loc.get('no_playlists_found'), style: const TextStyle(color: AppTheme.textSecondary)));
                    }
                    return ListView.builder(
                      controller: controller,
                      itemCount: playlists.length,
                      itemBuilder: (context, index) {
                        final p = playlists[index];
                        return ListTile(
                          leading: Container(
                            width: 50, height: 50,
                            color: Colors.grey.withValues(alpha: 0.2),
                            child: p.coverUrl.isNotEmpty
                                ? CachedNetworkImage(imageUrl: p.coverUrl, fit: BoxFit.cover)
                                : const Icon(Icons.music_note, color: Colors.grey),
                          ),
                          title: Text(p.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                          subtitle: Text('${p.songs.length} songs', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                          onTap: () async {
                            await firestore.addSongToPlaylist(p.playlistId, song);
                            if (!context.mounted) return;
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.get('added_to')} ${p.title}'), backgroundColor: AppTheme.redAccent));
                          },
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
