import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:healthtrack/services/reminder_service.dart';
import 'package:healthtrack/services/reminder_notification_service.dart';
import 'package:healthtrack/utils/message_utils.dart';
import 'package:healthtrack/utils/time_utils.dart';

// Enhanced Set Reminder Popup with improved design
class EnhancedSetReminderPopup extends StatefulWidget {
  final DateTime selectedDate;
  final Function()? onReminderSaved;

  const EnhancedSetReminderPopup({
    super.key,
    required this.selectedDate,
    this.onReminderSaved,
  });

  @override
  State<EnhancedSetReminderPopup> createState() => _EnhancedSetReminderPopupState();
}

class _EnhancedSetReminderPopupState extends State<EnhancedSetReminderPopup> {
  final TextEditingController _titleController = TextEditingController();
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;
  String? _selectedCategory;
  final TextEditingController _notesController = TextEditingController();
  List<String> _selectedRepeatDays = [];

  // Reminder categories based on notification types
  final List<Map<String, String>> _reminderCategories = [
    {'value': 'appointment_reminder', 'label': 'Appointment Reminder'},
    {'value': 'medication_reminder', 'label': 'Medication Reminder'},
    {'value': 'follow_up_reminder', 'label': 'Follow-up Reminder'},
    {'value': 'custom_reminder', 'label': 'Custom Reminder'},
  ];

  // Days of the week for repeat selection
  final List<String> _daysOfWeek = [
    'Everyday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.selectedDate;
    // Set default category
    _selectedCategory = _reminderCategories[0]['value'];
  }

  // Show the enhanced edit reminder popup
  void _showEditReminderPopup() {
    showDialog(
      context: context,
      barrierColor: Colors.black54, // 50% opacity gray background
      builder: (BuildContext context) {
        return EnhancedEditReminderPopup(
          selectedDate: _selectedDate,
          selectedTime: _selectedTime,
          onDateRangeSelected: (fromDate, toDate, time) {
            setState(() {
              _selectedDate = fromDate;
              _selectedTime = time;
            });
            Navigator.pop(context); // Close edit popup
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with edit icon above title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: _showEditReminderPopup,
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Title
            const Center(
              child: Text(
                "Set Reminder",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // Title input field
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: "Reminder Title",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Date display
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.blue),
                  const SizedBox(width: 10),
                  Text(
                    TimeUtils.formatDate(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // Category selection
            const Text(
              "Category",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  items: _reminderCategories.map((category) {
                    return DropdownMenuItem<String>(
                      value: category['value']!,
                      child: Text(category['label']!),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Repeat days selection
            const Text(
              "Repeat Days",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ..._daysOfWeek.map((day) {
                    return CheckboxListTile(
                      title: Text(day),
                      value: _selectedRepeatDays.contains(day),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            if (day == 'Everyday') {
                              // If "Everyday" is selected, clear other selections
                              _selectedRepeatDays = ['Everyday'];
                            } else {
                              // If a specific day is selected, remove "Everyday" if present
                              _selectedRepeatDays.remove('Everyday');
                              _selectedRepeatDays.add(day);
                            }
                          } else {
                            _selectedRepeatDays.remove(day);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Cancel button
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                
                // Save button
                ElevatedButton(
                  onPressed: () async {
                    if (_titleController.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(context, "Please enter a reminder title");
                      return;
                    }
                    
                    try {
                      await ReminderService.createReminder(
                        title: _titleController.text.trim(),
                        category: _selectedCategory,
                        reminderDate: _selectedDate,
                        reminderTime: _selectedTime != null 
                            ? "${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}"
                            : null,
                        isRepeating: _selectedRepeatDays.isNotEmpty,
                        repeatInterval: _selectedRepeatDays.isNotEmpty 
                            ? (_selectedRepeatDays.contains('Everyday') ? 'daily' : 'weekly')
                            : null,
                        repeatDays: _selectedRepeatDays.isNotEmpty ? _selectedRepeatDays : null,
                        notes: _notesController.text,
                      );

                      // Re-sync local scheduled notifications immediately to reflect the new reminder.
                      await ReminderNotificationService.syncSchedules();
                      
                      if (mounted) {
                        MessageUtils.showSuccessMessage(context, "Reminder saved successfully!");
                        widget.onReminderSaved?.call();
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      if (mounted) {
                        MessageUtils.showErrorMessage(context, "Failed to save reminder: $e");
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    "Save",
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Enhanced Edit Reminder Popup with date range picker
class EnhancedEditReminderPopup extends StatefulWidget {
  final DateTime selectedDate;
  final TimeOfDay? selectedTime;
  final Function(DateTime, DateTime, TimeOfDay?)? onDateRangeSelected;

  const EnhancedEditReminderPopup({
    super.key,
    required this.selectedDate,
    this.selectedTime,
    this.onDateRangeSelected,
  });

  @override
  State<EnhancedEditReminderPopup> createState() => _EnhancedEditReminderPopupState();
}

class _EnhancedEditReminderPopupState extends State<EnhancedEditReminderPopup> {
  late DateTime _fromDate;
  late DateTime _toDate;
  TimeOfDay? _selectedTime;
  List<String> _selectedRepeatDays = [];

  // Days of the week for repeat selection
  final List<String> _daysOfWeek = [
    'Everyday',
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday'
  ];

  @override
  void initState() {
    super.initState();
    _fromDate = widget.selectedDate;
    _toDate = widget.selectedDate;
    _selectedTime = widget.selectedTime;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Center(
              child: Text(
                "Select Date Range",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            // From date picker
            const Text(
              "From",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _fromDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _fromDate = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      DateFormat('MMMM dd, yyyy').format(_fromDate),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // To date picker
            const Text(
              "To",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _toDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _toDate = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      TimeUtils.formatDate(_toDate),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Time picker
            const Text(
              "Time",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime ?? TimeOfDay.now(),
                );
                if (picked != null && mounted) {
                  setState(() {
                    _selectedTime = picked;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.blue),
                    const SizedBox(width: 10),
                    Text(
                      _selectedTime != null ? TimeUtils.formatTime12Hour(DateTime(2023, 1, 1, _selectedTime!.hour, _selectedTime!.minute)) : "Select time",
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.black,
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 15),
            
            // Repeat selection
            const Text(
              "Repeat",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ..._daysOfWeek.map((day) {
                    return CheckboxListTile(
                      title: Text(day),
                      value: _selectedRepeatDays.contains(day),
                      onChanged: (bool? value) {
                        setState(() {
                          if (value == true) {
                            if (day == 'Everyday') {
                              // If "Everyday" is selected, clear other selections
                              _selectedRepeatDays = ['Everyday'];
                            } else {
                              // If a specific day is selected, remove "Everyday" if present
                              _selectedRepeatDays.remove('Everyday');
                              _selectedRepeatDays.add(day);
                            }
                          } else {
                            _selectedRepeatDays.remove(day);
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 15),
            
            // Set button
            Center(
              child: ElevatedButton(
                onPressed: () {
                  widget.onDateRangeSelected?.call(_fromDate, _toDate, _selectedTime);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  "Set",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}