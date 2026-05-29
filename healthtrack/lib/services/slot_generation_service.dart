import 'dart:math';
import 'package:intl/intl.dart';

class SlotGenerationService {
  /// Generates time slots based on start time, end time, and interval
  /// 
  /// Parameters:
  /// - startTime: Start time in HH:MM:SS format
  /// - endTime: End time in HH:MM:SS format
  /// - intervalMinutes: Interval between slots in minutes
  /// - maxPatientsPerSlot: Maximum number of patients per slot
  /// 
  /// Returns a list of slot objects with start_time, end_time, max_patients
  static List<Map<String, dynamic>> generateTimeSlots({
    required String startTime,
    required String endTime,
    required int intervalMinutes,
    required int maxPatientsPerSlot,
  }) {
    final slots = <Map<String, dynamic>>[];
    
    // Parse start and end times
    final start = _parseTime(startTime);
    final end = _parseTime(endTime);
    
    if (start == null || end == null) {
      throw Exception('Invalid time format. Expected HH:MM:SS');
    }
    
    // Generate slots
    DateTime current = start;
    while (current.isBefore(end)) {
      // Calculate end time for this slot
      final slotEnd = current.add(Duration(minutes: intervalMinutes));
      
      // Make sure we don't go beyond the end time
      if (slotEnd.isAfter(end)) {
        break;
      }
      
      // Format times back to string
      final startTimeStr = _formatTime(current);
      final endTimeStr = _formatTime(slotEnd);
      
      slots.add({
        'start_time': startTimeStr,
        'end_time': endTimeStr,
        'max_patients': maxPatientsPerSlot,
      });
      
      // Move to next slot
      current = slotEnd.add(Duration(minutes: 10)); // 10-minute break between slots
    }
    
    return slots;
  }
  
  /// Parses a time string in HH:MM:SS format to DateTime (using today's date)
  static DateTime? _parseTime(String timeString) {
    try {
      final format = DateFormat.Hms(); // HH:mm:ss
      final today = DateTime.now();
      final parsedTime = format.parse(timeString);
      return DateTime(today.year, today.month, today.day, 
          parsedTime.hour, parsedTime.minute, parsedTime.second);
    } catch (e) {
      return null;
    }
  }
  
  /// Formats a DateTime to HH:MM:SS string
  static String _formatTime(DateTime time) {
    return DateFormat.Hms().format(time); // HH:mm:ss
  }
  
  /// Generates multiple slots for a date range
  static List<Map<String, dynamic>> generateSlotsForDateRange({
    required DateTime startDate,
    required DateTime endDate,
    required String startTime,
    required String endTime,
    required int intervalMinutes,
    required int maxPatientsPerSlot,
  }) {
    final allSlots = <Map<String, dynamic>>[];
    
    // Iterate through each day in the date range
    DateTime currentDate = DateTime(startDate.year, startDate.month, startDate.day);
    final endDateNormalized = DateTime(endDate.year, endDate.month, endDate.day);
    
    while (!currentDate.isAfter(endDateNormalized)) {
      // Generate slots for this date
      final dailySlots = generateTimeSlots(
        startTime: startTime,
        endTime: endTime,
        intervalMinutes: intervalMinutes,
        maxPatientsPerSlot: maxPatientsPerSlot,
      );
      
      // Add date to each slot
      for (var slot in dailySlots) {
        allSlots.add({
          'date': DateFormat('yyyy-MM-dd').format(currentDate),
          'start_time': slot['start_time'],
          'end_time': slot['end_time'],
          'max_patients': slot['max_patients'],
        });
      }
      
      // Move to next day
      currentDate = currentDate.add(const Duration(days: 1));
    }
    
    return allSlots;
  }
}