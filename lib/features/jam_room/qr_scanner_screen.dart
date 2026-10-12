import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_theme.dart';
import '../../services/jam_service.dart';

class QRScannerScreen extends ConsumerStatefulWidget {
  final String title;
  final Future<void> Function(String code)? onScanned;

  const QRScannerScreen({
    super.key,
    this.title = 'QR Kodunu Tara',
    this.onScanned,
  });

  @override
  ConsumerState<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends ConsumerState<QRScannerScreen> {
  bool _isScanning = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(widget.title),
      ),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: (capture) async {
              if (!_isScanning) return;
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  setState(() => _isScanning = false);
                  final code = barcode.rawValue!;

                  if (widget.onScanned != null) {
                    await widget.onScanned!(code);
                  } else {
                    // Join the room
                    await ref.read(jamServiceProvider).joinRoom(code);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Joined Jam Room: $code')),
                    );
                  }

                  if (context.mounted) Navigator.pop(context);
                  break;
                }
              }
            },
          ),
          // Scanner Overlay overlay
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.redAccent, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
