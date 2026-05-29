import 'dart:convert';

void main() {
  // Test the exact error scenario
  print('Testing JSON parsing error scenarios...');
  
  // Test 1: Empty string
  try {
    final result1 = jsonDecode('');
    print('Empty string parsed successfully: $result1');
  } catch (e) {
    print('❌ Error parsing empty string: $e');
  }
  
  // Test 2: Invalid JSON
  try {
    final result2 = jsonDecode('{ invalid json }');
    print('Invalid JSON parsed successfully: $result2');
  } catch (e) {
    print('❌ Error parsing invalid JSON: $e');
  }
  
  // Test 3: Valid JSON
  try {
    final result3 = jsonDecode('{"success": true, "message": "test"}');
    print('✅ Valid JSON parsed successfully: $result3');
  } catch (e) {
    print('❌ Error parsing valid JSON: $e');
  }
  
  print('\nAll tests completed.');
}