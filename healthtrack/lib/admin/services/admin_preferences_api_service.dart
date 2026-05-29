import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:healthtrack/admin/services/admin_session_storage.dart';
import 'package:healthtrack/services/api_config.dart';

class AdminPreferencesApiException implements Exception {
  final String message;
  final int? statusCode;
  AdminPreferencesApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class AdminPreferencesApi {
  AdminPreferencesApi._();

  static Future<Map<String, String>> _jsonHeaders() async {
    final token = await AdminSessionStorage.getToken();
    final h = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      h['Authorization'] = 'Bearer $token';
    }
    return h;
  }

  static List<String> get _bases => ApiConfig.fallbackBaseUrls;

  static Future<http.Response> _tryHttp(
      Future<http.Response> Function(String base) runner) async {
    Exception? last;
    final tried = <String>[ApiConfig.baseUrl, ..._bases];
    for (final base in tried) {
      if (base.isEmpty) continue;
      try {
        return await runner(base).timeout(const Duration(seconds: 12));
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last ??
        AdminPreferencesApiException('Unable to reach the HealthTrack server.');
  }

  static Future<Map<String, dynamic>> _decodeMap(http.Response r) async {
    if (r.statusCode >= 200 && r.statusCode < 300) {
      final data = json.decode(r.body);
      if (data is Map<String, dynamic>) return data;
    }
    String msg = 'Request failed (${r.statusCode}).';
    try {
      final decoded = json.decode(r.body);
      if (decoded is Map && decoded['message'] != null) {
        msg = decoded['message'].toString();
      }
    } catch (_) {}
    throw AdminPreferencesApiException(msg, r.statusCode);
  }

  static Future<Map<String, dynamic>> fetchPreferencesPayload() async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.get(Uri.parse('$b/admin/me/preferences'), headers: headers),
    );
    final body = await _decodeMap(res);
    if (body['success'] == true && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    throw AdminPreferencesApiException(
        body['message']?.toString() ?? 'Could not load preferences.');
  }

  static Future<void> patchPreferences(Map<String, dynamic> patch) async {
    if (patch.isEmpty) return;
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.patch(
        Uri.parse('$b/admin/me/preferences'),
        headers: headers,
        body: json.encode(patch),
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] != true) {
      throw AdminPreferencesApiException(
          body['message']?.toString() ?? 'Failed to save preferences.');
    }
  }

  static Future<List<dynamic>> fetchSessions() async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.get(Uri.parse('$b/admin/me/sessions'), headers: headers),
    );
    final body = await _decodeMap(res);
    if (body['success'] == true && body['data'] is List) {
      return body['data'] as List<dynamic>;
    }
    throw AdminPreferencesApiException('Could not load sessions.');
  }

  static Future<void> revokeSession(String sessionId) async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.delete(
        Uri.parse('$b/admin/me/sessions/$sessionId'),
        headers: headers,
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] != true) {
      throw AdminPreferencesApiException(
          body['message']?.toString() ?? 'Failed to revoke session.');
    }
  }

  static Future<void> logoutCurrentSession() async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.delete(Uri.parse('$b/admin/me/session'), headers: headers),
    );
    final body = await _decodeMap(res);
    if (body['success'] != true) {
      throw AdminPreferencesApiException(
          body['message']?.toString() ?? 'Sign out failed.');
    }
  }

  static Future<Map<String, dynamic>> fetchSystemMeta() async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.get(Uri.parse('$b/admin/meta/system'), headers: headers),
    );
    final body = await _decodeMap(res);
    if (body['success'] == true && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    throw AdminPreferencesApiException('Could not load system metadata.');
  }

  static Future<List<dynamic>> fetchAuditLogs({int limit = 100}) async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.get(
        Uri.parse('$b/admin/audit-logs?limit=$limit'),
        headers: headers,
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] == true && body['data'] is List) {
      return body['data'] as List<dynamic>;
    }
    throw AdminPreferencesApiException('Could not load audit logs.');
  }

  static Future<Map<String, dynamic>> startTwoFactorSetup() async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.post(
        Uri.parse('$b/admin/me/security/2fa/start'),
        headers: headers,
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] == true && body['data'] is Map<String, dynamic>) {
      return body['data'] as Map<String, dynamic>;
    }
    throw AdminPreferencesApiException(
        body['message']?.toString() ?? 'Could not start 2FA setup.');
  }

  static Future<void> confirmTwoFactor(String code) async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.post(
        Uri.parse('$b/admin/me/security/2fa/confirm'),
        headers: headers,
        body: json.encode({'code': code}),
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] != true) {
      throw AdminPreferencesApiException(
          body['message']?.toString() ?? 'Could not enable 2FA.');
    }
  }

  static Future<void> disableTwoFactor(String password) async {
    final headers = await _jsonHeaders();
    final res = await _tryHttp(
      (b) => http.post(
        Uri.parse('$b/admin/me/security/2fa/disable'),
        headers: headers,
        body: json.encode({'current_password': password}),
      ),
    );
    final body = await _decodeMap(res);
    if (body['success'] != true) {
      throw AdminPreferencesApiException(
          body['message']?.toString() ?? 'Could not disable 2FA.');
    }
  }

  static Future<String?> uploadAvatarFile(String absolutePath) async {
    final token = await AdminSessionStorage.getToken();
    Exception? last;
    final tried = [ApiConfig.baseUrl, ..._bases];
    for (final base in tried) {
      if (base.isEmpty) continue;
      final uri = Uri.parse('$base/admin/me/avatar');
      try {
        final mf = await http.MultipartFile.fromPath('avatar', absolutePath,
            filename: absolutePath.split(Platform.pathSeparator).last);
        final req = http.MultipartRequest('POST', uri)
          ..files.add(mf)
          ..headers['Accept'] = 'application/json';
        if (token != null && token.isNotEmpty) {
          req.headers['Authorization'] = 'Bearer $token';
        }
        final streamed = await req.send().timeout(const Duration(seconds: 30));
        final response = await http.Response.fromStream(streamed);
        final body = await _decodeMap(response);
        final data = body['data'];
        if (data is Map &&
            data['avatar_url'] != null &&
            data['avatar_url'].toString().isNotEmpty) {
          return data['avatar_url'].toString();
        }
        throw AdminPreferencesApiException(
            body['message']?.toString() ?? 'Avatar upload failed.');
      } catch (e) {
        last = e is Exception ? e : Exception(e.toString());
      }
    }
    throw last ??
        AdminPreferencesApiException(
            'Could not upload your profile photo — check your connection.');
  }

  static Future<Map<String, dynamic>> pingHealthDetailed() async {
    final bases = [ApiConfig.baseUrl, ..._bases];
    for (final base in bases) {
      try {
        final r = await http
            .get(Uri.parse('$base/health'), headers: const {
          'Accept': 'application/json',
        }).timeout(const Duration(seconds: 8));
        return {
          'ok': r.statusCode >= 200 && r.statusCode < 300,
          'status': r.statusCode,
          'body': r.body,
        };
      } catch (_) {}
    }
    return {'ok': false};
  }
}
