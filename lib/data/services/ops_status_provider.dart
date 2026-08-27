import 'dart:async';
import 'package:flutter/foundation.dart';
import 'api.dart';

// Holds the operations kill-switch state (GET /operations-status, public).
// Loaded once at app start and re-fetched on home pull-to-refresh plus a
// 5-minute background timer. Fetch failures are silent — the app defaults to
// "live" and the server still enforces the pause on every create endpoint.
class OpsStatusProvider extends ChangeNotifier {
  final _api = Api();
  bool _paused = false;
  String _message = '';
  bool _fetching = false;
  Timer? _timer;

  bool get paused => _paused;
  String get message => _message;

  // Friendly text for banners/toasts — server message with a safe fallback.
  String get displayMessage =>
      _message.isNotEmpty ? _message : 'We are temporarily not accepting new orders.';

  Future<void> load() async {
    if (_fetching) return;
    _fetching = true;
    try {
      final res = asMap(await _api.getOperationsStatus());
      final paused = asBool(res['paused']);
      final message = asStr(res['message']);
      if (paused != _paused || message != _message) {
        _paused = paused;
        _message = message;
        notifyListeners();
      }
    } catch (_) {/* silently keep current state (defaults to live) */}
    _fetching = false;
  }

  // Idempotent — the periodic re-check is started once from the app shell.
  void startPolling() {
    _timer ??= Timer.periodic(const Duration(minutes: 5), (_) => load());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _timer = null;
    super.dispose();
  }
}
