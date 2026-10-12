import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart' hide Playlist;
import '../models/song.dart';
import '../models/playlist.dart';

final youtubeServiceProvider = Provider<YoutubeService>((ref) {
  final service = YoutubeService();
  ref.onDispose(() => service.dispose());
  return service;
});

class YoutubeService {
  YoutubeExplode? _yt;

  YoutubeExplode get _client {
    _yt ??= YoutubeExplode();
    return _yt!;
  }

  Future<List<Song>> searchSongs(String query) async {
    try {
      // Use searchContent with TypeFilters.video to prevent youtube_explode_dart
      // from crashing with FormatException on livestream/streamed replay dates.
      final results = await _client.search.searchContent(query, filter: TypeFilters.video);
      final songs = <Song>[];
      for (final item in results.whereType<SearchVideo>()) {
        if (item.isLive) continue;
        final durMs = _parseDurationString(item.duration);
        // Exclude compilations / hour-long mixes > 6.5 minutes or < 80 seconds
        if (durMs > 390 * 1000 || durMs < 80 * 1000) continue;
        final titleLower = item.title.toLowerCase();
        if (titleLower.contains('1 hour') ||
            titleLower.contains('10 hours') ||
            titleLower.contains('full album') ||
            titleLower.contains('compilation') ||
            titleLower.contains('megamix') ||
            titleLower.contains('en iyiler') ||
            titleLower.contains('karışık') ||
            titleLower.contains('top 100') ||
            titleLower.contains('top 50') ||
            titleLower.contains('lazy song') ||
            titleLower.contains('lush life') ||
            titleLower.contains('new rules') ||
            titleLower.contains('cheap thrills') ||
            titleLower.contains('despacito') ||
            titleLower.contains('taki taki') ||
            titleLower.contains('2011') ||
            titleLower.contains('2012') ||
            titleLower.contains('2013') ||
            titleLower.contains('2014') ||
            titleLower.contains('2015') ||
            titleLower.contains('2016') ||
            titleLower.contains('2017') ||
            titleLower.contains('2018') ||
            titleLower.contains('2019') ||
            titleLower.contains('2020') ||
            titleLower.contains('2021') ||
            titleLower.contains('2022') ||
            titleLower.contains('2023')) {
          continue;
        }

        final thumb = (item.thumbnails.isNotEmpty && !item.thumbnails.last.url.toString().contains('maxresdefault.jpg'))
            ? item.thumbnails.last.url.toString()
            : 'https://img.youtube.com/vi/${item.id.value}/hqdefault.jpg';

        songs.add(Song(
          videoId: item.id.value,
          title: item.title,
          author: item.author,
          thumbnailUrl: thumb,
          durationMs: durMs,
        ));
      }

      if (songs.isNotEmpty) return songs;

      // Fallback to legacy search if searchContent yielded no results
      try {
        final searchList = await _client.search.search(query);
        return searchList.where((v) => !v.isLive && (v.duration?.inMinutes ?? 0) < 12).map((video) {
          return Song(
            videoId: video.id.value,
            title: video.title,
            author: video.author,
            thumbnailUrl: 'https://img.youtube.com/vi/${video.id.value}/hqdefault.jpg',
            durationMs: video.duration?.inMilliseconds ?? 0,
          );
        }).toList();
      } catch (fallbackError) {
        log('Legacy search fallback failed: $fallbackError');
        return songs;
      }
    } catch (e) {
      log('Search error: $e');
      _recreateClient();
      rethrow;
    }
  }

  static int _parseDurationString(String durationStr) {
    if (durationStr.isEmpty) return 0;
    final parts = durationStr.split(':').map((p) => int.tryParse(p) ?? 0).toList();
    if (parts.length == 2) {
      return (parts[0] * 60 + parts[1]) * 1000;
    } else if (parts.length == 3) {
      return (parts[0] * 3600 + parts[1] * 60 + parts[2]) * 1000;
    }
    return 0;
  }

  /// Returns a fresh audio stream URL.
  Future<String?> getAudioStreamUrl(String videoId) async {
    return getAudioStreamUrlWithQuality(videoId, 'High');
  }

  /// Gets a stream URL with quality preference.
  Future<String?> getAudioStreamUrlWithQuality(String videoId, String quality) async {
    log('YoutubeService: Fetching stream for $videoId with quality $quality');
    final freshYt = YoutubeExplode();
    try {
      final manifest = await freshYt.videos.streamsClient.getManifest(videoId);

      // YouTube currently enforces Bot Detection / PoToken on standalone audio-only streams (tag 139/140),
      // returning HTTP 403 Forbidden on direct playback.
      // However, muxed MP4 streams (e.g. tag 18 - 360p AAC 44.1kHz audio) consistently return HTTP 200/206
      // and play smoothly in just_audio without any 403 errors across Windows, Android, iOS, and macOS.
      final muxedMp4 = manifest.muxed
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList()
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));

      final audioOnlyMp4 = manifest.audioOnly
          .where((s) => s.container.name.toLowerCase() == 'mp4')
          .toList()
        ..sort((a, b) => a.bitrate.compareTo(b.bitrate));

      StreamInfo? selectedStream;

      // 1. Try muxed MP4 first as it reliably bypasses HTTP 403 restrictions
      if (muxedMp4.isNotEmpty) {
        selectedStream = muxedMp4.first;
      } else if (audioOnlyMp4.isNotEmpty) {
        selectedStream = audioOnlyMp4.last;
      } else if (manifest.muxed.isNotEmpty) {
        selectedStream = manifest.muxed.first;
      } else if (manifest.audioOnly.isNotEmpty) {
        selectedStream = manifest.audioOnly.first;
      }

      if (selectedStream != null) {
        log('YoutubeService: Selected stream (${selectedStream.container.name}, ${selectedStream.bitrate}): ${selectedStream.url}');
        return selectedStream.url.toString();
      }

      log('YoutubeService: No usable stream found for $videoId');
      return null;
    } catch (e, stack) {
      log('YoutubeService ERROR fetching audio stream (quality=$quality) for $videoId: $e\n$stack');
      return null;
    } finally {
      freshYt.close();
    }
  }

  /// Gets related videos for autoplay
  Future<List<Song>> getRelatedVideos(String videoId) async {
    try {
      final video = await _client.videos.get(VideoId(videoId));
      final related = await _client.videos.getRelatedVideos(video);
      if (related == null || related.isEmpty) return [];

      return related.take(5).map((v) {
        return Song(
          videoId: v.id.value,
          title: v.title,
          author: v.author,
          thumbnailUrl: 'https://img.youtube.com/vi/${v.id.value}/hqdefault.jpg',
          durationMs: v.duration?.inMilliseconds ?? 0,
        );
      }).toList();
    } catch (e) {
      log('Error getting related videos: $e');
      return [];
    }
  }

  /// Gets predefined YouTube Mix Playlists for the Home Screen
  Future<List<Playlist>> getMixPlaylists() async {
    // Some popular YouTube Music Mix IDs
    final predefinedIds = [
      'RDCLAK5uy_m5D8E42wA-YhZJtK6V9F5m9K5G_tFk-zY', // Today's Biggest Hits
      'RDCLAK5uy_l4b9gD2Zg95p_6M_vI1cQ1t5_u9y985Jc', // Chill Mix
      'RDCLAK5uy_n7z5c5R0F6l0R8kY_n_v2h4y-uR1c_bX4', // Pop Hotlist
      'RDCLAK5uy_kZ41a63bI4h0gq4FzYlA0Y5m6j_w2h5S0', // Hip Hop Mix
    ];

    final playlists = <Playlist>[];

    try {
      for (var id in predefinedIds) {
        try {
          final ytPlaylist = await _client.playlists.get(id);
          final videos = await _client.playlists.getVideos(id).take(15).toList();
          if (videos.isNotEmpty) {
            playlists.add(Playlist(
              playlistId: ytPlaylist.id.value,
              title: ytPlaylist.title,
              coverUrl: ytPlaylist.thumbnails.mediumResUrl,
              ownerId: ytPlaylist.author,
              createdAt: DateTime.now(),
              songs: videos.map((v) => Song(
                videoId: v.id.value,
                title: v.title,
                author: v.author,
                thumbnailUrl: 'https://img.youtube.com/vi/${v.id.value}/hqdefault.jpg',
                durationMs: v.duration?.inMilliseconds ?? 0,
              )).toList(),
            ));
          }
        } catch (e) {
          log('Error fetching playlist $id: $e');
        }
      }
    } catch (e) {
      log('Error getting mix playlists: $e');
    }

    return playlists;
  }

  void _recreateClient() {
    try { _yt?.close(); } catch (_) {}
    _yt = null;
  }

  void dispose() {
    try { _yt?.close(); } catch (_) {}
    _yt = null;
  }
}
