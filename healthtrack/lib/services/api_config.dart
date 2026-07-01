import '../env_config.dart';
import 'package:http/http.dart' as http;

class ApiConfig {
  // Base URL for API endpoints
  // In production, this should be your server's public IP or domain
  // For development, use your machine's IP address instead of localhost for web compatibility
  static String get baseUrl {
    // Try to get from environment variable or use environment config
    final String? envBaseUrl = const String.fromEnvironment('API_BASE_URL');
    
    // More robust handling of the environment variable
    final String result;
    if (envBaseUrl == null || envBaseUrl.isEmpty || envBaseUrl.trim().isEmpty) {
      result = EnvironmentConfig.getApiBaseUrl();
      print('DEBUG: Using environment-configured base URL: $result');
    } else {
      result = envBaseUrl.trim();
      print('DEBUG: Using environment variable base URL');
    }
    
    print('API Base URL resolved to: "$result"');
    return result;
  }
  
  // Enhanced method to get the best available URL with fallback mechanism
  static Future<String> getWorkingBaseUrl() async {
    final urls = [baseUrl, ...fallbackBaseUrls];
    
    for (String url in urls) {
      try {
        print('Testing connection to: $url');
        final response = await http.head(
          Uri.parse('$url/health'),
          headers: {'Accept': 'application/json'},
        ).timeout(const Duration(seconds: 5));
        
        if (response.statusCode >= 200 && response.statusCode < 300) {
          print('✅ Connected successfully to: $url');
          return url;
        }
      } catch (e) {
        print('❌ Failed to connect to $url: $e');
        continue;
      }
    }
    
    // If all URLs fail, return the primary baseUrl for error handling
    print('⚠️ All connection attempts failed, using primary URL');
    return baseUrl;
  }
  
  // Fallback URLs for API endpoints
  static List<String> get fallbackBaseUrls {
    return EnvironmentConfig.getFallbackUrls();
  }
  
  // API Endpoints
  static const String loginEndpoint = '/auth/login';
  static const String registerEndpoint = '/auth/register';
  static const String getUserEndpoint = '/auth/user';
  static const String saveFcmTokenEndpoint = '/auth/save-fcm-token';
  static const String pushNotificationPreferenceEndpoint = '/auth/push-notification-preference';
  static const String adminLoginEndpoint = '/admin/login';
  static const String adminRegisterEndpoint = '/admin/register';
  static const String getAdminEndpoint = '/admin'; // Fixed endpoint
  static const String updateAdminEndpoint = '/admin'; // Fixed endpoint
  static const String getAppointmentsEndpoint = '/appointments';
  static const String addAppointmentEndpoint = '/appointments/add';
  static const String getConsultationTypesEndpoint = '/appointments/consultation-types';
  static const String getHealthRecordsEndpoint = '/health-records';
  static const String addHealthRecordEndpoint = '/health-records/add';
  static const String getPatientDataEndpoint = '/patients/data';
  static const String updatePatientDataEndpoint = '/patients/update';
  static const String getDashboardStatsEndpoint = '/dashboard/stats';
  static const String getHealthTipsEndpoint = '/health-tips';
  static const String getNotificationsEndpoint = '/notifications';
  static const String markNotificationReadEndpoint = '/notifications';
  static const String deleteNotificationEndpoint = '/notifications';
  static const String getRemindersEndpoint = '/reminders';
  static const String createReminderEndpoint = '/reminders';
  static const String updateReminderEndpoint = '/reminders';
  static const String deleteReminderEndpoint = '/reminders';
  static const String sendReminderNotificationEndpoint = '/reminder-notifications/send-reminder';
  static const String getUpcomingRemindersEndpoint = '/reminder-notifications';

  // ── Vaccine Tracking endpoints ─────────────────────────────────────────────
  static const String getVaccineDashboardEndpoint = '/vaccines/dashboard';
  static const String getVaccineCardEndpoint = '/vaccines/card';
  static const String postVaccineRecordEndpoint = '/vaccines/record';
  static const String deleteVaccineRecordEndpoint = '/vaccines/record';

  // ── Admin Vaccine Tracking endpoints (authenticateAdmin) ───────────────────
  static const String getAdminVaccineCardEndpoint   = '/vaccines/admin/card';
  static const String getAdminVaccineBadgeEndpoint  = '/vaccines/admin/badge';
}