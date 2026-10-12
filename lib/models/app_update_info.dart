class AppUpdateInfo {
  final String latestVersion;
  final String minRequiredVersion;
  final bool forceUpdate;
  final String title;
  final String releaseNotes;
  final String downloadUrlWindows;
  final String downloadUrlAndroid;
  final String releaseDate;

  AppUpdateInfo({
    required this.latestVersion,
    required this.minRequiredVersion,
    required this.forceUpdate,
    required this.title,
    required this.releaseNotes,
    required this.downloadUrlWindows,
    required this.downloadUrlAndroid,
    required this.releaseDate,
  });

  factory AppUpdateInfo.fromMap(Map<String, dynamic> map) {
    return AppUpdateInfo(
      latestVersion: map['latestVersion']?.toString() ?? '1.0.0',
      minRequiredVersion: map['minRequiredVersion']?.toString() ?? '1.0.0',
      forceUpdate: map['forceUpdate'] == true,
      title: map['title']?.toString() ?? 'Yeni Güncelleme Mevcut! 🚀',
      releaseNotes: map['releaseNotes']?.toString() ?? 'Performans iyileştirmeleri ve hata düzeltmeleri.',
      downloadUrlWindows: map['downloadUrlWindows']?.toString() ?? 'https://github.com/mozelabsprojects/mozemusic/releases',
      downloadUrlAndroid: map['downloadUrlAndroid']?.toString() ?? 'https://github.com/mozelabsprojects/mozemusic/releases',
      releaseDate: map['releaseDate']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latestVersion': latestVersion,
      'minRequiredVersion': minRequiredVersion,
      'forceUpdate': forceUpdate,
      'title': title,
      'releaseNotes': releaseNotes,
      'downloadUrlWindows': downloadUrlWindows,
      'downloadUrlAndroid': downloadUrlAndroid,
      'releaseDate': releaseDate,
    };
  }
}
