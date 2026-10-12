import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/song.dart';
import '../models/playlist.dart';
import 'auth_service.dart';

final firestoreServiceProvider = Provider<FirestoreService>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return FirestoreService(FirebaseFirestore.instance, authState?.uid);
});

final likedSongsProvider = StreamProvider<List<Song>>((ref) {
  ref.keepAlive();
  return ref.watch(firestoreServiceProvider).getLikedSongs();
});

final userPlaylistsProvider = StreamProvider<List<Playlist>>((ref) {
  return ref.watch(firestoreServiceProvider).getUserPlaylists();
});

final usersSearchProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  return ref.watch(firestoreServiceProvider).searchUsers(query);
});

class FirestoreService {
  final FirebaseFirestore _db;
  final String? _uid;

  FirestoreService(this._db, this._uid);

  Stream<List<Song>> getLikedSongs() {
    if (_uid == null) return Stream.value([]);
    
    // Use ServerAndCache to prefer cached data if offline, but server data when online
    return _db
        .collection('users')
        .doc(_uid)
        .collection('liked_songs')
        .orderBy('addedAt', descending: true)
        .snapshots() // Firetore snapshots automatically use cache for immediate emission
        .map((snapshot) {
      return snapshot.docs.map((doc) => Song.fromMap(doc.data())).toList();
    });
  }

  Future<void> toggleLikeSong(Song song, bool isLiked) async {
    if (_uid == null) return;
    
    final docRef = _db
        .collection('users')
        .doc(_uid)
        .collection('liked_songs')
        .doc(song.videoId);

    if (isLiked) {
      // Remove from liked songs
      await docRef.delete();
    } else {
      // Add to liked songs
      final data = song.toMap();
      data['addedAt'] = FieldValue.serverTimestamp();
      await docRef.set(data);
    }
  }

  Future<bool> isSongLiked(String videoId) async {
    if (_uid == null) return false;
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('liked_songs')
        .doc(videoId)
        .get(const GetOptions(source: Source.cache)); // Use cache to avoid loading times on UI
    
    if (!doc.exists) {
        // Fallback to server if not found in cache
        final serverDoc = await _db
          .collection('users')
          .doc(_uid)
          .collection('liked_songs')
          .doc(videoId)
          .get(const GetOptions(source: Source.server));
        return serverDoc.exists;
    }
    return true;
  }

  // Social Features
  Future<void> updateProfile(String username, String bio) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).update({
      'displayName': username,
      'displayNameLowercase': username.toLowerCase(),
      'bio': bio,
    });
  }

  Future<void> followUser(String targetUid) async {
    if (_uid == null || _uid == targetUid) return;
    
    // Add to current user's following list
    await _db.collection('users').doc(_uid).collection('following').doc(targetUid).set({
      'followedAt': FieldValue.serverTimestamp(),
    });
    
    // Add to target user's followers list
    await _db.collection('users').doc(targetUid).collection('followers').doc(_uid).set({
      'followedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> unfollowUser(String targetUid) async {
    if (_uid == null) return;
    
    // Remove from current user's following list
    await _db.collection('users').doc(_uid).collection('following').doc(targetUid).delete();
    
    // Remove from target user's followers list
    await _db.collection('users').doc(targetUid).collection('followers').doc(_uid).delete();
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    // Basic prefix search in firestore
    final queryLower = query.toLowerCase();
    if (queryLower.isEmpty) return [];
    final snapshot = await _db
        .collection('users')
        .where('displayNameLowercase', isGreaterThanOrEqualTo: queryLower)
        .where('displayNameLowercase', isLessThanOrEqualTo: '$queryLower\uf8ff')
        .limit(20)
        .get();
        
    return snapshot.docs.map((doc) => {'uid': doc.id, ...doc.data()}).toList();
  }

  Stream<bool> isFollowing(String targetUid) {
    if (_uid == null) return Stream.value(false);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('following')
        .doc(targetUid)
        .snapshots()
        .map((doc) => doc.exists);
  }
  // ---------------------------------------------------------------------------
  // PLAYLISTS
  // ---------------------------------------------------------------------------

  Stream<List<Playlist>> getUserPlaylists() {
    if (_uid == null) return Stream.value([]);
    return _db
        .collection('users')
        .doc(_uid)
        .collection('playlists')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Playlist.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<Playlist>> getPublicPlaylists(String targetUid) {
    return _db
        .collection('users')
        .doc(targetUid)
        .collection('playlists')
        .where('isPublic', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Playlist.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> createPlaylist(String title, String coverUrl, {bool isPublic = true}) async {
    if (_uid == null) return;
    final ref = _db.collection('users').doc(_uid).collection('playlists').doc();
    final playlist = Playlist(
      playlistId: ref.id,
      title: title,
      coverUrl: coverUrl,
      ownerId: _uid,
      songs: [],
      createdAt: DateTime.now(),
      isPublic: isPublic,
    );
    await ref.set(playlist.toMap());
  }

  Future<String?> uploadPlaylistCover(String playlistId, File imageFile) async {
    if (_uid == null) return null;
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('users/$_uid/playlists/$playlistId/cover.jpg');
      await storageRef.putFile(imageFile);
      final url = await storageRef.getDownloadURL();
      
      await _db
          .collection('users')
          .doc(_uid)
          .collection('playlists')
          .doc(playlistId)
          .update({'coverUrl': url});
          
      return url;
    } catch (e) {
      return null;
    }
  }

  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    if (_uid == null) return;
    final ref = _db.collection('users').doc(_uid).collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (doc.exists) {
      final p = Playlist.fromMap(doc.data()!, doc.id);
      if (!p.songs.any((s) => s.videoId == song.videoId)) {
        final newSongs = List<Song>.from(p.songs)..add(song);
        await ref.update({'songs': newSongs.map((e) => e.toMap()).toList()});
      }
    }
  }

  Future<void> removeSongFromPlaylist(String playlistId, String videoId) async {
    if (_uid == null) return;
    final ref = _db.collection('users').doc(_uid).collection('playlists').doc(playlistId);
    final doc = await ref.get();
    if (doc.exists) {
      final p = Playlist.fromMap(doc.data()!, doc.id);
      final newSongs = p.songs.where((s) => s.videoId != videoId).toList();
      await ref.update({'songs': newSongs.map((e) => e.toMap()).toList()});
    }
  }

  Future<void> updatePlaylistOrder(String playlistId, List<Song> newOrder) async {
    if (_uid == null) return;
    final ref = _db.collection('users').doc(_uid).collection('playlists').doc(playlistId);
    await ref.update({'songs': newOrder.map((e) => e.toMap()).toList()});
  }

  Future<void> deletePlaylist(String playlistId) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('playlists').doc(playlistId).delete();
  }

  Future<void> updatePlaylistName(String playlistId, String newName) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('playlists').doc(playlistId).update({'title': newName});
  }

  Future<void> togglePlaylistVisibility(String playlistId, bool isPublic) async {
    if (_uid == null) return;
    await _db.collection('users').doc(_uid).collection('playlists').doc(playlistId).update({'isPublic': isPublic});
  }

  Future<void> clonePlaylist(Playlist sourcePlaylist) async {
    if (_uid == null) return;
    final ref = _db.collection('users').doc(_uid).collection('playlists').doc();
    final clonedPlaylist = Playlist(
      playlistId: ref.id,
      title: sourcePlaylist.title,
      coverUrl: sourcePlaylist.coverUrl,
      ownerId: _uid, // The current user becomes the new owner
      songs: sourcePlaylist.songs,
      createdAt: DateTime.now(),
      isPublic: false, // Default clones to private
    );
    await ref.set(clonedPlaylist.toMap());
  }
}
