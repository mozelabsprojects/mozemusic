import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/app_update_info.dart';

final updateServiceProvider = Provider<UpdateService>((ref) {
  return UpdateService();
});

final updateStreamProvider = StreamProvider<AppUpdateInfo?>((ref) {
  return ref.watch(updateServiceProvider).watchUpdateInfo();
});

class UpdateService {
  static const String currentVersion = '1.0.0';

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Compares semantic versions (e.g. 1.0.1 > 1.0.0)
  static bool isNewerVersion(String current, String remote) {
    try {
      final currParts = current.split('+').first.replaceAll('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remParts = remote.split('+').first.replaceAll('v', '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
      for (int i = 0; i < 3; i++) {
        final c = i < currParts.length ? currParts[i] : 0;
        final r = i < remParts.length ? remParts[i] : 0;
        if (r > c) return true;
        if (r < c) return false;
      }
      return false;
    } catch (_) {
      return current != remote;
    }
  }

  /// Live stream for real-time update push notification from Firestore
  Stream<AppUpdateInfo?> watchUpdateInfo() {
    return _firestore
        .collection('app_config')
        .doc('version')
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return AppUpdateInfo.fromMap(snap.data()!);
    });
  }

  /// Fetch update checking both Firestore and GitHub Releases
  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    // 1. Try Firestore first
    try {
      final doc = await _firestore.collection('app_config').doc('version').get();
      if (doc.exists && doc.data() != null) {
        final info = AppUpdateInfo.fromMap(doc.data()!);
        if (isNewerVersion(currentVersion, info.latestVersion)) {
          return info;
        }
      }
    } catch (_) {}

    // 2. Check GitHub Releases API (automatic OTA updates when pushing to GitHub)
    return await fetchGitHubRelease();
  }

  /// Automatic GitHub Releases integration
  Future<AppUpdateInfo?> fetchGitHubRelease() async {
    try {
      final dio = Dio();
      final res = await dio.get(
        'https://api.github.com/repos/mozelabsprojects/mozemusic/releases/latest',
        options: Options(responseType: ResponseType.json),
      );
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        final tagName = data['tag_name']?.toString().replaceAll('v', '') ?? '';
        final body = data['body']?.toString() ?? '';
        final assets = (data['assets'] as List?) ?? [];

        String winUrl = 'https://github.com/mozelabsprojects/mozemusic/releases/latest/download/MozeMusic_Setup.exe';
        String apkUrl = 'https://github.com/mozelabsprojects/mozemusic/releases/latest/download/app-release.apk';

        for (final asset in assets) {
          final name = asset['name']?.toString().toLowerCase() ?? '';
          final downloadUrl = asset['browser_download_url']?.toString() ?? '';
          if (name.endsWith('.exe')) winUrl = downloadUrl;
          if (name.endsWith('.apk')) apkUrl = downloadUrl;
        }

        return AppUpdateInfo(
          latestVersion: tagName,
          minRequiredVersion: '1.0.0',
          forceUpdate: false,
          title: 'MozeMusic v$tagName Yayında! 🚀',
          releaseNotes: body.isNotEmpty ? body : 'GitHub üzerinden yeni sürüm yayınlandı.',
          downloadUrlWindows: winUrl,
          downloadUrlAndroid: apkUrl,
          releaseDate: data['published_at']?.toString().split('T').first ?? '',
        );
      }
    } catch (_) {}
    return null;
  }

  /// Admin method: broadcast new update to all devices instantly
  Future<void> publishUpdate(AppUpdateInfo info) async {
    await _firestore.collection('app_config').doc('version').set(info.toMap(), SetOptions(merge: true));
  }

  /// Launch download URL
  Future<bool> launchDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Choose appropriate download URL for active platform
  String getPlatformDownloadUrl(AppUpdateInfo info) {
    if (Platform.isWindows) {
      return info.downloadUrlWindows;
    } else {
      return info.downloadUrlAndroid;
    }
  }
}
