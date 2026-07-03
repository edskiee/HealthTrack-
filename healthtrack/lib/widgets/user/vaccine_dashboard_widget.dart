import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthtrack/services/user_session.dart';
import 'package:healthtrack/services/vaccine_service.dart';
import 'package:healthtrack/services/websocket_service.dart';
import 'package:healthtrack/screens/vaccine_card_screen.dart';
import 'package:intl/intl.dart';

/// Vaccine tracking section shown on the Home/Dashboard tab for immunization users.
///
/// Realtime strategy (consistent with HomeTab):
///   1. WebSocketService.vaccineRecordUpdated push — instant update when admin marks a dose
///   2. Timer.periodic 30 s fallback poll — catches any edge case where WS is offline
///   3. RefreshIndicator / manual pull-to-refresh from the parent scroll view
///
/// Edge cases handled:
///   • Zero vaccines given — shows all-zero summary with informative empty state
///   • Fully up to date   — shows "fully up to date" banner instead of "next up"
///   • Overdue doses      — shows red overdue alert at top
///   • No patient ID      — gracefully hides the section
///   • Network error      — shows retry banner, keeps last data visible
class VaccineDashboardWidget extends StatefulWidget {
  const VaccineDashboardWidget({super.key});

  @override
  State<VaccineDashboardWidget> createState() => _VaccineDashboardWidgetState();
}

class _VaccineDashboardWidgetState extends State<VaccineDashboardWidget>
    with WidgetsBindingObserver {
  // ── State ──────────────────────────────────────────────────────────────────
  VaccineDashboardSummary? _summary;
  bool _loading = true;
  String? _error;
  Timer? _pollTimer;
  StreamSubscription<void>? _activeChildSub;

  // Bound once so we can remove the same instance in dispose()
  late final void Function(Map<String, dynamic>) _onVaccineUpdate;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _onVaccineUpdate = (_) {
      if (mounted) _fetchSummary(silent: true);
    };

    // Re-fetch immediately when the parent switches the active child
    _activeChildSub = UserSession.instance.onActiveChildChanged.listen((_) {
      if (mounted) _fetchSummary();
    });

    _initRealtime();
    _fetchSummary();
    _startPollTimer();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    _activeChildSub?.cancel();
    WebSocketService.instance.removeVaccineRecordUpdatedListener(_onVaccineUpdate);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when the patient returns to the app from background
    if (state == AppLifecycleState.resumed) {
      _fetchSummary(silent: true);
    }
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
        debugPrint('[VaccineDashboard] WS init error: $e');
      }
    });
  }

  void _startPollTimer() {
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _fetchSummary(silent: true);
    });
  }

  // ── Data fetching ──────────────────────────────────────────────────────────

  Future<void> _fetchSummary({bool silent = false}) async {
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) {
      if (mounted) setState(() { _loading = false; _error = null; });
      return;
    }

    if (!silent && mounted) setState(() { _loading = true; _error = null; });

    try {
      final summary = await VaccineService.getDashboardSummary(patientId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      debugPrint('[VaccineDashboard] fetch error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load vaccine data. Tap to retry.';
        });
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Hide entirely if the patient has no ID yet
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header ──────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Vaccine tracking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              _ImmunizationChip(),
            ],
          ),
          const SizedBox(height: 12),

          // ── Error banner ────────────────────────────────────────────────
          if (_error != null) ...[
            _ErrorBanner(
              message: _error!,
              onRetry: () => _fetchSummary(),
            ),
            const SizedBox(height: 10),
          ],

          // ── Loading skeleton ────────────────────────────────────────────
          if (_loading && _summary == null)
            const _LoadingSkeleton()
          else ...[
            // ── Today summary card ────────────────────────────────────────
            _TodaySummaryCard(summary: _summary),
            const SizedBox(height: 10),

            // ── Last completed appointment ────────────────────────────────
            if (_summary?.lastCompleted != null)
              _LastCompletedCard(lastCompleted: _summary!.lastCompleted!),

            const SizedBox(height: 10),

            // ── Next up / fully up to date banner ────────────────────────
            if (_summary?.fullyUpToDate == true)
              const _FullyUpToDateBanner()
            else if (_summary?.nextDue != null)
              _NextUpBanner(nextDue: _summary!.nextDue!),

            const SizedBox(height: 14),

            // ── Show all progress button ──────────────────────────────────
            _ShowAllProgressButton(
              onTap: () => _openVaccineCard(context),
            ),
          ],
        ],
      ),
    );
  }

  void _openVaccineCard(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const VaccineCardScreen()),
    ).then((_) {
      // Refresh dashboard when the patient returns from the card screen
      if (mounted) _fetchSummary(silent: true);
    });
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets — each is stateless and pure; all data comes in via constructor
// ─────────────────────────────────────────────────────────────────────────────

class _ImmunizationChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.vaccines, size: 14, color: Colors.blueAccent),
          SizedBox(width: 4),
          Text(
            'Immunization',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.blueAccent,
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
      label: 'Vaccine data could not be loaded. Tap to retry.',
      button: true,
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
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 13, color: Colors.red.shade900),
                  ),
                ),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          height: 60,
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

/// Today's completed / in-progress / missed counts.
class _TodaySummaryCard extends StatelessWidget {
  final VaccineDashboardSummary? summary;

  const _TodaySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final completed  = summary?.todayCompleted  ?? 0;
    final inProgress = summary?.todayInProgress ?? 0;
    final missed     = summary?.todayMissed     ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueAccent.withOpacity(0.10), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _StatColumn(
                  emoji: '✓',
                  label: 'Completed',
                  value: completed,
                  valueColor: Colors.green.shade700,
                  emojiColor: Colors.green,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  emoji: '○',
                  label: 'In progress',
                  value: inProgress,
                  valueColor: const Color(0xFF0F766E),
                  emojiColor: Colors.grey.shade600,
                ),
              ),
              Expanded(
                child: _StatColumn(
                  emoji: '✕',
                  label: 'Missed',
                  value: missed,
                  valueColor: Colors.red.shade700,
                  emojiColor: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatColumn extends StatelessWidget {
  final String emoji;
  final String label;
  final int value;
  final Color valueColor;
  final Color emojiColor;

  const _StatColumn({
    required this.emoji,
    required this.label,
    required this.value,
    required this.valueColor,
    required this.emojiColor,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $value',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: TextStyle(color: emojiColor, fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Card showing the most recently completed vaccine dose.
class _LastCompletedCard extends StatelessWidget {
  final Map<String, dynamic> lastCompleted;

  const _LastCompletedCard({required this.lastCompleted});

  String _formatGivenAt(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw).toLocal();
      return 'Completed ${DateFormat("MMMM d, yyyy · h:mm a").format(dt)}';
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaccineName = lastCompleted['vaccine_name']?.toString() ?? '';
    final doseLabel   = lastCompleted['dose_label']?.toString() ?? '';
    final givenAt     = lastCompleted['given_at']?.toString();
    final givenBy     = lastCompleted['given_by']?.toString();

    final doctorLabel = (givenBy != null && givenBy.isNotEmpty)
        ? givenBy
        : 'Available doctor';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: Colors.blueAccent, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SmallChip(
                label: 'Immunization',
                bg: Colors.blueAccent.withOpacity(0.1),
                fg: Colors.blueAccent,
                icon: Icons.vaccines,
              ),
              const SizedBox(width: 8),
              _SmallChip(
                label: '✓ Completed',
                bg: Colors.green.shade50,
                fg: Colors.green.shade700,
                icon: Icons.check_circle_outline,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '$vaccineName ($doseLabel) — $doctorLabel',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 4),
          if (givenAt != null && givenAt.isNotEmpty) ...[
            Text(
              _formatGivenAt(givenAt),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
          ],
        ],
      ),
    );
  }
}

/// "Next up" banner showing the next due vaccine dose.
class _NextUpBanner extends StatelessWidget {
  final Map<String, dynamic> nextDue;

  const _NextUpBanner({required this.nextDue});

  String _formatDueDate(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw);
      return DateFormat('MMM d, yyyy').format(dt);
    } catch (_) {
      return raw;
    }
  }

  @override
  Widget build(BuildContext context) {
    final vaccineName   = nextDue['vaccine_name']?.toString() ?? '';
    final scheduleLabel = nextDue['schedule_label']?.toString() ?? '';
    final dueDateRaw    = nextDue['due_date_estimate']?.toString();
    final status        = nextDue['status']?.toString() ?? '';

    final duePart = dueDateRaw != null && dueDateRaw.isNotEmpty
        ? ', due ${_formatDueDate(dueDateRaw)}'
        : '';

    final isOverdue = status == 'overdue';
    final bg = isOverdue ? Colors.red.shade50   : Colors.amber.shade50;
    final fg = isOverdue ? Colors.red.shade700  : Colors.orange.shade800;
    final border = isOverdue ? Colors.red.shade200 : Colors.amber.shade200;

    return Semantics(
      label: isOverdue
          ? 'Overdue: $vaccineName is overdue. $scheduleLabel.'
          : 'Next up: $vaccineName$duePart. $scheduleLabel.',
      child: Container(
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
            Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.notifications_outlined,
              color: fg,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isOverdue
                    ? '$vaccineName ($scheduleLabel) is overdue. Visit the clinic as soon as possible.'
                    : 'Next up: $vaccineName$duePart. Watch for the reminder closer to the date.',
                style: TextStyle(
                  fontSize: 13,
                  color: fg,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullyUpToDateBanner extends StatelessWidget {
  const _FullyUpToDateBanner();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'All required vaccines are up to date.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'All required vaccines are fully up to date. Great job!',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.green.shade800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShowAllProgressButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShowAllProgressButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.blueAccent,
          side: const BorderSide(color: Colors.blueAccent, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Show all progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final IconData icon;

  const _SmallChip({
    required this.label,
    required this.bg,
    required this.fg,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
