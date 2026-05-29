import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../utils/message_utils.dart';

class SlotDetailsModal extends StatefulWidget {
  final DateTime selectedDate;
  final List<Map<String, dynamic>> slots;
  final int? serviceId;
  final Function()? onSlotsUpdated;

  const SlotDetailsModal({
    super.key,
    required this.selectedDate,
    required this.slots,
    this.serviceId,
    this.onSlotsUpdated,
  });

  @override
  State<SlotDetailsModal> createState() => _SlotDetailsModalState();
}

class _SlotDetailsModalState extends State<SlotDetailsModal> {
  List<Map<String, dynamic>> _slots = [];
  Set<int> _deletingSlotIds = {};

  @override
  void initState() {
    super.initState();
    _slots = List<Map<String, dynamic>>.from(widget.slots);
  }

  // Show confirmation dialog for deleting a slot
  Future<bool> _showDeleteConfirmationDialog(Map<String, dynamic> slot) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              const Text('Delete Slot'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this appointment slot?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Slot Details:',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Time: ${_formatTime(slot['start_time'])} - ${_formatTime(slot['end_time'])}',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    Text(
                      'Duration: ${slot['slot_duration_minutes']} minutes',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
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
                    Icon(Icons.info_outline, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This action will immediately remove the slot from both admin and user interfaces, and permanently delete it from the database.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('Delete Slot'),
            ),
          ],
        );
      },
    ) ?? false;
  }

  // Handle slot deletion with proper error handling and UI updates
  Future<void> _handleDeleteSlot(Map<String, dynamic> slot) async {
    final bool confirmed = await _showDeleteConfirmationDialog(slot);
    if (!confirmed) return;

    final int slotId = slot['id'];
    
    setState(() {
      _deletingSlotIds.add(slotId);
    });

    try {
      final response = await http.delete(
        Uri.parse('http://localhost:3000/appointment-slots/$slotId'),
        headers: {
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true) {
          // Remove slot from local list
          setState(() {
            _slots.removeWhere((s) => s['id'] == slotId);
            _deletingSlotIds.remove(slotId);
          });
          
          // Show success message
          if (mounted) {
            MessageUtils.showSuccessMessage(
              context,
              'Slot deleted successfully',
              title: 'Success',
            );
          }
          
          // Notify parent to refresh calendar
          widget.onSlotsUpdated?.call();
          
          print('🗑️ Slot $slotId deleted successfully');
        } else {
          throw Exception(responseData['message'] ?? 'Failed to delete slot');
        }
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      // Remove from deleting set on error
      setState(() {
        _deletingSlotIds.remove(slotId);
      });
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Failed to delete slot: ${e.toString()}',
        );
      }
      print('❌ Error deleting slot $slotId: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Group slots by service if multiple services exist
    Map<int?, List<Map<String, dynamic>>> groupedSlots = {};
    for (var slot in _slots) {
      int? serviceId = slot['service_id'];
      if (!groupedSlots.containsKey(serviceId)) {
        groupedSlots[serviceId] = [];
      }
      groupedSlots[serviceId]!.add(slot);
    }

    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        width: 600,
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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy').format(widget.selectedDate),
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close, color: Colors.blue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Text(
                          'Date: ${DateFormat('MMM d, yyyy').format(widget.selectedDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Text(
                          'Total Slots: ${_slots.length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.green.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Text(
                          'Available: ${_slots.where((slot) {
                            final booked = slot['booked_patients'] as int? ?? 0;
                            return slot['is_available'] == true && booked == 0;
                          }).length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.orange.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Text(
                          'Booked: ${_slots.where((slot) {
                            final booked = slot['booked_patients'] as int? ?? 0;
                            return booked >= 1;
                          }).length}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Slot Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Service groups
                    for (var entry in groupedSlots.entries)
                      _buildServiceSection(entry.key, entry.value, context),
                  ],
                ),
              ),
            ),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Close'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceSection(int? serviceId, List<Map<String, dynamic>> serviceSlots, BuildContext context) {
    // Get service name if possible
    String serviceName = 'Service ID: $serviceId';
    if (serviceId == 1) serviceName = 'Immunization';
    if (serviceId == 2) serviceName = 'Maternal Care';

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(
              serviceName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          const SizedBox(height: 12),
          
          // Slot cards
          for (var slot in serviceSlots)
            _buildSlotCard(slot, context),
        ],
      ),
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot, BuildContext context) {
    final isAvailable = slot['is_available'] == 1 || slot['is_available'] == true;
    final bookedPatients = slot['booked_patients'] as int? ?? 0;

    Color cardColor = Colors.grey.shade50;
    Color borderColor = Colors.grey.shade300;
    Color statusColor = Colors.grey.shade600;
    String statusText = 'Available';

    if (!isAvailable) {
      cardColor = Colors.red.shade50;
      borderColor = Colors.red.shade300;
      statusColor = Colors.red.shade700;
      statusText = 'Unavailable';
    } else if (bookedPatients >= 1) {
      cardColor = Colors.orange.shade50;
      borderColor = Colors.orange.shade300;
      statusColor = Colors.orange.shade700;
      statusText = 'Booked';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatTime(slot['start_time'])} - ${_formatTime(slot['end_time'])}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Interval: ${slot['slot_duration_minutes']} min',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Delete button
                  _deletingSlotIds.contains(slot['id'])
                      ? const SizedBox(
                          width: 32,
                          height: 32,
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
                            ),
                          ),
                        )
                      : InkWell(
                          onTap: () => _handleDeleteSlot(slot),
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              size: 18,
                              color: Colors.red.shade600,
                            ),
                          ),
                        ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoChip(Icons.schedule, '${slot['slot_duration_minutes']} min', Colors.blue.shade100, Colors.blue.shade700),
              const SizedBox(width: 8),
              _buildInfoChip(
                bookedPatients >= 1 ? Icons.person_off : Icons.person,
                bookedPatients >= 1 ? 'Booked' : 'Available',
                bookedPatients >= 1 ? Colors.red.shade100 : Colors.green.shade100,
                bookedPatients >= 1 ? Colors.red.shade700 : Colors.green.shade700,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: bgColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(String? timeString) {
    if (timeString == null) return '--:--';
    
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final period = hour >= 12 ? 'PM' : 'AM';
        final displayHour = hour % 12 == 0 ? 12 : hour % 12;
        return "${displayHour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period";
      }
    } catch (e) {
      // Handle parsing errors
    }
    return timeString;
  }
}