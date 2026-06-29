import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import '../utils/message_utils.dart';
import '../utils/time_utils.dart';
import '../services/appointment_service.dart';
import '../services/connection_status_service.dart';
import 'widgets/admin_header.dart';

class AppointmentsView extends StatefulWidget {
  const AppointmentsView({super.key});

  @override
  State<AppointmentsView> createState() => _AppointmentsViewState();
}

class _AppointmentsViewState extends State<AppointmentsView> {
  String _currentView = 'approved'; // approved, rescheduled

  List<Map<String, dynamic>> _appointments = [];
  List<Map<String, dynamic>> _approvedAppointments = [];
  List<Map<String, dynamic>> _rescheduledAppointments = [];
  bool _isLoading = true;
  String _errorMessage = '';
  Timer? _refreshTimer;

  final TextEditingController _searchController = TextEditingController();

  /// Applied filter state (combined with search using AND logic).
  DateTime? _filterDateFrom;
  DateTime? _filterDateTo;
  final Set<String> _filterDoctors = {};
  final Set<String> _filterTimeOfDay = {};
  String _filterPatientName = '';

  /// Prevents duplicate parallel status API calls for the same appointment (e.g. menu + poll rebuild).
  final Set<int> _updatingAppointmentIds = {};

  final Color blueAccent = Colors.blueAccent;
  final Color green = Colors.green;
  final Color orange = Colors.orange;
  final Color red = Colors.red;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
    // Start periodic refresh for real-time synchronization
    _startPeriodicRefresh();
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: Duration(seconds: 3),
      ),
    );
  }

  // Show appointment update notification banner
  void _showAppointmentUpdateBanner(String title, String message) {
    showOverlayNotification(
      (context) {
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.blueAccent.withOpacity(0.2),
              child: const Icon(Icons.event, color: Colors.blueAccent),
            ),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(message),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              OverlaySupportEntry.of(context)!.dismiss();
              // You can add navigation logic here if needed
            },
          ),
        );
      },
      duration: const Duration(seconds: 5),
      position: NotificationPosition.top,
    );
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) {
        _loadAppointments(silent: _updatingAppointmentIds.isNotEmpty);
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAppointments({bool silent = false}) async {
    try {
      if (!silent) {
        setState(() {
          _isLoading = true;
          _errorMessage = '';
        });
      } else if (mounted) {
        setState(() => _errorMessage = '');
      }

      final appointments = await AppointmentService.getAllAppointments();
      
      if (!mounted) return;
      
      setState(() {
        _appointments = appointments;
        _categorizeAppointments();
        if (!silent) {
          _isLoading = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = ConnectionStatusService.friendlyError(e);
        _isLoading = false;
      });
      MessageUtils.showNetworkError(context, e);
    }
  }

  void _categorizeAppointments() {
    _approvedAppointments = _appointments
        .where((apt) => apt['status'] == 'approved')
        .toList();
    _rescheduledAppointments = _appointments
        .where((apt) => apt['status'] == 'rescheduled' || apt['status'] == 'scheduled' || apt['status'] == 'pending')
        .toList();
  }

  int _appointmentNumericId(Map<String, dynamic> apt) {
    final v = apt['id'];
    if (v is int) return v;
    return int.tryParse('$v') ?? -1;
  }

  Future<void> _confirmAndSetVisitOutcome(
    Map<String, dynamic> appointment,
    String status,
  ) async {
    final patientName = appointment["patient_full_name"] ??
        appointment["patient_name"] ??
        appointment["user_full_name"] ??
        "this patient";
    final isComplete = status == 'completed';
    final title = isComplete ? 'Mark visit complete' : 'Mark visit as missed';
    final message = isComplete
        ? 'Mark $patientName\'s appointment as complete? The patient will see this in Health Tracking right away.'
        : 'Mark $patientName\'s appointment as missed? The patient will see this in Health Tracking right away.';

    final confirmed = await _showConfirmDialog(title, message);
    if (confirmed) {
      await _updateAppointmentStatus(appointment['id'], status);
    }
  }

  // ✅ Show confirmation dialogs
  void _handleAction(String action, Map<String, dynamic> appointment) async {
     final patientName = appointment["patient_full_name"] ?? appointment["patient_name"] ?? appointment["user_full_name"] ?? "Unknown Patient";

    if (action == 'delete') {
      final confirmed = await _showConfirmDialog(
        'Delete Appointment',
        'Are you sure you want to delete this appointment? This action cannot be undone.',
      );
      if (confirmed) {
        await _deleteAppointment(appointment['id']);
      }
      return;
    }

    if (action == 'approve') {
      final confirmed = await _showConfirmDialog(
        'Approve Appointment',
        'Are you sure you want to approve $patientName\'s appointment?',
      );
      if (confirmed) {
        await _updateAppointmentStatus(appointment['id'], 'approved');
      }
    } else if (action == 'cancel') {
      final confirmed = await _showConfirmDialog(
        'Cancel Appointment',
        'Are you sure you want to cancel $patientName\'s appointment?',
      );
      if (confirmed) {
        await _updateAppointmentStatus(appointment['id'], 'cancelled');
      }
    } else if (action == 'reschedule') {
      _showRescheduleForm(appointment);
    }
  }

  Future<void> _deleteAppointment(int appointmentId) async {
    try {
      setState(() => _isLoading = true);
      
      // Call delete API endpoint
      final result = await AppointmentService.deleteAppointment(appointmentId.toString());
      
      // Robust type checking for success field
      bool isSuccess = false;
      if (result['success'] is bool) {
        isSuccess = result['success'];
      } else if (result['success'] is String) {
        isSuccess = result['success'].toLowerCase() == 'true';
      } else if (result['success'] is int) {
        isSuccess = result['success'] == 1;
      }
      
      if (isSuccess) {
        // Remove from all lists immediately for real-time update
        setState(() {
          _appointments.removeWhere((apt) => apt['id'] == appointmentId);
          _categorizeAppointments();
          _isLoading = false;
        });
        
        _showSuccessMessage('Appointment deleted successfully');
        
        // Show notification banner
        _showAppointmentUpdateBanner("Appointment Deleted", "Appointment deleted successfully");
      } else {
        setState(() => _isLoading = false);
        _showErrorMessage(result['message'] ?? 'Failed to delete appointment');
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorMessage(ConnectionStatusService.friendlyError(e));
    }
  }

  Future<void> _updateAppointmentStatus(int appointmentId, String status) async {
    if (_updatingAppointmentIds.contains(appointmentId)) return;
    setState(() => _updatingAppointmentIds.add(appointmentId));

    try {
      final result = await AppointmentService.updateAppointmentStatus(
        appointmentId.toString(),
        status,
      );

      bool isSuccess = false;
      if (result['success'] is bool) {
        isSuccess = result['success'];
      } else if (result['success'] is String) {
        isSuccess = result['success'].toLowerCase() == 'true';
      } else if (result['success'] is int) {
        isSuccess = result['success'] == 1;
      }

      if (isSuccess) {
        if (mounted) {
          setState(() {
            final index = _appointments.indexWhere((apt) => apt['id'] == appointmentId);
            if (index != -1) {
              _appointments[index]['status'] = status;
            }
            _categorizeAppointments();
          });
        }

        final msg = ((result['message']?.toString().toLowerCase().contains('already') ?? false))
            ? 'Appointment status unchanged (already up to date).'
            : 'Appointment ${status.toLowerCase()} successfully';
        _showSuccessMessage(msg);
        _showAppointmentUpdateBanner('Appointment Updated', msg);
        await _loadAppointments(silent: true);
      } else {
        _showErrorMessage(result['message'] ?? 'Failed to update appointment status');
      }
    } catch (e) {
      _showErrorMessage(ConnectionStatusService.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() => _updatingAppointmentIds.remove(appointmentId));
      }
    }
  }

  Future<bool> _showConfirmDialog(String title, String message) async {
    return (await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("Cancel")),
              ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text("Confirm")),
            ],
          ),
        )) ??
        false;
  }

  void _showRescheduleForm(Map<String, dynamic> appointment) {
    DateTime? newDate;
    TimeOfDay? newTime;
    final TextEditingController notesController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text('Reschedule Appointment'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: Text('Select New Date'),
                      subtitle: Text(newDate == null
                          ? 'Tap to select date'
                          : '${newDate!.day}/${newDate!.month}/${newDate!.year}'),
                      leading: Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => newDate = picked);
                        }
                      },
                    ),
                    ListTile(
                      title: Text('Select New Time'),
                      subtitle: Text(newTime == null
                          ? 'Tap to select time'
                          : newTime!.format(context)),
                      leading: Icon(Icons.access_time),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setState(() => newTime = picked);
                        }
                      },
                    ),
                    TextField(
                      controller: notesController,
                      decoration: InputDecoration(
                        labelText: 'Reason for Rescheduling (Optional)',
                        hintText: 'Enter reason...',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (newDate == null || newTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Please select both date and time'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(context); // Close dialog
                    setState(() => _isLoading = true);

                    try {
                      final result = await AppointmentService.updateAppointmentStatus(
                        appointment['id'].toString(),
                        'rescheduled',
                        rescheduleDate: newDate!.toIso8601String(),
                        rescheduleTime: '${newTime!.hour.toString().padLeft(2, '0')}:${newTime!.minute.toString().padLeft(2, '0')}',
                        notes: notesController.text,
                      );

                      // Robust type checking for success field
                      bool isSuccess = false;
                      if (result['success'] is bool) {
                        isSuccess = result['success'];
                      } else if (result['success'] is String) {
                        isSuccess = result['success'].toLowerCase() == 'true';
                      } else if (result['success'] is int) {
                        isSuccess = result['success'] == 1;
                      }
                      
                      if (isSuccess) {
                        // Update the appointment in the list immediately
                        setState(() {
                          final index = _appointments.indexWhere((apt) => apt['id'] == appointment['id']);
                          if (index != -1) {
                            _appointments[index]['status'] = 'rescheduled';
                            _appointments[index]['appointment_date'] = newDate!.toIso8601String();
                            _appointments[index]['appointment_time'] = '${newTime!.hour.toString().padLeft(2, '0')}:${newTime!.minute.toString().padLeft(2, '0')}';
                            _appointments[index]['notes'] = notesController.text;
                          }
                          _categorizeAppointments();
                          _isLoading = false;
                        });

                        _showSuccessMessage('Appointment rescheduled successfully');
                        
                        // Show notification banner
                        _showAppointmentUpdateBanner("Appointment Rescheduled", "Appointment rescheduled successfully");
                      } else {
                        setState(() => _isLoading = false);
                        _showErrorMessage(result['message'] ?? 'Failed to reschedule appointment');
                      }
                    } catch (e) {
                      setState(() => _isLoading = false);
                      _showErrorMessage(ConnectionStatusService.friendlyError(e));
                    }
                  },
                  child: Text('Reschedule'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Format time string helper
  String _formatTimeString12Hour(String timeString) {
    try {
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);
      return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
    } catch (e) {
      return timeString;
    }
  }

  DateTime? _getAppointmentDateTime(Map<String, dynamic> appointment) {
    final date = (appointment['appointment_date'] ?? '').toString();
    final time = (appointment['appointment_time'] ?? '').toString();
    if (date.isEmpty) return null;
    final safeTime = time.isEmpty ? '00:00:00' : (time.length == 5 ? '$time:00' : time);
    return DateTime.tryParse('$date $safeTime');
  }

  bool _isAppointmentToday(Map<String, dynamic> appointment) {
    final appointmentDateTime = _getAppointmentDateTime(appointment);
    if (appointmentDateTime == null) return false;
    final now = DateTime.now().toLocal();
    final localAppointment = appointmentDateTime.toLocal();
    return now.day == localAppointment.day &&
        now.month == localAppointment.month &&
        now.year == localAppointment.year;
  }

  String _patientName(Map<String, dynamic> appointment) {
    return (appointment['patient_full_name'] ??
            appointment['patient_name'] ??
            appointment['user_full_name'] ??
            '')
        .toString();
  }

  String _doctorNameRaw(Map<String, dynamic> appointment) {
    return (appointment['doctor_name'] ?? '').toString();
  }

  DateTime? _appointmentDateOnly(Map<String, dynamic> appointment) {
    final raw = (appointment['appointment_date'] ?? '').toString();
    if (raw.isEmpty) return null;
    final datePart = raw.length >= 10 ? raw.substring(0, 10) : raw;
    return DateTime.tryParse(datePart);
  }

  int? _appointmentHour24(Map<String, dynamic> appointment) {
    final t = (appointment['appointment_time'] ?? '').toString();
    if (t.isEmpty) return null;
    final parts = t.split(':');
    return int.tryParse(parts[0]);
  }

  bool _hasActiveFilters() {
    return _filterDateFrom != null ||
        _filterDateTo != null ||
        _filterDoctors.isNotEmpty ||
        _filterTimeOfDay.isNotEmpty ||
        _filterPatientName.trim().isNotEmpty;
  }

  List<String> _uniqueDoctorNames() {
    final names = <String>{};
    for (final apt in _appointments) {
      final n = _doctorNameRaw(apt).trim();
      if (n.isNotEmpty) names.add(n);
    }
    final list = names.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return list;
  }

  bool _matchesSearchQuery(Map<String, dynamic> appointment) {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return true;

    final patient = _patientName(appointment).toLowerCase();
    final doctor = _doctorNameRaw(appointment).toLowerCase();
    final date = (appointment['appointment_date'] ?? '').toString().toLowerCase();
    final time = (appointment['appointment_time'] ?? '').toString().toLowerCase();
    var display = '';
    try {
      display = TimeUtils.formatAppointmentUtcDateTime(
        (appointment['appointment_date'] ?? '').toString(),
        (appointment['appointment_time'] ?? '').toString(),
        pattern: 'MMMM dd, yyyy hh:mm a',
      ).toLowerCase();
    } catch (_) {}

    return patient.contains(q) ||
        doctor.contains(q) ||
        date.contains(q) ||
        time.contains(q) ||
        display.contains(q);
  }

  bool _matchesTimeOfDayFilters(Map<String, dynamic> appointment) {
    if (_filterTimeOfDay.isEmpty) return true;
    final h = _appointmentHour24(appointment);
    if (h == null) return false;
    for (final slot in _filterTimeOfDay) {
      if (slot == 'morning' && h < 12) return true;
      if (slot == 'afternoon' && h >= 12 && h < 17) return true;
      if (slot == 'evening' && h >= 17) return true;
    }
    return false;
  }

  bool _matchesDoctorFilters(Map<String, dynamic> appointment) {
    if (_filterDoctors.isEmpty) return true;
    final doc = _doctorNameRaw(appointment).trim();
    for (final selected in _filterDoctors) {
      if (doc.toLowerCase() == selected.toLowerCase()) return true;
    }
    return false;
  }

  bool _matchesDateRangeFilter(Map<String, dynamic> appointment) {
    if (_filterDateFrom == null && _filterDateTo == null) return true;
    final aptDate = _appointmentDateOnly(appointment);
    if (aptDate == null) return false;

    DateTime startOf(DateTime d) => DateTime(d.year, d.month, d.day);
    final apt = startOf(aptDate);

    if (_filterDateFrom != null) {
      final from = startOf(_filterDateFrom!);
      if (apt.isBefore(from)) return false;
    }
    if (_filterDateTo != null) {
      final to = startOf(_filterDateTo!);
      if (apt.isAfter(to)) return false;
    }
    return true;
  }

  bool _matchesAppliedFilters(Map<String, dynamic> appointment) {
    if (!_matchesDateRangeFilter(appointment)) return false;
    if (!_matchesDoctorFilters(appointment)) return false;
    if (!_matchesTimeOfDayFilters(appointment)) return false;

    final p = _filterPatientName.trim().toLowerCase();
    if (p.isNotEmpty) {
      if (!_patientName(appointment).toLowerCase().contains(p)) return false;
    }
    return true;
  }

  bool _passesSearchAndFilters(Map<String, dynamic> appointment) {
    return _matchesSearchQuery(appointment) && _matchesAppliedFilters(appointment);
  }

  List<Map<String, dynamic>> _filteredForTab(List<Map<String, dynamic>> source) {
    return source.where(_passesSearchAndFilters).toList();
  }

  void _clearAppliedFilters() {
    setState(() {
      _filterDateFrom = null;
      _filterDateTo = null;
      _filterDoctors.clear();
      _filterTimeOfDay.clear();
      _filterPatientName = '';
    });
  }

  void _showFilterPanel() {
    DateTime? draftFrom = _filterDateFrom;
    DateTime? draftTo = _filterDateTo;
    final draftDoctors = Set<String>.from(_filterDoctors);
    final draftTime = Set<String>.from(_filterTimeOfDay);
    final draftPatientController = TextEditingController(text: _filterPatientName);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: StatefulBuilder(
            builder: (_, modalSetState) {
              Future<void> pickDate(String which) async {
                final initial = which == 'from'
                    ? (draftFrom ?? DateTime.now())
                    : (draftTo ?? draftFrom ?? DateTime.now());
                final picked = await showDatePicker(
                  context: context,
                  initialDate: initial,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked == null || !mounted) return;
                modalSetState(() {
                  if (which == 'from') {
                    draftFrom = picked;
                  } else {
                    draftTo = picked;
                  }
                });
              }

              final doctors = _uniqueDoctorNames();

              Widget sectionTitle(String text) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8, top: 4),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                    ),
                  ),
                );
              }

              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      sectionTitle('Date range'),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickDate('from'),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                draftFrom == null
                                    ? 'From'
                                    : '${draftFrom!.year}-${draftFrom!.month.toString().padLeft(2, '0')}-${draftFrom!.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => pickDate('to'),
                              icon: const Icon(Icons.calendar_today, size: 16),
                              label: Text(
                                draftTo == null
                                    ? 'To'
                                    : '${draftTo!.year}-${draftTo!.month.toString().padLeft(2, '0')}-${draftTo!.day.toString().padLeft(2, '0')}',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      sectionTitle('Doctor'),
                      if (doctors.isEmpty)
                        const Text(
                          'No doctors in loaded appointments.',
                          style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
                        )
                      else
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: doctors.map((name) {
                            final selected = draftDoctors.contains(name);
                            return FilterChip(
                              label: Text(name),
                              selected: selected,
                              onSelected: (v) {
                                modalSetState(() {
                                  if (v) {
                                    draftDoctors.add(name);
                                  } else {
                                    draftDoctors.remove(name);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 16),
                      sectionTitle('Time of day'),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Morning (before 12PM)'),
                            selected: draftTime.contains('morning'),
                            onSelected: (v) {
                              modalSetState(() {
                                if (v) {
                                  draftTime.add('morning');
                                } else {
                                  draftTime.remove('morning');
                                }
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Afternoon (12PM–5PM)'),
                            selected: draftTime.contains('afternoon'),
                            onSelected: (v) {
                              modalSetState(() {
                                if (v) {
                                  draftTime.add('afternoon');
                                } else {
                                  draftTime.remove('afternoon');
                                }
                              });
                            },
                          ),
                          FilterChip(
                            label: const Text('Evening (after 5PM)'),
                            selected: draftTime.contains('evening'),
                            onSelected: (v) {
                              modalSetState(() {
                                if (v) {
                                  draftTime.add('evening');
                                } else {
                                  draftTime.remove('evening');
                                }
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      sectionTitle('Patient name (optional)'),
                      TextField(
                        controller: draftPatientController,
                        decoration: const InputDecoration(
                          hintText: 'Filter by patient name',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                _clearAppliedFilters();
                              },
                              child: const Text('Clear filters / Reset'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                if (draftFrom != null &&
                                    draftTo != null &&
                                    draftFrom!.isAfter(draftTo!)) {
                                  MessageUtils.showErrorMessage(
                                    context,
                                    '"From" date cannot be after "To" date.',
                                  );
                                  return;
                                }
                                setState(() {
                                  _filterDateFrom = draftFrom;
                                  _filterDateTo = draftTo;
                                  _filterDoctors
                                    ..clear()
                                    ..addAll(draftDoctors);
                                  _filterTimeOfDay
                                    ..clear()
                                    ..addAll(draftTime);
                                  _filterPatientName = draftPatientController.text;
                                });
                                Navigator.pop(ctx);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                              ),
                              child: const Text('Apply filters'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(() => draftPatientController.dispose());
  }

  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'DR';
    final parts = trimmed.split(' ').where((part) => part.isNotEmpty).toList();
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return trimmed.substring(0, min(2, trimmed.length)).toUpperCase();
  }

  Widget _buildStatsSummaryRow() {
    final totalCount = _appointments.length;
    final approvedCount = _appointments
        .where((apt) => (apt['status'] ?? '').toString().toLowerCase() == 'approved')
        .length;
    final rescheduledCount = _appointments
        .where((apt) => (apt['status'] ?? '').toString().toLowerCase() == 'rescheduled')
        .length;
    final todayCount = _appointments.where(_isAppointmentToday).length;

    // Each card fills its Expanded slot — no fixed min/max widths.
    Widget statCard(String label, int count, Color color) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      );
    }

    // Use LayoutBuilder so cards reflow gracefully on narrow screens (< 480px):
    //   wide  → single Row, all 4 cards side-by-side with equal width
    //   narrow → two Rows of 2 cards each (2×2 grid)
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final isWide = constraints.maxWidth >= 480;

        if (isWide) {
          // ── Full-width 4-column row ────────────────────────────────────────
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: statCard('Total',       totalCount,       const Color(0xFF3B82F6))),
              const SizedBox(width: gap),
              Expanded(child: statCard('Approved',    approvedCount,    const Color(0xFF22C55E))),
              const SizedBox(width: gap),
              Expanded(child: statCard('Rescheduled', rescheduledCount, const Color(0xFFF59E0B))),
              const SizedBox(width: gap),
              Expanded(child: statCard('Today',       todayCount,       const Color(0xFF14B8A6))),
            ],
          );
        }

        // ── Narrow: 2×2 grid ──────────────────────────────────────────────
        return Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statCard('Total',    totalCount,    const Color(0xFF3B82F6))),
                const SizedBox(width: gap),
                Expanded(child: statCard('Approved', approvedCount, const Color(0xFF22C55E))),
              ],
            ),
            const SizedBox(height: gap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: statCard('Rescheduled', rescheduledCount, const Color(0xFFF59E0B))),
                const SizedBox(width: gap),
                Expanded(child: statCard('Today',       todayCount,       const Color(0xFF14B8A6))),
              ],
            ),
          ],
        );
      },
    );
  }

  // Enhanced Compact Slot Card with Content-Driven Layout
  Widget _buildCompactSlotCard(String slotKey, List<Map<String, dynamic>> appointments) {
    final appointment = appointments.first;
    final date = appointment['appointment_date'] ?? '';
    final time = appointment['appointment_time'] ?? '';
    final scheduleDisplay = TimeUtils.formatAppointmentUtcDateTime(
      date.toString(),
      time.toString(),
      pattern: 'MMMM dd, yyyy hh:mm a',
    );
    final doctorName = appointment['doctor_name'] ?? 'Unknown Doctor';
    final patientName = appointment['patient_full_name'] ?? appointment['patient_name'] ?? appointment['user_full_name'] ?? 'Unknown Patient';
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => _showSlotDetails(slotKey, appointments),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Time and Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Time Display
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        size: 14,
                        color: Color(0xFF3B82F6),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _formatTimeString12Hour(time),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  // Patient Count Badge
                  Row(
                    children: [
                      if (appointments.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: const Color(0xFF3B82F6).withOpacity(0.3)),
                          ),
                          child: Text(
                            '+${appointments.length - 1}',
                            style: const TextStyle(
                              color: Color(0xFF3B82F6),
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      if (_isAppointmentToday(appointment)) ...[
                        if (appointments.length > 1) const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'TODAY',
                            style: TextStyle(
                              color: Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  PopupMenuButton<String>(
                    tooltip: appointments.length == 1 &&
                            _updatingAppointmentIds.contains(_appointmentNumericId(appointments.first))
                        ? 'Updating appointment…'
                        : 'Appointment actions',
                    enabled: appointments.length > 1 ||
                        !_updatingAppointmentIds.contains(_appointmentNumericId(appointments.first)),
                    splashRadius: 22,
                    icon: appointments.length == 1 &&
                            _updatingAppointmentIds.contains(_appointmentNumericId(appointments.first))
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: Padding(
                              padding: EdgeInsets.all(2),
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(
                            Icons.more_vert,
                            size: 20,
                            color: Color(0xFF64748B),
                          ),
                    onSelected: (value) async {
                      switch (value) {
                        case '_open':
                          _showSlotDetails(slotKey, appointments);
                          break;
                        case 'complete':
                          await _confirmAndSetVisitOutcome(appointments.first, 'completed');
                          break;
                      }
                    },
                    itemBuilder: (ctx) {
                      if (appointments.length > 1) {
                        return [
                          PopupMenuItem<String>(
                            value: '_open',
                            child: Semantics(
                              label: 'Open slot details for all patients',
                              child: ListTile(
                                leading: const Icon(Icons.people_outline, size: 22),
                                title: const Text('Patients & actions'),
                                subtitle: const Text('Mark complete per patient'),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ];
                      }
                      return [
                        PopupMenuItem<String>(
                          value: 'complete',
                          child: Semantics(
                            label: 'Mark appointment complete',
                            button: true,
                            child: Row(
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Complete',
                                  style: TextStyle(
                                    color: Colors.green.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ];
                    },
                  ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Middle Section: Patient Name (Primary Focus)
              Text(
                patientName,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              
              const SizedBox(height: 8),
              
              // Bottom Row: Doctor and Date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Doctor Info
                  Expanded(
                    child: Row(
                      children: [
                        Icon(
                          Icons.medical_services,
                          size: 12,
                          color: const Color(0xFF6B7280).withOpacity(0.8),
                        ),
                        const SizedBox(width: 4),
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.blue.shade100,
                          child: Text(
                            _initials(doctorName),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1D4ED8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Dr. $doctorName',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280).withOpacity(0.8),
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Manila schedule
                  Text(
                    scheduleDisplay,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF6B7280).withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSlotDetails(String slotKey, List<Map<String, dynamic>> appointments) {
    final appointment = appointments.first;
    final date = appointment['appointment_date'] ?? '';
    final time = appointment['appointment_time'] ?? '';
    final scheduleDisplay = TimeUtils.formatAppointmentUtcDateTime(
      date.toString(),
      time.toString(),
      pattern: 'MMMM dd, yyyy hh:mm a',
    );
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Slot Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton(
                    onPressed: () => _showSlotDetails(slotKey, appointments),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      foregroundColor: const Color(0xFF3B82F6),
                    ),
                    child: const Text(
                      'View',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => _handleAction('reschedule', appointment),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    child: const Text(
                      'Reschedule',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text('Schedule: $scheduleDisplay', style: const TextStyle(fontSize: 16)),
              const SizedBox(height: 16),
              Text('Patients (${appointments.length}):', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: appointments.length,
                  itemBuilder: (context, index) {
                    final apt = appointments[index];
                    final patientName = apt['patient_full_name'] ?? apt['patient_name'] ?? apt['user_full_name'] ?? 'Unknown Patient';
                    final aid = _appointmentNumericId(apt);
                    final busy = _updatingAppointmentIds.contains(aid);
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(patientName),
                        subtitle: Text('${apt['appointment_type'] ?? 'General'}'),
                        trailing: PopupMenuButton<String>(
                          tooltip: busy ? 'Updating appointment…' : 'Patient appointment actions',
                          enabled: !busy,
                          splashRadius: 22,
                          icon: busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: Padding(
                                    padding: EdgeInsets.all(2),
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                )
                              : const Icon(Icons.more_vert, color: Color(0xFF64748B)),
                          onSelected: (value) async {
                            switch (value) {
                              case 'complete':
                                await _confirmAndSetVisitOutcome(apt, 'completed');
                                break;
                              case 'missed':
                                await _confirmAndSetVisitOutcome(apt, 'no_show');
                                break;
                              case 'reschedule':
                                _handleAction('reschedule', apt);
                                break;
                              case 'delete':
                                _handleAction('delete', apt);
                                break;
                            }
                          },
                          itemBuilder: (ctx) => [
                            PopupMenuItem<String>(
                              value: 'complete',
                              child: Row(
                                children: [
                                  Icon(Icons.check_circle_rounded, color: Colors.green.shade700, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Complete',
                                    style: TextStyle(
                                      color: Colors.green.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'missed',
                              child: Row(
                                children: [
                                  Icon(Icons.cancel_rounded, color: Colors.red.shade700, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Missed',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'reschedule',
                              child: Row(
                                children: [
                                  Icon(Icons.schedule_rounded, color: Colors.orange.shade800, size: 22),
                                  const SizedBox(width: 10),
                                  const Text(
                                    'Reschedule',
                                    style: TextStyle(
                                      color: Color(0xFF475569),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem<String>(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete_outline_rounded, color: Colors.red.shade700, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.red.shade800,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
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

  
  
  
  // Group appointments by time slot for compact card-based layout
  Map<String, List<Map<String, dynamic>>> _groupAppointmentsBySlot(List<Map<String, dynamic>> appointments) {
    final grouped = <String, List<Map<String, dynamic>>>{};
    
    for (final appointment in appointments) {
      // Create a key combining date and time
      final date = appointment['appointment_date'] ?? '';
      final time = appointment['appointment_time'] ?? '';
      final slotKey = '$date $time';
      
      if (!grouped.containsKey(slotKey)) {
        grouped[slotKey] = [];
      }
      grouped[slotKey]!.add(appointment);
    }
    
    return grouped;
  }

  // Build Rescheduled Appointments View with Content-Driven Grid Layout
  Widget _buildRescheduledAppointmentsView(List<Map<String, dynamic>> appointments) {
    final groupedAppointments = _groupAppointmentsBySlot(appointments);
    final sortedKeys = groupedAppointments.keys.toList()
      ..sort((a, b) {
        // Sort by date and time
        return a.compareTo(b);
      });
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
          double itemWidth = (constraints.maxWidth - (12 * (crossAxisCount - 1))) / crossAxisCount;
          itemWidth = itemWidth - 0.1;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: _buildStatsSummaryRow(),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Rescheduled appointments',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${appointments.length} records',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...sortedKeys.map((slotKey) {
                final slotAppointments = groupedAppointments[slotKey]!;
                return SizedBox(
                  width: itemWidth,
                  child: _buildCompactSlotCard(slotKey, slotAppointments),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  // Loading State
  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6)),
            ),
          ),
          SizedBox(height: 16),
          Text(
            'Loading appointments...',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Error State
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFEF4444),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF64748B),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadAppointments,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  // Empty State
  Widget _buildEmptyState(String title, [String subtitle = '']) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inbox_outlined,
              size: 56,
              color: Color(0xFF94A3B8),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
            textAlign: TextAlign.center,
          ),
          if (subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () {
              // Refresh appointments
              _loadAppointments();
            },
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              side: const BorderSide(color: Color(0xFF3B82F6)),
            ),
            child: const Text(
              'Refresh',
              style: TextStyle(color: Color(0xFF3B82F6)),
            ),
          ),
        ],
      ),
    );
  }

  // Build the approved appointments view with content-driven grid layout
  Widget _buildApprovedAppointmentsView(List<Map<String, dynamic>> appointments) {
    final groupedAppointments = _groupAppointmentsBySlot(appointments);
    final sortedKeys = groupedAppointments.keys.toList()
      ..sort((a, b) {
        // Sort by date and time
        return a.compareTo(b);
      });
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          int crossAxisCount = constraints.maxWidth > 900 ? 3 : constraints.maxWidth > 600 ? 2 : 1;
          double itemWidth = (constraints.maxWidth - (12 * (crossAxisCount - 1))) / crossAxisCount;
          itemWidth = itemWidth - 0.1;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.start,
            children: [
              SizedBox(
                width: constraints.maxWidth,
                child: _buildStatsSummaryRow(),
              ),
              SizedBox(
                width: constraints.maxWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Approved appointments',
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${appointments.length} records',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...sortedKeys.map((slotKey) {
                final slotAppointments = groupedAppointments[slotKey]!;
                return SizedBox(
                  width: itemWidth,
                  child: _buildCompactSlotCard(slotKey, slotAppointments),
                );
              }),
            ],
          );
        },
      ),
    );
  }


  // Enhanced Filter and Search Section (without Add Appointment button)
  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // View Selection Tabs
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(4),
            child: Row(
              children: [
                Expanded(
                  child: _buildTabButton(
                    'Approved',
                    Icons.check_circle_outline,
                    _currentView == 'approved',
                    () => setState(() => _currentView = 'approved'),
                    const Color(0xFF10B981),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _buildTabButton(
                    'Rescheduled',
                    Icons.schedule,
                    _currentView == 'rescheduled',
                    () => setState(() => _currentView = 'rescheduled'),
                    const Color(0xFFF59E0B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          // Search and Filter Row (without Add Appointment button)
          Row(
            children: [
              // Search Field
              Expanded(
                flex: 2,
                child: Container(
                  height: 44,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Color(0xFF94A3B8), size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            hintText: 'Search appointments...',
                            border: InputBorder.none,
                            hintStyle: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              // Filter Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showFilterPanel,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: _hasActiveFilters()
                          ? const Color(0xFFEFF6FF)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _hasActiveFilters()
                            ? const Color(0xFF93C5FD)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_list,
                          color: _hasActiveFilters()
                              ? const Color(0xFF2563EB)
                              : const Color(0xFF475569),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: TextStyle(
                            color: _hasActiveFilters()
                                ? const Color(0xFF1D4ED8)
                                : const Color(0xFF475569),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_hasActiveFilters()) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF3B82F6),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Tab Button Widget
  Widget _buildTabButton(String title, IconData icon, bool isSelected, VoidCallback onPressed, Color activeColor) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? activeColor : const Color(0xFF64748B),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? activeColor : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> tabAppointments;
    String emptyTabSubtitle;

    switch (_currentView) {
      case 'approved':
        tabAppointments = _approvedAppointments;
        emptyTabSubtitle = 'No approved appointments found';
        break;
      case 'rescheduled':
        tabAppointments = _rescheduledAppointments;
        emptyTabSubtitle = 'No rescheduled appointments found';
        break;
      default:
        tabAppointments = _approvedAppointments;
        emptyTabSubtitle = 'No approved appointments found';
    }

    final filteredTabAppointments = _filteredForTab(tabAppointments);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            AdminHeader(
              title: "Appointment Management",
              subtitle: "Manage and track all patient appointments",
              onRefresh: _loadAppointments,
              showLiveClock: true,
            ),
            
            // Filter and Search Section
            _buildFilterSection(),

            // Main Content Area
            Expanded(
              child: _isLoading
                  ? _buildLoadingState()
                  : _errorMessage.isNotEmpty
                      ? _buildErrorState()
                      : tabAppointments.isEmpty
                          ? _buildEmptyState('No Appointments Found', emptyTabSubtitle)
                          : filteredTabAppointments.isEmpty
                              ? _buildEmptyState(
                                  'No appointments found.',
                                  'Try adjusting your search or filters.',
                                )
                              : _currentView == 'approved'
                                  ? _buildApprovedAppointmentsView(filteredTabAppointments)
                                  : _buildRescheduledAppointmentsView(filteredTabAppointments),
            ),
          ],
        ),
      ),
    );
  }
}
