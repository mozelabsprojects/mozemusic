import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../models/song.dart';
import '../../../services/audio_handler.dart';
import '../../../services/firestore_service.dart';
import '../../library/song_menu_bottom_sheet.dart';

Future<void> showDesktopSongContextMenu({
  required BuildContext context,
  required Offset position,
  required Song song,
  required WidgetRef ref,
  List<Song>? songList,
  int? index,
}) async {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final loc = ref.read(locProvider);
  final handler = ref.read(audioHandlerProvider);
  final firestore = ref.read(firestoreServiceProvider);
  final likedSongs = ref.read(likedSongsProvider).value ?? [];
  final isLiked = likedSongs.any((s) => s.videoId == song.videoId);

  final selected = await showMenu<String>(
    context: context,
    position: RelativeRect.fromLTRB(
      position.dx,
      position.dy,
      position.dx + 1,
      position.dy + 1,
    ),
    color: isDark ? const Color(0xFF282828) : const Color(0xFFFFFFFF),
    elevation: 8,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    items: [
      PopupMenuItem(
        value: 'play',
        child: Row(
          children: [
            Icon(Icons.play_arrow_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text(loc.get('play'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'play_next',
        child: Row(
          children: [
            Icon(Icons.playlist_play_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text(loc.get('play_next'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'add_to_queue',
        child: Row(
          children: [
            Icon(Icons.queue_music_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text(loc.get('add_to_queue'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
          ],
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem(
        value: 'toggle_like',
        child: Row(
          children: [
            Icon(
              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 20,
              color: isLiked ? AppTheme.redAccent : (isDark ? Colors.white : Colors.black),
            ),
            const SizedBox(width: 12),
            Text(
              isLiked ? loc.get('remove_from_liked_songs') : loc.get('add_to_liked_songs'),
              style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'add_to_playlist',
        child: Row(
          children: [
            Icon(Icons.playlist_add_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text(loc.get('add_to_playlist'), style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'copy_link',
        child: Row(
          children: [
            Icon(Icons.link_rounded, size: 20, color: isDark ? Colors.white : Colors.black),
            const SizedBox(width: 12),
            Text('Copy Link', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13)),
          ],
        ),
      ),
    ],
  );

  if (selected == null || !context.mounted) return;

  final item = MediaItem(
    id: song.videoId,
    title: song.title,
    artist: song.author,
    artUri: Uri.parse(song.thumbnailUrl),
    duration: Duration(milliseconds: song.durationMs),
  );

  switch (selected) {
    case 'play':
      if (songList != null && songList.isNotEmpty && index != null) {
        await handler.playSongList(songList, initialIndex: index);
      } else {
        await handler.playFromVideoId(song.videoId, mediaItem: item);
      }
      break;
    case 'play_next':
      final queue = handler.queue.value;
      int currentIndex = 0;
      final currentItem = handler.mediaItem.value;
      if (currentItem != null) {
        final idx = queue.indexWhere((q) => q.id == currentItem.id);
        if (idx >= 0) currentIndex = idx;
      }
      await handler.insertQueueItem(currentIndex + 1, item);
      break;
    case 'add_to_queue':
      await handler.addQueueItem(item);
      break;
    case 'toggle_like':
      await firestore.toggleLikeSong(song, isLiked);
      break;
    case 'add_to_playlist':
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (_) => SongMenuBottomSheet(song: song),
      );
      break;
    case 'copy_link':
      await Clipboard.setData(ClipboardData(text: 'https://youtube.com/watch?v=${song.videoId}'));
      break;
  }
}
