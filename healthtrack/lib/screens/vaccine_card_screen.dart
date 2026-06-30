import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthtrack/services/user_session.dart';
import 'package:healthtrack/services/vaccine_service.dart';
import 'package:healthtrack/services/websocket_service.dart';
import 'package:intl/intl.dart';

/// Full-page Vaccine Card screen — shows every vaccine in the EPI schedule with
/// per-dose live status for the logged-in child.
///
/// Realtime strategy (identical to VaccineDashboardWidget):
///   1. WebSocketService.vaccineRecordUpdated push — instant update from admin action
///   2. Timer.periodic 30 s fallback poll — catches WS-offline scenarios
///   3. Overdue recomputed on every load (status comes from backend, not cached)
///
/// Edge cases:
///   • Zero vaccines given  — all doses show computed status (not_yet_due / due_soon)
///   • Fully up to date     — "Next" banner shows next scheduled vaccine or none
///   • Overdue              — red alert banner at top + per-dose Overdue chip
///   • Sequential lock      — locked doses shown with lock icon, no action possible
///   • Network error        — retry banner, last data stays visible
class VaccineCardScreen extends StatefulWidget {
  const VaccineCardScreen({super.key});

  @override
  State<VaccineCardScreen> createState() => _VaccineCardScreenState();
}

class _VaccineCardScreenState extends State<VaccineCardScreen>
    with WidgetsBindingObserver {
  // ── State ──────────────────────────────────────────────────────────────────
  VaccineCardData? _card;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;

  late final void Function(Map<String, dynamic>) _onVaccineUpdate;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _onVaccineUpdate = (_) {
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
    WebSocketService.instance.removeVaccineRecordUpdatedListener(_onVaccineUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _fetchCard(silent: true);
  }

  // ── Realtime setup ─────────────────────────────────────────────────────────

  void _initRealtime() {
    Future.microtask(() async {
      try {
        await WebSocketService.instance.initialize();
        final uid = int.tryParse(UserSession.instance.userId) ?? 0;
        if (uid > 0) WebSocketService.instance.joinUserRoom(uid);
        WebSocketService.instance.addVaccineRecordUpdatedListener(_onVaccineUpdate);
      } catch (e) {
        debugPrint('[VaccineCard] WS init error: $e');
      }
    });
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchCard(silent: true);
    });
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchCard({bool silent = false}) async {
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) {
      if (mounted) setState(() { _loading = false; });
      return;
    }

    if (!silent && mounted) setState(() { _loading = true; _error = null; });

    try {
      final card = await VaccineService.getVaccineCard(patientId);
      if (mounted) {
        setState(() {
          _card = card;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[VaccineCard] fetch error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load vaccine card. Tap to retry.';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildAppBar(context),
      body: RefreshIndicator(
        onRefresh: () => _fetchCard(),
        child: _buildBody(context),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: TextButton.icon(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.blueAccent),
        label: const Text(
          'Back to dashboard',
          style: TextStyle(color: Colors.blueAccent, fontSize: 13),
        ),
      ),
      leadingWidth: 170,
      actions: [
        if (_loading && _card != null)
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading && _card == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No patient record found. Please complete your profile first.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // ── Page header ───────────────────────────────────────────────────
        _buildPageHeader(context),
        const SizedBox(height: 14),

        // ── Error banner ──────────────────────────────────────────────────
        if (_error != null) ...[
          _ErrorRetryBanner(
            message: _error!,
            onRetry: () => _fetchCard(),
          ),
          const SizedBox(height: 12),
        ],

        // ── Overdue alert banner ──────────────────────────────────────────
        if (_card?.overdueAlert != null) ...[
          _OverdueAlertBanner(overdueAlert: _card!.overdueAlert!),
          const SizedBox(height: 12),
        ],

        // ── Vaccine groups ────────────────────────────────────────────────
        if (_card == null || _card!.vaccines.isEmpty)
          _buildEmptyState(context)
        else ...[
          for (final group in _card!.vaccines) ...[
            _VaccineGroupCard(group: group),
            const SizedBox(height: 10),
          ],
        ],

        const SizedBox(height: 12),

        // ── Bottom "next due" suggestion banner ───────────────────────────
        if (_card != null)
          _buildNextBanner(context),
      ],
    );
  }

  Widget _buildPageHeader(BuildContext context) {
    final childName = _card?.childName ?? UserSession.instance.childName;
    final dob = _card?.dob;
    String dobLabel = '';
    if (dob != null && dob.isNotEmpty) {
      try {
        dobLabel = 'DOB ${DateFormat('MMM d, yyyy').format(DateTime.parse(dob))}';
      } catch (_) {
        dobLabel = 'DOB $dob';
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vaccine card',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
        if (childName.isNotEmpty || dobLabel.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              [
                if (childName.isNotEmpty) childName,
                if (dobLabel.isNotEmpty) dobLabel,
              ].join(' · '),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        const SizedBox(height: 4),
        const Text(
          'Complete each dose in order to unlock the next.',
          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
        ),
      ],
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
            'Vaccine schedule not set up yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Contact your health provider to initialise the schedule for this child.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildNextBanner(BuildContext context) {
    if (_card!.vaccines.isEmpty) return const SizedBox.shrink();

    final nextDue = _card!.nextDue;

    if (nextDue == null) {
      // All doses that should be done by now are done
      return _BannerTile(
        icon: Icons.check_circle_outline,
        iconColor: Colors.green.shade700,
        backgroundColor: Colors.green.shade50,
        borderColor: Colors.green.shade200,
        text: 'All required vaccines for this child\'s current age are complete. Well done!',
        textColor: Colors.green.shade800,
      );
    }

    final vaccineName   = nextDue['vaccine_name']?.toString() ?? '';
    final doseLabel     = nextDue['dose_label']?.toString() ?? '';
    final dueDateRaw    = nextDue['due_date_estimate']?.toString();
    final status        = nextDue['status']?.toString() ?? '';

    final duePart = dueDateRaw != null && dueDateRaw.isNotEmpty
        ? ', due ${_formatDate(dueDateRaw)}'
        : '';

    final isOverdue = status == 'overdue';

    return _BannerTile(
      icon: isOverdue ? Icons.warning_amber_rounded : Icons.notifications_outlined,
      iconColor: isOverdue ? Colors.red.shade700 : Colors.orange.shade700,
      backgroundColor: isOverdue ? Colors.red.shade50 : Colors.amber.shade50,
      borderColor: isOverdue ? Colors.red.shade200 : Colors.amber.shade200,
      text: isOverdue
          ? 'Overdue: $vaccineName ($doseLabel). Visit the clinic as soon as possible.'
          : 'Next: $vaccineName ($doseLabel)$duePart. Watch for the reminder closer to the date.',
      textColor: isOverdue ? Colors.red.shade800 : Colors.orange.shade900,
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
// Vaccine group card (one per vaccine e.g. BCG, Hepatitis B…)
// ─────────────────────────────────────────────────────────────────────────────

class _VaccineGroupCard extends StatelessWidget {
  final VaccineGroup group;

  const _VaccineGroupCard({required this.group});

  @override
  Widget build(BuildContext context) {
    // Determine card-level border colour from overall status
    final hasOverdue  = group.doses.any((d) => d.status == VaccineDoseStatus.overdue);
    final hasDueSoon  = group.doses.any((d) => d.status == VaccineDoseStatus.dueSoon);
    final allDone     = group.doses.every((d) => d.status == VaccineDoseStatus.completed);

    final Color borderColor;
    if (hasOverdue) {
      borderColor = Colors.red.shade200;
    } else if (hasDueSoon) {
      borderColor = Colors.orange.shade200;
    } else if (allDone) {
      borderColor = Colors.green.shade200;
    } else {
      borderColor = Colors.grey.shade200;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group header row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    group.vaccineName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                _GroupStatusChip(statusLabel: group.groupStatusLabel),
              ],
            ),
            const SizedBox(height: 10),
            // Dose rows
            for (var i = 0; i < group.doses.length; i++) ...[
              if (i > 0)
                Divider(height: 14, color: Colors.grey.shade100),
              _DoseRow(dose: group.doses[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _GroupStatusChip extends StatelessWidget {
  final String statusLabel;

  const _GroupStatusChip({required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    // Choose chip colours based on text content
    final Color bg;
    final Color fg;

    if (statusLabel.startsWith('Completed') || statusLabel.endsWith('done')) {
      bg = Colors.green.shade50;
      fg = Colors.green.shade700;
    } else if (statusLabel == 'Overdue') {
      bg = Colors.red.shade50;
      fg = Colors.red.shade700;
    } else if (statusLabel == 'Due soon') {
      bg = Colors.orange.shade50;
      fg = Colors.orange.shade700;
    } else {
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusLabel,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

/// Single dose row inside a vaccine group card.
class _DoseRow extends StatelessWidget {
  final VaccineDose dose;

  const _DoseRow({required this.dose});

  @override
  Widget build(BuildContext context) {
    final status = dose.status;
    final locked = status == VaccineDoseStatus.locked;

    // Left icon
    final Widget leadIcon;
    if (locked) {
      leadIcon = Icon(Icons.lock_outline, size: 16, color: Colors.grey.shade400);
    } else if (status == VaccineDoseStatus.completed) {
      leadIcon = Icon(Icons.check_circle, size: 16, color: Colors.green.shade600);
    } else if (status == VaccineDoseStatus.overdue) {
      leadIcon = Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red.shade600);
    } else {
      leadIcon = Icon(Icons.radio_button_unchecked, size: 16, color: Colors.grey.shade400);
    }

    // Right label
    final Widget rightLabel = _DoseStatusBadge(status: status);

    // Sub-text lines
    final List<Widget> subLines = [];

    if (status == VaccineDoseStatus.completed && dose.givenAt != null) {
      final givenByPart = (dose.givenBy != null && dose.givenBy!.isNotEmpty)
          ? ' · marked by ${dose.givenBy}'
          : '';
      subLines.add(
        Text(
          'Given ${_formatDate(dose.givenAt)}$givenByPart',
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
        ),
      );
    } else if (status == VaccineDoseStatus.overdue) {
      final wasRaw = dose.dueDateEstimate;
      final wasPart = wasRaw != null && wasRaw.isNotEmpty
          ? 'Was due ${_formatDate(wasRaw)} · not yet given'
          : 'Not yet given';
      subLines.add(
        Text(
          wasPart,
          style: TextStyle(fontSize: 12, color: Colors.red.shade600),
        ),
      );
    } else if (status == VaccineDoseStatus.dueSoon && dose.dueDateEstimate != null) {
      subLines.add(
        Text(
          'Due ${_formatDate(dose.dueDateEstimate)}',
          style: TextStyle(fontSize: 12, color: Colors.orange.shade700),
        ),
      );
    } else if (locked) {
      subLines.add(
        Text(
          'Locked',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
        ),
      );
    }

    return Semantics(
      label: '${dose.doseLabel}, ${dose.scheduleLabel}. '
          'Status: ${_statusAccessibilityLabel(status)}.',
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: leadIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${dose.doseLabel} · ${dose.scheduleLabel}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: locked ? Colors.grey.shade500 : const Color(0xFF0F172A),
                  ),
                ),
                ...subLines,
              ],
            ),
          ),
          const SizedBox(width: 8),
          rightLabel,
        ],
      ),
    );
  }

  String _formatDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  String _statusAccessibilityLabel(VaccineDoseStatus s) {
    switch (s) {
      case VaccineDoseStatus.completed:  return 'Completed';
      case VaccineDoseStatus.dueSoon:    return 'Due soon';
      case VaccineDoseStatus.overdue:    return 'Overdue';
      case VaccineDoseStatus.locked:     return 'Locked — complete previous dose first';
      case VaccineDoseStatus.notYetDue:  return 'Not yet due';
    }
  }
}

class _DoseStatusBadge extends StatelessWidget {
  final VaccineDoseStatus status;

  const _DoseStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case VaccineDoseStatus.completed:
        return _badge('✓ Completed', Colors.green.shade50, Colors.green.shade700);
      case VaccineDoseStatus.overdue:
        return _badge('⚠ Overdue', Colors.red.shade50, Colors.red.shade700);
      case VaccineDoseStatus.dueSoon:
        return _badge('Due soon', Colors.orange.shade50, Colors.orange.shade700);
      case VaccineDoseStatus.locked:
        return _badge('Locked', Colors.grey.shade100, Colors.grey.shade500);
      case VaccineDoseStatus.notYetDue:
        return _badge('Not yet due', Colors.grey.shade100, Colors.grey.shade500);
    }
  }

  Widget _badge(String label, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared utility widgets
// ─────────────────────────────────────────────────────────────────────────────

class _OverdueAlertBanner extends StatelessWidget {
  final Map<String, dynamic> overdueAlert;

  const _OverdueAlertBanner({required this.overdueAlert});

  @override
  Widget build(BuildContext context) {
    final name      = overdueAlert['vaccine_name']?.toString() ?? '';
    final doseLabel = overdueAlert['dose_label']?.toString() ?? '';
    return _BannerTile(
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.red.shade700,
      backgroundColor: Colors.red.shade50,
      borderColor: Colors.red.shade200,
      text: '$name ($doseLabel) is overdue. Visit the clinic as soon as possible.',
      textColor: Colors.red.shade800,
    );
  }
}

class _ErrorRetryBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorRetryBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Error loading vaccine card. Tap to retry.',
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
                Icon(Icons.warning_amber_rounded,
                    color: Colors.red.shade700, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(message,
                      style:
                          TextStyle(fontSize: 13, color: Colors.red.shade900)),
                ),
                Text('Retry',
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color backgroundColor;
  final Color borderColor;
  final String text;
  final Color textColor;

  const _BannerTile({
    required this.icon,
    required this.iconColor,
    required this.backgroundColor,
    required this.borderColor,
    required this.text,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: textColor, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
