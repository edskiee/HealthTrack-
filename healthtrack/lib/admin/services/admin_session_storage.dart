import 'package:shared_preferences/shared_preferences.dart';

/// Persists opaque admin Bearer token returned by `/admin/login`.
///
/// Browser localStorage key: `flutter.healthtrack_admin_bearer_token`
/// (SharedPreferences adds the `flutter.` prefix on web).
class AdminSessionStorage {
  AdminSessionStorage._();

  static const _tokenKey = 'healthtrack_admin_bearer_token';
  static String? _cached;

  /// Preload token from persistent storage into memory (call at app startup).
  static Future<void> warmUp() async {
    await getToken();
  }

  static Future<void> setToken(String? token) async {
    final normalized = token?.trim();
    _cached = (normalized != null && normalized.isNotEmpty) ? normalized : null;
    final p = await SharedPreferences.getInstance();
    if (_cached == null) {
      await p.remove(_tokenKey);
    } else {
      await p.setString(_tokenKey, _cached!);
    }
  }

  static Future<String?> getToken() async {
    final mem = _cached;
    if (mem != null && mem.isNotEmpty) return mem;
    final p = await SharedPreferences.getInstance();
    final stored = p.getString(_tokenKey)?.trim();
    _cached = (stored != null && stored.isNotEmpty) ? stored : null;
    return _cached;
  }

  /// JSON headers for admin-protected API calls.
  /// Throws if [required] and no token is available.
  static Future<Map<String, String>> authHeaders({bool required = true}) async {
    final token = await getToken();
    // DEBUG — remove once 401s are resolved
    print('Token loaded: ${token == null ? "null" : token.isEmpty ? "empty" : "${token.substring(0, token.length.clamp(0, 12))}..."}');

    if (required && (token == null || token.isEmpty)) {
      throw Exception(
        'Admin session token missing. Please log in again. '
        '(expected key: $_tokenKey / flutter.$_tokenKey in browser localStorage)',
      );
    }

    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<void> clear() async => setToken(null);
}
