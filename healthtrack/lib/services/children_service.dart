import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_config.dart';
import 'user_session_storage.dart';

/// Represents a single child record (patients table row).
class ChildRecord {
  final int id;
  final int userId;
  final int childSortOrder;
  final String childFullname;
  final String motherFullname;
  final String fatherFullname;
  final String? dob;
  final bool dobNeedsVerification;
  final String placeOfBirth;
  final String birthWeight;
  final String birthHeight;
  final String sex;
  final String address;
  final String serviceType;
  final String status;
  final String healthCenter;
  final String barangay;
  final String familyNumber;
  final String ageLabel;

  const ChildRecord({
    required this.id,
    required this.userId,
    required this.childSortOrder,
    required this.childFullname,
    required this.motherFullname,
    required this.fatherFullname,
    this.dob,
    required this.dobNeedsVerification,
    required this.placeOfBirth,
    required this.birthWeight,
    required this.birthHeight,
    required this.sex,
    required this.address,
    required this.serviceType,
    required this.status,
    required this.healthCenter,
    required this.barangay,
    required this.familyNumber,
    required this.ageLabel,
  });

  factory ChildRecord.fromJson(Map<String, dynamic> j) {
    return ChildRecord(
      id:                   _parseInt(j['id']),
      userId:               _parseInt(j['user_id']),
      childSortOrder:       _parseInt(j['child_sort_order']),
      childFullname:        j['child_fullname']?.toString()  ?? '',
      motherFullname:       j['mother_fullname']?.toString() ?? '',
      fatherFullname:       j['father_fullname']?.toString() ?? '',
      dob:                  j['dob']?.toString(),
      dobNeedsVerification: j['dob_needs_verification'] == true || j['dob_needs_verification'] == 1,
      placeOfBirth:         j['place_of_birth']?.toString()  ?? '',
      birthWeight:          j['birth_weight']?.toString()    ?? '',
      birthHeight:          j['birth_height']?.toString()    ?? '',
      sex:                  j['sex']?.toString()             ?? '',
      address:              j['address']?.toString()         ?? '',
      serviceType:          j['service_type']?.toString()    ?? 'immunization',
      status:               j['status']?.toString()          ?? 'active',
      healthCenter:         j['health_center']?.toString()   ?? '',
      barangay:             j['barangay']?.toString()         ?? '',
      familyNumber:         j['family_number']?.toString()   ?? '',
      ageLabel:             j['age_label']?.toString()        ?? '',
    );
  }

  /// Converts back to a session-compatible patientData map so
  /// UserSession can be seeded with an active child's data.
  Map<String, dynamic> toPatientDataMap() => {
    'id':                  id,
    'user_id':             userId,
    'child_sort_order':    childSortOrder,
    'child_fullname':      childFullname,
    'mother_fullname':     motherFullname,
    'father_fullname':     fatherFullname,
    'dob':                 dob ?? '',
    'dob_needs_verification': dobNeedsVerification ? 1 : 0,
    'place_of_birth':      placeOfBirth,
    'birth_weight':        birthWeight,
    'birth_height':        birthHeight,
    'sex':                 sex,
    'address':             address,
    'service_type':        serviceType,
    'status':              status,
    'health_center':       healthCenter,
    'barangay':            barangay,
    'family_number':       familyNumber,
  };

  static int _parseInt(dynamic v) {
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? 0;
  }
}

/// Service for the /children API endpoints.
class ChildrenService {
  static List<String> get _urls => ApiConfig.fallbackBaseUrls;

  static Future<Map<String, String>> _headers() async {
    final token = await UserSessionStorage.getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static bool _isOk(Map<String, dynamic> body) {
    final s = body['success'];
    if (s is bool) return s;
    if (s is int) return s == 1;
    if (s is String) return s.toLowerCase() == 'true';
    return false;
  }

  // ── GET /children/user/:userId ─────────────────────────────────────────────

  /// Returns all children for a parent user account, ordered by child_sort_order.
  static Future<List<ChildRecord>> getChildren(int userId) async {
    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.get(
          Uri.parse('$base/children/user/$userId'),
          headers: await _headers(),
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          final body = json.decode(response.body) as Map<String, dynamic>;
          if (_isOk(body)) {
            final raw = body['data'];
            if (raw is List) {
              return raw
                  .whereType<Map<String, dynamic>>()
                  .map(ChildRecord.fromJson)
                  .toList();
            }
          }
          last = Exception(body['message'] ?? 'Failed to load children');
        } else {
          last = Exception('HTTP ${response.statusCode}: get children');
        }
      } catch (e) {
        last = Exception('Get children failed: $e');
      }
    }
    throw last ?? Exception('Failed to load children');
  }

  // ── POST /children ─────────────────────────────────────────────────────────

  /// Adds a new child to a parent account.
  /// Returns the new [ChildRecord] on success, or throws on failure.
  static Future<ChildRecord> addChild({
    required int userId,
    required String childFullname,
    required String dob,
    required String sex,
    required String placeOfBirth,
    String address = '',
    String birthWeight = '',
    String birthHeight = '',
    String healthCenter = '',
    String barangay = '',
    String familyNumber = '',
  }) async {
    final payload = {
      'user_id':        userId,
      'child_fullname': childFullname.trim(),
      'dob':            dob,
      'sex':            sex,
      'place_of_birth': placeOfBirth.trim(),
      if (address.isNotEmpty)       'address':       address.trim(),
      if (birthWeight.isNotEmpty)   'birth_weight':  birthWeight.trim(),
      if (birthHeight.isNotEmpty)   'birth_height':  birthHeight.trim(),
      if (healthCenter.isNotEmpty)  'health_center': healthCenter.trim(),
      if (barangay.isNotEmpty)      'barangay':      barangay.trim(),
      if (familyNumber.isNotEmpty)  'family_number': familyNumber.trim(),
    };

    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.post(
          Uri.parse('$base/children'),
          headers: await _headers(),
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 15));

        final body = json.decode(response.body) as Map<String, dynamic>;
        if ((response.statusCode == 200 || response.statusCode == 201) && _isOk(body)) {
          final data = body['data'] as Map<String, dynamic>;
          return ChildRecord.fromJson(data);
        }
        last = Exception(body['message']?.toString() ?? 'Failed to add child');
        // Don't retry on validation errors
        if (response.statusCode == 400 || response.statusCode == 403) throw last;
      } catch (e) {
        if (e == last) rethrow;
        last = Exception('Add child request failed: $e');
      }
    }
    throw last ?? Exception('Failed to add child');
  }

  // ── PATCH /children/:childId ───────────────────────────────────────────────

  /// Updates a child record's fields (partial update).
  static Future<ChildRecord> updateChild({
    required int childId,
    String? childFullname,
    String? dob,
    String? sex,
    String? placeOfBirth,
    String? address,
    String? birthWeight,
    String? birthHeight,
  }) async {
    final payload = <String, dynamic>{};
    if (childFullname != null && childFullname.isNotEmpty) payload['child_fullname'] = childFullname.trim();
    if (dob != null && dob.isNotEmpty)                     payload['dob']            = dob;
    if (sex != null && sex.isNotEmpty)                     payload['sex']            = sex;
    if (placeOfBirth != null && placeOfBirth.isNotEmpty)   payload['place_of_birth'] = placeOfBirth.trim();
    if (address != null && address.isNotEmpty)             payload['address']        = address.trim();
    if (birthWeight != null && birthWeight.isNotEmpty)     payload['birth_weight']   = birthWeight.trim();
    if (birthHeight != null && birthHeight.isNotEmpty)     payload['birth_height']   = birthHeight.trim();

    Exception? last;
    for (final base in _urls) {
      try {
        final response = await http.patch(
          Uri.parse('$base/children/$childId'),
          headers: await _headers(),
          body: json.encode(payload),
        ).timeout(const Duration(seconds: 10));

        final body = json.decode(response.body) as Map<String, dynamic>;
        if (response.statusCode == 200 && _isOk(body)) {
          return ChildRecord.fromJson(body['data'] as Map<String, dynamic>);
        }
        last = Exception(body['message']?.toString() ?? 'Failed to update child');
        if (response.statusCode == 400 || response.statusCode == 403 || response.statusCode == 404) {
          throw last;
        }
      } catch (e) {
        if (e == last) rethrow;
        last = Exception('Update child failed: $e');
      }
    }
    throw last ?? Exception('Failed to update child');
  }
}
