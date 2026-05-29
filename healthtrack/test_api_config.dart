// Test script for API config
import 'package:healthtrack/services/api_config.dart';
import 'package:healthtrack/services/dynamic_api_config.dart';

void main() async {
  print('Testing ApiConfig.baseUrl:');
  print('Value: "${ApiConfig.baseUrl}"');
  print('Length: ${ApiConfig.baseUrl.length}');
  
  print('\nTesting DynamicApiConfig.baseUrl:');
  final dynamicBaseUrl = await DynamicApiConfig.baseUrl;
  print('Value: "$dynamicBaseUrl"');
  print('Length: ${dynamicBaseUrl.length}');
  
  print('\nTesting fallback URLs:');
  print('ApiConfig.fallbackBaseUrls: ${ApiConfig.fallbackBaseUrls}');
  
  final dynamicFallbackUrls = await DynamicApiConfig.fallbackBaseUrls;
  print('DynamicApiConfig.fallbackBaseUrls: $dynamicFallbackUrls');
}