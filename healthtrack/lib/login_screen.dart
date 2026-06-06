import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/message_utils.dart';
import 'services/user_session.dart';
import 'services/user_session_storage.dart';
import 'services/auth_service.dart';
import 'services/websocket_service.dart';
import 'services/fcm_service.dart';
import 'services/connection_status_service.dart';
import 'services/startup_health_check.dart';
import 'dashboard.dart';
import 'unified_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isUsernameValid = false;
  bool _isPasswordValid = false;
  bool _isLoading = false;

  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );

    _controller.forward();

    _usernameController.addListener(() {
      setState(() {
        _isUsernameValid = _usernameController.text.trim().isNotEmpty;
      });
    });

    _passwordController.addListener(() {
      setState(() {
        _isPasswordValid = _passwordController.text.trim().length >= 4;
      });
    });
  }

  /// Single login function that handles the entire login process
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Check backend availability first — shows wakeup overlay if needed
    final serverOk = await StartupHealthCheck.run(context, forceCheck: true);
    if (!mounted) return;
    if (!serverOk) {
      setState(() => _isLoading = false);
      _showErrorDialog(
        'Unable to connect to HealthTrack services at the moment. '
        'Please check your internet connection or try again shortly.',
      );
      return;
    }

    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    try {
      debugPrint('🔗 Attempting login with username: $username');
      
      final userData = await AuthService.loginUser(username, password);
      
      if (userData != null) {
        debugPrint("✅ Login successful, user data: $userData");
        
        // The server returns data with 'user', 'patient', and 'access_token' objects
        final userInfo = userData['user'];
        final patientInfo = userData['patient'];
        final accessToken = userData['access_token']?.toString();

        // Persist the user JWT for authenticated API calls
        if (accessToken != null && accessToken.isNotEmpty) {
          await UserSessionStorage.setToken(accessToken);
        }

        if (userInfo != null) {
          // Store user session data
          UserSession.instance.setUserData(userInfo);
          await _syncPushPreferenceFromLoginUser(userInfo);
          await FCMService.syncTokenForCurrentUser();

          // Initialize real-time channel for in-app banners/badges
          final userId = int.tryParse(UserSession.instance.userId) ?? 0;
          if (userId > 0) {
            try {
              await WebSocketService.instance.initialize();
              WebSocketService.instance.joinUserRoom(userId);
            } catch (e) {
              debugPrint("❌ WebSocket init/join failed: $e");
            }
          }
          
          // Log service type for debugging
          final serviceType = userInfo['service_type']?.toString() ?? 'immunization';
          debugPrint("サービスタイプ: $serviceType");
          
          if (patientInfo != null) {
            // Store patient data if available
            UserSession.instance.setPatientData(patientInfo);
          } else {
            // Create a new patient record if none exists
            final newPatientData = {
              'id': userInfo['id'],
              'user_id': userInfo['id'],
              'child_fullname': userInfo['full_name'] ?? username,
              'mother_fullname': userInfo['full_name'] ?? username,
              'dob': "",
              'sex': "Male",
              'status': "active"
            };
            UserSession.instance.setPatientData(newPatientData);
          }
        } else {
          throw Exception("Invalid user data from server");
        }

        if (!mounted) return;
        
        // Show success message
        MessageUtils.showSuccessMessage(
          context,
          "Welcome back! You have successfully logged in.",
          title: "Login Successful",
        );

        // Navigate to dashboard after a short delay
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            // Try named route first, fallback to direct navigation
            try {
              Navigator.pushReplacementNamed(context, '/dashboard');
            } catch (e) {
              debugPrint("Named route failed, using direct navigation: $e");
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const DashboardScreen()),
              );
            }
          }
        });
      } else {
        if (!mounted) return;
        _showErrorDialog("Login failed. Please check your credentials and try again.");
      }
    } catch (e) {
      if (!mounted) return;
      debugPrint('❌ Login error: $e');
      _showErrorDialog(ConnectionStatusService.friendlyError(e));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// Align local Settings toggle with server `push_notifications_enabled` after login.
  Future<void> _syncPushPreferenceFromLoginUser(Map<String, dynamic> userInfo) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = userInfo['push_notifications_enabled'];
      var enabled = true;
      if (raw is int) {
        enabled = raw != 0;
      } else if (raw is bool) {
        enabled = raw;
      } else if (raw is String) {
        enabled = raw != '0' && raw.toLowerCase() != 'false';
      }
      await prefs.setBool('notifications', enabled);
    } catch (e) {
      debugPrint('⚠️ _syncPushPreferenceFromLoginUser: $e');
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text(
            "Login Failed",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _controller.dispose();
    super.dispose();
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool isValid,
    bool isPassword = false,
    VoidCallback? togglePassword,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword ? _obscurePassword : false,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey,
                ),
                onPressed: togglePassword,
              )
            : (controller.text.isNotEmpty
                ? Icon(
                    isValid ? Icons.check_circle : Icons.error,
                    color: isValid ? Colors.green : Colors.red,
                  )
                : null),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return "Enter your $label";
        }
        if (label == "Password" && value.length < 4) {
          return "Password must be at least 4 characters";
        }
        return null;
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 🖼️ Background Image
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage("assets/images/bluebackground.png"),
                fit: BoxFit.cover,
              ),
            ),
          ),

          // Overlay para clear ang UI
          Container(color: Colors.black.withOpacity(0.2)),

          // 🔹 Title and Back Icon
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: const [
                  SizedBox(width: 10),
                  Text(
                    "Sign in",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
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
                height: MediaQuery.of(context).size.height * 0.78,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Welcome Back",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        "Hello there, sign in to continue!",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Username Field with validation icon
                      _buildTextField(
                        label: "Username",
                        controller: _usernameController,
                        isValid: _isUsernameValid,
                      ),
                      const SizedBox(height: 16),

                      // Password Field with validation icon
                      _buildTextField(
                        label: "Password",
                        controller: _passwordController,
                        isValid: _isPasswordValid,
                        isPassword: true,
                        togglePassword: () =>
                            setState(() => _obscurePassword = !_obscurePassword),
                      ),
                      const SizedBox(height: 20),

                      // Sign in Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _login,
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
                                  "Sign in",
                                  style: TextStyle(fontSize: 18, color: Colors.white),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 🔹 Sign up link (bottom)
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "Don’t have an account? ",
                    style: TextStyle(color: Colors.black54),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const UnifiedRegisterScreen(),
                        ),
                      );
                    },
                    child: const Text(
                      "Sign up",
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}