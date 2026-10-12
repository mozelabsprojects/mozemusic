import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/song.dart';
import '../models/isar_models.dart';
import '../main.dart';

final historyServiceProvider = Provider<HistoryService>((ref) {
  return HistoryService(isar);
});

final historyProvider = NotifierProvider<HistoryNotifier, List<Song>>(HistoryNotifier.new);

class HistoryService {
  final Isar _isar;
  static const int _maxHistory = 100;

  HistoryService(this._isar);

  List<Song> getHistory() {
    final entries = _isar.historyEntrys.where().sortByAccessedAtDesc().findAllSync();
    return entries.map((e) => e.toSong()).toList();
  }

  Future<void> addToHistory(Song song) async {
    final entry = HistoryEntry.fromSong(song, DateTime.now());
    
    await _isar.writeTxn(() async {
      await _isar.historyEntrys.put(entry);

      final count = await _isar.historyEntrys.count();
      if (count > _maxHistory) {
        // Find the oldest ones and delete them
        final toDelete = await _isar.historyEntrys
            .where()
            .sortByAccessedAt()
            .limit(count - _maxHistory)
            .findAll();
        for (var e in toDelete) {
          await _isar.historyEntrys.delete(e.id);
        }
      }
    });

    // Cloud sync for cross-device listening history (mobile <-> desktop)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('listening_history')
            .doc(song.videoId)
            .set({
          ...song.toMap(),
          'listenedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }

  Future<void> clearHistory() async {
    await _isar.writeTxn(() async {
      await _isar.historyEntrys.clear();
    });

    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docs = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('listening_history')
            .limit(50)
            .get();
        for (final doc in docs.docs) {
          await doc.reference.delete();
        }
      } catch (_) {}
    }
  }
}

class HistoryNotifier extends Notifier<List<Song>> {
  late HistoryService _service;

  @override
  List<Song> build() {
    _service = ref.watch(historyServiceProvider);
    _syncCloudHistory();
    return _service.getHistory();
  }

  void _syncCloudHistory() {
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) return;
      FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('listening_history')
          .orderBy('listenedAt', descending: true)
          .limit(50)
          .snapshots()
          .listen((snapshot) async {
        if (snapshot.docs.isEmpty) return;
        final cloudSongs = snapshot.docs.map((d) => Song.fromMap(d.data())).toList();

        // Put into local isar if missing
        await isar.writeTxn(() async {
          for (final song in cloudSongs) {
            final exists = await isar.historyEntrys.filter().videoIdEqualTo(song.videoId).findFirst();
            if (exists == null) {
              await isar.historyEntrys.put(HistoryEntry.fromSong(song, DateTime.now()));
            }
          }
        });

        state = _service.getHistory();
      });
    });
  }

  Future<void> addSong(Song song) async {
    await _service.addToHistory(song);
    state = _service.getHistory();
  }

  Future<void> clear() async {
    await _service.clearHistory();
    state = [];
  }
}

final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  return SearchHistoryService(isar);
});

final searchHistoryProvider = NotifierProvider<SearchHistoryNotifier, List<String>>(SearchHistoryNotifier.new);

class SearchHistoryService {
  final Isar _isar;
  static const int _maxHistory = 20;

  SearchHistoryService(this._isar);

  List<String> getHistory() {
    return _isar.searchQueryEntrys.where().sortBySearchedAtDesc().findAllSync().map((e) => e.query).toList();
  }

  Future<void> addQuery(String queryText) async {
    final entry = SearchQueryEntry()
      ..query = queryText
      ..searchedAt = DateTime.now();

    await _isar.writeTxn(() async {
      await _isar.searchQueryEntrys.put(entry);

      final count = await _isar.searchQueryEntrys.count();
      if (count > _maxHistory) {
        final toDelete = await _isar.searchQueryEntrys
            .where()
            .sortBySearchedAt()
            .limit(count - _maxHistory)
            .findAll();
        for (var e in toDelete) {
          await _isar.searchQueryEntrys.delete(e.id);
        }
      }
    });
  }

  Future<void> removeQuery(String queryText) async {
    await _isar.writeTxn(() async {
      final item = await _isar.searchQueryEntrys.where().queryEqualTo(queryText).findFirst();
      if (item != null) {
        await _isar.searchQueryEntrys.delete(item.id);
      }
    });
  }

  Future<void> clearHistory() async {
    await _isar.writeTxn(() async {
      await _isar.searchQueryEntrys.clear();
    });
  }
}

class SearchHistoryNotifier extends Notifier<List<String>> {
  late SearchHistoryService _service;

  @override
  List<String> build() {
    _service = ref.watch(searchHistoryServiceProvider);
    return _service.getHistory();
  }

  Future<void> addQuery(String query) async {
    if (query.trim().isEmpty) return;
    await _service.addQuery(query.trim());
    state = _service.getHistory();
  }

  Future<void> removeQuery(String query) async {
    await _service.removeQuery(query);
    state = _service.getHistory();
  }

  Future<void> clear() async {
    await _service.clearHistory();
    state = [];
  }
}
