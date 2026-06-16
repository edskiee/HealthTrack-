import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'services/appointment_service.dart';
import 'services/appointment_slot_service.dart';
import 'services/service_config_service.dart';
import 'services/connection_status_service.dart';
import 'services/user_session.dart';
import 'services/websocket_service.dart';
import 'services/appointment_reminder_service.dart';
import 'utils/message_utils.dart';
import 'utils/time_utils.dart';
import 'models/service_model.dart';

class AppointmentTab extends StatefulWidget {
  const AppointmentTab({super.key});

  @override
  State<AppointmentTab> createState() => _AppointmentTabState();
}

class _AppointmentTabState extends State<AppointmentTab> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;
  final ScrollController _scrollController = ScrollController();

  // Service selection state
  List<ServiceModel> _services = [];
  int? _selectedServiceId;
  
  // Time slot booking state
  Map<String, List<Map<String, dynamic>>> _groupedSlots = {};
  List<DateTime> _availableDates = [];
  Map<String, dynamic>? _selectedSlot;
  bool _isLoadingServices = false;
  bool _isLoadingSlots = false;
  bool _isBooking = false;
  String _errorMessage = '';

  // Appointment history state
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    
    // Initialize WebSocket connection and add listener for slot updates
    _initializeWebSocket();
    
    // Initialize appointment reminder notifications
    _initializeAppointmentReminders();
    
    _loadServices();
    _loadAppointments();
    _loadAvailableSlots();
  }
  
  // Initialize WebSocket connection with error handling
  Future<void> _initializeWebSocket() async {
    try {
      await WebSocketService.instance.initialize();
      WebSocketService.instance.addSlotsUpdatedListener(_handleSlotsUpdated);
      
      // Join user room if logged in
      final userSession = UserSession.instance;
      if (userSession.isLoggedIn) {
        WebSocketService.instance.joinUserRoom(int.tryParse(userSession.userId) ?? 0);
      }
      
      print('🔌 User: WebSocket initialized and listening for slot updates');
    } catch (e) {
      print('❌ User: Failed to initialize WebSocket: $e');
      // Continue without WebSocket - app will still work with manual refresh
    }
  }
  
  @override
  void dispose() {
    // Remove listener when disposing
    WebSocketService.instance.removeSlotsUpdatedListener(_handleSlotsUpdated);
    
    // Leave user room if logged in
    final userSession = UserSession.instance;
    if (userSession.isLoggedIn) {
      WebSocketService.instance.leaveUserRoom(int.tryParse(userSession.userId) ?? 0);
    }
    
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Handle slot updates from WebSocket with enhanced feedback
  void _handleSlotsUpdated() {
    print('🔄 User: Received slots updated event');
    // Reload slots for the current view immediately
    if (mounted) {
      _loadAvailableSlots();
      print('📅 User: Slots updated, refreshing view');
      
      // Only show snackbar if user is actively viewing slots
      if (_currentPageIndex == 0 && !_isLoadingSlots) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.sync, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Appointment slots updated in real-time',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            action: SnackBarAction(
              label: 'Refresh',
              textColor: Colors.white,
              onPressed: () {
                _loadAvailableSlots();
              },
            ),
          ),
        );
      }
    }
  }

  // Initialize appointment reminder notifications
  Future<void> _initializeAppointmentReminders() async {
    try {
      print('🔔 Initializing appointment reminder notifications...');
      await AppointmentReminderService().initializeNotificationCheck();
    } catch (e) {
      print('❌ Error initializing appointment reminders: $e');
      // Continue without reminders - app will still work
    }
  }

  // Helper method to get selected service name
  String _getSelectedServiceName() {
    if (_selectedServiceId == null) return 'Unknown Service';
    
    final selectedService = _services.firstWhere(
      (service) => service.id == _selectedServiceId,
      orElse: () => ServiceModel(
        id: _selectedServiceId,
        serviceName: 'Unknown Service',
        serviceType: 'general',
      ),
    );
    
    return selectedService.serviceName;
  }

  Future<void> _loadServices() async {
    try {
      setState(() {
        _isLoadingServices = true;
        _errorMessage = '';
      });

      final services = await ServiceConfigService.getAllServices();
      
      if (!mounted) return;
      
      // Filter to only include Maternal Care and Immunization services
      final filteredServices = services
          .map((s) => ServiceModel.fromJson(s))
          .where((service) => 
              service.serviceName == 'Maternal Care' || 
              service.serviceName == 'Immunization')
          .toList();
      
      setState(() {
        _services = filteredServices;
        _isLoadingServices = false;
        
        // Auto-select first service if none selected
        if (_selectedServiceId == null && _services.isNotEmpty) {
          _selectedServiceId = _services.first.id;
          // Reload slots for the selected service
          _loadAvailableSlots();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ConnectionStatusService.friendlyError(e);
          _isLoadingServices = false;
        });
        MessageUtils.showNetworkError(context, e);
      }
    }
  }

  Future<void> _loadAppointments() async {
    setState(() {
      _isLoadingAppointments = true;
      _errorMessage = '';
    });

    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        throw Exception("User not logged in");
      }

      // Load all appointment history statuses
      final allAppointments = await AppointmentService.getUserAppointments(userSession.userId);
      final historyAppointments = allAppointments.where((appt) {
        final status = (appt["status"] ?? "").toString().toLowerCase();
        return status == "approved" ||
               status == "rescheduled" ||
               status == "completed" ||
               status == "no_show" ||
               status == "cancelled";
      }).toList();

      // Sort by created_at descending (newest first)
      historyAppointments.sort((a, b) =>
          (b["created_at"]?.toString() ?? "")
              .compareTo(a["created_at"]?.toString() ?? ""));

      if (mounted) {
        setState(() {
          _appointments = historyAppointments;
          _isLoadingAppointments = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = ConnectionStatusService.friendlyError(e);
          _isLoadingAppointments = false;
        });
        MessageUtils.showNetworkError(context, e);
      }
    }
  }

  Future<void> _loadAvailableSlots() async {
    if (_selectedServiceId == null) return;
    
    print('🔄 User: Loading available slots for service: $_selectedServiceId');
    
    try {
      setState(() {
        _isLoadingSlots = true;
      });

      // Get all slots for the service (including booked ones)
      final allSlots = await AppointmentSlotService.getUserViewableSlots(
       serviceId: _selectedServiceId,
     );
      
      print('📥 User: Received ${allSlots.length} total slots');
      
      // Group slots by date and filter for future dates
      final newGroupedSlots = <String, List<Map<String, dynamic>>>{};
      final newAvailableDates = <DateTime>[];
      
      for (var slot in allSlots) {
        try {
          final dateStr = slot['appointment_date'] as String;
          final dateParts = dateStr.split('-');
          if (dateParts.length == 3) {
            final year = int.parse(dateParts[0]);
            final monthNum = int.parse(dateParts[1]);
            final day = int.parse(dateParts[2]);
            final date = DateTime(year, monthNum, day);
          
          // Only include future dates (starting from tomorrow)
          if (date.isAfter(DateTime.now().subtract(const Duration(days: 1)))) {
            // Include all slots (both available and booked)
            if (!newGroupedSlots.containsKey(dateStr)) {
              newGroupedSlots[dateStr] = [];
              newAvailableDates.add(date);
            }
            // Add slot with server-calculated availability
            // The server returns `is_user_available` which correctly accounts for
            // booked_count >= capacity and is_available flag.
            final enhancedSlot = Map<String, dynamic>.from(slot);
            final serverAvailable = slot['is_user_available'] == 1 ||
                slot['is_user_available'] == true;
            // Fallback: recalculate if server field missing
            final bookedPatients = (slot['booked_patients'] ?? slot['booked_count'] ?? 0) as int? ?? 0;
            final maxPatients = (slot['max_patients'] ?? slot['capacity'] ?? 1) as int? ?? 1;
            final isAvailable = slot['is_available'] == 1 || slot['is_available'] == true;
            enhancedSlot['calculated_available'] = slot.containsKey('is_user_available')
                ? serverAvailable
                : (isAvailable && bookedPatients < maxPatients);
            newGroupedSlots[dateStr]!.add(enhancedSlot);
          }
        }
        } catch (e) {
          print("Error parsing slot date: $e");
        }
      }
      
      // Sort dates
      newAvailableDates.sort();
      
      // Sort slots within each date by start_time
      newGroupedSlots.forEach((date, slots) {
        slots.sort((a, b) {
          final timeA = a['start_time'] as String;
          final timeB = b['start_time'] as String;
          return timeA.compareTo(timeB);
        });
      });
      
      print('📊 User: Grouped ${newGroupedSlots.keys.length} dates with slots');
      
      if (!mounted) return;
      
      setState(() {
        _groupedSlots = newGroupedSlots;
        _availableDates = newAvailableDates;
        _isLoadingSlots = false;
      });
      
      print('✅ User: Slots loading complete');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSlots = false;
      });
      MessageUtils.showNetworkError(context, e);
    }
  }

  void _onSlotSelected(Map<String, dynamic> slot) {
    // Double-check availability before allowing selection
    final calculatedAvailable = slot['calculated_available'] as bool? ?? false;
    if (!calculatedAvailable) {
      MessageUtils.showErrorMessage(context, "This slot is no longer available");
      _loadAvailableSlots();
      return;
    }
    // Check if user already has an active approved appointment before showing dialog
    _checkActiveAppointmentThenBook(slot);
  }

  /// Checks for an existing approved/rescheduled appointment.
  /// Shows a blocking popup if one exists; otherwise shows the booking dialog.
  Future<void> _checkActiveAppointmentThenBook(Map<String, dynamic> slot) async {
    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        _showBookingConfirmationDialog(slot);
        return;
      }

      // Re-use already-loaded appointments list to avoid an extra network call
      final activeAppt = _appointments.firstWhere(
        (appt) {
          final status = (appt["status"] ?? "").toString().toLowerCase();
          return status == "approved" || status == "rescheduled";
        },
        orElse: () => {},
      );

      if (activeAppt.isNotEmpty) {
        // Format the date and time for the popup message
        final rawDate = activeAppt["appointment_date"]?.toString() ?? "";
        final rawTime = activeAppt["appointment_time"]?.toString() ?? "";
        String displayDate = rawDate;
        String displayTime = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;
        try {
          if (rawDate.isNotEmpty) {
            final parsed = DateTime.parse(rawDate);
            displayDate = DateFormat('MMMM d, yyyy').format(parsed);
          }
          // Convert 24h time to 12h
          if (rawTime.length >= 5) {
            final parts = rawTime.split(':');
            int hour = int.parse(parts[0]);
            final minute = parts[1];
            final period = hour >= 12 ? 'PM' : 'AM';
            if (hour > 12) hour -= 12;
            if (hour == 0) hour = 12;
            displayTime = '$hour:$minute $period';
          }
        } catch (_) {}

        if (!mounted) return;
        _showActiveAppointmentBlockedDialog(displayDate, displayTime);
        return;
      }

      // No active appointment — proceed to booking
      _showBookingConfirmationDialog(slot);
    } catch (_) {
      // On any error, allow booking (backend will double-check anyway)
      _showBookingConfirmationDialog(slot);
    }
  }

  /// Popup shown when the user already has an approved appointment.
  void _showActiveAppointmentBlockedDialog(String date, String time) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.event_busy, color: Colors.orange.shade700, size: 32),
        ),
        title: const Text(
          'Booking Not Allowed',
          textAlign: TextAlign.center,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You already have an approved appointment on $date at $time.',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please wait until your current appointment has been completed before creating a new booking request.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.black87, height: 1.4),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check, size: 16),
            label: const Text('Got it'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookingConfirmationDialog(Map<String, dynamic> slot) {
    final date = slot['appointment_date'] as String;
    final startTime = slot['start_time'] as String;
    final endTime = slot['end_time'] as String?;
    final slotDuration = slot['slot_duration_minutes'] as int? ?? 30;
    final formattedDate = DateFormat('EEEE, MMMM d, yyyy').format(
      DateTime.parse(date),
    );
    final formattedTimeRange = _formatTimeRange(startTime, endTime, slotDuration);
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              insetPadding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width < 360 ? 12 : 20,
                vertical: MediaQuery.of(context).size.height < 600 ? 20 : 40,
              ),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                padding: EdgeInsets.all(
                  MediaQuery.of(context).size.width < 360 ? 16 : 20,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: Colors.white,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with icon
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                            MediaQuery.of(context).size.width < 360 ? 8 : 10,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.calendar_month,
                            color: Theme.of(context).primaryColor,
                            size: MediaQuery.of(context).size.width < 360 ? 20 : 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Confirm Appointment',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 360 ? 16 : 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Please confirm your booking details',
                                style: TextStyle(
                                  fontSize: MediaQuery.of(context).size.width < 360 ? 12 : 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close),
                          color: Colors.grey[600],
                          iconSize: MediaQuery.of(context).size.width < 360 ? 20 : 24,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 36,
                            minHeight: 36,
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Appointment details
                    Container(
                      padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width < 360 ? 12 : 14,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildDialogInfoRow(
                            Icons.calendar_today,
                            'Date',
                            formattedDate,
                          ),
                          const SizedBox(height: 10),
                          _buildDialogInfoRow(
                            Icons.access_time,
                            'Time',
                            formattedTimeRange,
                          ),
                          const SizedBox(height: 10),
                          _buildDialogInfoRow(
                            Icons.medical_services,
                            'Service',
                            _getSelectedServiceName(),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 20),
                    
                    // Action buttons - using responsive layout
                    MediaQuery.of(context).size.width < 360
                        ? Column(
                            children: [
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: _isBooking ? null : () async {
                                    setState(() {
                                      _isBooking = true;
                                    });
                                    
                                    Navigator.of(context).pop();
                                    this.setState(() {
                                      _selectedSlot = slot;
                                    });
                                    await _bookAppointment();
                                    
                                    setState(() {
                                      _isBooking = false;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isBooking
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Booking...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'Book Appointment',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: Colors.grey[300]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: const Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: _isBooking ? null : () async {
                                    setState(() {
                                      _isBooking = true;
                                    });
                                    
                                    Navigator.of(context).pop();
                                    this.setState(() {
                                      _selectedSlot = slot;
                                    });
                                    await _bookAppointment();
                                    
                                    setState(() {
                                      _isBooking = false;
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Theme.of(context).primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    elevation: 2,
                                  ),
                                  child: _isBooking
                                      ? const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              width: 14,
                                              height: 14,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              'Booking...',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.check_circle, size: 16),
                                            SizedBox(width: 6),
                                            Text(
                                              'Book Appointment',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDialogInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(
            icon,
            size: 14,
            color: Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _bookAppointment() async {
    if (_selectedSlot == null) {
      MessageUtils.showErrorMessage(context, "Please select a time slot");
      return;
    }

    // Final availability check before booking
    final slotId = _selectedSlot!['id'] as int;
    final calculatedAvailable = _selectedSlot!['calculated_available'] as bool? ?? false;
    
    if (!calculatedAvailable) {
      MessageUtils.showErrorMessage(context, "This slot is no longer available. Please select another slot.");
      // Refresh slots to get current state
      _loadAvailableSlots();
      return;
    }

    setState(() {
      _isBooking = true;
    });

    try {
      final userSession = UserSession.instance;
      if (!userSession.isLoggedIn) {
        throw Exception("User not logged in");
      }

      // Step 1: Book the slot first (atomic operation)
      final bookResult = await AppointmentSlotService.bookSlot(slotId);
      
      if (!mounted) return;
      
      if (bookResult['success'] != true) {
        // If booking failed, refresh slots and show error
        _loadAvailableSlots();
        throw Exception(bookResult['message'] ?? "Failed to book slot");
      }

      // Step 2: Create the appointment record with approved status
      final startTime = _selectedSlot!['start_time'] as String;
      final dateString = _selectedSlot!['appointment_date'] as String;
      
      final appointmentData = {
        'userId': userSession.userId,
        'patientId': userSession.patientData?['id']?.toString() ?? '',
        'doctorName': 'Available Doctor',
        'clinicHospital': 'Balangasan Health Center',
        'appointmentDate': dateString,
        'appointmentTime': startTime,
        'appointmentType': _getSelectedServiceName(),
        'notes': '',
        'slotId': slotId,
        'status': 'approved', // Auto-approved since slot was successfully booked
      };

      final result = await AppointmentService.addAppointment(appointmentData);

      if (!mounted) return;

      if (result['success'] == true) {
        MessageUtils.showSuccessMessage(
          context, 
          "Appointment booked successfully and automatically approved!",
          title: "Appointment Confirmed",
        );
        
        // Refresh slots and appointments immediately
        await Future.wait([
          _loadAvailableSlots(),
          _loadAppointments()
        ]);
        
        // Reset selection
        setState(() {
          _selectedSlot = null;
        });
        
        // Switch to the history tab
        _pageController.animateToPage(
          1,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        // Check if backend blocked due to existing approved appointment
        if (result['code'] == 'ACTIVE_APPOINTMENT_EXISTS') {
          final existing = result['existingAppointment'] as Map<String, dynamic>? ?? {};
          final rawDate = existing['date']?.toString() ?? '';
          final rawTime = existing['time']?.toString() ?? '';
          String displayDate = rawDate;
          String displayTime = rawTime.length >= 5 ? rawTime.substring(0, 5) : rawTime;
          try {
            if (rawDate.isNotEmpty) {
              final parsed = DateTime.parse(rawDate);
              displayDate = DateFormat('MMMM d, yyyy').format(parsed);
            }
            if (rawTime.length >= 5) {
              final parts = rawTime.split(':');
              int hour = int.parse(parts[0]);
              final minute = parts[1];
              final period = hour >= 12 ? 'PM' : 'AM';
              if (hour > 12) hour -= 12;
              if (hour == 0) hour = 12;
              displayTime = '$hour:$minute $period';
            }
          } catch (_) {}
          _loadAvailableSlots();
          await _loadAppointments();
          if (mounted) _showActiveAppointmentBlockedDialog(displayDate, displayTime);
        } else {
          MessageUtils.showErrorMessage(
            context,
            result['message'] ?? "Slot booked but failed to create appointment record. Please contact support.",
          );
          _loadAvailableSlots();
        }
      }
    } catch (e) {
      if (!mounted) return;
      MessageUtils.showErrorMessage(context, "Failed to book appointment: $e");
      // Always refresh slots after error to ensure UI is current
      _loadAvailableSlots();
    } finally {
      if (mounted) {
        setState(() {
          _isBooking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Tab bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                _buildTabButton("New Appointment", 0),
                _buildTabButton("Appointment History", 1),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                });
              },
              children: [
                // New Appointment Tab
                _buildNewAppointmentTab(),
                
                // Appointment History Tab
                _buildAppointmentHistoryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String title, int index) {
    final isSelected = _currentPageIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          _pageController.animateToPage(
            index,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? Colors.blueAccent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Colors.blueAccent : Colors.grey,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNewAppointmentTab() {
    return Column(
      children: [
        // Service Selection Header
        _buildServiceSelectionHeader(),
        
        // Time Slot Booking Interface
        Expanded(
          child: _buildTimeSlotBookingInterface(),
        ),
      ],
    );
  }

  Widget _buildServiceSelectionHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          padding: EdgeInsets.all(constraints.maxWidth < 360 ? 12 : 16), // Responsive padding
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Service',
                style: TextStyle(
                  fontSize: constraints.maxWidth < 360 ? 16 : 18, // Responsive font size
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: constraints.maxWidth < 360 ? 8 : 12), // Responsive spacing
              if (_isLoadingServices)
                const Center(child: CircularProgressIndicator())
              else
                _buildServiceCards(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth < 360 ? 120.0 : 140.0; // Responsive card width
        final cardHeight = constraints.maxWidth < 360 ? 70.0 : 80.0; // Responsive card height
        
        return Center(
          child: SizedBox(
            height: cardHeight,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: _services.map((service) {
                  final isSelected = _selectedServiceId == service.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildServiceCard(service, isSelected, cardWidth),
                  );
                }).toList(),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildServiceCard(ServiceModel service, bool isSelected, double cardWidth) {
    IconData icon;
    String description;
    
    if (service.serviceName == 'Maternal Care') {
      icon = Icons.pregnant_woman;
      description = 'Prenatal and postnatal care';
    } else if (service.serviceName == 'Immunization') {
      icon = Icons.vaccines;
      description = 'Vaccination services';
    } else {
      icon = Icons.medical_services;
      description = 'Healthcare services';
    }
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedServiceId = service.id;
          _selectedSlot = null; // Reset selection when service changes
        });
        // Reload slots for the selected service
        _loadAvailableSlots();
      },
      child: Container(
        width: cardWidth,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: isSelected ? Theme.of(context).primaryColor.withOpacity(0.1) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? Theme.of(context).primaryColor 
                : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected 
                  ? Theme.of(context).primaryColor 
                  : Colors.grey.shade600,
              size: cardWidth < 130 ? 20 : 24, // Responsive icon size
            ),
            SizedBox(height: cardWidth < 130 ? 2 : 4), // Responsive spacing
            Flexible(
              child: Text(
                service.serviceName,
                style: TextStyle(
                  fontSize: cardWidth < 130 ? 10 : 11, // Responsive font size
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade800,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            SizedBox(height: cardWidth < 130 ? 1 : 2), // Responsive spacing
            Flexible(
              child: Text(
                description,
                style: TextStyle(
                  fontSize: cardWidth < 130 ? 8 : 9, // Responsive font size
                  color: isSelected 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: cardWidth < 130 ? 1 : 2, // Responsive max lines
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeSlotBookingInterface() {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (_isLoadingSlots) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: EdgeInsets.all(constraints.maxWidth < 360 ? 20 : 24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: constraints.maxWidth < 360 ? 16 : 20),
                      Text(
                        'Loading available appointment slots...',
                        style: TextStyle(
                          fontSize: constraints.maxWidth < 360 ? 14 : 16,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }

        if (_groupedSlots.isEmpty) {
          return Center(
            child: SingleChildScrollView(
              child: Container(
                margin: EdgeInsets.all(constraints.maxWidth < 360 ? 16 : 24),
                padding: EdgeInsets.all(constraints.maxWidth < 360 ? 24 : 32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: EdgeInsets.all(constraints.maxWidth < 360 ? 16 : 20),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.calendar_today,
                        size: constraints.maxWidth < 360 ? 48 : 64,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    SizedBox(height: constraints.maxWidth < 360 ? 16 : 24),
                    Text(
                      'No Available Slots',
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 360 ? 18 : 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                    SizedBox(height: constraints.maxWidth < 360 ? 8 : 12),
                    Text(
                      'Please check back later or contact the clinic',
                      style: TextStyle(
                        fontSize: constraints.maxWidth < 360 ? 13 : 15,
                        color: Colors.grey[600],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: constraints.maxWidth < 360 ? 16 : 20),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: constraints.maxWidth < 360 ? 16 : 20,
                        vertical: constraints.maxWidth < 360 ? 8 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: constraints.maxWidth < 360 ? 16 : 18,
                            color: Colors.grey[600],
                          ),
                          SizedBox(width: constraints.maxWidth < 360 ? 6 : 8),
                          Text(
                            'Slots are updated in real-time',
                            style: TextStyle(
                              fontSize: constraints.maxWidth < 360 ? 11 : 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Column(
          children: [
            // Enhanced header with gradient - reduced height
            Container(
              margin: EdgeInsets.only(
                left: constraints.maxWidth < 360 ? 8 : 12,
                right: constraints.maxWidth < 360 ? 8 : 12,
                top: constraints.maxWidth < 360 ? 6 : 8,
                bottom: constraints.maxWidth < 360 ? 8 : 12,
              ),
              padding: EdgeInsets.symmetric(
                horizontal: constraints.maxWidth < 360 ? 12 : 16,
                vertical: constraints.maxWidth < 360 ? 10 : 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor.withOpacity(0.08),
                    Theme.of(context).primaryColor.withOpacity(0.04),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.15),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(constraints.maxWidth < 360 ? 6 : 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(context).primaryColor.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.calendar_month,
                      color: Colors.white,
                      size: constraints.maxWidth < 360 ? 16 : 20,
                    ),
                  ),
                  SizedBox(width: constraints.maxWidth < 360 ? 8 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Available Appointment Slots',
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 360 ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: constraints.maxWidth < 360 ? 1 : 2),
                        Text(
                          'Select a time slot for your appointment',
                          style: TextStyle(
                            fontSize: constraints.maxWidth < 360 ? 11 : 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Time slots list with proper scrolling
            Expanded(
              child: RefreshIndicator(
                onRefresh: _loadAvailableSlots,
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 360 ? 8 : 12,
                    vertical: constraints.maxWidth < 360 ? 2 : 4,
                  ),
                  itemCount: _availableDates.length,
                  itemBuilder: (context, index) {
                    final date = _availableDates[index];
                    final dateStr = DateFormat('yyyy-MM-dd').format(date);
                    final slots = _groupedSlots[dateStr] ?? [];
                    
                    return _buildDateSection(date, slots, constraints.maxWidth);
                  },
                ),
              ),
            ),
            
            // Note: Removed booking confirmation section as we now use popup dialog
          ],
        );
      },
    );
  }

  Widget _buildDateSection(DateTime date, List<Map<String, dynamic>> slots, double screenWidth) {
    final dayName = DateFormat('EEE').format(date).toUpperCase();
    final monthDay = DateFormat('MMM d').format(date).toUpperCase();
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date header with enhanced design
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 12, vertical: isSmallScreen ? 8 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).primaryColor,
                  Theme.of(context).primaryColor.withOpacity(0.8),
                ],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 4 : 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    color: Colors.white,
                    size: isSmallScreen ? 14 : 16,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 6 : 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dayName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 11 : 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        monthDay,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 10,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6 : 8, vertical: isSmallScreen ? 2 : 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${slots.length} slots',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 8 : 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Time slots grid with enhanced container - using proper aspect ratio
          Container(
            constraints: BoxConstraints(
              minHeight: isSmallScreen ? 180.0 : 220.0, // Increased minimum height for taller cards
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: _buildTimeSlotsGrid(slots, screenWidth),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeSlotsGrid(List<Map<String, dynamic>> slots, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final crossAxisCount = isSmallScreen ? 2 : 3; // Responsive columns
    
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 10.0,
          mainAxisSpacing: 10.0,
          childAspectRatio: 0.85, // Taller cards for better content accommodation
        ),
        itemCount: slots.length,
        itemBuilder: (context, index) {
          return _buildTimeSlotCard(slots[index], screenWidth);
        },
      ),
    );
  }

  Widget _buildTimeSlotCard(Map<String, dynamic> slot, double screenWidth) {
    final startTime = slot['start_time'] as String;
    final endTime = slot['end_time'] as String?;
    final slotDuration = slot['slot_duration_minutes'] as int? ?? 30;
    
    // Use server-provided availability
    final isUserAvailable = slot['calculated_available'] as bool? ?? false;
    final isSmallScreen = screenWidth < 360;

    return GestureDetector(
      onTap: isUserAvailable ? () => _onSlotSelected(slot) : null,
      child: Opacity(
        opacity: isUserAvailable ? 1.0 : 0.72,
        child: Container(
          decoration: BoxDecoration(
            color: isUserAvailable ? Colors.white : const Color(0xFFFFF3F3),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUserAvailable ? Colors.green.shade300 : Colors.red.shade300,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isUserAvailable ? 0.08 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon at top
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isUserAvailable
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isUserAvailable ? Icons.schedule : Icons.lock,
                      size: isSmallScreen ? 20 : 24,
                      color: isUserAvailable
                          ? Colors.green.shade700
                          : Colors.red.shade400,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Time range
                Expanded(
                  flex: 3,
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _formatTimeRange(startTime, endTime, slotDuration),
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 12,
                        fontWeight: FontWeight.bold,
                        color: isUserAvailable
                            ? Colors.black87
                            : Colors.grey.shade500,
                        height: 1.3,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Status badge at bottom
                Expanded(
                  flex: 2,
                  child: Container(
                    width: double.infinity,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isUserAvailable
                          ? Colors.green.withOpacity(0.15)
                          : Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isUserAvailable
                            ? Colors.green.withOpacity(0.4)
                            : Colors.red.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isUserAvailable
                                ? Icons.check_circle_outline
                                : Icons.lock_outline,
                            size: isSmallScreen ? 9 : 10,
                            color: isUserAvailable
                                ? Colors.green.shade700
                                : Colors.red.shade700,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            isUserAvailable ? 'Available' : 'Booked',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 9 : 10,
                              color: isUserAvailable
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildAppointmentHistoryTab() {
    // Status display config: label, color, icon
    Color _statusColor(String status) {
      switch (status.toLowerCase()) {
        case 'approved':    return const Color(0xFF2563EB);
        case 'rescheduled': return Colors.orange;
        case 'completed':   return Colors.green;
        case 'no_show':     return Colors.red;
        case 'cancelled':   return Colors.grey;
        default:            return Colors.blueGrey;
      }
    }

    String _statusLabel(String status) {
      switch (status.toLowerCase()) {
        case 'approved':    return 'Approved';
        case 'rescheduled': return 'Rescheduled';
        case 'completed':   return 'Completed';
        case 'no_show':     return 'Missed';
        case 'cancelled':   return 'Cancelled';
        default:            return status;
      }
    }

    IconData _statusIcon(String status) {
      switch (status.toLowerCase()) {
        case 'approved':    return Icons.check_circle_outline;
        case 'rescheduled': return Icons.edit_calendar;
        case 'completed':   return Icons.check_circle;
        case 'no_show':     return Icons.cancel;
        case 'cancelled':   return Icons.remove_circle_outline;
        default:            return Icons.info_outline;
      }
    }

    // Group appointments by status
    final Map<String, List<Map<String, dynamic>>> grouped = {
      'approved':    [],
      'rescheduled': [],
      'completed':   [],
      'no_show':     [],
      'cancelled':   [],
    };
    for (final appt in _appointments) {
      final status = (appt["status"] ?? "").toString().toLowerCase();
      if (grouped.containsKey(status)) {
        grouped[status]!.add(appt);
      }
    }

    // Build sections only for statuses that have entries
    final sections = grouped.entries
        .where((e) => e.value.isNotEmpty)
        .toList();

    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              "Appointment History",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ),

        if (_isLoadingAppointments)
          const Expanded(
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_errorMessage.isNotEmpty)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                "Error: $_errorMessage",
                style: const TextStyle(color: Colors.red),
              ),
            ),
          )
        else if (_appointments.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.calendar_today, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  const Text(
                    "No appointment history yet",
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Book a new appointment to get started",
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadAppointments,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  for (final section in sections) ...[
                    // Section header
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 6),
                      child: Row(
                        children: [
                          Icon(
                            _statusIcon(section.key),
                            size: 16,
                            color: _statusColor(section.key),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "${_statusLabel(section.key)} (${section.value.length})",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: _statusColor(section.key),
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Appointment cards in this section
                    for (final appt in section.value)
                      _buildAppointmentCard(
                        appt,
                        _statusLabel(section.key),
                        _statusColor(section.key),
                        _statusIcon(section.key),
                      ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAppointmentCard(
    Map<String, dynamic> appt,
    String statusLabel,
    Color statusColor,
    IconData statusIcon,
  ) {
    final appointmentDateTime = _formatAppointmentDateTime(
      appt["appointment_date"] ?? "",
      appt["appointment_time"] ?? "",
    );

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: statusColor.withOpacity(0.15),
              child: Icon(statusIcon, color: statusColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appt["clinic_hospital"] ?? "Balangasan Health Center",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    appt["appointment_type"] ?? "General Check-up",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today,
                          size: 12, color: Colors.grey),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          appointmentDateTime,
                          style: const TextStyle(fontSize: 12),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  if (appt["notes"] != null &&
                      appt["notes"].toString().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.note, size: 12, color: Colors.grey),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              appt["notes"],
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatAppointmentDateTime(String dateString, String timeString) {
    if (dateString.isEmpty && timeString.isEmpty) return "Unknown Schedule";
    final formatted = TimeUtils.formatAppointmentUtcDateTime(
      dateString,
      timeString,
      pattern: 'MMMM dd, yyyy hh:mm a',
    );
    return formatted.isEmpty ? "$dateString $timeString".trim() : formatted;
  }

  // Helper method to format time range based on slot duration
  String _formatTimeRange(String startTime, String? endTime, int slotDuration) {
    if (endTime != null && endTime.isNotEmpty) {
      // If end time is provided, use it
      final startFormatted = _formatTimeString12Hour(startTime);
      final endFormatted = _formatTimeString12Hour(endTime);
      return '$startFormatted – $endFormatted';
    } else {
      // Calculate end time from start time and duration
      try {
        final parts = startTime.split(':');
        if (parts.length >= 2) {
          final hour = int.parse(parts[0]);
          final minute = int.parse(parts[1]);
          
          final endHour = hour + (minute + slotDuration) ~/ 60;
          final endMinute = (minute + slotDuration) % 60;
          
          final endFormatted = _formatTimeString12Hour('${endHour.toString().padLeft(2, '0')}:${endMinute.toString().padLeft(2, '0')}');
          final startFormatted = _formatTimeString12Hour(startTime);
          
          return '$startFormatted – $endFormatted';
        }
      } catch (e) {
        // Fallback to single time if calculation fails
      }
    }
    
    // Fallback to single time display
    return _formatTimeString12Hour(startTime);
  }

  // Helper method to format time in 12-hour format
  String _formatTimeString12Hour(String timeString) {
    if (timeString.isEmpty) return "Unknown Time";
    
    try {
      // Split time string (HH:MM:SS or HH:MM)
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        
        // Convert to 12-hour format
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        
        return "$displayHour:${minute.toString().padLeft(2, '0')} $period";
      }
    } catch (e) {
      // Handle parsing errors
    }
    return timeString;
  }
}
