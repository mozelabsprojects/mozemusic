import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'search_controller.dart';
import '../library/song_menu_bottom_sheet.dart';
import '../../services/audio_handler.dart';
import '../../services/firestore_service.dart';
import '../../services/download_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/song.dart';
import '../../common_widgets/song_cover_image.dart';
import '../../services/history_service.dart';
import '../desktop/components/desktop_song_context_menu.dart';
import '../../core/localization/app_localizations.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FocusNode _searchFocusNode = FocusNode();
  final TextEditingController _searchTextController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchFocusNode.dispose();
    _searchTextController.dispose();
    super.dispose();
  }

  Future<void> _playSong(Song song, {List<Song>? contextList, int? index}) async {
    FocusScope.of(context).unfocus();

    final handler = ref.read(audioHandlerProvider);

    if (!mounted) return;
    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (!isDesktop) {
      final loc = ref.read(locProvider);
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${loc.get('loading')} ${song.title}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 10),
          backgroundColor: Theme.of(context).cardColor,
        ),
      );
    }

    String result;
    if (contextList != null && contextList.isNotEmpty && index != null) {
      result = await handler.playSongList(contextList, initialIndex: index);
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

    if (!mounted) return;

    if (!isDesktop) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

    if (result != 'Success' && result != 'Cancelled') {
      final loc = ref.read(locProvider);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(loc.get('playback_error')),
          content: Text(result),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(loc.get('ok')),
            ),
          ],
        ),
      );
    }
  }

  void _showSongOptions(Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => SongMenuBottomSheet(song: song),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final loc = ref.watch(locProvider);

    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    final searchControls = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: TextField(
            controller: _searchTextController,
            focusNode: _searchFocusNode,
            style: TextStyle(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: loc.get('search_hint'),
              hintStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 16,
              ),
              prefixIcon: Icon(
                Icons.search,
                color: Theme.of(context).textTheme.bodyLarge?.color,
                size: 28,
              ),
              suffixIcon: _searchTextController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(
                        Icons.clear,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color,
                      ),
                      onPressed: () {
                        _searchTextController.clear();
                        ref
                            .read(searchQueryProvider.notifier)
                            .updateQuery('');
                        setState(() {});
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
            onChanged: (value) {
              ref.read(searchQueryProvider.notifier).updateQuery(value);
              setState(() {});
            },
            onSubmitted: (value) {
              if (value.trim().isNotEmpty) {
                ref.read(searchHistoryProvider.notifier).addQuery(value);
              }
            },
          ),
        ),
        const SizedBox(height: 8),
        TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.redAccent,
          labelColor: Theme.of(context).textTheme.bodyLarge?.color,
          unselectedLabelColor: Theme.of(
            context,
          ).textTheme.bodyMedium?.color,
          tabs: [
            Tab(text: loc.get('songs')),
            Tab(text: loc.get('profiles')),
          ],
        ),
      ],
    );

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isDesktop
          ? PreferredSize(
              preferredSize: const Size.fromHeight(100),
              child: Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: searchControls,
              ),
            )
          : AppBar(
              title: Text(
                loc.get('search'),
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.5,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
              centerTitle: false,
              backgroundColor: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.95),
              elevation: 0,
              bottom: PreferredSize(
                preferredSize: const Size.fromHeight(110),
                child: searchControls,
              ),
            ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.redAccent,
          backgroundColor: Theme.of(context).cardColor,
          onRefresh: () async {
            if (query.isNotEmpty) {
              ref.invalidate(searchResultsProvider);
              ref.invalidate(usersSearchProvider);
            }
          },
          child: TabBarView(
            controller: _tabController,
            children: [_buildSongsTab(query), _buildProfilesTab(query)],
          ),
        ),
      ),
    );
  }

  Widget _buildSongsTab(String query) {
    if (query.isEmpty) return _buildEmptyState();

    final searchResults = ref.watch(searchResultsProvider);
    final downloadedSongs = ref.watch(downloadedSongsProvider);
    return searchResults.when(
      data: (songs) {
        if (songs.isEmpty) return _buildEmptyState();
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 100,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);
            final tile = ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 4,
              ),
              leading: SongCoverImage.fromSong(
                song: song,
                width: 56,
                height: 56,
                borderRadius: BorderRadius.circular(4),
              ),
              title: Text(
                song.title,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Row(
                children: [
                  if (isDownloaded) ...[
                    const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      song.author,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color,
                        fontSize: 14,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              trailing: IconButton(
                icon: Icon(
                  Icons.more_vert,
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                ),
                onPressed: () => _showSongOptions(song),
              ),
              onTap: () => _playSong(song, contextList: songs, index: index),
              onLongPress: () {
                HapticFeedback.mediumImpact();
                _showSongOptions(song);
              },
            );

            return GestureDetector(
              onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                context: context,
                position: details.globalPosition,
                song: song,
                ref: ref,
                songList: songs,
                index: index,
              ),
              child: tile,
            )
            .animate()
            .fade(delay: Duration(milliseconds: index * 40))
            .slideX(begin: 0.05);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.redAccent),
      ),
      error: (e, st) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: AppTheme.redAccent,
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              'Search failed: $e',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redAccent,
              ),
              onPressed: () => ref.invalidate(searchResultsProvider),
              child: const Text('Retry', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilesTab(String query) {
    if (query.isEmpty) return _buildEmptyState();

    final usersAsync = ref.watch(usersSearchProvider(query));
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) return _buildEmptyState();
        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            top: 8,
            bottom: MediaQuery.of(context).padding.bottom + 100,
          ),
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            final targetUid = user['uid'] as String;
            return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppTheme.redAccent,
                    backgroundImage: (user['photoURL'] != null && (user['photoURL'] as String).isNotEmpty)
                        ? NetworkImage(user['photoURL'])
                        : null,
                    child: (user['photoURL'] == null || (user['photoURL'] as String).isEmpty)
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
                  ),
                  title: Text(
                    user['displayName'] ?? 'Unknown',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                  subtitle: Text(
                    user['bio'] ?? '',
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: StreamBuilder<bool>(
                    stream: ref
                        .read(firestoreServiceProvider)
                        .isFollowing(targetUid),
                    builder: (context, snapshot) {
                      final isFollowing = snapshot.data ?? false;
                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isFollowing
                              ? Theme.of(context).cardColor
                              : AppTheme.redAccent,
                          foregroundColor: isFollowing
                              ? Theme.of(context).textTheme.bodyLarge?.color
                              : Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () {
                          if (isFollowing) {
                            ref
                                .read(firestoreServiceProvider)
                                .unfollowUser(targetUid);
                          } else {
                            ref
                                .read(firestoreServiceProvider)
                                .followUser(targetUid);
                          }
                        },
                        child: Text(isFollowing ? 'Following' : 'Follow'),
                      );
                    },
                  ),
                )
                .animate()
                .fade(delay: Duration(milliseconds: index * 40))
                .slideX(begin: 0.05);
          },
        );
      },
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.redAccent),
      ),
      error: (e, st) => Center(
        child: Text(
          'Error: $e',
          style: const TextStyle(color: AppTheme.redAccent),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final searchHistory = ref.watch(searchHistoryProvider);
    if (searchHistory.isNotEmpty) {
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 8),
        itemCount: searchHistory.length,
        itemBuilder: (context, index) {
          final historyQuery = searchHistory[index];
          return ListTile(
            leading: const Icon(Icons.history, color: AppTheme.textSecondary),
            title: Text(
              historyQuery,
              style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
              onPressed: () {
                ref.read(searchHistoryProvider.notifier).removeQuery(historyQuery);
              },
            ),
            onTap: () {
              _searchTextController.text = historyQuery;
              ref.read(searchQueryProvider.notifier).updateQuery(historyQuery);
              setState(() {});
            },
          );
        },
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.2),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Theme.of(context).cardColor),
            const SizedBox(height: 16),
            Text(
              'Search Mozemusic',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find your favorite songs or friends.',
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
