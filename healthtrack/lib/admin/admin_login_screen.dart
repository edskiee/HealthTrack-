import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/api_config.dart';
import '../services/connection_status_service.dart';
import '../services/startup_health_check.dart';
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

    // Check backend availability first — shows wakeup overlay if Render is sleeping
    final serverOk = await StartupHealthCheck.run(context, forceCheck: true);
    if (!mounted) return;
    if (!serverOk) {
      setState(() => _isLoading = false);
      MessageUtils.showErrorMessage(
        context,
        'Unable to connect to HealthTrack services at the moment. '
        'Please check your internet connection or try again shortly.',
        title: 'Connection Error',
      );
      return;
    }

    try {
      final String adminLoginUrl =
          '${ApiConfig.baseUrl}${ApiConfig.adminLoginEndpoint}';

      http.Response? response;

      try {
        response = await http
            .post(
              Uri.parse(adminLoginUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'username': _username.text.trim(),
                'password': _password.text.trim(),
                if (_awaitingTotp || _totp.text.trim().isNotEmpty)
                  'totp': _totp.text.trim(),
              }),
            )
            .timeout(const Duration(seconds: 12));
      } catch (_) {
        // Primary URL failed — try fallbacks
        for (final fallbackUrl in ApiConfig.fallbackBaseUrls) {
          if (fallbackUrl.isEmpty || !fallbackUrl.startsWith('http')) continue;
          try {
            response = await http
                .post(
                  Uri.parse('$fallbackUrl${ApiConfig.adminLoginEndpoint}'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'username': _username.text.trim(),
                    'password': _password.text.trim(),
                    if (_awaitingTotp || _totp.text.trim().isNotEmpty)
                      'totp': _totp.text.trim(),
                  }),
                )
                .timeout(const Duration(seconds: 12));
            break;
          } catch (_) {
            continue;
          }
        }
      }

      if (response == null) {
        throw Exception('Could not connect to HealthTrack services. Please check your connection.');
      }

      if (response.body.isEmpty || response.body.trim().isEmpty) {
        throw Exception('Server returned an empty response. Please try again.');
      }

      Map<String, dynamic> data;
      try {
        data = jsonDecode(response.body);
      } catch (_) {
        throw Exception('Server returned an invalid response. Please try again.');
      }

      final bool wantsOtp = data['requiresOtp'] == true;
      if (wantsOtp) {
        if (!mounted) return;
        setState(() => _awaitingTotp = true);
        MessageUtils.showErrorMessage(
          context,
          data['message'] ?? 'Enter the 6-digit code from your authentication app.',
          title: 'Two-factor verification',
        );
        return;
      }

      final bool isSuccess = data['success'] == true ||
          data['success'].toString().toLowerCase() == 'true' ||
          data['success'] == 1;

      if (!isSuccess) {
        if (!mounted) return;
        MessageUtils.showErrorMessage(
          context,
          data['message'] ?? 'Invalid administrator credentials.',
          title: 'Admin Login Failed',
        );
        return;
      }

      final tokenValue = data['access_token']?.toString().trim();
      if (tokenValue != null && tokenValue.isNotEmpty) {
        await AdminSessionStorage.setToken(tokenValue);
        print('Token stored (login): ${tokenValue.substring(0, tokenValue.length.clamp(0, 12))}...');
        final savedToken = await AdminSessionStorage.getToken();
        final tokenOk = savedToken != null && savedToken.isNotEmpty;
        if (!tokenOk) {
          throw Exception(
            'Token received but could not be saved to local storage. '
            'This can happen in private/incognito mode on web.',
          );
        }
      } else {
        throw Exception(
          'Server authenticated you but omitted a session token — '
          'check admin_sessions migration.',
        );
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
        ConnectionStatusService.friendlyError(e),
        title: 'Connection Error',
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