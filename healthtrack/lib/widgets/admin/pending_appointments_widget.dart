import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../utils/time_utils.dart';
import '../../admin/services/admin_session_storage.dart';

class PendingAppointmentsWidget extends StatefulWidget {
  final VoidCallback? onRefresh;
  
  const PendingAppointmentsWidget({Key? key, this.onRefresh}) : super(key: key);

  @override
  _PendingAppointmentsWidgetState createState() => _PendingAppointmentsWidgetState();
}

class _PendingAppointmentsWidgetState extends State<PendingAppointmentsWidget> {
  List<Map<String, dynamic>> pendingAppointments = [];
  bool isLoading = true;
  String? error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadPendingAppointments();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (mounted) {
        _loadPendingAppointments();
      }
    });
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _loadPendingAppointments() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/admin/appointments/pending'),
        headers: await _authHeaders(),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }
        
        if (isSuccess) {
          setState(() {
            pendingAppointments = List<Map<String, dynamic>>.from(data['data'] ?? []);
            isLoading = false;
          });
        } else {
          throw Exception(data['message'] ?? 'Failed to load appointments');
        }
      } else if (response.statusCode == 404) {
        // Handle 404 error gracefully - show friendly message
        setState(() {
          pendingAppointments = [];
          isLoading = false;
        });
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to load appointments');
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load pending appointments: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _updateAppointmentStatus(int appointmentId, String status, {String? newDate, String? newTime}) async {
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/api/appointments/$appointmentId/status'),
        headers: await _authHeaders(),
        body: json.encode({
          'status': status,
          'newDate': newDate,
          'newTime': newTime,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // Robust type checking for success field
        bool isSuccess = false;
        if (data['success'] is bool) {
          isSuccess = data['success'];
        } else if (data['success'] is String) {
          isSuccess = data['success'].toLowerCase() == 'true';
        } else if (data['success'] is int) {
          isSuccess = data['success'] == 1;
        }
        
        if (isSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Appointment ${status.toLowerCase()} successfully'),
              backgroundColor: Colors.green,
            ),
          );
          _loadPendingAppointments();
          widget.onRefresh?.call();
        } else {
          throw Exception(data['message'] ?? 'Failed to update appointment');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: Failed to update appointment');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showRescheduleDialog(Map<String, dynamic> appointment) {
    final dateController = TextEditingController();
    final timeController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'New Date (YYYY-MM-DD)',
                hintText: '2024-12-31',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: timeController,
              decoration: const InputDecoration(
                labelText: 'New Time (HH:MM)',
                hintText: '14:30',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (dateController.text.isNotEmpty && timeController.text.isNotEmpty) {
                Navigator.pop(context);
                _updateAppointmentStatus(
                  appointment['id'],
                  'rescheduled',
                  newDate: dateController.text,
                  newTime: timeController.text,
                );
              }
            },
            child: const Text('Reschedule'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.info_outline, color: Colors.grey, size: 48),
            const SizedBox(height: 16),
            const Text(
              'No appointments',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'There are no pending appointments at this time',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadPendingAppointments,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    if (pendingAppointments.isEmpty) {
      return const Center(
        child: Text('No pending appointments'),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pending Appointments (${pendingAppointments.length})',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _loadPendingAppointments,
                tooltip: 'Refresh',
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: pendingAppointments.length,
            itemBuilder: (context, index) {
              final appointment = pendingAppointments[index];
              final appointmentSchedule = TimeUtils.formatAppointmentUtcDateTime(
                (appointment['appointment_date'] ?? '').toString(),
                (appointment['appointment_time'] ?? '').toString(),
                pattern: 'MMMM dd, yyyy hh:mm a',
              );
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${appointment['first_name']} ${appointment['last_name']}',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              appointment['status']?.toUpperCase() ?? 'PENDING',
                              style: const TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Email: ${appointment['email']}'),
                      Text('Phone: ${appointment['phone'] ?? 'N/A'}'),
                      Text('Doctor: ${appointment['doctor_name']}'),
                      Text('Clinic: ${appointment['clinic_hospital']}'),
                      Text('Schedule: $appointmentSchedule'),
                      if (appointment['notes'] != null && appointment['notes'].isNotEmpty)
                        Text('Notes: ${appointment['notes']}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => _updateAppointmentStatus(appointment['id'], 'approved'),
                            icon: const Icon(Icons.check, size: 16),
                            label: const Text('Approve'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showRescheduleDialog(appointment),
                            icon: const Icon(Icons.schedule, size: 16),
                            label: const Text('Reschedule'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _updateAppointmentStatus(appointment['id'], 'cancelled'),
                            icon: const Icon(Icons.cancel, size: 16),
                            label: const Text('Cancel'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}