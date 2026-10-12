import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityProvider = StreamProvider<bool>((ref) {
  final service = ConnectivityService();
  ref.onDispose(() => service.dispose());
  return service.onConnectivityChanged;
});

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

  ConnectivityService() {
    _init();
  }

  Stream<bool> get onConnectivityChanged => _controller.stream;

  Future<void> _init() async {
    final initialStatus = await _connectivity.checkConnectivity();
    _updateStatus(initialStatus);

    _connectivity.onConnectivityChanged.listen(_updateStatus);
  }

  void _updateStatus(List<ConnectivityResult> result) {
    bool hasConnection = !result.contains(ConnectivityResult.none);
    _controller.add(hasConnection);
  }

  void dispose() {
    _controller.close();
  }
}
