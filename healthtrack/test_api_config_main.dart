// Test script for API config
import 'package:flutter/material.dart';
import 'package:healthtrack/services/api_config.dart';

void main() {
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('API Config Test')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('API Base URL:'),
              Text(ApiConfig.baseUrl),
              const SizedBox(height: 20),
              const Text('Length:'),
              Text(ApiConfig.baseUrl.length.toString()),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  print('API Base URL: ${ApiConfig.baseUrl}');
                  print('Length: ${ApiConfig.baseUrl.length}');
                },
                child: const Text('Print to Console'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}