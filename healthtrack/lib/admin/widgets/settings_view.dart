import 'package:flutter/material.dart';
import '../admin_login_screen.dart';
import '../../utils/message_utils.dart';
import '../system_settings_service.dart';
import '../services/admin_profile_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
class SettingsView extends StatefulWidget {
  final Map<String, dynamic>? adminData;

  const SettingsView({super.key, this.adminData});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  // Admin profile
  Map<String, dynamic> adminProfile = {};
  bool isAdminLoading = false;
  String? adminErrorMessage;
  
  // Notification settings
  bool _appointmentReminders = true;
  bool _systemAlerts = true;
  
  // Privacy & Security settings
  bool _dataSharing = false;
  bool _analyticsTracking = false;
  bool _autoLogout = false;
  
  // System Information
  String _appVersion = "1.0.0";
  String _lastUpdated = "Dec 5, 2025";
  String _systemStatus = "Operational";
  String _environment = "Production";
  
  // Loading states
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadAdminProfile();
    _loadSettings();
  }
  
  Future<void> _loadAdminProfile() async {
    try {
      setState(() {
        isAdminLoading = true;
        adminErrorMessage = null;
      });
      
      // Get admin ID from logged-in user data
      final adminId = widget.adminData?['id'] as int? ?? 1;
      final profile = await AdminProfileService.getAdminProfile(adminId);
      
      setState(() {
        adminProfile = profile;
        isAdminLoading = false;
      });
    } catch (e) {
      setState(() {
        adminErrorMessage = e.toString();
        isAdminLoading = false;
      });
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error loading admin profile: $e',
          title: "Profile Error",
        );
      }
    }
  }
  
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load notification settings from backend
      final appointmentRemindersSetting = await SystemSettingsService.getSettingByKey('appointment_reminders_enabled');
      final systemAlertsSetting = await SystemSettingsService.getSettingByKey('notifications_enabled');
      
      // Load privacy settings from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final dataSharing = prefs.getBool('data_sharing') ?? false;
      final analyticsTracking = prefs.getBool('analytics_tracking') ?? false;
      final autoLogout = prefs.getBool('auto_logout') ?? false;
      
      setState(() {
        _appointmentReminders = appointmentRemindersSetting != null 
          ? appointmentRemindersSetting['setting_value'] == 'true' 
          : true;
        _systemAlerts = systemAlertsSetting != null 
          ? systemAlertsSetting['setting_value'] == 'true' 
          : true;
        _dataSharing = dataSharing;
        _analyticsTracking = analyticsTracking;
        _autoLogout = autoLogout;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error loading settings: $e',
          title: "Settings Error",
        );
      }
    }
  }
  
  Future<void> _saveNotificationSettings() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Save notification settings to backend
      await SystemSettingsService.updateSetting(
        'appointment_reminders_enabled',
        _appointmentReminders.toString(),
        'boolean',
        'Enable/disable appointment reminder notifications'
      );
      
      await SystemSettingsService.updateSetting(
        'notifications_enabled',
        _systemAlerts.toString(),
        'boolean',
        'Enable/disable all system notifications'
      );
      
      // Save privacy settings to shared preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('data_sharing', _dataSharing);
      await prefs.setBool('analytics_tracking', _analyticsTracking);
      await prefs.setBool('auto_logout', _autoLogout);
      
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        MessageUtils.showSuccessMessage(
          context,
          "Settings saved successfully!",
          title: "Settings Updated",
        );
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error saving settings: $e',
          title: "Save Error",
        );
      }
    }
  }
  
  Future<void> _changePassword() async {
    // Show dialog for password change
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text(
            "Change Password",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Current Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: () async {
                // Validate passwords
                if (newPasswordController.text.isEmpty) {
                  MessageUtils.showErrorMessage(
                    context,
                    "New password cannot be empty",
                    title: "Validation Error",
                  );
                  return;
                }
                
                if (newPasswordController.text != confirmPasswordController.text) {
                  MessageUtils.showErrorMessage(
                    context,
                    "New password and confirmation do not match",
                    title: "Validation Error",
                  );
                  return;
                }
                
                Navigator.pop(context);
                
                try {
                  // Update admin profile with new password
                  final adminId = widget.adminData?['id'] as int? ?? 1;
                  await AdminProfileService.updateAdminProfile(
                    adminId: adminId,
                    currentPassword: currentPasswordController.text,
                    newPassword: newPasswordController.text,
                  );
                  
                  if (mounted) {
                    MessageUtils.showSuccessMessage(
                      context,
                      "Password changed successfully!",
                      title: "Password Changed",
                    );
                    
                    // Clear password fields
                    currentPasswordController.clear();
                    newPasswordController.clear();
                    confirmPasswordController.clear();
                  }
                } catch (e) {
                  if (mounted) {
                    MessageUtils.showErrorMessage(
                      context,
                      'Error changing password: $e',
                      title: "Password Error",
                    );
                  }
                }
              },
              child: const Text("Change"),
            ),
          ],
        ),
      );
    }
  }
  
  Future<void> _logoutFromAllDevices() async {
    if (mounted) {
      MessageUtils.showInfoMessage(
        context,
        "This feature would log you out from all devices in a real implementation.",
        title: "Feature Information",
      );
    }
  }
  
  Future<void> _signOut() async {
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const AdminLoginScreen()),
        (route) => false,
      );    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Page Title
              const Text(
                'Settings',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Manage your account preferences and app settings',
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 20),
              
              // Loading indicator
              if (_isLoading || isAdminLoading)
                const Center(child: CircularProgressIndicator())
              else
                // Main content
                _buildSettingsContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsContent() {
    if (adminErrorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Failed to load profile',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              adminErrorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAdminProfile,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Profile Information Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Profile Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            adminProfile['full_name'] ?? 'Administrator',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            adminProfile['username'] ?? 'admin',
                            style: const TextStyle(
                              color: Colors.black54,
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
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Notifications Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notifications',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Appointment Reminders',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Receive notifications for upcoming appointments',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  value: _appointmentReminders,
                  onChanged: (value) {
                    setState(() {
                      _appointmentReminders = value;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'System Alerts',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Receive important system notifications',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  value: _systemAlerts,
                  onChanged: (value) {
                    setState(() {
                      _systemAlerts = value;
                    });
                  },
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Privacy & Security Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Privacy & Security',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Data Sharing',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Allow anonymous usage data sharing',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  value: _dataSharing,
                  onChanged: (value) {
                    setState(() {
                      _dataSharing = value;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Analytics Tracking',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Help us improve by sending analytics',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  value: _analyticsTracking,
                  onChanged: (value) {
                    setState(() {
                      _analyticsTracking = value;
                    });
                  },
                ),
                const Divider(),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text(
                    'Auto Logout',
                    style: TextStyle(
                      fontSize: 16,
                    ),
                  ),
                  subtitle: const Text(
                    'Automatically logout after 30 minutes of inactivity',
                    style: TextStyle(
                      fontSize: 14,
                    ),
                  ),
                  value: _autoLogout,
                  onChanged: (value) {
                    setState(() {
                      _autoLogout = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _changePassword,
                    child: const Text(
                      "Change Password",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // System Information Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'System Information',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Application Version', _appVersion),
                const SizedBox(height: 8),
                _buildInfoRow('Last Updated', _lastUpdated),
                const SizedBox(height: 8),
                _buildInfoRow('System Status', _systemStatus),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green[100],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    "Production",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Danger Zone Card
        Card(
          color: Colors.red[50],
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Danger Zone',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Logout from all devices',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This will log you out from all devices where you are currently signed in.',
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _logoutFromAllDevices,
                    child: const Text(
                      "Logout from all devices",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _signOut,
                    child: const Text(
                      "Sign Out",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Save Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: _isSaving ? null : _saveNotificationSettings,
            child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  "Save Settings",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Row(
      children: [
        Expanded(
          flex: 1,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            value,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 14,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}