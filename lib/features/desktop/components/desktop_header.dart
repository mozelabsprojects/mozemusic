import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/localization/app_localizations.dart';
import '../../../services/auth_service.dart';
import '../../settings/settings_screen.dart';
import '../../profile/profile_screen.dart';
import '../../home/listening_history_screen.dart';
import 'desktop_sidebar.dart';

class DesktopHeader extends ConsumerWidget {
  final VoidCallback? onBack;
  final VoidCallback? onForward;

  const DesktopHeader({super.key, this.onBack, this.onForward});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loc = ref.watch(locProvider);

    ref.watch(desktopNavIndexProvider);
    final navNotifier = ref.read(desktopNavIndexProvider.notifier);
    final canGoBack = navNotifier.canGoBack;
    final canGoForward = navNotifier.canGoForward;

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: const BoxDecoration(
        color: Colors.transparent,
      ),
      child: Row(
        children: [
          // Navigation arrows
          _buildCircleButton(
            Icons.chevron_left_rounded,
            isDark,
            enabled: canGoBack,
            onTap: onBack ?? (canGoBack ? () => navNotifier.goBack() : null),
          ),
          const SizedBox(width: 8),
          _buildCircleButton(
            Icons.chevron_right_rounded,
            isDark,
            enabled: canGoForward,
            onTap: onForward ?? (canGoForward ? () => navNotifier.goForward() : null),
          ),
          const SizedBox(width: 24),

          const Spacer(),

          // Notifications
          _buildCircleButton(
            Icons.notifications_none_rounded,
            isDark,
            size: 18,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                    appBar: AppBar(
                      title: Text(loc.get('notifications')),
                      backgroundColor: Colors.transparent,
                    ),
                    body: Center(
                      child: Text(
                        loc.get('no_new_notifications'),
                        style: TextStyle(
                          color: Theme.of(context).textTheme.bodyMedium?.color,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),

          // Listening History
          _buildCircleButton(
            Icons.history_rounded,
            isDark,
            size: 18,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ListeningHistoryScreen(),
                ),
              );
            },
          ),
          const SizedBox(width: 12),

          // Profile Avatar
          _buildProfileAvatar(ref, isDark, context),
        ],
      ),
    );
  }

  Widget _buildCircleButton(
    IconData icon,
    bool isDark, {
    double size = 22,
    bool enabled = true,
    VoidCallback? onTap,
  }) {
    return Material(
      color: isDark
          ? (enabled ? Colors.white.withValues(alpha: 0.07) : Colors.white.withValues(alpha: 0.02))
          : (enabled ? Colors.black.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02)),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        hoverColor: isDark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.black.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            size: size,
            color: isDark
                ? (enabled ? Colors.white.withValues(alpha: 0.8) : Colors.white24)
                : (enabled ? Colors.black.withValues(alpha: 0.8) : Colors.black26),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileAvatar(WidgetRef ref, bool isDark, BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final photoUrl = user?.photoURL;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

    return PopupMenuButton<String>(
      offset: const Offset(0, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      color: isDark ? const Color(0xFF282828) : Colors.white,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: hasPhoto
              ? null
              : const LinearGradient(
                  colors: [AppTheme.neonPurple, AppTheme.redAccent],
                ),
          image: hasPhoto
              ? DecorationImage(
                  image: NetworkImage(photoUrl),
                  fit: BoxFit.cover,
                )
              : null,
        ),
        child: hasPhoto
            ? null
            : const Icon(Icons.person_rounded, size: 18, color: Colors.white),
      ),
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 18, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 10),
              Text('Profile', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'settings',
          child: Row(
            children: [
              Icon(Icons.settings_outlined, size: 18, color: isDark ? Colors.white70 : Colors.black87),
              const SizedBox(width: 10),
              Text('Settings', style: TextStyle(fontSize: 13, color: isDark ? Colors.white : Colors.black)),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: AppTheme.redAccent),
              const SizedBox(width: 10),
              Text('Log out', style: TextStyle(fontSize: 13, color: AppTheme.redAccent)),
            ],
          ),
        ),
      ],
      onSelected: (value) {
        switch (value) {
          case 'profile':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            break;
          case 'settings':
            Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
            break;
          case 'logout':
            ref.read(authServiceProvider).signOut();
            break;
        }
      },
    );
  }
}
