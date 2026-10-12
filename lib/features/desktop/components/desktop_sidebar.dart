import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/firestore_service.dart';
import '../../home/listening_history_screen.dart';
import '../../library/playlist_details_screen.dart';

class DesktopNavIndexNotifier extends Notifier<int> {
  final List<int> _history = [0];
  int _historyIndex = 0;

  @override
  int build() => 0;

  bool get canGoBack => _historyIndex > 0;
  bool get canGoForward => _historyIndex < _history.length - 1;

  void set(int index) {
    if (state == index) return;
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }
    _history.add(index);
    _historyIndex = _history.length - 1;
    state = index;
  }

  void goBack() {
    if (canGoBack) {
      _historyIndex--;
      state = _history[_historyIndex];
    }
  }

  void goForward() {
    if (canGoForward) {
      _historyIndex++;
      state = _history[_historyIndex];
    }
  }
}

final desktopNavIndexProvider = NotifierProvider<DesktopNavIndexNotifier, int>(
  DesktopNavIndexNotifier.new,
);

class DesktopSidebar extends ConsumerStatefulWidget {
  const DesktopSidebar({super.key});

  @override
  ConsumerState<DesktopSidebar> createState() => _DesktopSidebarState();
}

class _DesktopSidebarState extends ConsumerState<DesktopSidebar> {
  bool _isCollapsed = false;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = ref.watch(desktopNavIndexProvider);
    final loc = ref.watch(locProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sidebarWidth = _isCollapsed ? 72.0 : 260.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      width: sidebarWidth,
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF0A0A0A)
            : const Color(0xFFF5F5F5),
        border: Border(
          right: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo Area
          _buildLogoArea(isDark),

          const SizedBox(height: 8),

          // Main Navigation
          _buildNavSection(
            items: [
              _NavItem(Icons.home_rounded, loc.get('home'), 0),
              _NavItem(Icons.search_rounded, loc.get('search'), 1),
              _NavItem(Icons.library_music_rounded, loc.get('library'), 2),
              _NavItem(Icons.graphic_eq_rounded, loc.get('jam_room'), 3),
            ],
            selectedIndex: selectedIndex,
            isDark: isDark,
          ),

          // Divider
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 16 : 20,
              vertical: 8,
            ),
            child: Divider(
              height: 1,
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
            ),
          ),

          // Library Section Header
          if (!_isCollapsed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    loc.get('library').toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                  const Spacer(),
                  _buildIconButton(
                    Icons.add_rounded,
                    isDark,
                    onTap: () {
                      _showCreatePlaylistDialog(context, ref, loc);
                    },
                  ),
                ],
              ),
            ),

          // Playlist list (scrollable)
          Expanded(
            child: _buildPlaylistArea(isDark, loc),
          ),

          // Collapse Toggle
          _buildCollapseToggle(isDark),
        ],
      ),
    );
  }

  Widget _buildLogoArea(bool isDark) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 12 : 20),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppTheme.neonPurple, AppTheme.redAccent],
              ),
            ),
            child: const Icon(Icons.music_note_rounded, color: Colors.white, size: 20),
          ),
          if (!_isCollapsed) ...[
            const SizedBox(width: 12),
            Text(
              'MozeMusic',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavSection({
    required List<_NavItem> items,
    required int selectedIndex,
    required bool isDark,
  }) {
    return Column(
      children: items.map((item) {
        final isSelected = selectedIndex == item.index;
        return _buildNavTile(item, isSelected, isDark);
      }).toList(),
    );
  }

  Widget _buildNavTile(_NavItem item, bool isSelected, bool isDark) {
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark
        ? Colors.white.withValues(alpha: 0.55)
        : Colors.black.withValues(alpha: 0.55);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: _isCollapsed ? 12 : 12,
        vertical: 2,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => ref.read(desktopNavIndexProvider.notifier).set(item.index),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.black.withValues(alpha: 0.04),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: _isCollapsed ? 0 : 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? (isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06))
                  : Colors.transparent,
            ),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  item.icon,
                  size: 22,
                  color: isSelected ? activeColor : inactiveColor,
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 14),
                  Text(
                    item.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                  ),
                  if (isSelected)
                    const Spacer(),
                  if (isSelected)
                    Container(
                      width: 4,
                      height: 18,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [AppTheme.neonPurple, AppTheme.redAccent],
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaylistArea(bool isDark, AppLocalizations loc) {
    final userPlaylistsAsync = ref.watch(userPlaylistsProvider);

    return ListView(
      padding: EdgeInsets.symmetric(horizontal: _isCollapsed ? 8 : 12),
      children: [
        // 1. Liked Songs
        _buildSidebarPlaylistTile(
          title: loc.get('liked_songs'),
          subtitle: 'Collection',
          icon: Icons.favorite_rounded,
          gradient: const LinearGradient(
            colors: [AppTheme.neonPurple, AppTheme.redAccent],
          ),
          isDark: isDark,
          onTap: () => ref.read(desktopNavIndexProvider.notifier).set(2),
        ),
        // 2. Listening History
        _buildSidebarPlaylistTile(
          title: loc.get('history'),
          subtitle: 'Recent',
          icon: Icons.history_rounded,
          gradient: LinearGradient(
            colors: [
              Colors.blueAccent.withValues(alpha: 0.7),
              Colors.tealAccent.withValues(alpha: 0.7),
            ],
          ),
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ListeningHistoryScreen()),
          ),
        ),
        // 3. User's Real Playlists
        ...userPlaylistsAsync.when(
          data: (playlists) => playlists.map((p) => _buildSidebarPlaylistTile(
            title: p.title,
            subtitle: '${p.songs.length} songs',
            imageUrl: p.coverUrl.isNotEmpty ? p.coverUrl : null,
            icon: Icons.music_note_rounded,
            isDark: isDark,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PlaylistDetailsScreen(playlist: p)),
            ),
          )),
          loading: () => [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            ),
          ],
          error: (_, _) => [],
        ),
      ],
    );
  }

  Widget _buildSidebarPlaylistTile({
    required String title,
    required String subtitle,
    required bool isDark,
    required VoidCallback onTap,
    IconData? icon,
    String? imageUrl,
    Gradient? gradient,
  }) {
    if (_isCollapsed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Tooltip(
          message: title,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                gradient: gradient,
                color: gradient == null
                    ? (isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.black.withValues(alpha: 0.04))
                    : null,
              ),
              child: Center(
                child: icon != null
                    ? Icon(icon, size: 18, color: Colors.white)
                    : Text(
                        title.isNotEmpty ? title[0].toUpperCase() : 'P',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
              ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          hoverColor: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      color: gradient == null
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.08)
                              : Colors.black.withValues(alpha: 0.06))
                          : null,
                    ),
                    child: imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, _, _) => Icon(icon ?? Icons.music_note_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black54),
                          )
                        : Icon(
                            icon ?? Icons.music_note_rounded,
                            size: 18,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.4)
                              : Colors.black.withValues(alpha: 0.4),
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

  Widget _buildIconButton(IconData icon, bool isDark, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            icon,
            size: 18,
            color: isDark
                ? Colors.white.withValues(alpha: 0.5)
                : Colors.black.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildCollapseToggle(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _isCollapsed = !_isCollapsed),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            child: Row(
              mainAxisAlignment: _isCollapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  _isCollapsed
                      ? Icons.chevron_right_rounded
                      : Icons.chevron_left_rounded,
                  size: 20,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.4),
                ),
                if (!_isCollapsed) ...[
                  const SizedBox(width: 8),
                  Text(
                    'Collapse',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : Colors.black.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int index;
  const _NavItem(this.icon, this.label, this.index);
}
