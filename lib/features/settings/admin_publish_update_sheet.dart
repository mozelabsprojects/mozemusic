import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../models/app_update_info.dart';
import '../../services/update_service.dart';

class AdminPublishUpdateSheet extends ConsumerStatefulWidget {
  const AdminPublishUpdateSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AdminPublishUpdateSheet(),
    );
  }

  @override
  ConsumerState<AdminPublishUpdateSheet> createState() => _AdminPublishUpdateSheetState();
}

class _AdminPublishUpdateSheetState extends ConsumerState<AdminPublishUpdateSheet> {
  final _versionController = TextEditingController(text: '1.0.1');
  final _titleController = TextEditingController(text: 'MozeMusic 1.0.1 Yayında! 🚀');
  final _notesController = TextEditingController(
    text: '• Liked Songs çalma sırası ve mix modu düzeltildi.\n• Performans artırıldı.',
  );
  final _windowsUrlController = TextEditingController(
    text: 'https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic_Setup.exe',
  );
  final _androidUrlController = TextEditingController(
    text: 'https://github.com/mozelabsprojects/mozemusic/releases/latest/download/app-release.apk',
  );
  bool _forceUpdate = false;
  bool _isPublishing = false;

  @override
  void dispose() {
    _versionController.dispose();
    _titleController.dispose();
    _notesController.dispose();
    _windowsUrlController.dispose();
    _androidUrlController.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    final version = _versionController.text.trim();
    if (version.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen geçerli bir sürüm numarası girin.')),
      );
      return;
    }

    setState(() => _isPublishing = true);
    try {
      final info = AppUpdateInfo(
        latestVersion: version,
        minRequiredVersion: _forceUpdate ? version : '1.0.0',
        forceUpdate: _forceUpdate,
        title: _titleController.text.trim(),
        releaseNotes: _notesController.text.trim(),
        downloadUrlWindows: _windowsUrlController.text.trim(),
        downloadUrlAndroid: _androidUrlController.text.trim(),
        releaseDate: DateTime.now().toIso8601String().split('T').first,
      );

      await ref.read(updateServiceProvider).publishUpdate(info);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎉 Güncelleme (v$version) başarıyla tüm kullanıcılara yayınlandı!'),
            backgroundColor: AppTheme.neonGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AppTheme.redAccent),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : Colors.black12,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                const Icon(Icons.rocket_launch_rounded, color: AppTheme.redAccent, size: 24),
                const SizedBox(width: 10),
                Text(
                  'Yeni Güncelleme Yayınla',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _versionController,
              decoration: const InputDecoration(
                labelText: 'Yeni Sürüm Numarası (örn: 1.0.1)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Güncelleme Başlığı',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Yenilikler / Güncelleme Notları',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _windowsUrlController,
              decoration: const InputDecoration(
                labelText: 'Windows İndirme Bağlantısı (.exe)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            TextField(
              controller: _androidUrlController,
              decoration: const InputDecoration(
                labelText: 'Android İndirme Bağlantısı (.apk)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Zorunlu Güncelleme (Force Update)'),
              subtitle: const Text('Kullanıcı güncellemeden uygulamayı kullanamaz', style: TextStyle(fontSize: 12)),
              value: _forceUpdate,
              activeThumbColor: AppTheme.redAccent,
              onChanged: (val) => setState(() => _forceUpdate = val),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _isPublishing ? null : _publish,
              child: _isPublishing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      '🚀 Güncellemeyi Herkese Yayınla',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
