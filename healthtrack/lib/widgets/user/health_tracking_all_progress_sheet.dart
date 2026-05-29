import 'package:flutter/material.dart';
import 'package:healthtrack/services/health_tracking_service.dart';

/// Full Health Tracking history: filter chips + sorted list (client-side only).
class HealthTrackingAllProgressSheet extends StatefulWidget {
  final List<Map<String, dynamic>> rawAppointments;

  const HealthTrackingAllProgressSheet({
    super.key,
    required this.rawAppointments,
  });

  @override
  State<HealthTrackingAllProgressSheet> createState() =>
      _HealthTrackingAllProgressSheetState();
}

class _HealthTrackingAllProgressSheetState
    extends State<HealthTrackingAllProgressSheet> {
  List<Map<String, dynamic>>? _history;
  ProgressStatus? _filter;

  static const Color _primaryBlue = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _history =
            HealthTrackingService.allTrackingEntriesMerged(widget.rawAppointments);
      });
    });
  }

  List<Map<String, dynamic>> _visibleEntries() {
    final h = _history;
    if (h == null) return [];
    if (_filter == null) return h;
    return h.where((a) {
      final kind = HealthTrackingService.rowKindForHealthTracking(a);
      if (kind == null) return false;
      return HealthTrackingService.progressStatusFromRowKind(kind) == _filter;
    }).toList();
  }

  String _filterEmptyMessage() {
    return switch (_filter) {
      ProgressStatus.completed => 'No completed entries found.',
      ProgressStatus.inProgress => 'No in progress entries found.',
      ProgressStatus.missed => 'No missed entries found.',
      null => 'No entries found.',
    };
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleEntries();
    final loading = _history == null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                      tooltip: 'Close',
                    ),
                    Expanded(
                      child: Text(
                        'All progress',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _filterChip(context, label: 'All', selected: _filter == null, onTap: () {
                      setState(() => _filter = null);
                    }),
                    _filterChip(
                      context,
                      label: 'Completed',
                      selected: _filter == ProgressStatus.completed,
                      onTap: () {
                        setState(() => _filter = ProgressStatus.completed);
                      },
                    ),
                    _filterChip(
                      context,
                      label: 'In Progress',
                      selected: _filter == ProgressStatus.inProgress,
                      onTap: () {
                        setState(() => _filter = ProgressStatus.inProgress);
                      },
                    ),
                    _filterChip(
                      context,
                      label: 'Missed',
                      selected: _filter == ProgressStatus.missed,
                      onTap: () {
                        setState(() => _filter = ProgressStatus.missed);
                      },
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : visible.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _filter == null
                                    ? 'No entries found.'
                                    : _filterEmptyMessage(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                  height: 1.35,
                                ),
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            itemCount: visible.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _HistoryEntryCard(appt: visible[index]),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _filterChip(
    BuildContext context, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _primaryBlue.withOpacity(0.2),
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? _primaryBlue : Colors.grey.shade800,
        ),
        side: BorderSide(
          color: selected ? _primaryBlue : Colors.grey.shade300,
          width: selected ? 1.5 : 1,
        ),
      ),
    );
  }
}

class _HistoryEntryCard extends StatelessWidget {
  final Map<String, dynamic> appt;

  const _HistoryEntryCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final kind = HealthTrackingService.rowKindForHealthTracking(appt)!;
    final status = HealthTrackingService.progressStatusFromRowKind(kind);
    final module =
        HealthTrackingService.moduleDisplayName(appt['appointment_type']?.toString());
    final activity = HealthTrackingService.activityTitleForEntry(appt);
    final ts = HealthTrackingService.progressEventTimestamp(appt);
    final dateLine = ts != null ? _formatLocalDateTime(ts) : 'Schedule unknown';

    late final String statusEmoji;
    late final String statusLabel;
    late final Color statusBg;
    late final Color statusFg;
    switch (status) {
      case ProgressStatus.completed:
        statusEmoji = '✅';
        statusLabel = 'Completed';
        statusBg = Colors.green.shade50;
        statusFg = Colors.green.shade800;
        break;
      case ProgressStatus.inProgress:
        statusEmoji = '🔄';
        statusLabel = 'In Progress';
        statusBg = const Color(0xFFCCFBF1);
        statusFg = const Color(0xFF0F766E);
        break;
      case ProgressStatus.missed:
        statusEmoji = '❌';
        statusLabel = 'Missed';
        statusBg = Colors.red.shade50;
        statusFg = Colors.red.shade800;
        break;
    }

    final progressLine = _progressLine(appt, kind, activity);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateLine,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        module,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusFg.withOpacity(0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(statusEmoji, style: const TextStyle(fontSize: 12)),
                      const SizedBox(width: 4),
                      Text(
                        statusLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: statusFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              activity,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              progressLine,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade800,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLocalDateTime(DateTime dt) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final h = dt.hour;
    final m = dt.minute;
    final period = h >= 12 ? 'PM' : 'AM';
    final hour12 = h % 12 == 0 ? 12 : h % 12;
    final mm = m.toString().padLeft(2, '0');
    return '${months[dt.month - 1]} ${dt.day}, ${dt.year} • $hour12:$mm $period';
  }

  String _progressLine(
    Map<String, dynamic> appt,
    HealthTrackingRowKind kind,
    String activity,
  ) {
    switch (kind) {
      case HealthTrackingRowKind.completed:
        final raw = appt['completed_at'];
        final formatted = raw != null && raw.toString().trim().isNotEmpty
            ? HealthTrackingService.formatOutcomeTimestamp(raw)
            : '';
        final tail = formatted.isNotEmpty ? ' — Done ($formatted)' : ' — Done';
        return '$activity$tail';
      case HealthTrackingRowKind.inProgress:
        final schedule =
            HealthTrackingService.formatAppointmentScheduleLine(appt);
        return '$activity — In progress • $schedule';
      case HealthTrackingRowKind.missed:
        final raw = appt['missed_at'];
        final formatted = raw != null && raw.toString().trim().isNotEmpty
            ? HealthTrackingService.formatOutcomeTimestamp(raw)
            : '';
        if (formatted.isNotEmpty) {
          return '$activity — Missed (recorded $formatted)';
        }
        return '$activity — Missed';
    }
  }
}
