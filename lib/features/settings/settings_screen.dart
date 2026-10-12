import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/app_localizations.dart';
import '../../services/auth_service.dart';
import 'controllers/settings_controller.dart';
import 'downloads_screen.dart';
import '../../services/update_service.dart';
import '../../common_widgets/update_dialog.dart';
import 'admin_publish_update_sheet.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final loc = ref.watch(locProvider);
    final currentUserEmail = ref.watch(authStateProvider).value?.email?.toLowerCase() ?? '';
    final isAdmin = currentUserEmail == 'mox17012000@gmail.com' ||
        currentUserEmail == 'cosmoxbusiness@gmail.com' ||
        currentUserEmail.contains('mozelabs');

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(loc.get('settings'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
      ),
      body: SafeArea(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 32),
          children: [
            _buildSectionHeader(loc.get('account')),
            ListTile(
              leading: Icon(Icons.email, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('email'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              trailing: Text(
                ref.watch(authStateProvider).value?.email ?? loc.get('not_logged_in'),
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
            ),

            _buildSectionHeader(loc.get('playback')),
            SwitchListTile(
              secondary: Icon(Icons.play_circle_outline, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('autoplay'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(
                settings.autoplay ? loc.get('on_nonstop') : loc.get('off'),
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              value: settings.autoplay,
              activeThumbColor: AppTheme.redAccent,
              onChanged: (val) => settingsNotifier.updateAutoplay(val),
            ),
            ListTile(
              leading: Icon(Icons.high_quality, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('audio_quality'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(
                _qualityDescription(settings.audioQuality, loc),
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              trailing: DropdownButton<String>(
                dropdownColor: Theme.of(context).cardColor,
                value: settings.audioQuality,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                underline: const SizedBox(),
                items: ['Low', 'Standard', 'High', 'Very High']
                    .map((e) => DropdownMenuItem(value: e, child: Text(_localizedQuality(e, loc))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.updateAudioQuality(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.get('audio_quality_set') + _localizedQuality(val, loc)),
                        backgroundColor: Theme.of(context).cardColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            ListTile(
              leading: Icon(Icons.download, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('download_quality'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(_localizedQuality(settings.downloadQuality, loc), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              trailing: DropdownButton<String>(
                dropdownColor: Theme.of(context).cardColor,
                value: settings.downloadQuality,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                underline: const SizedBox(),
                items: ['Standard', 'High', 'Very High']
                    .map((e) => DropdownMenuItem(value: e, child: Text(_localizedQuality(e, loc))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.updateDownloadQuality(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.get('download_quality_set') + _localizedQuality(val, loc)),
                        backgroundColor: Theme.of(context).cardColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),

            _buildSectionHeader(loc.get('app')),
            ListTile(
              leading: Icon(Icons.language, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('language'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(settings.language == 'English' ? loc.get('english') : loc.get('turkish'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              trailing: DropdownButton<String>(
                dropdownColor: Theme.of(context).cardColor,
                value: settings.language,
                style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
                underline: const SizedBox(),
                items: ['English', 'Turkish']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e == 'English' ? loc.get('english') : loc.get('turkish'))))
                    .toList(),
                onChanged: (val) {
                  if (val != null) {
                    settingsNotifier.updateLanguage(val);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(loc.get('language_changed') + (val == 'English' ? loc.get('english') : loc.get('turkish'))),
                        backgroundColor: Theme.of(context).cardColor,
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                },
              ),
            ),
            SwitchListTile(
              secondary: Icon(Icons.dark_mode, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('dark_mode'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text(
                settings.themeMode == ThemeMode.dark ? loc.get('dark_theme_active') : loc.get('light_theme_active'),
                style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
              ),
              value: settings.themeMode == ThemeMode.dark,
              activeThumbColor: AppTheme.redAccent,
              onChanged: (val) {
                settingsNotifier.updateThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(val ? loc.get('dark_mode_enabled') : loc.get('light_mode_enabled')),
                    backgroundColor: Theme.of(context).cardColor,
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
            ),

            _buildSectionHeader(loc.get('support')),
            ListTile(
              leading: Icon(Icons.email_outlined, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('contact_us'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text('cosmoxbusiness@gmail.com', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Contact: cosmoxbusiness@gmail.com'),
                    backgroundColor: Theme.of(context).cardColor,
                  ),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.info_outline, color: Theme.of(context).iconTheme.color),
              title: Text(loc.get('about'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
              subtitle: Text('MozeMusic v${UpdateService.currentVersion}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: 'MozeMusic',
                  applicationVersion: UpdateService.currentVersion,
                  applicationLegalese: '© 2026 MozeMusic. All rights reserved.',
                );
              },
            ),

            _buildSectionHeader('GÜNCELLEMELER'),
            ListTile(
              leading: const Icon(Icons.system_update_rounded, color: AppTheme.redAccent),
              title: Text('Güncellemeleri Denetle', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600)),
              subtitle: Text('Mevcut sürüm: v${UpdateService.currentVersion}', style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color, fontSize: 12)),
              trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
              onTap: () async {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Row(
                      children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        SizedBox(width: 12),
                        Text('Güncellemeler kontrol ediliyor...'),
                      ],
                    ),
                    backgroundColor: Theme.of(context).cardColor,
                    duration: const Duration(seconds: 2),
                  ),
                );

                final info = await ref.read(updateServiceProvider).fetchUpdateInfo();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).clearSnackBars();

                if (info != null && UpdateService.isNewerVersion(UpdateService.currentVersion, info.latestVersion)) {
                  UpdateDialog.show(context, info);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('✨ Harika! MozeMusic en güncel sürümde (v${UpdateService.currentVersion}).'),
                      backgroundColor: Theme.of(context).cardColor,
                    ),
                  );
                }
              },
            ),
            if (isAdmin)
              ListTile(
                leading: const Icon(Icons.rocket_launch_rounded, color: AppTheme.neonPurple),
                title: Text('Yeni Güncelleme Yayınla (Admin)', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.bold)),
                subtitle: const Text('Tüm kullanıcılara canlı güncelleme bildirimi at', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                trailing: const Icon(Icons.chevron_right, color: AppTheme.neonPurple),
                onTap: () {
                  AdminPublishUpdateSheet.show(context);
                },
              ),

            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).cardColor,
                  foregroundColor: AppTheme.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                onPressed: () async {
                  await ref.read(authServiceProvider).signOut();
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text(loc.get('log_out'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            ListTile(
            leading: Icon(Icons.download_done, color: Theme.of(context).iconTheme.color),
            title: Text(loc.get('downloads'), style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color)),
            subtitle: Text(loc.get('manage_downloads'), style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color)),
            trailing: const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const DownloadsScreen()));
            },
          ),
          const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  String _localizedQuality(String quality, AppLocalizations loc) {
    switch (quality) {
      case 'Low': return loc.get('low');
      case 'Standard': return loc.get('standard');
      case 'High': return loc.get('high');
      case 'Very High': return loc.get('very_high');
      default: return quality;
    }
  }

  String _qualityDescription(String quality, AppLocalizations loc) {
    switch (quality) {
      case 'Low':
        return loc.get('quality_low');
      case 'Standard':
        return loc.get('quality_standard');
      case 'High':
        return loc.get('quality_high');
      case 'Very High':
        return loc.get('quality_very_high');
      default:
        return quality;
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, top: 24, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(color: AppTheme.redAccent, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1),
      ),
    );
  }
}
