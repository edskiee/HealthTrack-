// Test script to check environment variable behavior
void main() {
  const String? envBaseUrl = const String.fromEnvironment('API_BASE_URL');
  const String defaultBaseUrl = 'http://10.243.17.91:3000';
  
  print('envBaseUrl = "$envBaseUrl"');
  print('envBaseUrl is null = ${envBaseUrl == null}');
  print('envBaseUrl is empty = ${envBaseUrl?.isEmpty ?? true}');
  print('envBaseUrl length = ${envBaseUrl?.length ?? 0}');
  
  final result = (envBaseUrl != null && envBaseUrl.isNotEmpty) ? envBaseUrl : defaultBaseUrl;
  print('Result = "$result"');
}