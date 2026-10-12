import 'dart:developer';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

/// A single synced lyric line
class LyricLine {
  final Duration timestamp;
  final String text;
  LyricLine(this.timestamp, this.text);
}

/// Lyrics data: synced lines + plain text fallback
class LyricsData {
  final List<LyricLine> syncedLines;
  final String? plainLyrics;
  bool get hasSynced => syncedLines.isNotEmpty;
  bool get hasAny => syncedLines.isNotEmpty || (plainLyrics?.isNotEmpty ?? false);
  LyricsData({this.syncedLines = const [], this.plainLyrics});
}

final lyricsServiceProvider = Provider<LyricsService>((ref) => LyricsService());

/// Fetches lyrics for a given title+artist from the LRCLIB API
final lyricsProvider = FutureProvider.family<LyricsData, ({String title, String artist})>((ref, params) async {
  final service = ref.watch(lyricsServiceProvider);
  return service.fetchLyrics(params.title, params.artist);
});

class LyricsService {
  final Dio _dio = Dio();
  static const _baseUrl = 'https://lrclib.net/api';

  /// Parse LRC format "[mm:ss.xx] text" into LyricLine list
  List<LyricLine> _parseLrc(String lrc) {
    final lines = <LyricLine>[];
    final regex = RegExp(r'\[(\d+):(\d+)\.(\d+)\]\s*(.*)');
    for (final line in lrc.split('\n')) {
      final match = regex.firstMatch(line.trim());
      if (match != null) {
        final min = int.parse(match.group(1)!);
        final sec = int.parse(match.group(2)!);
        final ms = int.parse(match.group(3)!.padRight(3, '0').substring(0, 3));
        final text = match.group(4) ?? '';
        if (text.isNotEmpty) {
          lines.add(LyricLine(
            Duration(minutes: min, seconds: sec, milliseconds: ms),
            text,
          ));
        }
      }
    }
    lines.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return lines;
  }

  Future<LyricsData> fetchLyrics(String title, String artist) async {
    try {
      // Clean up title: remove all common YouTube music tags & noise
      String cleanTitle = title
          .replaceAll(RegExp(r'[\(\[](official|music|video|audio|lyric|lyrics|visualizer|klip|video klip|remastered|live|prod\..*?|hd|4k|hq)[\)\]]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\((official|music|video|audio|lyric|lyrics|visualizer|klip|remastered|live).*?\)', caseSensitive: false), '')
          .replaceAll(RegExp(r'\[(official|music|video|audio|lyric|lyrics|visualizer|klip|remastered|live).*?\]', caseSensitive: false), '')
          .replaceAll(RegExp(r'\b(ft\.|feat\.|featuring)\s.*', caseSensitive: false), '')
          .replaceAll(RegExp(r'["“”]', caseSensitive: false), '')
          .trim();

      String searchArtist = artist.trim();
      
      if (cleanTitle.contains(' - ')) {
        final parts = cleanTitle.split(' - ');
        if (parts.length >= 2) {
          searchArtist = parts[0].trim();
          cleanTitle = parts.sublist(1).join(' - ').trim();
        }
      }

      // 1. Try track_name + artist_name
      var resp = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {
          'track_name': cleanTitle,
          'artist_name': searchArtist,
        },
      );

      if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
        final best = resp.data[0];
        final syncedLrc = best['syncedLyrics'] as String?;
        final plainLyrics = best['plainLyrics'] as String?;

        if (syncedLrc != null || plainLyrics != null) {
          return LyricsData(
            syncedLines: syncedLrc != null ? _parseLrc(syncedLrc) : [],
            plainLyrics: plainLyrics,
          );
        }
      }

      // 2. Fallback: query parameter with artist + title
      resp = await _dio.get(
        '$_baseUrl/search',
        queryParameters: {'q': '$searchArtist $cleanTitle'.trim()},
      );

      if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
        final best = resp.data[0];
        return LyricsData(
          syncedLines: best['syncedLyrics'] != null ? _parseLrc(best['syncedLyrics']) : [],
          plainLyrics: best['plainLyrics'] as String?,
        );
      }

      // 3. Fallback: query parameter with just cleanTitle
      if (cleanTitle.isNotEmpty) {
        resp = await _dio.get(
          '$_baseUrl/search',
          queryParameters: {'q': cleanTitle},
        );

        if (resp.statusCode == 200 && resp.data is List && (resp.data as List).isNotEmpty) {
          final best = resp.data[0];
          return LyricsData(
            syncedLines: best['syncedLyrics'] != null ? _parseLrc(best['syncedLyrics']) : [],
            plainLyrics: best['plainLyrics'] as String?,
          );
        }
      }

      return LyricsData();
    } catch (e) {
      log('LyricsService error: $e');
      return LyricsData();
    }
  }
}
