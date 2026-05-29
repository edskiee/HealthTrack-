import 'dart:async'; // Add this import

class UserSession {
  static UserSession? _instance;
  UserSession._internal();
  
  static UserSession get instance {
    _instance ??= UserSession._internal();
    return _instance!;
  }

  // User data
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _patientData;
  
  // Notification count change stream
  final StreamController<void> _notificationCountController = StreamController<void>.broadcast(); // Add this
  Stream<void> get onNotificationCountChanged => _notificationCountController.stream; // Add this

  // Getters
  Map<String, dynamic>? get userData => _userData;
  Map<String, dynamic>? get patientData => _patientData;
  
  bool get isLoggedIn => _userData != null;
  
  // User info getters - SAFE TYPE CONVERSION
  String get userId => _userData?['id']?.toString() ?? '';
  String get username => _userData?['username']?.toString() ?? '';
  String get fullName => _userData?['full_name']?.toString() ?? '';
  String get email => _userData?['email']?.toString() ?? '';
  String get phone => _userData?['phone']?.toString() ?? '';
  String get address => _userData?['address']?.toString() ?? '';
  String get serviceType => _userData?['service_type']?.toString() ?? 'immunization';
  
  // Patient info getters - SAFE TYPE CONVERSION TO PREVENT TYPE ERRORS
  String get patientId => _patientData?['id']?.toString() ?? '';
  String get childName => _patientData?['child_fullname']?.toString() ?? _patientData?['child_name']?.toString() ?? 'Unknown Child';
  String get motherName => _patientData?['mother_fullname']?.toString() ?? _patientData?['mother_name']?.toString() ?? 'Unknown Mother';
  String get fatherName => _patientData?['father_fullname']?.toString() ?? _patientData?['father_name']?.toString() ?? '';
  String get dateOfBirth => _patientData?['dob']?.toString() ?? _patientData?['date_of_birth']?.toString() ?? '';
  String get placeOfBirth => _patientData?['place_of_birth']?.toString() ?? '';
  String get birthWeight => _patientData?['birth_weight']?.toString() ?? '';
  String get birthHeight => _patientData?['birth_height']?.toString() ?? '';
  String get sex => _patientData?['sex']?.toString() ?? '';
  String get patientAddress => _patientData?['address']?.toString() ?? '';
  String get patientStatus => _patientData?['status']?.toString() ?? 'active';

  // Set user data (called after successful login) - SAFE TYPE CONVERSION
  void setUserData(Map<String, dynamic> userData) {
    _userData = userData;
    print('👤 User session set: ${userData['username']?.toString() ?? 'Unknown User'}');
    print('サービスタイプ: ${userData['service_type']?.toString() ?? 'immunization'}');
  }

  // Set patient data (called after fetching patient info) - SAFE TYPE CONVERSION
  void setPatientData(Map<String, dynamic> patientData) {
    _patientData = patientData;
    final childName = patientData['child_fullname']?.toString() ?? 
                     patientData['child_name']?.toString() ?? 
                     'Unknown Child';
    print('👶 Patient data set: $childName');
  }

  // Clear session (logout)
  void clearSession() {
    _userData = null;
    _patientData = null;
    print('🚪 User session cleared');
  }

  // Get formatted age from date of birth
  String get childAge {
    if (dateOfBirth.isEmpty) return 'Unknown';
    
    try {
      DateTime birthDate = DateTime.parse(dateOfBirth);
      DateTime now = DateTime.now();
      int ageYears = now.year - birthDate.year;
      int ageMonths = now.month - birthDate.month;
      
      if (ageMonths < 0) {
        ageYears--;
        ageMonths += 12;
      }
      
      if (ageYears > 0) {
        return '$ageYears yrs old';
      } else {
        return '$ageMonths months old';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  // Get formatted date of birth
  String get formattedDateOfBirth {
    if (dateOfBirth.isEmpty) return 'Unknown';
    
    try {
      DateTime birthDate = DateTime.parse(dateOfBirth);
      List<String> months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      
      return '${months[birthDate.month - 1]} ${birthDate.day}, ${birthDate.year}';
    } catch (e) {
      return dateOfBirth;
    }
  }
  
  // Notify that notification count has changed
  void notifyNotificationCountChanged() {
    // This method is used to trigger a refresh of notification badges
    _notificationCountController.add(null);
  }

  // Generate patient ID for display
  String get displayPatientId {
    if (patientId.isEmpty) return 'HC-UNKNOWN';
    return 'HC-2025-${patientId.padLeft(4, '0')}';
  }

  // Debug print session info
  void printSessionInfo() {
    print('=== USER SESSION INFO ===');
    print('User ID: $userId');
    print('Username: $username');
    print('Full Name: $fullName');
    print('Email: $email');
    print('Child Name: $childName');
    print('Mother Name: $motherName');
    print('Father Name: $fatherName');
    print('Date of Birth: $dateOfBirth');
    print('Age: $childAge');
    print('Sex: $sex');
    print('Patient ID: $displayPatientId');
    print('Service Type: $serviceType');
    print('========================');
  }
  
  // Dispose method to clean up resources
  void dispose() {
    _notificationCountController.close();
  }
}