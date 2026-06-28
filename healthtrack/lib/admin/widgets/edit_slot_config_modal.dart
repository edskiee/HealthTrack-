import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/appointment_slot_service.dart';
import '../../utils/message_utils.dart';

/// Modal for editing the slot configuration (time range / duration) of an
/// already-generated date.
///
/// Displaced bookings (slots that no longer exist in the new grid) are handled
/// server-side — their appointments are marked 'rescheduled' and the patient
/// receives an in-app notification.  The response from the server tells us how
/// many were displaced so we can surface a follow-up warning.
class EditSlotConfigModal extends StatefulWidget {
  final DateTime date;
  final int serviceId;
  final String serviceName;

  /// Pre-fill with the config that was used to generate this date's slots.
  final TimeOfDay initialStartTime;
  final TimeOfDay initialEndTime;
  final int initialDuration;

  final int currentSlotCount;
  final int currentBookedCount;

  /// Called after a successful edit so the parent can refresh.
  final VoidCallback onEdited;

  const EditSlotConfigModal({
    super.key,
    required this.date,
    required this.serviceId,
    required this.serviceName,
    required this.initialStartTime,
    required this.initialEndTime,
    required this.initialDuration,
    required this.currentSlotCount,
    required this.currentBookedCount,
    required this.onEdited,
  });

  @override
  State<EditSlotConfigModal> createState() => _EditSlotConfigModalState();
}

class _EditSlotConfigModalState extends State<EditSlotConfigModal> {
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late TextEditingController _durationCtrl;
  int? _duration;
  String _validationError = '';
  int _calculatedSlots = 0;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _startTime = widget.initialStartTime;
    _endTime   = widget.initialEndTime;
    _duration  = widget.initialDuration;
    _durationCtrl = TextEditingController(
        text: widget.initialDuration.toString());
    _recalculate();
  }

  @override
  void dispose() {
    _durationCtrl.dispose();
    super.dispose();
  }

  void _recalculate() {
    setState(() {
      _validationError = '';
      _calculatedSlots = 0;
    });

    if (_duration == null || _duration! <= 0) {
      setState(() => _validationError = 'Enter a valid duration');
      return;
    }

    final startMin = _startTime.hour * 60 + _startTime.minute;
    final endMin   = _endTime.hour   * 60 + _endTime.minute;

    if (startMin >= endMin) {
      setState(() => _validationError = 'End time must be after start time');
      return;
    }

    if (startMin < 8 * 60) {
      setState(() => _validationError = 'Start cannot be before 8:00 AM');
      return;
    }

    if (endMin > 18 * 60) {
      setState(() => _validationError = 'End cannot be after 6:00 PM');
      return;
    }

    final slots = (endMin - startMin) ~/ _duration!;
    if (slots <= 0) {
      setState(() => _validationError = 'Range too short for this duration');
      return;
    }
    if (slots > 100) {
      setState(
          () => _validationError = 'Would generate >100 slots — shorten range or increase duration');
      return;
    }

    setState(() => _calculatedSlots = slots);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart ? _startTime : _endTime;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: isStart ? 'Pick start time' : 'Pick end time',
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startTime = picked;
      } else {
        _endTime = picked;
      }
    });
    _recalculate();
  }

  String _fmtTime(TimeOfDay t) {
    final h   = t.hour;
    final m   = t.minute;
    final pm  = h >= 12;
    final dh  = h % 12 == 0 ? 12 : h % 12;
    return '${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} ${pm ? 'PM' : 'AM'}';
  }

  String _timeOfDayToStr(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2,'0')}:${t.minute.toString().padLeft(2,'0')}:00';

  Future<void> _save() async {
    if (_validationError.isNotEmpty || _calculatedSlots == 0) return;
    setState(() => _isSaving = true);

    try {
      final result = await AppointmentSlotService.editDateSlots(
        serviceId:            widget.serviceId,
        date:                 DateFormat('yyyy-MM-dd').format(widget.date),
        startTime:            _timeOfDayToStr(_startTime),
        endTime:              _timeOfDayToStr(_endTime),
        slotDurationMinutes:  _duration!,
      );

      if (!mounted) return;
      setState(() => _isSaving = false);

      final displaced =
          result['data']?['displaced_appointments'] as int? ?? 0;
      final newCount =
          result['data']?['new_slot_count'] as int? ?? _calculatedSlots;

      // Primary success toast
      MessageUtils.showSuccessMessage(
        context,
        '$newCount slot(s) configured for ${DateFormat('MMM d, yyyy').format(widget.date)}.',
        title: 'Slots Updated',
      );

      // Secondary warning if any appointments were displaced
      if (displaced > 0 && mounted) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: const Row(children: [
                Icon(Icons.warning_amber_rounded, color: Colors.orange),
                SizedBox(width: 8),
                Text('Follow-up Required'),
              ]),
              content: Text(
                '$displaced patient appointment(s) were displaced because '
                'their original time slot no longer exists in the new configuration.\n\n'
                'Each affected patient has been notified in-app to contact you '
                'for a new time. Please review and reassign these appointments.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange),
                  child: const Text('Understood',
                      style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          );
        });
      }

      widget.onEdited();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      MessageUtils.showErrorMessage(
          context, e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel =
        DateFormat('EEEE, MMMM d, yyyy').format(widget.date);
    final hasChanges = _startTime != widget.initialStartTime ||
        _endTime != widget.initialEndTime ||
        _duration != widget.initialDuration;
    final willReduceSlots = _calculatedSlots < widget.currentSlotCount &&
        widget.currentBookedCount > 0;

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
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.teal.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.edit_calendar,
                        color: Colors.teal.shade700, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Edit Slot Configuration',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(dateLabel,
                            style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade600)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
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
                  // Current state chip row
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _InfoChip(
                        label: widget.serviceName,
                        icon: Icons.medical_services_outlined,
                        color: Colors.teal),
                    _InfoChip(
                        label: '${widget.currentSlotCount} current slots',
                        icon: Icons.access_time,
                        color: Colors.blue),
                    if (widget.currentBookedCount > 0)
                      _InfoChip(
                          label: '${widget.currentBookedCount} booked',
                          icon: Icons.person,
                          color: Colors.orange),
                  ]),
                  const SizedBox(height: 20),

                  // ── Time range row ────────────────────────────────────────
                  const Text('Time Range',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _TimePicker(
                        label: 'Start',
                        time: _startTime,
                        onTap: () => _pickTime(isStart: true),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.arrow_forward,
                          color: Colors.grey.shade400, size: 18),
                    ),
                    Expanded(
                      child: _TimePicker(
                        label: 'End',
                        time: _endTime,
                        onTap: () => _pickTime(isStart: false),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 16),

                  // ── Duration ─────────────────────────────────────────────
                  const Text('Slot Duration (minutes)',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _durationCtrl,
                    keyboardType: TextInputType.number,
                    enabled: !_isSaving,
                    decoration: InputDecoration(
                      hintText: 'e.g. 30',
                      suffixText: 'min',
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                            color: Colors.teal, width: 1.5),
                      ),
                    ),
                    onChanged: (v) {
                      setState(() => _duration = int.tryParse(v));
                      _recalculate();
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Slot preview ─────────────────────────────────────────
                  if (_validationError.isNotEmpty)
                    _ErrorBanner(message: _validationError)
                  else if (_calculatedSlots > 0)
                    _PreviewBanner(
                      slotCount: _calculatedSlots,
                      startFmt:  _fmtTime(_startTime),
                      endFmt:    _fmtTime(_endTime),
                      duration:  _duration!,
                    ),

                  // ── Displacement warning ──────────────────────────────────
                  if (willReduceSlots) ...[
                    const SizedBox(height: 12),
                    _DisplacementWarning(
                        bookedCount: widget.currentBookedCount),
                  ],
                ],
              ),
            ),

            // ── Footer ──────────────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(16)),
                border:
                    Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: (_isSaving ||
                            _validationError.isNotEmpty ||
                            _calculatedSlots == 0 ||
                            !hasChanges)
                        ? null
                        : _save,
                    icon: _isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white),
                            ),
                          )
                        : const Icon(Icons.save, size: 18),
                    label:
                        Text(_isSaving ? 'Saving...' : 'Save Configuration'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey.shade300,
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

class _TimePicker extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;

  const _TimePicker(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h  = time.hour % 12 == 0 ? 12 : time.hour % 12;
    final m  = time.minute;
    final pm = time.hour >= 12;
    final display =
        '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} ${pm ? 'PM' : 'AM'}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(Icons.schedule,
                size: 16, color: Colors.teal.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                  Text(display,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Icon(Icons.arrow_drop_down,
                color: Colors.grey.shade400, size: 18),
          ],
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final MaterialColor color;

  const _InfoChip(
      {required this.label, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
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

class _PreviewBanner extends StatelessWidget {
  final int slotCount;
  final String startFmt;
  final String endFmt;
  final int duration;

  const _PreviewBanner({
    required this.slotCount,
    required this.startFmt,
    required this.endFmt,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.teal.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.teal.shade200),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_outline,
            color: Colors.teal.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '$slotCount slot(s) will be generated  '
            '($startFmt – $endFmt, $duration min each)',
            style: TextStyle(
                fontSize: 13,
                color: Colors.teal.shade900,
                height: 1.4),
          ),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: TextStyle(
                  fontSize: 13, color: Colors.red.shade900)),
        ),
      ]),
    );
  }
}

class _DisplacementWarning extends StatelessWidget {
  final int bookedCount;
  const _DisplacementWarning({required this.bookedCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.orange.shade300),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              color: Colors.orange.shade700, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'There are $bookedCount booked appointment(s) on this date. '
              'If the new configuration removes any of their time slots, '
              'those patients will be automatically notified to contact you '
              'for a new time.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                  height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
