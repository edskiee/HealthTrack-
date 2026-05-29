import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart'; // Import the API config
import '../utils/message_utils.dart';
import 'admin_login_screen.dart';

class AdminRegisterScreen extends StatefulWidget {
  const AdminRegisterScreen({super.key});

  @override
  State<AdminRegisterScreen> createState() => _AdminRegisterScreenState();
}

class _AdminRegisterScreenState extends State<AdminRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _isLoading = false;
  bool _obscure1 = true;
  bool _obscure2 = true;

  @override
  void dispose() {
    _username.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_password.text.trim() != _confirmPassword.text.trim()) {
      MessageUtils.showErrorMessage(
        context,
        "Passwords do not match. Please confirm again.",
        title: "Validation Error",
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Debug information
      print("=== Admin Registration Debug Info ===");
      print("API Base URL: '${ApiConfig.baseUrl}'");
      print("API Base URL length: ${ApiConfig.baseUrl.length}");
      print("Is API Base URL empty: ${ApiConfig.baseUrl.isEmpty}");
      print("Admin Register Endpoint: '${ApiConfig.adminRegisterEndpoint}'");
      
      // Use the centralized API configuration with fallback mechanism
      String adminRegisterUrl = "${ApiConfig.baseUrl}${ApiConfig.adminRegisterEndpoint}";
      print("Constructed URL: '$adminRegisterUrl'");
      
      // Add validation for the URL
      if (ApiConfig.baseUrl.isEmpty) {
        print("ERROR: API Base URL is empty!");
        throw Exception("API Base URL is not configured properly");
      }
      
      // Validate that the URL is properly formed
      if (!adminRegisterUrl.startsWith('http')) {
        print("ERROR: Malformed URL: $adminRegisterUrl");
        throw Exception("Malformed URL: $adminRegisterUrl");
      }
      
      http.Response? response;
      
      try {
        final url = Uri.parse(adminRegisterUrl);
        response = await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "username": _username.text.trim(),
                "password": _password.text.trim(),
              }),
            )
            .timeout(const Duration(seconds: 10));
      } catch (e) {
        print("Failed with primary URL: $e");
        // If primary URL fails, try fallback URLs
        for (String fallbackUrl in ApiConfig.fallbackBaseUrls) {
          try {
            String fallbackAdminRegisterUrl = "$fallbackUrl${ApiConfig.adminRegisterEndpoint}";
            print("Trying fallback URL: $fallbackAdminRegisterUrl");
            
            // Validate fallback URL
            if (fallbackUrl.isEmpty) {
              print("Skipping empty fallback URL");
              continue;
            }
            
            // Validate that the URL is properly formed
            if (!fallbackAdminRegisterUrl.startsWith('http')) {
              print("Skipping malformed fallback URL: $fallbackAdminRegisterUrl");
              continue;
            }
            
            response = await http
                .post(
                  Uri.parse(fallbackAdminRegisterUrl),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "username": _username.text.trim(),
                    "password": _password.text.trim(),
                  }),
                )
                .timeout(const Duration(seconds: 10));
            
            print("Successfully connected to fallback URL: $fallbackAdminRegisterUrl");
            break; // Exit loop on successful connection
          } catch (fallbackError) {
            print("Failed with fallback URL $fallbackUrl: $fallbackError");
            continue; // Try next URL
          }
        }
      }

      if (response == null) throw Exception("Cannot connect to the server");
      
      // Print detailed response information
      print("=== Response Details ===");
      print("Status Code: ${response.statusCode}");
      print("Headers: ${response.headers}");
      print("Body: '${response.body}'");
      print("Body Length: ${response.body.length}");
      print("========================");

      // ✅ Handle empty or invalid response body
      if (response.body.isEmpty) {
        throw Exception("Server returned an empty response. Please try again.");
      }

      // ✅ Handle non-JSON responses
      if (!response.headers.containsKey('content-type') || 
          !response.headers['content-type']!.contains('application/json')) {
        throw Exception("Server returned an invalid response format. Please try again.");
      }

      // ✅ Safely parse JSON response
      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (parseError) {
        print("❌ JSON Parse Error: $parseError");
        print("❌ Response body: ${response.body}");
        print("❌ Response headers: ${response.headers}");
        throw Exception("Server returned an invalid JSON response. Please try again.");
      }

      bool isSuccess = false;

      if (data["success"] is bool) {
        isSuccess = data["success"];
      } else if (data["success"] is String) {
        isSuccess = data["success"].toLowerCase() == "true";
      } else if (data["success"] is int) {
        isSuccess = data["success"] == 1;
      }

      if (isSuccess) {
        if (!mounted) return;
        MessageUtils.showSuccessMessage(
          context,
          "Admin Registered Successfully!",
          title: "Registration Complete",
        );

        // Auto redirect to Login after success
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
            );
          }
        });
      } else {
        if (!mounted) return;
        MessageUtils.showErrorMessage(
          context,
          data["message"] ?? "Registration failed. Try again.",
          title: "Error",
        );
      }
    } catch (e) {
      if (!mounted) return;
      MessageUtils.showErrorMessage(
        context,
        "Error occurred: $e",
        title: "Network Error",
      );
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage("assets/images/adminbackground.png"),
            fit: BoxFit.cover,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // --- Header / Logo ---
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/logo.png',
                        height: 150,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'HealthTrack',
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Secure Healthcare Management System',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 24),

                  // --- Registration Form Card ---
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: width < 600 ? 460 : 520,
                    ),
                    child: Card(
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Admin Registration',
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: const Color(0xFF2196F3),
                                    ),
                              ),
                              const SizedBox(height: 18),

                              // Username Field
                              TextFormField(
                                controller: _username,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'Username',
                                  prefixIcon: const Icon(Icons.person),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Enter username'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Password Field
                              TextFormField(
                                controller: _password,
                                obscureText: _obscure1,
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() {
                                      _obscure1 = !_obscure1;
                                    }),
                                    icon: Icon(
                                      _obscure1
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Enter password'
                                    : null,
                              ),
                              const SizedBox(height: 12),

                              // Confirm Password
                              TextFormField(
                                controller: _confirmPassword,
                                obscureText: _obscure2,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    onPressed: () => setState(() {
                                      _obscure2 = !_obscure2;
                                    }),
                                    icon: Icon(
                                      _obscure2
                                          ? Icons.visibility_off
                                          : Icons.visibility,
                                    ),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? 'Confirm your password'
                                    : null,
                              ),
                              const SizedBox(height: 18),

                              // Register Button
                              SizedBox(
                                height: 48,
                                child: FilledButton(
                                  onPressed: _isLoading ? null : _registerAdmin,
                                  style: FilledButton.styleFrom(
                                    backgroundColor:
                                        const Color.fromARGB(255, 0, 67, 200),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.6,
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                    Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Register',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Back to Login Button
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => const AdminLoginScreen(),
                                    ),
                                  );
                                },
                                child: const Text(
                                  "Back to Login",
                                  style: TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Footer
                  Text(
                    'Preventive Healthcare Management System © 2025',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: Colors.white70,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secure • Reliable • Professional',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Colors.white54,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}