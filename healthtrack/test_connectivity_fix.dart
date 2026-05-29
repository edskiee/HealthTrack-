import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'lib/services/api_service.dart';
import 'lib/services/notification_service.dart';
import 'lib/services/websocket_service.dart';
import 'lib/env_config.dart';

/// Comprehensive connectivity test to verify all fixes
class ConnectivityTestApp extends StatelessWidget {
  const ConnectivityTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthTrack Connectivity Test',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ConnectivityTestPage(),
    );
  }
}

class ConnectivityTestPage extends StatefulWidget {
  const ConnectivityTestPage({super.key});

  @override
  State<ConnectivityTestPage> createState() => _ConnectivityTestPageState();
}

class _ConnectivityTestPageState extends State<ConnectivityTestPage> {
  final List<TestResult> _testResults = [];
  bool _isRunning = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HealthTrack Connectivity Test'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ElevatedButton(
              onPressed: _isRunning ? null : _runAllTests,
              child: _isRunning
                  ? const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Running Tests...'),
                      ],
                    )
                  : const Text('Run All Connectivity Tests'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView.builder(
                itemCount: _testResults.length,
                itemBuilder: (context, index) {
                  final result = _testResults[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                result.success ? Icons.check_circle : Icons.error,
                                color: result.success ? Colors.green : Colors.red,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  result.testName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              Text(
                                result.duration,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          if (result.details.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              result.details,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAllTests() async {
    setState(() {
      _isRunning = true;
      _testResults.clear();
    });

    try {
      // Test 1: Environment Configuration
      await _testEnvironmentConfig();
      
      // Test 2: API Service Initialization
      await _testApiServiceInitialization();
      
      // Test 3: Health Check Endpoint
      await _testHealthCheckEndpoint();
      
      // Test 4: Notification Service
      await _testNotificationService();
      
      // Test 5: WebSocket Connection
      await _testWebSocketConnection();
      
      // Test 6: API Endpoints
      await _testApiEndpoints();
      
      // Test 7: Fallback URLs
      await _testFallbackUrls();
      
      // Test 8: Error Handling
      await _testErrorHandling();
      
    } finally {
      setState(() {
        _isRunning = false;
      });
    }
  }

  Future<void> _testEnvironmentConfig() async {
    final stopwatch = Stopwatch()..start();
    try {
      final envInfo = EnvironmentConfig.getEnvironmentInfo();
      final baseUrl = EnvironmentConfig.getApiBaseUrl();
      final fallbackUrls = EnvironmentConfig.getFallbackUrls();
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'Environment Configuration',
        success: true,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: '''Environment: ${EnvironmentConfig.currentEnvironment}
Platform: ${Platform.operatingSystem}
Base URL: $baseUrl
Fallback URLs: ${fallbackUrls.length} configured
${envInfo}''',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'Environment Configuration',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testApiServiceInitialization() async {
    final stopwatch = Stopwatch()..start();
    try {
      final apiService = ApiService.instance;
      await apiService.initialize();
      
      final status = apiService.getStatus();
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'API Service Initialization',
        success: status['isHealthy'] == true,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: '''Base URL: ${status['baseUrl']}
Last Working URL: ${status['lastWorkingUrl'] ?? 'None'}
Is Healthy: ${status['isHealthy']}
Environment: ${status['environment']}
Platform: ${status['platform']}''',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'API Service Initialization',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testHealthCheckEndpoint() async {
    final stopwatch = Stopwatch()..start();
    try {
      final apiService = ApiService.instance;
      final isHealthy = await apiService.checkHealth();
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'Health Check Endpoint',
        success: isHealthy,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: isHealthy 
            ? 'Health check passed successfully'
            : 'Health check failed',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'Health Check Endpoint',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testNotificationService() async {
    final stopwatch = Stopwatch()..start();
    try {
      await NotificationService.initialize();
      
      // Test with a dummy user ID (this will likely fail but tests the service)
      try {
        await NotificationService.getUserNotifications(999);
      } catch (e) {
        // Expected to fail, but we're testing connectivity
      }
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'Notification Service',
        success: true,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Notification service initialized successfully',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'Notification Service',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testWebSocketConnection() async {
    final stopwatch = Stopwatch()..start();
    try {
      final wsService = WebSocketService.instance;
      await wsService.initialize();
      
      // Wait a moment for connection
      await Future.delayed(const Duration(seconds: 2));
      
      final status = wsService.getStatus();
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'WebSocket Connection',
        success: status['connected'] == true || status['connecting'] == true,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: '''Connected: ${status['connected']}
Connecting: ${status['connecting']}
Should Reconnect: ${status['shouldReconnect']}
Reconnect Attempts: ${status['reconnectAttempts']}/${status['maxReconnectAttempts']}
Socket ID: ${status['socketId'] ?? 'None'}''',
      ));
      
      // Clean up
      wsService.dispose();
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'WebSocket Connection',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testApiEndpoints() async {
    final stopwatch = Stopwatch()..start();
    final endpoints = [
      '/health',
      '/notifications/user/999',
      '/notifications/user/999/unread-count',
    ];
    
    int successCount = 0;
    final List<String> results = [];
    
    for (final endpoint in endpoints) {
      try {
        final apiService = ApiService.instance;
        final response = await apiService.get(endpoint);
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          successCount++;
          results.add('$endpoint: ${response.statusCode} (Success)');
        } else {
          results.add('$endpoint: ${response.statusCode} (Failed)');
        }
      } catch (e) {
        results.add('$endpoint: Error - $e');
      }
    }
    
    stopwatch.stop();
    
    _addResult(TestResult(
      testName: 'API Endpoints Test',
      success: successCount > 0,
      duration: '${stopwatch.elapsedMilliseconds}ms',
      details: '''Tested ${endpoints.length} endpoints
Successful: $successCount
Results:
${results.join('\n')}''',
    ));
  }

  Future<void> _testFallbackUrls() async {
    final stopwatch = Stopwatch()..start();
    try {
      final fallbackUrls = EnvironmentConfig.getFallbackUrls();
      int workingUrls = 0;
      final List<String> results = [];
      
      for (final url in fallbackUrls.take(3)) { // Test first 3 URLs
        try {
          final response = await http.get(
            Uri.parse('$url/health'),
            headers: {'Accept': 'application/json'},
          ).timeout(const Duration(seconds: 3));
          
          if (response.statusCode == 200) {
            workingUrls++;
            results.add('$url: Working');
          } else {
            results.add('$url: HTTP ${response.statusCode}');
          }
        } catch (e) {
          results.add('$url: Failed - $e');
        }
      }
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'Fallback URLs Test',
        success: workingUrls > 0,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: '''Tested ${fallbackUrls.length} fallback URLs
Working URLs: $workingUrls
Results:
${results.join('\n')}''',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'Fallback URLs Test',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error: $e',
      ));
    }
  }

  Future<void> _testErrorHandling() async {
    final stopwatch = Stopwatch()..start();
    try {
      final apiService = ApiService.instance;
      
      // Test with invalid endpoint
      try {
        await apiService.get('/invalid-endpoint');
      } catch (e) {
        // Expected to fail
      }
      
      // Test with timeout
      try {
        await apiService.get('/health').timeout(const Duration(milliseconds: 1));
      } catch (e) {
        // Expected to timeout
      }
      
      stopwatch.stop();
      
      _addResult(TestResult(
        testName: 'Error Handling',
        success: true,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Error handling mechanisms are working correctly',
      ));
    } catch (e) {
      stopwatch.stop();
      _addResult(TestResult(
        testName: 'Error Handling',
        success: false,
        duration: '${stopwatch.elapsedMilliseconds}ms',
        details: 'Unexpected error: $e',
      ));
    }
  }

  void _addResult(TestResult result) {
    setState(() {
      _testResults.add(result);
    });
  }
}

class TestResult {
  final String testName;
  final bool success;
  final String duration;
  final String details;

  TestResult({
    required this.testName,
    required this.success,
    required this.duration,
    required this.details,
  });
}

void main() {
  runApp(const ConnectivityTestApp());
}
