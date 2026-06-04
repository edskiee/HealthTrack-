import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/user_session.dart';
import '../services/api_config.dart';
import '../services/user_session_storage.dart';

class Reminder {
  final int id;
  final int userId;
  final String title;
  final String? category;
  final DateTime reminderDate;
  final String? reminderTime;
  final bool isRepeating;
  final String? repeatInterval;
  final List<String>? repeatDays;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Reminder({
    required this.id,
    required this.userId,
    required this.title,
    this.category,
    required this.reminderDate,
    this.reminderTime,
    required this.isRepeating,
    this.repeatInterval,
    this.repeatDays,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Reminder.fromJson(Map<String, dynamic> json) {
    List<String>? repeatDaysList;
    if (json['repeat_days'] != null) {
      try {
        repeatDaysList = List<String>.from(jsonDecode(json['repeat_days']));
      } catch (e) {
        // Handle parsing error
        repeatDaysList = null;
      }
    }
    
    return Reminder(
      id: json['id'],
      userId: json['user_id'],
      title: json['title'],
      category: json['category'],
      reminderDate: DateTime.parse(json['reminder_date']),
      reminderTime: json['reminder_time'],
      isRepeating: json['is_repeating'] == 1,
      repeatInterval: json['repeat_interval'],
      repeatDays: repeatDaysList,
      notes: json['notes'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'title': title,
      'category': category,
      'reminder_date': reminderDate.toIso8601String().split('T')[0],
      'reminder_time': reminderTime,
      'is_repeating': isRepeating,
      'repeat_interval': repeatInterval,
      'repeat_days': repeatDays != null ? jsonEncode(repeatDays) : null,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class ReminderService {
  static const String _basePath = '/reminders';

  static Future<Map<String, String>> _authHeaders() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Future<List<Reminder>> getUserReminders() async {
    final userSession = UserSession.instance;
    if (!userSession.isLoggedIn) {
      throw Exception('User not logged in');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$_basePath/user/${userSession.userId}');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        final List remindersData = data['data'];
        return remindersData.map((reminder) => Reminder.fromJson(reminder)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch reminders');
      }
    } else {
      throw Exception('Failed to fetch reminders: ${response.statusCode}');
    }
  }

  static Future<List<Reminder>> getDateReminders(DateTime date) async {
    final userSession = UserSession.instance;
    if (!userSession.isLoggedIn) {
      throw Exception('User not logged in');
    }

    final dateString = date.toIso8601String().split('T')[0];
    final url = Uri.parse('${ApiConfig.baseUrl}$_basePath/user/${userSession.userId}/date/$dateString');
    final response = await http.get(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success']) {
        final List remindersData = data['data'];
        return remindersData.map((reminder) => Reminder.fromJson(reminder)).toList();
      } else {
        throw Exception(data['message'] ?? 'Failed to fetch reminders for date');
      }
    } else {
      throw Exception('Failed to fetch reminders for date: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> createReminder({
    required String title,
    String? category,
    required DateTime reminderDate,
    String? reminderTime,
    bool isRepeating = false,
    String? repeatInterval,
    List<String>? repeatDays,
    String? notes,
  }) async {
    final userSession = UserSession.instance;
    if (!userSession.isLoggedIn) {
      throw Exception('User not logged in');
    }

    final url = Uri.parse('${ApiConfig.baseUrl}$_basePath/user/${userSession.userId}');
    
    final body = json.encode({
      'title': title,
      'category': category,
      'reminderDate': reminderDate.toIso8601String().split('T')[0],
      'reminderTime': reminderTime,
      'isRepeating': isRepeating,
      'repeatInterval': repeatInterval,
      'repeatDays': repeatDays,
      'notes': notes,
    });

    final response = await http.post(
      url,
      headers: await _authHeaders(),
      body: body,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to create reminder: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> updateReminder({
    required int reminderId,
    String? title,
    String? category,
    DateTime? reminderDate,
    String? reminderTime,
    bool? isRepeating,
    String? repeatInterval,
    List<String>? repeatDays,
    String? notes,
  }) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$_basePath/$reminderId');
    
    final body = json.encode({
      if (title != null) 'title': title,
      if (category != null) 'category': category,
      if (reminderDate != null) 'reminderDate': reminderDate.toIso8601String().split('T')[0],
      if (reminderTime != null) 'reminderTime': reminderTime,
      if (isRepeating != null) 'isRepeating': isRepeating,
      if (repeatInterval != null) 'repeatInterval': repeatInterval,
      if (repeatDays != null) 'repeatDays': repeatDays,
      if (notes != null) 'notes': notes,
    });

    final response = await http.put(
      url,
      headers: await _authHeaders(),
      body: body,
    );

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to update reminder: ${response.statusCode}');
    }
  }

  static Future<Map<String, dynamic>> deleteReminder(int reminderId) async {
    final url = Uri.parse('${ApiConfig.baseUrl}$_basePath/$reminderId');
    final response = await http.delete(url, headers: await _authHeaders());

    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to delete reminder: ${response.statusCode}');
    }
  }
}