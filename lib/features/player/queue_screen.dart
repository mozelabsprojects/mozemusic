import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import '../../services/audio_handler.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';

/// A rich, interactive Queue & Song List Manager.
/// Features:
/// - "Now Playing" live banner
/// - Prominent "Up Next" preview
/// - Drag-and-drop reordering
/// - Direct removal & swipe-to-dismiss
/// - Synchronized across Mobile & Desktop
class QueueScreen extends ConsumerWidget {
  const QueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioHandler = ref.watch(audioHandlerProvider);
    final loc = ref.watch(locProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: StreamBuilder<List<MediaItem>>(
          stream: audioHandler.queue,
          builder: (context, snap) {
            final count = snap.data?.length ?? audioHandler.queue.value.length;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  loc.get('queue'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                    fontSize: 18,
                  ),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.redAccent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '$count',
                      style: const TextStyle(
                        color: AppTheme.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: false,
        actions: [
          StreamBuilder<List<MediaItem>>(
            stream: audioHandler.queue,
            builder: (context, snap) {
              final queue = snap.data ?? audioHandler.queue.value;
              if (queue.isEmpty) return const SizedBox.shrink();
              return TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.redAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                icon: const Icon(Icons.clear_all_rounded, size: 18),
                label: Text(
                  loc.get('clear_queue'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  audioHandler.clearQueue();
                },
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<MediaItem>>(
          stream: audioHandler.queue,
          builder: (context, queueSnap) {
            final queue = queueSnap.data ?? audioHandler.queue.value;

            return StreamBuilder<MediaItem?>(
              stream: audioHandler.mediaItem,
              builder: (context, mediaSnap) {
                final currentItem = mediaSnap.data ?? audioHandler.mediaItem.value;

                if (queue.isEmpty && currentItem == null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.queue_music_rounded, size: 40, color: AppTheme.textSecondary),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          loc.get('queue_is_empty'),
                          style: TextStyle(
                            color: Theme.of(context).textTheme.bodyLarge?.color,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          loc.get('autoplay_on'),
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      ],
                    ),
                  );
                }

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // 1. Now Playing Section
                    if (currentItem != null)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.volume_up_rounded, color: AppTheme.neonGreen, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    loc.get('now_playing').toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.neonGreen,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppTheme.neonGreen.withValues(alpha: 0.3),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.neonGreen.withValues(alpha: 0.08),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    SongCoverImage(
                                      imageUrl: currentItem.artUri?.toString(),
                                      videoId: currentItem.id,
                                      width: 52,
                                      height: 52,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            currentItem.title,
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14.5,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            currentItem.artist ?? loc.get('unknown'),
                                            style: const TextStyle(
                                              color: AppTheme.textSecondary,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: AppTheme.neonGreen.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.equalizer_rounded, color: AppTheme.neonGreen, size: 16),
                                          SizedBox(width: 4),
                                          Text(
                                            'Çalıyor',
                                            style: TextStyle(
                                              color: AppTheme.neonGreen,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // 2. Queue Header & Drag Instructions
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              loc.get('next_in_queue'),
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              loc.get('drag_to_reorder'),
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // 3. Reorderable Queue List
                    if (queue.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(32.0),
                          child: Center(
                            child: Text(
                              loc.get('queue_is_empty'),
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverReorderableList(
                        itemCount: queue.length,
                        // ignore: deprecated_member_use
                        onReorder: (oldIndex, newIndex) {
                          HapticFeedback.mediumImpact();
                          audioHandler.moveQueueItem(oldIndex, newIndex);
                        },
                        itemBuilder: (context, index) {
                          final item = queue[index];
                          final isCurrentlyActive = currentItem?.id == item.id;
                          final isUpNext = !isCurrentlyActive && (
                            (currentItem != null && index == (queue.indexWhere((q) => q.id == currentItem.id) + 1)) ||
                            (currentItem == null && index == 0)
                          );

                          return Dismissible(
                            key: ValueKey('queue_${item.id}_$index'),
                            direction: DismissDirection.endToStart,
                            background: Container(
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              color: AppTheme.redAccent,
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.white, size: 22),
                                  SizedBox(width: 6),
                                  Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                            onDismissed: (_) {
                              HapticFeedback.lightImpact();
                              audioHandler.removeQueueItemAt(index);
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${item.title} sıradan kaldırıldı'),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            child: ReorderableDelayedDragStartListener(
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                decoration: BoxDecoration(
                                  color: isCurrentlyActive
                                      ? AppTheme.neonGreen.withValues(alpha: 0.08)
                                      : (isUpNext
                                          ? (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03))
                                          : Colors.transparent),
                                  borderRadius: BorderRadius.circular(12),
                                  border: isUpNext
                                      ? Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1)
                                      : null,
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                  leading: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      SizedBox(
                                        width: 24,
                                        child: Text(
                                          '${index + 1}',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: isCurrentlyActive
                                                ? AppTheme.neonGreen
                                                : AppTheme.textSecondary,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      SongCoverImage(
                                        imageUrl: item.artUri?.toString(),
                                        videoId: item.id,
                                        width: 44,
                                        height: 44,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ],
                                  ),
                                  title: Row(
                                    children: [
                                      if (isUpNext) ...[
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                          margin: const EdgeInsets.only(right: 6),
                                          decoration: BoxDecoration(
                                            color: AppTheme.redAccent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            loc.get('up_next').toUpperCase(),
                                            style: const TextStyle(
                                              color: AppTheme.redAccent,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ],
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            color: isCurrentlyActive
                                                ? AppTheme.neonGreen
                                                : Theme.of(context).textTheme.bodyLarge?.color,
                                            fontWeight: isCurrentlyActive || isUpNext
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            fontSize: 13.5,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    item.artist ?? loc.get('unknown'),
                                    style: const TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11.5,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Instant Delete Button
                                      IconButton(
                                        icon: const Icon(Icons.close_rounded, size: 18),
                                        color: AppTheme.textSecondary,
                                        tooltip: 'Sıradan Çıkar',
                                        onPressed: () {
                                          HapticFeedback.lightImpact();
                                          audioHandler.removeQueueItemAt(index);
                                        },
                                      ),
                                      // Drag Handle
                                      const Icon(
                                        Icons.drag_handle_rounded,
                                        color: AppTheme.textSecondary,
                                        size: 20,
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    audioHandler.playFromVideoId(
                                      item.id,
                                      mediaItem: item,
                                      updateQueue: false,
                                    );
                                  },
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    const SliverToBoxAdapter(
                      child: SizedBox(height: 60),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
