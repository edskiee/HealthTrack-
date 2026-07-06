import 'dart:async';
import 'package:flutter/foundation.dart';

/// Real-time refresh service for admin panels
/// Provides centralized control for auto-refresh functionality across all admin modules
class RealtimeRefreshService {
  // Singleton instance
  static final RealtimeRefreshService _instance = RealtimeRefreshService._internal();
  factory RealtimeRefreshService() => _instance;
  RealtimeRefreshService._internal();

  // Timer for periodic refresh
  Timer? _refreshTimer;
  
  // List of registered refresh callbacks
  final List<_RefreshCallback> _callbacks = [];
  
  // Current refresh interval in seconds
  int _refreshInterval = 30;
  
  // Whether auto-refresh is enabled
  bool _autoRefreshEnabled = true;

  /// Minimum allowed refresh interval — prevents accidentally flooding the server.
  static const int _minIntervalSeconds = 30;

  /// Initialize the real-time refresh service
  void initialize({int refreshIntervalSeconds = 30}) {
    _refreshInterval = refreshIntervalSeconds.clamp(_minIntervalSeconds, 300);
    _startAutoRefresh();
  }

  /// Start auto-refresh timer
  void _startAutoRefresh() {
    _stopAutoRefresh();
    
    if (_autoRefreshEnabled && _refreshInterval > 0) {
      _refreshTimer = Timer.periodic(
        Duration(seconds: _refreshInterval),
        (timer) {
          triggerRefresh();
        },
      );
    }
  }

  /// Stop auto-refresh timer
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Enable or disable auto-refresh
  void setAutoRefresh(bool enabled) {
    _autoRefreshEnabled = enabled;
    if (enabled) {
      _startAutoRefresh();
    } else {
      _stopAutoRefresh();
    }
  }

  /// Set refresh interval (floor: 30s to protect the server)
  void setRefreshInterval(int seconds) {
    _refreshInterval = seconds.clamp(_minIntervalSeconds, 300);
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
    }
  }

  /// Add a refresh callback
  void addRefreshCallback(Function() callback, {String? moduleId, bool priority = false}) {
    _callbacks.add(_RefreshCallback(
      callback: callback,
      moduleId: moduleId,
      priority: priority,
    ));
  }

  /// Remove a refresh callback
  void removeRefreshCallback(Function() callback) {
    _callbacks.removeWhere((element) => element.callback == callback);
  }

  /// Remove callbacks by module ID
  void removeCallbacksByModuleId(String moduleId) {
    _callbacks.removeWhere((element) => element.moduleId == moduleId);
  }

  /// Trigger refresh for all registered callbacks
  void triggerRefresh() {
    // Execute priority callbacks first
    for (var callback in _callbacks.where((c) => c.priority)) {
      try {
        callback.callback();
      } catch (e) {
        debugPrint('Error in refresh callback: $e');
      }
    }
    
    // Then execute non-priority callbacks
    for (var callback in _callbacks.where((c) => !c.priority)) {
      try {
        callback.callback();
      } catch (e) {
        debugPrint('Error in refresh callback: $e');
      }
    }
  }

  /// Trigger refresh for specific module
  void triggerRefreshForModule(String moduleId) {
    for (var callback in _callbacks.where((c) => c.moduleId == moduleId)) {
      try {
        callback.callback();
      } catch (e) {
        debugPrint('Error in refresh callback for module $moduleId: $e');
      }
    }
  }

  /// Dispose the service
  void dispose() {
    _stopAutoRefresh();
    _callbacks.clear();
  }
}

/// Internal class to hold refresh callback information
class _RefreshCallback {
  final Function() callback;
  final String? moduleId;
  final bool priority;

  _RefreshCallback({
    required this.callback,
    this.moduleId,
    this.priority = false,
  });
}