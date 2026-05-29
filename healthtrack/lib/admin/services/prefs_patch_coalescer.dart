import 'dart:async';

import 'package:flutter/foundation.dart';

typedef PatchSender = Future<void> Function(Map<String, dynamic> payload);

/// Batches PATCH fields for 500ms to avoid chatter while keeping a single rollback surface.
class PrefsPatchCoalescer {
  PrefsPatchCoalescer({
    Duration delay = const Duration(milliseconds: 500),
    required this.sender,
    required this.onError,
    required this.onSuccess,
    required this.onBeforeSend,
    required this.onRevert,
  }) : _delay = delay;

  final Duration _delay;
  final PatchSender sender;
  final void Function(Object error, Map<String, dynamic> rolledBackBatch) onError;
  final VoidCallback onSuccess;
  final VoidCallback onBeforeSend;
  final void Function(Map<String, dynamic> batch) onRevert;

  Timer? _timer;
  final Map<String, dynamic> _pending = {};

  void schedule(Map<String, dynamic> slice) {
    if (slice.isEmpty) return;
    _pending.addAll(slice);
    _timer?.cancel();
    _timer = Timer(_delay, _flush);
  }

  Future<void> _flush() async {
    if (_pending.isEmpty) return;
    final snapshot = Map<String, dynamic>.from(_pending);
    _pending.clear();
    onBeforeSend();
    try {
      await sender(snapshot);
      onSuccess();
    } catch (e) {
      onRevert(snapshot);
      onError(e, snapshot);
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
