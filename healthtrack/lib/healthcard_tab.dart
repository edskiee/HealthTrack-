import 'dart:async';
import 'package:flutter/material.dart';
import 'settings_tab.dart';
import 'login_screen.dart';
import 'utils/message_utils.dart';
import 'services/user_session.dart';
import 'services/api_config.dart';
import 'services/health_record_service.dart';
import 'services/referral_service.dart';
import 'services/children_service.dart';
import 'models/referral.dart';
import 'widgets/vaccine_record_tab.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

class HealthCardTab extends StatefulWidget {
  const HealthCardTab({super.key});

  @override
  State<HealthCardTab> createState() => _HealthCardTabState();
}

class _HealthCardTabState extends State<HealthCardTab>
    with TickerProviderStateMixin {
  List<Map<String, dynamic>> _healthRecords = [];
  List<Referral> _referrals = [];
  bool _isLoading = true;
  bool _isLoadingReferrals = true;
  io.Socket? _socket;
  late TabController _tabController;

  // Active-child watcher
  StreamSubscription<void>? _childChangedSub;
  // Track which patientId the vaccine tab was last built for — rebuild on change
  int _vaccineTabPatientId = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _vaccineTabPatientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    _fetchHealthRecords();
    _fetchReferrals();
    _initializeWebSocket();

    // Rebuild whenever the active child changes (switcher selection)
    _childChangedSub =
        UserSession.instance.onActiveChildChanged.listen((_) {
      if (!mounted) return;
      final newId = int.tryParse(UserSession.instance.patientId) ?? 0;
      setState(() => _vaccineTabPatientId = newId);
      _fetchHealthRecords();
      _fetchReferrals();
    });
  }

  void _initializeWebSocket() {
    try {
      final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
      if (patientId > 0) {
        _socket = io.io(ApiConfig.baseUrl, <String, dynamic>{
          'transports': ['websocket'],
          'autoConnect': true,
        });
        _socket!.emit('joinUserRoom', patientId);
        _socket!.on('newReferral', (data) {
          if (mounted && data['type'] == 'referral_created') {
            _fetchReferrals();
            if (mounted) MessageUtils.showInfoMessage(context, data['message'] ?? 'New referral created', title: 'New Referral');
          }
        });
        _socket!.on('referralStatusUpdated', (data) {
          if (mounted && data['type'] == 'referral_status_updated') {
            _fetchReferrals();
            if (mounted) MessageUtils.showInfoMessage(context, data['message'] ?? 'Referral status updated', title: 'Referral Update');
          }
        });
        _socket!.on('referralDeleted', (data) {
          if (mounted && data['type'] == 'referral_deleted') {
            _fetchReferrals();
            if (mounted) MessageUtils.showInfoMessage(context, data['message'] ?? 'Referral deleted', title: 'Referral Deleted');
          }
        });
        _socket!.connect();
      }
    } catch (e) {
      debugPrint('Error initializing WebSocket: $e');
    }
  }

  @override
  void dispose() {
    _childChangedSub?.cancel();
    _tabController.dispose();
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (_socket != null) {
      if (patientId > 0) _socket!.emit('leaveUserRoom', patientId);
      _socket!.disconnect();
      _socket = null;
    }
    super.dispose();
  }

  Future<void> _fetchReferrals() async {
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) { if (mounted) setState(() => _isLoadingReferrals = false); return; }
    if (mounted) setState(() => _isLoadingReferrals = true);
    try {
      final referrals = await ReferralService.getPatientReferrals(patientId);
      if (mounted) setState(() { _referrals = referrals; _isLoadingReferrals = false; });
    } catch (e) {
      debugPrint('Error fetching referrals: $e');
      if (mounted) {
        setState(() => _isLoadingReferrals = false);
        MessageUtils.showErrorMessage(context, 'Failed to load referrals: $e', title: 'Load Error');
      }
    }
  }

  Future<void> _fetchHealthRecords() async {
    final patientId = int.tryParse(UserSession.instance.patientId) ?? 0;
    if (patientId <= 0) { if (mounted) setState(() => _isLoading = false); return; }
    try {
      final records = await HealthRecordService.getUserHealthRecords(patientId);
      if (mounted) setState(() { _healthRecords = records; _isLoading = false; });
    } catch (e) {
      debugPrint('Error fetching health records: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        MessageUtils.showErrorMessage(context, 'Failed to load health records: $e', title: 'Load Error');
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final userSession = UserSession.instance;
    final serviceType = userSession.serviceType;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: Column(
        children: [
          // ── Child switcher (immunization only — maternal is single-patient) ──
          if (serviceType != 'maternal') _ChildSwitcherBar(
            onAddChild: _openAddChildModal,
            onActiveChildChanged: () {
              final newId = int.tryParse(UserSession.instance.patientId) ?? 0;
              setState(() => _vaccineTabPatientId = newId);
              _fetchHealthRecords();
              _fetchReferrals();
            },
          ),

          // ── Tab bar ────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.blueAccent,
              unselectedLabelColor: Colors.grey.shade600,
              indicatorColor: Colors.blueAccent,
              indicatorWeight: 2.5,
              labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              unselectedLabelStyle: const TextStyle(fontSize: 13),
              tabs: const [
                Tab(icon: Icon(Icons.badge_outlined, size: 18), text: 'Health Card'),
                Tab(icon: Icon(Icons.vaccines_outlined, size: 18), text: 'Vaccine Record'),
              ],
            ),
          ),

          // ── Tab content ────────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildHealthCardContent(context, userSession, serviceType),
                // Pass active child's patientId so vaccine tab always shows correct child
                VaccineRecordTab(
                  key: ValueKey(_vaccineTabPatientId),
                  patientIdOverride: _vaccineTabPatientId > 0 ? _vaccineTabPatientId : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Add Child modal ────────────────────────────────────────────────────────

  Future<void> _openAddChildModal() async {
    final result = await showModalBottomSheet<ChildRecord>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddChildSheet(),
    );
    if (result != null && mounted) {
      UserSession.instance.addChild(result);
      final newId = int.tryParse(UserSession.instance.patientId) ?? 0;
      setState(() => _vaccineTabPatientId = newId);
      _fetchHealthRecords();
      _fetchReferrals();
      MessageUtils.showSuccessMessage(
        context,
        'Child added successfully. Vaccine tracking has been set up.',
        title: 'Child Added',
      );
    }
  }

  // ── Health Card content ────────────────────────────────────────────────────

  Widget _buildHealthCardContent(
    BuildContext context,
    UserSession userSession,
    String serviceType,
  ) {
    return RefreshIndicator(
      onRefresh: _fetchHealthRecords,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (serviceType == 'maternal')
              _buildMaternalProfileSection()
            else
              _buildImmunizationProfileSection(),
            const SizedBox(height: 20),
            if (serviceType == 'maternal')
              _buildMaternalInformationSection()
            else
              _buildImmunizationInformationSection(),
            const SizedBox(height: 20),
            _buildHealthRecordsSection(),
            const SizedBox(height: 20),
            _buildReferralHistorySection(),
            const SizedBox(height: 20),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: Icon(Icons.settings,
                    color: serviceType == 'maternal' ? Colors.pink : Colors.blueAccent),
                title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => SettingsTab(onItemTap: (item) {
                      if (item == 'Logout') {
                        UserSession.instance.clearSession();
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                          (r) => false,
                        );
                      }
                    }),
                  ));
                },
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () {
                UserSession.instance.clearSession();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false,
                );
              },
              icon: const Icon(Icons.logout),
              label: const Text('Logout', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  // ── Profile sections (unchanged logic, extracted) ─────────────────────────

  Widget _buildImmunizationProfileSection() {
    final s = UserSession.instance;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 45,
              backgroundColor: Colors.teal.shade50,
              backgroundImage: const AssetImage('assets/images/profile.png'),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.childName.isNotEmpty ? s.childName : 'Unknown Child',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('Patient ID: ${s.displayPatientId}',
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8, runSpacing: 4,
                    children: [
                      _infoChip(s.childAge, Colors.teal.shade100, Colors.blueAccent),
                      _infoChip(s.sex.isNotEmpty ? s.sex : 'Unknown', Colors.blue.shade100, Colors.blue),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaternalProfileSection() {
    final s = UserSession.instance;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE91E63), Color(0xFFF06292)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.pink.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('HEALTH CARD', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                child: const Text('MATERNAL CARE', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              const CircleAvatar(
                radius: 30, backgroundColor: Colors.white,
                child: Icon(Icons.pregnant_woman, color: Color(0xFFE91E63), size: 30),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s.fullName, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Patient ID: ${s.displayPatientId}', style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImmunizationInformationSection() {
    final s = UserSession.instance;
    return _sectionCard(title: 'Child Information', children: [
      _infoRow(Icons.child_care, "Child's Name", s.childName.isNotEmpty ? s.childName : 'Unknown'),
      _infoRow(Icons.calendar_today, 'Date of Birth', s.formattedDateOfBirth),
      _infoRow(Icons.location_on, 'Place of Birth', s.placeOfBirth.isNotEmpty ? s.placeOfBirth : 'Unknown'),
      _infoRow(Icons.home, 'Address', s.patientAddress.isNotEmpty ? s.patientAddress : 'Unknown'),
      const Divider(),
      _infoRow(Icons.female, "Mother's Name", s.motherName.isNotEmpty ? s.motherName : 'Unknown'),
      _infoRow(Icons.male, "Father's Name", s.fatherName.isNotEmpty ? s.fatherName : 'Unknown'),
      const Divider(),
      _infoRow(Icons.height, 'Birth Height', s.birthHeight.isNotEmpty ? '${s.birthHeight} cm' : 'Unknown'),
      _infoRow(Icons.monitor_weight, 'Birth Weight', s.birthWeight.isNotEmpty ? '${s.birthWeight} kg' : 'Unknown'),
      _infoRow(Icons.wc, 'Sex', s.sex.isNotEmpty ? s.sex : 'Unknown'),
    ]);
  }

  Widget _buildMaternalInformationSection() {
    final s = UserSession.instance;
    final p = s.patientData ?? {};
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Personal Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),
          _infoRow(Icons.person, 'Full Name', s.fullName),
          const Divider(height: 20),
          _infoRow(Icons.calendar_today, 'Date of Birth', s.formattedDateOfBirth),
          const Divider(height: 20),
          _infoRow(Icons.home, 'Address', s.address),
          const Divider(height: 20),
          _infoRow(Icons.phone, 'Phone', s.phone),
          const Divider(height: 20),
          _infoRow(Icons.email, 'Email', s.email),
          const Divider(height: 20),
          _infoRow(Icons.pregnant_woman, 'Spouse Name', p['spouse_name']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.family_restroom, 'Family Serial Number', p['family_serial_number']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.money, 'Monthly Income',
            p['monthly_income'] != null ? '₱${double.tryParse(p['monthly_income'].toString())?.toStringAsFixed(2) ?? '0.00'}' : 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.child_care, 'Living Children', p['living_children_count']?.toString() ?? '0'),
          const Divider(height: 20),
          _infoRow(Icons.school, 'Education', p['education']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.work, 'Occupation', p['occupation']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.church, 'Religion', p['religion']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.location_city, 'City', p['city']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.map, 'Province', p['province']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.event, 'Age', p['age'] != null ? '${p['age']} years old' : 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.local_hospital, 'Birth Plan', p['facility_type']?.toString() ?? 'Not provided'),
          const Divider(height: 20),
          _infoRow(Icons.medical_services, 'Birth Attendant', p['birth_attendant']?.toString() ?? 'Not provided'),
        ],
      ),
    );
  }

  Widget _buildHealthRecordsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Health Records', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_healthRecords.isEmpty)
            const Text('No health records found')
          else
            ..._healthRecords.map((r) => _buildHealthRecordItem(r)),
        ],
      ),
    );
  }

  Widget _buildHealthRecordItem(Map<String, dynamic> record) {
    final serviceType = UserSession.instance.serviceType;
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(record['title'] ?? 'Untitled Record',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: serviceType == 'maternal' ? Colors.pink.shade100 : Colors.blue.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(record['record_type'] ?? 'General',
                      style: TextStyle(color: serviceType == 'maternal' ? Colors.pink : Colors.blue, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(record['description'] ?? 'No description',
                style: const TextStyle(color: Colors.black87, fontSize: 14)),
            if (record['diagnosis'] != null && record['diagnosis'].toString().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Diagnosis: ${record['diagnosis']}',
                  style: const TextStyle(color: Colors.red, fontSize: 14, fontWeight: FontWeight.w500)),
            ],
            const SizedBox(height: 8),
            Text('Date: ${_formatDate(record['date_recorded'] ?? record['created_at'] ?? '')}',
                style: const TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  String _formatDate(String s) {
    if (s.isEmpty) return 'Unknown date';
    try {
      final d = DateTime.parse(s);
      return '${d.month}/${d.day}/${d.year}';
    } catch (_) { return s; }
  }

  Widget _buildReferralHistorySection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Referral History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
              if (_referrals.isNotEmpty)
                TextButton.icon(
                  onPressed: _fetchReferrals,
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Refresh', style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(foregroundColor: Colors.blue, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
            ],
          ),
          const SizedBox(height: 15),
          if (_isLoadingReferrals)
            const Center(child: CircularProgressIndicator())
          else if (_referrals.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(Icons.medical_services, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  Text('No referrals found', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  const Text(
                    'Your referral history will appear here once referrals are created by healthcare providers.',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ── Reusable widgets ────────────────────────────────────────────────────────

  Widget _infoChip(String text, Color bg, Color color) {
    return Chip(
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      backgroundColor: bg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    );
  }

  Widget _sectionCard({required String title, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    final serviceType = UserSession.instance.serviceType;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: serviceType == 'maternal' ? Colors.pink : Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(color: Colors.black87)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Child Switcher Bar — shown at the top of the Health Card tab (immunization)
// =============================================================================

class _ChildSwitcherBar extends StatefulWidget {
  final VoidCallback onAddChild;
  final VoidCallback onActiveChildChanged;

  const _ChildSwitcherBar({
    required this.onAddChild,
    required this.onActiveChildChanged,
  });

  @override
  State<_ChildSwitcherBar> createState() => _ChildSwitcherBarState();
}

class _ChildSwitcherBarState extends State<_ChildSwitcherBar> {
  StreamSubscription<void>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = UserSession.instance.onActiveChildChanged.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session  = UserSession.instance;
    final children = session.children;
    final active   = session.activeChild;

    // Single child — show compact bar with just name + "Add another child" button
    if (children.length <= 1) {
      return Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.child_care, size: 18, color: Colors.blueAccent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                active?.childFullname ?? session.childName,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            TextButton.icon(
              onPressed: widget.onAddChild,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add child', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
          ],
        ),
      );
    }

    // Multiple children — show dropdown selector
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.child_care, size: 18, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => _showChildPicker(context, children, session),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent.shade100),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.blue.shade50,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            active?.childFullname ?? session.childName,
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.blueAccent),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (active?.ageLabel.isNotEmpty == true)
                            Text(active!.ageLabel, style: TextStyle(fontSize: 11, color: Colors.blue.shade400)),
                        ],
                      ),
                    ),
                    Icon(Icons.expand_more, size: 18, color: Colors.blueAccent.shade200),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: widget.onAddChild,
            icon: const Icon(Icons.add_circle_outline, color: Colors.blueAccent),
            tooltip: 'Add another child',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
        ],
      ),
    );
  }

  void _showChildPicker(
    BuildContext context,
    List<ChildRecord> children,
    UserSession session,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Select Child', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
              const Divider(height: 1),
              ...List.generate(children.length, (i) {
                final child   = children[i];
                final isActive = session.activeChild?.id == child.id;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isActive ? Colors.blueAccent : Colors.grey.shade200,
                    child: Text(
                      child.childFullname.isNotEmpty ? child.childFullname[0].toUpperCase() : '?',
                      style: TextStyle(color: isActive ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    ),
                  ),
                  title: Text(child.childFullname, style: TextStyle(fontWeight: isActive ? FontWeight.bold : FontWeight.normal)),
                  subtitle: child.ageLabel.isNotEmpty ? Text(child.ageLabel) : null,
                  trailing: isActive ? const Icon(Icons.check_circle, color: Colors.blueAccent) : null,
                  onTap: () {
                    Navigator.pop(context);
                    session.setActiveChildByIndex(i);
                    widget.onActiveChildChanged();
                  },
                );
              }),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.green,
                  child: Icon(Icons.add, color: Colors.white),
                ),
                title: const Text('Add another child', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(context);
                  widget.onAddChild();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

// =============================================================================
// Add Child Sheet — modal bottom sheet for adding a new child
// =============================================================================

class _AddChildSheet extends StatefulWidget {
  const _AddChildSheet();

  @override
  State<_AddChildSheet> createState() => _AddChildSheetState();
}

class _AddChildSheetState extends State<_AddChildSheet> {
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _dobCtrl        = TextEditingController();
  final _placeCtrl      = TextEditingController();
  final _addressCtrl    = TextEditingController();

  String _sex           = 'Male';
  DateTime? _pickedDob;
  bool _saving          = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill address from parent account
    _addressCtrl.text = UserSession.instance.address;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _dobCtrl.dispose();
    _placeCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now.subtract(const Duration(days: 365 * 5)),
      lastDate: now,
      helpText: "Select Child's Date of Birth",
    );
    if (picked != null) {
      setState(() {
        _pickedDob = picked;
        _dobCtrl.text =
            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final userId = int.tryParse(UserSession.instance.userId) ?? 0;
      final child  = await ChildrenService.addChild(
        userId:        userId,
        childFullname: _nameCtrl.text.trim(),
        dob:           _dobCtrl.text.trim(),
        sex:           _sex,
        placeOfBirth:  _placeCtrl.text.trim(),
        address:       _addressCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, child);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        MessageUtils.showErrorMessage(context, e.toString().replaceFirst('Exception: ', ''), title: 'Add Child Failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Add Another Child',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                const Divider(),
                const SizedBox(height: 8),

                // Child's full name
                TextFormField(
                  controller: _nameCtrl,
                  decoration: _inputDeco("Child's Full Name *"),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Child's name is required";
                    // Emoji block
                    final emojiReg = RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true);
                    if (emojiReg.hasMatch(v)) return 'No emoji allowed in name';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Date of birth (date picker)
                TextFormField(
                  controller: _dobCtrl,
                  readOnly: true,
                  decoration: _inputDeco("Child's Date of Birth *", suffixIcon: Icons.calendar_today),
                  onTap: _pickedDob == null ? _pickDob : null,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return "Date of birth is required";
                    if (_pickedDob == null) return "Please use the date picker";
                    final cutoff = DateTime.now().subtract(const Duration(days: 365 * 5));
                    if (_pickedDob!.isBefore(cutoff)) {
                      return "Child must be under 5 years old for immunization records";
                    }
                    return null;
                  },
                  onChanged: (_) {},
                ),
                if (_dobCtrl.text.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: TextButton(
                      onPressed: _pickDob,
                      child: const Text('Tap to select date'),
                    ),
                  ),
                const SizedBox(height: 14),

                // Sex
                DropdownButtonFormField<String>(
                  value: _sex,
                  decoration: _inputDeco('Sex *'),
                  items: const [
                    DropdownMenuItem(value: 'Male',   child: Text('Male')),
                    DropdownMenuItem(value: 'Female', child: Text('Female')),
                  ],
                  onChanged: (v) => setState(() => _sex = v ?? 'Male'),
                  validator: (v) => v == null ? 'Please select sex' : null,
                ),
                const SizedBox(height: 14),

                // Place of birth
                TextFormField(
                  controller: _placeCtrl,
                  decoration: _inputDeco('Place of Birth *'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Place of birth is required';
                    final emojiReg = RegExp(r'[\u{1F000}-\u{1FFFF}]', unicode: true);
                    if (emojiReg.hasMatch(v)) return 'No emoji allowed';
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Address (pre-filled, editable)
                TextFormField(
                  controller: _addressCtrl,
                  decoration: _inputDeco('Address'),
                  maxLines: 2,
                ),
                const SizedBox(height: 24),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: _saving
                        ? const SizedBox(width: 20, height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Add Child', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String label, {IconData? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      suffixIcon: suffixIcon != null ? Icon(suffixIcon) : null,
    );
  }
}
