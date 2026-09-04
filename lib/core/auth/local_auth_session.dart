import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LocalAuthSession {
  LocalAuthSession._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _tokenKey = 'fth_access_token';
  static const String _userIdKey = 'fth_user_id';
  static const String _emailKey = 'fth_email';
  static const String _roleKey = 'fth_role';
  static const String _displayNameKey = 'fth_display_name';

  // Keeps the active session usable even when a browser blocks WebCrypto-backed
  // flutter_secure_storage reads (common in some Chrome debug sessions).
  static final Map<String, String> _memory = <String, String>{};

  static Future<String?> accessToken() => _read(_tokenKey);
  static Future<String?> userId() => _read(_userIdKey);
  static Future<String?> email() => _read(_emailKey);
  static Future<String?> role() => _read(_roleKey);
  static Future<String?> displayName() => _read(_displayNameKey);

  static Future<String?> _read(String key) async {
    final String? cached = _memory[key];
    if (cached != null && cached.isNotEmpty) return cached;
    try {
      final String? value = await _storage.read(key: key);
      if (value != null && value.isNotEmpty) _memory[key] = value;
      return value;
    } catch (_) {
      // Never crash the whole Customer app because browser secure storage failed.
      return cached;
    }
  }

  static Future<bool> get hasToken async {
    final String token = (await accessToken())?.trim() ?? '';
    return token.isNotEmpty;
  }

  static Future<void> saveFromAuthResponse(Map<String, dynamic> data) async {
    final String token = (data['accessToken'] ?? data['token'] ?? '').toString().trim();
    if (token.isEmpty) {
      throw StateError('Backend did not return an access token.');
    }

    final Map<String, String> values = <String, String>{
      _tokenKey: token,
      _userIdKey: (data['userId'] ?? data['id'] ?? data['firebaseUid'] ?? '').toString(),
      _emailKey: (data['email'] ?? '').toString(),
      _roleKey: (data['role'] ?? 'CUSTOMER').toString(),
      _displayNameKey: (data['displayName'] ?? data['name'] ?? '').toString(),
    };
    _memory.addAll(values);

    // Persist best-effort. Runtime session remains valid from memory even if a
    // browser-specific secure-storage operation is unavailable.
    for (final MapEntry<String, String> entry in values.entries) {
      try {
        await _storage.write(key: entry.key, value: entry.value);
      } catch (_) {
        // Intentionally ignored; in-memory session prevents runtime crashes.
      }
    }
  }

  static Future<void> clear() async {
    _memory.clear();
    for (final String key in <String>[
      _tokenKey,
      _userIdKey,
      _emailKey,
      _roleKey,
      _displayNameKey,
    ]) {
      try {
        await _storage.delete(key: key);
      } catch (_) {
        // Logout must still complete even if browser storage is unavailable.
      }
    }
  }
}
