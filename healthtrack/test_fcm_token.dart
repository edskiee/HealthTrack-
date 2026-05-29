// test_fcm_token.dart - Test FCM token retrieval
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> main() async {
  print('🏥 HealthTrack FCM Token Test');
  print('============================');
  
  try {
    // Initialize Firebase
    await Firebase.initializeApp();
    print('✅ Firebase initialized');
    
    // Get Firebase Messaging instance
    final messaging = FirebaseMessaging.instance;
    print('✅ Firebase Messaging instance created');
    
    // Request permission for notifications
    final NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: true,
    );
    
    print('🔔 Notification permission status: ${settings.authorizationStatus}');
    
    // Get FCM token
    final token = await messaging.getToken();
    if (token != null) {
      print('✅ FCM Token retrieved:');
      print('   ${token.substring(0, 50)}...');
      print('   Length: ${token.length} characters');
      
      // Check if it's a real token or fake/test token
      if (token.contains('fake') || token.contains('test')) {
        print('⚠️  This appears to be a FAKE/TEST token');
      } else {
        print('✅ This appears to be a REAL device token');
      }
    } else {
      print('❌ No FCM token retrieved');
    }
    
    // Listen for token refresh
    messaging.onTokenRefresh.listen((newToken) {
      print('🔄 FCM Token refreshed:');
      print('   ${newToken.substring(0, 50)}...');
      
      if (newToken.contains('fake') || newToken.contains('test')) {
        print('⚠️  Refreshed token appears to be FAKE/TEST');
      } else {
        print('✅ Refreshed token appears to be REAL');
      }
    }).onError((err) {
      print('❌ Error listening to token refresh: $err');
    });
    
  } catch (e) {
    print('❌ Error: $e');
  }
}