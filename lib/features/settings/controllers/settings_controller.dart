import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsState {
  final bool autoplay;
  final String audioQuality;
  final String downloadQuality;
  final String language;
  final ThemeMode themeMode;

  SettingsState({
    required this.autoplay,
    required this.audioQuality,
    required this.downloadQuality,
    required this.language,
    required this.themeMode,
  });

  SettingsState copyWith({
    bool? autoplay,
    String? audioQuality,
    String? downloadQuality,
    String? language,
    ThemeMode? themeMode,
  }) {
    return SettingsState(
      autoplay: autoplay ?? this.autoplay,
      audioQuality: audioQuality ?? this.audioQuality,
      downloadQuality: downloadQuality ?? this.downloadQuality,
      language: language ?? this.language,
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

final sharedPrefsProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('Initialize this in main.dart');
});

class SettingsNotifier extends Notifier<SettingsState> {
  @override
  SettingsState build() {
    final prefs = ref.watch(sharedPrefsProvider);
    return SettingsState(
      autoplay: prefs.getBool('autoplay') ?? true,
      audioQuality: prefs.getString('audioQuality') ?? 'High',
      downloadQuality: prefs.getString('downloadQuality') ?? 'Standard',
      language: prefs.getString('language') ?? 'English',
      themeMode: prefs.getBool('isDark') ?? true ? ThemeMode.dark : ThemeMode.light,
    );
  }

  Future<void> updateAutoplay(bool value) async {
    await ref.read(sharedPrefsProvider).setBool('autoplay', value);
    state = state.copyWith(autoplay: value);
  }

  Future<void> updateAudioQuality(String value) async {
    await ref.read(sharedPrefsProvider).setString('audioQuality', value);
    state = state.copyWith(audioQuality: value);
  }

  Future<void> updateDownloadQuality(String value) async {
    await ref.read(sharedPrefsProvider).setString('downloadQuality', value);
    state = state.copyWith(downloadQuality: value);
  }

  Future<void> updateLanguage(String value) async {
    await ref.read(sharedPrefsProvider).setString('language', value);
    state = state.copyWith(language: value);
  }

  Future<void> updateThemeMode(ThemeMode mode) async {
    await ref.read(sharedPrefsProvider).setBool('isDark', mode == ThemeMode.dark);
    state = state.copyWith(themeMode: mode);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsState>(() {
  return SettingsNotifier();
});
