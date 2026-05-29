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

  const EnhancedSlotManagementCalendar({super.key, this.onSlotsUpdated, this.onDateSelected});

  @override
  State<EnhancedSlotManagementCalendar> createState() =>
      _EnhancedSlotManagementCalendarState();
}

class _EnhancedSlotManagementCalendarState extends State<EnhancedSlotManagementCalendar> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  List<ServiceModel> _services = [];
  int? _selectedServiceId;
  bool _isLoading = false;
  
  // Slot data
  Map<DateTime, List<Map<String, dynamic>>> _slotEvents = {};
  bool _isLoadingSlots = false;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now().add(const Duration(days: 1)); // Start from tomorrow
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
  
  // Handle slot updates from WebSocket
  void _handleSlotsUpdated() {
    print('🔄 Admin: Received slots updated event');
    // Reload slots for the current view with a slight delay to ensure DB is updated
    if (mounted) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadSlotsForMonth(_focusedDay);
          print('📅 Admin: Slots updated, calendar view refreshed');
        }
      });
    }
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
      
      for (var slot in slots) {
        try {
          final dateStr = slot['appointment_date'] as String;
          final date = DateTime.parse(dateStr);
          
          // Only include slots from the current month and future dates (starting from tomorrow)
          if (date.year == month.year && date.month == month.month && date.isAfter(DateTime.now())) {
            if (newSlotEvents.containsKey(date)) {
              newSlotEvents[date]!.add(slot);
            } else {
              newSlotEvents[date] = [slot];
            }
            print('➕ Admin: Adding slot for date: $date');
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
        _isLoading = true;
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
          _isLoading = false;
          
          // Auto-select first service if none selected
          if (_selectedServiceId == null && _services.isNotEmpty) {
            _selectedServiceId = _services.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        MessageUtils.showErrorMessage(context, "Failed to load services: $e");
      }
    }
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    // Prevent selection of past dates
    final now = DateTime.now();
    if (selectedDay.isBefore(DateTime(now.year, now.month, now.day))) {
      MessageUtils.showErrorMessage(context, "Cannot select past dates");
      return;
    }
    
    // If it's today, check if business hours have passed
    if (isSameDay(selectedDay, now)) {
      final businessEndTime = TimeOfDay(hour: 17, minute: 0); // 5:00 PM business end time
      final currentTime = TimeOfDay.fromDateTime(now);
      
      if (currentTime.hour > businessEndTime.hour || 
          (currentTime.hour == businessEndTime.hour && currentTime.minute >= businessEndTime.minute)) {
        MessageUtils.showErrorMessage(context, "Cannot select today after business hours");
        return;
      }
    }
    
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
    });
    
    // Call the onDateSelected callback if provided
    widget.onDateSelected?.call(selectedDay);
    
    // Check if there are slots for this date and show the modal
    final slotsForDate = _slotEvents[selectedDay] ?? [];
    if (slotsForDate.isNotEmpty) {
      // Show slot details modal
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return SlotDetailsModal(
            selectedDate: selectedDay,
            slots: slotsForDate,
            serviceId: _selectedServiceId,
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
          TableCalendar(
            firstDay: DateTime.now(), // Allow today and future dates
            lastDay: DateTime.now().add(const Duration(days: 365)),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.monday,
            eventLoader: (day) => _slotEvents[day] ?? [],
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
                
                // Calculate remaining slots
                int totalSlots = 0;
                int bookedSlots = 0;
                bool hasAvailableSlot = false;
                
                for (var event in events) {
                  if (event is Map<String, dynamic>) {
                    final maxPatients = event['max_patients'] as int? ?? 0;
                    final bookedPatients = event['booked_patients'] as int? ?? 0;
                    final isAvailable = event['is_available'] as bool? ?? true;
                    
                    totalSlots += maxPatients;
                    bookedSlots += bookedPatients;
                    
                    // Check if there's at least one slot that's available
                    if (isAvailable && (maxPatients - bookedPatients) > 0) {
                      hasAvailableSlot = true;
                    }
                  }
                }
                
                final availableSlots = totalSlots - bookedSlots;
                
                // If all slots are booked or unavailable, show booked indicator
                if (availableSlots <= 0 && events.length > 0 && !hasAvailableSlot) {
                  // Show red indicator for fully booked dates
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
                }
                
                // If there are available slots, show green indicator
                if (availableSlots > 0 && hasAvailableSlot) {
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
                }
                
                // If there are slots but none are available, show orange indicator
                if (events.length > 0 && !hasAvailableSlot) {
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
                _focusedDay = focusedDay;
              });
              
              // Preload slots for the new month
              _loadSlotsForMonth(focusedDay);
            },
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
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.green.shade500, width: 1.5),
                      ),
                      child: const Center(
                        child: Text(
                          '2',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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