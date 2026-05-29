import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../services/service_config_service.dart';
import '../../services/websocket_service.dart';
import '../../services/appointment_slot_service.dart';
import '../../models/service_model.dart';
import '../../utils/message_utils.dart';
import 'slot_details_modal.dart';

class EnhancedSlotManagementCalendar extends StatefulWidget {
  final Function()? onSlotsUpdated;
  final Function(DateTime)? onDateSelected;
  final int refreshTrigger;

  const EnhancedSlotManagementCalendar({
    super.key,
    this.onSlotsUpdated,
    this.onDateSelected,
    this.refreshTrigger = 0,
  });

  @override
  State<EnhancedSlotManagementCalendar> createState() =>
      _EnhancedSlotManagementCalendarState();

  // Static method to create a GlobalKey for this widget
  static GlobalKey<_EnhancedSlotManagementCalendarState> createGlobalKey() {
    return GlobalKey<_EnhancedSlotManagementCalendarState>();
  }
}

class _EnhancedSlotManagementCalendarState extends State<EnhancedSlotManagementCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<ServiceModel> _services = [];
  int? _selectedServiceId;
  
  // Slot data
  Map<DateTime, List<Map<String, dynamic>>> _slotEvents = {};
  bool _isLoadingSlots = false;
  
  @override
  void initState() {
    super.initState();
    // Normalize dates to ensure consistent handling
    _focusedDay = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day).add(const Duration(days: 1)); // Start from tomorrow
    _selectedDay = _focusedDay;
    
    // Add listener for slot updates
    WebSocketService.instance.addSlotsUpdatedListener(_handleSlotsUpdated);
    
    _loadServices();
    _loadSlotsForMonth(_focusedDay);
  }
  
  @override
  void dispose() {
    // Remove listener when disposing
    WebSocketService.instance.removeSlotsUpdatedListener(_handleSlotsUpdated);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant EnhancedSlotManagementCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTrigger != widget.refreshTrigger) {
      _loadSlotsForMonth(_focusedDay);
    }
  }
  
  // Public method to manually refresh slots
  Future<void> refreshSlots() async {
    if (_selectedServiceId != null) {
      await _loadSlotsForMonth(_focusedDay);
    }
  }
  
  // Check if slots already exist for a given date and service
  Future<bool> _checkSlotsExistForDate(DateTime date, int serviceId) async {
    try {
      final dateString = "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
      
      final slots = await AppointmentSlotService.getAllSlots(
        serviceId: serviceId,
        date: dateString,
      );
      
      return slots.isNotEmpty;
    } catch (e) {
      print('Error checking if slots exist: $e');
      return false; // Assume no slots exist if there's an error
    }
  }
  
  // Method to create slots with duplicate prevention
  Future<Map<String, dynamic>> createSlotsWithValidation({
    required int serviceId,
    required String appointmentDate,
    required String startTime,
    required String endTime,
    int slotDurationMinutes = 30,
    int maxPatients = 10,
    bool generateSlots = false,
  }) async {
    try {
      // Parse the appointment date string to a DateTime object without timezone conversion
      final dateParts = appointmentDate.split('-');
      DateTime date;
      if (dateParts.length == 3) {
        final year = int.parse(dateParts[0]);
        final month = int.parse(dateParts[1]);
        final day = int.parse(dateParts[2]);
        date = DateTime(year, month, day);
      } else {
        // If date format is invalid, throw an exception
        throw FormatException('Invalid date format: $appointmentDate');
      }
      
      // Check if slots already exist for this date and service
      final slotsAlreadyExist = await _checkSlotsExistForDate(date, serviceId);
      
      if (slotsAlreadyExist) {
        return {
          'success': false,
          'message': 'Slots already exist for this date',
        };
      }
      
      // If no slots exist, proceed with creation
      final result = await AppointmentSlotService.createSlot(
        serviceId: serviceId,
        appointmentDate: appointmentDate,
        startTime: startTime,
        endTime: endTime,
        slotDurationMinutes: slotDurationMinutes,
        maxPatients: maxPatients,
        generateSlots: generateSlots,
      );
      
      return result;
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating slots: $e',
      };
    }
  }
  
  // Helper method to parse boolean values from various types
  bool _parseBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      return lower == 'true' || lower == '1' || lower == 'yes' || lower == 'on';
    }
    return defaultValue;
  }
  
  // Handle slot updates from WebSocket
  void _handleSlotsUpdated() {
    print('🔄 Admin: Received slots updated event');
    // Reload slots for the current view with a slight delay to ensure DB is updated
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _loadSlotsForMonth(_focusedDay);
          widget.onSlotsUpdated?.call(); // Trigger parent callback if provided
          setState(() {}); // Force rebuild to update calendar display
          print('📅 Admin: Slots updated, calendar view refreshed');
        }
      });
    }
  }

  // Public method to force refresh calendar data
  Future<void> forceRefresh() async {
    print('🔄 Admin: Force refreshing calendar data');
    await _loadSlotsForMonth(_focusedDay);
    setState(() {});
  }

  Future<void> _loadSlotsForMonth(DateTime month) async {
    if (_selectedServiceId == null) return;
    
    print('🔄 Admin: Loading slots for month: ${month.year}-${month.month}, service: $_selectedServiceId');
    
    try {
      setState(() {
        _isLoadingSlots = true;
      });

      // Calculate first and last day of the month
      final firstDay = DateTime(month.year, month.month, 1);
      final lastDay = DateTime(month.year, month.month + 1, 0);
      
      print('📅 Admin: Month range: $firstDay to $lastDay');
      
      // Load all available slots for the service
      final slots = await AppointmentSlotService.getAllSlots(
        serviceId: _selectedServiceId,
      );
      
      print('📥 Admin: Received ${slots.length} slots from backend');
      
      // Group available slots by date, but only for the current month and future dates
      final newSlotEvents = <DateTime, List<Map<String, dynamic>>>{};
      
      // Define today's date for comparison (normalized to date only)
      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      
      for (var slot in slots) {
        try {
          final dateStr = slot['appointment_date'] as String;
          // Parse date string without timezone conversion to avoid shifting
          final dateParts = dateStr.split('-');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final monthNum = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            final date = DateTime(year, monthNum, day);
          
          // Only include slots from the current month and future dates (starting from tomorrow)
          if (date.year == _focusedDay.year && date.month == _focusedDay.month && date.isAfter(today)) {
            if (newSlotEvents.containsKey(date)) {
              newSlotEvents[date]!.add(slot);
            } else {
              newSlotEvents[date] = [slot];
            }
            print('➕ Admin: Adding slot for date: $date');
          }
        }
      } catch (e) {
        print("Error parsing date for slot: $e");
      }
      }
      
      print('📊 Admin: Grouped slots by date: ${newSlotEvents.keys.length} dates with slots');
      
      if (!mounted) return;
      
      setState(() {
        _slotEvents = newSlotEvents;
        _isLoadingSlots = false;
      });
      
      print('✅ Admin: Slots loading complete');
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoadingSlots = false;
      });
      print('❌ Admin: Error loading slots: $e');
    }
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        // Reserved for service fetch state
      });

      final services = await ServiceConfigService.getAllServices();
      final serviceModels = services.map((s) => ServiceModel.fromJson(s)).toList();
      
      // Filter to only include Maternal Care and Immunization services
      final filteredServices = serviceModels.where((service) => 
        service.serviceName == 'Maternal Care' || 
        service.serviceName == 'Immunization'
      ).toList();

      if (mounted) {
        setState(() {
          _services = filteredServices;
          
          // Auto-select first service if none selected
          if (_selectedServiceId == null && _services.isNotEmpty) {
            _selectedServiceId = _services.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Reserved for service fetch state
        });
        MessageUtils.showErrorMessage(context, "Failed to load services: $e");
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Normalize dates for consistent comparison
    final normalizedSelectedDay = DateTime(selectedDay.year, selectedDay.month, selectedDay.day);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    
    // Prevent selection of past dates
    if (normalizedSelectedDay.isBefore(today)) {
      MessageUtils.showErrorMessage(context, "Cannot select past dates");
      return;
    }
    
    // If it's today, check if business hours have passed
    if (isSameDay(normalizedSelectedDay, today)) {
      final businessEndTime = TimeOfDay(hour: 17, minute: 0); // 5:00 PM business end time
      final currentTime = TimeOfDay.fromDateTime(DateTime.now());
      
      if (currentTime.hour > businessEndTime.hour || 
          (currentTime.hour == businessEndTime.hour && currentTime.minute >= businessEndTime.minute)) {
        MessageUtils.showErrorMessage(context, "Cannot select today after business hours");
        return;
      }
    }
    
    setState(() {
      _selectedDay = normalizedSelectedDay;
      _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
    });
    
    // Check if there are slots for this date and show the modal
    final slotsForDate = _slotEvents[normalizedSelectedDay] ?? [];
    if (slotsForDate.isNotEmpty) {
      // Show slot details modal
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SlotDetailsModal(
            selectedDate: normalizedSelectedDay,
            slots: slotsForDate,
            serviceId: _selectedServiceId,
            onSlotsUpdated: () {
              // Refresh slots for the current month to reflect changes
              _loadSlotsForMonth(_focusedDay);
            },
          );
        },
      );
    } else {
      // No slots, proceed with configuration
      widget.onDateSelected?.call(selectedDay);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Service selector at the top
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                const Icon(Icons.business, color: Colors.blue, size: 20),
                const SizedBox(width: 8),
                const Text(
                  "Service: ",
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.blue,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedServiceId,
                      underline: const SizedBox(),
                      items: _services.map((service) {
                        return DropdownMenuItem(
                          value: service.id,
                          child: Row(
                            children: [
                              Icon(
                                service.serviceName == 'Maternal Care' 
                                  ? Icons.pregnant_woman 
                                  : Icons.vaccines,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 8),
                              Text(service.serviceName),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedServiceId = value;
                        });
                        // Reload slots for the selected service
                        _loadSlotsForMonth(_focusedDay);
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Calendar
          Stack(
            children: [
              TableCalendar(
                firstDay: DateTime.now(), // Allow today and future dates
                lastDay: DateTime.now().add(const Duration(days: 365)),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                eventLoader: (day) {
                  // Normalize the calendar day to match the format used for grouping slots
                  final normalizedDay = DateTime(day.year, day.month, day.day);
                  return _slotEvents[normalizedDay] ?? [];
                },
                calendarStyle: CalendarStyle(
              // Style for default days
              defaultDecoration: const BoxDecoration(shape: BoxShape.rectangle),
              weekendDecoration: BoxDecoration(shape: BoxShape.rectangle),
              // Style for today
              todayDecoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.orange.shade300, width: 1.5),
              ),
              // Style for selected day
              selectedDecoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
                border: Border.all(color: Theme.of(context).primaryColorDark, width: 1.5),
              ),
              // Style for weekend days
              weekendTextStyle: const TextStyle().copyWith(
                color: Colors.red.shade400,
              ),
              // Text styles
              defaultTextStyle: const TextStyle().copyWith(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
              todayTextStyle: const TextStyle().copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              selectedTextStyle: const TextStyle().copyWith(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
                // Custom calendar builders for markers
                calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                if (events.isEmpty) {
                  return const SizedBox.shrink();
                }
                
                // Calculate slot status more accurately
                int totalSlots = 0;
                int availableSlots = 0;
                int fullyBookedSlots = 0;
                int unavailableSlots = 0;
                
                for (var event in events) {
                  if (event is Map<String, dynamic>) {
                    final bookedPatients = event['booked_patients'] as int? ?? 0;
                    final isAvailable = _parseBool(event['is_available'], true);
                    
                    totalSlots++;
                    
                    if (!isAvailable) {
                      unavailableSlots++;
                    } else if (bookedPatients >= 1) {
                      fullyBookedSlots++;
                    } else {
                      availableSlots++;
                    }
                    
                  }
                }
                
                // Determine the status of the date based on slot states - return boolean expressions
                final hasAvailableSlots = availableSlots > 0;
                final isFullyBooked = fullyBookedSlots > 0 || (unavailableSlots > 0 && totalSlots == unavailableSlots);
                final hasSlots = totalSlots > 0;
                
                // Return appropriate widget based on boolean conditions
                if (hasAvailableSlots) {
                  // If there are available slots, show green indicator with count of available slots
                  return Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.green.shade500, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$availableSlots',
                      style: const TextStyle(
                        color: Colors.green,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                } else if (isFullyBooked) {
                  // If all slots are fully booked or all are unavailable, show red indicator
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.shade400, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.block,
                      size: 6,
                      color: Colors.red.shade600,
                    ),
                  );
                } else if (hasSlots) {
                  // If there are slots but they're neither available nor fully booked, show orange indicator
                  return Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.orange.shade100,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.orange.shade400, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      Icons.timelapse,
                      size: 6,
                      color: Colors.orange.shade600,
                    ),
                  );
                }
                
                return const SizedBox.shrink();
              },
            ),
                headerStyle: HeaderStyle(
                  formatButtonVisible: false,
                  titleCentered: true,
                  leftChevronIcon: Icon(Icons.chevron_left, size: 28, color: Theme.of(context).primaryColor),
                  rightChevronIcon: Icon(Icons.chevron_right, size: 28, color: Theme.of(context).primaryColor),
                  titleTextStyle: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                onDaySelected: _onDaySelected,
                onPageChanged: (focusedDay) {
                  setState(() {
                    // Normalize focused day to ensure consistent date handling
                    _focusedDay = DateTime(focusedDay.year, focusedDay.month, focusedDay.day);
                  });
                  
                  // Preload slots for the new month
                  _loadSlotsForMonth(_focusedDay);
                },
              ),
              if (_isLoadingSlots)
                const Positioned(
                  top: 8,
                  right: 8,
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
          
          // Legend
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                // Available indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade500, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Available', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                // Fully Booked indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade400, width: 1.5),
                      ),
                      child: Icon(
                        Icons.block,
                        size: 6,
                        color: Colors.red.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Fully Booked', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                // Partially Booked indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange.shade400, width: 1.5),
                      ),
                      child: Icon(
                        Icons.timelapse,
                        size: 6,
                        color: Colors.orange.shade600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Partially Booked', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                // Today indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.orange.shade300, width: 1.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Today', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
                // Selected indicator
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text('Selected', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}