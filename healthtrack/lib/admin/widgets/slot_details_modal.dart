import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../services/api_config.dart';
import '../../services/appointment_slot_service.dart';
import '../../admin/services/admin_session_storage.dart';
import '../../utils/message_utils.dart';
import 'reschedule_date_modal.dart';
import 'edit_slot_config_modal.dart';

/// Per-date slot detail modal.
///
/// On open it calls GET /appointment-slots/date-detail to get the enriched
/// slot list (with patient/appointment info for booked slots), then renders:
///   • Summary: Total / Available / Booked / Fully Booked counts
///   • Per-slot cards showing time, status, and (if booked) patient name + appt ref
///   • Action bar: Reschedule Date | Edit Slot Config | (per-slot) Delete
class SlotDetailsModal extends StatefulWidget {
  final DateTime selectedDate;

  /// Initial slot list passed from the calendar (used for first render while
  /// the enriched detail loads).
  final List<Map<String, dynamic>> slots;
  final int? serviceId;
  final String? serviceName;
  final Function()? onSlotsUpdated;

  const SlotDetailsModal({
    super.key,
    required this.selectedDate,
    required this.slots,
    this.serviceId,
    this.serviceName,
    this.onSlotsUpdated,
  });

  @override
  State<SlotDetailsModal> createState() => _SlotDetailsModalState();
}

class _SlotDetailsModalState extends State<SlotDetailsModal> {
  // ── State ──────────────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _slots = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _loadError = '';
  final Set<int> _deletingSlotIds = {};

  // ── Helpers ────────────────────────────────────────────────────────────────
  String get _dateStr =>
      DateFormat('yyyy-MM-dd').format(widget.selectedDate);

  String get _serviceName =>
      widget.serviceName ??
      (_slots.isNotEmpty
          ? (_slots.first['service_name'] as String? ?? _resolveServiceName())
          : _resolveServiceName());

  String _resolveServiceName() {
    final id = widget.serviceId;
    if (id == 1) return 'Immunization';
    if (id == 2) return 'Maternal Care';
    return 'Service ${id ?? '?'}';
  }

  int get _totalSlots  => (_summary['total']  as int?) ?? _slots.length;
  int get _available   => (_summary['available']   as int?) ?? 0;
  int get _booked      => (_summary['booked']      as int?) ?? 0;
  int get _fullyBooked => (_summary['fully_booked'] as int?) ?? 0;

  // ── Init ───────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    // Start with the fast path (slots already passed in from calendar)
    _slots = List<Map<String, dynamic>>.from(widget.slots);
    _computeSummaryFromSlots();
    // Then load enriched detail (patient names etc.)
    if (widget.serviceId != null) {
      _loadDetail();
    } else {
      setState(() => _isLoading = false);
    }
  }

  void _computeSummaryFromSlots() {
    int available = 0, booked = 0, fullyBooked = 0;
    for (final s in _slots) {
      final bc  = _intVal(s['booked_count'] ?? s['booked_patients']);
      final cap = _intVal(s['capacity'] ?? s['max_patients'], fallback: 1);
      final avail = (s['is_available'] == 1 || s['is_available'] == true);
      if (avail && bc < cap) available++;
      if (bc > 0) booked++;
      if (bc >= cap) fullyBooked++;
    }
    _summary = {
      'total':        _slots.length,
      'available':    available,
      'booked':       booked,
      'fully_booked': fullyBooked,
    };
  }

  Future<void> _loadDetail() async {
    setState(() {
      _isLoading  = true;
      _loadError  = '';
    });
    try {
      final detail = await AppointmentSlotService.getDateDetail(
        serviceId: widget.serviceId!,
        date:      _dateStr,
      );
      if (!mounted) return;
      setState(() {
        _slots   = List<Map<String, dynamic>>.from(
            (detail['slots'] as List?) ?? _slots);
        _summary = Map<String, dynamic>.from(
            (detail['summary'] as Map?) ?? _summary);
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _loadError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  // ── Delete a single slot ──────────────────────────────────────────────────
  Future<void> _handleDeleteSlot(Map<String, dynamic> slot) async {
    final int slotId   = slot['id'] as int;
    final String time  = _formatTime(slot['slot_time'] ?? slot['start_time']);
    final int bc       = _intVal(slot['booked_count'] ?? slot['booked_patients']);

    // ── Step 1: Check live bookings from backend before confirming ────────────
    // Use the enriched appointment list already loaded into the slot map when
    // available; otherwise fall back to a quick API check.
    List<Map<String, dynamic>> activeBookings = [];

    final inMemoryAppts = (slot['appointments'] as List?)
        ?.map((a) => Map<String, dynamic>.from(a as Map))
        .toList();

    if (inMemoryAppts != null && inMemoryAppts.isNotEmpty) {
      activeBookings = inMemoryAppts;
    } else if (bc > 0) {
      // booked_count says there are bookings but we don't have patient detail yet
      try {
        final bookingData = await AppointmentSlotService.getSlotBookings(slotId);
        final rawList = bookingData['appointments'] as List?;
        if (rawList != null) {
          activeBookings = rawList
              .map((a) => Map<String, dynamic>.from(a as Map))
              .toList();
        }
      } catch (_) {
        // Non-fatal — we still show a generic warning
      }
    }

    final hasBookings = activeBookings.isNotEmpty;

    // ── Step 2: Show booking-aware confirmation dialog ────────────────────────
    final confirmed = await _showDeleteConfirmDialog(
      time:         time,
      hasBookings:  hasBookings,
      bookings:     activeBookings,
    );
    if (!confirmed || !mounted) return;

    setState(() => _deletingSlotIds.add(slotId));

    try {
      final headers = await AdminSessionStorage.authHeaders();
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/appointment-slots/$slotId'),
        headers: headers,
      ).timeout(const Duration(seconds: 20));

      if (!mounted) return;
      final body = json.decode(response.body);

      if (response.statusCode == 200 && body['success'] == true) {
        final cancelledCount =
            (body['data']?['appointmentsCancelled'] as int?) ?? 0;

        setState(() {
          _slots.removeWhere((s) => s['id'] == slotId);
          _deletingSlotIds.remove(slotId);
          _computeSummaryFromSlots();
        });

        final msg = cancelledCount > 0
            ? 'Slot deleted. $cancelledCount patient appointment(s) cancelled and notified.'
            : 'Slot deleted successfully.';
        MessageUtils.showSuccessMessage(context, msg, title: 'Deleted');

        widget.onSlotsUpdated?.call();

        // Auto-close the modal if no slots remain
        if (_slots.isEmpty && mounted) {
          Navigator.of(context).pop();
        }
      } else {
        throw Exception(body['message'] ?? 'Failed to delete slot');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _deletingSlotIds.remove(slotId));
      MessageUtils.showErrorMessage(
          context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Booking-aware delete confirmation dialog.
  Future<bool> _showDeleteConfirmDialog({
    required String time,
    required bool hasBookings,
    required List<Map<String, dynamic>> bookings,
  }) async {
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: Row(children: [
              Icon(Icons.warning_amber_rounded,
                  color: hasBookings ? Colors.red : Colors.orange, size: 24),
              const SizedBox(width: 10),
              Text(hasBookings ? 'Delete Booked Slot' : 'Delete Slot'),
            ]),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delete the $time slot?',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                if (hasBookings) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Icon(Icons.people,
                              color: Colors.red.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '${bookings.length} active booking(s) will be cancelled',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.red.shade800),
                          ),
                        ]),
                        const SizedBox(height: 8),
                        ...bookings.take(3).map((b) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(children: [
                                const Icon(Icons.person_outline,
                                    size: 13, color: Colors.grey),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    b['patient_name'] as String? ?? 'Unknown',
                                    style: const TextStyle(fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ]),
                            )),
                        if (bookings.length > 3)
                          Text(
                            '+ ${bookings.length - 3} more',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey.shade600),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Each patient will receive an in-app notification automatically.',
                          style: TextStyle(
                              fontSize: 12, color: Colors.red.shade700),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: const Row(children: [
                      Icon(Icons.info_outline, size: 15, color: Colors.grey),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This slot has no active bookings. It will be permanently removed.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ),
                    ]),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: Text(hasBookings ? 'Delete & Cancel Booking' : 'Delete'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  // ── Open Reschedule Date modal ────────────────────────────────────────────
  void _openRescheduleDateModal() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => RescheduleDateModal(
        sourceDate:  widget.selectedDate,
        serviceId:   widget.serviceId!,
        serviceName: _serviceName,
        totalSlots:  _totalSlots,
        bookedCount: _booked,
        onRescheduled: () {
          widget.onSlotsUpdated?.call();
          if (mounted) Navigator.of(context).pop(); // close this modal too
        },
      ),
    );
  }

  // ── Open Edit Slot Config modal ───────────────────────────────────────────
  void _openEditConfigModal() {
    // Derive pre-fill values from first slot if available
    TimeOfDay startTime = const TimeOfDay(hour: 9,  minute: 0);
    TimeOfDay endTime   = const TimeOfDay(hour: 17, minute: 0);
    int duration = 30;

    if (_slots.isNotEmpty) {
      final firstSlotTime =
          _slots.first['slot_time'] ?? _slots.first['start_time'];
      if (firstSlotTime != null) {
        final parts = (firstSlotTime as String).split(':');
        if (parts.length >= 2) {
          startTime = TimeOfDay(
              hour:   int.tryParse(parts[0]) ?? 9,
              minute: int.tryParse(parts[1]) ?? 0);
        }
      }
      final lastSlotTime =
          _slots.last['slot_time'] ?? _slots.last['start_time'];
      final dur = _intVal(
          _slots.first['slot_duration_minutes'],
          fallback: 30);
      if (lastSlotTime != null) {
        final parts = (lastSlotTime as String).split(':');
        if (parts.length >= 2) {
          final lastH = int.tryParse(parts[0]) ?? 17;
          final lastM = int.tryParse(parts[1]) ?? 0;
          // end = last slot start + duration
          final endTotalMin = lastH * 60 + lastM + dur;
          endTime = TimeOfDay(
              hour:   endTotalMin ~/ 60,
              minute: endTotalMin  % 60);
        }
      }
      duration = dur;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSlotConfigModal(
        date:               widget.selectedDate,
        serviceId:          widget.serviceId!,
        serviceName:        _serviceName,
        initialStartTime:   startTime,
        initialEndTime:     endTime,
        initialDuration:    duration,
        currentSlotCount:   _totalSlots,
        currentBookedCount: _booked,
        onEdited: () {
          widget.onSlotsUpdated?.call();
          if (mounted) {
            // Reload detail to reflect new slot grid
            _loadDetail();
          }
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  680,
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            Expanded(child: _buildBody()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, MMMM d, yyyy')
                      .format(widget.selectedDate),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.blue),
                tooltip: 'Close',
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Summary chips
          _isLoading
              ? const SizedBox(
                  height: 28,
                  width: 28,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: [
                    _Chip('Total: $_totalSlots',  Colors.blue,   icon: Icons.grid_view),
                    const SizedBox(width: 8),
                    _Chip('Available: $_available', Colors.green, icon: Icons.check_circle_outline),
                    const SizedBox(width: 8),
                    _Chip('Booked: $_booked',      Colors.orange, icon: Icons.person),
                    if (_fullyBooked > 0) ...[
                      const SizedBox(width: 8),
                      _Chip('Full: $_fullyBooked', Colors.red, icon: Icons.block),
                    ],
                  ]),
                ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_loadError.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  color: Colors.red.shade300, size: 40),
              const SizedBox(height: 12),
              Text(_loadError,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700)),
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: _loadDetail,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: Text('No slots found for this date.',
              style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    // Group by service_id
    final grouped = <int?, List<Map<String, dynamic>>>{};
    for (final s in _slots) {
      grouped.putIfAbsent(s['service_id'] as int?, () => []).add(s);
    }

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        for (final entry in grouped.entries)
          _buildServiceGroup(entry.key, entry.value),
      ],
    );
  }

  Widget _buildServiceGroup(
      int? svcId, List<Map<String, dynamic>> svcSlots) {
    final name = svcSlots.first['service_name'] as String? ??
        (svcId == 1
            ? 'Immunization'
            : svcId == 2
                ? 'Maternal Care'
                : 'Service $svcId');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Text(name,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade800)),
          ),
        ]),
        const SizedBox(height: 10),
        ...svcSlots.map((slot) => _buildSlotCard(slot)),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSlotCard(Map<String, dynamic> slot) {
    final slotId    = slot['id'] as int? ?? 0;
    final slotTime  = slot['slot_time'] ?? slot['start_time'] as String?;
    final duration  = _intVal(slot['slot_duration_minutes'], fallback: 0);
    final bc        = _intVal(slot['booked_count'] ?? slot['booked_patients']);
    final cap       = _intVal(slot['capacity'] ?? slot['max_patients'], fallback: 1);
    final isAvail   = slot['is_available'] == 1 || slot['is_available'] == true;

    // Status
    final bool isBooked    = bc > 0;
    final bool isFullyBook = bc >= cap;

    Color cardBg, border, statusColor;
    String statusText;
    IconData statusIcon;

    if (!isAvail || isFullyBook) {
      cardBg = Colors.red.shade50;
      border = Colors.red.shade300;
      statusColor = Colors.red.shade700;
      statusText  = 'Fully Booked';
      statusIcon  = Icons.block;
    } else if (isBooked) {
      cardBg = Colors.orange.shade50;
      border = Colors.orange.shade300;
      statusColor = Colors.orange.shade700;
      statusText  = 'Partially Booked';
      statusIcon  = Icons.person;
    } else {
      cardBg = Colors.green.shade50;
      border = Colors.green.shade200;
      statusColor = Colors.green.shade700;
      statusText  = 'Available';
      statusIcon  = Icons.check_circle_outline;
    }

    // Linked appointments (from enriched detail endpoint)
    final appointments = (slot['appointments'] as List?)
            ?.map((a) => Map<String, dynamic>.from(a as Map))
            .toList() ??
        [];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          // ── Slot header row ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            child: Row(
              children: [
                // Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatTime(slotTime),
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      if (duration > 0)
                        Text('$duration min',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600)),
                    ],
                  ),
                ),

                // Status badge
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: statusColor.withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon,
                          size: 13, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: statusColor)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Delete button
                _deletingSlotIds.contains(slotId)
                    ? const SizedBox(
                        width: 30,
                        height: 30,
                        child: Padding(
                          padding: EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.red),
                          ),
                        ),
                      )
                    : InkWell(
                        onTap: () => _handleDeleteSlot(slot),
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: Colors.red.shade200),
                          ),
                          child: Icon(Icons.delete_outline,
                              size: 16,
                              color: Colors.red.shade600),
                        ),
                      ),
              ],
            ),
          ),

          // ── Booked appointment rows ──────────────────────────────────────
          if (appointments.isNotEmpty) ...[
            Divider(
                height: 1,
                thickness: 1,
                color: border.withValues(alpha: 0.5)),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Booked Patients',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade600,
                          letterSpacing: 0.4)),
                  const SizedBox(height: 6),
                  ...appointments
                      .map((a) => _buildAppointmentRow(a)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAppointmentRow(Map<String, dynamic> appt) {
    final patientName   = appt['patient_name'] as String? ?? 'Unknown';
    final apptId        = appt['appointment_id'];
    final apptType      = appt['appointment_type'] as String? ?? '';
    final apptStatus    = appt['status'] as String? ?? '';

    Color statusColor = Colors.orange.shade700;
    if (apptStatus == 'approved')    statusColor = Colors.green.shade700;
    if (apptStatus == 'rescheduled') statusColor = Colors.blue.shade700;
    if (apptStatus == 'cancelled')   statusColor = Colors.red.shade700;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.person,
                size: 15, color: Colors.orange.shade700),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(patientName,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis),
                if (apptType.isNotEmpty)
                  Text(apptType,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600)),
              ],
            ),
          ),
          // Status + ID
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  apptStatus,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: statusColor),
                ),
              ),
              if (apptId != null)
                Text('#$apptId',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade400)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    final hasServiceId = widget.serviceId != null;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius:
            const BorderRadius.vertical(bottom: Radius.circular(16)),
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          // ── Action buttons (left side) ───────────────────────────────────
          if (hasServiceId && !_isLoading && _slots.isNotEmpty) ...[
            // Reschedule Date
            Tooltip(
              message: 'Move all slots to a different date',
              child: OutlinedButton.icon(
                onPressed: _openRescheduleDateModal,
                icon: const Icon(Icons.calendar_month, size: 16),
                label: const Text('Reschedule Date',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.indigo,
                  side: const BorderSide(color: Colors.indigo),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
            const SizedBox(width: 10),

            // Edit Slot Config
            Tooltip(
              message: 'Change time range or slot duration',
              child: OutlinedButton.icon(
                onPressed: _openEditConfigModal,
                icon:
                    const Icon(Icons.edit_calendar, size: 16),
                label: const Text('Edit Config',
                    style: TextStyle(fontSize: 13)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.teal,
                  side: const BorderSide(color: Colors.teal),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ),
          ],

          const Spacer(),

          // ── Close (right side) ───────────────────────────────────────────
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  // ── Utility ────────────────────────────────────────────────────────────────
  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '--:--';
    try {
      final parts = t.split(':');
      if (parts.length >= 2) {
        final h = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        final pm = h >= 12;
        final dh = h % 12 == 0 ? 12 : h % 12;
        return '${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} ${pm ? 'PM' : 'AM'}';
      }
    } catch (_) {}
    return t;
  }

  int _intVal(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }
}

// ── Summary chip helper ───────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  final String label;
  final MaterialColor color;
  final IconData icon;

  const _Chip(this.label, this.color, {required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color:  color.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color.shade700),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: color.shade800)),
        ],
      ),
    );
  }
}
