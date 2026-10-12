import 'dart:io';
import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:isar/isar.dart';
import '../models/song.dart';
import '../models/isar_models.dart';
import 'youtube_service.dart';
import '../main.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  final ytService = ref.watch(youtubeServiceProvider);
  final dio = Dio();
  return DownloadService(isar, ytService, dio);
});

final downloadedSongsProvider = NotifierProvider<DownloadedSongsNotifier, List<Song>>(DownloadedSongsNotifier.new);

class DownloadService {
  final Isar _isar;
  final YoutubeService _ytService;
  final Dio _dio;

  // Maps MIME types to file extensions
  static const _mimeToExt = {
    'audio/mp4': '.m4a',
    'audio/aac': '.m4a',
    'audio/webm': '.webm',
    'audio/ogg': '.ogg',
    'audio/mpeg': '.mp3',
    'video/mp4': '.mp4',
    'video/webm': '.webm',
  };

  DownloadService(this._isar, this._ytService, this._dio);

  List<Song> getDownloadedSongs() {
    return _isar.downloadEntrys.where().sortByDownloadedAtDesc().findAllSync().map((e) => e.toSong()).toList();
  }

  Future<bool> isDownloaded(String videoId) async {
    final entry = await _isar.downloadEntrys.where().videoIdEqualTo(videoId).findFirst();
    if (entry == null) return false;
    
    // Verify file actually exists on disk
    final file = File(entry.filePath);
    if (await file.exists()) return true;

    // If DB says downloaded but file missing, clean up DB
    await _isar.writeTxn(() async {
      await _isar.downloadEntrys.delete(entry.id);
    });
    return false;
  }

  /// Returns the local file path for a downloaded song, or null if not found
  Future<String?> getDownloadedFilePath(String videoId) async {
    final entry = await _isar.downloadEntrys.where().videoIdEqualTo(videoId).findFirst();
    if (entry != null) {
      final file = File(entry.filePath);
      if (await file.exists()) return file.path;
    }
    return null;
  }

  Future<void> downloadSong(Song song, String quality, {dynamic progress}) async {
    try {
      final streamUrl = await _ytService.getAudioStreamUrlWithQuality(song.videoId, quality);
      if (streamUrl == null) throw Exception('No audio stream found');

      // Detect MIME type from HEAD request
      String ext = '.m4a'; // sensible default
      try {
        final headResp = await _dio.head(streamUrl);
        final contentType = headResp.headers.value('content-type') ?? '';
        final baseMime = contentType.split(';').first.trim().toLowerCase();
        ext = _mimeToExt[baseMime] ?? '.m4a';
        log('DownloadService: Detected MIME=$baseMime, ext=$ext');
      } catch (e) {
        log('DownloadService: HEAD failed, using default ext .m4a: $e');
      }

      final dir = await getApplicationDocumentsDirectory();
      final savePath = '${dir.path}/${song.videoId}$ext';

      await _dio.download(
        streamUrl,
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0 && progress != null) {
            final p = received / total;
            progress.value = p;
          }
        },
      );

      final entry = DownloadEntry.fromSong(song, DateTime.now(), savePath);
      await _isar.writeTxn(() async {
        await _isar.downloadEntrys.put(entry);
      });
    } catch (e) {
      throw Exception('Failed to download: $e');
    }
  }

  Future<void> deleteSong(String videoId) async {
    final entry = await _isar.downloadEntrys.where().videoIdEqualTo(videoId).findFirst();
    if (entry != null) {
      final file = File(entry.filePath);
      if (await file.exists()) {
        await file.delete();
      }
      await _isar.writeTxn(() async {
        await _isar.downloadEntrys.delete(entry.id);
      });
    } else {
      // Fallback: Delete any file with any supported extension if DB out of sync
      final dir = await getApplicationDocumentsDirectory();
      for (final ext in ['.m4a', '.webm', '.mp3', '.mp4', '.ogg']) {
        final file = File('${dir.path}/$videoId$ext');
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }
}

class DownloadedSongsNotifier extends Notifier<List<Song>> {
  late DownloadService _service;

  @override
  List<Song> build() {
    _service = ref.watch(downloadServiceProvider);
    return _service.getDownloadedSongs();
  }

  Future<void> download(Song song, String quality) async {
    await _service.downloadSong(song, quality);
    state = _service.getDownloadedSongs();
  }

  Future<void> delete(String videoId) async {
    await _service.deleteSong(videoId);
    state = _service.getDownloadedSongs();
  }
  
  void refresh() {
    state = _service.getDownloadedSongs();
  }
}
