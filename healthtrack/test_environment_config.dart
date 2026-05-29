// Test script to verify environment-aware API configuration
import 'lib/env_config.dart';

void main() {
  print('=== Environment Configuration Test ===');
  print(EnvironmentConfig.getEnvironmentInfo());
  
  print('\n=== Testing API URL Resolution ===');
  print('Primary API URL: ${EnvironmentConfig.getApiBaseUrl()}');
  
  final fallbackUrls = EnvironmentConfig.getFallbackUrls();
  print('Fallback URLs:');
  for (int i = 0; i < fallbackUrls.length; i++) {
    print('  ${i + 1}. ${fallbackUrls[i]}');
  }
  
  print('\n=== Platform Detection ===');
  print('Is Android Emulator: ${EnvironmentConfig.isAndroidEmulator}');
  print('Is iOS Simulator: ${EnvironmentConfig.isIOSSimulator}');
  print('Is Physical Device: ${EnvironmentConfig.isPhysicalDevice}');
  print('Current Environment: ${EnvironmentConfig.currentEnvironment}');
  
  print('\n=== Test Complete ===');
}
