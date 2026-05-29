import 'package:flutter/material.dart';
import 'package:healthtrack/services/service_config_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Service Loading Test',
      home: ServiceLoadingTest(),
    );
  }
}

class ServiceLoadingTest extends StatefulWidget {
  @override
  _ServiceLoadingTestState createState() => _ServiceLoadingTestState();
}

class _ServiceLoadingTestState extends State<ServiceLoadingTest> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, dynamic>> _services = [];

  Future<void> _loadServices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // print('Attempting to load immunization services...');
      final immunizationServices = await ServiceConfigService.getAllServices(serviceType: 'immunization');
      // print('Immunization services loaded: ${immunizationServices.length}');
      
      // print('Attempting to load maternal services...');
      final maternalServices = await ServiceConfigService.getAllServices(serviceType: 'maternal');
      // print('Maternal services loaded: ${maternalServices.length}');
      
      // Combine and filter only enabled services
      final enabledServices = [...immunizationServices, ...maternalServices]
          .where((service) => service['is_enabled'] == 1)
          .toList();
      
      // print('Enabled services: ${enabledServices.length}');
      
      setState(() {
        _services = enabledServices;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      // print('Error loading services: $e');
      // print('Stack trace: $stackTrace');
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Service Loading Test')),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Service Loading Test', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            SizedBox(height: 20),
            if (_isLoading)
              Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Error:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  Text(_errorMessage!, style: TextStyle(color: Colors.red)),
                ],
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Loaded Services: ${_services.length}', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  ..._services.map((service) => 
                    ListTile(
                      title: Text(service['service_name'].toString()),
                      subtitle: Text('${service['service_type']} - Enabled: ${service['is_enabled']}'),
                    )
                  ).toList(),
                ],
              ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadServices,
              child: Text('Reload Services'),
            ),
          ],
        ),
      ),
    );
  }
}