import 'dart:async';
import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'health_records_service.dart';
import '../utils/message_utils.dart';
import '../utils/time_utils.dart';
import '../services/dashboard_service.dart';
import '../services/connection_status_service.dart';
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

// 🗑 DELETE RECORD with confirmation dialog 
void _deleteRecord(int index) {
  final record = filteredRecords[index];
  
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text("Delete Record"),
      content: const Text(
        "Are you sure you want to delete this health record? This action cannot be undone.",
      ),
      actions: [
        // ✅ Cancel Text (Green)
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text(
            "Cancel",
            style: TextStyle(
              color: Colors.green, // Green text color
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        // 🟥 Delete Button (Red background, White text)
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red, // Red background
            foregroundColor: Colors.white, // White text
          ),
          onPressed: () async {
            Navigator.pop(ctx); // Close confirmation dialog
            
            try {
              final recordId = int.parse(record['id']);
              final success = await HealthRecordsService.deleteHealthRecord(recordId);
              
              if (success) {
                await _loadHealthRecords(); // Refresh the list
                if (mounted) {
                  MessageUtils.showSuccessMessage(
                    context,
                    "Health record has been deleted successfully!",
                    title: "Record Deleted",
                  );
                }
              } else {
                throw Exception('Failed to delete record');
              }
            } catch (e) {
              if (mounted) {
                MessageUtils.showErrorMessage(
                  context,
                  'Error deleting record: $e',
                  title: "Delete Error",
                );
              }
            }
          },
          child: const Text(
            "Delete",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                ),
                const SizedBox(width: 4),
                _gridActionIcon(
                  icon: Icons.print_outlined,
                  backgroundColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF22C55E),
                  borderColor: const Color(0xFFA7F3D0),
                  onPressed: () => _printRecord(context, record),
                ),
                const SizedBox(width: 4),
                _gridActionIcon(
                  icon: Icons.delete_outline,
                  backgroundColor: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFEF4444),
                  borderColor: const Color(0xFFFECACA),
                  onPressed: () => _deleteRecord(index),
                ),
                const SizedBox(width: 4),
                _gridActionIcon(
                  icon: Icons.medical_services_outlined,
                  backgroundColor: const Color(0xFFF5F3FF),
                  iconColor: const Color(0xFF8B5CF6),
                  borderColor: const Color(0xFFDDD6FE),
                  onPressed: () => _showReferralModal(record),
                ),
              ],
            ),
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
  }) {
    return SizedBox(
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