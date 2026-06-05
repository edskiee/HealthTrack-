import 'package:flutter/material.dart';
import 'utils/message_utils.dart';
import 'services/registration_service.dart';
import 'package:intl/intl.dart';
import 'login_screen.dart';
import 'services/service_config_service.dart';

class UnifiedRegisterScreen extends StatefulWidget {
  const UnifiedRegisterScreen({super.key});

  @override
  State<UnifiedRegisterScreen> createState() => _UnifiedRegisterScreenState();
}

class _UnifiedRegisterScreenState extends State<UnifiedRegisterScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  // Service type selection
  String _selectedServiceType = 'immunization';
  List<Map<String, dynamic>> _availableServices = [];
  bool _isLoadingServices = false;
  String? _servicesErrorMessage;

  // Controllers for all fields
  // General fields (visible for all service types)
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _contactNumber = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  // Maternal Care specific fields
  final TextEditingController _motherDob = TextEditingController();
  final TextEditingController _age = TextEditingController();
  String _civilStatus = "Married"; // Default status
  final TextEditingController _religion = TextEditingController();
  final TextEditingController _education = TextEditingController();
  final TextEditingController _occupation = TextEditingController();
  
  // Spouse/Pregnancy Information (conditionally shown)
  final TextEditingController _spouseName = TextEditingController();
  final TextEditingController _spouseDob = TextEditingController();
  final TextEditingController _spouseEducation = TextEditingController();
  final TextEditingController _spouseOccupation = TextEditingController();
  final TextEditingController _monthlyIncome = TextEditingController();
  final TextEditingController _livingChildrenCount = TextEditingController();
  String _birthPlan = "Hospital"; // Default birth plan
  String _birthAttendant = "SBA"; // Default birth attendant
  bool _showBirthAttendant = false; // Show birth attendant only if "Home" is selected
  
  // Immunization Information (conditionally shown)
  final TextEditingController _childName = TextEditingController();
  final TextEditingController _childDob = TextEditingController();
  final TextEditingController _placeOfBirth = TextEditingController();
  final TextEditingController _birthWeight = TextEditingController();
  final TextEditingController _birthHeight = TextEditingController();
  String _childSex = "Male"; // Default sex
  final TextEditingController _healthCenter = TextEditingController();
  final TextEditingController _barangay = TextEditingController();
  final TextEditingController _familyNumber = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _controller.forward();
    
    // Load available services
    _loadAvailableServices();
  }

  Future<void> _loadAvailableServices() async {
    try {
      print('🔄 Starting to load available services...');
      setState(() {
        _isLoadingServices = true;
        _servicesErrorMessage = null;
      });
      
      // Only load immunization and maternal care services
      // Load both service types separately to ensure proper filtering
      print('📥 Loading immunization services...');
      final immunizationServices = await ServiceConfigService.getAllServices(serviceType: 'immunization');
      print('✅ Loaded ${immunizationServices.length} immunization services');
      
      print('📥 Loading maternal services...');
      final maternalServices = await ServiceConfigService.getAllServices(serviceType: 'maternal');
      print('✅ Loaded ${maternalServices.length} maternal services');
      
      // Combine and filter only enabled services
      // Accept both is_enabled and is_active (handles DB column naming differences)
      print('🔧 Filtering enabled services...');
      final enabledServices = [...immunizationServices, ...maternalServices]
          .where((service) =>
              service['is_enabled'] == 1 ||
              service['is_enabled'] == true ||
              service['is_active'] == 1 ||
              service['is_active'] == true)
          .toList();
      print('✅ Found ${enabledServices.length} enabled services');
      
      setState(() {
        _availableServices = enabledServices;
        _isLoadingServices = false;
        
        print('📊 Available services updated. Count: ${_availableServices.length}');
        print('📝 Services: ${_availableServices.map((s) => s['service_name']).join(', ')}');
        
        // Set default service if none selected or if selected service is not available
        if (_selectedServiceType.isEmpty || 
            !_availableServices.any((service) => service['service_type'] == _selectedServiceType)) {
          if (_availableServices.isNotEmpty) {
            _selectedServiceType = _availableServices.first['service_type'];
            print('📌 Default service type set to: $_selectedServiceType');
          }
        }
      });
    } catch (e, stackTrace) {
      setState(() {
        _servicesErrorMessage = e.toString();
        _isLoadingServices = false;
      });
      
      print('❌ Error loading services: $e');
      print('📄 Stack trace: $stackTrace');
    }
  }

  void _registerUser() async {
    // Validate all fields before proceeding
    if (!_formKey.currentState!.validate()) {
      MessageUtils.showErrorMessage(
          context, "Please fill in all required fields correctly.");
      return;
    }
    
    // Additional validation for maternal care service based on civil status
    if (_selectedServiceType == 'maternal') {
      // Validate basic required fields for all maternal registrations
      if (_fullName.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Mother's full name is required.");
        return;
      }
      
      if (_motherDob.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Mother's date of birth is required.");
        return;
      }
      
      if (_age.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Age is required.");
        return;
      }
      
      if (_education.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Education is required.");
        return;
      }
      
      if (_occupation.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Occupation is required.");
        return;
      }
      
      if (_address.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Address is required.");
        return;
      }
      
      if (_contactNumber.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Contact number is required.");
        return;
      }

      // For married/widowed/separated statuses, pregnancy information is required
      if (_civilStatus != "Single") {
        if (_spouseName.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Spouse's name is required for selected civil status.");
          return;
        }
        
        if (_spouseDob.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Spouse's date of birth is required for selected civil status.");
          return;
        }
        
        if (_spouseEducation.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Spouse's education is required for selected civil status.");
          return;
        }
        
        if (_spouseOccupation.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Spouse's occupation is required for selected civil status.");
          return;
        }
        
        if (_monthlyIncome.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Monthly income is required for selected civil status.");
          return;
        }
        
        if (_livingChildrenCount.text.trim().isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Number of living children is required for selected civil status.");
          return;
        }
        
        if (_birthPlan.isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Birth plan is required.");
          return;
        }
        
        // Birth attendant is only required if "Home" is selected as birth plan
        if (_birthPlan == "Home" && _birthAttendant.isEmpty) {
          MessageUtils.showErrorMessage(
              context, "Birth attendant type is required when birth plan is Home.");
          return;
        }
      }
      // For "Single" status, pregnancy information is not required, so we skip those validations
    }
    // Additional validation for immunization service
    else if (_selectedServiceType != 'maternal') {
      if (_childName.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Child's name is required for immunization service.");
        return;
      }
      
      if (_childDob.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Child's date of birth is required for immunization service.");
        return;
      }
      
      if (_placeOfBirth.text.trim().isEmpty) {
        MessageUtils.showErrorMessage(
            context, "Place of birth is required for immunization service.");
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Convert date to MySQL format (YYYY-MM-DD)
      String formattedMotherDob = _formatDateForDatabase(_motherDob.text.trim());
      if (formattedMotherDob.isEmpty && _selectedServiceType == 'maternal') {
        MessageUtils.showErrorMessage(
            context, "Invalid date format. Please select a valid date.");
        return;
      }

      // Prepare registration data with null safety
      final registrationData = {
        // User account info
        'username': _username.text.trim(),
        'password': _password.text.trim(),
        'email': _email.text.trim().isEmpty
            ? '${_username.text.trim()}@healthtrack.local'
            : _email.text.trim(),
        'role': 'user',
        'serviceType': _selectedServiceType,
        'full_name': _fullName.text.trim(),
        'phone': _contactNumber.text.trim(),
        'address': _address.text.trim(),

        // For maternal care, use maternal-specific fields
        'motherName': _fullName.text.trim(),
        'dob': formattedMotherDob,
        'age': _age.text.trim().isEmpty ? "0" : _age.text.trim(),
        'education': _education.text.trim(),
        'occupation': _occupation.text.trim(),
        'status': _civilStatus,
        'religion': _religion.text.trim(),
        'contact': _contactNumber.text.trim(),
        'sex': 'Female', // Maternal care is always for females
        
        // Map spouse fields to father fields for backend compatibility
        'fatherName': _spouseName.text.trim(),
        'placeOfBirth': '', // Not used in maternal care
        'birthWeight': '', // Not used in maternal care
        'birthHeight': '', // Not used in maternal care
        
        // Spouse/Pregnancy Information (conditionally included)
        'spouseName': _spouseName.text.trim(),
        'spouseDob': _spouseDob.text.trim(),
        'spouseEducation': _spouseEducation.text.trim(),
        'spouseOccupation': _spouseOccupation.text.trim(),
        'monthlyIncome': _monthlyIncome.text.trim().isEmpty
            ? "0"
            : _monthlyIncome.text.trim(),
        'livingChildrenCount': _livingChildrenCount.text.trim().isEmpty
            ? "0"
            : _livingChildrenCount.text.trim(),
        'birthPlan': _birthPlan,
        'birthAttendant': _birthAttendant,
        'facilityType': _birthPlan,

        'recordType': _selectedServiceType == 'maternal'
            ? 'Maternal Care'
            : 'Immunization',
        'recordDescription': _selectedServiceType == 'maternal'
            ? 'Maternal care patient record'
            : 'Immunization patient record',
      };

      // Add immunization-specific fields if needed
      if (_selectedServiceType != 'maternal') {
        registrationData.addAll({
          'childName': _childName.text.trim(),
          'placeOfBirth': _placeOfBirth.text.trim(),
          'birthWeight': _birthWeight.text.trim(),
          'birthHeight': _birthHeight.text.trim(),
          'sex': _childSex,
          'healthCenter': _healthCenter.text.trim(),
          'barangay': _barangay.text.trim(),
          'familyNumber': _familyNumber.text.trim(),
        });
      }

      print('📤 Final registration data being sent:');
      registrationData.forEach((key, value) => print('  $key: $value'));

      // Call registration service
      final result =
          await RegistrationService.registerUserWithChild(registrationData);

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      // Handle success field with robust type checking
      bool isSuccess = false;
      if (result['success'] is bool) {
        isSuccess = result['success'];
      } else if (result['success'] is String) {
        isSuccess = result['success'].toLowerCase() == 'true';
      } else if (result['success'] is int) {
        isSuccess = result['success'] == 1;
      }

      if (isSuccess) {
        // Send welcome notification to newly registered patient
        try {
          final userData = result['data']?['user'];
          final patientData = result['data']?['patient'];

          if (userData != null && patientData != null) {
            final userId = userData['id']?.toString() ?? '';
            final patientId = patientData['id']?.toString() ?? '';
            final patientName = patientData['child_fullname']?.toString() ??
                patientData['mother_fullname']?.toString() ??
                'Patient';
            final serviceType =
                userData['service_type']?.toString() ?? 'immunization';

            // Welcome notification functionality has been moved to automated system
          }
        } catch (notificationSetupError) {
          print('⚠️ Error setting up welcome notification: $notificationSetupError');
        }

        if (mounted) {
          MessageUtils.showSuccessMessage(
            context,
            "Registration successful! You can now sign in with your new account.",
            title: "Registration Successful",
          );

          // Navigate to login screen immediately
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LoginScreen(),
            ),
          );
        }
      } else {
        if (mounted) {
          String errorMessage =
              result['message']?.toString() ?? "Registration failed. Please try again.";
          MessageUtils.showErrorMessage(
            context,
            errorMessage,
            title: "Registration Failed",
          );
        }
      }
    } catch (e, stackTrace) {
      // Hide loading
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        MessageUtils.showErrorMessage(
          context,
          "Failed to create account: $e\n\n$stackTrace",
          title: "Registration Error",
        );
      }
    }
  }

  // Format date from user input to MySQL format (YYYY-MM-DD)
  String _formatDateForDatabase(String inputDate) {
    try {
      if (inputDate.isEmpty) return '';

      // Try different date formats
      DateTime? date;

      // Try MM/DD/YYYY format first
      if (inputDate.contains('/')) {
        List<String> parts = inputDate.split('/');
        if (parts.length == 3) {
          int month = int.parse(parts[0]);
          int day = int.parse(parts[1]);
          int year = int.parse(parts[2]);
          date = DateTime(year, month, day);
        }
      }
      // Try YYYY-MM-DD format (already correct)
      else if (inputDate.contains('-')) {
        date = DateFormat('yyyy-MM-dd').parse(inputDate);
      }

      if (date != null) {
        return DateFormat('yyyy-MM-dd').format(date);
      }
    } catch (e) {
      print('Date parsing error: $e');
    }
    return inputDate; // Return as-is if parsing fails
  }

  // Show date picker
  Future<void> _selectMotherDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _motherDob.text = DateFormat('MM/dd/yyyy').format(picked);
        // Calculate age automatically
        final now = DateTime.now();
        final age = now.year - picked.year;
        _age.text = age.toString();
      });
    }
  }

  // Show spouse date picker
  Future<void> _selectSpouseDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      helpText: 'Select Spouse\'s Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _spouseDob.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // Show child date picker
  Future<void> _selectChildDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 5)),
      firstDate: DateTime(2010),
      lastDate: DateTime.now(),
      helpText: 'Select Child\'s Date of Birth',
    );
    if (picked != null) {
      setState(() {
        _childDob.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  InputDecoration _inputDecoration(String label, {bool required = false}) {
    return InputDecoration(
      labelText: required ? "$label *" : label,
      filled: true,
      fillColor: Colors.grey.shade100,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(30),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🔹 Background
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bluebackground.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(color: Colors.black.withOpacity(0.2)),

          // 🔹 Title and Back Icon
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  const SizedBox(width: 10),
                  const Text(
                    "Sign Up",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Color.fromARGB(255, 255, 255, 255),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 🔹 Sliding White Card (mas mataas na)
          SlideTransition(
            position: _slideAnimation,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                padding: const EdgeInsets.all(24),
                height: MediaQuery.of(context).size.height * 0.85,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      const Text(
                        "Unified Registration",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Fill in the details below to create your account",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Service Type Selection Dropdown
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Select Service Type",
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _isLoadingServices
                              ? const Column(
                                  children: [
                                    CircularProgressIndicator(),
                                    SizedBox(height: 10),
                                    Text("Loading services..."),
                                  ],
                                )
                              : _servicesErrorMessage != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Failed to load services",
                                        style: TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        _servicesErrorMessage!,
                                        style: const TextStyle(color: Colors.red, fontSize: 12),
                                      ),
                                      TextButton(
                                        onPressed: _loadAvailableServices,
                                        child: const Text("Retry"),
                                      ),
                                    ],
                                  )
                                : _availableServices.isEmpty
                                  ? Column(
                                      children: [
                                        const Text("No services available", style: TextStyle(color: Colors.orange)),
                                        const SizedBox(height: 10),
                                        TextButton(
                                          onPressed: _loadAvailableServices,
                                          child: const Text("Retry"),
                                        ),
                                      ],
                                    )
                                  : DropdownButtonFormField<String>(
                                      value: _selectedServiceType,
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                      ),
                                      items: _availableServices.map<DropdownMenuItem<String>>((service) {
                                        IconData icon;
                                        Color color;
                                        
                                        // Determine icon and color based on service type
                                        switch (service['service_type']) {
                                          case 'maternal':
                                            icon = Icons.pregnant_woman;
                                            color = Colors.pink;
                                            break;
                                          case 'immunization':
                                            icon = Icons.vaccines;
                                            color = Colors.green;
                                            break;
                                          case 'dental':
                                            icon = Icons.local_hospital;
                                            color = Colors.blue;
                                            break;
                                          case 'epi':
                                            icon = Icons.medical_services;
                                            color = Colors.orange;
                                            break;
                                          case 'checkup':
                                            icon = Icons.health_and_safety;
                                            color = Colors.teal;
                                            break;
                                          default:
                                            icon = Icons.medical_services;
                                            color = Colors.blue;
                                        }
                                        
                                        return DropdownMenuItem<String>(
                                          value: service['service_type'],
                                          child: Row(
                                            children: [
                                              Icon(icon, color: color),
                                              const SizedBox(width: 8),
                                              Text(service['service_name']),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedServiceType = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return "Please select a service type";
                                        }
                                        return null;
                                      },
                                    ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Steps Content - Wrapped in SingleChildScrollView to prevent overflow
                      Expanded(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // General Information Section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "General Information",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _fullName,
                                      decoration:
                                          _inputDecoration("Mother's Full Name", required: true),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Full name is required";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Date of Birth with Age Calculation
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            controller: _motherDob,
                                            decoration: _inputDecoration("Date of Birth", required: true),
                                            validator: (value) {
                                              if (_selectedServiceType == 'maternal' && 
                                                  (value == null || value.trim().isEmpty)) {
                                                return "Date of birth is required";
                                              }
                                              return null;
                                            },
                                            onTap: () => _selectMotherDate(context),
                                            readOnly: true,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Expanded(
                                          child: TextFormField(
                                            controller: _age,
                                            decoration: _inputDecoration("Age (auto-calculated)", required: true),
                                            keyboardType: TextInputType.number,
                                            enabled: false, // Auto-calculated, so disabled
                                            validator: (value) {
                                              if (_selectedServiceType == 'maternal' && 
                                                  (value == null || value.trim().isEmpty)) {
                                                return "Age is required";
                                              }
                                              return null;
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    // Occupation Status
                                    Padding(
                                      padding: const EdgeInsets.symmetric(vertical: 8),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text("Occupation Status *", style: TextStyle(fontWeight: FontWeight.w500)),
                                          const SizedBox(height: 8),
                                          DropdownButtonFormField<String>(
                                            value: _civilStatus,
                                            decoration: _inputDecoration("Civil Status"),
                                            items: const [
                                              DropdownMenuItem(value: "Single", child: Text("Single")),
                                              DropdownMenuItem(value: "Married", child: Text("Married")),
                                              DropdownMenuItem(value: "Widowed", child: Text("Widowed")),
                                              DropdownMenuItem(value: "Separated", child: Text("Separated")),
                                            ],
                                            onChanged: (value) {
                                              if (value != null) {
                                                setState(() {
                                                  _civilStatus = value;
                                                });
                                              }
                                            },
                                            validator: (value) {
                                              if (_selectedServiceType == 'maternal' && 
                                                  (value == null || value.isEmpty)) {
                                                return "Civil status is required";
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    TextFormField(
                                      controller: _occupation,
                                      decoration: _inputDecoration("Occupation", required: true),
                                      validator: (value) {
                                        if (_selectedServiceType == 'maternal' && 
                                            (value == null || value.trim().isEmpty)) {
                                          return "Occupation is required";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: _religion,
                                      decoration: _inputDecoration("Religion"),
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: _address,
                                      decoration: _inputDecoration("Address", required: true),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Address is required";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: _contactNumber,
                                      decoration: _inputDecoration("Contact Number", required: true),
                                      keyboardType: TextInputType.phone,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Contact number is required";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    
                                    TextFormField(
                                      controller: _email,
                                      decoration: _inputDecoration("Email Address"),
                                      keyboardType: TextInputType.emailAddress,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 20),

                              // Pregnancy Information Section (conditionally shown for maternal care)
                              if (_selectedServiceType == 'maternal' && _civilStatus != "Single")
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.pink.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Pregnancy Information",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.pink,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _spouseName,
                                        decoration: _inputDecoration("Spouse's Full Name", required: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Spouse's name is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _spouseDob,
                                        decoration: _inputDecoration("Spouse's Date of Birth", required: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Spouse's date of birth is required";
                                          }
                                          return null;
                                        },
                                        onTap: () => _selectSpouseDate(context),
                                        readOnly: true,
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _spouseEducation,
                                        decoration: _inputDecoration("Spouse's Highest Education", required: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Spouse's education is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _spouseOccupation,
                                        decoration: _inputDecoration("Spouse's Occupation", required: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Spouse's occupation is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _monthlyIncome,
                                        decoration: _inputDecoration("Average Family Income", required: true),
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Monthly income is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _livingChildrenCount,
                                        decoration: _inputDecoration("Number of Living Children", required: true),
                                        keyboardType: TextInputType.number,
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Number of living children is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Birth Plan Selection
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Birth Plan *", style: TextStyle(fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _birthPlan,
                                              decoration: _inputDecoration("Preferred Birth Location"),
                                              items: const [
                                                DropdownMenuItem(value: "Hospital", child: Text("Hospital")),
                                                DropdownMenuItem(value: "Birthing Center", child: Text("Birthing Center")),
                                                DropdownMenuItem(value: "RHU", child: Text("RHU (Rural Health Unit)")),
                                                DropdownMenuItem(value: "Home", child: Text("Home")),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _birthPlan = value;
                                                    // Show birth attendant field only if "Home" is selected
                                                    _showBirthAttendant = value == "Home";
                                                  });
                                                }
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return "Birth plan is required";
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Birth Attendant Selection (only shown if "Home" is selected)
                                      if (_showBirthAttendant)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 8),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              const Text("Birth Attendant Type *", style: TextStyle(fontWeight: FontWeight.w500)),
                                              const SizedBox(height: 8),
                                              DropdownButtonFormField<String>(
                                                value: _birthAttendant,
                                                decoration: _inputDecoration("Birth Attendant"),
                                                items: const [
                                                  DropdownMenuItem(value: "SBA", child: Text("SBA")),
                                                  DropdownMenuItem(value: "Non-SBA", child: Text("Non-SBA")),
                                                ],
                                                onChanged: (value) {
                                                  if (value != null) {
                                                    setState(() {
                                                      _birthAttendant = value;
                                                    });
                                                  }
                                                },
                                                validator: (value) {
                                                  if (_showBirthAttendant &&
                                                      (value == null || value.isEmpty)) {
                                                    return "Birth attendant type is required";
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                              // Immunization Information Section (conditionally shown for immunization service)
                              if (_selectedServiceType != 'maternal')
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.shade50,
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        "Immunization Information",
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _childName,
                                        decoration: _inputDecoration("Child's Name", required: true),
                                        validator: (value) {
                                          if (value == null || value.trim().isEmpty) {
                                            return "Child's name is required";
                                          }
                                          return null;
                                        },
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Date of Birth with Place of Birth
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _childDob,
                                              decoration: _inputDecoration("Child's Date of Birth", required: true),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return "Child's date of birth is required";
                                                }
                                                return null;
                                              },
                                              onTap: () => _selectChildDate(context),
                                              readOnly: true,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _placeOfBirth,
                                              decoration: _inputDecoration("Place of Birth", required: true),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return "Place of birth is required";
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Birth Weight and Height
                                      Row(
                                        children: [
                                          Expanded(
                                            child: TextFormField(
                                              controller: _birthWeight,
                                              decoration: _inputDecoration("Birth Weight (kg)", required: true),
                                              keyboardType: TextInputType.numberWithOptions(decimal: true),
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return "Birth weight is required";
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: TextFormField(
                                              controller: _birthHeight,
                                              decoration: _inputDecoration("Birth Height (cm)", required: true),
                                              keyboardType: TextInputType.number,
                                              validator: (value) {
                                                if (value == null || value.trim().isEmpty) {
                                                  return "Birth height is required";
                                                }
                                                return null;
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      // Sex Selection
                                      Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text("Sex *", style: TextStyle(fontWeight: FontWeight.w500)),
                                            const SizedBox(height: 8),
                                            DropdownButtonFormField<String>(
                                              value: _childSex,
                                              decoration: _inputDecoration("Child's Sex"),
                                              items: const [
                                                DropdownMenuItem(value: "Male", child: Text("Male")),
                                                DropdownMenuItem(value: "Female", child: Text("Female")),
                                              ],
                                              onChanged: (value) {
                                                if (value != null) {
                                                  setState(() {
                                                    _childSex = value;
                                                  });
                                                }
                                              },
                                              validator: (value) {
                                                if (value == null || value.isEmpty) {
                                                  return "Child's sex is required";
                                                }
                                                return null;
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      TextFormField(
                                        controller: _healthCenter,
                                        decoration: _inputDecoration("Health Center"),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _barangay,
                                        decoration: _inputDecoration("Barangay"),
                                      ),
                                      const SizedBox(height: 16),
                                      
                                      TextFormField(
                                        controller: _familyNumber,
                                        decoration: _inputDecoration("Family Number"),
                                        keyboardType: TextInputType.number,
                                      ),
                                    ],
                                  ),
                                ),

                              // Account Setup Section
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(15),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      "Account Setup",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _username,
                                      decoration:
                                          _inputDecoration("Username", required: true),
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Username is required";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _password,
                                      decoration: InputDecoration(
                                        labelText: "Password *",
                                        filled: true,
                                        fillColor: Colors.grey.shade100,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(30),
                                          borderSide: BorderSide.none,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_off
                                                : Icons.visibility,
                                            color: Colors.grey,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _obscurePassword = !_obscurePassword;
                                            });
                                          },
                                        ),
                                      ),
                                      obscureText: _obscurePassword,
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return "Password is required";
                                        }
                                        if (value.length < 6) {
                                          return "Password must be at least 6 characters";
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 16),
                                    TextFormField(
                                      controller: _confirmPassword,
                                      decoration: _inputDecoration("Confirm Password"),
                                      obscureText: _obscurePassword,
                                      validator: (value) {
                                        if (value != _password.text) {
                                          return "Passwords do not match";
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // 🔹 Register Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () {
                                  _registerUser();
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0052D4),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: _isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text(
                                  "Register",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      // Have an account? Sign in
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Have an account? ",
                            style: TextStyle(color: Colors.black54),
                          ),
                          GestureDetector(
                            onTap: () {
                              // Navigate to login screen immediately
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => LoginScreen(),
                                ),
                              );
                            },
                            child: const Text(
                              "Sign in",
                              style: TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    // Dispose all controllers
    _fullName.dispose();
    _contactNumber.dispose();
    _email.dispose();
    _address.dispose();
    _motherDob.dispose();
    _age.dispose();
    _religion.dispose();
    _education.dispose();
    _occupation.dispose();
    _spouseName.dispose();
    _spouseDob.dispose();
    _spouseEducation.dispose();
    _spouseOccupation.dispose();
    _monthlyIncome.dispose();
    _livingChildrenCount.dispose();
    // Dispose immunization controllers
    _childName.dispose();
    _childDob.dispose();
    _placeOfBirth.dispose();
    _birthWeight.dispose();
    _birthHeight.dispose();
    _healthCenter.dispose();
    _barangay.dispose();
    _familyNumber.dispose();
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _controller.dispose();
    super.dispose();
  }
}