import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/service_model.dart';
import '../../services/appointment_slot_service.dart';
import '../../utils/message_utils.dart';

class SlotConfigurationPanel extends StatefulWidget {
  final DateTime selectedDate;
  final List<ServiceModel> services;
  final int? selectedServiceId;
  final Function()? onSlotsGenerated;
  final Function()? onClose;

  const SlotConfigurationPanel({
    super.key,
    required this.selectedDate,
    required this.services,
    this.selectedServiceId,
    this.onSlotsGenerated,
    this.onClose,
  });

  @override
  State<SlotConfigurationPanel> createState() => _SlotConfigurationPanelState();
}

class _SlotConfigurationPanelState extends State<SlotConfigurationPanel> {
  // Form state
  int? _selectedServiceId;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;
  String _durationInput = '';
  int? _customDuration;
  bool _isGenerating = false;
  
  // Calculation results
  int _calculatedSlots = 0;
  String _calculationError = '';
  bool _isValidConfiguration = false;

  @override
  void initState() {
    super.initState();
    _selectedServiceId = widget.selectedServiceId;
    _startTime = const TimeOfDay(hour: 9, minute: 0);
    _endTime = const TimeOfDay(hour: 17, minute: 0);
    _durationInput = '30';
    _customDuration = 30;
    _calculateSlots();
  }

  // Calculate total slots based on time range and duration
  void _calculateSlots() {
    setState(() {
      _calculationError = '';
      _calculatedSlots = 0;
      _isValidConfiguration = false;
    });

    // Validate required fields
    if (_startTime == null || _endTime == null || _customDuration == null || _customDuration! <= 0) {
      return;
    }

    // Validate time range
    if (_startTime!.hour > _endTime!.hour || 
        (_startTime!.hour == _endTime!.hour && _startTime!.minute >= _endTime!.minute)) {
      setState(() {
        _calculationError = 'End time must be later than start time';
      });
      return;
    }

    // Calculate time difference in minutes
    final startMinutes = _startTime!.hour * 60 + _startTime!.minute;
    final endMinutes = _endTime!.hour * 60 + _endTime!.minute;
    final timeRangeMinutes = endMinutes - startMinutes;
    
    // Calculate number of slots
    final slots = timeRangeMinutes ~/ _customDuration!;
    
    if (slots <= 0) {
      setState(() {
        _calculationError = 'Time range is too short for the selected duration';
      });
      return;
    }

    setState(() {
      _calculatedSlots = slots;
      _isValidConfiguration = true;
    });
  }

  // Validate and parse custom duration input
  void _validateDurationInput(String input) {
    setState(() {
      _durationInput = input;
      _customDuration = int.tryParse(input);
      _calculationError = '';
    });

    if (input.isEmpty) {
      setState(() {
        _calculationError = 'Duration is required';
        _customDuration = null;
      });
      return;
    }

    final duration = int.tryParse(input);
    if (duration == null) {
      setState(() {
        _calculationError = 'Please enter a valid number';
        _customDuration = null;
      });
      return;
    }

    if (duration <= 0) {
      setState(() {
        _calculationError = 'Duration must be greater than 0';
        _customDuration = null;
      });
      return;
    }

    if (duration > 480) {
      setState(() {
        _calculationError = 'Duration cannot exceed 8 hours (480 minutes)';
        _customDuration = null;
      });
      return;
    }

    // Recalculate slots with valid duration
    _calculateSlots();
  }

  Future<void> _generateSlots() async {
    if (!_isValidConfiguration) {
      MessageUtils.showErrorMessage(context, "Please fix validation errors before generating slots");
      return;
    }

    setState(() {
      _isGenerating = true;
    });

    try {
      final dateString = DateFormat('yyyy-MM-dd').format(widget.selectedDate);
      final startTimeString = "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00";
      final endTimeString = "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00";
      
      final result = await AppointmentSlotService.createSlot(
        serviceId: _selectedServiceId!,
        appointmentDate: dateString,
        startTime: startTimeString,
        endTime: endTimeString,
        slotDurationMinutes: _customDuration!,
        maxPatients: 10, // Default value, can be made configurable
        generateSlots: true,
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
          
          widget.onSlotsGenerated?.call();
          widget.onClose?.call();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          _buildHeader(),
          
          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date display
                  _buildDateDisplay(),
                  const SizedBox(height: 24),
                  
                  // Configuration form
                  _buildConfigurationForm(),
                  const SizedBox(height: 24),
                  
                  // Calculation results
                  _buildCalculationResults(),
                  const SizedBox(height: 24),
                  
                  // Generate button
                  _buildGenerateButton(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            "Slot Configuration",
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.blue),
            onPressed: widget.onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildDateDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.blue.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.calendar_today, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Text(
            "Date: ${DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate)}",
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.blue.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigurationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Configuration",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 16),
        
        // Service selection
        _buildServiceSelector(),
        const SizedBox(height: 16),
        
        // Time range selection
        _buildTimeRangeSelector(),
        const SizedBox(height: 16),
        
        // Duration input
        _buildDurationInput(),
      ],
    );
  }

  Widget _buildServiceSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Service Type",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<int>(
            value: _selectedServiceId,
            items: widget.services.map((service) {
              return DropdownMenuItem(
                value: service.id,
                child: Row(
                  children: [
                    Icon(
                      service.serviceName == 'Maternal Care' 
                        ? Icons.pregnant_woman 
                        : Icons.vaccines,
                      size: 18,
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
            },
            isExpanded: true,
            underline: const SizedBox(),
          ),
        ),
      ],
    );
  }

  Widget _buildTimeRangeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Time Range",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTimePicker(
                label: "Start Time",
                selectedTime: _startTime,
                onTimeSelected: (time) {
                  setState(() {
                    _startTime = time;
                  });
                  _calculateSlots();
                },
                icon: Icons.access_time,
              ),
            ),
            const SizedBox(width: 16),
            const Text("to", style: TextStyle(color: Colors.grey)),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTimePicker(
                label: "End Time",
                selectedTime: _endTime,
                onTimeSelected: (time) {
                  setState(() {
                    _endTime = time;
                  });
                  _calculateSlots();
                },
                icon: Icons.access_time,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimePicker({
    required String label,
    required TimeOfDay? selectedTime,
    required Function(TimeOfDay) onTimeSelected,
    required IconData icon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 48,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            title: Text(
              selectedTime?.format(context) ?? "Select time",
              style: TextStyle(
                fontSize: 14,
                color: selectedTime != null ? Colors.black : Colors.grey.shade600,
                fontWeight: selectedTime != null ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
            trailing: Icon(icon, color: Colors.grey, size: 20),
            onTap: () async {
              final pickedTime = await showTimePicker(
                context: context,
                initialTime: selectedTime ?? const TimeOfDay(hour: 9, minute: 0),
              );
              if (pickedTime != null) {
                onTimeSelected(pickedTime);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDurationInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Slot Duration (minutes)",
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(
              color: _calculationError.isNotEmpty ? Colors.red.shade300 : Colors.grey.shade300,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer, size: 20, color: Colors.grey),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: TextEditingController(text: _durationInput),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: "Enter duration (e.g., 15, 30, 45)",
                    hintStyle: TextStyle(color: Colors.grey),
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: _validateDurationInput,
                ),
              ),
              const Text(
                "min",
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
        if (_calculationError.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _calculationError,
              style: TextStyle(
                color: Colors.red.shade600,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCalculationResults() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isValidConfiguration ? Colors.green.shade50 : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isValidConfiguration ? Colors.green.shade300 : Colors.grey.shade300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isValidConfiguration ? Icons.check_circle : Icons.info,
                color: _isValidConfiguration ? Colors.green.shade600 : Colors.grey.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                "Calculation Results",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _isValidConfiguration ? Colors.green.shade700 : Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_isValidConfiguration) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "$_calculatedSlots slots will be generated",
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              "Based on ${_startTime?.format(context) ?? '--:--'} to ${_endTime?.format(context) ?? '--:--'} "
              "with $_customDuration minute intervals",
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ] else ...[
            const Text(
              "Configure time range and duration to see slot calculation",
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenerateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isGenerating || !_isValidConfiguration ? null : _generateSlots,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        child: _isGenerating
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text("Generating Slots..."),
                ],
              )
            : const Text(
                "Generate Slots",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}