import 'dart:async';
import 'children_service.dart';

class UserSession {
  static UserSession? _instance;
  UserSession._internal();

  static UserSession get instance {
    _instance ??= UserSession._internal();
    return _instance!;
  }

  // ── Core data ──────────────────────────────────────────────────────────────
  Map<String, dynamic>? _userData;
  Map<String, dynamic>? _patientData;   // always mirrors the active child

  // ── Multi-child state ──────────────────────────────────────────────────────
  /// All children for this parent account, ordered by child_sort_order.
  List<ChildRecord> _children = [];

  /// Index into [_children] for the currently selected child.
  /// -1 means no children loaded yet.
  int _activeChildIndex = 0;

  // ── Streams ────────────────────────────────────────────────────────────────
  final StreamController<void> _notificationCountController =
      StreamController<void>.broadcast();
  Stream<void> get onNotificationCountChanged =>
      _notificationCountController.stream;

  /// Fires whenever the active child changes (switcher selection).
  final StreamController<void> _activeChildChangedController =
      StreamController<void>.broadcast();
  Stream<void> get onActiveChildChanged =>
      _activeChildChangedController.stream;

  // ── Getters — user ─────────────────────────────────────────────────────────
  Map<String, dynamic>? get userData    => _userData;
  Map<String, dynamic>? get patientData => _patientData;
  bool get isLoggedIn => _userData != null;

  String get userId      => _userData?['id']?.toString()           ?? '';
  String get username    => _userData?['username']?.toString()      ?? '';
  String get fullName    => _userData?['full_name']?.toString()     ?? '';
  String get email       => _userData?['email']?.toString()         ?? '';
  String get phone       => _userData?['phone']?.toString()         ?? '';
  String get address     => _userData?['address']?.toString()       ?? '';
  String get serviceType => _userData?['service_type']?.toString()  ?? 'immunization';

  // ── Getters — active child (delegates to _patientData for compat) ──────────
  String get patientId    => _patientData?['id']?.toString() ?? '';
  String get childName    => _patientData?['child_fullname']?.toString()
                          ?? _patientData?['child_name']?.toString()
                          ?? 'Unknown Child';
  String get motherName   => _patientData?['mother_fullname']?.toString()
                          ?? _patientData?['mother_name']?.toString()
                          ?? 'Unknown Mother';
  String get fatherName   => _patientData?['father_fullname']?.toString()
                          ?? _patientData?['father_name']?.toString()
                          ?? '';
  String get dateOfBirth  => _patientData?['dob']?.toString()
                          ?? _patientData?['date_of_birth']?.toString()
                          ?? '';
  String get placeOfBirth => _patientData?['place_of_birth']?.toString() ?? '';
  String get birthWeight  => _patientData?['birth_weight']?.toString()   ?? '';
  String get birthHeight  => _patientData?['birth_height']?.toString()   ?? '';
  String get sex          => _patientData?['sex']?.toString()             ?? '';
  String get patientAddress => _patientData?['address']?.toString()      ?? '';
  String get patientStatus  => _patientData?['status']?.toString()       ?? 'active';

  // ── Multi-child getters ────────────────────────────────────────────────────
  List<ChildRecord> get children => List.unmodifiable(_children);
  int get childCount => _children.length;
  bool get hasMultipleChildren => _children.length > 1;

  /// The currently active child as a [ChildRecord], or null if none loaded.
  ChildRecord? get activeChild {
    if (_children.isEmpty) return null;
    final idx = _activeChildIndex.clamp(0, _children.length - 1);
    return _children[idx];
  }

  // ── Setters ────────────────────────────────────────────────────────────────

  void setUserData(Map<String, dynamic> userData) {
    _userData = userData;
    print('👤 User session set: ${userData['username']?.toString() ?? 'Unknown'}');
  }

  void setPatientData(Map<String, dynamic> patientData) {
    _patientData = patientData;
    final name = patientData['child_fullname']?.toString()
               ?? patientData['child_name']?.toString()
               ?? 'Unknown Child';
    print('👶 Patient data set: $name');
  }

  /// Loads the full children list from the login response and sets the
  /// active child to the first one (primary child, child_sort_order = 0).
  ///
  /// Call this from login / session restore with the `children` array
  /// returned by POST /auth/login.
  void setChildren(List<dynamic> rawList) {
    final parsed = rawList
        .whereType<Map<String, dynamic>>()
        .map(ChildRecord.fromJson)
        .toList();

    _children = parsed;
    _activeChildIndex = 0;

    if (_children.isNotEmpty) {
      _patientData = _children[0].toPatientDataMap();
      print('👶 Children loaded: ${_children.length} child(ren). Active: ${_children[0].childFullname}');
    }
  }

  /// Adds a newly created child to the local list and makes it the active child.
  void addChild(ChildRecord child) {
    _children = [..._children, child];
    _activeChildIndex = _children.length - 1;
    _patientData = child.toPatientDataMap();
    _activeChildChangedController.add(null);
    print('👶 New child added to session: ${child.childFullname}');
  }

  /// Switches the active child to [index] and updates [_patientData].
  /// Fires [onActiveChildChanged] so any listening widget can rebuild.
  void setActiveChildByIndex(int index) {
    if (_children.isEmpty) return;
    final clamped = index.clamp(0, _children.length - 1);
    if (clamped == _activeChildIndex) return; // no change
    _activeChildIndex = clamped;
    _patientData = _children[clamped].toPatientDataMap();
    _activeChildChangedController.add(null);
    print('👶 Active child switched to: ${_children[clamped].childFullname}');
  }

  /// Switches by child ID.
  void setActiveChildById(int childId) {
    final idx = _children.indexWhere((c) => c.id == childId);
    if (idx >= 0) setActiveChildByIndex(idx);
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Age label for the active child (e.g. "6 months old" / "2 years old").
  String get childAge {
    if (dateOfBirth.isEmpty) return 'Unknown';
    try {
      final birth = DateTime.parse(dateOfBirth);
      final now   = DateTime.now();
      int years   = now.year  - birth.year;
      int months  = now.month - birth.month;
      if (months < 0) { years--; months += 12; }
      if (years > 0) return '$years yr${years == 1 ? '' : 's'} old';
      return '$months month${months == 1 ? '' : 's'} old';
    } catch (_) {
      return 'Unknown';
    }
  }

  String get formattedDateOfBirth {
    if (dateOfBirth.isEmpty) return 'Unknown';
    try {
      final d = DateTime.parse(dateOfBirth);
      const months = ['Jan','Feb','Mar','Apr','May','Jun',
                      'Jul','Aug','Sep','Oct','Nov','Dec'];
      return '${months[d.month - 1]} ${d.day}, ${d.year}';
    } catch (_) {
      return dateOfBirth;
    }
  }

  String get displayPatientId {
    if (patientId.isEmpty) return 'HC-UNKNOWN';
    return 'HC-2025-${patientId.padLeft(4, '0')}';
  }

  // ── Notification helpers ───────────────────────────────────────────────────
  void notifyNotificationCountChanged() {
    _notificationCountController.add(null);
  }

  // ── Session management ─────────────────────────────────────────────────────
  void clearSession() {
    _userData      = null;
    _patientData   = null;
    _children      = [];
    _activeChildIndex = 0;
    print('🚪 User session cleared');
  }

  void printSessionInfo() {
    print('=== USER SESSION INFO ===');
    print('User ID: $userId');
    print('Username: $username');
    print('Full Name: $fullName');
    print('Children: ${_children.length}');
    print('Active child: $childName (ID: $patientId)');
    print('Service Type: $serviceType');
    print('========================');
  }

  void dispose() {
    _notificationCountController.close();
    _activeChildChangedController.close();
  }
}
