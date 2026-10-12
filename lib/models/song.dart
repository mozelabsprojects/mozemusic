class Song {
  final String videoId;
  final String title;
  final String author;
  final String thumbnailUrl;
  final int durationMs;

  Song({
    required this.videoId,
    required this.title,
    required this.author,
    required String thumbnailUrl,
    required this.durationMs,
  }) : thumbnailUrl = _sanitizeThumbnail(thumbnailUrl, videoId);

  static String _sanitizeThumbnail(String url, String videoId) {
    var trimmed = url.trim();
    if (trimmed.isEmpty && videoId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    // YouTube's maxresdefault.jpg returns 404 for standard definition videos.
    // Replace with hqdefault.jpg which is guaranteed to exist for 100% of YouTube videos.
    if (trimmed.contains('maxresdefault.jpg') && videoId.isNotEmpty) {
      return 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    }
    // Prefer img.youtube.com over i.ytimg.com to bypass regional throttling and DNS blocks
    if (trimmed.contains('i.ytimg.com')) {
      trimmed = trimmed.replaceAll('i.ytimg.com', 'img.youtube.com');
    }
    return trimmed;
  }

  factory Song.fromMap(Map<String, dynamic> map) {
    final vid = (map['videoId'] ?? '').toString();
    final rawThumb = (map['thumbnailUrl'] ?? '').toString();
    return Song(
      videoId: vid,
      title: (map['title'] ?? '').toString(),
      author: (map['author'] ?? '').toString(),
      thumbnailUrl: rawThumb,
      durationMs: map['durationMs'] is int
          ? map['durationMs'] as int
          : int.tryParse(map['durationMs']?.toString() ?? '0') ?? 0,
    );
  }

  /// Guaranteed working fallback image
  String get fallbackThumbnailUrl => videoId.isNotEmpty
      ? 'https://img.youtube.com/vi/$videoId/hqdefault.jpg'
      : thumbnailUrl;

  Map<String, dynamic> toMap() {
    return {
      'videoId': videoId,
      'title': title,
      'author': author,
      'thumbnailUrl': thumbnailUrl,
      'durationMs': durationMs,
    };
  }
}
