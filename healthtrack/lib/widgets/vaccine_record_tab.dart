import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/user_session.dart';
import '../services/vaccine_service.dart';
import '../services/websocket_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// VaccineRecordTab — embedded in HealthCardTab as "Vaccine Record" tab.
//
// Data source : GET /vaccines/card/:patientId  (existing endpoint, enhanced)
// Realtime    : WebSocketService.vaccineRecordUpdated + 30 s poll fallback
// Edge cases  : no patient ID, empty vaccine list, network error, loading
// ─────────────────────────────────────────────────────────────────────────────

class VaccineRecordTab extends StatefulWidget {
  /// When provided, overrides UserSession.patientId so the tab always shows
  /// the active child's vaccine record regardless of session state.
  final int? patientIdOverride;

  const VaccineRecordTab({super.key, this.patientIdOverride});

  @override
  State<VaccineRecordTab> createState() => _VaccineRecordTabState();
}

class _VaccineRecordTabState extends State<VaccineRecordTab>
    with WidgetsBindingObserver {
  // ── state ────────────────────────────────────────────────────────────────
  VaccineCardData? _card;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  late final void Function(Map<String, dynamic>) _wsListener;

  // ── lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _wsListener = (_) {
      if (mounted) _fetchCard(silent: true);
    };

    _initRealtime();
    _fetchCard();
    _startPollTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    WebSocketService.instance.removeVaccineRecordUpdatedListener(_wsListener);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchCard(silent: true);
  }

  // ── realtime ──────────────────────────────────────────────────────────────

  void _initRealtime() {
    Future.microtask(() async {
      try {
        await WebSocketService.instance.initialize();
        final uid = int.tryParse(UserSession.instance.userId) ?? 0;
        if (uid > 0) WebSocketService.instance.joinUserRoom(uid);
        WebSocketService.instance.addVaccineRecordUpdatedListener(_wsListener);
      } catch (e) {
        debugPrint('[VaccineRecordTab] WS init error: $e');
      }
    });
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchCard(silent: true);
    });
  }

  // ── data ──────────────────────────────────────────────────────────────────

  Future<void> _fetchCard({bool silent = false}) async {
    // Use override if provided (child switcher passes the active child's ID)
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);
    if (patientId <= 0) {
      if (mounted) setState(() { _loading = false; });
      return;
    }
    if (!silent && mounted) {
      setState(() { _loading = true; _error = null; });
    }
    try {
      final card = await VaccineService.getVaccineCard(patientId);
      if (mounted) setState(() { _card = card; _loading = false; _error = null; });
    } catch (e) {
      debugPrint('[VaccineRecordTab] fetch error: $e');
      if (mounted) setState(() { _loading = false; _error = 'Unable to load vaccine record. Please try again.'; });
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final patientId = widget.patientIdOverride != null && widget.patientIdOverride! > 0
        ? widget.patientIdOverride!
        : (int.tryParse(UserSession.instance.patientId) ?? 0);

    // No patient record at all
    if (!_loading && _error == null && patientId <= 0) {
      return _buildNoPatient(context);
    }

    // Full loading skeleton (first load only)
    if (_loading && _card == null) {
      return _buildSkeleton(context);
    }

    return RefreshIndicator(
      onRefresh: () => _fetchCard(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          // Silent refresh spinner (subsequent refreshes)
          if (_loading && _card != null)
            const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: LinearProgressIndicator(minHeight: 2),
            ),

          // Error banner — non-breaking, shown above stale data
          if (_error != null) ...[
            _ErrorBanner(message: _error!, onRetry: () => _fetchCard()),
            const SizedBox(height: 12),
          ],

          if (_card != null) ...[
            // 2a — Header summary card
            _HeaderSummaryCard(card: _card!),
            const SizedBox(height: 16),

            // 2b — Completed vaccines
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

            // 2c — Pending / incomplete
            if (_card!.pendingDoses.isNotEmpty) ...[
              _SectionHeader(
                icon: Icons.pending_outlined,
                iconColor: Colors.orange.shade700,
                label: 'Pending Vaccines',
                count: _card!.pendingDoses.length,
              ),
              const SizedBox(height: 8),
              ..._card!.pendingDoses.map((d) => _PendingDoseCard(dose: d)),
              const SizedBox(height: 16),
            ],

            // Empty state — no records at all
            if (_card!.completedDoses.isEmpty && _card!.pendingDoses.isEmpty)
              _buildEmptyState(context),

            // 2d — Next action banner
            _NextActionBanner(card: _card!),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
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
            Text(
              'No patient record found.',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Please complete your profile first.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
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
          Text(
            'No vaccines recorded yet.',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey.shade700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Visit the clinic to start your child\'s immunization record.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
            textAlign: TextAlign.center,
          ),
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
// 2a — Header Summary Card
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderSummaryCard extends StatelessWidget {
  final VaccineCardData card;
  const _HeaderSummaryCard({required this.card});

  @override
  Widget build(BuildContext context) {
    final childName = card.childName.isNotEmpty
        ? card.childName
        : UserSession.instance.childName;
    final ageLabel = _ageLabel(card.ageInDays);
    final completed = card.totalDosesCompleted;
    final total     = card.totalDosesRequired;
    final progress  = total > 0 ? completed / total : 0.0;

    // Status colour + label
    final Color statusBg;
    final Color statusFg;
    final IconData statusIcon;
    final String statusLabel;

    switch (card.overallStatus) {
      case 'overdue':
        statusBg    = Colors.red.shade50;
        statusFg    = Colors.red.shade700;
        statusIcon  = Icons.warning_amber_rounded;
        statusLabel = 'Overdue vaccines';
        break;
      case 'action_needed':
        statusBg    = Colors.amber.shade50;
        statusFg    = Colors.amber.shade800;
        statusIcon  = Icons.notifications_active_outlined;
        statusLabel = 'Action needed';
        break;
      default:
        statusBg    = Colors.green.shade50;
        statusFg    = Colors.green.shade700;
        statusIcon  = Icons.check_circle_outline;
        statusLabel = 'Up to date';
    }

    final Color barColor = card.overallStatus == 'overdue'
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
        boxShadow: [
          BoxShadow(color: Colors.grey.shade100, blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Name + age
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      childName,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    if (ageLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        ageLabel,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 14, color: statusFg),
                    const SizedBox(width: 4),
                    Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: statusFg)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Progress count
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '$completed of $total doses completed',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: barColor),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  String _ageLabel(int days) {
    if (days <= 0) return '';
    if (days < 30) return '$days days old';
    final months = days ~/ 30;
    if (months < 12) return '$months month${months == 1 ? '' : 's'} old';
    final years  = months ~/ 12;
    final rem    = months % 12;
    if (rem == 0) return '$years year${years == 1 ? '' : 's'} old';
    return '$years yr${years == 1 ? '' : 's'} $rem mo old';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2b — Completed dose card
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedDoseCard extends StatelessWidget {
  final VaccineCompletedEntry entry;
  const _CompletedDoseCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final dose      = entry.dose;
    final givenDate = dose.givenAt != null ? _formatDate(dose.givenAt!) : null;
    final givenBy   = (dose.givenBy != null && dose.givenBy!.isNotEmpty) ? dose.givenBy : null;
    final notes     = (dose.notes  != null && dose.notes!.isNotEmpty)   ? dose.notes  : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade100),
        boxShadow: [BoxShadow(color: Colors.grey.shade50, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading check icon
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vaccine name + dose label
                Text(
                  '${entry.vaccineName} — ${dose.doseLabel}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 3),

                // Date given
                if (givenDate != null)
                  _metaRow(Icons.calendar_today_outlined, 'Given $givenDate', Colors.green.shade700),

                // Health worker
                if (givenBy != null)
                  _metaRow(Icons.person_outline, 'By $givenBy', Colors.green.shade600),

                // Remarks
                if (notes != null)
                  _metaRow(Icons.notes_outlined, notes, const Color(0xFF64748B)),
              ],
            ),
          ),

          // Trailing badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '✓ Done',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.green.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12, color: color, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2c — Pending dose card
// ─────────────────────────────────────────────────────────────────────────────

class _PendingDoseCard extends StatelessWidget {
  final VaccinePendingDose dose;
  const _PendingDoseCard({required this.dose});

  @override
  Widget build(BuildContext context) {
    // Colour scheme by status
    final Color borderColor;
    final Color badgeBg;
    final Color badgeFg;
    final String badgeLabel;
    final IconData leadIcon;

    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        borderColor = Colors.red.shade200;
        badgeBg     = Colors.red.shade50;
        badgeFg     = Colors.red.shade700;
        badgeLabel  = '⚠ Overdue';
        leadIcon    = Icons.warning_amber_rounded;
        break;
      case VaccineDoseStatus.dueSoon:
        borderColor = Colors.orange.shade200;
        badgeBg     = Colors.orange.shade50;
        badgeFg     = Colors.orange.shade700;
        badgeLabel  = 'Due soon';
        leadIcon    = Icons.schedule_outlined;
        break;
      case VaccineDoseStatus.locked:
        borderColor = Colors.grey.shade200;
        badgeBg     = Colors.grey.shade100;
        badgeFg     = Colors.grey.shade500;
        badgeLabel  = 'Locked';
        leadIcon    = Icons.lock_outline;
        break;
      default:
        borderColor = Colors.grey.shade200;
        badgeBg     = Colors.grey.shade50;
        badgeFg     = Colors.grey.shade500;
        badgeLabel  = 'Not yet due';
        leadIcon    = Icons.radio_button_unchecked;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [BoxShadow(color: Colors.grey.shade50, blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Leading icon
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(leadIcon, size: 20, color: badgeFg),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vaccine name + dose label
                Text(
                  '${dose.vaccineName} · ${dose.doseLabel}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: dose.status == VaccineDoseStatus.locked
                        ? Colors.grey.shade500
                        : const Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 3),

                // Sub-detail based on status
                if (dose.status == VaccineDoseStatus.overdue) ...[
                  _subText(
                    'Was due ${_formatDate(dose.dueDateEstimate)} · not yet given',
                    Colors.red.shade700,
                  ),
                  if (dose.daysOverdue != null && dose.daysOverdue! > 0)
                    _subText(
                      '${dose.daysOverdue} day${dose.daysOverdue == 1 ? '' : 's'} overdue',
                      Colors.red.shade500,
                    ),
                ] else if (dose.status == VaccineDoseStatus.dueSoon) ...[
                  _subText('Due on ${_formatDate(dose.dueDateEstimate)}', Colors.orange.shade700),
                ] else if (dose.status == VaccineDoseStatus.locked) ...[
                  _subText(
                    dose.waitingFor != null
                        ? 'Waiting for ${dose.waitingFor} to be completed first'
                        : 'Complete the previous dose first',
                    Colors.grey.shade500,
                  ),
                ] else ...[
                  // not_yet_due
                  _subText('Due at ${dose.scheduleLabel} (${_formatDate(dose.dueDateEstimate)})', Colors.grey.shade500),
                ],
              ],
            ),
          ),

          // Trailing badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
            child: Text(badgeLabel, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg)),
          ),
        ],
      ),
    );
  }

  Widget _subText(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(text, style: TextStyle(fontSize: 12, color: color, height: 1.3)),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return 'TBD';
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2d — Next action banner
// ─────────────────────────────────────────────────────────────────────────────

class _NextActionBanner extends StatelessWidget {
  final VaccineCardData card;
  const _NextActionBanner({required this.card});

  @override
  Widget build(BuildContext context) {
    final hasOverdue  = card.overallStatus == 'overdue';
    final hasDueSoon  = card.overallStatus == 'action_needed';

    if (hasOverdue) {
      // Find the most overdue item
      final worst = card.pendingDoses
          .where((d) => d.status == VaccineDoseStatus.overdue)
          .toList();
      final name = worst.isNotEmpty ? '${worst.first.vaccineName} (${worst.first.doseLabel})' : 'vaccines';
      return _banner(
        icon: Icons.warning_amber_rounded,
        iconColor: Colors.red.shade700,
        bg: Colors.red.shade50,
        border: Colors.red.shade200,
        text: 'You have overdue vaccines ($name). Visit the clinic as soon as possible.',
        textColor: Colors.red.shade800,
      );
    }

    if (hasDueSoon) {
      final next = card.pendingDoses
          .where((d) => d.status == VaccineDoseStatus.dueSoon)
          .toList();
      if (next.isNotEmpty) {
        final n = next.first;
        final datePart = n.dueDateEstimate != null && n.dueDateEstimate!.isNotEmpty
            ? ', due ${_formatDate(n.dueDateEstimate!)}'
            : '';
        return _banner(
          icon: Icons.notifications_outlined,
          iconColor: Colors.amber.shade800,
          bg: Colors.amber.shade50,
          border: Colors.amber.shade200,
          text: 'Next: ${n.vaccineName} (${n.doseLabel})$datePart. Book an appointment to stay on schedule.',
          textColor: Colors.amber.shade900,
        );
      }
    }

    // Fully up to date
    final nextScheduled = card.nextDue;
    String upToDateText = 'Your child is fully up to date!';
    if (nextScheduled != null) {
      final vacName   = nextScheduled['vaccine_name']?.toString() ?? '';
      final doseLabel = nextScheduled['dose_label']?.toString() ?? '';
      final dueDate   = nextScheduled['due_date_estimate']?.toString();
      if (vacName.isNotEmpty) {
        final datePart = dueDate != null && dueDate.isNotEmpty ? ' on ${_formatDate(dueDate)}' : '';
        upToDateText += ' Next vaccine: $vacName ($doseLabel)$datePart.';
      }
    }

    return _banner(
      icon: Icons.check_circle_outline,
      iconColor: Colors.green.shade700,
      bg: Colors.green.shade50,
      border: Colors.green.shade200,
      text: upToDateText,
      textColor: Colors.green.shade800,
    );
  }

  Widget _banner({
    required IconData icon,
    required Color iconColor,
    required Color bg,
    required Color border,
    required String text,
    required Color textColor,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 13, color: textColor, height: 1.4)),
          ),
        ],
      ),
    );
  }

  String _formatDate(String raw) {
    try {
      return DateFormat('MMM d, yyyy').format(DateTime.parse(raw));
    } catch (_) {
      return raw;
    }
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
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF1E293B)),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: iconColor),
            ),
          ),
        ],
      ),
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
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                  ),
                ),
                Text(
                  'Retry',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700),
                ),
              ],
            ),
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
