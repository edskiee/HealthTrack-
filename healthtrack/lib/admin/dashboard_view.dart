import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../services/dashboard_service.dart';
import '../utils/message_utils.dart';
import '../utils/time_utils.dart';
import '../admin/admin_login_screen.dart';
import '../admin/services/realtime_refresh_service.dart';
import 'widgets/admin_header.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> {
  bool isLoading = true;
  String? errorMessage;
  Map<String, dynamic> dashboardStats = {};
  List<Map<String, dynamic>> activities = [];
  List<Map<String, dynamic>> appointments = [];
  Timer? _refreshTimer;
  
  // Socket.IO client for real-time updates
  io.Socket? _socket;
  
  // Register for dashboard refresh callbacks
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
    
    // Register callback with real-time refresh service
    RealtimeRefreshService().addRefreshCallback(_loadDashboardData, moduleId: 'dashboard');
    
    // Initialize Socket.IO connection for real-time updates
    _initSocketConnection();
  }

  @override
  void dispose() {
    // Unregister callback when widget is disposed
    RealtimeRefreshService().removeCallbacksByModuleId('dashboard');
    
    // Disconnect Socket.IO when widget is disposed
    _socket?.disconnect();
    
    super.dispose();
  }
  
  /// Initialize Socket.IO connection for real-time dashboard updates
  void _initSocketConnection() {
    try {
      // Connect to the same server the API is running on
      final serverUrl = 'http://10.243.17.91:3000'; // Use the actual server IP
      
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });
      
      // Connect to the socket
      _socket?.connect();
      
      // Join the admins room for real-time updates
      _socket?.emit('joinAdminsRoom');
      
      // Listen for dashboard updates
      _socket?.on('dashboard_update', (data) {
        print('🔔 Dashboard update received: $data');
        // Refresh the dashboard data when an update is received
        if (mounted) {
          _loadDashboardData();
        }
      });
      
      print('✅ Socket.IO connection initialized for real-time dashboard updates');
    } catch (e) {
      print('❌ Error initializing Socket.IO connection: $e');
    }
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch dashboard statistics
      final stats = await DashboardService.getDashboardStats();
      if (!mounted) return;
      
      // Fetch recent activities
      final activities = await DashboardService.getRecentActivities();
      if (!mounted) return;
      
      // Fetch today's appointments
      final appointments = await DashboardService.getTodayAppointments();
      if (!mounted) return;
      
      setState(() {
        dashboardStats = stats;
        this.activities = activities;
        this.appointments = appointments;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        errorMessage = 'Error: ${e.toString()}';
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        // ✅ Light blue gradient background
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFE3F2FD), // softer blue top
              Color(0xFFFFFFFF), // pure white bottom
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            AdminHeader(
              title: "Dashboard Overview",
              subtitle: "Preventive Healthcare Management System",
              onRefresh: _loadDashboardData,
            ),
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline,
                                  size: 48, color: Colors.red),
                              const SizedBox(height: 16),
                              Text(
                                errorMessage!,
                                style: TextStyle(color: Colors.red[700]),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadDashboardData,
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildWelcomeBanner(),
                                const SizedBox(height: 20),
                                _buildStatsCards(),
                                const SizedBox(height: 20),
                                _buildActivitiesAndAppointments(),
                              ],
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildWelcomeBanner() {
    return Card(
      elevation: 4,
      shadowColor: Colors.blue.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: const Color(0xFFE3F2FD),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, size: 48, color: const Color(0xFF1565C0)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Here's what's happening with your healthtrack system today",
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF1565C0), // Professional blue
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.autorenew, size: 14, color: const Color(0xFF1565C0)),
                          const SizedBox(width: 4),
                          Text(
                            "Auto-refreshes every 30 seconds",
                            style: TextStyle(color: const Color(0xFF1565C0), fontSize: 12),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Overview",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              "Total Patients",
              "${dashboardStats['totalPatients'] ?? 0}",
              Icons.people,
              Colors.blue,
              _getChangeIndicator(dashboardStats['totalPatientsChange']),
              elevation: 8, // ✅ Enhanced shadow
              shadowColor: Colors.blue.withOpacity(0.15), // ✅ Enhanced soft shadow
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              "Prenatal Care Patients",
              "${dashboardStats['maternalPatients'] ?? 0}",
              Icons.pregnant_woman,
              Colors.pink,
              _getChangeIndicator(dashboardStats['maternalPatientsChange']),
              elevation: 8,
              shadowColor: Colors.pink.withOpacity(0.15),
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              "Immunization Patients",
              "${dashboardStats['immunizationPatients'] ?? 0}",
              Icons.vaccines,
              Colors.green,
              _getChangeIndicator(dashboardStats['immunizationPatientsChange']),
              elevation: 8,
              shadowColor: Colors.green.withOpacity(0.15),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              "Appointments Today",
              "${dashboardStats['appointmentsToday'] ?? 0}",
              Icons.calendar_today,
              Colors.blue,
              _getChangeIndicator(dashboardStats['appointmentsTodayChange']),
              elevation: 8,
              shadowColor: Colors.blue.withOpacity(0.15),
            ),
            const SizedBox(width: 16),
            _buildStatCard(
              "Health Records Added",
              "${dashboardStats['todayRecords'] ?? 0}",
              Icons.description,
              Colors.purple,
              _getChangeIndicator(dashboardStats['todayRecordsChange']),
              elevation: 8,
              shadowColor: Colors.purple.withOpacity(0.15),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildStatCard(
              "Pending Approvals",
              "${dashboardStats['pendingApprovals'] ?? 0}",
              Icons.pending_actions,
              Colors.orange,
              _getChangeIndicator(dashboardStats['pendingApprovalsChange']),
              elevation: 8,
              shadowColor: Colors.orange.withOpacity(0.15),
            ),
          ],
        ),
      ],
    );
  }  
  
  String _getChangeIndicator(dynamic change) {
    if (change == null) return "+0.0%";
    
    if (change is num) {
      final prefix = change >= 0 ? "+" : "";
      return "$prefix${change.toStringAsFixed(1)}%";
    } else if (change is String) {
      if (change.startsWith("+") || change.startsWith("-")) {
        return change;
      } else {
        return "+$change";
      }
    }
    
    return "+0.0%";
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change, {
    double elevation = 4, // ✅ Step 4: soft shadow elevation
    Color? shadowColor,   // ✅ Step 4: soft shadow color
  }) {
    return Expanded(
      child: Card(
        elevation: elevation, // ✅ adds the airlifted look
        shadowColor: shadowColor ?? color.withOpacity(0.1), // ✅ soft glow
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // optional: smoother edges
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: const Color(0xFF424242), // Darker gray for better readability
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Icon(icon, color: color),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    change,
                    style: TextStyle(
                      color: change.startsWith("+") ? const Color(0xFF388E3C) : const Color(0xFFD32F2F), // Deeper green / Professional red
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    "vs last month",
                    style: TextStyle(
                      color: const Color(0xFF757575), // Medium gray
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivitiesAndAppointments() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 1,
          child: Card(
            elevation: 4,
            shadowColor: Colors.grey.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Recent Activities",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (activities.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "No recent activities",
                          style: TextStyle(color: const Color(0xFF757575)),
                        ),
                      ),
                    )
                  else
                    ...activities.map((activity) => _buildActivityItem(
                          activity['patient_name']?.toString() ?? 'Unknown Patient',
                          'New patient registered',
                          activity['time']?.toString() ?? '',
                        )).toList(),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          flex: 1,
          child: Card(
            elevation: 4,
            shadowColor: Colors.grey.withOpacity(0.1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Today's Appointments",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  if (appointments.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          "No appointments today",
                          style: TextStyle(color: const Color(0xFF757575)),
                        ),
                      ),
                    )
                  else
                     ...appointments.map((appointment) => _buildAppointmentItem(
                           TimeUtils.formatTimeString12Hour(appointment['time']?.toString() ?? ''),
                           appointment['patientName']?.toString() ?? 'Unknown Patient',
                           appointment['type']?.toString() ?? '',
                           status: appointment['status']?.toString() ?? 'Confirmed',
                         )).toList(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActivityItem(String title, String description, String time) {
    IconData activityIcon = Icons.history;
    Color activityColor = Colors.blue;
    
    if (title.contains('Registration') || title.contains('New Patient')) {
      activityIcon = Icons.person_add;
      activityColor = Colors.green;
    } else if (title.contains('Appointment')) {
      activityIcon = Icons.calendar_today;
      activityColor = Colors.blue;
    } else if (title.contains('Record') || title.contains('Updated')) {
      activityIcon = Icons.description;
      activityColor = Colors.purple;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: activityColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(activityIcon, color: activityColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF424242)),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: const Color(0xFF424242), fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(color: const Color(0xFF757575), fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentItem(String time, String patientName, String appointmentType, {String status = "Confirmed"}) {
    Color statusColor = Colors.green;
    if (status == "Pending") {
      statusColor = Colors.orange;
    } else if (status == "Cancelled") {
      statusColor = Colors.red;
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE3F2FD), // Softer blue
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                time.isNotEmpty ? time.substring(0, 1) : "A",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1565C0), // Professional blue
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patientName,
                  style: TextStyle(fontWeight: FontWeight.bold, color: const Color(0xFF424242)),
                ),
                const SizedBox(height: 4),
                Text(
                  "$time - $appointmentType",
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF424242),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: statusColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}