import 'dart:convert';
import 'package:flutter/material.dart';
import 'dart:developer' as developer;

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  static void handleError(dynamic error, {String? context, StackTrace? stackTrace}) {
    final errorMessage = _formatErrorMessage(error, context);
    developer.log(errorMessage, error: error, stackTrace: stackTrace);
    
    // Log to console for debugging
    print('ERROR: $errorMessage');
    if (stackTrace != null) {
      print('StackTrace: $stackTrace');
    }
  }

  static void handleApiError(dynamic error, {String? endpoint, int? statusCode}) {
    String message = 'API Error';
    if (endpoint != null) message += ' at $endpoint';
    if (statusCode != null) message += ' (Status: $statusCode)';
    
    handleError(error, context: message);
  }

  static void handleValidationError(String field, String message) {
    handleError('Validation Error: $field - $message', context: 'Form Validation');
  }

  static void handleDuplicateError(String entity, String identifier) {
    handleError('Duplicate $entity detected: $identifier', context: 'Duplicate Prevention');
  }

  static String _formatErrorMessage(dynamic error, String? context) {
    String message = error.toString();
    if (context != null) {
      message = '$context: $message';
    }
    return message;
  }

  static void showErrorDialog(BuildContext context, String message, {String? title}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title ?? 'Error'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  static void showSuccessDialog(BuildContext context, String message, {String? title}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title ?? 'Success'),
          content: Text(message),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }
}

class DuplicatePreventionService {
  static final DuplicatePreventionService _instance = DuplicatePreventionService._internal();
  factory DuplicatePreventionService() => _instance;
  DuplicatePreventionService._internal();

  final Map<String, DateTime> _recentRequests = {};
  static const Duration _duplicateWindow = Duration(seconds: 5);

  bool isDuplicateRequest(String requestKey) {
    final now = DateTime.now();
    final lastRequest = _recentRequests[requestKey];

    if (lastRequest != null && now.difference(lastRequest) < _duplicateWindow) {
      ErrorHandlerService.handleDuplicateError('Request', requestKey);
      return true;
    }

    _recentRequests[requestKey] = now;
    
    // Clean up old entries
    _recentRequests.removeWhere((key, timestamp) => 
      now.difference(timestamp) > _duplicateWindow);
    
    return false;
  }

  void clearRequestHistory(String requestKey) {
    _recentRequests.remove(requestKey);
  }

  String generateRequestKey(String endpoint, Map<String, dynamic> data) {
    final sortedData = Map.fromEntries(
      data.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );
    return '$endpoint:${jsonEncode(sortedData)}';
  }
}

class ValidationService {
  static bool validateEmail(String email) {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    return emailRegex.hasMatch(email);
  }

  static bool validatePhoneNumber(String phone) {
    final phoneRegex = RegExp(r'^[\+]?[0-9]{10,15}$');
    return phoneRegex.hasMatch(phone.replaceAll(RegExp(r'[\s\-\(\)]'), ''));
  }

  static bool validateDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  static bool validateTime(String time) {
    // Support both HH:MM and HH:MM:SS formats
    final timeRegex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9](:[0-5][0-9])?$');
    return timeRegex.hasMatch(time);
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }

  static String? validateAppointmentData(Map<String, dynamic> data) {
    // Check required fields using frontend field names
    final requiredFields = [
      'userId',
      'patientId',
      'doctorName',
      'clinicHospital',
      'appointmentDate',
      'appointmentTime',
      'appointmentType'
    ];
    
    for (final field in requiredFields) {
      if (data[field] == null || data[field].toString().trim().isEmpty) {
        return 'Missing required field: $field';
      }
    }

    // Validate date format
    if (!validateDate(data['appointmentDate'])) {
      return 'Invalid appointment date format. Please use YYYY-MM-DD format.';
    }

    // Validate time format
    if (!validateTime(data['appointmentTime'])) {
      return 'Invalid appointment time format. Please use HH:MM format.';
    }

    // Check that the date is not in the past
    try {
      final appointmentDate = DateTime.parse(data['appointmentDate']);
      final today = DateTime.now();
      final todayWithoutTime = DateTime(today.year, today.month, today.day);
      
      if (appointmentDate.isBefore(todayWithoutTime)) {
        return 'Appointment date cannot be in the past.';
      }
    } catch (e) {
      return 'Invalid appointment date.';
    }

    return null;
  }
}