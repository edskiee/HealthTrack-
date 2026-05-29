import 'package:flutter/material.dart';
import 'package:healthtrack/services/health_tracking_service.dart';
import 'package:healthtrack/widgets/user/health_tracking_all_progress_sheet.dart';

/// Health Tracking section: today's progress for Immunization / Maternal, plus full history sheet.
class HealthTrackingCard extends StatelessWidget {
  /// Entries for **today only** (local calendar) in [selectedCategory].
  final List<Map<String, dynamic>> appointments;

  /// Whether the category has any trackable rows (approved / completed / missed).
  final bool categoryHasTrackedEntries;

  /// Full appointment list from the existing API (used for the history sheet, lazy merge).
  final List<Map<String, dynamic>> allRawAppointments;

  final bool isLoading;
  final String? loadError;
  final HealthScheduleCategory selectedCategory;
  final bool showCategoryToggle;
  final ValueChanged<HealthScheduleCategory> onCategorySelected;
  final VoidCallback onRetry;

  const HealthTrackingCard({
    super.key,
    required this.appointments,
    required this.categoryHasTrackedEntries,
    required this.allRawAppointments,
    required this.isLoading,
    this.loadError,
    required this.selectedCategory,
    required this.showCategoryToggle,
    required this.onCategorySelected,
    required this.onRetry,
  });

  static const Color _primaryBlue = Colors.blueAccent;

  bool get _hasAnyHistory {
    final raw = allRawAppointments;
    return HealthTrackingService.trackingEntriesForCategory(
              raw,
              HealthScheduleCategory.immunization,
            ).isNotEmpty ||
        HealthTrackingService.trackingEntriesForCategory(
              raw,
              HealthScheduleCategory.maternal,
            ).isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Health Tracking',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
              ),
              _buildCategoryPills(context),
            ],
          ),
          const SizedBox(height: 16),
          if (loadError != null && loadError!.isNotEmpty) ...[
            _buildErrorBanner(context),
            const SizedBox(height: 12),
          ],
          if (isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 12),
                    Text('Loading health tracking…'),
                  ],
                ),
              ),
            )
          else if (!categoryHasTrackedEntries && appointments.isEmpty)
            _buildEmptyState(context)
          else ...[
            _buildTodaySummaryCard(context),
            const SizedBox(height: 12),
            if (appointments.isEmpty)
              _buildNoProgressToday(context)
            else
              _buildAppointmentList(context),
            if (_hasAnyHistory) ...[
              const SizedBox(height: 12),
              _buildShowAllProgressButton(context),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildErrorBanner(BuildContext context) {
    return Semantics(
      label: 'Health tracking could not be loaded',
      container: true,
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
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    loadError!,
                    style: TextStyle(
                      color: Colors.red.shade900,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                ),
                Text(
                  'Retry',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.red.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryPills(BuildContext context) {
    if (showCategoryToggle) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _pill(
            context,
            label: 'Immunization',
            icon: Icons.vaccines,
            selected: selectedCategory == HealthScheduleCategory.immunization,
            onTap: () =>
                onCategorySelected(HealthScheduleCategory.immunization),
          ),
          const SizedBox(width: 8),
          _pill(
            context,
            label: 'Maternal Care',
            icon: Icons.pregnant_woman,
            selected: selectedCategory == HealthScheduleCategory.maternal,
            onTap: () =>
                onCategorySelected(HealthScheduleCategory.maternal),
          ),
        ],
      );
    }

    final maternal = selectedCategory == HealthScheduleCategory.maternal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _primaryBlue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            maternal ? Icons.pregnant_woman : Icons.vaccines,
            size: 16,
            color: _primaryBlue,
          ),
          const SizedBox(width: 4),
          Text(
            maternal ? 'Maternal Care' : 'Immunization',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? _primaryBlue.withOpacity(0.15) : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? _primaryBlue : Colors.grey.shade300,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: selected ? _primaryBlue : Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: selected ? _primaryBlue : Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodaySummaryCard(BuildContext context) {
    var completed = 0;
    var inProgress = 0;
    var missed = 0;
    for (final a in appointments) {
      final kind = HealthTrackingService.rowKindForHealthTracking(a);
      if (kind == null) continue;
      switch (kind) {
        case HealthTrackingRowKind.completed:
          completed++;
          break;
        case HealthTrackingRowKind.inProgress:
          inProgress++;
          break;
        case HealthTrackingRowKind.missed:
          missed++;
          break;
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_primaryBlue.withOpacity(0.12), Colors.white],
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
                  fontSize: 16,
                  color: const Color(0xFF0F172A),
                ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _miniStat('✅ Completed', completed, Colors.green.shade800),
              ),
              Expanded(
                child: _miniStat('🔄 In progress', inProgress, const Color(0xFF0F766E)),
              ),
              Expanded(
                child: _miniStat('❌ Missed', missed, Colors.red.shade800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade700, height: 1.2),
        ),
        const SizedBox(height: 4),
        Text(
          '$value',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No active immunization or maternal appointments to track yet.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
              height: 1.35,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'When an appointment is approved, completed, or missed, it will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoProgressToday(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.today_outlined, size: 44, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'No progress recorded for today. Start tracking!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.grey[800],
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShowAllProgressButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            useSafeArea: true,
            backgroundColor: Colors.transparent,
            builder: (ctx) => HealthTrackingAllProgressSheet(
              rawAppointments: allRawAppointments,
            ),
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: _primaryBlue,
          side: const BorderSide(color: _primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: const Text(
          'Show All Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildAppointmentList(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          for (var i = 0; i < appointments.length; i++) ...[
            if (i > 0) Divider(height: 20, color: Colors.grey[300]),
            _buildTrackingRow(context, appointments[i]),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingRow(
    BuildContext context,
    Map<String, dynamic> appt,
  ) {
    final kind = HealthTrackingService.rowKindForHealthTracking(appt)!;
    final typeLabel =
        HealthTrackingService.categoryLabelForType(appt['appointment_type']?.toString());
    final maternal = HealthTrackingService.isMaternalType(
      appt['appointment_type']?.toString(),
    );
    final scheduleLine = HealthTrackingService.formatAppointmentScheduleLine(appt);
    final activityTitle = HealthTrackingService.activityTitleForEntry(appt);

    late final String statusLabel;
    late final String statusEmoji;
    late final Color statusBg;
    late final Color statusFg;
    late final IconData statusIcon;
    switch (kind) {
      case HealthTrackingRowKind.inProgress:
        statusEmoji = '🔄';
        statusLabel = 'In Progress';
        statusBg = const Color(0xFFCCFBF1);
        statusFg = const Color(0xFF0F766E);
        statusIcon = Icons.pending_actions_rounded;
        break;
      case HealthTrackingRowKind.completed:
        statusEmoji = '✅';
        statusLabel = 'Completed';
        statusBg = Colors.green.shade50;
        statusFg = Colors.green.shade800;
        statusIcon = Icons.check_circle_rounded;
        break;
      case HealthTrackingRowKind.missed:
        statusEmoji = '❌';
        statusLabel = 'Missed';
        statusBg = Colors.red.shade50;
        statusFg = Colors.red.shade800;
        statusIcon = Icons.event_busy_rounded;
        break;
    }

    final completedRaw = appt['completed_at'];
    final missedRaw = appt['missed_at'];
    final outcomeNote = kind == HealthTrackingRowKind.completed &&
            completedRaw != null &&
            completedRaw.toString().trim().isNotEmpty
        ? 'Completed ${HealthTrackingService.formatOutcomeTimestamp(completedRaw)}'
        : kind == HealthTrackingRowKind.missed &&
                missedRaw != null &&
                missedRaw.toString().trim().isNotEmpty
            ? 'Missed (recorded ${HealthTrackingService.formatOutcomeTimestamp(missedRaw)})'
            : kind == HealthTrackingRowKind.missed
                ? 'This visit was marked as missed.'
                : null;

    final accessibilityLabel =
        '$typeLabel appointment. $statusLabel. $activityTitle. $scheduleLine.${outcomeNote != null ? ' $outcomeNote' : ''}';

    return Semantics(
      label: accessibilityLabel,
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: statusFg, width: 4),
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.only(left: 12, right: 4, bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _chipLabel(
                        typeLabel,
                        bg: _primaryBlue.withOpacity(0.12),
                        fg: const Color(0xFF1D4ED8),
                        icon: maternal ? Icons.pregnant_woman : Icons.vaccines,
                      ),
                      _chipLabel(
                        '$statusEmoji $statusLabel',
                        bg: statusBg,
                        fg: statusFg,
                        icon: statusIcon,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    activityTitle,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    scheduleLine,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF334155),
                    ),
                  ),
                  if (outcomeNote != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      outcomeNote,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[800],
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chipLabel(
    String text, {
    required Color bg,
    required Color fg,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
