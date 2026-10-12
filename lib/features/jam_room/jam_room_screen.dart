import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../services/jam_service.dart';
import '../../core/localization/app_localizations.dart';
import 'jam_controller.dart';
import 'qr_scanner_screen.dart';

class JamRoomScreen extends ConsumerStatefulWidget {
  const JamRoomScreen({super.key});

  @override
  ConsumerState<JamRoomScreen> createState() => _JamRoomScreenState();
}

class _JamRoomScreenState extends ConsumerState<JamRoomScreen> {
  String? _currentRoomId;
  bool _isLoading = false;

  Future<void> _createRoom() async {
    setState(() => _isLoading = true);
    final roomId = await ref.read(jamServiceProvider).createRoom();
    if (roomId != null) {
      await ref.read(jamControllerProvider).joinRoom(roomId);
    }
    setState(() {
      _currentRoomId = roomId;
      _isLoading = false;
    });
  }

  Future<void> _joinRoom(String roomId) async {
    setState(() => _isLoading = true);
    await ref.read(jamControllerProvider).joinRoom(roomId);
    setState(() {
      _currentRoomId = roomId;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(locProvider);
    final isDesktop = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: isDesktop
          ? null
          : AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: Text(loc.get('jam_room'), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).textTheme.bodyLarge?.color)),
            ),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator(color: AppTheme.redAccent)
            : _currentRoomId == null
                ? _buildJoinCreateUI(loc)
                : _buildRoomUI(loc),
      ),
    );
  }

  Widget _buildJoinCreateUI(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.speaker_group, size: 80, color: AppTheme.textSecondary),
        const SizedBox(height: 24),
        Text(
          loc.get('listen_together'),
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          loc.get('start_jam_desc'),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 48),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
          onPressed: _createRoom,
          icon: const Icon(Icons.add),
          label: Text(loc.get('start_a_jam')),
        ),
        const SizedBox(height: 16),
        TextButton.icon(
          style: TextButton.styleFrom(
            foregroundColor: Colors.white,
          ),
          onPressed: () async {
            final roomId = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const QRScannerScreen()));
            if (roomId != null) {
              await _joinRoom(roomId);
            }
          },
          icon: const Icon(Icons.qr_code_scanner),
          label: Text(loc.get('scan_to_join')),
        ),
      ],
    );
  }

  Widget _buildRoomUI(AppLocalizations loc) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          loc.get('jam_is_active'),
          style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Text(
          loc.get('let_friends_scan'),
          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
        ),
        const SizedBox(height: 32),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: QrImageView(
            data: _currentRoomId!,
            version: QrVersions.auto,
            size: 200.0,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          loc.get('syncing_playback'),
          style: const TextStyle(color: AppTheme.neonGreen, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 32),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.surfaceLight,
            foregroundColor: AppTheme.redAccent,
          ),
          onPressed: () async {
            await ref.read(jamControllerProvider).leaveRoom();
            setState(() => _currentRoomId = null);
          },
          child: Text(loc.get('leave_jam')),
        ),
      ],
    );
  }
}
