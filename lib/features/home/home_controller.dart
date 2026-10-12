import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/youtube_service.dart';
import '../../models/song.dart';
import '../../services/history_service.dart';

class HomeCategory {
  final String id;
  final String locKey;
  final String icon;
  final String query;
  final List<Song> fallbackSongs;

  const HomeCategory({
    required this.id,
    required this.locKey,
    required this.icon,
    required this.query,
    required this.fallbackSongs,
  });
}

/// Dedicated Turkish sub-categories (Pop, Rap, Rock, Klasik, Soft)
final turkishSubCategories = <HomeCategory>[
  HomeCategory(
    id: 'turkey_pop',
    locKey: 'turkey_pop',
    icon: '🎤',
    query: 'Türkçe Pop yeni hit şarkılar official audio',
    fallbackSongs: [
      Song(videoId: '-O22D3EV6G0', title: 'Lan', author: 'Zeynep Bastık', thumbnailUrl: 'https://img.youtube.com/vi/-O22D3EV6G0/hqdefault.jpg', durationMs: 199000),
      Song(videoId: 'RQmXet6kZ-Y', title: 'Ateşe Düştüm', author: 'Mert Demir', thumbnailUrl: 'https://img.youtube.com/vi/RQmXet6kZ-Y/hqdefault.jpg', durationMs: 230000),
      Song(videoId: 'h5l8fIvFRP4', title: 'Mesafe', author: 'Semicenk', thumbnailUrl: 'https://img.youtube.com/vi/h5l8fIvFRP4/hqdefault.jpg', durationMs: 232000),
      Song(videoId: 'i6CSvLvSNZ4', title: 'Antidepresan', author: 'Mert Demir feat. Mabel Matiz', thumbnailUrl: 'https://img.youtube.com/vi/i6CSvLvSNZ4/hqdefault.jpg', durationMs: 240000),
      Song(videoId: 'stKHZQb4hn4', title: 'Aşkın Olayım', author: 'Simge Sağın', thumbnailUrl: 'https://img.youtube.com/vi/stKHZQb4hn4/hqdefault.jpg', durationMs: 252000),
      Song(videoId: 'gi80-tmEduI', title: 'Yalnız Çiçek', author: 'Aleyna Tilki ft. Emrah Karaduman', thumbnailUrl: 'https://img.youtube.com/vi/gi80-tmEduI/hqdefault.jpg', durationMs: 240000),
      Song(videoId: 'Tb-zjsEqr1k', title: 'İnceden İnceden', author: 'Tuğba Yurt', thumbnailUrl: 'https://img.youtube.com/vi/Tb-zjsEqr1k/hqdefault.jpg', durationMs: 192000),
    ],
  ),
  HomeCategory(
    id: 'turkey_rap',
    locKey: 'turkey_rap',
    icon: '🎧',
    query: 'Türkçe Rap yeni hit official audio',
    fallbackSongs: [
      Song(videoId: 'mY--4-vzY6E', title: 'Suspus', author: 'Ceza', thumbnailUrl: 'https://img.youtube.com/vi/mY--4-vzY6E/hqdefault.jpg', durationMs: 261000),
      Song(videoId: 'CNXGQ0eKphM', title: 'Şarkılar Sokaklara Ait', author: 'UZI & Motive', thumbnailUrl: 'https://img.youtube.com/vi/CNXGQ0eKphM/hqdefault.jpg', durationMs: 180000),
      Song(videoId: 'QDS6xS6uo1I', title: 'Hayata Küstüm', author: 'Cash Flow', thumbnailUrl: 'https://img.youtube.com/vi/QDS6xS6uo1I/hqdefault.jpg', durationMs: 208000),
      Song(videoId: 'DOuWjI5qABk', title: 'Leylim Yar', author: 'Canbay & Wolker', thumbnailUrl: 'https://img.youtube.com/vi/DOuWjI5qABk/hqdefault.jpg', durationMs: 166000),
      Song(videoId: 'Pv08geuhFcU', title: 'Çatla', author: 'Velet', thumbnailUrl: 'https://img.youtube.com/vi/Pv08geuhFcU/hqdefault.jpg', durationMs: 143000),
      Song(videoId: 'W1obTj5uso8', title: 'Olabilir', author: 'MERO', thumbnailUrl: 'https://img.youtube.com/vi/W1obTj5uso8/hqdefault.jpg', durationMs: 235000),
    ],
  ),
  HomeCategory(
    id: 'turkey_rock',
    locKey: 'turkey_rock',
    icon: '🎸',
    query: 'Türkçe Rock official audio',
    fallbackSongs: [
      Song(videoId: '3bfkyXtuIXk', title: 'Senden Daha Güzel', author: 'Duman', thumbnailUrl: 'https://img.youtube.com/vi/3bfkyXtuIXk/hqdefault.jpg', durationMs: 239000),
      Song(videoId: '7RW8n4iXZbA', title: 'Bir Derdim Var', author: 'Mor ve Ötesi', thumbnailUrl: 'https://img.youtube.com/vi/7RW8n4iXZbA/hqdefault.jpg', durationMs: 202000),
      Song(videoId: 'WJL2qW6_weQ', title: 'Alışırım Gözlerimi Kapamaya', author: 'maNga', thumbnailUrl: 'https://img.youtube.com/vi/WJL2qW6_weQ/hqdefault.jpg', durationMs: 354000),
      Song(videoId: 'MqEVljq65kY', title: 'Pembe Mezarlık', author: 'Model', thumbnailUrl: 'https://img.youtube.com/vi/MqEVljq65kY/hqdefault.jpg', durationMs: 255000),
      Song(videoId: 'yjGigzkkXMM', title: 'Sil Baştan', author: 'Şebnem Ferah', thumbnailUrl: 'https://img.youtube.com/vi/yjGigzkkXMM/hqdefault.jpg', durationMs: 316000),
      Song(videoId: 'SjKZdvAmSTo', title: 'Bir', author: 'Pentagram', thumbnailUrl: 'https://img.youtube.com/vi/SjKZdvAmSTo/hqdefault.jpg', durationMs: 258000),
      Song(videoId: '77ygz-MC6_8', title: 'Dönence', author: 'Barış Manço', thumbnailUrl: 'https://img.youtube.com/vi/77ygz-MC6_8/hqdefault.jpg', durationMs: 411000),
    ],
  ),
  HomeCategory(
    id: 'turkey_classical',
    locKey: 'turkey_classical',
    icon: '🎻',
    query: 'Türk Sanat Müziği Klasik official audio',
    fallbackSongs: [
      Song(videoId: 'QwK6HDk7Pgs', title: 'Gitme Sana Muhtacım', author: 'Zeki Müren', thumbnailUrl: 'https://img.youtube.com/vi/QwK6HDk7Pgs/hqdefault.jpg', durationMs: 250000),
      Song(videoId: 'HMRc4E3N46g', title: 'Benzemez Kimse Sana', author: 'Müzeyyen Senar & Tarkan', thumbnailUrl: 'https://img.youtube.com/vi/HMRc4E3N46g/hqdefault.jpg', durationMs: 260000),
      Song(videoId: 'RzEJzHH_3vw', title: 'Çile Bülbülüm Çile', author: 'Safiye Ayla', thumbnailUrl: 'https://img.youtube.com/vi/RzEJzHH_3vw/hqdefault.jpg', durationMs: 220000),
    ],
  ),
  HomeCategory(
    id: 'turkey_soft',
    locKey: 'turkey_soft',
    icon: '☕',
    query: 'Türkçe Akustik dinlendirici şarkılar official audio',
    fallbackSongs: [
      Song(videoId: 'oD6fL4yyhDk', title: 'Sar Bu Şehri', author: 'Can Ozan', thumbnailUrl: 'https://img.youtube.com/vi/oD6fL4yyhDk/hqdefault.jpg', durationMs: 215000),
      Song(videoId: 'TaUuYrpvMS0', title: 'Uzunlar', author: 'Evdeki Saat', thumbnailUrl: 'https://img.youtube.com/vi/TaUuYrpvMS0/hqdefault.jpg', durationMs: 235000),
      Song(videoId: 'NZ926mNdt1w', title: 'Nalan', author: 'Emir Can İğrek', thumbnailUrl: 'https://img.youtube.com/vi/NZ926mNdt1w/hqdefault.jpg', durationMs: 210000),
    ],
  ),
];

/// All main home categories
final homeGenreCategories = <HomeCategory>[
  HomeCategory(
    id: 'trending_now',
    locKey: 'trending_now',
    icon: '🔥',
    query: 'Top Trending songs official music video',
    fallbackSongs: [
      Song(videoId: 'ekr2nIex040', title: 'APT.', author: 'ROSÉ & Bruno Mars', thumbnailUrl: 'https://img.youtube.com/vi/ekr2nIex040/hqdefault.jpg', durationMs: 173000),
      Song(videoId: 'kPa7bsKwL-c', title: 'Die With A Smile', author: 'Lady Gaga, Bruno Mars', thumbnailUrl: 'https://img.youtube.com/vi/kPa7bsKwL-c/hqdefault.jpg', durationMs: 252000),
      Song(videoId: 'd5gf9dXbPi0', title: 'BIRDS OF A FEATHER', author: 'Billie Eilish', thumbnailUrl: 'https://img.youtube.com/vi/d5gf9dXbPi0/hqdefault.jpg', durationMs: 211000),
      Song(videoId: 'KEG7b851Ric', title: 'Taste', author: 'Sabrina Carpenter', thumbnailUrl: 'https://img.youtube.com/vi/KEG7b851Ric/hqdefault.jpg', durationMs: 199000),
      Song(videoId: 't7bQwwqW-Hc', title: 'A Bar Song (Tipsy)', author: 'Shaboozey', thumbnailUrl: 'https://img.youtube.com/vi/t7bQwwqW-Hc/hqdefault.jpg', durationMs: 174000),
      Song(videoId: 'Oa_RSwwpPaA', title: 'Beautiful Things', author: 'Benson Boone', thumbnailUrl: 'https://img.youtube.com/vi/Oa_RSwwpPaA/hqdefault.jpg', durationMs: 193000),
      Song(videoId: 'GZ3zL7kT6_c', title: 'Lose Control', author: 'Teddy Swims', thumbnailUrl: 'https://img.youtube.com/vi/GZ3zL7kT6_c/hqdefault.jpg', durationMs: 241000),
      Song(videoId: '1RKqOmSkGgM', title: 'Good Luck, Babe!', author: 'Chappell Roan', thumbnailUrl: 'https://img.youtube.com/vi/1RKqOmSkGgM/hqdefault.jpg', durationMs: 218000),
      Song(videoId: 'MLlSSJ0z7xM', title: 'Dancing in the Flames', author: 'The Weeknd', thumbnailUrl: 'https://img.youtube.com/vi/MLlSSJ0z7xM/hqdefault.jpg', durationMs: 256000),
      Song(videoId: 'zG5YzRxOcsI', title: 'MILLION DOLLAR BABY', author: 'Tommy Richman', thumbnailUrl: 'https://img.youtube.com/vi/zG5YzRxOcsI/hqdefault.jpg', durationMs: 155000),
      Song(videoId: '9p9EauIOPm8', title: 'Stargazing', author: 'Myles Smith', thumbnailUrl: 'https://img.youtube.com/vi/9p9EauIOPm8/hqdefault.jpg', durationMs: 175000),
      Song(videoId: 'G_lNBrDJQC8', title: 'That’s So True', author: 'Gracie Abrams', thumbnailUrl: 'https://img.youtube.com/vi/G_lNBrDJQC8/hqdefault.jpg', durationMs: 168000),
    ],
  ),
  HomeCategory(
    id: 'top_hits',
    locKey: 'top_hits',
    icon: '🌟',
    query: 'Global Top Hits official audio',
    fallbackSongs: [
      Song(videoId: 'eVli-tstM5E', title: 'Espresso', author: 'Sabrina Carpenter', thumbnailUrl: 'https://img.youtube.com/vi/eVli-tstM5E/hqdefault.jpg', durationMs: 201000),
      Song(videoId: '4QIZE708gJ4', title: 'I Had Some Help', author: 'Post Malone ft. Morgan Wallen', thumbnailUrl: 'https://img.youtube.com/vi/4QIZE708gJ4/hqdefault.jpg', durationMs: 202000),
      Song(videoId: 'KNtJGQkC-WI', title: 'we can\'t be friends', author: 'Ariana Grande', thumbnailUrl: 'https://img.youtube.com/vi/KNtJGQkC-WI/hqdefault.jpg', durationMs: 283000),
      Song(videoId: 'q3zqJs7JUCQ', title: 'Fortnight', author: 'Taylor Swift ft. Post Malone', thumbnailUrl: 'https://img.youtube.com/vi/q3zqJs7JUCQ/hqdefault.jpg', durationMs: 250000),
      Song(videoId: 'Fqey8LxQxFU', title: 'vampire', author: 'Olivia Rodrigo', thumbnailUrl: 'https://img.youtube.com/vi/Fqey8LxQxFU/hqdefault.jpg', durationMs: 220000),
      Song(videoId: 'G7KNmW9a75Y', title: 'Flowers', author: 'Miley Cyrus', thumbnailUrl: 'https://img.youtube.com/vi/G7KNmW9a75Y/hqdefault.jpg', durationMs: 202000),
      Song(videoId: 'aezstCBHOPQ', title: 'Too Sweet', author: 'Hozier', thumbnailUrl: 'https://img.youtube.com/vi/aezstCBHOPQ/hqdefault.jpg', durationMs: 252000),
      Song(videoId: 'TUVcZfQe-Kw', title: 'Levitating', author: 'Dua Lipa', thumbnailUrl: 'https://img.youtube.com/vi/TUVcZfQe-Kw/hqdefault.jpg', durationMs: 230000),
    ],
  ),
  ...turkishSubCategories,
  HomeCategory(
    id: 'pop_hits',
    locKey: 'pop_hits',
    icon: '🎤',
    query: 'Pop Hits official audio',
    fallbackSongs: [
      Song(videoId: 'ic8j13piAhQ', title: 'Cruel Summer', author: 'Taylor Swift', thumbnailUrl: 'https://img.youtube.com/vi/ic8j13piAhQ/hqdefault.jpg', durationMs: 178000),
      Song(videoId: 'H5v3kku4y6Q', title: 'As It Was', author: 'Harry Styles', thumbnailUrl: 'https://img.youtube.com/vi/H5v3kku4y6Q/hqdefault.jpg', durationMs: 167000),
      Song(videoId: 'MB3VkzPdgLA', title: 'LUNCH', author: 'Billie Eilish', thumbnailUrl: 'https://img.youtube.com/vi/MB3VkzPdgLA/hqdefault.jpg', durationMs: 180000),
      Song(videoId: 'JGwWNGJdvx8', title: 'Shape of You', author: 'Ed Sheeran', thumbnailUrl: 'https://img.youtube.com/vi/JGwWNGJdvx8/hqdefault.jpg', durationMs: 233000),
    ],
  ),
  HomeCategory(
    id: 'rap_hip_hop',
    locKey: 'rap_hip_hop',
    icon: '🎧',
    query: 'Rap Hip Hop hits official audio',
    fallbackSongs: [
      Song(videoId: 'T6eK-2OQtew', title: 'Not Like Us', author: 'Kendrick Lamar', thumbnailUrl: 'https://img.youtube.com/vi/T6eK-2OQtew/hqdefault.jpg', durationMs: 273000),
      Song(videoId: '22tVWwmTie8', title: 'Houdini', author: 'Eminem', thumbnailUrl: 'https://img.youtube.com/vi/22tVWwmTie8/hqdefault.jpg', durationMs: 297000),
      Song(videoId: 'B9synWjqBn8', title: 'FE!N', author: 'Travis Scott', thumbnailUrl: 'https://img.youtube.com/vi/B9synWjqBn8/hqdefault.jpg', durationMs: 210000),
      Song(videoId: 'xpVfcZ0ZcFM', title: 'God\'s Plan', author: 'Drake', thumbnailUrl: 'https://img.youtube.com/vi/xpVfcZ0ZcFM/hqdefault.jpg', durationMs: 199000),
      Song(videoId: 'Iq8h3GEe22o', title: 'Lovin On Me', author: 'Jack Harlow', thumbnailUrl: 'https://img.youtube.com/vi/Iq8h3GEe22o/hqdefault.jpg', durationMs: 138000),
    ],
  ),
  HomeCategory(
    id: 'rock_alternative',
    locKey: 'rock_alternative',
    icon: '🎸',
    query: 'Rock Alternative Hits official audio',
    fallbackSongs: [
      Song(videoId: 'SRXH9AbT280', title: 'The Emptiness Machine', author: 'Linkin Park', thumbnailUrl: 'https://img.youtube.com/vi/SRXH9AbT280/hqdefault.jpg', durationMs: 190000),
      Song(videoId: 'V3IVdLo-2NM', title: 'feelslikeimfallinginlove', author: 'Coldplay', thumbnailUrl: 'https://img.youtube.com/vi/V3IVdLo-2NM/hqdefault.jpg', durationMs: 261000),
      Song(videoId: 'v08qmr8m_-w', title: 'Eyes Closed', author: 'Imagine Dragons', thumbnailUrl: 'https://img.youtube.com/vi/v08qmr8m_-w/hqdefault.jpg', durationMs: 249000),
      Song(videoId: 'hTWKbfoikeg', title: 'Smells Like Teen Spirit', author: 'Nirvana', thumbnailUrl: 'https://img.youtube.com/vi/hTWKbfoikeg/hqdefault.jpg', durationMs: 301000),
      Song(videoId: 'fJ9rUzIMcZQ', title: 'Bohemian Rhapsody', author: 'Queen', thumbnailUrl: 'https://img.youtube.com/vi/fJ9rUzIMcZQ/hqdefault.jpg', durationMs: 359000),
    ],
  ),
  HomeCategory(
    id: 'electronic_dance',
    locKey: 'electronic_dance',
    icon: '⚡',
    query: 'EDM Dance Festival club hits official audio',
    fallbackSongs: [
      Song(videoId: 'x8Y8k4w2z1o', title: '(It Goes Like) Nanana', author: 'Peggy Gou', thumbnailUrl: 'https://img.youtube.com/vi/x8Y8k4w2z1o/hqdefault.jpg', durationMs: 231000),
      Song(videoId: '90RLzVUuuc4', title: 'I\'m Good (Blue)', author: 'David Guetta & Bebe Rexha', thumbnailUrl: 'https://img.youtube.com/vi/90RLzVUuuc4/hqdefault.jpg', durationMs: 175000),
      Song(videoId: '1_4FL96144M', title: 'The Business', author: 'Tiësto', thumbnailUrl: 'https://img.youtube.com/vi/1_4FL96144M/hqdefault.jpg', durationMs: 164000),
      Song(videoId: 'o7_3p3t2g1s', title: 'Miracle', author: 'Calvin Harris, Ellie Goulding', thumbnailUrl: 'https://img.youtube.com/vi/o7_3p3t2g1s/hqdefault.jpg', durationMs: 186000),
    ],
  ),
  HomeCategory(
    id: 'chill_rnb',
    locKey: 'chill_rnb',
    icon: '🌙',
    query: 'Acoustic Chill relaxing music official audio',
    fallbackSongs: [
      Song(videoId: 'hKgl5-lkT8U', title: 'Best Part', author: 'Daniel Caesar ft. H.E.R.', thumbnailUrl: 'https://img.youtube.com/vi/hKgl5-lkT8U/hqdefault.jpg', durationMs: 243000),
      Song(videoId: 'LDY_Xa77Hoo', title: 'Snooze', author: 'SZA', thumbnailUrl: 'https://img.youtube.com/vi/LDY_Xa77Hoo/hqdefault.jpg', durationMs: 294000),
      Song(videoId: 'sT8qf2W_e9A', title: 'Lost', author: 'Frank Ocean', thumbnailUrl: 'https://img.youtube.com/vi/sT8qf2W_e9A/hqdefault.jpg', durationMs: 235000),
      Song(videoId: 'viimfQi_pUw', title: 'ocean eyes', author: 'Billie Eilish', thumbnailUrl: 'https://img.youtube.com/vi/viimfQi_pUw/hqdefault.jpg', durationMs: 200000),
    ],
  ),
];

class SelectedGenreFilterNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setGenre(String genre) {
    state = genre;
  }
}

final selectedGenreFilterProvider = NotifierProvider<SelectedGenreFilterNotifier, String>(() {
  return SelectedGenreFilterNotifier();
});

/// Turkish Sub-Genre Filter Notifier (all, turkey_pop, turkey_rap, turkey_rock, turkey_classical, turkey_soft)
class SelectedTurkishSubGenreNotifier extends Notifier<String> {
  @override
  String build() => 'all';

  void setSubGenre(String sub) {
    state = sub;
  }
}

final selectedTurkishSubGenreProvider = NotifierProvider<SelectedTurkishSubGenreNotifier, String>(() {
  return SelectedTurkishSubGenreNotifier();
});

/// Map of category ID -> `List<Song>`.
/// Keys are stable IDs: 'trending_now', 'top_hits', 'turkey_pop', 'turkey_rap', etc.
final homeFeedProvider = FutureProvider<Map<String, List<Song>>>((ref) async {
  final ytService = ref.watch(youtubeServiceProvider);
  final prefs = await SharedPreferences.getInstance();
  final historyService = ref.watch(historyServiceProvider);
  
  // 1. Initialize default category map with verified, accurate 2024-2026 fallback songs
  final Map<String, List<Song>> feedData = {};
  for (final cat in homeGenreCategories) {
    feedData[cat.id] = List<Song>.from(cat.fallbackSongs);
  }

  // 2. Try loading cached songs from SharedPreferences (v4 cache)
  final cachedData = prefs.getString('cached_home_feed_v5');
  if (cachedData != null) {
    try {
      final Map<String, dynamic> decoded = jsonDecode(cachedData);
      for (final entry in decoded.entries) {
        final list = (entry.value as List).map((e) => Song.fromMap(e)).toList();
        if (list.isNotEmpty && entry.key != 'trending_now') {
          feedData[entry.key] = list;
        }
      }
    } catch (e) {
      debugPrint('Cache decode error: $e');
    }
  }

  // 3. User History (if available)
  final history = historyService.getHistory();
  if (history.isNotEmpty) {
    feedData['continue_where_you_left_off'] = history.take(8).toList();
    
    // Recommended songs based on last played
    try {
      final lastPlayed = history.first;
      final related = await ytService.getRelatedVideos(lastPlayed.videoId);
      if (related.isNotEmpty) {
        feedData['recommended_songs'] = related.take(8).toList();
      }
    } catch (e) {
      debugPrint('Error getting related songs: $e');
    }
  }

  // 4. Trending Now is strictly guarded: always keep the curated 2024-2026 tracklist!
  feedData['trending_now'] = List<Song>.from(homeGenreCategories.first.fallbackSongs);

  // 5. Persist updated feed to cache
  try {
    final jsonMap = feedData.map((key, value) => MapEntry(key, value.map((e) => e.toMap()).toList()));
    await prefs.setString('cached_home_feed_v5', jsonEncode(jsonMap));
  } catch (e) {
    debugPrint('Error saving cached home feed: $e');
  }

  return feedData;
});
