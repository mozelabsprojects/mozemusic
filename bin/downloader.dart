// ignore_for_file: avoid_print, prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:io';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

void main(List<String> args) async {
  // Set Windows console UTF-8 output if possible
  stdout.encoding = SystemEncoding();

  printHeader();

  final yt = YoutubeExplode();
  final saveDir = getDownloadDirectory();

  print('📂 Kayıt Klasörü: ${saveDir.path}\n');

  bool running = true;
  while (running) {
    stdout.write('🎵 Şarkı adı veya YouTube bağlantısı girin (Çıkış için "q"): ');
    final input = stdin.readLineSync()?.trim() ?? '';

    if (input.isEmpty) {
      continue;
    }

    if (input.toLowerCase() == 'q' || input.toLowerCase() == 'exit' || input.toLowerCase() == 'cikis') {
      running = false;
      break;
    }

    try {
      await processDownload(yt, input, saveDir);
    } catch (e) {
      print('\n❌ Hata oluştu: $e\n');
    }

    print('\n' + ('─' * 50) + '\n');
  }

  yt.close();
  print('\n👋 MozeMusic İndirme Aracı kapatılıyor. İyi dinlemeler!');
  await Future.delayed(const Duration(seconds: 1));
}

void printHeader() {
  print('╔══════════════════════════════════════════════════════════╗');
  print('║             MOZEMUSIC ŞARKI İNDİRME ARACI                ║');
  print('║         Yüksek Kalite YouTube Ses & Müzik İndirici       ║');
  print('╚══════════════════════════════════════════════════════════╝');
  print('');
}

Directory getDownloadDirectory() {
  // Prioritize Desktop/MozeMusic_Indirilenler for immediate convenience
  final userProfile = Platform.environment['USERPROFILE'] ?? 'C:\\Users\\W10';
  final desktopDir = Directory('$userProfile\\Desktop\\MozeMusic_Indirilenler');
  if (!desktopDir.existsSync()) {
    desktopDir.createSync(recursive: true);
  }
  return desktopDir;
}

String sanitizeFilename(String name) {
  return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
}

Future<void> processDownload(YoutubeExplode yt, String query, Directory saveDir) async {
  Video? video;

  // Check if query is a direct YouTube link / ID
  final isUrl = query.contains('youtube.com') || query.contains('youtu.be');
  if (isUrl) {
    stdout.write('🔍 Bağlantı çözülüyor...');
    try {
      video = await yt.videos.get(query);
    } catch (e) {
      print(' Başarısız!');
      print('⚠️ Bağlantı doğrudan okunamadı, arama yapılıyor...');
    }
  }

  if (video == null) {
    stdout.write('🔍 "$query" aranıyor...');
    final searchResults = await yt.search.search(query);
    if (searchResults.isEmpty) {
      print(' Bulunamadı!');
      print('⚠️ Arama sonucu bulunamadı.');
      return;
    }
    video = searchResults.first;
    print(' Bulundu! ✅');
  }

  print('\n📌 Bulunan: ${video.title}');
  print('🎤 Sanatçı: ${video.author}');
  print('⏱️  Süre   : ${video.duration?.inMinutes}:${((video.duration?.inSeconds ?? 0) % 60).toString().padLeft(2, '0')}');

  stdout.write('⏳ Akış bilgileri alınıyor...');
  final manifest = await yt.videos.streamsClient.getManifest(video.id);
  print(' Hazır! ✅');

  // Find best audio stream or muxed stream
  // Notice: standalone audio-only streams on YouTube sometimes face 403, muxed mp4 is rock-solid.
  final audioStreams = manifest.audioOnly.toList()..sort((a, b) => b.bitrate.compareTo(a.bitrate));
  final muxedMp4 = manifest.muxed.where((s) => s.container.name.toLowerCase() == 'mp4').toList()
    ..sort((a, b) => b.bitrate.compareTo(a.bitrate));

  StreamInfo? selectedStream;
  String extension = 'm4a';

  if (audioStreams.isNotEmpty) {
    selectedStream = audioStreams.first;
    extension = selectedStream.container.name;
    if (extension.toLowerCase() == 'mp4') extension = 'm4a';
  } else if (muxedMp4.isNotEmpty) {
    selectedStream = muxedMp4.first;
    extension = 'mp4';
  } else if (manifest.muxed.isNotEmpty) {
    selectedStream = manifest.muxed.first;
    extension = 'mp4';
  }

  if (selectedStream == null) {
    print('❌ İndirilebilir ses akışı bulunamadı.');
    return;
  }

  final cleanTitle = sanitizeFilename('${video.author} - ${video.title}');
  final filePath = '${saveDir.path}\\$cleanTitle.$extension';
  final outputFile = File(filePath);

  final totalBytes = selectedStream.size.totalBytes;
  final totalMb = (totalBytes / (1024 * 1024)).toStringAsFixed(2);

  print('\n⬇️  İndiriliyor: $cleanTitle.$extension ($totalMb MB)');

  final stream = yt.videos.streamsClient.get(selectedStream);
  final outputSink = outputFile.openWrite();

  int downloaded = 0;
  final stopwatch = Stopwatch()..start();

  try {
    await for (final chunk in stream) {
      outputSink.add(chunk);
      downloaded += chunk.length;

      final progress = totalBytes > 0 ? (downloaded / totalBytes) : 0.0;
      final percent = (progress * 100).toStringAsFixed(1);
      final currentMb = (downloaded / (1024 * 1024)).toStringAsFixed(2);

      final speed = downloaded / (stopwatch.elapsedMilliseconds / 1000 + 0.001);
      final speedMb = (speed / (1024 * 1024)).toStringAsFixed(2);

      final barWidth = 24;
      final filled = (progress * barWidth).clamp(0, barWidth).toInt();
      final bar = '█' * filled + '░' * (barWidth - filled);

      stdout.write('\r[$bar] $percent% ($currentMb / $totalMb MB) - $speedMb MB/s  ');
    }
    await outputSink.flush();
    await outputSink.close();
    stopwatch.stop();

    print('\n🎉 Tamamlandı! Dosya kaydedildi:');
    print('   $filePath');
  } catch (e) {
    await outputSink.close();
    if (outputFile.existsSync()) {
      try { outputFile.deleteSync(); } catch (_) {}
    }
    print('\n⚠️ İndirme sırasında hata: $e');
  }
}
