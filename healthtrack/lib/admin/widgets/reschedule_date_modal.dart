import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_slot_service.dart';
import '../../utils/message_utils.dart';

/// Modal that lets an admin bulk-move all slots from [sourceDate] to a new date.
///
/// Shows:
///   • Summary of what will move (slot count, booked count)
///   • Date picker for the target date
///   • Conflict warning if the target already has slots
///   • Confirmation step before executing
class RescheduleDateModal extends StatefulWidget {
  final DateTime sourceDate;
  final int serviceId;
  final String serviceName;
  final int totalSlots;
  final int bookedCount;

  /// Called when the reschedule completes successfully so the parent can refresh.
  final VoidCallback onRescheduled;

  const RescheduleDateModal({
    super.key,
    required this.sourceDate,
    required this.serviceId,
    required this.serviceName,
    required this.totalSlots,
    required this.bookedCount,
    required this.onRescheduled,
  });

  @override
  State<RescheduleDateModal> createState() => _RescheduleDateModalState();
}

class _RescheduleDateModalState extends State<RescheduleDateModal> {
  DateTime? _targetDate;
  bool _isRescheduling = false;
  bool _showConfirmStep = false;

  String get _sourceDateStr =>
      DateFormat('yyyy-MM-dd').format(widget.sourceDate);

  String get _targetDateStr =>
      _targetDate == null ? '' : DateFormat('yyyy-MM-dd').format(_targetDate!);

  Future<void> _pickTargetDate() async {
    final firstAllowed = DateTime.now().add(const Duration(days: 1));
    final picked = await showDatePicker(
      context: context,
      initialDate: firstAllowed,
      firstDate: firstAllowed,
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: 'Select new date for all slots',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _targetDate = DateTime(picked.year, picked.month, picked.day);
        _showConfirmStep = false; // reset confirm if date changes
      });
    }
  }

  Future<void> _execute() async {
    if (_targetDate == null) return;
    setState(() => _isRescheduling = true);

    try {
      final result = await AppointmentSlotService.rescheduleDate(
        serviceId: widget.serviceId,
        fromDate:  _sourceDateStr,
        toDate:    _targetDateStr,
      );

      if (!mounted) return;
      setState(() => _isRescheduling = false);

      final slotsCount = result['data']?['slots_moved'] ?? widget.totalSlots;
      final apptCount  = result['data']?['appointments_updated'] ?? 0;

      MessageUtils.showSuccessMessage(
        context,
        '$slotsCount slot(s) moved to ${DateFormat('MMM d, yyyy').format(_targetDate!)}.'
        '${apptCount > 0 ? ' $apptCount patient(s) notified.' : ''}',
        title: 'Rescheduled',
      );

      widget.onRescheduled();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isRescheduling = false);

      final msg = e.toString().replaceFirst('Exception: ', '');
      // Conflict has extra detail — show a richer dialog
      if (msg.toLowerCase().contains('conflict') ||
          msg.toLowerCase().contains('overlap') ||
          msg.toLowerCase().contains('already has')) {
        _showConflictDialog(msg);
      } else {
        MessageUtils.showErrorMessage(context, msg);
      }
    }
  }

  void _showConflictDialog(String detail) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Row(children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange),
          SizedBox(width: 8),
          Text('Date Conflict'),
        ]),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.indigo.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.calendar_month,
                        color: Colors.indigo.shade700, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Reschedule Entire Date',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(
                          'Move all slots from ${DateFormat('MMM d, yyyy').format(widget.sourceDate)}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _isRescheduling
                        ? null
                        : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),

            // ── Body ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary chips
                  _SummaryRow(
                    sourceDate:  widget.sourceDate,
                    serviceName: widget.serviceName,
                    totalSlots:  widget.totalSlots,
                    bookedCount: widget.bookedCount,
                  ),
                  const SizedBox(height: 20),

                  // Target date picker
                  const Text('New Date',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  InkWell(
                    onTap: _isRescheduling ? null : _pickTargetDate,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: _targetDate != null
                              ? Colors.indigo
                              : Colors.grey.shade300,
                          width: _targetDate != null ? 1.5 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: _targetDate != null
                            ? Colors.indigo.shade50
                            : Colors.grey.shade50,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.event,
                            color: _targetDate != null
                                ? Colors.indigo
                                : Colors.grey.shade400,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _targetDate != null
                                ? DateFormat('EEEE, MMMM d, yyyy')
                                    .format(_targetDate!)
                                : 'Tap to pick a date',
                            style: TextStyle(
                              fontSize: 14,
                              color: _targetDate != null
                                  ? Colors.indigo.shade800
                                  : Colors.grey.shade500,
                              fontWeight: _targetDate != null
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.grey.shade400),
                        ],
                      ),
                    ),
                  ),

                  // Booked warning
                  if (widget.bookedCount > 0) ...[
                    const SizedBox(height: 16),
                    _WarningBanner(
                      message:
                          '${widget.bookedCount} booked appointment(s) will be '
                          'moved to the new date and patients will receive an '
                          'in-app notification automatically.',
                    ),
                  ],

                  // Confirm step
                  if (_showConfirmStep && _targetDate != null) ...[
                    const SizedBox(height: 16),
                    _ConfirmBanner(
                      sourceDateStr: DateFormat('MMM d, yyyy')
                          .format(widget.sourceDate),
                      targetDateStr:
                          DateFormat('MMM d, yyyy').format(_targetDate!),
                      slotsCount:  widget.totalSlots,
                      apptCount:   widget.bookedCount,
                    ),
                  ],
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border: Border(
                    top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isRescheduling
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  if (!_showConfirmStep)
                    ElevatedButton.icon(
                      onPressed: _targetDate == null
                          ? null
                          : () => setState(() => _showConfirmStep = true),
                      icon: const Icon(Icons.arrow_forward, size: 18),
                      label: const Text('Review & Confirm'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isRescheduling ? null : _execute,
                      icon: _isRescheduling
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white)),
                            )
                          : const Icon(Icons.check, size: 18),
                      label: Text(_isRescheduling
                          ? 'Rescheduling...'
                          : 'Confirm Reschedule'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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
}

// ── Internal sub-widgets ─────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  final DateTime sourceDate;
  final String serviceName;
  final int totalSlots;
  final int bookedCount;

  const _SummaryRow({
    required this.sourceDate,
    required this.serviceName,
    required this.totalSlots,
    required this.bookedCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, size: 15, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text('What will be moved',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700)),
          ]),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              _Chip(
                  label:
                      DateFormat('MMM d, yyyy').format(sourceDate),
                  icon: Icons.calendar_today,
                  color: Colors.blue),
              _Chip(
                  label: serviceName,
                  icon: Icons.medical_services_outlined,
                  color: Colors.teal),
              _Chip(
                  label: '$totalSlots slot(s)',
                  icon: Icons.access_time,
                  color: Colors.indigo),
              if (bookedCount > 0)
                _Chip(
                    label: '$bookedCount booked',
                    icon: Icons.person,
                    color: Colors.orange),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _Chip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.shade200),
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

class _WarningBanner extends StatelessWidget {
  final String message;
  const _WarningBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.notifications_active_outlined,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade900,
                    height: 1.4)),
          ),
        ],
      ),
    );
  }
}

class _ConfirmBanner extends StatelessWidget {
  final String sourceDateStr;
  final String targetDateStr;
  final int slotsCount;
  final int apptCount;

  const _ConfirmBanner({
    required this.sourceDateStr,
    required this.targetDateStr,
    required this.slotsCount,
    required this.apptCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.shade300, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.check_circle_outline,
                color: Colors.green.shade700, size: 16),
            const SizedBox(width: 6),
            Text('Please confirm',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                    fontSize: 13)),
          ]),
          const SizedBox(height: 8),
          Text(
            'Move $slotsCount slot(s) from $sourceDateStr → $targetDateStr.'
            '${apptCount > 0 ? '\n$apptCount patient(s) will be notified automatically.' : ''}',
            style: TextStyle(
                fontSize: 13,
                color: Colors.green.shade900,
                height: 1.5),
          ),
        ],
      ),
    );
  }
}
