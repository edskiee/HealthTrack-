import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'main.mobile.dart'; // Import to access SettingsProvider
import 'services/user_session.dart';
import 'services/auth_service.dart';

class SettingsTab extends StatefulWidget {
  final void Function(String) onItemTap;

  const SettingsTab({super.key, required this.onItemTap});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  bool _darkMode = false;
  bool _notifications = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Load settings from shared preferences (and server push flag when logged in)
  _loadSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    var notifications = prefs.getBool('notifications') ?? true;
    final uid = UserSession.instance.userId;
    final sid = int.tryParse(uid);
    if (sid != null) {
      final serverPref = await AuthService.fetchPushNotificationPreference(sid);
      if (serverPref != null) {
        notifications = serverPref;
        await prefs.setBool('notifications', notifications);
      }
    }
    if (!mounted) return;
    setState(() {
      _darkMode = prefs.getBool('isDarkMode') ?? false;
      _notifications = notifications;
    });
  }

  // Save settings to shared preferences
  _saveSettings() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', _darkMode);
    await prefs.setBool('notifications', _notifications);
    
    // Update theme globally
    if (mounted) {
      final settingsProvider = SettingsProvider.of(context);
      if (settingsProvider != null) {
        settingsProvider.updateTheme(_darkMode);
      }
    }
  }

  // Toggle dark mode
  _toggleDarkMode(bool value) {
    setState(() {
      _darkMode = value;
    });
    _saveSettings();
    
    // Apply theme change through SettingsProvider
    final settingsProvider = SettingsProvider.of(context);
    if (settingsProvider != null) {
      settingsProvider.updateTheme(_darkMode);
    }
    
    // Notify parent about theme change
    widget.onItemTap(_darkMode ? "DarkModeEnabled" : "DarkModeDisabled");
  }

  // Toggle notifications (persist locally + server for FCM gating)
  _toggleNotifications(bool value) async {
    setState(() {
      _notifications = value;
    });
    await _saveSettings();
    final sid = int.tryParse(UserSession.instance.userId);
    if (sid != null) {
      await AuthService.updatePushNotificationPreference(userId: sid, enabled: value);
    }
    if (!mounted) return;
    widget.onItemTap(_notifications ? "NotificationsEnabled" : "NotificationsDisabled");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Theme.of(context).appBarTheme.backgroundColor ?? Colors.white,
        foregroundColor: Theme.of(context).appBarTheme.foregroundColor ?? Colors.black87,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            "Settings",
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "Manage your account and app preferences",
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Preferences Section
          _buildSectionHeader("Preferences"),
          _buildSwitchTile(
            icon: Icons.dark_mode,
            title: "Dark Mode",
            subtitle: "Switch between light and dark themes",
            value: _darkMode,
            onChanged: _toggleDarkMode,
          ),
          _buildSwitchTile(
            icon: Icons.notifications,
            title: "Notifications",
            subtitle: "Receive push notifications for appointments and reminders",
            value: _notifications,
            onChanged: _toggleNotifications,
          ),

          const SizedBox(height: 20),

          // Account Section
          _buildSectionHeader("Account"),
          _buildListTile(
            icon: Icons.person,
            title: "Profile Settings",
            subtitle: "Manage your personal information",
            onTap: () => widget.onItemTap("Profile Settings"),
          ),

          const SizedBox(height: 20),

          // Support Section
          _buildSectionHeader("Support"),
          _buildListTile(
            icon: Icons.help,
            title: "Help & Support",
            subtitle: "Get help and contact support",
            onTap: () => widget.onItemTap("Help & Support"),
          ),
          _buildListTile(
            icon: Icons.language,
            title: "Language",
            subtitle: "English",
            onTap: () => widget.onItemTap("Language"),
          ),
          _buildListTile(
            icon: Icons.info,
            title: "About",
            subtitle: "App version and information",
            onTap: () => widget.onItemTap("About"),
          ),

          const SizedBox(height: 20),

          // App Info
          Center(
            child: Column(
              children: const [
                Text("HealthTrack", style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 4),
                Text("Version 1.0.0", style: TextStyle(color: Colors.grey)),
                SizedBox(height: 4),
                Text("Preventive HealthCare Management",
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Logout Button
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => widget.onItemTap("Logout"),
            icon: const Icon(Icons.logout),
            label: const Text("Logout"),
          ),
        ],
      ),
    );
  }

  // 🔹 Reusable widgets
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required void Function(bool) onChanged,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: Switch(value: value, onChanged: onChanged),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}