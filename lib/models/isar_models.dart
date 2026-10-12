import 'package:isar/isar.dart';
import 'song.dart';

part 'isar_models.g.dart';

@collection
class HistoryEntry {
  Id id = Isar.autoIncrement; // you can also use id = fastHash(videoId)

  @Index(unique: true, replace: true)
  late String videoId;

  late String title;
  late String author;
  late String thumbnailUrl;
  late int durationMs;

  late DateTime accessedAt;

  Song toSong() {
    return Song(
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
    );
  }

  static HistoryEntry fromSong(Song song, DateTime time) {
    return HistoryEntry()
      ..videoId = song.videoId
      ..title = song.title
      ..author = song.author
      ..thumbnailUrl = song.thumbnailUrl
      ..durationMs = song.durationMs
      ..accessedAt = time;
  }
}

@collection
class DownloadEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String videoId;

  late String title;
  late String author;
  late String thumbnailUrl;
  late int durationMs;

  late DateTime downloadedAt;
  late String filePath;

  Song toSong() {
    return Song(
      videoId: videoId,
      title: title,
      author: author,
      thumbnailUrl: thumbnailUrl,
      durationMs: durationMs,
    );
  }

  static DownloadEntry fromSong(Song song, DateTime time, String path) {
    return DownloadEntry()
      ..videoId = song.videoId
      ..title = song.title
      ..author = song.author
      ..thumbnailUrl = song.thumbnailUrl
      ..durationMs = song.durationMs
      ..downloadedAt = time
      ..filePath = path;
  }
}

@collection
class SearchQueryEntry {
  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String query;

  late DateTime searchedAt;
}
