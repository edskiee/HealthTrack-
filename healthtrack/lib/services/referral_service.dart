import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:healthtrack/models/referral.dart';
import 'package:healthtrack/services/api_config.dart';
import 'package:healthtrack/admin/services/admin_session_storage.dart';
import 'package:healthtrack/services/user_session_storage.dart';
import 'package:flutter/material.dart';

class ReferralService {
  static String get _baseUrl => ApiConfig.baseUrl;

  static Future<Map<String, String>> _adminHeaders() async {
    final token = await AdminSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<Map<String, String>> _userHeaders() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  // Create a new referral
  static Future<Referral?> createReferral({
    required int patientId,
    required String referredTo,
    required String referralDate,
    required String referralNotes,
    int? referringAdminId,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/referrals'),
        headers: await _adminHeaders(),
        body: jsonEncode({
          'patient_id': patientId,
          'referred_to': referredTo.trim(),
          'referral_date': referralDate,
          'referral_notes': referralNotes.trim(),
          'referring_admin_id': referringAdminId,
        }),
      );

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          return Referral.fromJson(responseData['data']);
        }
      }
      
      // Handle error responses
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to create referral');
      
    } catch (e) {
      debugPrint('Error creating referral: $e');
      throw Exception('Failed to create referral: $e');
    }
  }

  // Get referrals for a specific patient
  static Future<List<Referral>> getPatientReferrals(int patientId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/referrals/patient/$patientId'),
        headers: await _userHeaders(),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          return data.map((item) => Referral.fromJson(item)).toList();
        }
      }
      
      // Handle error responses
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to fetch referrals');
      
    } catch (e) {
      debugPrint('Error fetching patient referrals: $e');
      throw Exception('Failed to fetch referrals: $e');
    }
  }

  // Get all referrals (admin only)
  static Future<List<Referral>> getAllReferrals() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/referrals'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          final List<dynamic> data = responseData['data'];
          return data.map((item) => Referral.fromJson(item)).toList();
        }
      }
      
      // Handle error responses
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to fetch all referrals');
      
    } catch (e) {
      debugPrint('Error fetching all referrals: $e');
      throw Exception('Failed to fetch referrals: $e');
    }
  }

  // Update referral status
  static Future<Referral?> updateReferralStatus(int referralId, String status) async {
    try {
      final response = await http.put(
        Uri.parse('$_baseUrl/referrals/$referralId/status'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'status': status,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['success'] == true) {
          // Return the updated referral data
          return Referral.fromJson({
            'id': referralId,
            'status': status,
            'updated_at': responseData['data']['updated_at'],
          });
        }
      }
      
      // Handle error responses
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to update referral status');
      
    } catch (e) {
      debugPrint('Error updating referral status: $e');
      throw Exception('Failed to update referral status: $e');
    }
  }

  // Delete a referral
  static Future<bool> deleteReferral(int referralId) async {
    try {
      final response = await http.delete(
        Uri.parse('$_baseUrl/referrals/$referralId'),
        headers: {
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        return responseData['success'] == true;
      }
      
      // Handle error responses
      final errorData = jsonDecode(response.body);
      throw Exception(errorData['message'] ?? 'Failed to delete referral');
      
    } catch (e) {
      debugPrint('Error deleting referral: $e');
      throw Exception('Failed to delete referral: $e');
    }
  }

  // Validate referral form data
  static String? validateReferralForm({
    required String referredTo,
    required String referralDate,
    required String referralNotes,
  }) {
    // Validate referred to
    if (referredTo.trim().isEmpty) {
      return 'Referred to field is required';
    }
    if (referredTo.trim().length < 3) {
      return 'Referred to must be at least 3 characters long';
    }

    // Validate referral date
    if (referralDate.trim().isEmpty) {
      return 'Referral date is required';
    }

    // Validate referral notes
    if (referralNotes.trim().isEmpty) {
      return 'Referral notes are required';
    }
    if (referralNotes.trim().length < 10) {
      return 'Referral notes must be at least 10 characters long';
    }
    if (referralNotes.trim().length > 1000) {
      return 'Referral notes must not exceed 1000 characters';
    }

    return null; // No validation errors
  }

  // Format referral status for display
  static String formatStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return 'Pending';
      case 'accepted':
        return 'Accepted';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  // Get status color
  static Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'accepted':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  // Get status background color
  static Color getStatusBackgroundColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange.withOpacity(0.1);
      case 'accepted':
        return Colors.blue.withOpacity(0.1);
      case 'completed':
        return Colors.green.withOpacity(0.1);
      case 'cancelled':
        return Colors.red.withOpacity(0.1);
      default:
        return Colors.grey.withOpacity(0.1);
    }
  }
}
