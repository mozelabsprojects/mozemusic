import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import '../../models/playlist.dart';
import '../../services/audio_handler.dart';
import '../../services/firestore_service.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../models/song.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../features/settings/controllers/settings_controller.dart';
import 'song_menu_bottom_sheet.dart';
import '../player/main_player_screen.dart';
import '../desktop/components/desktop_song_context_menu.dart';

class PlaylistDetailsScreen extends ConsumerStatefulWidget {
  final Playlist playlist;
  final bool isReadOnly;

  const PlaylistDetailsScreen({
    super.key,
    required this.playlist,
    this.isReadOnly = false,
  });

  @override
  ConsumerState<PlaylistDetailsScreen> createState() => _PlaylistDetailsScreenState();
}

class _PlaylistDetailsScreenState extends ConsumerState<PlaylistDetailsScreen> {
  late List<Song> _songs;
  String? _coverUrl;
  bool _isUploading = false;
  bool _isPublic = true;

  @override
  void initState() {
    super.initState();
    _songs = List.from(widget.playlist.songs);
    _coverUrl = widget.playlist.coverUrl;
    _isPublic = widget.playlist.isPublic;
  }

  Future<void> _pickAndUploadCover() async {
    final scaffoldColor = Theme.of(context).scaffoldBackgroundColor;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      if (!context.mounted) return;
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: ref.read(locProvider).get('rename_playlist'),
            toolbarColor: scaffoldColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            lockAspectRatio: true,
          ),
          IOSUiSettings(
            title: 'Crop Playlist Cover',
            aspectRatioLockEnabled: true,
            resetAspectRatioEnabled: false,
          ),
        ],
      );

      if (croppedFile != null) {
        setState(() => _isUploading = true);
        final file = File(croppedFile.path);
        final newUrl = await ref.read(firestoreServiceProvider).uploadPlaylistCover(widget.playlist.playlistId, file);
        
        if (newUrl != null) {
          setState(() => _coverUrl = newUrl);
        }
        setState(() => _isUploading = false);
      }
    }
  }

  void _onReorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    setState(() {
      final item = _songs.removeAt(oldIndex);
      _songs.insert(newIndex, item);
    });
    ref.read(firestoreServiceProvider).updatePlaylistOrder(widget.playlist.playlistId, _songs);
  }

  @override
  Widget build(BuildContext context) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final loc = ref.watch(locProvider);
    final downloadedSongs = ref.watch(downloadedSongsProvider);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            flexibleSpace: FlexibleSpaceBar(
              title: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.playlist.title, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4)])),
                  if (!widget.isReadOnly)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_isPublic ? Icons.public : Icons.lock, size: 10, color: Colors.white70),
                        const SizedBox(width: 4),
                        Text(_isPublic ? ref.read(locProvider).get('public') : ref.read(locProvider).get('private'), style: const TextStyle(color: Colors.white70, fontSize: 10)),
                      ],
                    ),
                ],
              ),
              background: GestureDetector(
                onTap: widget.isReadOnly ? null : _pickAndUploadCover,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (_coverUrl != null && _coverUrl!.isNotEmpty)
                      CachedNetworkImage(imageUrl: _coverUrl!, fit: BoxFit.cover)
                    else
                      Container(color: Theme.of(context).cardColor, child: const Icon(Icons.music_note, size: 80, color: Colors.grey)),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.7)],
                        ),
                      ),
                    ),
                    if (_isUploading)
                      const Center(child: CircularProgressIndicator(color: AppTheme.redAccent)),
                    if (!widget.isReadOnly)
                      Positioned(
                        bottom: 16,
                        right: 16,
                        child: SafeArea(
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.edit, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actions: [
              if (!widget.isReadOnly)
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  onSelected: (value) async {
                    if (value == 'download_all') {
                      final quality = ref.read(settingsProvider).downloadQuality;
                      for (var song in _songs) {
                        ref.read(downloadedSongsProvider.notifier).download(song, quality);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Downloading all songs...'), backgroundColor: Theme.of(context).cardColor));
                    } else if (value == 'remove_downloads') {
                      for (var song in _songs) {
                        ref.read(downloadedSongsProvider.notifier).delete(song.videoId);
                      }
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed downloads'), backgroundColor: Theme.of(context).cardColor));
                    } else if (value == 'rename') {
                    final controller = TextEditingController(text: widget.playlist.title);
                    final newName = await showDialog<String>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        title: Text('Rename Playlist', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                        content: TextField(
                          controller: controller,
                          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                          decoration: InputDecoration(
                            hintText: 'Playlist Name',
                            hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                          ),
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(loc.get('cancel'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redAccent),
                            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                            child: Text(loc.get('save'), style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (newName != null && newName.isNotEmpty) {
                      await ref.read(firestoreServiceProvider).updatePlaylistName(widget.playlist.playlistId, newName);
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${loc.get('playlist_renamed')} $newName'), backgroundColor: Theme.of(context).cardColor));
                    }
                  } else if (value == 'delete') {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        title: Text(loc.get('delete_playlist_confirm'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.get('cancel'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redAccent),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(loc.get('delete'), style: const TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(firestoreServiceProvider).deletePlaylist(widget.playlist.playlistId);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  } else if (value == 'toggle_visibility') {
                    final newVisibility = !_isPublic;
                    setState(() { _isPublic = newVisibility; });
                    await ref.read(firestoreServiceProvider).togglePlaylistVisibility(widget.playlist.playlistId, newVisibility);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newVisibility ? loc.get('playlist_is_now_public') : loc.get('playlist_is_now_private')), backgroundColor: Theme.of(context).cardColor));
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'download_all',
                    child: Text(loc.get('download_all'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),
                  PopupMenuItem<String>(
                    value: 'remove_downloads',
                    child: Text(loc.get('remove_downloads'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),
                  PopupMenuItem<String>(
                    value: 'rename',
                    child: Text(loc.get('rename_playlist'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),
                  PopupMenuItem<String>(
                    value: 'toggle_visibility',
                    child: Text(_isPublic ? loc.get('make_private') : loc.get('make_public'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),
                  PopupMenuItem<String>(
                    value: 'delete',
                    child: Text(loc.get('delete_playlist'), style: const TextStyle(color: AppTheme.redAccent)),
                  ),
                ],
              ),
            ],
          ),
          SliverFillRemaining(
            child: _songs.isEmpty
                ? Center(
                    child: Text(
                      loc.get('playlist_is_empty'),
                      style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 16),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: _songs.length,
                    onReorderItem: _onReorder,
              itemBuilder: (context, index) {
                final song = _songs[index];
                final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);
                return Dismissible(
                  key: ValueKey('${song.videoId}_$index'),
                  direction: widget.isReadOnly ? DismissDirection.none : DismissDirection.endToStart,
                  onDismissed: (_) {
                    setState(() {
                      _songs.removeAt(index);
                    });
                    ref.read(firestoreServiceProvider).removeSongFromPlaylist(widget.playlist.playlistId, song.videoId);
                  },
                  background: Container(
                    color: AppTheme.redAccent,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: GestureDetector(
                    onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                      context: context,
                      position: details.globalPosition,
                      song: song,
                      ref: ref,
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: SongCoverImage.fromSong(
                        song: song,
                        width: 50,
                        height: 50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: Text(song.title, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Row(
                        children: [
                          if (isDownloaded) ...[
                            const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                            const SizedBox(width: 4),
                          ],
                          Expanded(
                            child: Text(
                              song.author,
                              style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.more_vert, color: AppTheme.textSecondary),
                            onPressed: () {
                              showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (context) => SongMenuBottomSheet(song: song),
                              );
                            },
                          ),
                          if (!widget.isReadOnly)
                            ReorderableDragStartListener(
                              index: index,
                              child: const Icon(Icons.drag_handle, color: AppTheme.textSecondary),
                            ),
                        ],
                      ),
                      onTap: () {
                        audioHandler.playSongList(_songs, initialIndex: index);
                        final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
                        if (!isDesktop) {
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const MainPlayerScreen()));
                        }
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Colors.transparent,
                          isScrollControlled: true,
                          builder: (context) => SongMenuBottomSheet(song: song),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: widget.isReadOnly
          ? FloatingActionButton.extended(
              backgroundColor: AppTheme.redAccent,
              onPressed: () async {
                await ref.read(firestoreServiceProvider).clonePlaylist(widget.playlist);
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loc.get('saved_to_library')), backgroundColor: AppTheme.redAccent));
              },
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(loc.get('save'), style: const TextStyle(color: Colors.white)),
            )
          : (_songs.isNotEmpty
              ? FloatingActionButton(
                  backgroundColor: AppTheme.redAccent,
                  child: const Icon(Icons.play_arrow, color: Colors.white),
                  onPressed: () async {
                    if (_songs.isEmpty) return;
                    await audioHandler.playSongList(_songs, initialIndex: 0);
                    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
                    if (!isDesktop && context.mounted) {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MainPlayerScreen()));
                    }
                  },
                )
              : null),
    );
  }
}
