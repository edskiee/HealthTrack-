import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_session.dart';
import '../services/vaccine_service.dart';
import '../services/appointment_service.dart';
import '../services/vaccine_card_pdf.dart';
import '../services/websocket_service.dart';
import '../appointments_tab.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VaccineRecordTab — embedded in HealthCardTab as "Vaccine Record" tab.
//
// Record-based schedule (panelist fix):
//   • Completed doses: show actual given date + "was supposed to be given on
//     [theoretical date]" when the two dates differ.
//   • Pending doses with a record-based due date: show that date.
//   • Locked doses (previous dose not yet completed): show
//     "Date will be set after [waitingFor] is completed" — no date shown.
//
// Data source : GET /vaccines/card/:patientId
// Realtime    : WebSocketService.vaccineRecordUpdated + 30 s poll fallback
// ─────────────────────────────────────────────────────────────────────────────

class VaccineRecordTab extends StatefulWidget {
  final int? patientIdOverride;
  const VaccineRecordTab({super.key, this.patientIdOverride});

  @override
  State<VaccineRecordTab> createState() => _VaccineRecordTabState();
}

class _VaccineRecordTabState extends State<VaccineRecordTab>
    with WidgetsBindingObserver {
  VaccineCardData? _card;
  bool _loading = true;
  String? _error;
  bool _generatingPdf = false;
  Timer? _pollTimer;
  late final void Function(Map<String, dynamic>) _wsListener;
  late final void Function(Map<String, dynamic>) _apptWsListener;

  /// Maps vaccine_schedule_id → active appointment (approved/rescheduled).
  /// Used so pending dose cards can show "Appointment Scheduled" status.
  Map<int, Map<String, dynamic>> _scheduledAppointments = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _wsListener = (_) { if (mounted) _fetchCard(silent: true); };
    _apptWsListener = (_) { if (mounted) _fetchScheduledAppointments(silent: true); };
    _initRealtime();
    _fetchCard();
    _fetchScheduledAppointments();
    _startPollTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    WebSocketService.instance.removeVaccineRecordUpdatedListener(_wsListener);
    WebSocketService.instance.removeAppointmentUpdatedListener(_apptWsListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchCard(silent: true);
      _fetchScheduledAppointments(silent: true);
    }
  }

  void _initRealtime() {
    Future.microtask(() async {
      try {
        await WebSocketService.instance.initialize();
        final uid = int.tryParse(UserSession.instance.userId) ?? 0;
        if (uid > 0) WebSocketService.instance.joinUserRoom(uid);
        WebSocketService.instance.addVaccineRecordUpdatedListener(_wsListener);
        WebSocketService.instance.addAppointmentUpdatedListener(_apptWsListener);
      } catch (e) {
        debugPrint('[VaccineRecordTab] WS init error: $e');
      }
    });
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _fetchCard(silent: true);
        _fetchScheduledAppointments(silent: true);
      }
    });
  }

  /// Loads the patient's active (approved/rescheduled) immunization appointments
  /// and builds a map of vaccine_schedule_id → appointment so that each
  /// pending dose card can show "Appointment Scheduled — {date}".
  Future<void> _fetchScheduledAppointments({bool silent = false}) async {
    final session = UserSession.instance;
    if (!session.isLoggedIn) return;
    try {
      final all = await AppointmentService.getUserAppointments(session.userId);
      // Only immunization appointments that are still active
      final active = all.where((a) {
        final status = (a['status'] ?? '').toString().toLowerCase();
        final type   = (a['appointment_type'] ?? '').toString().toLowerCase();
        return (status == 'approved' || status == 'rescheduled') &&
               type.contains('immunization');
      }).toList();

      final map = <int, Map<String, dynamic>>{};
      for (final appt in active) {
        final scheduleId = appt['linked_vaccine_schedule_id'];
        if (scheduleId != null) {
          final sid = scheduleId is int ? scheduleId : int.tryParse('$scheduleId');
          if (sid != null && sid > 0) map[sid] = appt;
        }
      }

      if (mounted) setState(() => _scheduledAppointments = map);
    } catch (e) {
      debugPrint('[VaccineRecordTab] appt fetch error: $e');
    }
  }


  Future<void> _downloadVaccineCard() async {
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);
    if (patientId <= 0) return;

    if (mounted) setState(() => _generatingPdf = true);

    // Show a non-dismissible "generating" indicator
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(children: [
            SizedBox(
              width: 16, height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ),
            SizedBox(width: 12),
            Text('Generating your vaccine card…'),
          ]),
          duration: Duration(seconds: 30),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    try {
      final success = await VaccineCardPdfService.generateAndPrint(
        fetchData: () => VaccineCardPdfService.fetchForPatient(patientId),
        context: context,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        if (!success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Unable to generate vaccine card. Please try again.'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate vaccine card. Please try again.'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }

  Future<void> _fetchCard({bool silent = false}) async {
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);
    if (patientId <= 0) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    if (!silent && mounted) setState(() { _loading = true; _error = null; });
    try {
      final card = await VaccineService.getVaccineCard(patientId);
      if (mounted) setState(() { _card = card; _loading = false; _error = null; });
    } catch (e) {
      debugPrint('[VaccineRecordTab] fetch error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Unable to load vaccine record. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);

    if (!_loading && _error == null && patientId <= 0) return _buildNoPatient(context);
    if (_loading && _card == null) return _buildSkeleton(context);

    return RefreshIndicator(
      onRefresh: () => _fetchCard(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          if (_loading && _card != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          if (_error != null) ...[
            _ErrorBanner(message: _error!, onRetry: () => _fetchCard()),
            const SizedBox(height: 12),
          ],
          if (_card != null) ...[
            // ── Download button row ──────────────────────────────────────
            Align(
              alignment: Alignment.centerRight,
              child: Semantics(
                button: true,
                label: 'Download vaccine card as PDF',
                child: OutlinedButton.icon(
                  onPressed: _generatingPdf ? null : _downloadVaccineCard,
                  icon: _generatingPdf
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 16),
                  label: Text(
                    _generatingPdf ? 'Generating…' : 'Download Card',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F766E),
                    side: const BorderSide(color: Color(0xFF0F766E)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _HeaderSummaryCard(card: _card!),
            const SizedBox(height: 16),
            if (_card!.completedDoses.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.check_circle,
                iconColor: Colors.green.shade600,
                label: 'Completed Vaccines',
                count: _card!.completedDoses.length,
              ),
              const SizedBox(height: 8),
              ..._card!.completedDoses.map((e) => _CompletedDoseCard(entry: e)),
              const SizedBox(height: 16),
            ],
            if (_card!.pendingDoses.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.pending_outlined,
                iconColor: Colors.orange.shade700,
                label: 'Pending Vaccines',
                count: _card!.pendingDoses.length,
              ),
              const SizedBox(height: 8),
              ..._card!.pendingDoses.map((d) {
                final scheduledAppt = _scheduledAppointments[d.scheduleId];
                return _PendingDoseCard(
                  dose: d,
                  scheduledAppointment: scheduledAppt,
                  onBookAppointment: (dose) => _navigateToBooking(dose),
                );
              }),
              const SizedBox(height: 16),
            ],
            if (_card!.completedDoses.isEmpty && _card!.pendingDoses.isEmpty)
              _buildEmptyState(context),
            _NextActionBanner(card: _card!),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }


  /// Opens the Appointment Booking screen pre-loaded with Immunization service
  /// and the vaccine/dose linkage from the tapped pending dose card.
  void _navigateToBooking(VaccinePendingDose dose) {
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: const Text('Book Appointment'),
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
          ),
          body: AppointmentTab(
            initialServiceName:        'Immunization',
            linkedVaccineScheduleId:   dose.scheduleId,
            linkedDoseNumber:          dose.doseNumber,
            linkedVaccineName:         dose.vaccineName,
            linkedDoseLabel:           dose.doseLabel,
            patientIdOverride:         patientId > 0 ? patientId : null,
          ),
        ),
      ),
    ).then((_) {
      // Refresh both the vaccine card and scheduled appointments when
      // the user returns (they may have just booked or cancelled).
      if (mounted) {
        _fetchCard(silent: true);
        _fetchScheduledAppointments(silent: true);
      }
    });
  }

  Widget _buildNoPatient(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.person_off_outlined, size: 52, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text('No patient record found.',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
                textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text('Please complete your profile first.',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(Icons.vaccines_outlined, size: 52, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text('No vaccines recorded yet.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text("Visit the clinic to start your child's immunization record.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: List.generate(4, (_) => _SkeletonCard()),
    );
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Header summary card
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSummaryCard extends StatelessWidget {
  final VaccineCardData card;
  const _HeaderSummaryCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final childName = card.childName.isNotEmpty ? card.childName : UserSession.instance.childName;
    final ageLabel  = _ageLabel(card.ageInDays);
    final completed = card.totalDosesCompleted;
    final total     = card.totalDosesRequired;
    final progress  = total > 0 ? completed / total : 0.0;

    final Color statusBg, statusFg;
    final IconData statusIcon;
    final String statusLabel;
    switch (card.overallStatus) {
      case 'overdue':
        statusBg    = Colors.red.shade50;   statusFg    = Colors.red.shade700;
        statusIcon  = Icons.warning_amber_rounded; statusLabel = 'Overdue vaccines';
        break;
      case 'action_needed':
        statusBg    = Colors.amber.shade50; statusFg    = Colors.amber.shade800;
        statusIcon  = Icons.notifications_active_outlined; statusLabel = 'Action needed';
        break;
      default:
        statusBg    = Colors.green.shade50; statusFg    = Colors.green.shade700;
        statusIcon  = Icons.check_circle_outline; statusLabel = 'Up to date';
    }
    final barColor = card.overallStatus == 'overdue'
        ? Colors.red.shade400
        : card.overallStatus == 'action_needed'
            ? Colors.amber.shade600
            : Colors.green.shade500;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusFg.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(childName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            if (ageLabel.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(ageLabel, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
            ],
          ])),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(statusIcon, size: 14, color: statusFg),
              const SizedBox(width: 4),
              Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('$completed of $total doses completed',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
          Text('${(progress * 100).round()}%',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: barColor)),
        ]),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress, minHeight: 8,
            backgroundColor: Colors.grey.shade100,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ]),
    );
  }

  String _ageLabel(int days) {
    if (days <= 0) return '';
    if (days < 30) return '$days days old';
    final months = days ~/ 30;
    if (months < 12) return '$months month${months == 1 ? '' : 's'} old';
    final years = months ~/ 12;
    final rem   = months % 12;
    if (rem == 0) return '$years year${years == 1 ? '' : 's'} old';
    return '$years yr${years == 1 ? '' : 's'} $rem mo old';
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Completed dose card  (record-based: shows actual + theoretical when they differ)
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedDoseCard extends StatelessWidget {
  final VaccineCompletedEntry entry;
  const _CompletedDoseCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dose       = entry.dose;
    final actualDate = dose.givenAt != null ? _fmt(dose.givenAt!) : null;
    final theoDate   = dose.theoreticalDueDate != null ? _fmt(dose.theoreticalDueDate!) : null;
    final givenBy    = (dose.givenBy != null && dose.givenBy!.isNotEmpty) ? dose.givenBy : null;
    final notes      = (dose.notes   != null && dose.notes!.isNotEmpty)   ? dose.notes  : null;
    final remarks    = (dose.remarks != null && dose.remarks!.isNotEmpty) ? dose.remarks : null;

    // Show "was supposed to be given on X" only when dates actually differ
    final bool wasLate = actualDate != null && theoDate != null && actualDate != theoDate;

    return Semantics(
      label: '${entry.vaccineName} ${dose.doseLabel} completed'
          '${actualDate != null ? " on $actualDate" : ""}',
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade100),
          boxShadow: [BoxShadow(color: Colors.grey.shade50, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${entry.vaccineName} — ${dose.doseLabel}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
              const SizedBox(height: 3),
              // Actual date given (record-based ground truth)
              if (actualDate != null)
                _metaRow(Icons.event_available_outlined, 'Given on $actualDate', Colors.green.shade700),
              // Theoretical date — shown only when different (was late/early)
              if (wasLate)
                _metaRow(
                  Icons.event_outlined,
                  'Was scheduled for $theoDate',
                  Colors.orange.shade600,
                ),
              if (givenBy != null)
                _metaRow(Icons.person_outline, 'By $givenBy', Colors.green.shade600),
              if (notes != null)
                _metaRow(Icons.notes_outlined, notes, const Color(0xFF64748B)),
              if (remarks != null)
                _metaRow(Icons.comment_outlined, remarks, const Color(0xFF64748B)),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
            child: Text('✓ Done',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade700)),
          ),
        ]),
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Expanded(child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.3))),
      ]),
    );
  }

  String _fmt(String raw) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Pending dose card  (record-based due dates; locked shows "awaiting" message)
// ─────────────────────────────────────────────────────────────────────────────

class _PendingDoseCard extends StatelessWidget {
  final VaccinePendingDose dose;

  /// When non-null an active (approved/rescheduled) immunization appointment
  /// is already linked to this dose — show "Appointment Scheduled" status and
  /// disable the "Book Appointment" button to prevent double-booking.
  final Map<String, dynamic>? scheduledAppointment;

  /// Called when the patient taps "Book Appointment".
  final void Function(VaccinePendingDose dose)? onBookAppointment;

  const _PendingDoseCard({
    required this.dose,
    this.scheduledAppointment,
    this.onBookAppointment,
  });

  @override
  Widget build(BuildContext context) {
    // Determine whether an appointment is already booked for this dose.
    final bool hasScheduled = scheduledAppointment != null;
    final bool canBook = (dose.status == VaccineDoseStatus.dueSoon ||
                          dose.status == VaccineDoseStatus.overdue) &&
                         !hasScheduled;

    final Color borderColor, badgeBg, badgeFg;
    final IconData leadIcon;
    final String badgeLabel;

    if (hasScheduled) {
      // Override visual status with the scheduled appointment date
      final rawDate = scheduledAppointment!['appointment_date']?.toString() ?? '';
      String displayDate = rawDate;
      try {
        if (rawDate.length >= 10) {
          displayDate = DateFormat('MMM d, yyyy').format(DateTime.parse(rawDate));
        }
      } catch (_) {}
      borderColor = Colors.teal.shade200;
      badgeBg     = Colors.teal.shade50;
      badgeFg     = Colors.teal.shade700;
      badgeLabel  = '📅 Scheduled';
      leadIcon    = Icons.event_available_outlined;
      // We compute these inside build but need them only for the badge — pass
      // displayDate to _buildSubDetail via a closure below.
      return _buildCard(
        context,
        borderColor: borderColor,
        badgeBg: badgeBg,
        badgeFg: badgeFg,
        badgeLabel: badgeLabel,
        leadIcon: leadIcon,
        canBook: canBook,
        scheduledDateDisplay: displayDate,
      );
    }

    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        borderColor = Colors.red.shade200;   badgeBg = Colors.red.shade50;
        badgeFg     = Colors.red.shade700;   badgeLabel = '⚠ Overdue';
        leadIcon    = Icons.warning_amber_rounded;
        break;
      case VaccineDoseStatus.dueSoon:
        borderColor = Colors.orange.shade200; badgeBg = Colors.orange.shade50;
        badgeFg     = Colors.orange.shade700; badgeLabel = 'Due soon';
        leadIcon    = Icons.schedule_outlined;
        break;
      case VaccineDoseStatus.locked:
        borderColor = Colors.grey.shade200;  badgeBg = Colors.grey.shade100;
        badgeFg     = Colors.grey.shade500;  badgeLabel = 'Locked';
        leadIcon    = Icons.lock_outline;
        break;
      default:
        borderColor = Colors.grey.shade200;  badgeBg = Colors.grey.shade50;
        badgeFg     = Colors.grey.shade500;  badgeLabel = 'Not yet due';
        leadIcon    = Icons.radio_button_unchecked;
    }

    return _buildCard(
      context,
      borderColor: borderColor,
      badgeBg: badgeBg,
      badgeFg: badgeFg,
      badgeLabel: badgeLabel,
      leadIcon: leadIcon,
      canBook: canBook,
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required Color borderColor,
    required Color badgeBg,
    required Color badgeFg,
    required String badgeLabel,
    required IconData leadIcon,
    required bool canBook,
    String? scheduledDateDisplay,
  }) {
    return Semantics(
      label: _semanticLabel(scheduledDateDisplay),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
          boxShadow: [BoxShadow(color: Colors.grey.shade50, blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(leadIcon, size: 20, color: badgeFg),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(
                    '${dose.vaccineName} · ${dose.doseLabel}',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: dose.status == VaccineDoseStatus.locked
                          ? Colors.grey.shade500
                          : const Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 3),
                  _buildSubDetail(scheduledDateDisplay),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
                child: Text(badgeLabel,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg)),
              ),
            ]),

            // ── "Book Appointment" / "Appointment Scheduled" button row ──────
            if (dose.status == VaccineDoseStatus.dueSoon ||
                dose.status == VaccineDoseStatus.overdue ||
                scheduledAppointment != null) ...[
              const SizedBox(height: 10),
              _buildBookingRow(context, canBook, scheduledDateDisplay, badgeFg),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingRow(
    BuildContext context,
    bool canBook,
    String? scheduledDateDisplay,
    Color scheduledFg,
  ) {
    if (scheduledAppointment != null) {
      // Show the scheduled date and a subtle "already booked" indicator
      final rawTime = scheduledAppointment!['appointment_time']?.toString() ?? '';
      String timeDisplay = '';
      try {
        if (rawTime.length >= 5) {
          final parts = rawTime.split(':');
          int hour = int.parse(parts[0]);
          final min  = parts[1];
          final ampm = hour >= 12 ? 'PM' : 'AM';
          if (hour > 12) hour -= 12;
          if (hour == 0) hour = 12;
          timeDisplay = ' at $hour:$min $ampm';
        }
      } catch (_) {}

      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.teal.shade200),
        ),
        child: Row(children: [
          Icon(Icons.event_available_outlined, size: 14, color: Colors.teal.shade700),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Appointment Scheduled — ${scheduledDateDisplay ?? ''}$timeDisplay',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.teal.shade800,
              ),
            ),
          ),
        ]),
      );
    }

    // Actionable "Book Appointment" button for due-soon / overdue doses
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: 'Book appointment for ${dose.vaccineName} ${dose.doseLabel}',
        child: OutlinedButton.icon(
          onPressed: canBook && onBookAppointment != null
              ? () => onBookAppointment!(dose)
              : null,
          icon: const Icon(Icons.calendar_month_outlined, size: 14),
          label: const Text('Book Appointment',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF0F766E),
            side: const BorderSide(color: Color(0xFF0F766E)),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }

  Widget _buildSubDetail(String? scheduledDateDisplay) {
    if (scheduledAppointment != null) {
      // Show the original due-date info even when scheduled
      return _buildDueDateDetail();
    }
    return _buildDueDateDetail();
  }

  Widget _buildDueDateDetail() {
    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sub('Was due ${_fmt(dose.dueDateEstimate)} · not yet given', Colors.red.shade700),
          if (dose.daysOverdue != null && dose.daysOverdue! > 0)
            _sub('${dose.daysOverdue} day${dose.daysOverdue == 1 ? '' : 's'} overdue',
                Colors.red.shade500),
          if (_showTheoNote())
            _sub('Original schedule: ${_fmt(dose.theoreticalDueDate)}', Colors.grey.shade500),
        ]);

      case VaccineDoseStatus.dueSoon:
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sub('Due on ${_fmt(dose.dueDateEstimate)}', Colors.orange.shade700),
          if (_showTheoNote())
            _sub('Original schedule: ${_fmt(dose.theoreticalDueDate)}', Colors.grey.shade500),
        ]);

      case VaccineDoseStatus.locked:
        final msg = dose.waitingFor != null
            ? 'Date will be set after ${dose.waitingFor} is completed'
            : 'Date will be set after the previous dose is completed';
        return _sub(msg, Colors.grey.shade500);

      default: // not_yet_due
        if (dose.dueDateEstimate != null) {
          return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sub('Due on ${_fmt(dose.dueDateEstimate)} (${dose.scheduleLabel})',
                Colors.grey.shade500),
            if (_showTheoNote())
              _sub('Original schedule: ${_fmt(dose.theoreticalDueDate)}', Colors.grey.shade400),
          ]);
        }
        return _sub('Due at ${dose.scheduleLabel}', Colors.grey.shade500);
    }
  }

  bool _showTheoNote() {
    if (dose.theoreticalDueDate == null || dose.theoreticalDueDate!.isEmpty) return false;
    if (dose.dueDateEstimate == null || dose.dueDateEstimate!.isEmpty) return false;
    final rec  = dose.dueDateEstimate!.substring(0, 10);
    final theo = dose.theoreticalDueDate!.substring(0, 10);
    return rec != theo;
  }

  Widget _sub(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.3)),
    );
  }

  String _fmt(String? raw) {
    if (raw == null || raw.isEmpty) return 'TBD';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }

  String _semanticLabel([String? scheduledDate]) {
    if (scheduledAppointment != null) {
      return '${dose.vaccineName} ${dose.doseLabel} has appointment scheduled'
          '${scheduledDate != null ? " on $scheduledDate" : ""}.';
    }
    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        return '${dose.vaccineName} ${dose.doseLabel} overdue.'
            '${dose.daysOverdue != null ? " ${dose.daysOverdue} days overdue." : ""}';
      case VaccineDoseStatus.dueSoon:
        return '${dose.vaccineName} ${dose.doseLabel} due soon on ${_fmt(dose.dueDateEstimate)}.';
      case VaccineDoseStatus.locked:
        return '${dose.vaccineName} ${dose.doseLabel} locked. '
            '${dose.waitingFor != null ? "Waiting for ${dose.waitingFor}." : ""}';
      default:
        return '${dose.vaccineName} ${dose.doseLabel} not yet due.';
    }
  }
}


// ─────────────────────────────────────────────────────────────────────────────
// Next action banner (bottom of card)
// ─────────────────────────────────────────────────────────────────────────────

class _NextActionBanner extends StatelessWidget {
  final VaccineCardData card;
  const _NextActionBanner({required this.card});

  @override
  Widget build(BuildContext context) {
    if (card.overallStatus == 'overdue') {
      final worst = card.pendingDoses
          .where((d) => d.status == VaccineDoseStatus.overdue)
          .toList();
      final name = worst.isNotEmpty
          ? '${worst.first.vaccineName} (${worst.first.doseLabel})'
          : 'vaccines';
      return _banner(
        icon: Icons.warning_amber_rounded, iconColor: Colors.red.shade700,
        bg: Colors.red.shade50, border: Colors.red.shade200,
        text: 'You have overdue vaccines ($name). Visit the clinic as soon as possible.',
        textColor: Colors.red.shade800,
      );
    }

    if (card.overallStatus == 'action_needed') {
      final next = card.pendingDoses
          .where((d) => d.status == VaccineDoseStatus.dueSoon)
          .toList();
      if (next.isNotEmpty) {
        final n = next.first;
        final datePart = n.dueDateEstimate != null && n.dueDateEstimate!.isNotEmpty
            ? ', due ${_fmt(n.dueDateEstimate!)}'
            : '';
        return _banner(
          icon: Icons.notifications_outlined, iconColor: Colors.amber.shade800,
          bg: Colors.amber.shade50, border: Colors.amber.shade200,
          text: 'Next: ${n.vaccineName} (${n.doseLabel})$datePart. Book an appointment to stay on schedule.',
          textColor: Colors.amber.shade900,
        );
      }
    }

    // Fully up to date
    final nd = card.nextDue;
    String upToDateText = 'Your child is fully up to date!';
    if (nd != null) {
      final vacName   = nd['vaccine_name']?.toString() ?? '';
      final doseLabel = nd['dose_label']?.toString() ?? '';
      final dueDate   = nd['due_date_estimate']?.toString();
      if (vacName.isNotEmpty) {
        final datePart = dueDate != null && dueDate.isNotEmpty ? ' on ${_fmt(dueDate)}' : '';
        upToDateText += ' Next vaccine: $vacName ($doseLabel)$datePart.';
      }
    }
    return _banner(
      icon: Icons.check_circle_outline, iconColor: Colors.green.shade700,
      bg: Colors.green.shade50, border: Colors.green.shade200,
      text: upToDateText, textColor: Colors.green.shade800,
    );
  }

  Widget _banner({
    required IconData icon, required Color iconColor,
    required Color bg, required Color border,
    required String text, required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: TextStyle(fontSize: 13, color: textColor, height: 1.4))),
      ]),
    );
  }

  String _fmt(String raw) {
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(raw)); }
    catch (_) { return raw; }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared utility widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final int count;

  const _SectionHeader({
    required this.icon, required this.iconColor,
    required this.label, required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B))),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text('$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor)),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Error loading vaccine record. Tap to retry.',
      child: Material(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onRetry,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(message,
                  style: TextStyle(fontSize: 13, color: Colors.red.shade900))),
              Text('Retry',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
            ]),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      height: 80,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}
