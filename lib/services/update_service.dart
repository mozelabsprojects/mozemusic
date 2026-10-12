import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
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
      final currParts = current.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
      final remParts = remote.split('+').first.split('.').map((e) => int.tryParse(e) ?? 0).toList();
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

  /// Live stream for real-time update push notification
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

  /// One-time fetch for manual update check
  Future<AppUpdateInfo?> fetchUpdateInfo() async {
    try {
      final doc = await _firestore.collection('app_config').doc('version').get();
      if (!doc.exists || doc.data() == null) return null;
      return AppUpdateInfo.fromMap(doc.data()!);
    } catch (e) {
      return null;
    }
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
