import 'package:flutter/material.dart';

// ─── Reason data model ────────────────────────────────────────────────────────

class AppointmentReason {
  final String code;
  final String label;
  final String patientLabel; // plain-language sentence shown to patient
  final Set<int>? onlyForServiceIds; // null = all services

  const AppointmentReason({
    required this.code,
    required this.label,
    required this.patientLabel,
    this.onlyForServiceIds,
  });
}

class AppointmentReasonData {
  AppointmentReasonData._();

  // Service ID constants (must match DB services_config.id)
  static const int _immunization  = 1;
  static const int _maternalCare  = 2;

  static const List<AppointmentReason> all = [
    AppointmentReason(
      code:         'clinic_closed',
      label:        'Clinic Closed / Holiday',
      patientLabel: 'The clinic will be closed on that date.',
    ),
    AppointmentReason(
      code:         'staff_unavailable',
      label:        'Health Worker / Staff Unavailable',
      patientLabel: 'Staff availability adjustment.',
    ),
    AppointmentReason(
      code:         'facility_maintenance',
      label:        'Facility Maintenance / Repair',
      patientLabel: 'Facility maintenance or repair work is scheduled.',
    ),
    AppointmentReason(
      code:         'vaccine_shortage',
      label:        'Vaccine / Supply Shortage',
      patientLabel: 'Vaccine or supply shortage for this service.',
      onlyForServiceIds: {_immunization},
    ),
    AppointmentReason(
      code:         'overbooking',
      label:        'High Patient Volume / Overbooking Adjustment',
      patientLabel: 'High patient volume or overbooking adjustment.',
    ),
    AppointmentReason(
      code:         'weather_calamity',
      label:        'Weather / Calamity Disruption',
      patientLabel: 'Weather or calamity disruption.',
    ),
    AppointmentReason(
      code:         'prenatal_staff',
      label:        'Prenatal Staff Unavailable',
      patientLabel: 'Prenatal staff unavailability adjustment.',
      onlyForServiceIds: {_maternalCare},
    ),
    AppointmentReason(
      code:         'service_discontinued',
      label:        'Service Discontinued for This Date',
      patientLabel: 'This service session has been discontinued for that date.',
    ),
    AppointmentReason(
      code:         'other',
      label:        'Other (specify)',
      patientLabel: '', // filled from free-text
    ),
  ];

  /// Returns the subset visible for [serviceId]. If null, returns all.
  static List<AppointmentReason> forService(int? serviceId) {
    if (serviceId == null) return all;
    return all
        .where((r) =>
            r.onlyForServiceIds == null ||
            r.onlyForServiceIds!.contains(serviceId))
        .toList();
  }
}

// ─── ReasonSelector widget ────────────────────────────────────────────────────
//
// Renders:
//   • A labelled dropdown with service-aware options.
//   • If "Other" is selected, a required free-text input appears.
//   • Exposes [selectedCode] and [otherNote] for the parent to read.
//   • [onChanged] fires whenever either field changes so the parent can
//     re-evaluate whether all required fields are filled.

class ReasonSelector extends StatefulWidget {
  /// Service ID — used to filter service-specific reasons.
  final int? serviceId;

  /// Fired whenever the reason selection or note changes.
  final VoidCallback onChanged;

  /// Read these after [onChanged] to get current values.
  final ReasonSelectorController controller;

  const ReasonSelector({
    super.key,
    this.serviceId,
    required this.onChanged,
    required this.controller,
  });

  @override
  State<ReasonSelector> createState() => _ReasonSelectorState();
}

class _ReasonSelectorState extends State<ReasonSelector> {
  late final List<AppointmentReason> _options;
  AppointmentReason? _selected;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    _options  = AppointmentReasonData.forService(widget.serviceId);
    _noteCtrl = TextEditingController();
    _noteCtrl.addListener(_onNoteChanged);
  }

  @override
  void dispose() {
    _noteCtrl.removeListener(_onNoteChanged);
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onNoteChanged() {
    widget.controller._update(
      code: _selected?.code,
      note: _noteCtrl.text.trim(),
    );
    widget.onChanged();
  }

  void _onReasonSelected(AppointmentReason? r) {
    setState(() => _selected = r);
    if (r?.code != 'other') _noteCtrl.clear();
    widget.controller._update(
      code: r?.code,
      note: r?.code == 'other' ? _noteCtrl.text.trim() : null,
    );
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final isOther = _selected?.code == 'other';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Label ──────────────────────────────────────────────────────────
        Row(children: [
          const Text(
            'Reason',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
          const SizedBox(width: 4),
          Text(
            '(required)',
            style: TextStyle(fontSize: 12, color: Colors.red.shade600),
          ),
        ]),
        const SizedBox(height: 8),

        // ── Dropdown ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: _selected != null ? Colors.blue.shade50 : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _selected != null ? Colors.blue.shade300 : Colors.grey.shade300,
              width: _selected != null ? 1.5 : 1.0,
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<AppointmentReason>(
              isExpanded: true,
              value: _selected,
              hint: Text(
                'Select a reason…',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              items: _options.map((r) {
                return DropdownMenuItem<AppointmentReason>(
                  value: r,
                  child: Text(r.label, style: const TextStyle(fontSize: 14)),
                );
              }).toList(),
              onChanged: _onReasonSelected,
            ),
          ),
        ),

        // ── "Other" free-text input ────────────────────────────────────────
        if (isOther) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _noteCtrl,
            autofocus: true,
            maxLines: 2,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Describe the reason…',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              filled: true,
              fillColor: Colors.grey.shade50,
              counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Colors.blue, width: 1.5),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── Controller ──────────────────────────────────────────────────────────────
//
// Create one instance per usage site, pass to [ReasonSelector].
// After [onChanged] fires, read [isValid], [code], and [note].

class ReasonSelectorController {
  String? _code;
  String? _note;

  void _update({String? code, String? note}) {
    _code = code;
    _note = note;
  }

  /// Currently selected reason code (null if nothing selected).
  String? get code => _code;

  /// Free-text note when code == 'other'. Null otherwise.
  String? get note => (_code == 'other') ? _note : null;

  /// True when a reason has been selected AND (if "other") the note is non-empty.
  bool get isValid {
    if (_code == null || _code!.isEmpty) return false;
    if (_code == 'other') return _note != null && _note!.isNotEmpty;
    return true;
  }

  /// Reset back to unselected state.
  void reset() {
    _code = null;
    _note = null;
  }
}
