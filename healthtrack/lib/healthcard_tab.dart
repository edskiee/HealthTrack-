import 'package:flutter/material.dart';
import 'settings_tab.dart';
import 'login_screen.dart';
import 'utils/message_utils.dart';
import 'services/user_session.dart';
import 'services/health_record_service.dart';
import 'services/referral_service.dart';
import 'models/referral.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class HealthCardTab extends StatefulWidget {
  const HealthCardTab({super.key});

  @override
  State<HealthCardTab> createState() => _HealthCardTabState();
}

class _HealthCardTabState extends State<HealthCardTab> {
  List<Map<String, dynamic>> _healthRecords = [];
  List<Referral> _referrals = [];
  bool _isLoading = true;
  bool _isLoadingReferrals = true;
  io.Socket? _socket;

  @override
  void initState() {
    super.initState();
    _fetchHealthRecords();
    _fetchReferrals();
    _initializeWebSocket();
  }

  void _initializeWebSocket() {
    try {
      final userSession = UserSession.instance;
      final patientId = int.tryParse(userSession.patientId) ?? 0;
      
      if (patientId > 0) {
        _socket = io.io('http://10.243.17.91:3000', <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
        });

        // Join user room for real-time updates
        _socket!.emit('joinUserRoom', patientId);
        
        // Listen for new referrals
        _socket!.on('newReferral', (data) {
          if (mounted && data['type'] == 'referral_created') {
            _fetchReferrals(); // Refresh referrals when new one is created
            if (mounted) {
              MessageUtils.showInfoMessage(
                context,
                data['message'] ?? 'New referral created',
                title: "New Referral",
              );
            }
          }
        });

        // Listen for referral status updates
        _socket!.on('referralStatusUpdated', (data) {
          if (mounted && data['type'] == 'referral_status_updated') {
            _fetchReferrals(); // Refresh referrals when status changes
            if (mounted) {
              MessageUtils.showInfoMessage(
                context,
                data['message'] ?? 'Referral status updated',
                title: "Referral Update",
              );
            }
          }
        });

        // Listen for referral deletions
        _socket!.on('referralDeleted', (data) {
          if (mounted && data['type'] == 'referral_deleted') {
            _fetchReferrals(); // Refresh referrals when one is deleted
            if (mounted) {
              MessageUtils.showInfoMessage(
                context,
                data['message'] ?? 'Referral deleted',
                title: "Referral Deleted",
              );
            }
          }
        });

        _socket!.connect();
      }
    } catch (e) {
      debugPrint('Error initializing WebSocket: $e');
    }
  }

  Future<void> _fetchReferrals() async {
    try {
      final userSession = UserSession.instance;
      final patientId = int.tryParse(userSession.patientId) ?? 0;
      
      if (patientId > 0) {
        setState(() {
          _isLoadingReferrals = true;
        });
        
        final referrals = await ReferralService.getPatientReferrals(patientId);
        if (mounted) {
          setState(() {
            _referrals = referrals;
            _isLoadingReferrals = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoadingReferrals = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching referrals: $e');
      if (mounted) {
        setState(() {
          _isLoadingReferrals = false;
        });
        MessageUtils.showErrorMessage(
          context,
          "Failed to load referrals: $e",
          title: "Load Error",
        );
      }
    }
  }

  @override
  void dispose() {
    // Leave user room and disconnect WebSocket
    if (_socket != null) {
      final userSession = UserSession.instance;
      final patientId = int.tryParse(userSession.patientId) ?? 0;
      if (patientId > 0) {
        _socket!.emit('leaveUserRoom', patientId);
      }
      _socket!.disconnect();
      _socket = null;
    }
    super.dispose();
  }

  Future<void> _fetchHealthRecords() async {
    try {
      final userSession = UserSession.instance;
      final patientId = int.tryParse(userSession.patientId) ?? 0;
      
      if (patientId > 0) {
        final records = await HealthRecordService.getUserHealthRecords(patientId);
        if (mounted) {
          setState(() {
            _healthRecords = records;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error fetching health records: $e');
      if (mounted) {
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
  }

  @override
  Widget build(BuildContext context) {
    final userSession = UserSession.instance;
    final serviceType = userSession.serviceType;
    
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
              // 🔹 Profile Section - Different based on service type
              if (serviceType == 'maternal')
                _buildMaternalProfileSection()
              else
                _buildImmunizationProfileSection(),
              const SizedBox(height: 20),

              // 🔹 Information Section - Different based on service type
              if (serviceType == 'maternal')
                _buildMaternalInformationSection()
              else
                _buildImmunizationInformationSection(),
              const SizedBox(height: 20),
              
              // 🔹 Health Records Section
              _buildHealthRecordsSection(),
              const SizedBox(height: 20),

              // 🔹 Referral History Section
              _buildReferralHistorySection(),
              const SizedBox(height: 20),

              // 🔹 Settings Shortcut
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Icon(Icons.settings, 
                    color: serviceType == 'maternal' ? Colors.pink : Colors.blueAccent),
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
          ),
        ),
      ),
    );
  }

  // Immunization Profile Section
  Widget _buildImmunizationProfileSection() {
    final userSession = UserSession.instance;
    
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.teal.shade50,
              backgroundImage: const AssetImage("assets/images/profile.png"),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(userSession.childName.isNotEmpty ? userSession.childName : "Unknown Child",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text("Patient ID: ${userSession.displayPatientId}",
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _infoChip(userSession.childAge, Colors.teal.shade100, Colors.blueAccent),
                      _infoChip(userSession.sex.isNotEmpty ? userSession.sex : "Unknown", Colors.blue.shade100, Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Maternal Profile Section
  Widget _buildMaternalProfileSection() {
    final userSession = UserSession.instance;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.pink.withValues(alpha: 0.3),
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
                  color: Colors.white.withValues(alpha: 0.2),
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
                  color: Color(0xFFE91E63),
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

  // Immunization Information Section
  Widget _buildImmunizationInformationSection() {
    final userSession = UserSession.instance;
    
    return _sectionCard(
      title: "Child Information",
      children: [
        _infoRow(Icons.child_care, "Child's Name", userSession.childName.isNotEmpty ? userSession.childName : "Unknown"),
        _infoRow(Icons.calendar_today, "Date of Birth", userSession.formattedDateOfBirth),
        _infoRow(Icons.location_on, "Place of Birth", userSession.placeOfBirth.isNotEmpty ? userSession.placeOfBirth : "Unknown"),
        _infoRow(Icons.home, "Address", userSession.patientAddress.isNotEmpty ? userSession.patientAddress : "Unknown"),
        const Divider(),
        _infoRow(Icons.female, "Mother's Name", userSession.motherName.isNotEmpty ? userSession.motherName : "Unknown"),
        _infoRow(Icons.male, "Father's Name", userSession.fatherName.isNotEmpty ? userSession.fatherName : "Unknown"),
        const Divider(),
        _infoRow(Icons.height, "Birth Height", userSession.birthHeight.isNotEmpty ? "${userSession.birthHeight} cm" : "Unknown"),
        _infoRow(Icons.monitor_weight, "Birth Weight", userSession.birthWeight.isNotEmpty ? "${userSession.birthWeight} kg" : "Unknown"),
        _infoRow(Icons.wc, "Sex", userSession.sex.isNotEmpty ? userSession.sex : "Unknown"),
        const Divider(),
        _infoRow(Icons.local_hospital, "Health Center", "General Health Center"), // Add this to database later
        _infoRow(Icons.location_city, "Barangay", "General Area"), // Add this to database later
      ],
    );
  }

  // Maternal Information Section
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
            color: Colors.grey.withValues(alpha: 0.1),
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
            color: Colors.grey.withValues(alpha: 0.1),
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
            ..._healthRecords.map((record) => _buildHealthRecordItem(record)),
        ],
      ),
    );
  }

  Widget _buildHealthRecordItem(Map<String, dynamic> record) {
    final serviceType = UserSession.instance.serviceType;
    
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
                    color: serviceType == 'maternal' ? Colors.pink.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    record['record_type'] ?? 'General',
                    style: TextStyle(
                      color: serviceType == 'maternal' ? Colors.pink : Colors.blue,
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
  Widget _infoChip(String text, Color bg, Color color) {
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: UserSession.instance.serviceType == 'maternal' ? Colors.pink : Colors.blueAccent),
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

  // Referral History Section
  Widget _buildReferralHistorySection() {
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Referral History",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              if (_referrals.isNotEmpty)
                TextButton.icon(
                  onPressed: _fetchReferrals,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text("Refresh", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingReferrals)
            const Center(child: CircularProgressIndicator())
          else if (_referrals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.medical_services,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    "No referrals found",
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Your referral history will appear here once referrals are created by healthcare providers.",
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            ..._referrals.map((referral) => _buildReferralItem(referral)),
        ],
      ),
    );
  }

  Widget _buildReferralItem(Referral referral) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    referral.referredTo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ReferralService.getStatusBackgroundColor(referral.status),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: ReferralService.getStatusColor(referral.status),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    ReferralService.formatStatus(referral.status),
                    style: TextStyle(
                      color: ReferralService.getStatusColor(referral.status),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Referral details
            _buildReferralDetailRow(Icons.calendar_today, "Date", _formatReferralDate(referral.referralDate)),
            _buildReferralDetailRow(Icons.person, "Referred By", referral.adminName ?? "Healthcare Provider"),
            if (referral.referralNotes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                "Clinical Notes:",
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Text(
                  referral.referralNotes,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
              ),
            ],
            
            // Created at timestamp
            if (referral.createdAt != null) ...[
              const SizedBox(height: 8),
              Text(
                "Created: ${_formatDateTime(referral.createdAt!)}",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReferralDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Colors.grey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatReferralDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return "${date.month}/${date.day}/${date.year}";
    } catch (e) {
      return dateString;
    }
  }

  String _formatDateTime(String dateTimeString) {
    try {
      final dateTime = DateTime.parse(dateTimeString);
      return "${dateTime.month}/${dateTime.day}/${dateTime.year} at ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}";
    } catch (e) {
      return dateTimeString;
    }
  }
}
