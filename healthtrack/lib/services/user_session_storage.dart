import 'package:shared_preferences/shared_preferences.dart';

/// Persists the user JWT Bearer token returned by `/auth/login`.
/// Mirrors the pattern of AdminSessionStorage.
class UserSessionStorage {
  UserSessionStorage._();

  static const _tokenKey = 'healthtrack_user_bearer_token';
  static String? _cached;

  static Future<void> setToken(String? token) async {
    _cached = token;
    final p = await SharedPreferences.getInstance();
    if (token == null || token.isEmpty) {
      await p.remove(_tokenKey);
    } else {
      await p.setString(_tokenKey, token);
    }
  }

  static Future<String?> getToken() async {
    final mem = _cached;
    if (mem != null && mem.isNotEmpty) return mem;
    final p = await SharedPreferences.getInstance();
    _cached = p.getString(_tokenKey);
    return _cached;
  }

  static Future<void> clear() async => setToken(null);
}
