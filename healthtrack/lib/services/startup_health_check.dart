import 'package:flutter/material.dart';
import 'connection_status_service.dart';
import '../widgets/server_wakeup_overlay.dart';

/// Runs before navigating to any protected screen.
///
/// Call [StartupHealthCheck.run] from initState / startup code.
/// It checks the backend and shows the wakeup overlay if needed.
///
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   WidgetsBinding.instance.addPostFrameCallback((_) async {
///     await StartupHealthCheck.run(context);
///   });
/// }
/// ```
class StartupHealthCheck {
  StartupHealthCheck._();

  /// Checks backend health.
  ///
  /// - If the backend responds within ~2 s, returns silently.
  /// - If the backend is slow / offline, shows the wakeup overlay and
  ///   waits for it to come online before returning.
  ///
  /// Returns `true` when the backend is confirmed online.
  /// Returns `false` if the user is still offline after the retry window.
  static Future<bool> run(
    BuildContext context, {
    bool forceCheck = false,
  }) async {
    // Skip if we recently confirmed the server is online
    if (!forceCheck && ConnectionStatusService.isKnownOnline) return true;

    // Quick probe first — if it comes back fast don't show any UI
    final quick = await ConnectionStatusService.checkBackendHealth();
    if (quick.isOnline) return true;

    // Server is not responding — show the wakeup overlay
    if (!context.mounted) return false;
    final online = await ServerWakeupOverlay.show(context);
    return online;
  }

  /// Wraps an async operation with connection checking and friendly error
  /// handling. If the operation throws a network error, shows the wakeup
  /// overlay before re-throwing so the caller can retry.
  ///
  /// ```dart
  /// final data = await StartupHealthCheck.guardedCall(
  ///   context: context,
  ///   call: () => MyService.fetchSomething(),
  /// );
  /// ```
  static Future<T> guardedCall<T>({
    required BuildContext context,
    required Future<T> Function() call,
    String? operationLabel,
  }) async {
    try {
      return await call();
    } catch (e) {
      final friendly = ConnectionStatusService.friendlyError(e);
      // If it looks like a network error, offer the wakeup overlay
      if (context.mounted) {
        final shouldRetry = await _showErrorWithRetry(
          context,
          friendly,
          operationLabel,
        );
        if (shouldRetry) {
          await ServerWakeupOverlay.show(context);
          if (context.mounted) return await call();
        }
      }
      rethrow;
    }
  }

  // ── internal helpers ──────────────────────────────────────────────────────

  /// Shows a dialog with a friendly message and a Retry button.
  /// Returns `true` if the user taps Retry.
  static Future<bool> _showErrorWithRetry(
    BuildContext context,
    String message,
    String? operationLabel,
  ) async {
    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            const Icon(Icons.wifi_off_rounded, color: Colors.orange, size: 22),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Connection Issue',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
            if (operationLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                'Action: $operationLabel',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black45,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Dismiss'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0052D4),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retry'),
          ),
        ],
      ),
    );

    return result ?? false;
  }
}
