import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'health_records_service.dart';
import 'patients_service.dart';
import 'services/vaccine_tracking_service.dart';
import 'services/admin_session_storage.dart';
import '../utils/message_utils.dart';
import '../utils/time_utils.dart';
import '../services/dashboard_service.dart';
import '../services/connection_status_service.dart';
import '../services/api_config.dart';
import 'widgets/admin_header.dart';
import 'widgets/referral_modal.dart';

class HealthRecordsView extends StatefulWidget {
  const HealthRecordsView({super.key});

  @override
  State<HealthRecordsView> createState() => _HealthRecordsViewState();
}

class _HealthRecordsViewState extends State<HealthRecordsView> {
  String searchQuery = "";
  List<Map<String, dynamic>> healthRecords = [];
  List<Map<String, dynamic>> filteredRecords = [];
  bool isLoading = true;
  String? errorMessage;

  // ── Pagination ─────────────────────────────────────────────────────────
  int _currentPage  = 1;
  int _totalPages   = 1;
  int _totalRecords = 0;
  static const int _pageSize = 20;

  // ── Debounce ───────────────────────────────────────────────────────────
  Timer? _searchDebounce;
  final TextEditingController _searchController = TextEditingController();
  
  // Filter variables
  String _filterServiceType = 'All';
  String _filterRecordType = 'All';
  String _filterGender = 'All';
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  // ── Vaccine badge cache ────────────────────────────────────────────────
  // Map of patientId → badge summary (lazy-loaded per visible card)
  final Map<int, VaccineBadgeSummary?> _badgeCache = {};
  final Map<int, bool> _badgeLoading = {};

  @override
  void initState() {
    super.initState();
    _loadHealthRecords();
    _searchController.addListener(_onSearchChanged);
    
    // Register for real-time dashboard refresh with higher priority
    DashboardService.addRefreshCallback(_loadHealthRecords, priority: true);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    // Remove refresh callback when widget is disposed
    DashboardService.removeRefreshCallback(_loadHealthRecords);
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        searchQuery  = _searchController.text;
        _currentPage = 1;
      });
      _loadHealthRecords();
    });
  }

  // Load health records from database — paginated + server-filtered
  Future<void> _loadHealthRecords() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final startDate = _filterStartDate != null
          ? '${_filterStartDate!.year}-${_filterStartDate!.month.toString().padLeft(2, '0')}-${_filterStartDate!.day.toString().padLeft(2, '0')}'
          : null;
      final endDate = _filterEndDate != null
          ? '${_filterEndDate!.year}-${_filterEndDate!.month.toString().padLeft(2, '0')}-${_filterEndDate!.day.toString().padLeft(2, '0')}'
          : null;

      final result = await HealthRecordsService.getHealthRecordsPage(
        page:        _currentPage,
        limit:       _pageSize,
        search:      searchQuery.trim().isEmpty ? null : searchQuery.trim(),
        serviceType: _filterServiceType == 'All' ? null : _filterServiceType,
        recordType:  _filterRecordType  == 'All' ? null : _filterRecordType,
        gender:      _filterGender == 'All' ? null : _filterGender,
        startDate:   startDate,
        endDate:     endDate,
      );

      setState(() {
        healthRecords    = (result['data'] as List).cast<Map<String, dynamic>>();
        filteredRecords  = List.from(healthRecords);
        _totalRecords    = result['total'] as int;
        _totalPages      = result['totalPages'] as int;
        isLoading        = false;
        // Clear badge cache on every page load — fresh badges per page
        _badgeCache.clear();
        _badgeLoading.clear();
      });
    } catch (e) {
      setState(() {
        errorMessage = ConnectionStatusService.friendlyError(e);
        isLoading = false;
      });
      if (mounted) {
        MessageUtils.showNetworkError(context, e);
      }
    }
  }

  void _applyFilters() {
    setState(() => _currentPage = 1);
    _loadHealthRecords();
  }

  // 📄 PRINT RECORD WITH TIMESTAMP
  Future<void> _printRecord(BuildContext context, Map<String, dynamic> record) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) => pw.Padding(
          padding: const pw.EdgeInsets.all(20),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Health Record",
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Text("Generated on: ${TimeUtils.formatDateTime(DateTime.now())}", style: const pw.TextStyle(fontSize: 12)),
              pw.Divider(),
              pw.SizedBox(height: 20),
              
              // Patient Information Section
              pw.Text("Patient Information", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Child Name:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['patientName'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Mother Name:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['motherName'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Date of Birth:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['dateOfBirth'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Place of Birth:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['placeOfBirth'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Birth Weight:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['birthWeight'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Birth Height:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['birthHeight'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Sex:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['sex'] ?? 'N/A')),
                    ],
                  ),
                ],
              ),
              
              pw.SizedBox(height: 20),
              
              // Record Information Section
              pw.Text("Record Information", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Record Type:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['recordType'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Title:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['title'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Description:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['description'] ?? 'N/A')),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text("Created At:", style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(record['createdAt'] ?? 'N/A')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // 🔎 VIEW RECORD with improved layout
  void _viewRecord(Map<String, dynamic> record) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Patient Details", style: Theme.of(context).textTheme.headlineSmall),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              
              // Patient Information Section
              Text("Patient Information", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildDetailRow("Child Name", record['patientName']),
              _buildDetailRow("Mother Name", record['motherName']),
              _buildDetailRow("Date of Birth", record['dateOfBirth']),
              _buildDetailRow("Place of Birth", record['placeOfBirth']),
              _buildDetailRow("Birth Weight", record['birthWeight']),
              _buildDetailRow("Birth Height", record['birthHeight']),
              _buildDetailRow("Sex", record['sex']),
              _buildDetailRow("Address", record['address']),

              // ── ⚠️ DOB verification banner inside view modal ──────────────
              Builder(builder: (ctx) {
                final needsVerif = record["dobNeedsVerification"] == true ||
                    record["dobNeedsVerification"] == 1 ||
                    record["dob_needs_verification"] == true ||
                    record["dob_needs_verification"] == 1;
                final svcType = record["serviceType"]?.toString().toLowerCase() ?? "";
                if (!needsVerif || !svcType.contains('immun')) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        border: Border.all(color: const Color(0xFFFBBF24)),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              color: Color(0xFFD97706), size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Child's date of birth may be incorrect",
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Stored DOB: ${record['dateOfBirth'] ?? 'unknown'}. "
                                  "This date appears to be the mother's DOB, not the child's. "
                                  "Please verify and update before vaccine tracking can be computed accurately.",
                                  style: const TextStyle(
                                      fontSize: 12, color: Color(0xFF78350F), height: 1.4),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFFF59E0B),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 14, vertical: 8),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.edit_calendar_outlined, size: 16),
                                  label: const Text("Edit Child DOB",
                                      style: TextStyle(
                                          fontSize: 12, fontWeight: FontWeight.w600)),
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    _showDobEditModal(
                                      patientId: record['patientId']?.toString() ?? '',
                                      patientName: record['patientName'] ?? '',
                                      storedDob: record['dateOfBirth'] ?? '',
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              
              const SizedBox(height: 20),
              
              // Record Information Section
              Text("Record Information", style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              _buildDetailRow("Record Type", record['recordType']),
              _buildDetailRow("Title", record['title']),
              _buildDetailRow("Description", record['description']),
              _buildDetailRow("Created At", TimeUtils.formatTimestampString(record['createdAt'] ?? '')),
              
              const SizedBox(height: 20),
              
              // Close Button
             Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, // 🔴 Red button
                  foregroundColor: Colors.white, // ⚪ White text
                ),
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  // ── DOB Edit Modal ─────────────────────────────────────────────────────────
  // Admin enters the correct child DOB, which is validated (≤ 5 years ago),
  // saved via PATCH /patients/:id/dob, and triggers an immediate vaccine
  // schedule recomputation via the Socket.IO vaccineRecordUpdated event.
  void _showDobEditModal({
    required String patientId,
    required String patientName,
    required String storedDob,
  }) {
    final formKey = GlobalKey<FormState>();
    final dobController = TextEditingController();
    DateTime? pickedDate;
    bool saving = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            title: const Row(
              children: [
                Icon(Icons.edit_calendar_outlined, color: Color(0xFFD97706), size: 22),
                SizedBox(width: 8),
                Text("Edit Child DOB",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context banner
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFBBF24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            patientName,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Stored DOB: $storedDob",
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF78350F)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      "Enter the correct child date of birth:",
                      style: TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: dobController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: "Child's Date of Birth *",
                        hintText: "Tap to select",
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        suffixIcon: const Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return "Please select the child's date of birth";
                        }
                        if (pickedDate != null) {
                          final cutoff = DateTime.now()
                              .subtract(const Duration(days: 365 * 5));
                          if (pickedDate!.isBefore(cutoff)) {
                            return "Child appears older than 5 years — please verify";
                          }
                        }
                        return null;
                      },
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: now,
                          firstDate:
                              now.subtract(const Duration(days: 365 * 5)),
                          lastDate: now,
                          helpText: "Select Child's Correct Date of Birth",
                        );
                        if (picked != null) {
                          setModalState(() {
                            pickedDate = picked;
                            dobController.text =
                                DateFormat('MMMM d, yyyy').format(picked);
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "After saving, vaccine schedules will recalculate automatically.",
                      style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B7280),
                          height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFF59E0B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        if (pickedDate == null) return;

                        setModalState(() => saving = true);

                        final isoDate =
                            DateFormat('yyyy-MM-dd').format(pickedDate!);
                        final pid = int.tryParse(patientId) ?? 0;

                        final result =
                            await PatientsService.updateChildDob(pid, isoDate);

                        if (!mounted) return;
                        // Use ctx for dialog close, then outer context for snackbar
                        if (ctx.mounted) Navigator.pop(ctx);

                        if (result['success'] == true) {
                          if (!mounted) return;
                          MessageUtils.showSuccessMessage(
                            // ignore: use_build_context_synchronously
                            context,
                            "Child's DOB updated to ${DateFormat('MMMM d, yyyy').format(pickedDate!)}. "
                            "Vaccine schedules will recalculate automatically.",
                            title: "DOB Updated",
                          );
                          // Reload health records so the badge disappears
                          await _loadHealthRecords();
                        } else {
                          if (!mounted) return;
                          MessageUtils.showErrorMessage(
                            // ignore: use_build_context_synchronously
                            context,
                            result['message']?.toString() ??
                                "Failed to update DOB. Please try again.",
                            title: "Update Failed",
                          );
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text("Save DOB",
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to build detail rows
  Widget _buildDetailRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              "$label:",
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value ?? "N/A"),
          ),
        ],
      ),
    );
  }

  // Filter Panel
  Widget _buildFilterPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter Health Records",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              // Service Type Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Service Type",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  value: _filterServiceType,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Services')),
                    DropdownMenuItem(value: 'Immunization', child: Text('Immunization')),
                    DropdownMenuItem(value: 'Maternal Care', child: Text('Maternal Care')),
                    DropdownMenuItem(value: 'Diagnosis', child: Text('Diagnosis')),
                    DropdownMenuItem(value: 'Consultation', child: Text('Consultation')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterServiceType = val ?? 'All';
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Record Type Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Record Type",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  value: _filterRecordType,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Record Types')),
                    DropdownMenuItem(value: 'Immunization', child: Text('Immunization')),
                    DropdownMenuItem(value: 'Maternal Care', child: Text('Maternal Care')),
                    DropdownMenuItem(value: 'Diagnosis', child: Text('Diagnosis')),
                    DropdownMenuItem(value: 'Consultation', child: Text('Consultation')),
                    DropdownMenuItem(value: 'Others', child: Text('Others')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterRecordType = val ?? 'All';
                      _applyFilters();
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          Row(
            children: [
              // Gender Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: "Gender",
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
                    ),
                  ),
                  value: _filterGender,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All Genders')),
                    DropdownMenuItem(value: 'Male', child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _filterGender = val ?? 'All';
                      _applyFilters();
                    });
                  },
                ),
              ),
              const SizedBox(width: 16),
              
              // Date Range Filter
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Date Range",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _filterStartDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterStartDate = picked;
                                  _applyFilters();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterStartDate == null
                                        ? "Start Date"
                                        : "${_filterStartDate!.year}-${_filterStartDate!.month.toString().padLeft(2, '0')}-${_filterStartDate!.day.toString().padLeft(2, '0')}",
                                    style: const TextStyle(color: Color(0xFF1F2937)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("to", style: TextStyle(color: Color(0xFF6B7280))),
                        const SizedBox(width: 8),
                        Expanded(
                          child: InkWell(
                            onTap: () async {
                              final DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: _filterEndDate ?? DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime.now(),
                              );
                              if (picked != null) {
                                setState(() {
                                  _filterEndDate = picked;
                                  _applyFilters();
                                });
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18, color: Color(0xFF6B7280)),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterEndDate == null
                                        ? "End Date"
                                        : "${_filterEndDate!.year}-${_filterEndDate!.month.toString().padLeft(2, '0')}-${_filterEndDate!.day.toString().padLeft(2, '0')}",
                                    style: const TextStyle(color: Color(0xFF1F2937)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_filterStartDate != null || _filterEndDate != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextButton(
                          onPressed: () {
                            setState(() {
                              _filterStartDate = null;
                              _filterEndDate = null;
                              _applyFilters();
                            });
                          },
                          child: const Text(
                            "Clear Date Filter",
                            style: TextStyle(color: Color(0xFFEF4444)),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Clinical light gray background
      body: Column(
        children: [
          AdminHeader(
            title: "Health Records",
            subtitle: "Manage and track all patient health records",
            onRefresh: _loadHealthRecords,
            showLiveClock: true,
          ),

          // ===== CONTENT =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Filter Panel
                  _buildFilterPanel(),
                  const SizedBox(height: 20),
                   
                  // Search Bar
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildSection(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection() {
    if (isLoading) {
      return _buildSkeletonLoader();
    }
    
    if (errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Error loading health records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadHealthRecords,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    
    if (filteredRecords.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.health_and_safety, size: 48, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No health records found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Health records will appear here once added',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }
    
    return Column(
      children: [
        // Pagination info bar
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${filteredRecords.length} of $_totalRecords record(s)  •  Page $_currentPage of $_totalPages',
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 8.0;
            const cols = 5;
            final maxW = constraints.maxWidth;
            final cardWidth = maxW.isFinite
                ? ((maxW - gap * (cols - 1)) / cols).clamp(120.0, double.infinity)
                : 200.0;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: filteredRecords.asMap().entries.map((entry) {
                final index = entry.key;
                final record = entry.value;
                return SizedBox(
                  width: cardWidth,
                  child: _buildCompactRecordCard(record, index),
                );
              }).toList(),
            );
          },
        ),
        const SizedBox(height: 16),
        _buildPaginationControls(),
      ],
    );
  }

  Widget _buildSkeletonLoader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 5;
        final maxW = constraints.maxWidth;
        final cardWidth = maxW.isFinite
            ? ((maxW - gap * (cols - 1)) / cols).clamp(120.0, double.infinity)
            : 200.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(10, (_) => SizedBox(
            width: cardWidth,
            child: Container(
              height: 140,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBFDBFE), width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    _shimmerBox(32, 32, circular: true),
                    const SizedBox(width: 10),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _shimmerBox(12, double.infinity),
                        const SizedBox(height: 6),
                        _shimmerBox(10, 80),
                      ],
                    )),
                  ]),
                  const SizedBox(height: 10),
                  _shimmerBox(1, double.infinity),
                  const SizedBox(height: 10),
                  _shimmerBox(10, 60),
                  const SizedBox(height: 6),
                  _shimmerBox(10, 80),
                ],
              ),
            ),
          )),
        );
      },
    );
  }

  Widget _shimmerBox(double height, double width, {bool circular = false}) {
    return Container(
      height: height,
      width: width == double.infinity ? double.infinity : width,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: circular ? BorderRadius.circular(999) : BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildPaginationControls() {
    if (_totalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: _currentPage > 1
              ? () {
                  setState(() => _currentPage--);
                  _loadHealthRecords();
                }
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Prev'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B82F6),
            side: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Page $_currentPage of $_totalPages',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
        const SizedBox(width: 16),
        OutlinedButton.icon(
          onPressed: _currentPage < _totalPages
              ? () {
                  setState(() => _currentPage++);
                  _loadHealthRecords();
                }
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF3B82F6),
            side: const BorderSide(color: Color(0xFF3B82F6)),
          ),
        ),
      ],
    );
  }

  // Modern Search Bar
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: "Search patient or record...",
          prefixIcon: const Icon(Icons.search, color: Color(0xFF6B7280)),
          suffixIcon: searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Color(0xFF6B7280)),
                  onPressed: () {
                    _searchController.clear();
                  },
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  // Compact EMR-style Record Card (grid tile)
  Widget _buildCompactRecordCard(Map<String, dynamic> record, int index) {
    final patientName = record["patientName"] ?? "Unknown Patient";
    final recordType = record["recordType"] ?? "N/A";
    final createdAt = record["createdAt"] ?? "N/A";
    final patientId = record["patientId"]?.toString() ?? "—";
    final statusRaw = record["status"]?.toString().toLowerCase() ?? "";
    final isActive = statusRaw == "active" || statusRaw == "1";
    // ── DOB verification flag ─────────────────────────────────────────────────
    final needsDobVerification = record["dobNeedsVerification"] == true ||
        record["dobNeedsVerification"] == 1 ||
        record["dob_needs_verification"] == true ||
        record["dob_needs_verification"] == 1;
    final storedDob = record["dateOfBirth"]?.toString() ?? "";
    final serviceType = record["serviceType"]?.toString().toLowerCase() ?? "";

    final initials = _patientInitials(patientName);
    final avatarStyle = _avatarPaletteForIndex(index, initials);

    return _HoverRecordCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: avatarStyle.$1,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: avatarStyle.$2,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              patientName,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF1E3A5F),
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive
                                  ? const Color(0xFF16A34A)
                                  : const Color(0xFF94A3B8),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "ID $patientId",
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF3B6899),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      // ── ⚠️ DOB needs verification badge ──────────────────
                      if (needsDobVerification && serviceType.contains('immun')) ...[
                        const SizedBox(height: 5),
                        GestureDetector(
                          onTap: () => _showDobEditModal(
                            patientId: patientId,
                            patientName: patientName,
                            storedDob: storedDob,
                          ),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7),
                              border: Border.all(color: const Color(0xFFFBBF24)),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    size: 11, color: Color(0xFFD97706)),
                                SizedBox(width: 3),
                                Text(
                                  '⚠️ DOB needs verification',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF92400E),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // ── Child count badge ─────────────────────────────────────────────
            Builder(builder: (ctx) {
              final childCount = record["childCount"] as int? ?? 1;
              final label = childCount == 1 ? '1 child' : '$childCount children';
              return Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    border: Border.all(color: const Color(0xFFCBD5E1)),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.child_care, size: 10, color: Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF475569),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            Container(height: 0.5, color: const Color(0xFFBFDBFE)),
            const SizedBox(height: 10),
            _metaLabel("SERVICE"),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBEAFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _serviceIconForRecordType(recordType),
                      size: 12,
                      color: const Color(0xFF1D4ED8),
                    ),
                    const SizedBox(width: 4),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        recordType,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF1D4ED8),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            _metaLabel("RECORD"),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFBFDBFE),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    recordType,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF1E3A5F),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(height: 0.5, color: const Color(0xFFBFDBFE)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: const Color(0xFF3B6899),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDateShort(createdAt),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF3B6899),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _gridActionIcon(
                  icon: Icons.visibility_outlined,
                  backgroundColor: const Color(0xFFEFF6FF),
                  iconColor: const Color(0xFF3B82F6),
                  borderColor: const Color(0xFFBFDBFE),
                  onPressed: () => _viewRecord(record),
                  tooltip: 'View record',
                ),
                const SizedBox(width: 4),
                _gridActionIcon(
                  icon: Icons.print_outlined,
                  backgroundColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF22C55E),
                  borderColor: const Color(0xFFA7F3D0),
                  onPressed: () => _printRecord(context, record),
                  tooltip: 'Print record',
                ),
                const SizedBox(width: 4),
                // ── Vaccine Tracking icon (replaces delete) ────────────────
                _gridActionIcon(
                  icon: Icons.vaccines_outlined,
                  backgroundColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF0D9488),
                  borderColor: const Color(0xFF99F6E4),
                  onPressed: () => _showVaccineTrackingModal(record),
                  tooltip: 'View vaccine tracking',
                ),
                const SizedBox(width: 4),
                _gridActionIcon(
                  icon: Icons.medical_services_outlined,
                  backgroundColor: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF8B5CF6),
                  borderColor: const Color(0xFFDDD6FE),
                  onPressed: () => _showReferralModal(record),
                  tooltip: 'Create referral',
                ),
                // ── Fix DOB button — only shown when flagged ──────────────
                if (needsDobVerification && serviceType.contains('immun')) ...[
                  const SizedBox(width: 4),
                  _gridActionIcon(
                    icon: Icons.edit_calendar_outlined,
                    backgroundColor: const Color(0xFFFEF3C7),
                    iconColor: const Color(0xFFD97706),
                    borderColor: const Color(0xFFFBBF24),
                    onPressed: () => _showDobEditModal(
                      patientId: patientId,
                      patientName: patientName,
                      storedDob: storedDob,
                    ),
                  ),
                ],
              ],
            ),
            // ── Vaccine status badge (lazy-loaded) ─────────────────────────
            if (serviceType.contains('immun')) ...[
              const SizedBox(height: 8),
              _buildVaccineBadge(patientId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metaLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: Color(0xFF5A85AD),
        height: 1.1,
      ),
    );
  }

  (Color, Color) _avatarPaletteForIndex(int index, String initials) {
    final palettes = <(Color, Color)>[
      (const Color(0xFFE6F1FB), const Color(0xFF0C447C)),
      (const Color(0xFFE1F5EE), const Color(0xFF085041)),
      (const Color(0xFFEEEDFE), const Color(0xFF3C3489)),
      (const Color(0xFFFAECE7), const Color(0xFF712B13)),
      (const Color(0xFFEAF3DE), const Color(0xFF27500A)),
    ];
    var h = 0;
    for (final c in initials.codeUnits) {
      h = (h + c) % 256;
    }
    final i = (index + h) % palettes.length;
    return palettes[i];
  }

  String _patientInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return "?";
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0] : "";
      final b = parts.last.isNotEmpty ? parts.last[0] : "";
      return ("$a$b").toUpperCase();
    }
    final s = parts.first;
    if (s.length >= 2) {
      return s.substring(0, 2).toUpperCase();
    }
    return s.toUpperCase();
  }

  IconData _serviceIconForRecordType(String recordType) {
    switch (recordType.toLowerCase()) {
      case 'immunization':
        return Icons.vaccines_outlined;
      case 'maternal care':
        return Icons.pregnant_woman_outlined;
      case 'diagnosis':
        return Icons.sick_outlined;
      case 'consultation':
        return Icons.chat_bubble_outline;
      default:
        return Icons.medical_information_outlined;
    }
  }

  Widget _gridActionIcon({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required Color borderColor,
    required VoidCallback onPressed,
    String? tooltip,
  }) {
    final btn = SizedBox(
      width: 24,
      height: 24,
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 24, height: 24),
        style: IconButton.styleFrom(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          visualDensity: VisualDensity.compact,
          backgroundColor: backgroundColor,
          foregroundColor: iconColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(6),
            side: BorderSide(color: borderColor, width: 0.5),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: iconColor),
      ),
    );
    if (tooltip != null) {
      return Tooltip(message: tooltip, child: btn);
    }
    return btn;
  }

  String _formatDateShort(String dateString) {
    if (dateString == "N/A" || dateString.isEmpty) return "N/A";
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM d, y').format(date);
    } catch (e) {
      return dateString;
    }
  }

  // ── Vaccine badge (lazy-loaded per card) ──────────────────────────────────
  Widget _buildVaccineBadge(String patientIdStr) {
    final patientId = int.tryParse(patientIdStr) ?? 0;
    if (patientId <= 0) return const SizedBox.shrink();

    final badge = _badgeCache[patientId];
    final loading = _badgeLoading[patientId] ?? false;

    // Trigger load if not yet loaded
    if (badge == null && !loading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_badgeLoading[patientId] == true) return;
        setState(() => _badgeLoading[patientId] = true);
        VaccineTrackingService.getAdminBadge(patientId).then((result) {
          if (!mounted) return;
          setState(() {
            _badgeCache[patientId] = result;
            _badgeLoading[patientId] = false;
          });
        }).catchError((_) {
          if (!mounted) return;
          setState(() => _badgeLoading[patientId] = false);
        });
      });
      // Show a tiny placeholder while we wait
      return Container(
        height: 16,
        width: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    if (loading || badge == null) {
      return Container(
        height: 16,
        width: 60,
        decoration: BoxDecoration(
          color: const Color(0xFFE2E8F0),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }

    // Not an immunization patient — don't show badge
    if (badge.notImmunization) return const SizedBox.shrink();

    Color bgColor;
    Color textColor;
    String label;

    if (badge.dobNeedsVerification) {
      bgColor   = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      label     = '⚠️ DOB unverified';
    } else if (badge.overallStatus == 'overdue') {
      bgColor   = const Color(0xFFFEE2E2);
      textColor = const Color(0xFF991B1B);
      label     = '❌ Overdue';
    } else if (badge.overallStatus == 'action_needed') {
      bgColor   = const Color(0xFFFEF3C7);
      textColor = const Color(0xFF92400E);
      label     = '⚠️ Due soon';
    } else {
      // up_to_date
      bgColor   = const Color(0xFFDCFCE7);
      textColor = const Color(0xFF166534);
      label     = '${badge.totalDosesCompleted}/${badge.totalDosesRequired} ✅';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: textColor,
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── Vaccine Tracking Modal ────────────────────────────────────────────────
  void _showVaccineTrackingModal(Map<String, dynamic> record) {
    final patientId   = int.tryParse(record['patientId']?.toString() ?? '0') ?? 0;
    final userId      = int.tryParse(record['userId']?.toString() ?? record['user_id']?.toString() ?? '0') ?? 0;
    final patientName = record['patientName']?.toString()  ?? 'Unknown Patient';
    final storedDob   = record['dateOfBirth']?.toString()  ?? '';
    final serviceType = record['serviceType']?.toString()  ?? '';
    final childCount  = record['childCount'] as int? ?? 1;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _VaccineTrackingModal(
        patientId:    patientId,
        userId:       userId,
        childCount:   childCount,
        patientName:  patientName,
        storedDob:    storedDob,
        serviceType:  serviceType,
        onDobCorrected: () async {
          // Clear badge cache for this patient and refresh list
          setState(() {
            _badgeCache.remove(patientId);
            _badgeLoading.remove(patientId);
          });
          await _loadHealthRecords();
        },
      ),
    );
  }

  // 🏥 SHOW REFERRAL MODAL
  void _showReferralModal(Map<String, dynamic> record) {
    final patientId = int.tryParse(record['patientId']?.toString() ?? '0') ?? 0;
    final patientName = record['patientName']?.toString() ?? 'Unknown Patient';
    
    if (patientId == 0) {
      MessageUtils.showErrorMessage(
        context,
        'Invalid patient ID. Cannot create referral.',
        title: "Error",
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => ReferralModal(
        patientId: patientId,
        patientName: patientName,
        onReferralCreated: () {
          // Optionally refresh data or show success message
          MessageUtils.showSuccessMessage(
            context,
            'Referral created successfully!',
            title: "Success",
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Vaccine Tracking Modal
// ─────────────────────────────────────────────────────────────────────────────

class _VaccineTrackingModal extends StatefulWidget {
  const _VaccineTrackingModal({
    required this.patientId,
    required this.userId,
    required this.childCount,
    required this.patientName,
    required this.storedDob,
    required this.serviceType,
    required this.onDobCorrected,
  });

  final int patientId;
  final int userId;
  final int childCount;
  final String patientName;
  final String storedDob;
  final String serviceType;
  final VoidCallback onDobCorrected;

  @override
  State<_VaccineTrackingModal> createState() => _VaccineTrackingModalState();
}

class _VaccineTrackingModalState extends State<_VaccineTrackingModal> {
  bool _loading = true;
  String? _error;
  VaccineCardData? _cardData;
  Timer? _pollTimer;

  // Multi-child: when null we show the child-selector; when set we show the card
  int? _activeChildId;
  String? _activeChildName;
  bool _loadingChildren = false;
  List<Map<String, dynamic>> _children = [];

  @override
  void initState() {
    super.initState();
    if (widget.childCount >= 2) {
      // Show child list first
      _loadingChildren = true;
      _fetchChildren();
    } else {
      // Single child — go straight to card
      _activeChildId = widget.patientId;
      _loadCard();
      _pollTimer = Timer.periodic(
          const Duration(seconds: 15), (_) => _loadCard(silent: true));
    }
  }

  Future<void> _fetchChildren() async {
    try {
      // Use the admin patients endpoint to get all children for this parent
      final children = await _AdminChildrenHelper.fetchChildren(widget.userId);
      if (!mounted) return;
      setState(() {
        _children = children;
        _loadingChildren = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingChildren = false;
        _error = 'Failed to load children: $e';
      });
    }
  }

  void _selectChild(Map<String, dynamic> child) {
    final id   = int.tryParse(child['id']?.toString() ?? '0') ?? 0;
    final name = child['child_fullname']?.toString() ?? 'Unknown Child';
    setState(() {
      _activeChildId   = id;
      _activeChildName = name;
      _loading         = true;
      _error           = null;
    });
    _loadCard();
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
        const Duration(seconds: 15), (_) => _loadCard(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCard({bool silent = false}) async {
    if (!mounted) return;
    final targetId = _activeChildId ?? widget.patientId;
    if (!silent) setState(() { _loading = true; _error = null; });
    try {
      final data = await VaccineTrackingService.getAdminVaccineCard(targetId);
      if (!mounted) return;
      setState(() { _cardData = data; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      if (!silent) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Age formatting ─────────────────────────────────────────────────────────
  String _formatAge(int days) {
    if (days < 30)  return '$days day${days == 1 ? '' : 's'} old';
    if (days < 365) { final m = (days / 30).floor(); return '$m month${m == 1 ? '' : 's'} old'; }
    final y = (days / 365).floor();
    final rem = ((days % 365) / 30).floor();
    if (rem == 0) return '$y year${y == 1 ? '' : 's'} old';
    return '$y yr $rem mo old';
  }

  String _formatDateDisplay(String? isoDate) {
    if (isoDate == null || isoDate.isEmpty) return 'N/A';
    try { return DateFormat('MMM d, yyyy').format(DateTime.parse(isoDate)); }
    catch (_) { return isoDate; }
  }

  // ── DOB correction handler ─────────────────────────────────────────────────
  void _showDobCorrection(BuildContext outerCtx) {
    final formKey = GlobalKey<FormState>();
    final dobCtrl = TextEditingController();
    DateTime? picked;
    bool saving = false;

    showDialog(
      context: outerCtx,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Row(children: [
          Icon(Icons.edit_calendar_outlined, color: Color(0xFFD97706), size: 20),
          SizedBox(width: 8),
          Text('Edit Child DOB', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        content: SizedBox(
          width: 360,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFFBBF24)),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.patientName,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                  const SizedBox(height: 2),
                  Text('Stored DOB: ${widget.storedDob}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF78350F))),
                ]),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: dobCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: "Child's Date of Birth *",
                  hintText: 'Tap to select',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  suffixIcon: const Icon(Icons.calendar_today_outlined),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return "Please select the child's date of birth";
                  if (picked != null) {
                    final cutoff = DateTime.now().subtract(const Duration(days: 365 * 5));
                    if (picked!.isBefore(cutoff)) return 'Child appears older than 5 years — please verify';
                  }
                  return null;
                },
                onTap: () async {
                  final now = DateTime.now();
                  final p = await showDatePicker(
                    context: ctx,
                    initialDate: now,
                    firstDate: now.subtract(const Duration(days: 365 * 5)),
                    lastDate: now,
                    helpText: "Select Child's Correct Date of Birth",
                  );
                  if (p != null) {
                    setS(() {
                      picked = p;
                      dobCtrl.text = DateFormat('MMMM d, yyyy').format(p);
                    });
                  }
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'After saving, vaccine schedules will recalculate automatically.',
                style: TextStyle(fontSize: 11, color: Color(0xFF6B7280), height: 1.4),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(
            onPressed: saving ? null : () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: saving ? null : () async {
              if (!formKey.currentState!.validate()) return;
              if (picked == null) return;
              setS(() => saving = true);
              final isoDate = DateFormat('yyyy-MM-dd').format(picked!);
              // Capture messenger before async gap
              final messenger = ScaffoldMessenger.of(outerCtx);
              final result  = await PatientsService.updateChildDob(widget.patientId, isoDate);
              if (!mounted) return;
              if (ctx.mounted) Navigator.pop(ctx);
              if (result['success'] == true) {
                widget.onDobCorrected();
                await _loadCard(); // Refresh modal immediately
              } else {
                messenger.showSnackBar(
                  SnackBar(content: Text(result['message']?.toString() ?? 'Failed to update DOB')),
                );
              }
            },
            child: saving
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save DOB', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth:  MediaQuery.of(context).size.width  * 0.72,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(children: [
          // ── Modal header ────────────────────────────────────────────────
          _buildModalHeader(context),
          // ── Body ────────────────────────────────────────────────────────
          // If multi-child and no child selected yet, show child-list screen
          if (widget.childCount >= 2 && _activeChildId == null)
            Expanded(child: _buildChildListScreen(context))
          else
            Expanded(child: _buildModalBody(context)),
        ]),
      ),
    );
  }

  // ── Child list screen (shown first when 2+ children) ──────────────────────
  Widget _buildChildListScreen(BuildContext context) {
    if (_loadingChildren) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Select a child to view vaccine tracking:',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
            ),
          ),
          ..._children.map((child) {
            final name = child['child_fullname']?.toString() ?? 'Unknown Child';
            final dob  = child['dob']?.toString() ?? '';
            final age  = _ageFromDob(dob);
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF0F766E),
                  child: Text(
                    name.isNotEmpty ? name[0].toUpperCase() : '?',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: age.isNotEmpty ? Text(age) : null,
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Color(0xFF0F766E)),
                onTap: () => _selectChild(child),
              ),
            );
          }),
        ],
      ),
    );
  }

  String _ageFromDob(String dob) {
    if (dob.isEmpty) return '';
    try {
      final birth = DateTime.parse(dob);
      final now   = DateTime.now();
      final days  = now.difference(birth).inDays;
      if (days < 30)  return '$days day${days == 1 ? "" : "s"} old';
      if (days < 365) { final m = (days / 30).floor(); return '$m month${m == 1 ? "" : "s"} old'; }
      final y = (days / 365).floor();
      return '$y year${y == 1 ? "" : "s"} old';
    } catch (_) { return ''; }
  }

  Widget _buildModalHeader(BuildContext context) {
    // In multi-child mode with a child selected, show "← Back to children"
    final showBackButton = widget.childCount >= 2 && _activeChildId != null;
    final displayName = showBackButton
        ? (_activeChildName ?? widget.patientName)
        : widget.patientName;
    final displayId = _activeChildId ?? widget.patientId;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      decoration: const BoxDecoration(
        color: Color(0xFF0F766E),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16), topRight: Radius.circular(16),
        ),
      ),
      child: Row(children: [
        if (showBackButton) ...[
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            onPressed: () {
              _pollTimer?.cancel();
              setState(() {
                _activeChildId   = null;
                _activeChildName = null;
                _cardData        = null;
              });
            },
            tooltip: 'Back to children',
            splashRadius: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
          const SizedBox(width: 4),
        ] else ...[
          const Icon(Icons.vaccines_outlined, color: Colors.white, size: 22),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              displayName,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis,
            ),
            Text(
              showBackButton
                  ? '${widget.patientName}  •  Vaccine Tracking'
                  : 'Vaccine Tracking  •  ID $displayId',
              style: const TextStyle(color: Color(0xFFCCFBF1), fontSize: 11),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.close, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
          splashRadius: 18,
        ),
      ]),
    );
  }

  Widget _buildModalBody(BuildContext context) {
    if (_loading) return _buildSkeleton();

    if (_error != null) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 12),
          const Text('Unable to load vaccine record.', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          const Text('Please try again.', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _loadCard,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
            ),
          ),
        ]),
      ));
    }

    final data = _cardData!;

    // ── Not an immunization patient ─────────────────────────────────────────
    if (data.notImmunization) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.pregnant_woman_outlined, size: 48, color: Color(0xFF94A3B8)),
          const SizedBox(height: 16),
          const Text(
            'Vaccine tracking is for Immunization patients only.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
          ),
        ]),
      ));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── 3a Header — age + progress ────────────────────────────────────
        _buildProgressHeader(data),
        const SizedBox(height: 16),

        // ── 3b DOB verification warning ───────────────────────────────────
        if (data.dobNeedsVerification) ...[
          _buildDobWarningBanner(context, data),
          const SizedBox(height: 8),
        ],

        // ── Sections only for non-flagged records ─────────────────────────
        if (!data.dobNeedsVerification) ...[

          // Completed doses
          if (data.completedDoses.isNotEmpty) ...[
            _sectionHeader('Completed Doses', color: const Color(0xFF166534)),
            const SizedBox(height: 8),
            ...data.vaccines.expand((g) => g.doses
                .where((d) => d.status == VaccineDoseStatus.completed)
                .map((d) => _buildCompletedDoseRow(g.vaccineName, d))),
            const SizedBox(height: 16),
          ],

          // Pending / incomplete doses
          if (data.pendingDoses.isNotEmpty) ...[
            _sectionHeader('Pending / Upcoming Doses', color: const Color(0xFF1E3A5F)),
            const SizedBox(height: 8),
            ...data.pendingDoses.map(_buildPendingDoseRow),
            const SizedBox(height: 16),
          ],

          // ── 3e Bottom summary banner ─────────────────────────────────────
          _buildSummaryBanner(data),
        ],
      ]),
    );
  }

  // ── 3a Progress header ────────────────────────────────────────────────────
  Widget _buildProgressHeader(VaccineCardData data) {
    final pct = data.totalDosesRequired > 0
        ? data.totalDosesCompleted / data.totalDosesRequired
        : 0.0;

    Color statusColor;
    String statusLabel;
    Color statusBg;
    switch (data.overallStatus) {
      case 'overdue':
        statusColor = const Color(0xFF991B1B);
        statusBg    = const Color(0xFFFEE2E2);
        statusLabel = 'Overdue vaccines';
        break;
      case 'action_needed':
        statusColor = const Color(0xFF92400E);
        statusBg    = const Color(0xFFFEF3C7);
        statusLabel = 'Action needed';
        break;
      default:
        statusColor = const Color(0xFF166534);
        statusBg    = const Color(0xFFDCFCE7);
        statusLabel = 'Up to date';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDFA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF99F6E4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _formatAge(data.ageInDays),
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
            ),
            if (data.dob != null)
              Text('DOB: ${_formatDateDisplay(data.dob)}',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: statusColor)),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 6,
                backgroundColor: const Color(0xFFCCFBF1),
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '${data.totalDosesCompleted} of ${data.totalDosesRequired} doses',
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
          ),
        ]),
      ]),
    );
  }

  // ── 3b DOB warning banner ─────────────────────────────────────────────────
  Widget _buildDobWarningBanner(BuildContext context, VaccineCardData data) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: Color(0xFFDC2626), size: 22),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text(
            '⚠️ Child DOB needs verification',
            style: TextStyle(
                fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF991B1B)),
          ),
          const SizedBox(height: 4),
          Text(
            'This child\'s date of birth may be incorrect (${widget.storedDob.isNotEmpty ? widget.storedDob : 'unknown'}). '
            'Vaccine tracking cannot be computed accurately until the DOB is verified.',
            style: const TextStyle(fontSize: 12, color: Color(0xFF7F1D1D), height: 1.4),
          ),
          const SizedBox(height: 10),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            icon: const Icon(Icons.edit_calendar_outlined, size: 16),
            label: const Text('Edit Child DOB',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: () => _showDobCorrection(context),
          ),
        ])),
      ]),
    );
  }

  // ── Section header ────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, {Color color = const Color(0xFF1E3A5F)}) {
    return Text(title,
        style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.2));
  }

  // ── 3c Completed dose row ─────────────────────────────────────────────────
  // Shows actual given date as primary, and "Was scheduled for [theoretical]"
  // when the dose was given on a different date than originally planned.
  Widget _buildCompletedDoseRow(String vaccineName, VaccineDose dose) {
    final actualDateStr = dose.givenAt != null
        ? _formatDateDisplay(dose.givenAt!.substring(0, 10))
        : null;
    final theoDateStr = dose.theoreticalDueDate != null
        ? _formatDateDisplay(dose.theoreticalDueDate!)
        : null;

    // Highlight late/early administration
    final bool wasOffSchedule = actualDateStr != null &&
        theoDateStr != null &&
        actualDateStr != theoDateStr;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFBBF7D0)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: Color(0xFF16A34A), size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '$vaccineName — ${dose.doseLabel}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF14532D)),
          ),
          // Actual date given (record-based ground truth)
          if (actualDateStr != null)
            Text('Given: $actualDateStr',
                style: const TextStyle(fontSize: 11, color: Color(0xFF16A34A))),
          // Theoretical date — shown only when it differs from actual
          if (wasOffSchedule)
            Text('Was scheduled for: $theoDateStr',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFFD97706), fontStyle: FontStyle.italic)),
          if (dose.givenBy != null && dose.givenBy!.isNotEmpty)
            Text('By: ${dose.givenBy}',
                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
          if (dose.notes != null && dose.notes!.isNotEmpty)
            Text('Note: ${dose.notes}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
          if (dose.remarks != null && dose.remarks!.isNotEmpty)
            Text('Remarks: ${dose.remarks}',
                style: const TextStyle(
                    fontSize: 11, color: Color(0xFF64748B), fontStyle: FontStyle.italic)),
        ])),
      ]),
    );
  }

  // ── 3d Pending dose row ───────────────────────────────────────────────────
  // Uses record-based due_date_estimate as primary date.
  // Locked doses show "Due date will be computed after [X] is given" — no date.
  // When record-based date differs from theoretical, shows original schedule as note.
  Widget _buildPendingDoseRow(PendingDose dose) {
    final Color bg, border, iconColor, labelColor;
    final IconData icon;

    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        bg = const Color(0xFFFEF2F2); border    = const Color(0xFFFCA5A5);
        iconColor = const Color(0xFFDC2626);  labelColor = const Color(0xFF991B1B);
        icon = Icons.warning_rounded;
        break;
      case VaccineDoseStatus.dueSoon:
        bg = const Color(0xFFFFFBEB); border    = const Color(0xFFFDE68A);
        iconColor = const Color(0xFFD97706);  labelColor = const Color(0xFF92400E);
        icon = Icons.access_time_rounded;
        break;
      case VaccineDoseStatus.locked:
        bg = const Color(0xFFF8FAFC); border    = const Color(0xFFE2E8F0);
        iconColor = const Color(0xFF94A3B8);  labelColor = const Color(0xFF64748B);
        icon = Icons.lock_outline_rounded;
        break;
      default: // not_yet_due
        bg = const Color(0xFFF8FAFC); border    = const Color(0xFFE2E8F0);
        iconColor = const Color(0xFF94A3B8);  labelColor = const Color(0xFF475569);
        icon = Icons.lock_clock_outlined;
    }

    // Build subtitle lines
    final List<String> lines = [];
    final List<Color> lineColors = [];

    switch (dose.status) {
      case VaccineDoseStatus.overdue:
        lines.add('Was due ${_formatDateDisplay(dose.dueDateEstimate)}'
            '${dose.daysOverdue != null ? ', ${dose.daysOverdue} day${dose.daysOverdue == 1 ? '' : 's'} overdue' : ''}');
        lineColors.add(iconColor);
        if (_scheduleShifted(dose)) {
          lines.add('Original schedule: ${_formatDateDisplay(dose.theoreticalDueDate)}');
          lineColors.add(const Color(0xFFD97706));
        }
        break;
      case VaccineDoseStatus.dueSoon:
        // Record-based date is the primary due date
        lines.add('Due on ${_formatDateDisplay(dose.dueDateEstimate)}');
        lineColors.add(iconColor);
        if (_scheduleShifted(dose)) {
          lines.add('Original schedule: ${_formatDateDisplay(dose.theoreticalDueDate)}');
          lineColors.add(const Color(0xFFD97706));
        }
        break;
      case VaccineDoseStatus.locked:
        // Previous dose not yet given — cannot show any date
        lines.add(dose.waitingFor != null
            ? 'Due date will be computed after ${dose.waitingFor} is given'
            : 'Due date will be computed after the previous dose is given');
        lineColors.add(iconColor);
        break;
      default: // not_yet_due
        if (dose.dueDateEstimate != null && dose.dueDateEstimate!.isNotEmpty) {
          lines.add('Due on ${_formatDateDisplay(dose.dueDateEstimate)} (${dose.scheduleLabel})');
          lineColors.add(iconColor);
          if (_scheduleShifted(dose)) {
            lines.add('Original schedule: ${_formatDateDisplay(dose.theoreticalDueDate)}');
            lineColors.add(const Color(0xFFD97706));
          }
        } else {
          lines.add('Due at ${dose.scheduleLabel}');
          lineColors.add(iconColor);
        }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Row(children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
            '${dose.vaccineName} — ${dose.doseLabel}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: labelColor),
          ),
          for (int i = 0; i < lines.length; i++)
            Text(lines[i],
                style: TextStyle(fontSize: 11, color: lineColors[i], height: 1.4)),
        ])),
      ]),
    );
  }

  /// Returns true when the record-based due date differs from the theoretical DOB-based date.
  bool _scheduleShifted(PendingDose dose) {
    final rec  = dose.dueDateEstimate;
    final theo = dose.theoreticalDueDate;
    if (rec == null || rec.isEmpty || theo == null || theo.isEmpty) return false;
    return rec.substring(0, 10) != theo.substring(0, 10);
  }

  // ── 3e Bottom summary banner ───────────────────────────────────────────────
  Widget _buildSummaryBanner(VaccineCardData data) {
    Color bg, border, textColor;
    String message;

    final hasOverdue = data.pendingDoses.any((d) => d.status == VaccineDoseStatus.overdue);
    final hasDueSoon = data.pendingDoses.any((d) => d.status == VaccineDoseStatus.dueSoon);
    final nextDueSoon = data.pendingDoses
        .where((d) => d.status == VaccineDoseStatus.dueSoon)
        .firstOrNull;

    if (hasOverdue) {
      bg        = const Color(0xFFFEF2F2);
      border    = const Color(0xFFFCA5A5);
      textColor = const Color(0xFF991B1B);
      message   = 'This child has overdue vaccines. Follow up with the patient immediately.';
    } else if (hasDueSoon && nextDueSoon != null) {
      bg        = const Color(0xFFFFFBEB);
      border    = const Color(0xFFFDE68A);
      textColor = const Color(0xFF92400E);
      // Use record-based due date for the banner text
      final duePart = (nextDueSoon.dueDateEstimate != null && nextDueSoon.dueDateEstimate!.isNotEmpty)
          ? ', due ${_formatDateDisplay(nextDueSoon.dueDateEstimate)}'
          : '';
      message = 'Next: ${nextDueSoon.vaccineName} ${nextDueSoon.doseLabel}$duePart.';
    } else {
      bg        = const Color(0xFFDCFCE7);
      border    = const Color(0xFFBBF7D0);
      textColor = const Color(0xFF166534);
      message   = 'This child is fully up to date for their current age.';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: border),
      ),
      child: Text(message,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor, height: 1.4)),
    );
  }

  // ── Skeleton loader ───────────────────────────────────────────────────────
  Widget _buildSkeleton() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _skBox(60, double.infinity),
        const SizedBox(height: 16),
        _skBox(14, 120),
        const SizedBox(height: 8),
        ...List.generate(5, (_) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _skBox(52, double.infinity),
        )),
      ]),
    );
  }

  Widget _skBox(double h, double w) => Container(
    height: h,
    width: w == double.infinity ? double.infinity : w,
    margin: const EdgeInsets.only(bottom: 2),
    decoration: BoxDecoration(
      color: const Color(0xFFE2E8F0),
      borderRadius: BorderRadius.circular(8),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Hover card wrapper (unchanged)
// ─────────────────────────────────────────────────────────────────────────────

class _HoverRecordCard extends StatefulWidget {
  const _HoverRecordCard({required this.child});

  final Widget child;

  @override
  State<_HoverRecordCard> createState() => _HoverRecordCardState();
}

class _HoverRecordCardState extends State<_HoverRecordCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: _hover ? const Color(0xFFDBEAFE) : const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _hover ? const Color(0xFF93C5FD) : const Color(0xFFBFDBFE),
            width: 0.5,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// =============================================================================
// Helper for fetching children list (used by multi-child vaccine modal)
// =============================================================================

class _AdminChildrenHelper {
  static Future<List<Map<String, dynamic>>> fetchChildren(int userId) async {
    try {
      final token = await AdminSessionStorage.getToken();
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/patients/user/$userId/children'),
        headers: headers,
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body) as Map<String, dynamic>;
        if (body['success'] == true && body['data'] is List) {
          return (body['data'] as List)
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      }
      throw Exception('Failed to fetch children');
    } catch (e) {
      throw Exception('Error fetching children: $e');
    }
  }
}
