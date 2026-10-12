import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/auth_service.dart';
import '../../../services/device_playback_sync_service.dart';
import '../../../services/audio_handler.dart';
import '../../jam_room/qr_scanner_screen.dart';

class DeviceConnectModal extends ConsumerStatefulWidget {
  const DeviceConnectModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const DeviceConnectModal(),
    );
  }

  @override
  ConsumerState<DeviceConnectModal> createState() => _DeviceConnectModalState();
}

class _DeviceConnectModalState extends ConsumerState<DeviceConnectModal> {
  final _codeController = TextEditingController();
  bool _isPairing = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _handleApproveCode(String rawCode) async {
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) return;

    setState(() => _isPairing = true);
    try {
      await ref.read(authServiceProvider).approvePairSession(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🎉 Masaüstü oturumu başarıyla bağlandı!'),
          backgroundColor: Color(0xFF1DB954),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hata: ${e.toString().replaceFirst("Exception: ", "")}'),
          backgroundColor: Colors.red[800],
        ),
      );
    } finally {
      if (mounted) setState(() => _isPairing = false);
    }
  }

  Future<void> _showDesktopPairQR(BuildContext parentContext) async {
    final authService = ref.read(authServiceProvider);
    String? pairCode;
    try {
      pairCode = await authService.createDevicePairSession();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Hata: $e'), backgroundColor: Colors.red[800]),
      );
      return;
    }

    if (!parentContext.mounted) return;

    showDialog(
      context: parentContext,
      builder: (dialogCtx) {
        return StreamBuilder(
          stream: authService.listenToPairSession(pairCode!),
          builder: (context, snapshot) {
            final data = snapshot.data?.data();
            final isApproved = data?['status'] == 'approved';

            if (isApproved && data != null) {
              Future.microtask(() async {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                await authService.completePairOnDesktop(pairCode!, data);
              });

              return AlertDialog(
                backgroundColor: AppTheme.surfaceLight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                content: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 16),
                    Icon(Icons.check_circle_rounded, color: Color(0xFF1DB954), size: 64),
                    SizedBox(height: 16),
                    Text('Giriş Başarılı!', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Masaüstü oturumu senkronize ediliyor...', style: TextStyle(color: Colors.white70)),
                    SizedBox(height: 16),
                  ],
                ),
              );
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF181818),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Color(0xFF1DB954), size: 28),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text('Telefon ile Hızlı Eşleştir', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Telefonunuzdaki MozeMusic uygulamasında Profil > "Moze Connect" seçeneğine dokunarak bu QR kodu tarayın:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: QrImageView(
                      data: pairCode!,
                      version: QrVersions.auto,
                      size: 170.0,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('Eşleşme Kodu: ', style: TextStyle(color: Colors.white60, fontSize: 13)),
                        Text(
                          pairCode,
                          style: const TextStyle(
                            color: Color(0xFF1DB954),
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1DB954))),
                      SizedBox(width: 10),
                      Text('Telefondan onay bekleniyor...', style: TextStyle(color: Colors.white54, fontSize: 12)),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final syncService = ref.watch(devicePlaybackSyncServiceProvider);
    final remoteStateAsync = ref.watch(remotePlaybackStateProvider);
    final audioHandler = ref.watch(audioHandlerProvider);
    final localMediaItem = audioHandler.mediaItem.value;
    final user = FirebaseAuth.instance.currentUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF181818) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black26,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.devices_rounded,
                  color: Color(0xFF1DB954),
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Moze Connect & Cihazlar',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    Text(
                      user != null
                          ? '${user.displayName ?? user.email ?? "Kullanıcı"} hesabı • Kesintisiz Müzik'
                          : 'Cihazlar arası uzaktan kontrol & aktarım',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Current Device Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFF1DB954).withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isDesktop ? Icons.laptop_mac_rounded : Icons.phone_android_rounded,
                  color: const Color(0xFF1DB954),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            syncService.deviceName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1DB954).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Bu Cihaz',
                              style: TextStyle(
                                color: Color(0xFF1DB954),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        localMediaItem != null
                            ? 'Şu anda çalıyor: ${localMediaItem.title}'
                            : 'Aktif dinleme cihazı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Remote Device Card (Interactive Remote Control Hub)
          remoteStateAsync.when(
            data: (remote) {
              if (remote == null) {
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off_rounded, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 10),
                      Text(
                        'Diğer cihazda şu anda müzik çalmıyor',
                        style: TextStyle(color: Colors.grey[500], fontSize: 12),
                      ),
                    ],
                  ),
                );
              }

              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF7F7F7),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFF1DB954).withValues(alpha: 0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top row: Device Info + Live status badge
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1DB954).withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            remote.deviceType == 'mobile'
                                ? Icons.phone_android_rounded
                                : Icons.laptop_mac_rounded,
                            color: const Color(0xFF1DB954),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    remote.deviceName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1DB954),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                remote.isPlaying ? 'Canlı Çalıyor • Uzaktan Kontrol' : 'Duraklatıldı',
                                style: TextStyle(
                                  color: remote.isPlaying ? const Color(0xFF1DB954) : Colors.grey,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Middle: Song info & thumbnail
                    Row(
                      children: [
                        if (remote.thumbnailUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: remote.thumbnailUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(width: 48, height: 48, color: Colors.grey[800]),
                              errorWidget: (context, url, error) => Container(width: 48, height: 48, color: Colors.grey[800]),
                            ),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                remote.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                remote.artist,
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 12,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Remote Playback Controls (Previous, Play/Pause, Next)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: Icon(Icons.skip_previous_rounded, size: 30, color: isDark ? Colors.white70 : Colors.black87),
                          tooltip: 'Önceki (Uzaktan)',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            syncService.sendRemoteCommand(targetDeviceId: remote.deviceId, action: 'skipPrevious');
                          },
                        ),
                        const SizedBox(width: 16),
                        Material(
                          color: const Color(0xFF1DB954),
                          shape: const CircleBorder(),
                          elevation: 4,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.mediumImpact();
                              syncService.sendRemoteCommand(targetDeviceId: remote.deviceId, action: 'toggle');
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Icon(
                                remote.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 28,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded, size: 30, color: isDark ? Colors.white70 : Colors.black87),
                          tooltip: 'Sonraki (Uzaktan)',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            syncService.sendRemoteCommand(targetDeviceId: remote.deviceId, action: 'skipNext');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Remote Volume Slider
                    Row(
                      children: [
                        Icon(Icons.volume_down_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                        Expanded(
                          child: SliderTheme(
                            data: SliderThemeData(
                              trackHeight: 3,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                              activeTrackColor: const Color(0xFF1DB954),
                              inactiveTrackColor: isDark ? Colors.white12 : Colors.black12,
                              thumbColor: const Color(0xFF1DB954),
                            ),
                            child: Slider(
                              value: remote.volume.clamp(0.0, 1.0),
                              onChanged: (v) {
                                syncService.sendRemoteCommand(
                                  targetDeviceId: remote.deviceId,
                                  action: 'setVolume',
                                  value: v,
                                );
                              },
                            ),
                          ),
                        ),
                        Icon(Icons.volume_up_rounded, size: 18, color: isDark ? Colors.white54 : Colors.black45),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Transfer & Teleport buttons
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.download_rounded, size: 18),
                            label: const Text('Bu Cihaza Aktar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1DB954),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            onPressed: () async {
                              ref.read(dismissedRemoteVideoIdProvider.notifier).dismiss(remote.videoId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('▶ Oynatma ${remote.deviceName}\'den devralındı'),
                                    backgroundColor: const Color(0xFF1DB954),
                                    duration: const Duration(seconds: 2),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                              await syncService.takeoverPlayback(remote);
                            },
                          ),
                        ),
                        if (localMediaItem != null) ...[
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.upload_rounded, size: 18),
                              label: const Text('Oraya Gönder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1DB954),
                                side: const BorderSide(color: Color(0xFF1DB954)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: () async {
                                await syncService.sendCurrentPlaybackToRemote(remote);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('↗ Müzik ${remote.deviceName}\'e aktarıldı'),
                                      backgroundColor: const Color(0xFF1DB954),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, errorTrace) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 16),

          // Desktop-only section: Show Pairing QR code
          if (isDesktop) ...[
            const Divider(),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDesktopPairQR(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1DB954),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_2_rounded),
              label: const Text('📱 Telefon Eşleştirme QR Kodunu Göster', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ], const SizedBox(height: 20),

          // Mobile-only section: Connect Desktop via QR or 6-digit Code
          if (!isDesktop) ...[
            const Divider(),
            const SizedBox(height: 12),
            Text(
              '💻 Masaüstü MozeMusic\'e Bağlan',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Bilgisayarınızdaki MozeMusic oturumunu telefonunuzla hemen açın.',
              style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
            ),
            const SizedBox(height: 14),

            // Scan QR Button
            ElevatedButton.icon(
              onPressed: _isPairing
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => QRScannerScreen(
                            title: 'Masaüstü QR Kodunu Tara',
                            onScanned: (scannedCode) async {
                              await _handleApproveCode(scannedCode);
                            },
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.redAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('Masaüstü QR Kodunu Tara', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 10),

            // Enter 6-digit code
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    textCapitalization: TextCapitalization.characters,
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                      letterSpacing: 2,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: 'MZ-1234',
                      hintStyle: const TextStyle(letterSpacing: 1, color: Colors.grey),
                      filled: true,
                      fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: _isPairing ? null : () => _handleApproveCode(_codeController.text),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white24 : Colors.black12,
                    foregroundColor: isDark ? Colors.white : Colors.black87,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isPairing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Bağla', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
