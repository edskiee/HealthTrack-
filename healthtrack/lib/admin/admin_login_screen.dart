import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart'; // Import the API config
import 'admin_dashboard_screen.dart';
import '../utils/message_utils.dart';
import 'services/admin_session_storage.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _totp = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;
  bool _awaitingTotp = false;

  @override
  void initState() {
    super.initState();
    _username.addListener(_resetTotpRequirement);
    _password.addListener(_resetTotpRequirement);
  }

  void _resetTotpRequirement() {
    if (!_awaitingTotp) return;
    setState(() {
      _awaitingTotp = false;
      _totp.clear();
    });
  }

  @override
  void dispose() {
    _username.removeListener(_resetTotpRequirement);
    _password.removeListener(_resetTotpRequirement);
    _username.dispose();
    _password.dispose();
    _totp.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // ✅ Try login via backend API using centralized configuration
    try {
      print("=== Admin Login Debug Info ===");
      print("API Base URL: '${ApiConfig.baseUrl}'");
      print("API Base URL length: ${ApiConfig.baseUrl.length}");
      print("Is API Base URL empty: ${ApiConfig.baseUrl.isEmpty}");
      print("Admin Login Endpoint: '${ApiConfig.adminLoginEndpoint}'");
      
      String adminLoginUrl = "${ApiConfig.baseUrl}${ApiConfig.adminLoginEndpoint}";
      print("Constructed URL: '$adminLoginUrl'");
      
      // Add validation for the URL
      if (ApiConfig.baseUrl.isEmpty) {
        print("ERROR: API Base URL is empty!");
        throw Exception("API Base URL is not configured properly");
      }
      
      // Validate that the URL is properly formed
      if (!adminLoginUrl.startsWith('http')) {
        print("ERROR: Malformed URL: $adminLoginUrl");
        throw Exception("Malformed URL: $adminLoginUrl");
      }
      
      http.Response? response;
      
      try {
        final url = Uri.parse(adminLoginUrl);
        print("🔗 Trying URL: $url");
        
        response = await http
            .post(
              url,
              headers: {"Content-Type": "application/json"},
              body: jsonEncode({
                "username": _username.text.trim(),
                "password": _password.text.trim(),
                if (_awaitingTotp || _totp.text.trim().isNotEmpty)
                  "totp": _totp.text.trim(),
              }),
            )
            .timeout(const Duration(seconds: 10)); // 10 second timeout
        
        print("✅ Successfully connected to: $adminLoginUrl");
      } catch (e) {
        print("❌ Failed to connect to $adminLoginUrl: $e");
        
        // If primary URL fails, try fallback URLs
        print("Primary URL failed, trying fallback URLs");
        print("Fallback URLs: ${ApiConfig.fallbackBaseUrls}");
        for (String fallbackUrl in ApiConfig.fallbackBaseUrls) {
          try {
            String fallbackAdminLoginUrl = "$fallbackUrl${ApiConfig.adminLoginEndpoint}";
            print("🔗 Trying fallback URL: $fallbackAdminLoginUrl (from base: $fallbackUrl)");
            
            // Validate fallback URL
            if (fallbackUrl.isEmpty) {
              print("Skipping empty fallback URL");
              continue;
            }
            
            // Validate that the URL is properly formed
            if (!fallbackAdminLoginUrl.startsWith('http')) {
              print("Skipping malformed fallback URL: $fallbackAdminLoginUrl");
              continue;
            }
            
            response = await http
                .post(
                  Uri.parse(fallbackAdminLoginUrl),
                  headers: {"Content-Type": "application/json"},
                  body: jsonEncode({
                    "username": _username.text.trim(),
                    "password": _password.text.trim(),
                    if (_awaitingTotp || _totp.text.trim().isNotEmpty)
                      "totp": _totp.text.trim(),
                  }),
                )
                .timeout(const Duration(seconds: 10));
            
            print("✅ Successfully connected to fallback URL: $fallbackAdminLoginUrl");
            break; // Exit loop on successful connection
          } catch (fallbackError) {
            print("❌ Failed to connect to fallback URL $fallbackUrl: $fallbackError");
            continue; // Try next URL
          }
        }
      }

      if (response == null) {
        throw Exception("Could not connect to server. Check if it's running.");
      }
      
      // Print detailed response information
      print("=== Response Details ===");
      print("Status Code: ${response.statusCode}");
      print("Headers: ${response.headers}");
      print("Body: '${response.body}'");
      print("Body Length: ${response.body.length}");
      print("========================");

      // ✅ Handle empty or invalid response body
      print("Response object: $response");
      print("Response status: ${response.statusCode}");
      print("Response headers: ${response.headers}");
      print("Response body: '${response.body}'");
      print("Response body length: ${response.body.length}");
      
      if (response.body.isEmpty || response.body.trim().isEmpty) {
        print("Throwing empty response exception");
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

      final bool wantsOtp = data["requiresOtp"] == true;
      if (wantsOtp) {
        if (!mounted) return;
        setState(() => _awaitingTotp = true);
        MessageUtils.showErrorMessage(
          context,
          data["message"] ??
              "Enter the 6-digit code from your authentication app.",
          title: "Two-factor verification",
        );
        return;
      }

      bool isSuccess = data["success"] == true ||
          data["success"].toString().toLowerCase() == "true" ||
          data["success"] == 1;

      if (!isSuccess) {
        if (!mounted) return;
        MessageUtils.showErrorMessage(
          context,
          data["message"] ?? "Invalid administrator credentials.",
          title: "Admin Login Failed",
        );
        return;
      }

      final tokenValue = data["access_token"]?.toString();
      if (tokenValue != null && tokenValue.isNotEmpty) {
        await AdminSessionStorage.setToken(tokenValue);
      } else {
        throw Exception(
            "Server authenticated you but omitted a session token — check admin_sessions migration.");
      }

      if (!mounted) return;
      MessageUtils.showSuccessMessage(
        context,
        "Welcome back — secure session armed.",
        title: "Admin Login Successful",
      );
      Future.delayed(const Duration(milliseconds: 800), () {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => AdminDashboardScreen(adminData: data["admin"]),
          ),
        );
      });
    } catch (e) {
      if (!mounted) return;
      MessageUtils.showErrorMessage(
        context,
        "Login error: $e",
        title: "Connection Error",
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
                  // --- Brand header
                  Column(
                    children: [
                      Image.asset('assets/images/logo.png', height: 150),
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

                  // --- Login Card
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
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Admin Login',
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

                            // --- Login Form
                            Form(
                              key: _formKey,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
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
                                  TextFormField(
                                    controller: _password,
                                    obscureText: _obscure,
                                    onFieldSubmitted: (_) => _submit(),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(Icons.lock),
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(() {
                                          _obscure = !_obscure;
                                        }),
                                        icon: Icon(_obscure
                                            ? Icons.visibility_off
                                            : Icons.visibility),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    validator: (v) => (v == null || v.isEmpty)
                                        ? 'Enter password'
                                        : null,
                                  ),
                                  if (_awaitingTotp) ...[
                                    const SizedBox(height: 12),
                                    TextFormField(
                                      controller: _totp,
                                      keyboardType: TextInputType.number,
                                      decoration: InputDecoration(
                                        labelText: 'Authenticator code',
                                        prefixIcon:
                                            const Icon(Icons.security),
                                        border: OutlineInputBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      validator: (v) {
                                        if (!_awaitingTotp) return null;
                                        if (v == null ||
                                            v.trim().length != 6) {
                                          return 'Enter the six-digit code';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                  const SizedBox(height: 18),

                                  // --- Sign In button
                                  SizedBox(
                                    height: 48,
                                    child: FilledButton(
                                      onPressed: _isLoading ? null : _submit,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF0047C8),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.6,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                        Color>(Colors.white),
                                              ),
                                            )
                                          : const Text(
                                              'Sign In',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.white,
                                              ),
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // --- Footer
                  Text(
                    'Preventive Healthcare Management System © 2025',
                    style: Theme.of(context)
                        .textTheme
                        .labelLarge
                        ?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Secure • Reliable • Professional',
                    style: Theme.of(context)
                        .textTheme
                        .labelMedium
                        ?.copyWith(color: Colors.white54),
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