import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_config.dart';

/// Result of a single health-check probe.
enum ServerStatus {
  online,
  waking,    // reachable but slow (Render cold-start)
  offline,   // not reachable
  timeout,   // no response within deadline
}

class ConnectionCheckResult {
  final ServerStatus status;
  final int elapsedMs;
  final String? errorMessage;

  const ConnectionCheckResult({
    required this.status,
    required this.elapsedMs,
    this.errorMessage,
  });

  bool get isOnline => status == ServerStatus.online;
}

/// Centralised service for all backend connectivity concerns.
///
/// Usage
/// -----
/// ```dart
/// // One-shot check
/// final result = await ConnectionStatusService.checkBackendHealth();
///
/// // Block until server is up (with progress callbacks)
/// final ok = await ConnectionStatusService.waitForServerWakeup(
///   onStatusUpdate: (msg) => setState(() => _message = msg),
/// );
/// ```
class ConnectionStatusService {
  ConnectionStatusService._();

  // ── tunables ────────────────────────────────────────────────────────────
  static const Duration _probeTimeout    = Duration(seconds: 12);
  static const Duration _retryInterval   = Duration(seconds: 5);
  static const Duration _giveUpAfter     = Duration(seconds: 90);

  static const int _maxRetries = 18; // 18 × 5 s = 90 s max

  // cached result so the rest of the app can ask synchronously
  static ServerStatus _lastStatus = ServerStatus.offline;
  static DateTime?    _lastCheck;

  static ServerStatus get lastStatus => _lastStatus;
  static bool get isKnownOnline =>
      _lastStatus == ServerStatus.online &&
      _lastCheck != null &&
      DateTime.now().difference(_lastCheck!) < const Duration(seconds: 30);

  // ── primary health-check ─────────────────────────────────────────────────

  /// Pings `GET /health` on the Render backend.
  /// Returns quickly (≤ 12 s) so callers can show appropriate UI.
  static Future<ConnectionCheckResult> checkBackendHealth() async {
    final url = '${ApiConfig.baseUrl}/health';
    final sw  = Stopwatch()..start();

    try {
      final response = await http
          .get(
            Uri.parse(url),
            headers: {'Accept': 'application/json'},
          )
          .timeout(_probeTimeout);

      sw.stop();
      final ms = sw.elapsedMilliseconds;

      if (response.statusCode >= 200 && response.statusCode < 500) {
        _lastStatus = ServerStatus.online;
        _lastCheck  = DateTime.now();
        return ConnectionCheckResult(status: ServerStatus.online, elapsedMs: ms);
      }

      _lastStatus = ServerStatus.offline;
      return ConnectionCheckResult(
        status: ServerStatus.offline,
        elapsedMs: ms,
        errorMessage: 'Server returned HTTP ${response.statusCode}',
      );
    } on TimeoutException {
      sw.stop();
      _lastStatus = ServerStatus.timeout;
      return ConnectionCheckResult(
        status: ServerStatus.timeout,
        elapsedMs: sw.elapsedMilliseconds,
        errorMessage: 'Connection timed out',
      );
    } on SocketException catch (e) {
      sw.stop();
      _lastStatus = ServerStatus.offline;
      return ConnectionCheckResult(
        status: ServerStatus.offline,
        elapsedMs: sw.elapsedMilliseconds,
        errorMessage: 'Network error: ${e.message}',
      );
    } catch (e) {
      sw.stop();
      _lastStatus = ServerStatus.offline;
      return ConnectionCheckResult(
        status: ServerStatus.offline,
        elapsedMs: sw.elapsedMilliseconds,
        errorMessage: e.toString(),
      );
    }
  }

  /// Returns `true` if the server is reachable right now (quick path).
  static Future<bool> isServerAvailable() async {
    if (isKnownOnline) return true;
    final result = await checkBackendHealth();
    return result.isOnline;
  }

  // ── wake-up poller ───────────────────────────────────────────────────────

  /// Polls until the backend responds or [_giveUpAfter] elapses.
  ///
  /// [onStatusUpdate] receives human-readable progress strings so the UI
  /// can show them without knowing internal timing.
  ///
  /// Returns `true` when the server comes online, `false` on give-up.
  static Future<bool> waitForServerWakeup({
    void Function(String message)? onStatusUpdate,
    void Function()? onOnline,
    void Function()? onGaveUp,
  }) async {
    final deadline = DateTime.now().add(_giveUpAfter);
    int attempt   = 0;

    onStatusUpdate?.call(
      'Please wait while we establish a secure connection to the server. '
      'This may take a few moments if the system is waking up.',
    );

    while (DateTime.now().isBefore(deadline) && attempt < _maxRetries) {
      final result = await checkBackendHealth();

      if (result.isOnline) {
        onStatusUpdate?.call('Connected successfully.');
        onOnline?.call();
        return true;
      }

      attempt++;
      final elapsed = DateTime.now().difference(deadline.subtract(_giveUpAfter));

      if (elapsed.inSeconds > 30) {
        onStatusUpdate?.call(
          'The server is currently waking up. Please try again in a few moments.',
        );
      } else if (elapsed.inSeconds > 10) {
        onStatusUpdate?.call('Server is starting. Please wait…');
      }

      // wait before next probe
      await Future.delayed(_retryInterval);
    }

    _lastStatus = ServerStatus.offline;
    onGaveUp?.call();
    return false;
  }

  // ── friendly error messages ───────────────────────────────────────────────

  /// Converts raw exception strings into user-friendly copy.
  static String friendlyError(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('socketexception') ||
        msg.contains('failed host lookup') ||
        msg.contains('network is unreachable') ||
        msg.contains('connection refused')) {
      return 'Unable to connect to HealthTrack services at the moment. '
          'Please check your internet connection or try again shortly.';
    }
    if (msg.contains('timeoutexception') ||
        msg.contains('connection timed out') ||
        msg.contains('timed out')) {
      return 'The connection timed out. The server may be waking up — '
          'please wait a moment and try again.';
    }
    if (msg.contains('failed to fetch') ||
        msg.contains('xmlhttprequest') ||
        msg.contains('cors')) {
      return 'Unable to reach HealthTrack services. '
          'Please check your internet connection or try again shortly.';
    }
    if (msg.contains('401') || msg.contains('unauthorized')) {
      return 'Your session has expired. Please log in again.';
    }
    if (msg.contains('500') || msg.contains('internal server')) {
      return 'The server encountered an unexpected error. '
          'Please try again in a moment.';
    }

    return 'Unable to connect to HealthTrack services at the moment. '
        'Please check your internet connection or try again shortly.';
  }
}
