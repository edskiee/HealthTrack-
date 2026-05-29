import 'package:flutter/material.dart';
import 'settings_tab.dart';
import 'login_screen.dart';
import 'utils/message_utils.dart';
import 'services/user_session.dart';
import 'services/health_record_service.dart';

class MaternalHealthCardTab extends StatefulWidget {
  const MaternalHealthCardTab({super.key});

  @override
  State<MaternalHealthCardTab> createState() => _MaternalHealthCardTabState();
}

class _MaternalHealthCardTabState extends State<MaternalHealthCardTab> {
  List<Map<String, dynamic>> _healthRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchHealthRecords();
  }

  Future<void> _fetchHealthRecords() async {
    try {
      final userSession = UserSession.instance;
      final patientId = int.tryParse(userSession.patientId) ?? 0;
      
      if (patientId > 0) {
        final records = await HealthRecordService.getUserHealthRecords(patientId);
        setState(() {
          _healthRecords = records;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching health records: $e');
      setState(() {
        _isLoading = false;
      });
      MessageUtils.showErrorMessage(
        context,
        "Failed to load health records: $e",
        title: "Load Error",
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: RefreshIndicator(
        onRefresh: _fetchHealthRecords,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 🔹 Profile Section - Maternal version
            _buildMaternalProfileSection(),
            const SizedBox(height: 20),

            // 🔹 Information Section - Maternal version
            _buildMaternalInformationSection(),
            const SizedBox(height: 20),
            
            // 🔹 Health Records Section
            _buildHealthRecordsSection(),
            const SizedBox(height: 20),

            // 🔹 Settings Shortcut
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: const Icon(Icons.settings, color: Colors.blueAccent),
                title: const Text("Settings", style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SettingsTab(
                        onItemTap: (item) {
                          // Handle settings actions
                          if (item == "DarkModeEnabled" || item == "DarkModeDisabled") {
                            // Theme changes are handled by main app
                            MessageUtils.showInfoMessage(
                              context,
                              "Theme updated successfully",
                              title: "Settings",
                            );
                          } else if (item == "NotificationsEnabled") {
                            MessageUtils.showInfoMessage(
                              context,
                              "Notifications enabled",
                              title: "Settings",
                            );
                          } else if (item == "NotificationsDisabled") {
                            MessageUtils.showInfoMessage(
                              context,
                              "Notifications disabled",
                              title: "Settings",
                            );
                          } else if (item == "Profile Settings") {
                            MessageUtils.showInfoMessage(
                              context,
                              "Navigating to profile settings",
                              title: "Settings",
                            );
                          } else if (item == "Logout") {
                            // Clear user session
                            UserSession.instance.clearSession();
                            
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (context) => const LoginScreen()),
                              (Route<dynamic> route) => false,
                            );
                          } else {
                            MessageUtils.showInfoMessage(
                              context,
                              "Settings for $item",
                              title: "Settings",
                            );
                          }
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),

            // 🔹 Logout Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                // Clear user session
                UserSession.instance.clearSession();
                
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text("Logout",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ), // Column closing
        ),
      ),
    );
  }

  // Maternal Profile Section (matching healthcard_tab.dart)
  Widget _buildMaternalProfileSection() {
    final userSession = UserSession.instance;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.shade400, Colors.blue.shade200],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "HEALTH CARD",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  "MATERNAL CARE",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const CircleAvatar(
                radius: 30,
                backgroundColor: Colors.white,
                child: Icon(
                  Icons.pregnant_woman,
                  color: Colors.blueAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      userSession.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      "Patient ID: ${userSession.displayPatientId}",
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Maternal Information Section (updated to use real data)
  Widget _buildMaternalInformationSection() {
    final userSession = UserSession.instance;
    
    // Get maternal care specific data from patientData
    final patientData = userSession.patientData ?? {};
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Personal Information",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          _infoRow(Icons.person, "Full Name", userSession.fullName),
          const Divider(height: 20),
          _infoRow(Icons.calendar_today, "Date of Birth", userSession.formattedDateOfBirth),
          const Divider(height: 20),
          _infoRow(Icons.home, "Address", userSession.address),
          const Divider(height: 20),
          _infoRow(Icons.phone, "Phone", userSession.phone),
          const Divider(height: 20),
          _infoRow(Icons.email, "Email", userSession.email),
          const Divider(height: 20),
          _infoRow(Icons.pregnant_woman, "Spouse Name", patientData['spouse_name']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.family_restroom, "Family Serial Number", patientData['family_serial_number']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.money, "Monthly Income", 
            patientData['monthly_income'] != null ? 
            "₱${double.tryParse(patientData['monthly_income'].toString())?.toStringAsFixed(2) ?? '0.00'}" : 
            "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.child_care, "Living Children", 
            patientData['living_children_count']?.toString() ?? "0"),
          const Divider(height: 20),
          _infoRow(Icons.school, "Education", patientData['education']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.work, "Occupation", patientData['occupation']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.church, "Religion", patientData['religion']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.location_city, "City", patientData['city']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.map, "Province", patientData['province']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.event, "Age", 
            patientData['age'] != null ? 
            "${patientData['age'].toString()} years old" : 
            "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.local_hospital, "Birth Plan", patientData['facility_type']?.toString() ?? "Not provided"),
          const Divider(height: 20),
          _infoRow(Icons.medical_services, "Birth Attendant", patientData['birth_attendant']?.toString() ?? "Not provided"),
        ],
      ),
    );
  }

  // Health Records Section
  Widget _buildHealthRecordsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Health Records",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_healthRecords.isEmpty)
            const Text("No health records found")
          else
            ..._healthRecords.map((record) => _buildHealthRecordItem(record)).toList(),
        ],
      ),
    );
  }

  Widget _buildHealthRecordItem(Map<String, dynamic> record) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  record['title'] ?? 'Untitled Record',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.pink.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record['record_type'] ?? 'General',
                    style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              record['description'] ?? 'No description',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 14,
              ),
            ),
            if (record['diagnosis'] != null && record['diagnosis'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Diagnosis: ${record['diagnosis']}",
                style: const TextStyle(
                  color: Colors.red,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              "Date: ${_formatDate(record['date_recorded'] ?? record['created_at'] ?? '')}",
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return 'Unknown date';
    
    try {
      final DateTime date = DateTime.parse(dateStr);
      return "${date.month}/${date.day}/${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  // 🔹 Reusable Widgets
  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}