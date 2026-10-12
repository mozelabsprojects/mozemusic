import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:audio_service/audio_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/theme/app_theme.dart';
import '../settings/settings_screen.dart';
import 'listening_history_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/firestore_service.dart';
import '../../services/audio_handler.dart';
import '../../services/auth_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/download_service.dart';
import '../../core/localization/app_localizations.dart';
import 'home_controller.dart';
import '../../models/song.dart';
import '../../common_widgets/song_cover_image.dart';
import '../library/song_menu_bottom_sheet.dart';
import '../desktop/components/desktop_song_context_menu.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likedSongsStream = ref.watch(likedSongsProvider);
    final homeFeed = ref.watch(homeFeedProvider);
    final loc = ref.watch(locProvider);
    final authState = ref.watch(authStateProvider);
    final user = authState.value;
    final isOnline = ref.watch(connectivityProvider).value ?? true;
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(loc.get('good_evening'), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: Theme.of(context).textTheme.bodyLarge?.color)),
              actions: [
                IconButton(
                  icon: Icon(Icons.notifications_none, color: Theme.of(context).iconTheme.color),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      appBar: AppBar(title: Text(loc.get('notifications')), backgroundColor: Colors.transparent),
                      body: Center(child: Text(loc.get('no_new_notifications'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color))),
                    )));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.history, color: Theme.of(context).iconTheme.color),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ListeningHistoryScreen()));
                  },
                ),
                IconButton(
                  icon: Icon(Icons.settings, color: Theme.of(context).iconTheme.color),
                  onPressed: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                  },
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(right: 16.0, left: 8.0),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppTheme.redAccent,
                      backgroundImage: (user?.photoURL != null && user!.photoURL!.isNotEmpty) ? NetworkImage(user.photoURL!) : null,
                      child: (user?.photoURL == null || user!.photoURL!.isEmpty) ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                    ),
                  ),
                ),
              ],
            ),
      body: SafeArea(
        bottom: false,
        child: isOnline 
            ? _buildOnlineBody(context, ref, likedSongsStream, homeFeed, loc, isDesktop)
            : _buildOfflineBody(context, ref, loc),
      ),
    );
  }

  Widget _buildOfflineBody(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final downloadedSongs = ref.watch(downloadedSongsProvider);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        left: 16.0,
        right: 16.0,
        top: 16.0,
        bottom: MediaQuery.of(context).padding.bottom + 100,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.redAccent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.redAccent.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.wifi_off, color: AppTheme.redAccent),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    loc.get('offline_mode'),
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                  ),
                ),
              ],
            ),
          ).animate().fade(),
          const SizedBox(height: 32),
          Text(loc.get('downloads'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (downloadedSongs.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    const Icon(Icons.download_done, size: 48, color: AppTheme.textSecondary),
                    const SizedBox(height: 16),
                    Text(loc.get('no_downloads_yet'), style: const TextStyle(color: AppTheme.textSecondary)),
                  ],
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: downloadedSongs.length,
              itemBuilder: (context, index) {
                final song = downloadedSongs[index];
                return GestureDetector(
                  onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                    context: context,
                    position: details.globalPosition,
                    song: song,
                    ref: ref,
                  ),
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: SongCoverImage.fromSong(
                      song: song,
                      width: 50,
                      height: 50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color ?? Colors.white)),
                    subtitle: Text(song.author, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color ?? Colors.grey)),
                    trailing: const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 18),
                    onTap: () => _playSong(context, ref, song, loc, contextList: downloadedSongs, index: index),
                    onLongPress: () {
                      HapticFeedback.mediumImpact();
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (_) => SongMenuBottomSheet(song: song),
                      );
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildGenreChips(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final selectedGenre = ref.watch(selectedGenreFilterProvider);

    final chips = [
      (id: 'all', label: loc.get('all'), icon: '✨'),
      (id: 'top_hits', label: loc.get('top_hits'), icon: '🌟'),
      (id: 'trending_now', label: loc.get('trending_now'), icon: '🔥'),
      (id: 'turkey_hub', label: loc.get('turkey_hub'), icon: '🇹🇷'),
      (id: 'pop_hits', label: loc.get('pop_hits'), icon: '🎤'),
      (id: 'rap_hip_hop', label: loc.get('rap_hip_hop'), icon: '🎧'),
      (id: 'rock_alternative', label: loc.get('rock_alternative'), icon: '🎸'),
      (id: 'electronic_dance', label: loc.get('electronic_dance'), icon: '⚡'),
      (id: 'chill_rnb', label: loc.get('chill_rnb'), icon: '🌙'),
    ];

    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final chip = chips[index];
          final isSelected = selectedGenre == chip.id;
          final isDark = Theme.of(context).brightness == Brightness.dark;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.lightImpact();
                ref.read(selectedGenreFilterProvider.notifier).setGenre(chip.id);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [AppTheme.redAccent, Color(0xFFFF5252)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected
                      ? null
                      : (isDark ? const Color(0xFF1E1E22) : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
                    width: 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppTheme.redAccent.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip.icon, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 7),
                    Text(
                      chip.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTurkishHubView({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, List<Song>> feedData,
    required List<Song> downloadedSongs,
    required AppLocalizations loc,
    required bool isDesktop,
  }) {
    final selectedSubGenre = ref.watch(selectedTurkishSubGenreProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final allTurkishSongs = <Song>[];
    for (final subCat in turkishSubCategories) {
      final s = (feedData[subCat.id] != null && feedData[subCat.id]!.isNotEmpty)
          ? feedData[subCat.id]!
          : subCat.fallbackSongs;
      allTurkishSongs.addAll(s);
    }

    final subChips = [
      (id: 'all', label: loc.get('all'), icon: '✨'),
      (id: 'turkey_pop', label: loc.get('turkey_pop'), icon: '🎤'),
      (id: 'turkey_rap', label: loc.get('turkey_rap'), icon: '🎧'),
      (id: 'turkey_rock', label: loc.get('turkey_rock'), icon: '🎸'),
      (id: 'turkey_classical', label: loc.get('turkey_classical'), icon: '🎻'),
      (id: 'turkey_soft', label: loc.get('turkey_soft'), icon: '☕'),
    ];

    final cardWidth = isDesktop ? 165.0 : 145.0;
    final listHeight = isDesktop ? 240.0 : 225.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Hub Header Hero Banner
        Container(
          padding: EdgeInsets.all(isDesktop ? 20 : 14),
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFE50914).withValues(alpha: isDark ? 0.35 : 0.2),
                isDark ? const Color(0xFF221518) : const Color(0xFFFFF0F2),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE50914).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 58 : 46,
                height: isDesktop ? 58 : 46,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFFFF416C)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Text('🇹🇷', style: TextStyle(fontSize: isDesktop ? 30 : 22)),
              ),
              SizedBox(width: isDesktop ? 18 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.get('turkish_music_hub'),
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: isDesktop ? 26 : 19,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${allTurkishSongs.length} ${loc.get('all') == 'Tümü' ? 'Hit Şarkı • Pop, Rap, Rock, Klasik & Soft' : 'Hit Songs • Pop, Rap, Rock, Classical & Soft'}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.85),
                        fontSize: isDesktop ? 13 : 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (allTurkishSongs.isNotEmpty)
                isDesktop
                    ? ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE50914),
                          foregroundColor: Colors.white,
                          shape: const StadiumBorder(),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          elevation: 5,
                          shadowColor: const Color(0xFFE50914).withValues(alpha: 0.5),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 22),
                        label: Text(
                          loc.get('play_all'),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        onPressed: () => _playSong(
                          context,
                          ref,
                          allTurkishSongs.first,
                          loc,
                          contextList: allTurkishSongs,
                          index: 0,
                        ),
                      )
                    : Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(24),
                          onTap: () => _playSong(
                            context,
                            ref,
                            allTurkishSongs.first,
                            loc,
                            contextList: allTurkishSongs,
                            index: 0,
                          ),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFE50914), Color(0xFFFF416C)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.5),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                          ),
                        ),
                      ),
            ],
          ),
        ),

        // 2. Turkish Sub-Category Filters
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: subChips.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final chip = subChips[index];
              final isSelected = selectedSubGenre == chip.id;

              return MouseRegion(
                cursor: SystemMouseCursors.click,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(selectedTurkishSubGenreProvider.notifier).setSubGenre(chip.id);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [Color(0xFFE50914), Color(0xFFFF5252)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected
                          ? null
                          : (isDark ? const Color(0xFF26262C) : Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06)),
                        width: 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFFE50914).withValues(alpha: 0.35),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(chip.icon, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 6),
                        Text(
                          chip.label,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                            color: isSelected
                                ? Colors.white
                                : Theme.of(context).textTheme.bodyLarge?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),

        // 3. Sub-Category Content
        if (selectedSubGenre == 'all')
          ...turkishSubCategories.map((subCat) {
            final songs = (feedData[subCat.id] != null && feedData[subCat.id]!.isNotEmpty)
                ? feedData[subCat.id]!
                : subCat.fallbackSongs;

            if (songs.isEmpty) return const SizedBox.shrink();

            return Padding(
              padding: const EdgeInsets.only(bottom: 32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Text(subCat.icon, style: const TextStyle(fontSize: 20)),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                loc.get(subCat.locKey),
                                style: TextStyle(
                                  color: Theme.of(context).textTheme.bodyLarge?.color,
                                  fontSize: isDesktop ? 20 : 17,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Row(
                        children: [
                          TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            ),
                            onPressed: () {
                              ref.read(selectedTurkishSubGenreProvider.notifier).setSubGenre(subCat.id);
                            },
                            child: Text(
                              loc.get('all') == 'Tümü' ? 'Tümünü Gör' : 'See All',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                            ),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.redAccent,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            icon: const Icon(Icons.play_circle_fill, size: 20),
                            label: Text(
                              loc.get('play_all'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                            onPressed: () => _playSong(
                              context,
                              ref,
                              songs.first,
                              loc,
                              contextList: songs,
                              index: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: listHeight,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      itemCount: songs.length,
                      itemBuilder: (context, index) {
                        final song = songs[index];
                        final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);

                        return Container(
                          width: cardWidth,
                          margin: const EdgeInsets.only(right: 14),
                          child: MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _playSong(context, ref, song, loc, contextList: songs, index: index),
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => SongMenuBottomSheet(song: song),
                                );
                              },
                              onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                                context: context,
                                position: details.globalPosition,
                                song: song,
                                ref: ref,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.08),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: SongCoverImage.fromSong(
                                              song: song,
                                              width: double.infinity,
                                              height: double.infinity,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 6,
                                            right: 6,
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppTheme.redAccent,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black.withValues(alpha: 0.4),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            song.title,
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (isDownloaded) ...[
                                          const SizedBox(width: 4),
                                          const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      song.author,
                                      style: TextStyle(
                                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ).animate().fade(delay: Duration(milliseconds: index * 20)).scale(begin: const Offset(0.96, 0.96));
                      },
                    ),
                  ),
                ],
              ),
            );
          })
        else ...[
          _buildDedicatedGenreView(
            context: context,
            ref: ref,
            feedData: feedData,
            selectedGenre: selectedSubGenre,
            downloadedSongs: downloadedSongs,
            loc: loc,
            isDesktop: isDesktop,
          ),
        ],
      ],
    );
  }

  Widget _buildDedicatedGenreView({
    required BuildContext context,
    required WidgetRef ref,
    required Map<String, List<Song>> feedData,
    required String selectedGenre,
    required List<Song> downloadedSongs,
    required AppLocalizations loc,
    required bool isDesktop,
  }) {
    final category = homeGenreCategories.firstWhere(
      (c) => c.id == selectedGenre,
      orElse: () => homeGenreCategories.first,
    );
    final targetTitle = loc.get(category.locKey);
    final songs = (feedData[selectedGenre] != null && feedData[selectedGenre]!.isNotEmpty)
        ? feedData[selectedGenre]!
        : category.fallbackSongs;

    if (songs.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: CircularProgressIndicator(color: AppTheme.redAccent),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Category Header Hero Banner
        Container(
          padding: EdgeInsets.all(isDesktop ? 18 : 14),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.redAccent.withValues(alpha: isDark ? 0.25 : 0.15),
                isDark ? const Color(0xFF1E1E24) : Colors.grey.shade50,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.redAccent.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 52 : 44,
                height: isDesktop ? 52 : 44,
                decoration: BoxDecoration(
                  color: AppTheme.redAccent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(category.icon, style: TextStyle(fontSize: isDesktop ? 26 : 22)),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetTitle,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                        fontSize: isDesktop ? 26 : 19,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${songs.length} ${loc.get('all') == 'Tümü' ? 'Hit Şarkı' : 'Hit Songs'}',
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                        fontSize: isDesktop ? 13 : 11.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              isDesktop
                  ? ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.redAccent,
                        foregroundColor: Colors.white,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                        elevation: 4,
                        shadowColor: AppTheme.redAccent.withValues(alpha: 0.4),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded, size: 22),
                      label: Text(loc.get('play_all'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      onPressed: () => _playSong(context, ref, songs.first, loc, contextList: songs, index: 0),
                    )
                  : Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(24),
                        onTap: () => _playSong(context, ref, songs.first, loc, contextList: songs, index: 0),
                        child: Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppTheme.redAccent, Color(0xFFFF5252)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.redAccent.withValues(alpha: 0.45),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 26),
                        ),
                      ),
                    ),
            ],
          ),
        ),

        // Songs Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: isDesktop ? 5 : 2,
            childAspectRatio: isDesktop ? 0.74 : 0.72,
            crossAxisSpacing: 14,
            mainAxisSpacing: 16,
          ),
          itemCount: songs.length,
          itemBuilder: (context, index) {
            final song = songs[index];
            final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);

            return MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _playSong(context, ref, song, loc, contextList: songs, index: index),
                onLongPress: () {
                  HapticFeedback.mediumImpact();
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    builder: (_) => SongMenuBottomSheet(song: song),
                  );
                },
                onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                  context: context,
                  position: details.globalPosition,
                  song: song,
                  ref: ref,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: SongCoverImage.fromSong(
                                song: song,
                                width: double.infinity,
                                height: double.infinity,
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 8,
                              child: Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: AppTheme.redAccent,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              song.title,
                              style: TextStyle(
                                color: Theme.of(context).textTheme.bodyLarge?.color,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isDownloaded) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.author,
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ).animate().fade(delay: Duration(milliseconds: index * 25)).scale(begin: const Offset(0.96, 0.96));
          },
        ),
      ],
    );
  }

  Widget _buildOnlineBody(BuildContext context, WidgetRef ref, AsyncValue<List<Song>> likedSongsStream, AsyncValue<Map<String, List<Song>>> homeFeed, AppLocalizations loc, bool isDesktop) {
    final downloadedSongs = ref.watch(downloadedSongsProvider);
    final selectedGenre = ref.watch(selectedGenreFilterProvider);

    return RefreshIndicator(
          color: AppTheme.redAccent,
          backgroundColor: Theme.of(context).cardColor,
          onRefresh: () async {
            ref.invalidate(homeFeedProvider);
            return await ref.read(homeFeedProvider.future);
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 16.0,
              bottom: MediaQuery.of(context).padding.bottom + 100, // Dynamic padding for safe area + miniplayer
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isDesktop) ...[
                  Text(
                    loc.get('good_evening'),
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // 1. Genre & Hits Filter Bar
                _buildGenreChips(context, ref, loc),
                const SizedBox(height: 20),

                // 2. Top Grid (Recently played / Liked Songs) - only shown when 'all' is selected
                if (selectedGenre == 'all') ...[
                  likedSongsStream.when(
                    data: (songs) {
                      if (songs.isEmpty) {
                        return Text(loc.get('start_liking_songs_to_see_them_here'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color));
                      }
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: isDesktop ? 3 : 2,
                          childAspectRatio: isDesktop ? 3.5 : 3,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: songs.length > 6 ? 6 : songs.length,
                        itemBuilder: (context, index) {
                          final song = songs[index];
                          final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);
                          return MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: GestureDetector(
                              onTap: () => _playSong(context, ref, song, loc, contextList: songs, index: index),
                              onLongPress: () {
                                HapticFeedback.mediumImpact();
                                showModalBottomSheet(
                                  context: context,
                                  backgroundColor: Colors.transparent,
                                  builder: (_) => SongMenuBottomSheet(song: song),
                                );
                              },
                              onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                                context: context,
                                position: details.globalPosition,
                                song: song,
                                ref: ref,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: Row(
                                  children: [
                                    SongCoverImage.fromSong(
                                      song: song,
                                      width: 56,
                                      height: 56,
                                      borderRadius: BorderRadius.zero,
                                    ),
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                song.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 13, fontWeight: FontWeight.w600),
                                              ),
                                            ),
                                            if (isDownloaded) ...[
                                              const SizedBox(width: 4),
                                              const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ).animate().fade(duration: 500.ms);
                    },
                    loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.redAccent)),
                    error: (e, st) => Text('${loc.get('error_loading_songs')}$e', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
                  ),
                  const SizedBox(height: 28),
                ],

                // 3. Hits & Genre Feed
                homeFeed.when(
                  data: (feedData) {
                    if (selectedGenre == 'turkey_hub') {
                      return _buildTurkishHubView(
                        context: context,
                        ref: ref,
                        feedData: feedData,
                        downloadedSongs: downloadedSongs,
                        loc: loc,
                        isDesktop: isDesktop,
                      );
                    }
                    if (selectedGenre != 'all') {
                      return _buildDedicatedGenreView(
                        context: context,
                        ref: ref,
                        feedData: feedData,
                        selectedGenre: selectedGenre,
                        downloadedSongs: downloadedSongs,
                        loc: loc,
                        isDesktop: isDesktop,
                      );
                    }

                    final cardWidth = isDesktop ? 165.0 : 145.0;
                    final listHeight = isDesktop ? 240.0 : 225.0;

                    // Build structured sections:
                    // 1. History (if present)
                    // 2. Recommended (if present)
                    // 3. Each category from homeGenreCategories
                    final sections = <({String id, String title, String? icon, List<Song> songs})>[];

                    final historySongs = feedData['continue_where_you_left_off'];
                    if (historySongs != null && historySongs.isNotEmpty) {
                      sections.add((
                        id: 'continue_where_you_left_off',
                        title: loc.get('continue_where_you_left_off'),
                        icon: '⏮️',
                        songs: historySongs,
                      ));
                    }

                    final recSongs = feedData['recommended_songs'];
                    if (recSongs != null && recSongs.isNotEmpty) {
                      sections.add((
                        id: 'recommended_songs',
                        title: loc.get('recommended_songs'),
                        icon: '🎧',
                        songs: recSongs,
                      ));
                    }

                    for (final cat in homeGenreCategories) {
                      final songs = (feedData[cat.id] != null && feedData[cat.id]!.isNotEmpty)
                          ? feedData[cat.id]!
                          : cat.fallbackSongs;
                      if (songs.isNotEmpty) {
                        sections.add((
                          id: cat.id,
                          title: loc.get(cat.locKey),
                          icon: cat.icon,
                          songs: songs,
                        ));
                      }
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: sections.map((sec) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 32.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        if (sec.icon != null) ...[
                                          Text(sec.icon!, style: const TextStyle(fontSize: 20)),
                                          const SizedBox(width: 8),
                                        ],
                                        Flexible(
                                          child: Text(
                                            sec.title,
                                            style: TextStyle(
                                              color: Theme.of(context).textTheme.bodyLarge?.color,
                                              fontSize: isDesktop ? 22 : 18,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      if (sec.id != 'continue_where_you_left_off' && sec.id != 'recommended_songs')
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            foregroundColor: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          ),
                                          onPressed: () {
                                            ref.read(selectedGenreFilterProvider.notifier).setGenre(sec.id);
                                          },
                                          child: Text(
                                            loc.get('all') == 'Tümü' ? 'Tümünü Gör' : 'See All',
                                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                          ),
                                        ),
                                      if (sec.songs.isNotEmpty)
                                        TextButton.icon(
                                          style: TextButton.styleFrom(
                                            foregroundColor: AppTheme.redAccent,
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          ),
                                          icon: const Icon(Icons.play_circle_fill, size: 20),
                                          label: Text(
                                            loc.get('play_all'),
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                          onPressed: () => _playSong(
                                            context,
                                            ref,
                                            sec.songs.first,
                                            loc,
                                            contextList: sec.songs,
                                            index: 0,
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              SizedBox(
                                height: listHeight,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: sec.songs.length,
                                  itemBuilder: (context, index) {
                                    final song = sec.songs[index];
                                    final isDownloaded = downloadedSongs.any((d) => d.videoId == song.videoId);

                                    return MouseRegion(
                                      cursor: SystemMouseCursors.click,
                                      child: GestureDetector(
                                        onTap: () => _playSong(context, ref, song, loc, contextList: sec.songs, index: index),
                                        onLongPress: () {
                                          HapticFeedback.mediumImpact();
                                          showModalBottomSheet(
                                            context: context,
                                            backgroundColor: Colors.transparent,
                                            builder: (_) => SongMenuBottomSheet(song: song),
                                          );
                                        },
                                        onSecondaryTapUp: (details) => showDesktopSongContextMenu(
                                          context: context,
                                          position: details.globalPosition,
                                          song: song,
                                          ref: ref,
                                        ),
                                        child: Container(
                                          width: cardWidth,
                                          margin: const EdgeInsets.only(right: 16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Stack(
                                                children: [
                                                  SongCoverImage.fromSong(
                                                    song: song,
                                                    width: cardWidth,
                                                    height: cardWidth,
                                                    borderRadius: BorderRadius.circular(10),
                                                  ),
                                                  Positioned(
                                                    bottom: 6,
                                                    right: 6,
                                                    child: Container(
                                                      width: 30,
                                                      height: 30,
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.redAccent,
                                                        shape: BoxShape.circle,
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black.withValues(alpha: 0.3),
                                                            blurRadius: 4,
                                                            offset: const Offset(0, 2),
                                                          ),
                                                        ],
                                                      ),
                                                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 8),
                                              Row(
                                                children: [
                                                  Expanded(
                                                    child: Text(
                                                      song.title,
                                                      style: TextStyle(
                                                        color: Theme.of(context).textTheme.bodyLarge?.color,
                                                        fontWeight: FontWeight.bold,
                                                        fontSize: 13,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  if (isDownloaded) ...[
                                                    const SizedBox(width: 4),
                                                    const Icon(Icons.download_done, color: AppTheme.neonGreen, size: 14),
                                                  ],
                                                ],
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                song.author,
                                                style: TextStyle(
                                                  color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.8),
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ).animate().fade(delay: Duration(milliseconds: index * 35)).slideX(begin: 0.08);
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 40.0),
                      child: CircularProgressIndicator(color: AppTheme.redAccent),
                    ),
                  ),
                  error: (e, st) => Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline, color: AppTheme.redAccent, size: 48),
                        const SizedBox(height: 16),
                        Text(loc.get('failed_to_load_recommendations'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.redAccent),
                          onPressed: () => ref.invalidate(homeFeedProvider),
                          child: Text(loc.get('retry'), style: const TextStyle(color: Colors.white)),
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
  }

  Future<void> _playSong(BuildContext context, WidgetRef ref, Song song, AppLocalizations loc, {List<Song>? contextList, int? index}) async {
    HapticFeedback.lightImpact();
    final handler = ref.read(audioHandlerProvider);

    final isDesktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    if (!isDesktop) {
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
      result = await handler.playFromVideoId(song.videoId, mediaItem: mediaItem);
    }

    if (!context.mounted) return;

    if (!isDesktop) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }

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
  }
}

