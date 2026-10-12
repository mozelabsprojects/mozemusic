import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../core/theme/app_theme.dart';
import '../../services/firestore_service.dart';
import '../../services/audio_handler.dart';
import '../../models/song.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../models/playlist.dart';
import '../../core/localization/app_localizations.dart';
import 'playlist_details_screen.dart';
import 'song_menu_bottom_sheet.dart';
import '../settings/downloads_screen.dart';
import '../../services/download_service.dart';
import '../desktop/components/desktop_song_context_menu.dart';

class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedSongs = ref.watch(likedSongsProvider);
    final userPlaylists = ref.watch(userPlaylistsProvider);
    final downloadedSongs = ref.watch(downloadedSongsProvider);
    final loc = ref.watch(locProvider);
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(loc.get('your_library'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppTheme.redAccent,
          backgroundColor: Theme.of(context).cardColor,
          onRefresh: () async {
            ref.invalidate(likedSongsProvider);
            ref.invalidate(userPlaylistsProvider);
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // Quick Access Cards: Liked Songs & Downloads
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      // Downloads Card
                      Expanded(
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const DownloadsScreen()),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: Theme.of(context).dividerColor.withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    gradient: const LinearGradient(
                                      colors: [AppTheme.neonGreen, Color(0xFF00B4D8)],
                                    ),
                                  ),
                                  child: const Icon(Icons.download_done_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        loc.get('downloads'),
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                          color: Theme.of(context).textTheme.bodyLarge?.color,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${downloadedSongs.length} ${loc.get('songs')}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Theme.of(context).textTheme.bodyMedium?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Playlists Section
              SliverToBoxAdapter(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(loc.get('playlists'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () {
                              _showCreatePlaylistDialog(context, ref, loc);
                            },
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      height: 140,
                      child: userPlaylists.when(
                        data: (playlists) {
                          if (playlists.isEmpty) {
                            return Center(child: Text(loc.get('no_playlists_yet'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)));
                          }
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final playlist = playlists[index];
                              return _PlaylistDragTarget(playlist: playlist);
                            },
                          );
                        },
                        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.redAccent)),
                        error: (e, st) => Center(child: Text('Error loading playlists', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),

              // Liked Songs Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(loc.get('liked_songs'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
                      likedSongs.maybeWhen(
                        data: (songs) => songs.isNotEmpty
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.shuffle_rounded, size: 20),
                                    tooltip: 'Karışık Çal',
                                    onPressed: () async {
                                      final handler = ref.read(audioHandlerProvider);
                                      await handler.setShuffleMode(AudioServiceShuffleMode.all);
                                      await handler.playSongList(songs, initialIndex: 0);
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.play_circle_fill_rounded, size: 28, color: AppTheme.redAccent),
                                    tooltip: 'Tümünü Çal',
                                    onPressed: () async {
                                      final handler = ref.read(audioHandlerProvider);
                                      await handler.setShuffleMode(AudioServiceShuffleMode.none);
                                      await handler.playSongList(songs, initialIndex: 0);
                                    },
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                        orElse: () => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              ),

              // Liked Songs List
              likedSongs.when(
                data: (songs) {
                  if (songs.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 64.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.library_music, size: 64, color: Theme.of(context).cardColor),
                            const SizedBox(height: 16),
                            Text(loc.get('no_liked_songs_yet'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 18, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(loc.get('songs_you_like_appear_here'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                          ],
                        ),
                      ),
                    );
                  }
                  return SliverPadding(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final song = songs[index];
                          return LongPressDraggable<Song>(
                            data: song,
                            delay: const Duration(milliseconds: 300),
                            feedback: Material(
                              color: Colors.transparent,
                              child: Opacity(
                                opacity: 0.8,
                                child: Container(
                                  width: MediaQuery.of(context).size.width - 32,
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)
                                    ]
                                  ),
                                  child: ListTile(
                                    leading: SongCoverImage.fromSong(
                                      song: song,
                                      width: 50,
                                      height: 50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    title: Text(song.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold), maxLines: 1),
                                  ),
                                ),
                              ),
                            ),
                            childWhenDragging: Opacity(
                              opacity: 0.3,
                              child: _buildSongTile(context, ref, song, loc, songs: songs, index: index),
                            ),
                            child: _buildSongTile(context, ref, song, loc, songs: songs, index: index),
                          );
                        },
                        childCount: songs.length,
                      ),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator(color: AppTheme.redAccent))),
                error: (e, st) => SliverToBoxAdapter(child: Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.redAccent)))),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSongTile(
    BuildContext context,
    WidgetRef ref,
    Song song,
    AppLocalizations loc, {
    List<Song>? songs,
    int? index,
  }) {
    return GestureDetector(
      onSecondaryTapUp: (details) {
        showDesktopSongContextMenu(
          context: context,
          position: details.globalPosition,
          song: song,
          ref: ref,
          songList: songs,
          index: index,
        );
      },
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: SongCoverImage.fromSong(
          song: song,
          width: 56,
          height: 56,
          borderRadius: BorderRadius.circular(4),
        ),
        title: Text(song.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(song.author, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.favorite, color: AppTheme.redAccent),
              onPressed: () {
                ref.read(firestoreServiceProvider).toggleLikeSong(song, true);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${loc.get('remove_from_liked_songs')}: "${song.title}"'),
                    backgroundColor: Theme.of(context).cardColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: Theme.of(context).iconTheme.color),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (_) => SongMenuBottomSheet(song: song),
                );
              },
            ),
          ],
        ),
        onTap: () async {
          final handler = ref.read(audioHandlerProvider);

          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(child: Text('${loc.get('loading')} ${song.title}', maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
              ),
              duration: const Duration(seconds: 10),
              backgroundColor: Theme.of(context).cardColor,
            ),
          );

          final String result;
          if (songs != null && songs.isNotEmpty && index != null) {
            result = await handler.playSongList(songs, initialIndex: index);
          } else {
            final mediaItem = MediaItem(
              id: song.videoId,
              title: song.title,
              artist: song.author,
              artUri: Uri.parse(song.thumbnailUrl),
              duration: Duration(milliseconds: song.durationMs),
            );
            result = await handler.playFromVideoId(song.videoId, mediaItem: mediaItem);
          }
          if (!context.mounted) return;

          ScaffoldMessenger.of(context).clearSnackBars();

          if (result != 'Success' && result != 'Cancelled') {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(loc.get('playback_error')),
                content: Text(result),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(loc.get('ok')),
                  )
                ],
              ),
            );
          }
        },
      ),
    );
  }

  void _showCreatePlaylistDialog(BuildContext context, WidgetRef ref, AppLocalizations loc) {
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
                  await ref.read(firestoreServiceProvider).createPlaylist(name, '');
                  if (context.mounted) Navigator.pop(context);
                }
              },
              child: Text(loc.get('create'), style: const TextStyle(color: AppTheme.redAccent)),
            ),
          ],
        );
      },
    );
  }
}

class _PlaylistDragTarget extends ConsumerWidget {
  final Playlist playlist;

  const _PlaylistDragTarget({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(locProvider);

    return DragTarget<Song>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        final song = details.data;
        await ref.read(firestoreServiceProvider).addSongToPlaylist(playlist.playlistId, song);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${loc.get('added_to')} ${playlist.title}'),
            backgroundColor: AppTheme.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      },
      builder: (context, candidateData, rejectedData) {
        final isHovered = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => PlaylistDetailsScreen(playlist: playlist)));
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 100,
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isHovered ? AppTheme.redAccent : Colors.transparent,
                width: 2,
              ),
              boxShadow: isHovered
                  ? [BoxShadow(color: AppTheme.redAccent.withValues(alpha: 0.5), blurRadius: 10)]
                  : [],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: playlist.coverUrl.isNotEmpty
                      ? CachedNetworkImage(imageUrl: playlist.coverUrl, width: 100, height: 100, fit: BoxFit.cover)
                      : Container(
                          width: 100, height: 100, color: Theme.of(context).cardColor,
                          child: const Icon(Icons.music_note, color: Colors.grey, size: 40),
                        ),
                ),
                const SizedBox(height: 8),
                Text(
                  playlist.title,
                  style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
