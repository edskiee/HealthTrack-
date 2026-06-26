import 'dart:async';
import 'package:flutter/material.dart';
import 'package:healthtrack/admin/admin_login_screen.dart';
import 'package:healthtrack/services/api_config.dart';
import 'patients_service.dart';
import '../utils/message_utils.dart';
import '../services/dashboard_service.dart';
import '../services/appointment_service.dart';
import '../services/fcm_service.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:csv/csv.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:excel/excel.dart' as xl;
import 'package:healthtrack/services/fcm_notification_service.dart';
import 'package:healthtrack/utils/time_utils.dart';
import 'package:flutter/services.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'widgets/admin_header.dart';

class ManagePatientsView extends StatefulWidget {
  const ManagePatientsView({super.key});

  @override
  State<ManagePatientsView> createState() => _ManagePatientsViewState();
}

class _ManagePatientsViewState extends State<ManagePatientsView> {
  final Color primaryBlue = Colors.blueAccent;
  final TextEditingController _searchController = TextEditingController();
  
  // Socket.IO client for real-time updates
  io.Socket? _socket;
  
  // Paginated patient data
  List<Map<String, String>> patients = [];
  List<Map<String, String>> filteredPatients = [];
  bool isLoading = true;
  String? errorMessage;
  String searchQuery = '';

  // ── Pagination state ─────────────────────────────────────────────────────
  int _currentPage  = 1;
  int _totalPages   = 1;
  int _totalRecords = 0;
  static const int _pageSize = 20;

  // ── Debounce timer for search ────────────────────────────────────────────
  Timer? _searchDebounce;

  // Filter variables
  String _filterServiceType = 'All';
  String _filterGender = 'All';
  String _filterStatus = 'All';
  String _filterAgeRange = 'All';
  
  // Date filter variables for calendar picker
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;

  @override
  void initState() {
    super.initState();
    _loadPatients();
    _searchController.addListener(_onSearchChanged);
    
    // Register for real-time dashboard refresh
    DashboardService.addRefreshCallback(_loadPatients);
    
    // Initialize Socket.IO connection for real-time updates
    _initSocketConnection();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    
    // Remove refresh callback when widget is disposed
    DashboardService.removeRefreshCallback(_loadPatients);
    
    // Disconnect Socket.IO when widget is disposed
    _socket?.disconnect();
    
    super.dispose();
  }
  
  /// Initialize Socket.IO connection for real-time patient updates
  void _initSocketConnection() {
    try {
      // Connect to the Render backend (same server the API is running on)
      final serverUrl = ApiConfig.baseUrl;
      
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket'],
        'autoConnect': true,
      });
      
      // Connect to the socket
      _socket?.connect();
      
      // Join the admins room for real-time updates
      _socket?.emit('joinAdminsRoom');
      
      // Listen for new patient registrations
      _socket?.on('patientRegistered', (data) {
        print('🔔 New patient registered: $data');
        // Refresh the patient list when a new patient is registered
        if (mounted) {
          _loadPatients();
        }
      });
      
      // Listen for new patients (alternative event name)
      _socket?.on('newPatient', (data) {
        print('🔔 New patient added: $data');
        // Refresh the patient list when a new patient is added
        if (mounted) {
          _loadPatients();
        }
      });
      
      // Listen for patient updates
      _socket?.on('patientUpdated', (data) {
        print('🔔 Patient updated: $data');
        // Refresh the patient list when a patient is updated
        if (mounted) {
          _loadPatients();
        }
      });
      
      // Listen for patient deletions
      _socket?.on('patientDeleted', (data) {
        print('🔔 Patient deleted: $data');
        // Refresh the patient list when a patient is deleted
        if (mounted) {
          _loadPatients();
        }
      });
      
      print('✅ Socket.IO connection initialized for real-time patient updates');
    } catch (e) {
      print('❌ Error initializing Socket.IO connection: $e');
    }
  }

  void _onSearchChanged() {
    // 400 ms debounce — only fires a server request after the user stops typing
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() {
        searchQuery = _searchController.text;
        _currentPage = 1; // Reset to first page on new search
      });
      _loadPatients();
    });
  }
  
  void _filterPatients() {
    // Filtering is now server-side; kept as no-op.
    filteredPatients = List.from(patients);
  }

  // Load patients from database — paginated and server-filtered
  Future<void> _loadPatients() async {
    if (!mounted) return;
    
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

      // Retry up to 2 times with a brief backoff (handles Render cold-start 500s)
      Map<String, dynamic>? result;
      Exception? lastError;
      for (int attempt = 0; attempt < 2; attempt++) {
        try {
          result = await PatientsService.getPatientsPage(
            page:        _currentPage,
            limit:       _pageSize,
            search:      searchQuery.trim().isEmpty ? null : searchQuery.trim(),
            serviceType: _filterServiceType == 'All' ? null : _filterServiceType,
            gender:      _filterGender == 'All' ? null : _filterGender,
            status:      _filterStatus == 'All' ? null : _filterStatus,
            ageRange:    _filterAgeRange == 'All' ? null : _filterAgeRange,
            startDate:   startDate,
            endDate:     endDate,
          );
          lastError = null;
          break; // success — stop retrying
        } catch (e) {
          lastError = e is Exception ? e : Exception(e.toString());
          if (attempt == 0) {
            // Wait 2 s before retrying (Render cold-start warm-up)
            await Future.delayed(const Duration(seconds: 2));
          }
        }
      }
      if (lastError != null) throw lastError!;

      if (!mounted) return;
      setState(() {
        patients         = (result!['data'] as List).cast<Map<String, String>>();
        filteredPatients = List.from(patients);
        _totalRecords    = result['total'] as int;
        _totalPages      = result['totalPages'] as int;
        isLoading        = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
      // Error is displayed inline in the patient list container — no popup needed.
    }
  }

  // Add patient to database
  Future<void> _addPatientToDatabase(Map<String, String> patientData) async {
    try {
      // Validate required fields
      if (patientData['childName']?.trim().isEmpty ?? true) {
        throw Exception('Child name is required');
      }
      if (patientData['motherName']?.trim().isEmpty ?? true) {
        throw Exception('Mother name is required');
      }
      if (patientData['dob']?.trim().isEmpty ?? true) {
        throw Exception('Date of birth is required');
      }
      if (patientData['sex']?.trim().isEmpty ?? true) {
        throw Exception('Sex is required');
      }
      if (patientData['recordType']?.trim().isEmpty ?? true) {
        throw Exception('Record type is required');
      }

      setState(() => isLoading = true);
      
      // Add userId required by backend
      final patientWithUserId = {
        ...patientData,
        'userId': '1', // Default admin user ID - can be made dynamic later
      };
      
      final success = await PatientsService.addPatient(patientWithUserId);
      
      // Robust type checking for success field
      bool isSuccess = false;
      if (success['success'] is bool) {
        isSuccess = success['success'];
      } else if (success['success'] is String) {
        isSuccess = success['success'].toLowerCase() == 'true';
      } else if (success['success'] is int) {
        isSuccess = success['success'] == 1;
      }
      
      if (isSuccess) {
        await _loadPatients();
        if (mounted) {
          MessageUtils.showSuccessMessage(
            context,
            "Patient has been added successfully to the system!",
            title: "Patient Added",
          );
        }
      } else {
        throw Exception('Failed to add patient - server returned false');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error adding patient: $e',
          title: "Add Error",
        );
      }
    }
  }

  // Update patient in database
  Future<void> _updatePatientInDatabase(int index, Map<String, String> patientData) async {
    try {
      setState(() => isLoading = true);
      
      // Ensure we have all required fields including userId
      final updatedData = {
        'userId': '1', // Default admin user ID - can be made dynamic later
        'childName': patientData['childName'] ?? '',
        'motherName': patientData['motherName'] ?? '',
        'fatherName': patientData['fatherName'] ?? '',
        'dob': patientData['dob'] ?? '',
        'placeOfBirth': patientData['placeOfBirth'] ?? '',
        'birthWeight': patientData['birthWeight'] ?? '',
        'birthHeight': patientData['birthHeight'] ?? '',
        'sex': patientData['sex'] ?? '',
        'address': patientData['address'] ?? '',
        'recordType': patientData['recordType'] ?? 'Diagnosis',
        'serviceType': patientData['serviceType'] ?? 'immunization',
        'recordDescription': patientData['recordDescription'] ?? '',
        // Add maternal care fields with proper type handling
        'familySerialNumber': patientData['familySerialNumber'] ?? '',
        'contactNumber': patientData['contactNumber'] ?? '',
        'spouseName': patientData['spouseName'] ?? '',
        'livingChildrenCount': patientData['livingChildrenCount'] ?? '0',
        'monthlyIncome': patientData['monthlyIncome'] ?? '0',
        'religion': patientData['religion'] ?? '',
        'city': patientData['city'] ?? '',
        'province': patientData['province'] ?? '',
        'age': patientData['age'] ?? '0',
        'education': patientData['education'] ?? '',
        'occupation': patientData['occupation'] ?? '',
        'birthAttendant': patientData['birthAttendant'] ?? 'None',
        'facilityType': patientData['facilityType'] ?? '',
        // Immunization fields
        'healthCenter': patientData['healthCenter'] ?? '',
        'barangay': patientData['barangay'] ?? '',
        'familyNumber': patientData['familyNumber'] ?? ''
      };
      
      // Get the patient ID from the patients list
      if (patients[index].containsKey('id')) {
        final patientId = patients[index]['id']!;
      
        // Debug: Print the data being sent
        print('Updating patient ID: $patientId');
        print('Update data: $updatedData');
        
        final result = await PatientsService.updatePatient(patientId, updatedData);
        
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
          await _loadPatients(); // Reload the list
          if (mounted) {
            MessageUtils.showSuccessMessage(
              context,
              "Patient information has been updated successfully!",
              title: "Patient Updated",
            );
          }
        } else {
          throw Exception(result['message'] ?? 'Failed to update patient');
        }
      } else {
        throw Exception('Patient ID not found. Please refresh the list.');
      }
    } catch (e, stackTrace) {
      // Log detailed error information
      print('Update error: $e');
      print('Stack trace: $stackTrace');
      
      setState(() => isLoading = false);
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          "Error updating patient: $e",
          title: "Update Error",
        );
      }
    }
  }

  // Show patient type selection dialog
Future<void> _showPatientTypeSelection() async {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Select Patient Type"),
        content: const Text("Choose the type of patient you want to add:"),
        actions: [
          // 🔴 Cancel Button - Red Text
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              "Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),

          // 🟩 Immunization Patient Button - Green
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white, // text color
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showImmunizationForm();
            },
            child: const Text("Immunization Patient"),
          ),

          // 💗 Maternal Care Patient Button - Pink
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.pinkAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _showMaternalCareForm();
            },
            child: const Text("Maternal Care Patient"),
          ),
        ],
      );
    },
  );
}

  // Show immunization patient form
  Future<void> _showImmunizationForm() async {
    // Controllers for immunization form
    final childNameCtrl = TextEditingController();
    final motherNameCtrl = TextEditingController();
    final fatherNameCtrl = TextEditingController();
    final dobCtrl = TextEditingController();
    final placeOfBirthCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final birthHeightCtrl = TextEditingController();
    final birthWeightCtrl = TextEditingController();
    final healthCenterCtrl = TextEditingController();
    final barangayCtrl = TextEditingController();
    final familyNumberCtrl = TextEditingController();
    
    // Sex selection
    String sexValue = "Male";
    
    // Date of birth
    DateTime? selectedDate;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Helper function to check if form is valid
            bool isFormValid() {
              // Required field validation
              if (childNameCtrl.text.trim().isEmpty) return false;
              if (motherNameCtrl.text.trim().isEmpty) return false;
              if (selectedDate == null) return false;
              
              // Numeric field validation
              if (birthHeightCtrl.text.trim().isNotEmpty && _validateNumericInput(birthHeightCtrl.text) != null) return false;
              if (birthWeightCtrl.text.trim().isNotEmpty && _validateNumericInput(birthWeightCtrl.text) != null) return false;
              if (familyNumberCtrl.text.trim().isNotEmpty && _validateNumericInput(familyNumberCtrl.text) != null) return false;
              
              return true;
            }
            
            return AlertDialog(
              title: const Text("Add Immunization Patient"),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildField("Child's Name", childNameCtrl, required: true),
                      _buildField("Mother's Name", motherNameCtrl, required: true),
                      _buildField("Father's Name", fatherNameCtrl),
                      
                      // Date of Birth Picker
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Date of Birth *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    selectedDate = picked;
                                    dobCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedDate == null
                                          ? "Select Date of Birth"
                                          : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                                    ),
                                    const Icon(Icons.calendar_today, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _buildField("Place of Birth", placeOfBirthCtrl),
                      _buildField("Address", addressCtrl),
                      StatefulBuilder(
                        builder: (context, setStateInner) {
                          return TextField(
                            controller: birthHeightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                            ],
                            decoration: InputDecoration(
                              labelText: "Birth Height (cm)",
                              border: const OutlineInputBorder(),
                              errorText: _validateNumericInput(birthHeightCtrl.text),
                            ),
                            onChanged: (value) {
                              setStateInner(() {});
                              setStateDialog(() {});
                            },
                          );
                        },
                      ),
                      StatefulBuilder(
                        builder: (context, setStateInner) {
                          return TextField(
                            controller: birthWeightCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                            ],
                            decoration: InputDecoration(
                              labelText: "Birth Weight (kg)",
                              border: const OutlineInputBorder(),
                              errorText: _validateNumericInput(birthWeightCtrl.text),
                            ),
                            onChanged: (value) {
                              setStateInner(() {});
                              setStateDialog(() {});
                            },
                          );
                        },
                      ),
                      _buildField("Health Center", healthCenterCtrl),
                      _buildField("Barangay", barangayCtrl),
                      StatefulBuilder(
                        builder: (context, setStateInner) {
                          return TextField(
                            controller: familyNumberCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
                            ],
                            decoration: InputDecoration(
                              labelText: "Family Number",
                              border: const OutlineInputBorder(),
                              errorText: _validateNumericInput(familyNumberCtrl.text),
                            ),
                            onChanged: (value) {
                              setStateInner(() {});
                              setStateDialog(() {});
                            },
                          );
                        },
                      ),
                      
                      // Sex Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Sex *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: sexValue,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Male", child: Text("Male")),
                                DropdownMenuItem(value: "Female", child: Text("Female")),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  sexValue = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                // 🔴 Cancel Button (Red Text)
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text(
                    "Cancel",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                
                // 🟢 Save Button (Green with White Text)
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green, // Green background
                    foregroundColor: Colors.white, // White text
                  ),
                  onPressed: isFormValid() ? () async {
                    // Validation
                    if (childNameCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Child's name is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (motherNameCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Mother's name is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (selectedDate == null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Date of birth is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    // Numeric field validation
                    if (birthHeightCtrl.text.trim().isNotEmpty && _validateNumericInput(birthHeightCtrl.text) != null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Birth Height must be a valid number",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    if (birthWeightCtrl.text.trim().isNotEmpty && _validateNumericInput(birthWeightCtrl.text) != null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Birth Weight must be a valid number",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    if (familyNumberCtrl.text.trim().isNotEmpty && _validateNumericInput(familyNumberCtrl.text) != null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Family Number must be a valid number",
                        title: "Validation Error",
                      );
                      return;
                    }

                    // Prepare data
                    final newData = {
                      "childName": childNameCtrl.text.trim(),
                      "motherName": motherNameCtrl.text.trim(),
                      "fatherName": fatherNameCtrl.text.trim(),
                      "dob": dobCtrl.text,
                      "placeOfBirth": placeOfBirthCtrl.text.trim(),
                      "birthWeight": birthWeightCtrl.text.trim(),
                      "birthHeight": birthHeightCtrl.text.trim(),
                      "sex": sexValue,
                      "address": addressCtrl.text.trim(),
                      "recordType": "Immunization",
                      "serviceType": "immunization",
                      "recordDescription": "Immunization patient record",
                      "healthCenter": healthCenterCtrl.text.trim(),
                      "barangay": barangayCtrl.text.trim(),
                      "familyNumber": familyNumberCtrl.text.trim(),
                    };

                    Navigator.of(context).pop();
                    await _addPatientToDatabase(newData);
                  } : null, // Disable button if form is not valid
                  child: const Text(
                    "Save",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ), // ElevatedButton
              ], // <-- ✅ Close the actions list properly
            );
          }, // <-- ✅ Close StatefulBuilder
        );
      }, // <-- ✅ Close showDialog builder
    );
  } // <-- 

  // Show maternal care patient form
  Future<void> _showMaternalCareForm() async {
    // Controllers for maternal care form - Updated to match new requirements
    final motherNameCtrl = TextEditingController();
    final motherDobCtrl = TextEditingController();
    final educationCtrl = TextEditingController();
    final occupationCtrl = TextEditingController();
    String statusValue = "Married"; // Default status
    final religionCtrl = TextEditingController();
    final addressCtrl = TextEditingController();
    final contactNumberCtrl = TextEditingController();
    
    // Spouse information
    final spouseNameCtrl = TextEditingController();
    final spouseDobCtrl = TextEditingController();
    final spouseEducationCtrl = TextEditingController();
    final spouseOccupationCtrl = TextEditingController();
    
    // Pregnancy information
    final monthlyIncomeCtrl = TextEditingController();
    final livingChildrenCtrl = TextEditingController();
    String birthPlanValue = "Hospital"; // Default birth plan
    String birthAttendantValue = "SBA"; // Default birth attendant
    bool showBirthAttendant = false; // Show birth attendant only if "Home" is selected
    
    // Age calculation
    final ageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            // Helper function to check if maternal care form is valid
            bool isMaternalFormValid() {
              // Required field validation
              if (motherNameCtrl.text.trim().isEmpty) return false;
              if (motherDobCtrl.text.isEmpty) return false;
              if (occupationCtrl.text.trim().isEmpty) return false;
              if (addressCtrl.text.trim().isEmpty) return false;
              if (contactNumberCtrl.text.trim().isEmpty) return false;
              
              // Numeric field validation
              if (contactNumberCtrl.text.trim().isNotEmpty && _validateNumericInput(contactNumberCtrl.text) != null) return false;
              
              // Conditional validation for spouse information when status is not Single
              if (statusValue != "Single") {
                if (spouseNameCtrl.text.trim().isEmpty) return false;
                if (spouseDobCtrl.text.isEmpty) return false;
                if (spouseEducationCtrl.text.trim().isEmpty) return false;
                if (spouseOccupationCtrl.text.trim().isEmpty) return false;
                if (monthlyIncomeCtrl.text.trim().isEmpty) return false;
                if (livingChildrenCtrl.text.trim().isEmpty) return false;
                
                // Numeric field validation for living children
                if (livingChildrenCtrl.text.trim().isNotEmpty && _validateNumericInput(livingChildrenCtrl.text) != null) return false;
              }
              
              if (showBirthAttendant && birthAttendantValue.isEmpty) return false;
              
              return true;
            }
            
            return AlertDialog(
              title: const Text("Add Maternal Care Patient"),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Mother Information Section
                      const Divider(height: 32),
                      const Text("Mother Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      
                      _buildField("Mother's Full Name", motherNameCtrl, required: true),
                      
                      // Mother Date of Birth Picker with Age Calculation
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Date of Birth *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(1900),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    motherDobCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
                                    // Calculate age
                                    final now = DateTime.now();
                                    final age = now.year - picked.year;
                                    ageCtrl.text = age.toString();
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      motherDobCtrl.text.isEmpty
                                          ? "Select Date of Birth"
                                          : "${motherDobCtrl.text}",
                                    ),
                                    const Icon(Icons.calendar_today, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      _buildField("Age (calculated)", ageCtrl, enabled: false),
                      _buildField("Occupation", occupationCtrl, required: true),
                      
                      // Status Selection with dynamic behavior
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Status *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: statusValue,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Single", child: Text("Single")),
                                DropdownMenuItem(value: "Married", child: Text("Married")),
                                DropdownMenuItem(value: "Widowed", child: Text("Widowed")),
                                DropdownMenuItem(value: "Separated", child: Text("Separated")),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  statusValue = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      _buildField("Religion", religionCtrl),
                      _buildField("Address", addressCtrl, required: true),
                      StatefulBuilder(
                        builder: (context, setStateInner) {
                          return TextField(
                            controller: contactNumberCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: false),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: InputDecoration(
                              labelText: "Contact Number *",
                              border: const OutlineInputBorder(),
                              errorText: _validateNumericInput(contactNumberCtrl.text),
                            ),
                            onChanged: (value) {
                              setStateInner(() {});
                              setStateDialog(() {});
                            },
                          );
                        },
                      ),
                      
                      // Pregnancy Information Section (conditionally shown)
                      if (statusValue != "Single") ...[
                        const Divider(height: 32),
                        const Text("Pregnancy Information", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 8),
                        
                        _buildField("Spouse's Full Name", spouseNameCtrl, required: true),
                        
                        // Spouse Date of Birth Picker
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Spouse's Date of Birth *", style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setStateDialog(() {
                                      spouseDobCtrl.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
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
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        spouseDobCtrl.text.isEmpty
                                            ? "Select Spouse's Date of Birth"
                                            : "${spouseDobCtrl.text}",
                                      ),
                                      const Icon(Icons.calendar_today, size: 18),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        _buildField("Spouse's Highest Education", spouseEducationCtrl, required: true),
                        _buildField("Spouse's Occupation", spouseOccupationCtrl, required: true),
                        _buildField("Average Family Income", monthlyIncomeCtrl, required: true),
                        StatefulBuilder(
                          builder: (context, setStateInner) {
                            return TextField(
                              controller: livingChildrenCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: false),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: InputDecoration(
                                labelText: "Number of Living Children *",
                                border: const OutlineInputBorder(),
                                errorText: _validateNumericInput(livingChildrenCtrl.text),
                              ),
                              onChanged: (value) {
                                setStateInner(() {});
                                setStateDialog(() {});
                              },
                            );
                          },
                        ),
                      ],
                      
                      // Birth Plan Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Birth Plan *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: birthPlanValue,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Hospital", child: Text("Hospital")),
                                DropdownMenuItem(value: "Birthing Center", child: Text("Birthing Center")), // Updated to Birthing Center
                                DropdownMenuItem(value: "RHU", child: Text("RHU (Rural Health Unit)")), // Added full name
                                DropdownMenuItem(value: "Home", child: Text("Home")),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  birthPlanValue = value!;
                                  // Show birth attendant field only if "Home" is selected
                                  showBirthAttendant = value == "Home";
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      // Birth Attendant Selection (only shown if "Home" is selected)
                      if (showBirthAttendant)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Birth Attendant Type *", style: TextStyle(fontWeight: FontWeight.w500)),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: birthAttendantValue,
                                decoration: const InputDecoration(
                                  border: OutlineInputBorder(),
                                ),
                                items: const [
                                  DropdownMenuItem(value: "SBA", child: Text("SBA")),
                                  DropdownMenuItem(value: "Non-SBA", child: Text("Non-SBA")),
                                ],
                                onChanged: (value) {
                                  setStateDialog(() {
                                    birthAttendantValue = value!;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: isMaternalFormValid() ? () async {
                    // Validation
                    if (motherNameCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Mother's name is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (motherDobCtrl.text.isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Mother's date of birth is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (occupationCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Mother's occupation is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (addressCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Address is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (contactNumberCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Contact number is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    // Numeric validation for contact number
                    if (contactNumberCtrl.text.trim().isNotEmpty && _validateNumericInput(contactNumberCtrl.text) != null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Contact number must be a valid number",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    // Conditional validation for spouse information when status is not Single
                    if (statusValue != "Single") {
                      if (spouseNameCtrl.text.trim().isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Spouse's name is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      if (spouseDobCtrl.text.isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Spouse's date of birth is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      if (spouseEducationCtrl.text.trim().isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Spouse's education is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      if (spouseOccupationCtrl.text.trim().isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Spouse's occupation is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      if (monthlyIncomeCtrl.text.trim().isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Monthly income is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      if (livingChildrenCtrl.text.trim().isEmpty) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Number of living children is required",
                          title: "Validation Error",
                        );
                        return;
                      }
                      
                      // Numeric validation for living children
                      if (livingChildrenCtrl.text.trim().isNotEmpty && _validateNumericInput(livingChildrenCtrl.text) != null) {
                        MessageUtils.showErrorMessage(
                          context,
                          "Number of living children must be a valid number",
                          title: "Validation Error",
                        );
                        return;
                      }
                    }
                    
                    if (showBirthAttendant && birthAttendantValue.isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Birth attendant type is required when birth plan is Home",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    // Prepare data - Updated to match new maternal care fields
                    final newData = {
                      "childName": motherNameCtrl.text.trim(), // Using mother name as child name for consistency
                      "motherName": motherNameCtrl.text.trim(),
                      "fatherName": spouseNameCtrl.text.trim(),
                      "dob": motherDobCtrl.text,
                      "placeOfBirth": "", // Not applicable for maternal care
                      "birthWeight": "", // Not applicable for maternal care
                      "birthHeight": "", // Not applicable for maternal care
                      "sex": "Female", // Assuming maternal care is for females
                      "address": addressCtrl.text.trim(),
                      "recordType": "Maternal Care",
                      "serviceType": "maternal",
                      "recordDescription": "Maternal care patient record",
                      
                      // Maternal care specific fields
                      "familySerialNumber": "", // Can be added later if needed
                      "contactNumber": contactNumberCtrl.text.trim(),
                      "spouseName": spouseNameCtrl.text.trim(),
                      "livingChildrenCount": livingChildrenCtrl.text.trim(),
                      "monthlyIncome": monthlyIncomeCtrl.text.trim(),
                      "religion": religionCtrl.text.trim(),
                      "city": "", // Can be extracted from address if needed
                      "province": "", // Can be extracted from address if needed
                      "age": ageCtrl.text.trim(),
                      "education": educationCtrl.text.trim(),
                      "occupation": occupationCtrl.text.trim(),
                      "birthAttendant": showBirthAttendant ? birthAttendantValue : "",
                      "facilityType": birthPlanValue,
                    };

                    Navigator.of(context).pop();

                    await _addPatientToDatabase(newData);
                  } : null, // Disable button if form is not valid
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Show patient form dialog (existing method for editing)
  Future<void> _showPatientForm({Map<String, String>? patient, int? index}) async {
    // Controllers
    final childCtrl = TextEditingController(text: patient?["childName"]);
    final motherCtrl = TextEditingController(text: patient?["motherName"]);
    final fatherCtrl = TextEditingController(text: patient?["fatherName"]);
    final pobCtrl = TextEditingController(text: patient?["placeOfBirth"]);
    final weightCtrl = TextEditingController(text: patient?["birthWeight"]);
    final heightCtrl = TextEditingController(text: patient?["birthHeight"]);
    final addressCtrl = TextEditingController(text: patient?["address"]);
    final recordDescCtrl = TextEditingController(text: patient?["recordDescription"]);
    
    // Date of birth
    DateTime? selectedDate = patient?["dob"] != null && patient!["dob"]!.isNotEmpty
        ? DateTime.tryParse(patient["dob"]!)
        : null;
    
    // Sex selection
    String sexValue = patient?["sex"] ?? "Male";
    
    // Record type selection
    String recordTypeValue = patient?["recordType"] ?? "Diagnosis";
    
    // Service type selection (Patient Type)
    // Initialize with a valid default value that exists in the dropdown
    String serviceTypeValue = 'immunization';
    
    // Only attempt to set from patient data if it exists
    if (patient != null && patient["serviceType"] != null) {
      // Ensure we only use exact values that match dropdown options
      String patientServiceType = patient["serviceType"].toString();
      if (patientServiceType == 'maternal' || patientServiceType == 'Maternal Care') {
        serviceTypeValue = 'maternal';
      } else {
        serviceTypeValue = 'immunization';
      }
    }

    // Show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: Text(patient == null ? "Add New Patient" : "Edit Patient"),
              content: SingleChildScrollView(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.8,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildField("Child's Full Name", childCtrl, required: true),
                      _buildField("Mother's Full Name", motherCtrl, required: true),
                      _buildField("Father's Full Name", fatherCtrl),
                      _buildField("Place of Birth", pobCtrl),
                      
                      // Date of Birth Picker
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Date of Birth *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            InkWell(
                              onTap: () async {
                                final DateTime? picked = await showDatePicker(
                                  context: context,
                                  initialDate: selectedDate ?? DateTime.now(),
                                  firstDate: DateTime(2000),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) {
                                  setStateDialog(() {
                                    selectedDate = picked;
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
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      selectedDate == null
                                          ? "Select Date of Birth"
                                          : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                                    ),
                                    const Icon(Icons.calendar_today, size: 18),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildField("Birth Weight (kg)", weightCtrl),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildField("Birth Height (cm)", heightCtrl),
                          ),
                        ],
                      ),
                      
                      // Sex Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Sex *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: sexValue,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "Male", child: Text("Male")),
                                DropdownMenuItem(value: "Female", child: Text("Female")),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  sexValue = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      _buildField("Address", addressCtrl),
                      
                      // Record Type Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Record Type *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
  value: recordTypeValue,
  decoration: const InputDecoration(
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: "Diagnosis", child: Text("Diagnosis")),
    DropdownMenuItem(value: "Immunization", child: Text("Immunization")),
    DropdownMenuItem(value: "Consultation", child: Text("Consultation")),
    DropdownMenuItem(value: "Maternal Care", child: Text("Maternal Care")), // ✅ Added this
    DropdownMenuItem(value: "Others", child: Text("Others")),
  ],
  onChanged: (value) {
    setStateDialog(() {
      recordTypeValue = value!;
    });
  },
),
                          ],
                        ),
                      ),
                      
                      // Patient Type (Service Type) Selection
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Patient Type *", style: TextStyle(fontWeight: FontWeight.w500)),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: serviceTypeValue,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                              ),
                              items: const [
                                DropdownMenuItem(value: "immunization", child: Text("Immunization")),
                                DropdownMenuItem(value: "maternal", child: Text("Maternal Care")),
                              ],
                              onChanged: (value) {
                                setStateDialog(() {
                                  serviceTypeValue = value!;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      
                      _buildField("Record Description", recordDescCtrl),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Validation
                    if (childCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Child's name is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (motherCtrl.text.trim().isEmpty) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Mother's name is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    if (selectedDate == null) {
                      MessageUtils.showErrorMessage(
                        context,
                        "Date of birth is required",
                        title: "Validation Error",
                      );
                      return;
                    }
                    
                    // Format date as string
                    final dobString = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
                    
                    // Prepare data
                    final newData = {
                      "childName": childCtrl.text.trim(),
                      "motherName": motherCtrl.text.trim(),
                      "fatherName": fatherCtrl.text.trim(),
                      "dob": dobString,
                      "placeOfBirth": pobCtrl.text.trim(),
                      "birthWeight": weightCtrl.text.trim(),
                      "birthHeight": heightCtrl.text.trim(),
                      "sex": sexValue,
                      "address": addressCtrl.text.trim(),
                      "recordType": recordTypeValue,
                      "serviceType": serviceTypeValue ?? 'immunization',
                      "recordDescription": recordDescCtrl.text.trim(),
                    };

                    Navigator.of(context).pop();

                    if (patient == null) {
                      await _addPatientToDatabase(newData);
                    } else {
                      await _updatePatientInDatabase(index!, newData);
                    }
                  },
                  child: const Text("Save"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Confirm delete
  void _confirmDelete(int index) async {
    final confirmed = await MessageUtils.showConfirmationDialog(
      context,
      title: "Delete Patient",
      message: "Are you sure you want to delete ${patients[index]["childName"]}? This action cannot be undone.",
      confirmText: "Delete",
      cancelText: "Cancel",
      confirmColor: Colors.red,
    );
    
    if (confirmed) {
      await _deletePatient(index);
    }
  }

  // Delete patient from database
  Future<void> _deletePatient(int index) async {
    try {
      setState(() => isLoading = true);
      
      // Use the filtered list if search is active, otherwise use the main list
      final patientsList = searchQuery.isNotEmpty ? filteredPatients : patients;
      
      if (patientsList[index].containsKey('id')) {
        final patientId = patientsList[index]['id']!;
        final result = await PatientsService.deletePatient(patientId);
        
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
          await _loadPatients();
          if (mounted) {
            MessageUtils.showSuccessMessage(
              context,
              "Patient has been removed from the system successfully!",
              title: "Patient Deleted",
            );
          }
        } else {
          throw Exception(result['message'] ?? 'Failed to delete patient');
        }
      } else {
        throw Exception('Patient ID not found');
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error deleting patient: $e',
          title: "Delete Error",
        );
      }
    }
  }

  // Build form field
  Widget _buildField(String label, TextEditingController controller, {bool required = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  // Build numeric form field with validation
  Widget _buildNumericField(String label, TextEditingController controller, {bool required = false, bool enabled = true}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*$')),
        ],
        decoration: InputDecoration(
          labelText: required ? "$label *" : label,
          border: const OutlineInputBorder(),
          errorText: _validateNumericInput(controller.text),
        ),
      ),
    );
  }

  // Validate numeric input
  String? _validateNumericInput(String value) {
    if (value.isEmpty) return null;
    
    // Check if the value is a valid number (including decimals)
    final numericRegex = RegExp(r'^\d*\.?\d*$');
    if (!numericRegex.hasMatch(value)) {
      return 'Please enter numbers only';
    }
    
    return null;
  }

  // Format date for display
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not specified';
    
    try {
      String cleanDate = dateStr;
      if (dateStr.contains('T')) {
        cleanDate = dateStr.split('T')[0];
      }
      final date = DateTime.parse(cleanDate);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr; // Return original if parsing fails
    }
  }

  /// Avatar color pairs cycle by grid index (layout only).
  (Color, Color) _patientAvatarPaletteForGridIndex(int index) {
    const palettes = <(Color, Color)>[
      (Color(0xFFE6F1FB), Color(0xFF0C447C)),
      (Color(0xFFE1F5EE), Color(0xFF085041)),
      (Color(0xFFEEEDFE), Color(0xFF3C3489)),
      (Color(0xFFFAECE7), Color(0xFF712B13)),
      (Color(0xFFEAF3DE), Color(0xFF27500A)),
    ];
    return palettes[index % palettes.length];
  }

  String _patientCardInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts =
        trimmed.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) {
      final a = parts.first.isNotEmpty ? parts.first[0] : '';
      final b = parts.last.isNotEmpty ? parts.last[0] : '';
      return ('$a$b').toUpperCase();
    }
    final s = parts.first;
    if (s.length >= 2) {
      return s.substring(0, 2).toUpperCase();
    }
    return s.toUpperCase();
  }

  bool _patientRowIsActive(Map<String, String> patient) {
    final statusRaw = patient['status']?.toLowerCase().trim() ?? '';
    return statusRaw == 'active' || statusRaw == '1';
  }

  String _patientSubtitleIdOrDob(Map<String, String> patient) {
    final id = patient['id']?.trim();
    if (id != null && id.isNotEmpty) {
      return 'ID $id';
    }
    return _formatDate(patient['dob']);
  }

  Widget _patientCardMetaCaption(String text) {
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

  Widget _patientCardGrayChip(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        value,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: Color(0xFF475569),
          height: 1.2,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _patientGridActionIcon({
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

  Widget _buildPatientGridCard(int i) {
    final patient = filteredPatients[i];
    final childName = patient['childName'] ?? '';
    final initials = _patientCardInitials(childName);
    final avatarStyle = _patientAvatarPaletteForGridIndex(i);
    final isActive = _patientRowIsActive(patient);
    final recordType = patient['recordType'] ?? 'N/A';

    void onEdit() {
      final originalIndex =
          patients.indexWhere((p) => p['id'] == filteredPatients[i]['id']);
      _showPatientForm(patient: patients[originalIndex], index: originalIndex);
    }

    void onDelete() {
      final originalIndex =
          patients.indexWhere((p) => p['id'] == filteredPatients[i]['id']);
      _confirmDelete(originalIndex);
    }

    return _HoverPatientCard(
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
                              childName,
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
                        _patientSubtitleIdOrDob(patient),
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _patientCardMetaCaption('RECORD'),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _patientCardGrayChip(recordType),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _patientCardMetaCaption('TYPE'),
                const SizedBox(width: 8),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: _patientCardGrayChip(
                        _formatServiceType(patient['serviceType'])),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(height: 0.5, color: const Color(0xFFBFDBFE)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: Color(0xFF3B6899),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _formatDate(patient['dob']),
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF3B6899),
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _patientGridActionIcon(
                  icon: Icons.edit_outlined,
                  backgroundColor: const Color(0xFFECFDF5),
                  iconColor: const Color(0xFF22C55E),
                  borderColor: const Color(0xFFBBF7D0),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 4),
                _patientGridActionIcon(
                  icon: Icons.delete_outline,
                  backgroundColor: const Color(0xFFFEF2F2),
                  iconColor: const Color(0xFFEF4444),
                  borderColor: const Color(0xFFFECACA),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonLoader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 5;
        final maxW = constraints.maxWidth;
        final cardWidth = maxW.isFinite ? (maxW - gap * (cols - 1)) / cols : 200.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: List.generate(10, (i) => SizedBox(
            width: cardWidth,
            child: _buildSkeletonCard(),
          )),
        );
      },
    );
  }

  Widget _buildSkeletonCard() {
    return Container(
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
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _shimmerBox(12, double.infinity),
              const SizedBox(height: 6),
              _shimmerBox(10, 80),
            ])),
          ]),
          const SizedBox(height: 10),
          _shimmerBox(1, double.infinity),
          const SizedBox(height: 10),
          _shimmerBox(10, 60),
          const SizedBox(height: 6),
          _shimmerBox(10, 80),
          const SizedBox(height: 10),
          _shimmerBox(1, double.infinity),
          const SizedBox(height: 10),
          _shimmerBox(10, 100),
        ],
      ),
    );
  }

  Widget _shimmerBox(double height, double width, {bool circular = false}) {
    return Container(
      height: height,
      width: width == double.infinity ? double.infinity : width,
      decoration: BoxDecoration(
        color: const Color(0xFFDBEAFE),
        borderRadius: circular
            ? BorderRadius.circular(999)
            : BorderRadius.circular(4),
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
                  _loadPatients();
                }
              : null,
          icon: const Icon(Icons.chevron_left, size: 18),
          label: const Text('Prev'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            side: const BorderSide(color: Colors.blueAccent),
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
                  _loadPatients();
                }
              : null,
          icon: const Icon(Icons.chevron_right, size: 18),
          label: const Text('Next'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.blueAccent,
            side: const BorderSide(color: Colors.blueAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildPatientListWrap() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        const cols = 5;
        final maxW = constraints.maxWidth;
        final cardWidth =
            maxW.isFinite ? (maxW - gap * (cols - 1)) / cols : 200.0;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (int i = 0; i < filteredPatients.length; i++)
              SizedBox(
                width: cardWidth,
                child: _buildPatientGridCard(i),
              ),
          ],
        );
      },
    );
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.blue[50],
    body: SafeArea(
      child: Column(
        children: [
          AdminHeader(
            title: "Manage Patients",
            subtitle: "Manage and track all patient records",
            onRefresh: _loadPatients,
            showLiveClock: true,
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Next Appointment Reminder Panel
                  _buildNextAppointmentReminderPanel(),
                  const SizedBox(height: 16),

                  // Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.people_alt,
                            color: primaryBlue, size: 32),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Patient Management",
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: primaryBlue)),
                            const Text(
                                "Manage and monitor patient information"),
                          ],
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: _showPatientTypeSelection, // Changed to show patient type selection
                          icon: const Icon(Icons.add),
                          label: const Text("Add Patient"),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Enhanced Filters
                  _buildFilterPanel(),
                  const SizedBox(height: 16),

                  // Search + Export
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: "Search by mother, father, or child name...",
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _showExportOptions,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white),
                          child: const Text("Export List")),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Patient List
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4)
                      ],
                    ),
                    child: Column(
                      children: [
                        if (isLoading)
                          // ── Skeleton loader ──────────────────────────────
                          _buildSkeletonLoader()
                        else if (errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(Icons.error, color: Colors.red, size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading patients',
                                  style: TextStyle(
                                      fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                Text(errorMessage!),
                                const SizedBox(height: 16),
                                ElevatedButton(
                                  onPressed: _loadPatients,
                                  child: const Text('Retry'),
                                ),
                              ],
                            ),
                          )
                        else if (filteredPatients.isEmpty && searchQuery.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              children: [
                                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                                const SizedBox(height: 16),
                                Text(
                                  'No patients found for "$searchQuery"',
                                  style: const TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Try searching with different keywords',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else if (filteredPatients.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(20),
                            child: Column(
                              children: [
                                Icon(Icons.people_outline, size: 48, color: Colors.grey),
                                SizedBox(height: 16),
                                Text(
                                  'No patients found',
                                  style: TextStyle(fontSize: 18, color: Colors.grey),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Add your first patient using the button above',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              // ── Pagination info bar ──────────────────────
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Showing ${filteredPatients.length} of $_totalRecords patient(s)  •  Page $_currentPage of $_totalPages',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _buildPatientListWrap(),
                              const SizedBox(height: 16),
                              // ── Prev / Next controls ─────────────────────
                              _buildPaginationControls(),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// Next Appointment Reminder Panel
Widget _buildNextAppointmentReminderPanel() {
  return FutureBuilder<Map<String, dynamic>?>(
    future: _getNextAppointment(), // This will fetch the next appointment
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text("Loading next appointment..."),
            ],
          ),
        );
      }

      if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: const Text(
            "No upcoming appointments found",
            style: TextStyle(
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      }

      final appointment = snapshot.data!;
      final patientName = appointment['patient_full_name'] ?? appointment['patient_name'] ?? 'Unknown Patient';
      final serviceType = appointment['service_type'] ?? 'immunization';
      final appointmentDate = appointment['appointment_date'] ?? '';
      final appointmentTime = appointment['appointment_time'] ?? '';
      final scheduleDisplay = TimeUtils.formatAppointmentUtcDateTime(
        appointmentDate.toString(),
        appointmentTime.toString(),
        pattern: 'MMMM dd, yyyy hh:mm a',
      );

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black12.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Next Appointment",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "$patientName — ${_formatServiceType(serviceType)} on $scheduleDisplay",
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _sendReminder(appointment),
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text("Send Reminder"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () => _viewAppointmentDetails(appointment),
                    icon: const Icon(Icons.visibility, size: 18),
                    label: const Text("View Details"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.blueAccent,
                      side: const BorderSide(color: Colors.blueAccent),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

// Enhanced Filter Panel
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
          "Filter Patients",
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
                  DropdownMenuItem(value: 'immunization', child: Text('Immunization')),
                  DropdownMenuItem(value: 'maternal', child: Text('Maternal Care')),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterServiceType = val ?? 'All';
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
            
            // Status Filter
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Status",
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                value: _filterStatus,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'archived', child: Text('Archived')),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterStatus = val ?? 'All';
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
            // Age Range Filter
            Expanded(
              child: DropdownButtonFormField<String>(
                decoration: const InputDecoration(
                  labelText: "Age Range",
                  contentPadding: EdgeInsets.symmetric(horizontal: 12),
                ),
                value: _filterAgeRange,
                items: const [
                  DropdownMenuItem(value: 'All', child: Text('All Ages')),
                  DropdownMenuItem(value: '0-1', child: Text('0-1 years')),
                  DropdownMenuItem(value: '1-5', child: Text('1-5 years')),
                  DropdownMenuItem(value: '5-10', child: Text('5-10 years')),
                  DropdownMenuItem(value: '10+', child: Text('10+ years')),
                ],
                onChanged: (val) {
                  setState(() {
                    _filterAgeRange = val ?? 'All';
                    _applyFilters();
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            
            // Date Registered Filter - Replaced with date pickers
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Registered Date",
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

// Export Options Dialog
void _showExportOptions() async {
  String exportFormat = 'Excel';
  
  await showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text("Export Patient Data"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Choose export format:"),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: exportFormat,
                  items: const [
                    DropdownMenuItem(value: 'Excel', child: Text('Excel (.xlsx)')),
                    DropdownMenuItem(value: 'CSV', child: Text('CSV (.csv)')),
                    DropdownMenuItem(value: 'PDF', child: Text('PDF (.pdf)')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      exportFormat = value ?? 'Excel';
                    });
                  },
                  decoration: const InputDecoration(
                    labelText: 'Format',
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Note: Export will include current filters and timestamp"),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Cancel"),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _exportData(exportFormat);
                },
                child: const Text("Export"),
              ),
            ],
          );
        },
      );
    },
  );
}

// Export Data
Future<void> _exportData(String format) async {
  try {
    setState(() => isLoading = true);

    // Fetch all patients (or apply filters if needed)
    final patientsToExport = await PatientsService.getPatients();

    // Prepare data for export
    final List<List<String>> rows = [];
    rows.add([
      'ID',
      'Child Name',
      'Mother Name',
      'Father Name',
      'Date of Birth',
      'Place of Birth',
      'Birth Weight',
      'Birth Height',
      'Sex',
      'Address',
      'Record Type',
      'Service Type',
      'Record Description',
      'Family Serial Number',
      'Contact Number',
      'Spouse Name',
      'Living Children Count',
      'Monthly Income',
      'Religion',
      'City',
      'Province',
      'Age',
      'Education',
      'Occupation',
      'Birth Attendant',
      'Facility Type',
      'Health Center',
      'Barangay',
      'Family Number',
    ]);

    for (final patient in patientsToExport) {
      rows.add([
        patient['id'] ?? '',
        patient['childName'] ?? '',
        patient['motherName'] ?? '',
        patient['fatherName'] ?? '',
        patient['dob'] ?? '',
        patient['placeOfBirth'] ?? '',
        patient['birthWeight'] ?? '',
        patient['birthHeight'] ?? '',
        patient['sex'] ?? '',
        patient['address'] ?? '',
        patient['recordType'] ?? '',
        patient['serviceType'] ?? '',
        patient['recordDescription'] ?? '',
        patient['familySerialNumber'] ?? '',
        patient['contactNumber'] ?? '',
        patient['spouseName'] ?? '',
        patient['livingChildrenCount'] ?? '',
        patient['monthlyIncome'] ?? '',
        patient['religion'] ?? '',
        patient['city'] ?? '',
        patient['province'] ?? '',
        patient['age'] ?? '',
        patient['education'] ?? '',
        patient['occupation'] ?? '',
        patient['birthAttendant'] ?? '',
        patient['facilityType'] ?? '',
        patient['healthCenter'] ?? '',
        patient['barangay'] ?? '',
        patient['familyNumber'] ?? '',
      ]);
    }

    // Generate file name with timestamp
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').replaceAll('.', '-');
    final fileName = 'patients_$timestamp.$format';

    try {
      // Export to Excel
      if (format == 'Excel') {
        final filePath = await _exportToExcel(rows, fileName);
        if (mounted) {
          MessageUtils.showSuccessMessage(
            context,
            "Patient data exported successfully to $fileName",
            title: "Export Success",
          );
        }
      }
      // Export to CSV
      else if (format == 'CSV') {
        final csv = ListToCsvConverter().convert(rows);
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsString(csv);
        if (mounted) {
          MessageUtils.showSuccessMessage(
            context,
            "Patient data exported successfully to $fileName",
            title: "Export Success",
          );
        }
      }
      // Export to PDF
      else if (format == 'PDF') {
        final pdf = pw.Document();
        pdf.addPage(
          pw.Page(
            build: (pw.Context context) {
              return pw.Table.fromTextArray(
                data: rows,
                border: pw.TableBorder.all(),
                cellPadding: const pw.EdgeInsets.all(8),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              );
            },
          ),
        );
        final bytes = await pdf.save();
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(bytes);
        if (mounted) {
          MessageUtils.showSuccessMessage(
            context,
            "Patient data exported successfully to $fileName",
            title: "Export Success",
          );
        }
      }
    } on MissingPluginException catch (e) {
      // Handle MissingPluginException specifically
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Export functionality is not available on this platform.\n\nError: $e',
          title: "Export Not Supported",
        );
      }
    } catch (pathError) {
      // Handle other path_provider errors
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          'Error accessing storage: $pathError\n\nPlease ensure the app has proper storage permissions.',
          title: "Export Error",
        );
      }
    }

    setState(() => isLoading = false);
  } catch (e) {
    setState(() => isLoading = false);
    if (mounted) {
      MessageUtils.showErrorMessage(
        context,
        'Error exporting patient data: $e',
        title: "Export Error",
      );
    }
  }
}

// Export to Excel
Future<String> _exportToExcel(List<List<dynamic>> rows, String fileName) async {
  try {
    // Create Excel file
    var excel = xl.Excel.createExcel();
    var sheet = excel['Sheet1'];
    
    // Add data to sheet
    for (int i = 0; i < rows.length; i++) {
      sheet.appendRow(rows[i]);
    }
    
    // Save file
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(excel.save()!);
    
    return file.path;
  } on MissingPluginException {
    // Handle MissingPluginException specifically
    throw Exception('Export to Excel is not supported on this platform');
  } catch (e) {
    // Handle other errors
    throw Exception('Error exporting to Excel: $e');
  }
}

// Apply Filters — server-side; reset to page 1 and reload
void _applyFilters() {
  setState(() {
    _currentPage = 1;
  });
  _loadPatients();
}

// Check Age Range
bool _checkAgeRange(String? dob) {
  if (dob == null || dob.isEmpty) return true;

  final dobDate = DateTime.tryParse(dob);
  if (dobDate == null) return true;

  final now = DateTime.now();
  final age = now.year - dobDate.year;

  if (_filterAgeRange == '0-1') return age >= 0 && age <= 1;
  if (_filterAgeRange == '1-5') return age >= 1 && age <= 5;
  if (_filterAgeRange == '5-10') return age >= 5 && age <= 10;
  if (_filterAgeRange == '10+') return age >= 10;

  return true;
}

// Check Date Registered with Date Range
bool _checkDateRegisteredRange(String? createdAt) {
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
    final patientDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
    matchesStartDate = patientDate.isAtSameMomentAs(startDate) || patientDate.isAfter(startDate);
  }
  
  if (_filterEndDate != null) {
    // Compare dates (ignoring time) by creating DateTime objects with time set to 23:59:59
    final endDate = DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day, 23, 59, 59);
    final patientDate = DateTime(createdDate.year, createdDate.month, createdDate.day);
    matchesEndDate = patientDate.isAtSameMomentAs(DateTime(_filterEndDate!.year, _filterEndDate!.month, _filterEndDate!.day)) || patientDate.isBefore(endDate);
  }
  
  return matchesStartDate && matchesEndDate;
}

// Get Next Appointment
Future<Map<String, dynamic>?> _getNextAppointment() async {
  try {
    // Fetch upcoming appointments
    final appointments = await AppointmentService.getUpcomingAppointments();
    if (appointments.isNotEmpty) {
      // Return the first (next) appointment
      return appointments.first;
    }
    return null;
  } catch (e) {
    print('Error fetching next appointment: $e');
    return null;
  }
}

// Send Reminder
void _sendReminder(Map<String, dynamic> appointment) async {
  try {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

      // Get patient ID from appointment - using the correct field name from backend
    final patientId = appointment['patient_id']?.toString() ?? appointment['patientId']?.toString();
    
    if (patientId == null || patientId.isEmpty) {
      // Close loading indicator
      Navigator.pop(context);
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          "Patient ID not found in appointment data",
          title: "Send Reminder Error",
        );
      }
      return;
    }

    // First check if patient has a valid FCM token
    final tokenCheckResult = await FCMNotificationService.checkPatientFCMToken(
      patientId: patientId,
    );

    // If the token check failed, show the error and stop
    if (!tokenCheckResult['success']) {
      // Close loading indicator
      Navigator.pop(context);
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          tokenCheckResult['message'] ?? "Failed to verify patient's notification status",
          title: "Verification Error",
        );
      }
      return;
    }

    // If patient doesn't have a valid FCM token, show a specific message
    if (!tokenCheckResult['hasValidToken']) {
      // Close loading indicator
      Navigator.pop(context);
      
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          "Patient's mobile app is not properly registered for notifications.\n\nTo fix this issue:\n1. Ensure the patient has installed the HealthTrack mobile app\n2. The patient must log in to the app at least once\n3. The app must have internet connectivity to register with our notification service",
          title: "Patient App Not Registered",
        );
      }
      return;
    }

    // Extract appointment details with proper fallbacks and formatting
    final appointmentDateRaw = appointment['appointment_date'] ?? appointment['appointmentDate'] ?? '';
    final appointmentTimeRaw = appointment['appointment_time'] ?? appointment['appointmentTime'] ?? '';
    final doctorName = appointment['doctor_name'] ?? appointment['doctorName'] ?? 'Unknown Doctor';
    
    final appointmentDateString = appointmentDateRaw?.toString() ?? '';
    final appointmentTimeString = appointmentTimeRaw?.toString() ?? '';
    final formattedSchedule = TimeUtils.formatAppointmentUtcDateTime(
      appointmentDateString,
      appointmentTimeString,
      pattern: 'MMMM dd, yyyy hh:mm a',
    );

    // Construct the message with centralized Manila timezone formatting
    final message = "You have an appointment on $formattedSchedule with Dr. $doctorName";

    // Send appointment reminder notification
    final result = await FCMNotificationService.sendAppointmentReminder(
      patientId: patientId,
      title: "Appointment Reminder",
      message: message,
    );

    // Close loading indicator
    Navigator.pop(context);

    if (result['success'] == true) {
      if (mounted) {
        MessageUtils.showSuccessMessage(
          context,
          result['message'] ?? "Reminder sent successfully to patient's mobile device",
          title: "Reminder Sent",
        );
      }
    } else {
      if (mounted) {
        MessageUtils.showErrorMessage(
          context,
          result['message'] ?? "Failed to send reminder. Please try again.",
          title: "Send Reminder Failed",
        );
      }
    }
  } catch (e) {
    // Close loading indicator
    Navigator.pop(context);
    
    if (mounted) {
      MessageUtils.showErrorMessage(
        context,
        "Failed to send reminder. Please check your internet connection and try again.",
        title: "Network Error",
      );
    }
  }
}

// View Appointment Details
void _viewAppointmentDetails(Map<String, dynamic> appointment) {
  final scheduleDisplay = TimeUtils.formatAppointmentUtcDateTime(
    (appointment['appointment_date'] ?? '').toString(),
    (appointment['appointment_time'] ?? '').toString(),
    pattern: 'MMMM dd, yyyy hh:mm a',
  );
  // Show appointment details in a dialog
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text("Appointment Details"),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Patient: ${appointment['patient_full_name'] ?? appointment['patient_name'] ?? 'Unknown Patient'}"),
              Text("Doctor: ${appointment['doctor_name'] ?? 'Unknown Doctor'}"),
              Text("Clinic: ${appointment['clinic_hospital'] ?? 'Unknown Clinic'}"),
              Text("Schedule: $scheduleDisplay"),
              Text("Type: ${appointment['appointment_type'] ?? 'General'}"),
              if (appointment['notes'] != null && appointment['notes'].toString().isNotEmpty)
                Text("Notes: ${appointment['notes']}"),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Close"),
          ),
        ],
      );
    },
  );
}

  // Format service type for display
  String _formatServiceType(String? serviceType) {
    if (serviceType == null) return 'Unknown';
    
    // Normalize the service type for display
    String normalizedServiceType = serviceType.toLowerCase().trim();
    
    switch (normalizedServiceType) {
      case 'immunization':
      case 'immunization care':
        return 'Immunization';
      case 'maternal':
      case 'maternal care':
      case 'maternalcare':
        return 'Maternal Care';
      default:
        // Return a default display value for unrecognized types
        return 'Immunization'; // Default to Immunization for unrecognized types
    }
  }
}

class _HoverPatientCard extends StatefulWidget {
  const _HoverPatientCard({required this.child});

  final Widget child;

  @override
  State<_HoverPatientCard> createState() => _HoverPatientCardState();
}

class _HoverPatientCardState extends State<_HoverPatientCard> {
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