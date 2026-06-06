import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../services/connection_status_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ServerWakeupOverlay
//
// Shows a full-screen overlay (web) or modal dialog (mobile) while the app
// waits for the Render backend to become available.
//
// Usage — show programmatically:
//   await ServerWakeupOverlay.show(context);
//
// Usage — wrap a widget tree to gate navigation:
//   ServerWakeupOverlay.gateWidget(child: LoginScreen())
// ─────────────────────────────────────────────────────────────────────────────

class ServerWakeupOverlay {
  ServerWakeupOverlay._();

  // ── public API ─────────────────────────────────────────────────────────────

  /// Displays the overlay / dialog and waits until the server is online.
  ///
  /// Returns `true` when the server comes online.
  /// Returns `false` if the user taps "Retry" and it still fails after
  /// the maximum wait window.
  static Future<bool> show(BuildContext context) async {
    if (kIsWeb) {
      return _showWebOverlay(context);
    } else {
      return _showMobileDialog(context);
    }
  }

  // ── web: full-screen overlay ───────────────────────────────────────────────

  static Future<bool> _showWebOverlay(BuildContext context) async {
    final completer = Completer<bool>();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _WebOverlayWidget(
        onDone: (success) {
          entry.remove();
          if (!completer.isCompleted) completer.complete(success);
        },
      ),
    );

    Overlay.of(context).insert(entry);
    return completer.future;
  }

  // ── mobile: modal dialog ───────────────────────────────────────────────────

  static Future<bool> _showMobileDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _MobileDialogWidget(),
    );
    return result ?? false;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _SharedLoadingContent — identical content for both platforms
// ─────────────────────────────────────────────────────────────────────────────

class _SharedLoadingContent extends StatefulWidget {
  final void Function(bool success) onDone;
  const _SharedLoadingContent({required this.onDone});

  @override
  State<_SharedLoadingContent> createState() => _SharedLoadingContentState();
}

class _SharedLoadingContentState extends State<_SharedLoadingContent> {
  String _message =
      'Please wflutter analyzeait while we establish a secure connection to the server. '
      'This may take a few moments if the system is waking up.';
  bool _showRetry  = false;
  bool _isRetrying = false;
  int  _elapsed    = 0;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _startWakeup();
    _startTicker();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed++);
    });
  }

  Future<void> _startWakeup() async {
    setState(() {
      _showRetry  = false;
      _isRetrying = false;
    });

    final ok = await ConnectionStatusService.waitForServerWakeup(
      onStatusUpdate: (msg) {
        if (mounted) setState(() => _message = msg);
      },
      onOnline: () {
        _ticker?.cancel();
        widget.onDone(true);
      },
      onGaveUp: () {
        if (mounted) {
          setState(() {
            _message =
                'The server is currently waking up. '
                'Please try again in a few moments.';
            _showRetry = true;
          });
        }
      },
    );

    if (!ok && mounted) {
      setState(() {
        _message =
            'The server is currently waking up. '
            'Please try again in a few moments.';
        _showRetry = true;
      });
    }
  }

  Future<void> _retry() async {
    setState(() {
      _isRetrying = true;
      _elapsed    = 0;
      _showRetry  = false;
      _message    =
          'Please wait while we establish a secure connection to the server. '
          'This may take a few moments if the system is waking up.';
    });
    _ticker?.cancel();
    _startTicker();
    await _startWakeup();
    if (mounted) setState(() => _isRetrying = false);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── logo / icon ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF0052D4).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.health_and_safety_rounded,
            size: 48,
            color: Color(0xFF0052D4),
          ),
        ),

        const SizedBox(height: 20),

        // ── title ────────────────────────────────────────────────────────
        const Text(
          'Connecting to HealthTrack Services',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A237E),
          ),
        ),

        const SizedBox(height: 16),

        // ── message ──────────────────────────────────────────────────────
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _message,
            key: ValueKey(_message),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black54,
              height: 1.5,
            ),
          ),
        ),

        const SizedBox(height: 24),

        // ── progress indicator ───────────────────────────────────────────
        if (!_showRetry)
          Column(
            children: [
              const SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  strokeWidth: 3.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0052D4)),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                '${_elapsed}s',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black38,
                ),
              ),
            ],
          ),

        // ── retry button ─────────────────────────────────────────────────
        if (_showRetry)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isRetrying ? null : _retry,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0052D4),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isRetrying
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(_isRetrying ? 'Connecting…' : 'Retry Connection'),
            ),
          ),

        const SizedBox(height: 20),

        // ── footer ───────────────────────────────────────────────────────
        const Divider(height: 1),
        const SizedBox(height: 12),
        const Text(
          'Thank you for your patience.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black38,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _WebOverlayWidget — full-screen frosted glass overlay for web
// ─────────────────────────────────────────────────────────────────────────────

class _WebOverlayWidget extends StatelessWidget {
  final void Function(bool success) onDone;
  const _WebOverlayWidget({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.55),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            margin: const EdgeInsets.all(24),
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
              vertical: 36,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: _SharedLoadingContent(onDone: onDone),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _MobileDialogWidget — modal dialog for iOS / Android
// ─────────────────────────────────────────────────────────────────────────────

class _MobileDialogWidget extends StatelessWidget {
  const _MobileDialogWidget();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 48),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: _SharedLoadingContent(
          onDone: (success) {
            if (Navigator.canPop(context)) {
              Navigator.of(context).pop(success);
            }
          },
        ),
      ),
    );
  }
}
