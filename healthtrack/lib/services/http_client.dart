import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'connection_status_service.dart';

/// Centralised HTTP helper with:
///   • 15-second per-request timeout (matches the task spec)
///   • Exponential backoff on transient failures (5s → 10s → 30s → give up)
///   • Friendly error messages via ConnectionStatusService.friendlyError()
///
/// Usage
/// -----
/// ```dart
/// final response = await AppHttpClient.get(uri, headers: headers);
/// ```
///
/// Throws [AppHttpException] with a user-readable message on failure after
/// all retries are exhausted.
class AppHttpClient {
  AppHttpClient._();

  static const Duration _requestTimeout = Duration(seconds: 15);

  /// Delays between retry attempts: 5 s, 10 s, 30 s.
  static const List<Duration> _backoffDelays = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
  ];

  // ── Public API ─────────────────────────────────────────────────────────────

  static Future<http.Response> get(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 2,
  }) =>
      _withRetry(() => http.get(uri, headers: headers), maxRetries: maxRetries);

  static Future<http.Response> post(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 1,
  }) =>
      _withRetry(
        () => http.post(uri, headers: headers, body: body),
        maxRetries: maxRetries,
      );

  static Future<http.Response> patch(
    Uri uri, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 1,
  }) =>
      _withRetry(
        () => http.patch(uri, headers: headers, body: body),
        maxRetries: maxRetries,
      );

  static Future<http.Response> delete(
    Uri uri, {
    Map<String, String>? headers,
    int maxRetries = 1,
  }) =>
      _withRetry(
        () => http.delete(uri, headers: headers),
        maxRetries: maxRetries,
      );

  // ── Core retry engine ──────────────────────────────────────────────────────

  static Future<http.Response> _withRetry(
    Future<http.Response> Function() call, {
    required int maxRetries,
  }) async {
    Object? lastError;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final response = await call().timeout(_requestTimeout);

        // 5xx responses from an overloaded server are retriable.
        if (response.statusCode >= 500 && attempt < maxRetries) {
          lastError = Exception(
            'Server returned ${response.statusCode}. '
            'Retrying in ${_backoffDelays[attempt.clamp(0, _backoffDelays.length - 1)].inSeconds}s…',
          );
          await Future.delayed(_backoffDelays[attempt.clamp(0, _backoffDelays.length - 1)]);
          continue;
        }

        return response;
      } on TimeoutException catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          final delay = _backoffDelays[attempt.clamp(0, _backoffDelays.length - 1)];
          await Future.delayed(delay);
        }
      } on SocketException catch (e) {
        lastError = e;
        if (attempt < maxRetries) {
          final delay = _backoffDelays[attempt.clamp(0, _backoffDelays.length - 1)];
          await Future.delayed(delay);
        }
      } catch (e) {
        // Non-retriable errors (auth, bad URL, etc.) — rethrow immediately.
        throw AppHttpException(
          ConnectionStatusService.friendlyError(e),
          cause: e,
        );
      }
    }

    // All retries exhausted.
    throw AppHttpException(
      ConnectionStatusService.friendlyError(lastError ?? Exception('Request failed')),
      cause: lastError,
    );
  }
}

/// Thrown by [AppHttpClient] when all retry attempts are exhausted.
///
/// [message] is always safe to show to users.
/// [cause] is the underlying exception for logging.
class AppHttpException implements Exception {
  final String message;
  final Object? cause;

  const AppHttpException(this.message, {this.cause});

  @override
  String toString() => message;
}
