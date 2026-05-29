import 'package:flutter/material.dart';
import 'package:healthtrack/admin/admin_login_screen.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import 'health_records_service.dart';
import '../utils/message_utils.dart';
import '../services/dashboard_service.dart';

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
    
    // Register for real-time dashboard refresh with higher priority
    DashboardService.addRefreshCallback(_loadHealthRecords, priority: true);
  }

  @override
  void dispose() {
    // Remove refresh callback when widget is disposed
    DashboardService.removeRefreshCallback(_loadHealthRecords);
    super.dispose();
  }

  // Load health records from database
  Future<void> _loadHealthRecords() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
      
      final loadedRecords = await HealthRecordsService.getHealthRecords();
      setState(() {
        healthRecords = loadedRecords;
        filteredRecords = List.from(loadedRecords);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error loading health records: $e',
          title: "Load Error",
        );
      }
    }
  }

  // Filter records based on search query and filters
  void _filterRecords() {
    if (searchQuery.isEmpty && 
        _filterServiceType == 'All' && 
        _filterRecordType == 'All' && 
        _filterGender == 'All' && 
        _filterStartDate == null && 
        _filterEndDate == null) {
      setState(() {
        filteredRecords = List.from(healthRecords);
      });
    } else {
      setState(() {
        filteredRecords = healthRecords.where((record) {
          // Search filter
          bool searchMatch = true;
          if (searchQuery.isNotEmpty) {
            final patientName = record['patientName']?.toString().toLowerCase() ?? '';
            final motherName = record['motherName']?.toString().toLowerCase() ?? '';
            final title = record['title']?.toString().toLowerCase() ?? '';
            final recordType = record['recordType']?.toString().toLowerCase() ?? '';
            
            searchMatch = patientName.contains(searchQuery.toLowerCase()) ||
                         motherName.contains(searchQuery.toLowerCase()) ||
                         title.contains(searchQuery.toLowerCase()) ||
                         recordType.contains(searchQuery.toLowerCase());
          }
          
          // Service type filter (based on recordType)
          bool serviceTypeMatch = _filterServiceType == 'All' || 
                                 (record['recordType']?.toString() ?? '').toLowerCase() == _filterServiceType.toLowerCase();
          
          // Record type filter
          bool recordTypeMatch = _filterRecordType == 'All' || 
                                (record['recordType']?.toString() ?? '').toLowerCase() == _filterRecordType.toLowerCase();
          
          // Gender filter
          bool genderMatch = _filterGender == 'All' || 
                            (record['sex']?.toString() ?? '').toLowerCase() == _filterGender.toLowerCase();
          
          // Date range filter
          bool dateMatch = _checkDateRange(record['createdAt']);
          
          return searchMatch && serviceTypeMatch && recordTypeMatch && genderMatch && dateMatch;
        }).toList();
      });
    }
  }
  
  // Check if record date falls within selected range
  bool _checkDateRange(String? createdAt) {
    // If no date filters are set, match all records
    if (_filterStartDate == null && _filterEndDate == null) return true;
    
    // If createdAt is null or empty, don't match
    if (createdAt == null || createdAt.isEmpty) return true;
    
    // Parse the createdAt date
    final createdDate = DateTime.tryParse(createdAt);
    if (createdDate == null) return true;
    
    // Check if the createdDate falls within the selected range
    bool matchesStartDate = true;
    bool matchesEndDate = true;
    
    if (_filterStartDate != null) {
      // Compare dates (ignoring time) by creating DateTime objects with time set to 00:00:00
      final startDate = DateTime(_filterStartDate!.year, _filterStartDate!.month, _filterStartDate!.day);
      final recordDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
      matchesStartDate = recordDate.isAtSameMomentAs(startDate) || recordDate.isAfter(startDate);
    }
    
    if (_filterEndDate != null) {
      // Compare dates (ignoring time) by creating DateTime objects with time set to 23:59:59
      final endDate = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
      final recordDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
      matchesEndDate = recordDate.isAtSameMomentAs(DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day)) || recordDate.isBefore(endDate);
    }
    
    return matchesStartDate && matchesEndDate;
  }
  
  // Apply filters
  void _applyFilters() {
    _filterRecords();
  }

  // 📄 PRINT RECORD WITH TIMESTAMP
  Future<void> _printRecord(BuildContext context, Map<String, dynamic> record) async {
    final pdf = pw.Document();
    final now = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

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
              pw.Text("Generated on: $now", style: const pw.TextStyle(fontSize: 12)),
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
              _buildDetailRow("Created At", record['createdAt']),
              
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Filter Health Records",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Service Type Filter
              Expanded(
                child: DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Service Type",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                  decoration: const InputDecoration(
                    labelText: "Record Type",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
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
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterStartDate == null
                                        ? "Start Date"
                                        : "${_filterStartDate!.year}-${_filterStartDate!.month.toString().padLeft(2, '0')}-${_filterStartDate!.day.toString().padLeft(2, '0')}",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text("to"),
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
                                border: Border.all(color: Colors.grey),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    _filterEndDate == null
                                        ? "End Date"
                                        : "${_filterEndDate!.year}-${_filterEndDate!.month.toString().padLeft(2, '0')}-${_filterEndDate!.day.toString().padLeft(2, '0')}",
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_filterStartDate != null || _filterEndDate != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _filterStartDate = null;
                            _filterEndDate = null;
                            _applyFilters();
                          });
                        },
                        child: const Text(
                          "Clear Date Filter",
                          style: TextStyle(color: Colors.red),
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
      backgroundColor: Colors.blue[50],
      body: Column(
        children: [
          // ===== HEADER =====
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            color: Colors.blue[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Manage Patient Health Records",
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text("Monitor Health Records",
                        style: TextStyle(color: Colors.black54, fontSize: 13)),
                  ],
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none, color: Colors.black87),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text("No new notifications")),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    const CircleAvatar(
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.person, color: Colors.white),
                    ),
                    const SizedBox(width: 8),
                    const Text("Admin User", style: TextStyle(fontWeight: FontWeight.w500)),
                    const SizedBox(width: 12),
                  ],
                ),
              ],
            ),
          ),

          // ===== CONTENT =====
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Filter Panel
                  _buildFilterPanel(),
                  const SizedBox(height: 16),
                  
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Search patient or record...",
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.all(12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) {
                      setState(() => searchQuery = val);
                      _filterRecords();
                    },
                  ),
                  const SizedBox(height: 20),
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
      return const Center(child: CircularProgressIndicator());
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: filteredRecords.asMap().entries.map((entry) {
        final index = entry.key;
        final record = entry.value;
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.symmetric(vertical: 6),
          elevation: 2,
          child: ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.blueAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.health_and_safety, color: Colors.blueAccent),
            ),
            title: Text(record["title"] ?? "Untitled Record"),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Patient: ${record["patientName"] ?? "Unknown"}"),
                Text("Type: ${record["recordType"] ?? "N/A"}"),
                Text("Date: ${record["createdAt"] ?? "N/A"}"),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View Icon
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.visibility, color: Colors.blue),
                  ),
                  onPressed: () => _viewRecord(record),
                ),
                
                // Delete Icon
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.delete, color: Colors.red),
                  ),
                  onPressed: () => _deleteRecord(index),
                ),
                
                // Print Icon
                IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.print, color: Colors.green),
                  ),
                  onPressed: () => _printRecord(context, record),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}