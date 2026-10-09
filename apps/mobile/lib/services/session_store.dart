/// Where the signed-in session lives on the phone: the access token (15
/// minutes), the refresh token (60 days, rotated on every refresh) and the
/// last known user, so the app opens signed in — even offline — instead of
/// asking for a code again.
///
/// Tokens go to the platform keystore (flutter_secure_storage: Android
/// Keystore / iOS Keychain), never to plain SharedPreferences, so they are
/// not readable from a backup. When the keystore is unavailable (widget
/// tests, an odd device) it falls back to SharedPreferences rather than
/// losing the session.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show debugPrint, visibleForTesting;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/domain.dart';

class StoredSession {
  const StoredSession({required this.access, this.refresh, this.user});
  final String access;
  final String? refresh;
  final User? user;
}

class SessionStore {
  SessionStore({FlutterSecureStorage? secure})
    : _secure = secure ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secure;

  /// A keystore that does not answer must not leave the app on its
  /// splash: after this, the plain-prefs fallback is used.
  static const _keystoreWait = Duration(seconds: 3);

  static const _kAccess = 'sl_access';
  static const _kRefresh = 'sl_refresh';
  static const _kUser = 'sl_user';

  /// Before 2026-10-09 the access token alone sat in SharedPreferences
  /// under this key (and expired 15 minutes later).
  static const legacyTokenKey = 'sl_token';

  /// Tests: skip the keystore entirely.
  @visibleForTesting
  static bool forcePrefsForTesting = false;

  Future<String?> _read(String key) async {
    if (!forcePrefsForTesting) {
      try {
        final v = await _secure.read(key: key).timeout(_keystoreWait);
        if (v != null) return v;
      } catch (e) {
        debugPrint('[session] keystore read failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('fallback_$key');
  }

  Future<void> _write(String key, String? value) async {
    if (!forcePrefsForTesting) {
      try {
        if (value == null) {
          await _secure.delete(key: key).timeout(_keystoreWait);
        } else {
          await _secure.write(key: key, value: value).timeout(_keystoreWait);
        }
        // keystore worked: no copy may linger in plain prefs
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('fallback_$key');
        return;
      } catch (e) {
        debugPrint('[session] keystore write failed: $e');
      }
    }
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove('fallback_$key');
    } else {
      await prefs.setString('fallback_$key', value);
    }
  }

  Future<StoredSession?> read() async {
    var access = await _read(_kAccess);
    if (access == null) {
      // an install from before the keystore: carry the old token over once
      final prefs = await SharedPreferences.getInstance();
      final legacy = prefs.getString(legacyTokenKey);
      if (legacy != null) {
        access = legacy;
        await _write(_kAccess, legacy);
        await prefs.remove(legacyTokenKey);
      }
    }
    if (access == null) return null;
    User? user;
    try {
      final raw = await _read(_kUser);
      if (raw != null) {
        user = User.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (_) {
      user = null; // an unreadable cache only costs the offline start
    }
    return StoredSession(
      access: access,
      refresh: await _read(_kRefresh),
      user: user,
    );
  }

  Future<void> saveTokens(String access, String? refresh) async {
    await _write(_kAccess, access);
    if (refresh != null) await _write(_kRefresh, refresh);
  }

  Future<void> saveUser(User user) =>
      _write(_kUser, jsonEncode(user.toJson()));

  Future<void> clear() async {
    await _write(_kAccess, null);
    await _write(_kRefresh, null);
    await _write(_kUser, null);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(legacyTokenKey);
  }
}
