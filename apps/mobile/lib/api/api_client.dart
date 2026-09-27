/// Typed REST client — consumes the exact contract in src/lib/api.ts
/// (the NestJS API implements the same routes). Base URL from
/// `--dart-define=SUNNAH_API_BASE` (default https://sunnahlife.app).
/// Guest mode = local-only; the client is simply never called until sign-in.
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/domain.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message);
  final int status;
  final String message;

  @override
  String toString() => message;
}

class OtpResponse {
  const OtpResponse({required this.ok, this.devCode});
  final bool ok;
  final String? devCode;
}

class VerifyResponse {
  const VerifyResponse({required this.user, this.token});
  final User user;
  final String? token;
}

class AppConfig {
  const AppConfig({
    required this.donationUrl,
    required this.domain,
    required this.hijriAdjust,
    required this.goldPerGramBdt,
    required this.silverPerGramBdt,
  });
  final String donationUrl;
  final String domain;
  final int hijriAdjust;
  final double goldPerGramBdt;
  final double silverPerGramBdt;

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final nisab = (j['nisab'] as Map<String, dynamic>?) ?? const {};
    return AppConfig(
      donationUrl: j['donationUrl'] as String? ?? '',
      domain: j['domain'] as String? ?? 'sunnahlife.app',
      hijriAdjust: (j['hijriAdjust'] as num?)?.toInt() ?? 0,
      goldPerGramBdt: (nisab['goldPerGramBdt'] as num?)?.toDouble() ?? 0,
      silverPerGramBdt: (nisab['silverPerGramBdt'] as num?)?.toDouble() ?? 0,
    );
  }
}

class SurahBrief {
  const SurahBrief({
    required this.number,
    required this.name,
    required this.nameBn,
    required this.englishName,
    required this.ayahCount,
    required this.revelationType,
  });
  final int number;
  final String name;
  final String nameBn;
  final String englishName;
  final int ayahCount;
  final String revelationType;
}

class ApiClient {
  ApiClient({http.Client? innerClient}) : _inner = innerClient ?? http.Client();

  /// Closes the inner HTTP client (riverpod onDispose).
  void dispose() => _inner.close();

  static const String baseUrl = String.fromEnvironment(
    'SUNNAH_API_BASE',
    defaultValue: 'https://sunnahlife.app',
  );

  final http.Client _inner;
  String? _token;

  /// Bearer token (OTP-issued). Seams: cookie sessions also accepted by the
  /// server; http keeps no cookie jar by design.
  set token(String? value) => _token = value;

  /// Fired on any 401: the session is dead — providers use this to clear
  /// the persisted token and drop back to guest mode.
  void Function()? onUnauthorized;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  Future<Map<String, dynamic>> _req(
    String method,
    String path, {
    Object? body,
    Map<String, String>? query,
  }) async {
    Uri uri;
    if (baseUrl.startsWith('http')) {
      uri = Uri.parse(baseUrl);
    } else {
      uri = Uri.parse('https://$baseUrl');
    }
    uri = uri.replace(
      path: path,
      queryParameters: (query?.isEmpty ?? true) ? null : query,
    );
    http.Response res;
    try {
      final request = http.Request(method, uri)..headers.addAll(_headers);
      if (body != null) request.body = jsonEncode(body);
      res = await http.Response.fromStream(
        await _inner.send(request).timeout(const Duration(seconds: 20)),
      );
    } catch (e) {
      throw ApiException(0, 'নেটওয়ার্ক সমস্যা — $e');
    }
    Map<String, dynamic> decoded;
    try {
      final parsed = jsonDecode(utf8.decode(res.bodyBytes));
      decoded = parsed is Map<String, dynamic> ? parsed : <String, dynamic>{};
    } catch (_) {
      decoded = const {};
    }
    if (res.statusCode == 401) {
      // Session expired/revoked: drop the token, then notify the host.
      _token = null;
      onUnauthorized?.call();
    }
    if (res.statusCode >= 400) {
      throw ApiException(
        res.statusCode,
        decoded['error'] as String? ??
            decoded['message'] as String? ??
            'রিকোয়েস্ট ব্যর্থ (${res.statusCode})',
      );
    }
    return decoded;
  }

  // ── Auth ────────────────────────────────────────────────────────────────────

  Future<OtpResponse> requestOtp(String phone) async {
    final j = await _req(
      'POST',
      '/api/auth/otp/request',
      body: {'phone': phone},
    );
    return OtpResponse(
      ok: j['ok'] as bool? ?? false,
      devCode: j['devCode'] as String?,
    );
  }

  Future<VerifyResponse> verifyOtp({
    required String phone,
    required String code,
    String? name,
    Gender? gender,
    String? referredByCode,
    List<AmalEntry>? guestEntries,
  }) async {
    final j = await _req(
      'POST',
      '/api/auth/otp/verify',
      body: {
        'phone': phone,
        'code': code,
        if (name != null && name.isNotEmpty) 'name': name,
        if (gender != null) 'gender': gender.json,
        if (referredByCode != null && referredByCode.isNotEmpty)
          'referredByCode': referredByCode,
        if (guestEntries != null && guestEntries.isNotEmpty)
          'guestEntries': guestEntries.map((e) => e.toJson()).toList(),
      },
    );
    return VerifyResponse(
      user: User.fromJson(j['user'] as Map<String, dynamic>),
      token: j['token'] as String?,
    );
  }

  Future<void> logout() async {
    await _req('POST', '/api/auth/logout');
    _token = null;
  }

  Future<User?> me() async {
    final j = await _req('GET', '/api/me');
    final user = j['user'];
    return user is Map<String, dynamic> ? User.fromJson(user) : null;
  }

  Future<User> updateMe(Map<String, dynamic> patch) async {
    final j = await _req('PATCH', '/api/me', body: patch);
    return User.fromJson(j['user'] as Map<String, dynamic>);
  }

  // ── Config ─────────────────────────────────────────────────────────────────

  Future<AppConfig> config() async =>
      AppConfig.fromJson(await _req('GET', '/api/config'));

  // ── Amal ────────────────────────────────────────────────────────────────────

  Future<List<AmalDefinition>> amalDefinitions() async {
    final j = await _req('GET', '/api/amal/definitions');
    return ((j['definitions'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => AmalDefinition.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<List<AmalEntry>> amalEntries(String from, String to) async {
    final j = await _req(
      'GET',
      '/api/amal/entries',
      query: {'from': from, 'to': to},
    );
    return ((j['entries'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => AmalEntry.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<AmalUpsertResult> amalUpsert(List<AmalEntry> entries) async {
    final j = await _req(
      'POST',
      '/api/amal/entries',
      body: {'entries': entries.map((e) => e.toJson()).toList()},
    );
    return AmalUpsertResult.fromJson(j);
  }

  Future<void> amalUnlock(String userId, String date, {String? reason}) => _req(
    'POST',
    '/api/amal/unlock',
    body: {
      'userId': userId,
      'date': date,
      'reason': ?reason,
    },
  );

  // ── Dawah engine ────────────────────────────────────────────────────────────

  Future<DawahOverview> dawahOverview() async =>
      DawahOverview.fromJson(await _req('GET', '/api/dawah'));

  Future<(Usrah?, List<Announcement>)> usrah() async {
    final j = await _req('GET', '/api/usrah');
    final usrahRaw = j['usrah'];
    final usrah = usrahRaw is Map<String, dynamic>
        ? Usrah.fromJson(usrahRaw)
        : null;
    final announcements = ((j['announcements'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Announcement.fromJson(e.cast<String, dynamic>()))
        .toList();
    return (usrah, announcements);
  }

  Future<List<WeeklyReview>> reviews() async {
    final j = await _req('GET', '/api/reviews');
    return ((j['reviews'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => WeeklyReview.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  // ── Reminders / live / misc ─────────────────────────────────────────────────

  Future<List<ReminderItem>> reminders() async {
    final j = await _req('GET', '/api/reminders');
    return ((j['reminders'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ReminderItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> readReminder(String id) =>
      _req('PATCH', '/api/reminders', body: {'id': id});

  Future<List<LiveProgramItem>> live() async {
    final j = await _req('GET', '/api/live');
    return ((j['programs'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => LiveProgramItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  Future<void> notifyLive(String id) =>
      _req('POST', '/api/live', body: {'id': id});

  Future<void> masala({
    required String name,
    String? phone,
    required String question,
  }) => _req(
    'POST',
    '/api/masala',
    body: {
      'name': name,
      'phone': ?phone,
      'question': question,
    },
  );

  Future<void> feedback(String message) =>
      _req('POST', '/api/feedback', body: {'message': message});

  // ── Push (B2) — device token registration ────────────────────────────────────

  /// Register/refresh the FCM token (upserts per user+token server-side).
  Future<void> registerPushToken({
    required String token,
    required String platform,
  }) => _req(
    'POST',
    '/api/push/token',
    body: {'token': token, 'platform': platform},
  );

  /// Remove one device token (sign-out on this device).
  Future<void> unregisterPushToken(String token) =>
      _req('DELETE', '/api/push/token', body: {'token': token});

  // ── Quran (server mirror — the bundled pack is the offline fallback) ────────

  Future<List<SurahBrief>> quranSurahs() async {
    final j = await _req('GET', '/api/quran/surahs');
    return ((j['surahs'] as List?) ?? [])
        .whereType<Map>()
        .map(
          (e) => SurahBrief(
            number: (e['number'] as num?)?.toInt() ?? 0,
            name: e['name'] as String? ?? '',
            nameBn: e['nameBn'] as String? ?? '',
            englishName: e['englishName'] as String? ?? '',
            ayahCount: (e['ayahCount'] as num?)?.toInt() ?? 0,
            revelationType: e['revelationType'] as String? ?? '',
          ),
        )
        .toList();
  }
}
