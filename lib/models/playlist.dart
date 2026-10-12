import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mozemusic/models/song.dart';

class Playlist {
  final String playlistId;
  final String title;
  final String coverUrl;
  final String ownerId;
  final List<Song> songs;
  final DateTime createdAt;
  final bool isPublic;

  Playlist({
    required this.playlistId,
    required this.title,
    required this.coverUrl,
    required this.ownerId,
    required this.songs,
    required this.createdAt,
    this.isPublic = true,
  });

  factory Playlist.fromMap(Map<String, dynamic> map, String id) {
    return Playlist(
      playlistId: id,
      title: map['title'] ?? '',
      coverUrl: map['coverUrl'] ?? '',
      ownerId: map['ownerId'] ?? '',
      songs: (map['songs'] as List<dynamic>?)
              ?.map((e) => Song.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isPublic: map['isPublic'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'coverUrl': coverUrl,
      'ownerId': ownerId,
      'songs': songs.map((e) => e.toMap()).toList(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
    };
  }

  Playlist copyWith({
    String? playlistId,
    String? title,
    String? coverUrl,
    String? ownerId,
    List<Song>? songs,
    DateTime? createdAt,
    bool? isPublic,
  }) {
    return Playlist(
      playlistId: playlistId ?? this.playlistId,
      title: title ?? this.title,
      coverUrl: coverUrl ?? this.coverUrl,
      ownerId: ownerId ?? this.ownerId,
      songs: songs ?? this.songs,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
    );
  }
}
