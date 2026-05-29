// Environment Configuration for HealthTrack App
// This file helps configure the app for different environments

import 'dart:io';

class EnvironmentConfig {
  // Environment types
  static const String development = 'development';
  static const String production = 'production';
  static const String testing = 'testing';

  // Current environment - change this as needed
  static const String currentEnvironment = development;

  // Detect if running on Android emulator
  static bool get isAndroidEmulator {
    try {
      return Platform.isAndroid && 
             (Platform.environment['ANDROID_EMULATOR'] == '1' ||
              Platform.environment['ANDROID_ROOT']?.contains('emulator') == true);
    } catch (e) {
      return false;
    }
  }

  // Detect if running on iOS simulator
  static bool get isIOSSimulator {
    try {
      return Platform.isIOS && 
             (Platform.environment['SIMULATOR_DEVICE_NAME'] != null ||
              Platform.environment['XPC_SERVICE_NAME']?.contains('iphonesimulator') == true);
    } catch (e) {
      return false;
    }
  }

  // Detect if running on physical device
  static bool get isPhysicalDevice {
    try {
      return (Platform.isAndroid || Platform.isIOS) && 
             !isAndroidEmulator && !isIOSSimulator;
    } catch (e) {
      return false;
    }
  }

  // Get the appropriate API base URL based on runtime environment
  static String getApiBaseUrl() {
    switch (currentEnvironment) {
      case development:
        // For development, prioritize based on runtime environment
        if (isAndroidEmulator) {
          return 'http://10.0.2.2:3000'; // Android emulator gateway
        } else if (isIOSSimulator) {
          return 'http://127.0.0.1:3000'; // iOS simulator can use localhost
        } else if (isPhysicalDevice) {
          // For physical devices, use Railway production URL
          return 'https://healthtrack-production-0be7.up.railway.app';
        } else {
          // Desktop/Web development - use Railway production URL
          return 'https://healthtrack-production-0be7.up.railway.app';
        }
      case production:
        // For production, use Railway production URL
        return 'https://healthtrack-production-0be7.up.railway.app';
      case testing:
        // For testing, use Railway production URL
        return 'https://healthtrack-production-0be7.up.railway.app';
      default:
        return 'https://healthtrack-production-0be7.up.railway.app';
    }
  }

  static List<String> getFallbackUrls() {
    switch (currentEnvironment) {
      case development:
        List<String> urls = [];

        // Add URLs based on runtime environment
        if (isAndroidEmulator) {
          urls.addAll([
            'http://10.0.2.2:3000',       // Primary: Android emulator gateway
            'https://healthtrack-production-0be7.up.railway.app', // Railway production
            'http://192.168.254.113:3000', // Local network
            'http://192.168.1.66:3000',    // Alternative local network
            'http://192.168.137.1:3000',   // Windows hotspot
            'http://192.168.0.1:3000',     // Router gateway
          ]);
        } else if (isIOSSimulator) {
          urls.addAll([
            'http://127.0.0.1:3000',      // Primary: iOS simulator localhost
            'http://localhost:3000',      // Alternative localhost
            'https://healthtrack-production-0be7.up.railway.app', // Railway production
            'http://192.168.254.113:3000', // Local network
            'http://192.168.1.66:3000',    // Alternative local network
            'http://192.168.137.1:3000',   // Windows hotspot
            'http://192.168.0.1:3000',     // Router gateway
          ]);
        } else if (isPhysicalDevice) {
          urls.addAll([
            'https://healthtrack-production-0be7.up.railway.app', // Primary: Railway production
            'http://192.168.254.113:3000', // Local network
            'http://192.168.1.66:3000',    // Alternative local network
            'http://192.168.137.1:3000',   // Windows hotspot
            'http://192.168.0.1:3000',     // Router gateway
          ]);
        } else {
          // Desktop/Web - use Railway production
          urls.addAll([
            'https://healthtrack-production-0be7.up.railway.app', // Primary: Railway production
            'http://192.168.254.113:3000', // Local network
            'http://192.168.1.66:3000',    // Alternative local network
            'http://192.168.137.1:3000',   // Windows hotspot
            'http://192.168.0.1:3000',     // Router gateway
          ]);
        }

        return urls;

      case production:
        return [
          'https://healthtrack-production-0be7.up.railway.app',
          'http://192.168.254.113:3000',
          'http://192.168.1.66:3000',
          'http://192.168.137.1:3000',
          'http://192.168.0.1:3000',
        ];
      case testing:
        return [
          'https://healthtrack-production-0be7.up.railway.app',
          'http://192.168.254.113:3000',
          'http://192.168.1.66:3000',
          'http://192.168.137.1:3000',
          'http://192.168.0.1:3000',
        ];
      default:
        return [
          'https://healthtrack-production-0be7.up.railway.app',
          'http://192.168.254.113:3000',
          'http://192.168.1.66:3000',
          'http://192.168.137.1:3000',
          'http://192.168.0.1:3000',
        ];
    }
  }

  // Check if in development mode
  static bool get isDevelopment => currentEnvironment == development;

  // Check if in production mode
  static bool get isProduction => currentEnvironment == production;

  // Check if in testing mode
  static bool get isTesting => currentEnvironment == testing;

  // Get environment info for debugging
  static String getEnvironmentInfo() {
    return '''
Environment Info:
- Current Environment: $currentEnvironment
- Platform: ${Platform.operatingSystem}
- Is Android Emulator: $isAndroidEmulator
- Is iOS Simulator: $isIOSSimulator
- Is Physical Device: $isPhysicalDevice
- Primary API URL: ${getApiBaseUrl()}
- Fallback URLs: ${getFallbackUrls().join(', ')}
    ''';
  }
}