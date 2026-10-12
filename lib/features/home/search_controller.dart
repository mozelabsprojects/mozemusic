import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/song.dart';
import '../../services/youtube_service.dart';

class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void updateQuery(String newQuery) {
    state = newQuery;
  }
}

final searchQueryProvider = NotifierProvider<SearchQueryNotifier, String>(() {
  return SearchQueryNotifier();
});

final searchResultsProvider = FutureProvider<List<Song>>((ref) async {
  ref.keepAlive();
  final query = ref.watch(searchQueryProvider);
  final prefs = await SharedPreferences.getInstance();

  if (query.trim().isEmpty) {
    // Return cached results if available
    final cachedData = prefs.getString('cached_search_results');
    if (cachedData != null) {
      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.map((json) => Song.fromMap(json)).toList();
    }
    return [];
  }
  
  final youtubeService = ref.watch(youtubeServiceProvider);
  final results = await youtubeService.searchSongs(query);
  
  // Cache the new results locally for offline/instant load
  final jsonList = results.map((song) => song.toMap()).toList();
  await prefs.setString('cached_search_results', jsonEncode(jsonList));
  
  return results;
});
