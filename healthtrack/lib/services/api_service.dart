import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../env_config.dart';

class ApiService {
  static ApiService? _instance;
  static ApiService get instance => _instance ??= ApiService._();
  
  ApiService._();

  // Single reliable base URL
  late String _baseUrl;
  String? _lastWorkingUrl;
  bool _isHealthy = false;
  DateTime? _lastHealthCheck;

  // Initialize the service
  Future<void> initialize() async {
    _baseUrl = EnvironmentConfig.getApiBaseUrl();
    print('API Service initialized with base URL: $_baseUrl');
    
    // Perform initial health check
    await _performHealthCheck();
  }

  // Get current base URL
  String get baseUrl => _baseUrl;

  // Headers for API requests
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    'User-Agent': 'HealthTrack-Flutter/1.0.0',
  };

  // Perform health check
  Future<bool> _performHealthCheck({bool forceCheck = false}) async {
    final now = DateTime.now();
    
    // Skip if recently checked (within 30 seconds) unless forced
    if (!forceCheck && _lastHealthCheck != null && 
        now.difference(_lastHealthCheck!).inSeconds < 30) {
      return _isHealthy;
    }

    try {
      print('Performing health check against: $_baseUrl/health');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/health'),
        headers: _headers,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException('Health check timeout'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _isHealthy = data['success'] == true;
        _lastHealthCheck = now;
        
        if (_isHealthy) {
          _lastWorkingUrl = _baseUrl;
          print('Health check passed: Server is healthy');
        } else {
          print('Health check failed: Server reports unhealthy');
        }
        
        return _isHealthy;
      } else {
        print('Health check failed: HTTP ${response.statusCode}');
        _isHealthy = false;
        _lastHealthCheck = now;
        return false;
      }
    } catch (e) {
      print('Health check failed: $e');
      _isHealthy = false;
      _lastHealthCheck = now;
      
      // Try fallback URLs if primary fails
      if (await _tryFallbackUrls()) {
        return true;
      }
      
      return false;
    }
  }

  // Try fallback URLs
  Future<bool> _tryFallbackUrls() async {
    final fallbackUrls = EnvironmentConfig.getFallbackUrls();
    
    for (String url in fallbackUrls) {
      if (url == _baseUrl) continue; // Skip primary URL
      
      try {
        print('Trying fallback URL: $url/health');
        
        final response = await http.get(
          Uri.parse('$url/health'),
          headers: _headers,
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['success'] == true) {
            _baseUrl = url;
            _lastWorkingUrl = url;
            _isHealthy = true;
            _lastHealthCheck = DateTime.now();
            print('Switched to working fallback URL: $url');
            return true;
          }
        }
      } catch (e) {
        print('Fallback URL $url failed: $e');
        continue;
      }
    }
    
    return false;
  }

  // Ensure server is healthy before making requests
  Future<bool> _ensureHealthy() async {
    if (_isHealthy && _lastHealthCheck != null && 
        DateTime.now().difference(_lastHealthCheck!).inSeconds < 60) {
      return true;
    }
    
    return await _performHealthCheck(forceCheck: true);
  }

  // Enhanced HTTP request method with retry and health check
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    int maxRetries = 3,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    // Ensure server is healthy
    if (!await _ensureHealthy()) {
      throw Exception('Server is not healthy. Please check your connection.');
    }

    final url = Uri.parse('$_baseUrl$endpoint');
    final requestHeaders = {..._headers, ...?headers};
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        print('API Request $attempt/$maxRetries: $method $url');
        
        late http.Response response;
        switch (method.toUpperCase()) {
          case 'GET':
            response = await http.get(url, headers: requestHeaders).timeout(timeout);
            break;
          case 'POST':
            response = await http.post(
              url, 
              headers: requestHeaders, 
              body: body,
            ).timeout(timeout);
            break;
          case 'PUT':
            response = await http.put(
              url, 
              headers: requestHeaders, 
              body: body,
            ).timeout(timeout);
            break;
          case 'DELETE':
            response = await http.delete(
              url, 
              headers: requestHeaders,
            ).timeout(timeout);
            break;
          case 'PATCH':
            response = await http.patch(
              url, 
              headers: requestHeaders, 
              body: body,
            ).timeout(timeout);
            break;
          default:
            throw UnsupportedError('HTTP method $method not supported');
        }
        
        print('API Response: ${response.statusCode}');
        return response;
        
      } catch (e) {
        print('API Request $attempt failed: $e');
        
        // If it's a network error, try to find a working URL
        if (e.toString().contains('Connection') || 
            e.toString().contains('SocketException') ||
            e.toString().contains('Network')) {
          _isHealthy = false;
          if (await _tryFallbackUrls()) {
            // Retry with new URL
            continue;
          }
        }
        
        if (attempt == maxRetries) {
          rethrow;
        }
        
        // Exponential backoff
        await Future.delayed(Duration(milliseconds: 1000 * attempt));
      }
    }
    
    throw Exception('All $maxRetries attempts failed');
  }

  // HTTP GET method
  Future<http.Response> get(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return await _makeRequest(
      'GET',
      endpoint,
      headers: headers,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  // HTTP POST method
  Future<http.Response> post(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return await _makeRequest(
      'POST',
      endpoint,
      headers: headers,
      body: body,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  // HTTP PUT method
  Future<http.Response> put(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return await _makeRequest(
      'PUT',
      endpoint,
      headers: headers,
      body: body,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  // HTTP DELETE method
  Future<http.Response> delete(
    String endpoint, {
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    return await _makeRequest(
      'DELETE',
      endpoint,
      headers: headers,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  // HTTP PATCH method
  Future<http.Response> patch(
    String endpoint, {
    Map<String, String>? headers,
    Object? body,
    Duration? timeout,
  }) async {
    return await _makeRequest(
      'PATCH',
      endpoint,
      headers: headers,
      body: body,
      timeout: timeout ?? const Duration(seconds: 10),
    );
  }

  // Get current status
  Map<String, dynamic> getStatus() {
    return {
      'baseUrl': _baseUrl,
      'lastWorkingUrl': _lastWorkingUrl,
      'isHealthy': _isHealthy,
      'lastHealthCheck': _lastHealthCheck?.toIso8601String(),
      'environment': EnvironmentConfig.currentEnvironment,
      'platform': kIsWeb ? 'web' : Platform.operatingSystem,
    };
  }

  // Force re-check health
  Future<bool> checkHealth() async {
    return await _performHealthCheck(forceCheck: true);
  }

  // Reset to primary URL
  void resetToPrimaryUrl() {
    _baseUrl = EnvironmentConfig.getApiBaseUrl();
    _isHealthy = false;
    _lastHealthCheck = null;
    print('Reset to primary URL: $_baseUrl');
  }
}
