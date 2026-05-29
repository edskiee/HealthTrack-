import 'package:flutter/material.dart';
import 'package:healthtrack/admin/widgets/enhanced_slot_management_calendar.dart';
import 'widgets/admin_app_bar.dart';
import '../services/appointment_slot_service.dart';
import '../services/service_config_service.dart';
import '../services/websocket_service.dart';
import '../models/service_model.dart';
import '../utils/message_utils.dart';

class AdminToolsView extends StatefulWidget {
  const AdminToolsView({super.key});

  @override
  State<AdminToolsView> createState() => _AdminToolsViewState();
}

class _AdminToolsViewState extends State<AdminToolsView> {
  bool _showConfigPanel = false;
  DateTime? _selectedDate;
  List<ServiceModel> _services = [];
  int? _selectedServiceId;
  int _totalSlots = 1;
  int _duration = 30;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  bool _isGenerating = false;
  bool _isDeleting = false;

    
  @override
  void initState() {
    super.initState();
    _loadServices();
    _initializeWebSocket();
  }

  // Initialize WebSocket connection for real-time updates
  Future<void> _initializeWebSocket() async {
    try {
      await WebSocketService.instance.initialize();
      // Join admin room to receive all slot updates
      WebSocketService.instance.joinAdminsRoom();
      debugPrint('🔌 Admin: WebSocket initialized for real-time slot management');
    } catch (e) {
      debugPrint('❌ Admin: Failed to initialize WebSocket: $e');
      // Continue without WebSocket - admin tools will still work
    }
  }

  @override
  void dispose() {
    // Leave admin room when disposing
    WebSocketService.instance.leaveAdminsRoom();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final services = await ServiceConfigService.getAllServices();
      final serviceModels = services.map((s) => ServiceModel.fromJson(s)).toList();
      
      if (mounted) {
        setState(() {
          _services = serviceModels;
          // Auto-select first service if none selected
          if (_selectedServiceId == null && _services.isNotEmpty) {
            _selectedServiceId = _services.first.id;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        MessageUtils.showErrorMessage(context, "Failed to load services: $e");
      }
    }
  }

  Future<void> _generateSlots() async {
    if (_selectedDate == null || _selectedServiceId == null || _startTime == null || _endTime == null) {
      MessageUtils.showErrorMessage(context, "Please fill all required fields");
      return;
    }
    
    // Validate time range
    if (_startTime!.hour > _endTime!.hour || 
        (_startTime!.hour == _endTime!.hour && _startTime!.minute >= _endTime!.minute)) {
      MessageUtils.showErrorMessage(context, "Start time must be before end time");
      return;
    }
    
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final startTimeString = "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00";
      final endTimeString = "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00";
      
      final result = await AppointmentSlotService.createSlot(
        serviceId: _selectedServiceId!,
        appointmentDate: dateString,
        startTime: startTimeString,
        endTime: endTimeString,
        slotDurationMinutes: _duration,
        maxPatients: _totalSlots,
        generateSlots: true, // This tells the backend to generate multiple slots
      );
      
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        
        if (result['success'] == true) {
          MessageUtils.showSuccessMessage(
            context, 
            "${result['data'].length} slots generated successfully!",
            title: "Success",
          );
          
          // Clear the form
          setState(() {
            _showConfigPanel = false;
            _selectedDate = null;
            _startTime = null;
            _endTime = null;
          });
        } else {
          MessageUtils.showErrorMessage(context, result['message'] ?? "Failed to generate slots");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        MessageUtils.showErrorMessage(context, "Failed to generate slots: $e");
      }
    }
  }

  // Show confirmation dialog for deleting all slots
  Future<void> _showDeleteAllConfirmation() async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // User must tap button
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('⚠️ Confirm Delete All Slots'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text(
                  'Are you sure you want to remove ALL generated appointment slots?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text('This action will:'),
                const SizedBox(height: 8),
                const Text('• Delete all appointment slot records from the database'),
                const Text('• Remove slots from both admin and user interfaces'),
                const Text('• Clear all slot availability immediately'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This action cannot be undone and will only affect appointment slots. Other system data will remain intact.',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete All Slots'),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteAllSlots();
              },
            ),
          ],
        );
      },
    );
  }

  // Delete all appointment slots
  Future<void> _deleteAllSlots() async {
    setState(() {
      _isDeleting = true;
    });
    
    try {
      // Allow filtering by service if one is selected, otherwise delete all
      final result = await AppointmentSlotService.deleteAllSlots(
        serviceId: _selectedServiceId,
      );
      
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        
        if (result['success'] == true) {
          final deletedCount = result['data']['deletedCount'];
          final serviceFilter = result['data']['serviceId'];
          final dateFilter = result['data']['date'];
          
          String message = "$deletedCount appointment slot(s) deleted successfully!";
          if (serviceFilter != null || dateFilter != null) {
            message += "\n\nFilters applied:";
            if (serviceFilter != null) {
              final service = _services.firstWhere((s) => s.id == serviceFilter, 
                orElse: () => ServiceModel(id: serviceFilter, serviceName: 'Unknown', serviceType: 'unknown'));
              message += "\n• Service: ${service.serviceName}";
            }
            if (dateFilter != null) {
              message += "\n• Date: $dateFilter";
            }
          }
          
          MessageUtils.showSuccessMessage(
            context, 
            message,
            title: "Success",
          );
          
          // Clear the configuration panel if it's open
          setState(() {
            _showConfigPanel = false;
            _selectedDate = null;
            _startTime = null;
            _endTime = null;
          });
        } else {
          MessageUtils.showErrorMessage(context, result['message'] ?? "Failed to delete slots");
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
        MessageUtils.showErrorMessage(context, "Failed to delete slots: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue[50], // Light pastel background like Reports section
      appBar: const AdminAppBar(title: 'Admin Tools'),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left side: Calendar (enlarged to fit available space)
            Expanded(
              flex: _showConfigPanel ? 2 : 3, // Take more space when right panel is hidden
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Appointment Slot Management",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          // Refresh button
                          IconButton(
                            onPressed: () async {
                              // Trigger a state refresh to update the calendar
                              setState(() {});
                              MessageUtils.showSuccessMessage(
                                context,
                                "Calendar refreshed successfully",
                                title: "Refreshed",
                              );
                            },
                            icon: const Icon(Icons.refresh),
                            tooltip: "Refresh Calendar",
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.blue.shade50,
                              foregroundColor: Colors.blue,
                              padding: const EdgeInsets.all(8),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: EnhancedSlotManagementCalendar(
                          onSlotsUpdated: () {
                            // Refresh the UI if needed
                          },
                          onDateSelected: (selectedDate) {
                            setState(() {
                              _showConfigPanel = true;
                              _selectedDate = selectedDate;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(width: 24),

            // Right side: Administrative Actions (always visible)
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  // Configuration Panel (appears when date is selected)
                  if (_showConfigPanel) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  "Slot Configuration",
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () {
                                    setState(() {
                                      _showConfigPanel = false;
                                      _selectedDate = null;
                                      _startTime = null;
                                      _endTime = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            if (_selectedDate != null)
                              Text(
                                "Configure slots for ${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}",
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.black54,
                                ),
                              ),
                            const SizedBox(height: 16),
                            const Text(
                              "Service Type:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildServiceDropdown(),
                            const SizedBox(height: 16),
                            const Text(
                              "Total Slots:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildTotalSlotsField(),
                            const SizedBox(height: 16),
                            const Text(
                              "Duration:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildDurationDropdown(),
                            const SizedBox(height: 16),
                            const Text(
                              "Start Time:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildStartTimeField(),
                            const SizedBox(height: 16),
                            const Text(
                              "End Time:",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildEndTimeField(),
                            const SizedBox(height: 24),
                            ElevatedButton(
                              onPressed: _isGenerating ? null : _generateSlots,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                minimumSize: const Size(double.infinity, 45),
                              ),
                              child: _isGenerating
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Text("Generate Slots"),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Administrative Actions Panel (always visible)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Administrative Actions",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            "Service Filter (Optional):",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _buildServiceDropdown(),
                          const SizedBox(height: 16),
                          // Remove All Slots button
                          Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(12),
                                  child: Row(
                                    children: [
                                      Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          "Danger Zone",
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                                  child: ElevatedButton.icon(
                                    onPressed: _isDeleting ? null : _showDeleteAllConfirmation,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                                      minimumSize: const Size(double.infinity, 45),
                                    ),
                                    icon: _isDeleting
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.delete_forever),
                                    label: Text(_isDeleting ? "Deleting..." : "Remove All Slots"),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceDropdown() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<int>(
        value: _selectedServiceId,
        items: _services
            .map((service) => DropdownMenuItem<int>(
                  value: service.id,
                  child: Text(service.serviceName),
                ))
            .toList(),
        onChanged: (value) {
          setState(() {
            _selectedServiceId = value;
          });
        },
        isExpanded: true,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildTotalSlotsField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: TextField(
        decoration: const InputDecoration(
          border: InputBorder.none,
          hintText: "Enter number of slots",
        ),
        keyboardType: TextInputType.number,
        onChanged: (value) {
          final parsed = int.tryParse(value);
          if (parsed != null && parsed > 0) {
            setState(() {
              _totalSlots = parsed;
            });
          }
        },
      ),
    );
  }

  Widget _buildDurationDropdown() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButton<int>(
        value: _duration,
        items: const [
          DropdownMenuItem(value: 15, child: Text("15 minutes")),
          DropdownMenuItem(value: 30, child: Text("30 minutes")),
          DropdownMenuItem(value: 60, child: Text("60 minutes")),
        ],
        onChanged: (value) {
          if (value == null) return;
          setState(() {
            _duration = value;
          });
        },
        isExpanded: true,
        underline: const SizedBox(),
      ),
    );
  }

  Widget _buildStartTimeField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          _startTime?.format(context) ?? "Select start time",
          style: TextStyle(
            fontSize: 14,
            color: _startTime != null ? Colors.black : Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(Icons.access_time, color: Colors.grey),
        onTap: () async {
          final selectedTime = await showTimePicker(
            context: context,
            initialTime: _startTime ?? const TimeOfDay(hour: 9, minute: 0),
          );
          if (selectedTime != null) {
            setState(() {
              _startTime = selectedTime;
            });
          }
        },
      ),
    );
  }

  Widget _buildEndTimeField() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        title: Text(
          _endTime?.format(context) ?? "Select end time",
          style: TextStyle(
            fontSize: 14,
            color: _endTime != null ? Colors.black : Colors.grey.shade600,
          ),
        ),
        trailing: const Icon(Icons.access_time, color: Colors.grey),
        onTap: () async {
          final selectedTime = await showTimePicker(
            context: context,
            initialTime: _endTime ?? const TimeOfDay(hour: 17, minute: 0),
          );
          if (selectedTime != null) {
            setState(() {
              _endTime = selectedTime;
            });
          }
        },
      ),
    );
  }
}