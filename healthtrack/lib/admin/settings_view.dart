import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:healthtrack/admin/admin_login_screen.dart';
import 'package:healthtrack/admin/theme_provider.dart';
import 'package:healthtrack/admin/screens/audit_logs_screen.dart';
import 'package:healthtrack/admin/services/admin_preferences_api_service.dart';
import 'package:healthtrack/admin/services/admin_profile_service.dart';
import 'package:healthtrack/admin/services/admin_session_storage.dart';
import 'package:healthtrack/admin/services/prefs_patch_coalescer.dart';
import 'package:healthtrack/admin/signals/admin_dashboard_signals.dart';
import 'package:healthtrack/admin/widgets/admin_header.dart';
import 'package:healthtrack/services/analytics_gate.dart';
import 'package:healthtrack/services/api_config.dart';
import 'package:healthtrack/utils/message_utils.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Modern admin settings — wired to `/admin/me/*`, sessions, audits, realtime IO.
class SettingsView extends StatefulWidget {
  final Map<String, dynamic>? adminData;
  final ValueChanged<String>? onThemeModeChanged;

  const SettingsView({
    super.key,
    this.adminData,
    this.onThemeModeChanged,
  });

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class AppColors {
  static const Color primary = Color(0xFF0EA5E9);
  static const Color primaryDark = Color(0xFF0284C7);
  static const Color primaryLight = Color(0xFFE0F2FE);
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Colors.white;
  static const Color border = Color(0xFFE2E8F0);
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color danger = Color(0xFFEF4444);
  static const Color dangerBg = Color(0xFFFEF2F2);
  static const Color success = Color(0xFF10B981);
}

class AppSpacing {
  static const double xs = 4,
      sm = 8,
      md = 12,
      lg = 16,
      xl = 20,
      xxl = 24,
      xxxl = 32,
      huge = 48;
}

class AppLayout {
  static const double maxWidth = 1200;
  static const double sidePadding = AppSpacing.xxxl;
  static const double columnGap = AppSpacing.xxl;
}

class AppBorderRadius {
  static const double sm = 6, md = 8, lg = 12, xl = 16, card = 16;
}

class AppElevation {
  static const double card = 4;
}

class _SettingsViewState extends State<SettingsView>
    with WidgetsBindingObserver {
  Map<String, dynamic> _adminProfile = {};
  Map<String, dynamic> _preferences = {};

  bool _loading = true;
  String? _error;

  Timer? _sessionTimer;
  Timer? _healthTimer;
  PrefsPatchCoalescer? _patchCoalescer;

  io.Socket? _socket;

  List<Map<String, dynamic>> _sessions = [];
  bool _sessionsBusy = false;

  Map<String, dynamic> _systemMeta = {};

  bool _isEditingProfile = false;
  bool _isSavingProfile = false;
  final TextEditingController _nameController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _phoneController = TextEditingController();

  bool _pushBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _patchCoalescer = PrefsPatchCoalescer(
      sender: AdminPreferencesApi.patchPreferences,
      onError: (err, _) {
        if (!mounted) return;
        MessageUtils.showErrorMessage(
          context,
          _friendly(err),
          title: 'Update failed',
        );
        _reloadFromServerQuiet();
      },
      onSuccess: () => pingAdminDashboard(),
      onBeforeSend: () {},
      onRevert: (_) {},
    );
    _bootstrap();
    _sessionTimer =
        Timer.periodic(const Duration(seconds: 30), (_) => _loadSessions());
    _healthTimer =
        Timer.periodic(const Duration(seconds: 60), (_) => _probeHealthOnly());
    _connectSocket();
  }

  String _friendly(Object e) {
    if (e is AdminPreferencesApiException) return e.message;
    final s = e.toString();
    if (s.startsWith('Exception: ')) return s.substring(11);
    return 'An unexpected issue occurred.';
  }

  Future<void> _bootstrap() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _reloadFromServerQuiet();
      await Future.wait([
        _loadSessions(),
        _loadSystemMeta(),
        _probeHealthOnly(),
      ]);
    } catch (e) {
      if (mounted) {
        setState(() => _error = _friendly(e));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reloadFromServerQuiet() async {
    final payload = await AdminPreferencesApi.fetchPreferencesPayload();
    final admin = payload['admin'] as Map<String, dynamic>? ?? {};
    final prefs = payload['preferences'] as Map<String, dynamic>? ?? {};
    AnalyticsGate.setEnabled(_boolPref(prefs['analytics_enabled']));
    AnalyticsGate.record(
      'admin.settings.preferences_hydrated',
      {'analytics': _boolPref(prefs['analytics_enabled'])},
    );
    if (!mounted) return;
    setState(() {
      _adminProfile = Map.from(admin);
      _preferences = Map<String, dynamic>.from(prefs);
      _nameController.text = (admin['full_name'] ?? '').toString();
      _phoneController.text = (prefs['phone'] ?? '').toString();
    });
  }

  void _enqueuePref(Map<String, dynamic> slice) {
    _patchCoalescer?.schedule(slice);
  }

  bool _boolPref(dynamic raw) =>
      raw == true || raw == 1 || raw == 'true' || raw == '1';

  Future<void> _loadSessions() async {
    if (_sessionsBusy || !mounted) return;
    setState(() => _sessionsBusy = true);
    try {
      final list = await AdminPreferencesApi.fetchSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {/* quiet */} finally {
      if (mounted) setState(() => _sessionsBusy = false);
    }
  }

  Future<void> _loadSystemMeta() async {
    try {
      final data = await AdminPreferencesApi.fetchSystemMeta();
      if (!mounted) return;
      setState(() => _systemMeta = Map<String, dynamic>.from(data));
    } catch (_) {
      /* keep prior */
    }
  }

  Future<void> _probeHealthOnly() async {
    final det = await AdminPreferencesApi.pingHealthDetailed();
    final ok = det['ok'] == true;
    if (!mounted) return;
    setState(() {
      _systemMeta['serverStatus'] =
          ok ? 'Operational' : 'Degraded';
    });
    if (!ok && mounted) {
      MessageUtils.showErrorMessage(
        context,
        'Platform health probe failed.',
        title: 'System status',
      );
    }
  }

  void _connectSocket() {
    final id = widget.adminData?['id'];
    try {
      final origin = ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '');
      _socket = io.io(origin, io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build());
      _socket?.connect();
      _socket?.onConnect((_) {
        _socket?.emit('joinAdminsRoom');
        if (id != null) {
          _socket?.emit('joinAdminRoom', id);
        }
      });
      _socket?.on('adminSessionsRefresh', (_) => _loadSessions());
      _socket?.on(
          'serverHealthChanged',
          (payload) {
            if (payload is Map) {
              _applyHealthSocket(Map<String, dynamic>.from(payload));
            }
          },
      );
      _socket?.on('systemAlert', (payload) => _presentSystemIssue(payload));
    } catch (e) {
      debugPrint('Socket connection skipped: $e');
    }
  }

  void _applyHealthSocket(Map<String, dynamic> raw) {
    final status = raw['status'];
    if (status == null) return;
    if (!mounted) return;
    setState(() => _systemMeta['serverStatus'] = status.toString());
  }

  void _presentSystemIssue(dynamic payload) {
    if (!mounted) return;
    final map = payload is Map ? payload : {};
    MessageUtils.showErrorMessage(
      context,
      '${map['message'] ?? 'New system alert detected.'}',
      title: 'System alert',
    );
  }

  @override
  void didChangePlatformBrightness() {
    if (context.read<ThemeProvider>().themeMode != ThemeMode.system) return;
    setState(() {});
    widget.onThemeModeChanged?.call('system');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _patchCoalescer?.dispose();
    _sessionTimer?.cancel();
    _healthTimer?.cancel();
    _socket?.disconnect();
    _socket?.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ThemeMode _themeModeFromString(String mode) {
    switch (mode) {
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.light;
    }
  }

  Future<void> _persistTheme(String mode) async {
    await context.read<ThemeProvider>().setTheme(_themeModeFromString(mode));
    if (!mounted) return;
    setState(() => _preferences['theme_mode'] = mode);
    _enqueuePref({'theme_mode': mode});
    widget.onThemeModeChanged?.call(mode);
    if (mounted) {
      MessageUtils.showSuccessMessage(
        context,
        'Theme synchronized across devices.',
      );
    }
  }

  Future<void> _saveProfilePressed() async {
    final trimmed = _nameController.text.trim();
    if (trimmed.isEmpty) {
      MessageUtils.showErrorMessage(context, 'Name cannot be empty.');
      return;
    }
    setState(() => _isSavingProfile = true);
    try {
      final adminIdRaw = widget.adminData?['id'];
      final adminId = adminIdRaw is int
          ? adminIdRaw
          : int.tryParse(adminIdRaw?.toString() ?? '');
      if (adminId == null) throw Exception('Missing administrator id.');
      await AdminProfileService.updateAdminProfile(
        adminId: adminId,
        fullName: trimmed,
      );
      await AdminPreferencesApi.patchPreferences({
        'phone': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
      });
      await _reloadFromServerQuiet();
      if (!mounted) return;
      setState(() => _isEditingProfile = false);
      MessageUtils.showSuccessMessage(context, 'Profile saved.');
      pingAdminDashboard();
    } catch (e) {
      MessageUtils.showErrorMessage(context, _friendly(e));
    } finally {
      if (mounted) setState(() => _isSavingProfile = false);
    }
  }

  Future<void> _pickAvatar() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;
      final path = await AdminPreferencesApi.uploadAvatarFile(file.path);
      if (!mounted || path == null) return;
      setState(() => _preferences['avatar_url'] = path);
      MessageUtils.showSuccessMessage(context, 'Avatar updated.');
      await _reloadFromServerQuiet();
    } catch (e) {
      MessageUtils.showErrorMessage(context, _friendly(e));
    }
  }

  String _pwdChangedLabel() {
    final raw = _adminProfile['password_changed_at'];
    if (raw == null || raw.toString().isEmpty) {
      return 'Last changed • not recorded yet';
    }
    final parsed = DateTime.tryParse(raw.toString());
    if (parsed == null) return 'Last changed • unknown';
    final diff = DateTime.now().difference(parsed);
    if (diff.inDays >= 365) {
      final years = (diff.inDays / 365).floor();
      return 'Last changed $years year${years == 1 ? '' : 's'} ago';
    }
    if (diff.inDays >= 30) {
      final m = (diff.inDays / 30).floor();
      return 'Last changed $m month${m == 1 ? '' : 's'} ago';
    }
    if (diff.inDays >= 1) {
      return 'Last changed ${diff.inDays} day${diff.inDays == 1 ? '' : 's'} ago';
    }
    return 'Updated ${DateFormat('MMM d • HH:mm').format(parsed)}';
  }

  Widget _circleAvatarResolved() {
    final rel = (_preferences['avatar_url'] ?? '').toString().trim();
    if (rel.isEmpty) {
      return const CircleAvatar(
        radius: 32,
        backgroundColor: AppColors.primaryLight,
        child:
            Icon(Icons.person, size: 32, color: AppColors.primaryDark),
      );
    }
    final uri = Uri.parse(ApiConfig.baseUrl).resolve(rel);
    return CircleAvatar(
      radius: 32,
      backgroundColor: AppColors.primaryLight,
      backgroundImage: NetworkImage(uri.toString()),
    );
  }

  Future<void> _toggleTwoFactor(bool wantOn) async {
    if (wantOn) {
      await _showTwoSetupFlow();
      return;
    }

    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disable Two-Factor'),
        content: TextField(
          controller: passwordController,
          obscureText: true,
          decoration: _inputDecoration('Current password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await AdminPreferencesApi.disableTwoFactor(passwordController.text);
      passwordController.dispose();
      await _reloadFromServerQuiet();
      if (!mounted) return;
      MessageUtils.showSuccessMessage(
        context,
        'Two-factor authentication disabled.',
      );
    } catch (e) {
      passwordController.dispose();
      MessageUtils.showErrorMessage(context, _friendly(e));
    }
  }

  Future<void> _showTwoSetupFlow() async {
    String? otpauthUrl;
    String? qrImg;
    final codeCtl = TextEditingController();
    try {
      final data = await AdminPreferencesApi.startTwoFactorSetup();
      otpauthUrl = data['otpauth_url'] as String?;
      qrImg = data['qr_base64_png']?.toString();
    } catch (e) {
      MessageUtils.showErrorMessage(context, _friendly(e));
      return;
    }

    Uint8List? qrBytes;
    final imgStr = qrImg ?? '';
    if (imgStr.contains(',')) {
      qrBytes =
          Uint8List.fromList(base64.decode(imgStr.split(',').last.trim()));
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
            title: const Text('Enable Two-Factor'),
            content: SizedBox(
              width: 360,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (qrBytes != null) Image.memory(qrBytes, height: 200),
                  const SizedBox(height: 8),
                  SelectableText(
                    otpauthUrl ?? '',
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: codeCtl,
                    keyboardType: TextInputType.number,
                    decoration:
                        _inputDecoration('Authenticator code').copyWith(labelText: '6-digit code'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogCtx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  try {
                    await AdminPreferencesApi.confirmTwoFactor(codeCtl.text);
                    Navigator.pop(dialogCtx);
                    await _reloadFromServerQuiet();
                    MessageUtils.showSuccessMessage(
                      context,
                      'Two-factor authentication is active.',
                    );
                  } catch (e) {
                    MessageUtils.showErrorMessage(dialogCtx, _friendly(e));
                  }
                },
                child: const Text('Verify & activate'),
              ),
            ],
          ),
    );

    await _reloadFromServerQuiet();
  }

  Future<void> _maybeAcquirePushConsent() async {
    if (_pushBusy) return;
    _pushBusy = true;
    try {
      if (kIsWeb) {
        return;
      }
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Push permission skipped: $e');
    } finally {
      _pushBusy = false;
    }
  }

  Widget _granularChecks({
    required String masterField,
    required String emailField,
    required String pushField,
    required String smsField,
  }) {
    if (!_boolPref(_preferences[masterField])) {
      return const SizedBox.shrink();
    }

    Future<void> setEmail(bool v) async {
      setState(() => _preferences[emailField] = v ? 1 : 0);
      _enqueuePref({emailField: v});
    }

    Future<void> setPush(bool v) async {
      if (v) await _maybeAcquirePushConsent();
      setState(() => _preferences[pushField] = v ? 1 : 0);
      _enqueuePref({pushField: v});
    }

    Future<void> setSms(bool v) async {
      if (v && (_preferences['phone'] ?? '').toString().trim().isEmpty) {
        MessageUtils.showErrorMessage(context,
            'Provide a mobile number via Edit Profile before enabling SMS.');
        return;
      }
      setState(() => _preferences[smsField] = v ? 1 : 0);
      _enqueuePref({smsField: v});
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CheckboxListTile(
          title: const Text('Email channel'),
          value: _boolPref(_preferences[emailField]),
          onChanged: (v) =>
              setEmail(v == true),
        ),
        CheckboxListTile(
          title: const Text('Push notifications'),
          value: _boolPref(_preferences[pushField]),
          onChanged: (v) =>
              setPush(v == true),
        ),
        CheckboxListTile(
          title: const Text('SMS'),
          value: _boolPref(_preferences[smsField]),
          onChanged: (v) =>
              setSms(v == true),
        ),
      ],
    );
  }

  String _sessionsSummarySentence() {
    if (_sessions.isEmpty) {
      return 'Active sessions hydrate every thirty seconds.';
    }
    final devices = _sessions
        .map((s) => (s['device_label'] ?? 'Device').toString().split('·').first.trim())
        .toSet()
        .toList();
    final plural = _sessions.length == 1 ? 'session' : 'sessions';
    if (devices.isEmpty || devices.length > 4) {
      return '${_sessions.length} active $plural.';
    }
    return '${_sessions.length} active $plural on ${devices.take(4).join(' & ')}.';
  }

  void _showSessionsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Active Sessions'),
        content: SizedBox(
          width: 520,
          height: 400,
          child: _sessions.isEmpty
              ? const Center(child: Text('Nothing to show'))
              : ListView.separated(
                  itemBuilder: (_, i) {
                    final s = _sessions[i];
                    final isCurrent = s['isCurrent'] == true;
                    return ListTile(
                      title:
                          Text(s['device_label']?.toString() ?? 'Unknown device'),
                      subtitle: Text(
                        '${s['browser_label'] ?? ''}\n'
                        '${s['ip_address'] ?? '—'}\n'
                        'Last activity ${s['last_active_at']}',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: isCurrent
                          ? const Chip(label: Text('Current'))
                          : TextButton(
                              onPressed: () async {
                                try {
                                  await AdminPreferencesApi.revokeSession(
                                      s['id'].toString());
                                  await _loadSessions();
                                  Navigator.pop(ctx);
                                  MessageUtils.showSuccessMessage(
                                    context,
                                    'Session revoked.',
                                  );
                                } catch (e) {
                                  MessageUtils.showErrorMessage(
                                      context, _friendly(e));
                                }
                              },
                              child: const Text(
                                'Revoke',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                    );
                  },
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1),
                  itemCount: _sessions.length,
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _confirmSignOutAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text(
          'Signing out terminates this authenticated session locally and on the API.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await AdminPreferencesApi.logoutCurrentSession();
    } catch (_) {
      /* still clear local credentials */
    } finally {
      await AdminSessionStorage.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
        (_) => false,
      );
    }
  }

  void _launchAuditNavigator() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AuditLogsScreen()),
    );
  }

  Widget _environmentBadge(String env) =>
      Chip(backgroundColor: AppColors.primaryLight, label: Text(env));

  ThemeData _settingsThemeBrightness(ThemeMode mode, MediaQueryData mq) {
    Brightness b;
    if (mode == ThemeMode.dark) {
      b = Brightness.dark;
    } else if (mode == ThemeMode.system) {
      b = mq.platformBrightness;
    } else {
      b = Brightness.light;
    }
    final isDark = b == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: b,
      colorScheme: ColorScheme.fromSeed(
        brightness: b,
        seedColor: AppColors.primary,
      ),
      scaffoldBackgroundColor:
          isDark ? const Color(0xFF020617) : AppColors.background,
    );
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final themeMode = context.watch<ThemeProvider>().themeMode;

    if (_loading && _preferences.isEmpty) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(child: Center(child: CircularProgressIndicator())),
      );
    }

    final roleLabel =
        (_adminProfile['role'] ?? widget.adminData?['role'] ?? 'Administrator')
            .toString();
    final analyticsOn = _boolPref(_preferences['analytics_enabled']);

    return Theme(
      data: _settingsThemeBrightness(themeMode, mq),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: SafeArea(
              child: LayoutBuilder(builder: (_, constraints) {
                final wide = constraints.maxWidth > 900;

                Widget column(List<Widget> kids) =>
                    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: kids);

                return Scrollbar(
                  controller: _scrollController,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    padding: EdgeInsets.symmetric(
                      horizontal: constraints.maxWidth > AppLayout.maxWidth
                          ? (constraints.maxWidth - AppLayout.maxWidth) / 2
                          : AppLayout.sidePadding,
                      vertical: AppLayout.sidePadding,
                    ),
                    child: column([
                      AdminHeader(
                        title: 'Settings',
                        subtitle: 'Manage administrator profile and safeguards',
                        onRefresh: () {
                          _reloadFromServerQuiet();
                          _loadSessions();
                          _loadSystemMeta();
                          _probeHealthOnly();
                        },
                        showLiveClock: true,
                      ),
                      if (_error != null)
                        Padding(
                          padding:
                              const EdgeInsets.only(bottom: AppSpacing.lg),
                          child:
                              Text(_error!, style: const TextStyle(color: Colors.red)),
                        ),
                      if (wide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: column([
                                _profileSection(roleLabel),
                                const SizedBox(height: AppLayout.columnGap),
                                _securitySection(),
                                const SizedBox(height: AppLayout.columnGap),
                                _danger(),
                              ]),
                            ),
                            const SizedBox(width: AppLayout.columnGap),
                            Expanded(
                              child: column([
                                _appearanceSection(themeMode),
                                const SizedBox(height: AppLayout.columnGap),
                                _notificationsSection(),
                                const SizedBox(height: AppLayout.columnGap),
                                _systemSection(analyticsOn),
                              ]),
                            ),
                          ],
                        )
                      else
                        column([
                          _profileSection(roleLabel),
                          const SizedBox(height: AppLayout.columnGap),
                          _appearanceSection(themeMode),
                          const SizedBox(height: AppLayout.columnGap),
                          _notificationsSection(),
                          const SizedBox(height: AppLayout.columnGap),
                          _securitySection(),
                          const SizedBox(height: AppLayout.columnGap),
                          _systemSection(analyticsOn),
                          const SizedBox(height: AppLayout.columnGap),
                          _danger(),
                        ]),
                    ]),
                  ),
                );
              }),
            ),
      ),
    );
  }

  Widget _profileSection(String roleLabel) => _surfaceCard(
        title: 'Profile Information',
        icon: Icons.person_outline,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Stack(
                  children: [
                    _circleAvatarResolved(),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickAvatar,
                        child: const CircleAvatar(
                          radius: 14,
                          child: Icon(Icons.camera_alt, size: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: !_isEditingProfile
                      ? Text(
                          (_adminProfile['full_name'] ??
                                      widget.adminData?['username'] ??
                                      'Administrator')
                                  .toString(),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 20),
                        )
                      : Column(children: [
                          TextField(
                            controller: _nameController,
                            decoration: _inputDecoration('Full name'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: _phoneController,
                            decoration: _inputDecoration('Mobile phone (SMS)'),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          const Text(
                            'Phone stays on-device encrypted at rest according to infra policy.',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.textSecondary),
                          ),
                        ]),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            const Text(
              'Role',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            _environmentBadge(roleLabel.isEmpty ? 'Administrator' : roleLabel),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                if (_isEditingProfile) ...[
                  TextButton(
                    onPressed: () => setState(() => _isEditingProfile = false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  ElevatedButton(
                    onPressed: _isSavingProfile ? null : _saveProfilePressed,
                    child: _isSavingProfile
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: () => setState(() => _isEditingProfile = true),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit Profile'),
                  ),
              ],
              mainAxisAlignment: MainAxisAlignment.end,
            ),
          ],
        ),
      );

  Widget _securitySection() => _surfaceCard(
        title: 'Security & Access',
        icon: Icons.shield_outlined,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title:
                  const Text('Two-factor authentication', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: const Text(
                  'Authenticate with GA / Authy-compatible TOTP.'),
              value: _boolPref(_preferences['totp_enabled']),
              onChanged: (v) => _toggleTwoFactor(v),
            ),
            const Divider(),
            SwitchListTile(
              title:
                  const Text('Auto logout (30 minutes)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Dashboard resets after inactivity (pointer events).'),
              value: _boolPref(_preferences['auto_logout_enabled']),
              onChanged: (v) {
                setState(() =>
                    _preferences['auto_logout_enabled'] = v ? 1 : 0);
                _enqueuePref({'auto_logout_enabled': v});
                pingAdminDashboard();
                MessageUtils.showSuccessMessage(
                  context,
                  v ? 'Inactivity watchdog armed.' : 'Inactivity watchdog removed.',
                );
              },
            ),
            const Divider(),
            Text(_pwdChangedLabel(),
                style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: _promptChangePassword,
              child: const Text('Change Password'),
            ),
            const Divider(height: AppSpacing.xxl),
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Session overview',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    _sessionsSummarySentence(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              )),
              ElevatedButton(
                onPressed: _sessionsBusy ? null : _showSessionsDialog,
                child: const Text('View all'),
              ),
            ]),
          ],
        ),
      );

  Future<void> _promptChangePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (_, setModal) {
          return AlertDialog(
            title: const Text('Change Password'),
            content: Form(
              key: formKey,
              child: SizedBox(
                width: 400,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: current,
                    obscureText: true,
                    decoration: _inputDecoration('Current password'),
                    validator: (v) =>
                        (v == null || v.length < 4) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: next,
                    obscureText: true,
                    decoration: _inputDecoration('New password'),
                    validator: (v) {
                      if (v == null || v.length < 6) {
                        return 'At least 6 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirm,
                    obscureText: true,
                    decoration: _inputDecoration('Confirm'),
                    validator: (v) => v == next.text ? null : 'Mismatch',
                  ),
                ]),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!formKey.currentState!.validate()) return;
                  try {
                    final adminId = int.parse(
                        widget.adminData!['id'].toString());
                    await AdminProfileService.updateAdminProfile(
                      adminId: adminId,
                      currentPassword: current.text,
                      newPassword: next.text,
                    );
                    Navigator.pop(ctx);
                    MessageUtils.showSuccessMessage(
                      context,
                      'Password updated — other devices were signed out.',
                    );
                    await _reloadFromServerQuiet();
                  } catch (e) {
                    MessageUtils.showErrorMessage(ctx, _friendly(e));
                  }
                },
                child: const Text('Update'),
              ),
            ],
          );
        });
      },
    );
  }

  Widget _appearanceSection(ThemeMode themeMode) => _surfaceCard(
        title: 'Appearance',
        icon: Icons.palette_outlined,
        body: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Theme mode',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  const Text(
                    'System watches OS appearance when set to System.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Light'),
                  selected: themeMode == ThemeMode.light,
                  onSelected: (_) => _persistTheme('light'),
                ),
                ChoiceChip(
                  label: const Text('Dark'),
                  selected: themeMode == ThemeMode.dark,
                  onSelected: (_) => _persistTheme('dark'),
                ),
                ChoiceChip(
                  label: const Text('System'),
                  selected: themeMode == ThemeMode.system,
                  onSelected: (_) => _persistTheme('system'),
                ),
              ],
            ),
          ],
        ),
      );

  Widget _notificationsSection() => _surfaceCard(
        title: 'Notifications',
        icon: Icons.notifications_none,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SwitchListTile(
              title:
                  const Text('Appointment reminders', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Keep families prepared for encounters.'),
              value: _boolPref(_preferences['appointment_reminders_enabled']),
              onChanged: (value) {
                setState(() {
                  _preferences['appointment_reminders_enabled'] = value ? 1 : 0;
                });
                _enqueuePref({'appointment_reminders_enabled': value});
                MessageUtils.showSuccessMessage(context, 'Reminder preference saved.');
              },
            ),
            _granularChecks(
              masterField: 'appointment_reminders_enabled',
              emailField: 'appointment_notify_email',
              pushField: 'appointment_notify_push',
              smsField: 'appointment_notify_sms',
            ),
            const Divider(height: AppSpacing.xxl),
            SwitchListTile(
              title:
                  const Text('System alerts', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Notify staff about infrastructure regressions.'),
              value: _boolPref(_preferences['system_alerts_enabled']),
              onChanged: (value) {
                setState(() {
                  _preferences['system_alerts_enabled'] = value ? 1 : 0;
                });
                _enqueuePref({'system_alerts_enabled': value});
              },
            ),
            _granularChecks(
              masterField: 'system_alerts_enabled',
              emailField: 'system_alert_email',
              pushField: 'system_alert_push',
              smsField: 'system_alert_sms',
            ),
          ],
        ),
      );

  Widget _systemSection(bool analyticsFlag) => _surfaceCard(
        title: 'System Information',
        icon: Icons.computer,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Version',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                    Text(
                      (_systemMeta['versionLabel'] ?? 'Checking…').toString(),
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                  ],
                )),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Environment',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _environmentBadge(
                        (_systemMeta['environment'] ?? 'Production')
                            .toString(),
                      ),
                    ),
                  ],
                )),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Last updated',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Text(
                      (_systemMeta['lastUpdatedIso'] == null ||
                              (_systemMeta['lastUpdatedIso'] ?? '').toString().isEmpty)
                          ? '—'
                          : DateFormat('MMM d, y • hh:mm').format(DateTime.tryParse(_systemMeta['lastUpdatedIso'].toString()) ?? DateTime.now()),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                )),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Server status',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                    Chip(
                      backgroundColor: ((_systemMeta['serverStatus'] ?? '')
                                  .toString() ==
                              'Operational')
                          ? AppColors.primaryLight.withOpacity(0.65)
                          : AppColors.dangerBg,
                      label: Text(
                          (_systemMeta['serverStatus'] ?? 'Operational')
                              .toString()),
                    ),
                  ],
                )),
              ],
            ),
            SwitchListTile(
              title:
                  const Text('Analytics telemetry', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Honor privacy — disables outbound analytics pings.'),
              value: analyticsFlag,
              onChanged: (v) {
                setState(() =>
                    _preferences['analytics_enabled'] = v ? 1 : 0);
                AnalyticsGate.setEnabled(v);
                _enqueuePref({'analytics_enabled': v});
              },
            ),
            SwitchListTile(
              title:
                  const Text('Data sharing preference', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  const Text('Controls anonymised exports for benchmarking.'),
              value: _boolPref(_preferences['data_sharing_enabled']),
              onChanged: (v) {
                setState(() =>
                    _preferences['data_sharing_enabled'] = v ? 1 : 0);
                _enqueuePref({'data_sharing_enabled': v});
              },
            ),
            OutlinedButton.icon(
              onPressed: _launchAuditNavigator,
              icon: const Icon(Icons.history),
              label: const Text('View global audit logs'),
            ),
          ],
        ),
      );

  Widget _danger() => Card(
        color: AppColors.dangerBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
          side: const BorderSide(color: AppColors.danger),
        ),
        child: ListTile(
          title: const Text('Danger Zone',
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger)),
          subtitle:
              const Text('Signing out resets local dashboards and websocket rooms.'),
          trailing: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: _confirmSignOutAll,
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ),
      );

  Widget _surfaceCard({
    required String title,
    required IconData icon,
    required Widget body,
  }) =>
      Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppBorderRadius.card),
          side: const BorderSide(color: AppColors.border),
        ),
        elevation: AppElevation.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              leading: Icon(icon, color: AppColors.primaryDark),
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: body,
            ),
          ],
        ),
      );

  InputDecoration _inputDecoration(String label) =>
      InputDecoration(
        labelText: label,
        filled: true,
        fillColor: AppColors.surface,
      );
}
