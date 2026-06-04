// Environment Configuration for HealthTrack App
// ─────────────────────────────────────────────
// Before deploying to production:
//   1. Change currentEnvironment to 'production'
//   2. Replace 'https://healthtrack-api.onrender.com' with your actual Render URL
//      (found in Render dashboard after deployment)

import 'dart:io';

class EnvironmentConfig {
  // ── Environment constants ────────────────────────────────────────────────
  static const String development = 'development';
  static const String production  = 'production';
  static const String testing     = 'testing';

  // ── CHANGE THIS TO 'production' BEFORE PUBLISHING ────────────────────────
  static const String currentEnvironment = production;

  // ── Your Render backend URL ───────────────────────────────────────────────
  // Replace this with your actual Render service URL after deployment.
  // Format: https://<your-service-name>.onrender.com
  static const String _renderUrl = 'https://healthtrack-api.onrender.com';

  // ─── Platform Detection ───────────────────────────────────────────────────

  static bool get isAndroidEmulator {
    try {
      return Platform.isAndroid &&
             (Platform.environment['ANDROID_EMULATOR'] == '1' ||
              (Platform.environment['ANDROID_ROOT']?.contains('emulator') ?? false));
    } catch (_) {
      return false;
    }
  }

  static bool get isIOSSimulator {
    try {
      return Platform.isIOS &&
             (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
              (Platform.environment['XPC_SERVICE_NAME']?.contains('iphonesimulator') ?? false));
    } catch (_) {
      return false;
    }
  }

  static bool get isPhysicalDevice {
    try {
      return (Platform.isAndroid || Platform.isIOS) &&
             !isAndroidEmulator && !isIOSSimulator;
    } catch (_) {
      return false;
    }
  }

  // ─── Primary URL ──────────────────────────────────────────────────────────

  static String getApiBaseUrl() {
    if (currentEnvironment == production || currentEnvironment == testing) {
      return _renderUrl;
    }

    // Development — use localhost/emulator gateway for local testing only
    if (isAndroidEmulator) {
      return 'http://10.0.2.2:3000';
    } else if (isIOSSimulator) {
      return 'http://127.0.0.1:3000';
    }

    // Physical device or desktop in dev — use Render (no local IP fallback)
    return _renderUrl;
  }

  // ─── Fallback URLs ────────────────────────────────────────────────────────
  // The app tries these in order if the primary URL fails.
  // In production, only the Render URL is needed.

  static List<String> getFallbackUrls() {
    if (currentEnvironment == production || currentEnvironment == testing) {
      return [_renderUrl];
    }

    // Development fallbacks
    final List<String> urls = [_renderUrl];

    if (isAndroidEmulator) {
      urls.insert(0, 'http://10.0.2.2:3000');
    } else if (isIOSSimulator) {
      urls.insert(0, 'http://127.0.0.1:3000');
      urls.insert(1, 'http://localhost:3000');
    }

    return urls;
  }

  // ─── Convenience getters ──────────────────────────────────────────────────

  static bool get isDevelopment => currentEnvironment == development;
  static bool get isProduction  => currentEnvironment == production;
  static bool get isTesting     => currentEnvironment == testing;

  static String getEnvironmentInfo() {
    return '''
HealthTrack Environment Info:
- Environment : $currentEnvironment
- Platform    : ${_platformName()}
- Primary URL : ${getApiBaseUrl()}
- Fallbacks   : ${getFallbackUrls().join(', ')}
    ''';
  }

  static String _platformName() {
    try {
      return Platform.operatingSystem;
    } catch (_) {
      return 'web';
    }
  }
}
