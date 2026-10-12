import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/audio_handler.dart';
import '../../../common_widgets/song_cover_image.dart';

final desktopQueueVisibleProvider = NotifierProvider<DesktopQueueVisibleNotifier, bool>(
  DesktopQueueVisibleNotifier.new,
);

class DesktopQueueVisibleNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void set(bool value) => state = value;
}

/// Desktop Queue & Playback Order Panel (Right Sidebar).
/// Features:
/// - "Now Playing" live banner
/// - Prominent "Up Next" preview card
/// - Drag-and-drop reorderable list
/// - Hover removal buttons
/// - Direct play from queue
class DesktopQueuePanel extends ConsumerWidget {
  const DesktopQueuePanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 360,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F0F) : const Color(0xFFF7F7F7),
        border: Border(
          left: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 12, 10),
            child: Row(
              children: [
                const Icon(Icons.queue_music_rounded, color: AppTheme.redAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Çalma Sırası',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(width: 8),
                StreamBuilder<List<MediaItem>>(
                  stream: audioHandler.queue,
                  builder: (context, snap) {
                    final queue = snap.data ?? audioHandler.queue.value;
                    if (queue.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${queue.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.redAccent,
                        ),
                      ),
                    );
                  },
                ),
                const Spacer(),
                StreamBuilder<List<MediaItem>>(
                  stream: audioHandler.queue,
                  builder: (context, snap) {
                    final queue = snap.data ?? audioHandler.queue.value;
                    if (queue.isEmpty) return const SizedBox.shrink();
                    return TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () => audioHandler.clearQueue(),
                      child: Text(
                        'Temizle',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(6),
                    onTap: () {
                      ref.read(desktopQueueVisibleProvider.notifier).set(false);
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

          const Divider(height: 1),

          // 2. Now Playing
          StreamBuilder<MediaItem?>(
            stream: audioHandler.mediaItem,
            builder: (context, snap) {
              final current = snap.data ?? audioHandler.mediaItem.value;
              if (current == null) return const SizedBox.shrink();

              return Container(
                margin: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF181818) : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.neonGreen.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.volume_up_rounded, color: AppTheme.neonGreen, size: 14),
                        const SizedBox(width: 6),
                        const Text(
                          'ŞU AN ÇALIYOR',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: AppTheme.neonGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        SongCoverImage(
                          imageUrl: current.artUri?.toString(),
                          videoId: current.id,
                          width: 46,
                          height: 46,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.title,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : Colors.black,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                current.artist ?? 'Bilinmeyen Sanatçı',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.6)
                                      : Colors.black.withValues(alpha: 0.6),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),

          // 3. Queue List / Upcoming Songs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sırada Çalacaklar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : Colors.black87,
                  ),
                ),
                Text(
                  'Sürükleyerek sırala',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : Colors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<MediaItem>>(
              stream: audioHandler.queue,
              builder: (context, queueSnap) {
                final queue = queueSnap.data ?? audioHandler.queue.value;
                final currentItem = audioHandler.mediaItem.value;

                if (queue.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.queue_music_rounded,
                            size: 40,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Sırada şarkı yok',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white60 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sağ tıkla "Sıraya Ekle" diyerek şarkı ekleyebilirsiniz',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white30 : Colors.black38,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return ReorderableListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  itemCount: queue.length,
                  // ignore: deprecated_member_use
                  onReorder: (oldIndex, newIndex) {
                    audioHandler.moveQueueItem(oldIndex, newIndex);
                  },
                  itemBuilder: (context, index) {
                    final item = queue[index];
                    final isCurrent = currentItem?.id == item.id;
                    final isUpNext = !isCurrent && (
                      (currentItem != null && index == (queue.indexWhere((q) => q.id == currentItem.id) + 1)) ||
                      (currentItem == null && index == 0)
                    );

                    return Padding(
                      key: ValueKey('desktop_q_${item.id}_$index'),
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: _buildQueueTile(
                        item: item,
                        index: index,
                        isCurrent: isCurrent,
                        isUpNext: isUpNext,
                        isDark: isDark,
                        handler: audioHandler,
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
  }

  Widget _buildQueueTile({
    required MediaItem item,
    required int index,
    required bool isCurrent,
    required bool isUpNext,
    required bool isDark,
    required MozeAudioHandler handler,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: isCurrent
            ? null
            : () => handler.playFromVideoId(item.id, mediaItem: item, updateQueue: false),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isCurrent
                ? (isDark
                    ? AppTheme.neonGreen.withValues(alpha: 0.12)
                    : AppTheme.neonGreen.withValues(alpha: 0.08))
                : (isUpNext
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.04)
                        : Colors.black.withValues(alpha: 0.03))
                    : Colors.transparent),
            border: isUpNext
                ? Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : Colors.black.withValues(alpha: 0.06),
                    width: 1,
                  )
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${index + 1}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? AppTheme.neonGreen
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SongCoverImage(
                imageUrl: item.artUri?.toString(),
                videoId: item.id,
                width: 38,
                height: 38,
                borderRadius: BorderRadius.circular(6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (isUpNext) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            margin: const EdgeInsets.only(right: 5),
                            decoration: BoxDecoration(
                              color: AppTheme.redAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(3),
                            ),
                            child: const Text(
                              'SIRADA',
                              style: TextStyle(
                                color: AppTheme.redAccent,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: isCurrent || isUpNext ? FontWeight.w700 : FontWeight.w500,
                              color: isCurrent
                                  ? AppTheme.neonGreen
                                  : (isDark ? Colors.white : Colors.black),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.artist ?? 'Bilinmeyen Sanatçı',
                      style: TextStyle(
                        fontSize: 11,
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
              // Delete Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(4),
                  onTap: () => handler.removeQueueItemAt(index),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      Icons.close_rounded,
                      size: 15,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              // Drag Handle
              Icon(
                Icons.drag_handle_rounded,
                size: 16,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.25)
                    : Colors.black.withValues(alpha: 0.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
