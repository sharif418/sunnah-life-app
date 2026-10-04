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

/// A GET read with offline provenance (W4-fix4): [data] is the parsed
/// payload; [fetchedAt] is when it last came over the network; [stale] is
/// true when the network failed and this came from the local cache — the
/// UI then shows the offline banner + the "সর্বশেষ হালনাগাদ" stamp.
class ApiCached<T> {
  const ApiCached(this.data, {required this.fetchedAt, this.stale = false});
  final T data;
  final DateTime fetchedAt;
  final bool stale;
}

/// Pluggable last-good cache behind [ApiClient] (implemented over Drift in
/// lib/db/api_cache.dart; injected in providers.dart so tests stay
/// hermetic — a null store simply disables the offline path).
abstract class ApiCacheStore {
  Future<void> write(
    String key,
    Map<String, dynamic> payload,
    DateTime fetchedAt,
  );
  Future<({Map<String, dynamic> payload, DateTime fetchedAt})?> read(
    String key,
  );
}

/// The guest diary rows worth merging at sign-in: a real value (a cleared
/// tristate leaves '' / null behind) and a well-formed day. A bad row must
/// never ride along — older servers rejected the WHOLE sign-in for one.
List<Map<String, dynamic>> sendableGuestEntries(Iterable<AmalEntry> entries) => [
  for (final e in entries)
    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(e.date) &&
        switch (e.value) {
          final bool _ => true,
          final num n => n.isFinite,
          final String v => v.isNotEmpty && v.length <= 100,
          _ => false,
        })
      e.toJson(),
];

/// One of my মাসআলা questions (GET /api/masala/mine).
class MasalaItem {
  const MasalaItem({
    required this.id,
    required this.question,
    required this.status,
    this.answer,
    this.answeredAt,
    required this.createdAt,
  });
  final String id;
  final String question;
  final String status; // new | answered
  final String? answer;
  final String? answeredAt;
  final String createdAt;

  bool get answered => status == 'answered' && (answer ?? '').isNotEmpty;

  factory MasalaItem.fromJson(Map<String, dynamic> j) => MasalaItem(
    id: j['id'] as String? ?? '',
    question: j['question'] as String? ?? '',
    status: j['status'] as String? ?? 'new',
    answer: j['answer'] as String?,
    answeredAt: j['answeredAt'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
  );
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

/// GET /api/auth/providers — which social sign-in buttons to show
/// (env-driven on the server; all-false ⇒ hide the social section).
class AuthProviders {
  const AuthProviders({required this.google, required this.apple});
  final bool google;
  final bool apple;

  factory AuthProviders.fromJson(Map<String, dynamic> j) => AuthProviders(
    google: j['google'] as bool? ?? false,
    apple: j['apple'] as bool? ?? false,
  );
}

class ConfigContact {
  const ConfigContact({
    required this.org,
    required this.descBn,
    this.phone,
    this.email,
    this.website,
    this.address,
  });
  final String org;
  final String descBn;
  final String? phone;
  final String? email;
  final String? website;
  final String? address;

  factory ConfigContact.fromJson(Map<String, dynamic> j) => ConfigContact(
    org: j['org'] as String? ?? '',
    descBn: j['descBn'] as String? ?? '',
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    website: j['website'] as String?,
    address: j['address'] as String?,
  );
}

class ConfigGroup {
  const ConfigGroup({required this.titleBn, required this.url, this.descBn});
  final String titleBn;
  final String url;
  final String? descBn;

  factory ConfigGroup.fromJson(Map<String, dynamic> j) => ConfigGroup(
    titleBn: j['titleBn'] as String? ?? '',
    url: j['url'] as String? ?? '',
    descBn: j['descBn'] as String?,
  );
}

class AppConfig {
  const AppConfig({
    required this.donationUrl,
    required this.domain,
    required this.hijriAdjust,
    required this.goldPerGramBdt,
    required this.silverPerGramBdt,
    this.contacts = const [],
    this.groups = const [],
    this.audioBase = '',
    this.leaderboardEnabled = false,
    this.detoxEnabled = false,
  });
  final String donationUrl;
  final String domain;
  final int hijriAdjust;
  final double goldPerGramBdt;
  final double silverPerGramBdt;
  /// The five institutions (admin-editable) — the floating Contact panel.
  final List<ConfigContact> contacts;
  /// App-user group links (admin-editable) — the More tab section.
  final List<ConfigGroup> groups;
  /// Recitation audio base (per-ayah streaming, W3a).
  final String audioBase;
  /// Gender-scoped leaderboard — gated on the scholars' decision.
  final bool leaderboardEnabled;
  /// Social-media-detox reminders (Guard-module seed).
  final bool detoxEnabled;

  factory AppConfig.fromJson(Map<String, dynamic> j) {
    final nisab = (j['nisab'] as Map<String, dynamic>?) ?? const {};
    return AppConfig(
      donationUrl: j['donationUrl'] as String? ?? '',
      domain: j['domain'] as String? ?? 'sunnahlife.app',
      hijriAdjust: (j['hijriAdjust'] as num?)?.toInt() ?? 0,
      goldPerGramBdt: (nisab['goldPerGramBdt'] as num?)?.toDouble() ?? 0,
      silverPerGramBdt: (nisab['silverPerGramBdt'] as num?)?.toDouble() ?? 0,
      contacts: ((j['contacts'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ConfigContact.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      groups: ((j['groups'] as List?) ?? const [])
          .whereType<Map>()
          .map((e) => ConfigGroup.fromJson(e.cast<String, dynamic>()))
          .toList(growable: false),
      audioBase: j['audioBase'] as String? ?? '',
      leaderboardEnabled: j['leaderboardEnabled'] as bool? ?? false,
      detoxEnabled: j['detoxEnabled'] as bool? ?? false,
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
  ApiClient({http.Client? innerClient, this.cacheStore})
    : _inner = innerClient ?? http.Client();

  /// Closes the inner HTTP client (riverpod onDispose).
  void dispose() => _inner.close();

  static const String baseUrl = String.fromEnvironment(
    'SUNNAH_API_BASE',
    defaultValue: 'https://sunnahlife.app',
  );

  final http.Client _inner;

  /// Last-good cache for the offline-capable GET reads. Nullable — absent
  /// in tests that don't exercise the cache (and for pure guest use).
  final ApiCacheStore? cacheStore;
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

  /// Cached GET pipeline (W4-fix4): success overwrites the cache row for
  /// `key` and returns fresh; a NETWORK failure (status 0) serves the last
  /// good envelope with `stale: true` — and rethrows only when nothing was
  /// ever cached. A real server rejection (any 4xx/5xx) always rethrows:
  /// stale data must never mask a live refusal. `scope` (user id) keys the
  /// row so cached reads can never cross a user boundary.
  Future<ApiCached<T>> _cachedGet<T>(
    String path, {
    required String key,
    required T Function(Map<String, dynamic>) parse,
    String? scope,
  }) async {
    final cacheKey = scope == null ? key : '$key:$scope';
    Map<String, dynamic> raw;
    final fetchedAt = DateTime.now();
    try {
      raw = await _req('GET', path);
    } on ApiException catch (e) {
      if (e.status != 0 || cacheStore == null) rethrow;
      final hit = await cacheStore!.read(cacheKey);
      if (hit == null) rethrow;
      return ApiCached(
        parse(hit.payload),
        fetchedAt: hit.fetchedAt,
        stale: true,
      );
    }
    await cacheStore?.write(cacheKey, raw, fetchedAt);
    return ApiCached(parse(raw), fetchedAt: fetchedAt);
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
        if (gender != null && !gender.needsCompletion) 'gender': gender.json,
        if (referredByCode != null && referredByCode.isNotEmpty)
          'referredByCode': referredByCode,
        if (guestEntries != null && guestEntries.isNotEmpty)
          'guestEntries': sendableGuestEntries(guestEntries),
      },
    );
    return VerifyResponse(
      user: User.fromJson(j['user'] as Map<String, dynamic>),
      // The API returns {accessToken, refreshToken, …} (otp/verify envelope).
      token: j['accessToken'] as String?,
    );
  }

  /// GET /api/auth/providers — social sign-in availability (B5).
  Future<AuthProviders> authProviders() async =>
    AuthProviders.fromJson(await _req('GET', '/api/auth/providers'));

  /// POST /api/auth/social — Google/Apple id_token sign-in (B5). Same
  /// envelope as otp/verify (user + accessToken/refreshToken); guestEntries
  /// ride along exactly like the OTP flow.
  Future<VerifyResponse> socialSignIn({
    required String provider,
    required String idToken,
    String? name,
    Gender? gender,
    String? referredByCode,
    List<AmalEntry>? guestEntries,
  }) async {
    final j = await _req(
      'POST',
      '/api/auth/social',
      body: {
        'provider': provider,
        'idToken': idToken,
        if (name != null && name.isNotEmpty) 'name': name,
        if (gender != null && !gender.needsCompletion) 'gender': gender.json,
        if (referredByCode != null && referredByCode.isNotEmpty)
          'referredByCode': referredByCode,
        if (guestEntries != null && guestEntries.isNotEmpty)
          'guestEntries': sendableGuestEntries(guestEntries),
      },
    );
    return VerifyResponse(
      user: User.fromJson(j['user'] as Map<String, dynamic>),
      token: j['accessToken'] as String?,
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

  /// POST /api/me/phone/request — PROF-04: an OTP to the NEW number. In dev
  /// the server returns `devCode` (mock SMS); null in production.
  Future<String?> requestPhoneChange(String phone) async {
    final j = await _req('POST', '/api/me/phone/request', body: {'phone': phone});
    return j['devCode'] as String?;
  }

  /// POST /api/me/phone/verify — consume the OTP and switch the phone.
  Future<User> verifyPhoneChange(String phone, String code) async {
    final j = await _req(
      'POST',
      '/api/me/phone/verify',
      body: {'phone': phone, 'code': code},
    );
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

  // ── Personal goals (W4c) ─────────────────────────────────────────────────────

  /// GET /api/goals — own goals, every lifecycle status (newest first).
  Future<List<PersonalGoal>> fetchGoals() async {
    final j = await _req('GET', '/api/goals');
    return ((j['goals'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => PersonalGoal.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/goals — propose a goal for mentor approval (max 14 open).
  /// The server sets status "proposed"; startDate is YYYY-MM-DD.
  Future<PersonalGoal> proposeGoal({
    required String amalKey,
    required String title,
    required String startDate,
    String? note,
    String? target,
  }) async {
    final j = await _req(
      'POST',
      '/api/goals',
      body: {
        'amalKey': amalKey,
        'title': title,
        'startDate': startDate,
        if (note != null && note.isNotEmpty) 'note': note,
        if (target != null && target.isNotEmpty) 'target': target,
      },
    );
    return PersonalGoal.fromJson(
      (j['goal'] as Map).cast<String, dynamic>(),
    );
  }

  /// DELETE /api/goals?id= — remove one of my open (non-terminal) goals.
  /// Terminal rows are history on the server and are refused with 400.
  Future<void> deleteGoal(String id) =>
      _req('DELETE', '/api/goals', query: {'id': id});

  /// GET /api/usrah/goals — the approval queue (usrah_head+; RLS scopes
  /// the rows to the caller's own members).
  Future<List<GoalQueueItem>> usrahGoals() async {
    final j = await _req('GET', '/api/usrah/goals');
    return ((j['queue'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => GoalQueueItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/goals/:id/approve — usrah_head+ (fires the member reminder).
  Future<PersonalGoal> approveGoal(String id) async {
    final j = await _req('POST', '/api/goals/$id/approve');
    return PersonalGoal.fromJson(
      (j['goal'] as Map).cast<String, dynamic>(),
    );
  }

  /// POST /api/goals/:id/reject — usrah_head+ (optional reason).
  Future<PersonalGoal> rejectGoal(String id, {String? reason}) async {
    final j = await _req(
      'POST',
      '/api/goals/$id/reject',
      body: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return PersonalGoal.fromJson(
      (j['goal'] as Map).cast<String, dynamic>(),
    );
  }

  /// GET /api/leaderboard/me — own gender-scoped percentile band
  /// (config-gated; 404 while the flag is off server-side).
  Future<LeaderboardMe> leaderboardMe() async =>
      LeaderboardMe.fromJson(await _req('GET', '/api/leaderboard/me'));

  // ── Live support threads (W4d) ───────────────────────────────────────────

  /// GET /api/support — own threads (newest activity first).
  Future<List<SupportThread>> supportThreads() async {
    final j = await _req('GET', '/api/support');
    return ((j['threads'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SupportThread.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/support — open a support thread (subject + first message;
  /// max 5 non-closed threads server-side).
  Future<SupportThread> supportCreate({
    required String subject,
    required String message,
  }) async {
    final j = await _req(
      'POST',
      '/api/support',
      body: {'subject': subject, 'message': message},
    );
    return SupportThread.fromJson(
      (j['thread'] as Map).cast<String, dynamic>(),
    );
  }

  /// GET /api/support/:id — own thread + its messages (asc).
  Future<(SupportThread, List<SupportMessage>)> supportThread(String id) async {
    final j = await _req('GET', '/api/support/$id');
    return (
      SupportThread.fromJson(
        (j['thread'] as Map).cast<String, dynamic>(),
      ),
      ((j['messages'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => SupportMessage.fromJson(e.cast<String, dynamic>()))
          .toList(),
    );
  }

  /// POST /api/support/:id/messages — append (400 once the thread is closed).
  Future<SupportMessage> supportAppend({
    required String id,
    required String message,
  }) async {
    final j = await _req(
      'POST',
      '/api/support/$id/messages',
      body: {'message': message},
    );
    return SupportMessage.fromJson(
      (j['message'] as Map).cast<String, dynamic>(),
    );
  }

  // ── Usrah join requests (W4d) ────────────────────────────────────────────

  /// POST /api/usrah/join-request — ask for an usrah assignment. 409 when the
  /// member is already in one; idempotent while a request is pending (the
  /// same pending row is returned).
  Future<UsrahJoinRequest> joinRequestCreate({String? message}) async {
    final j = await _req(
      'POST',
      '/api/usrah/join-request',
      body: {
        if (message != null && message.isNotEmpty) 'message': message,
      },
    );
    return UsrahJoinRequest.fromJson(
      (j['request'] as Map).cast<String, dynamic>(),
    );
  }

  /// GET /api/usrah/join-request — own current/last request (null when none).
  Future<UsrahJoinRequest?> joinRequestStatus() async {
    final j = await _req('GET', '/api/usrah/join-request');
    final raw = j['request'];
    return raw is Map<String, dynamic> ? UsrahJoinRequest.fromJson(raw) : null;
  }

  // ── Dawah engine ────────────────────────────────────────────────────────────

  /// GET /api/dawah — cached offline (W4-fix4). [scope] = user id so one
  /// member's overview can never surface for another account.
  Future<ApiCached<DawahOverview>> dawahOverview({String? scope}) =>
      _cachedGet(
        '/api/dawah',
        key: 'dawah/overview',
        scope: scope,
        parse: DawahOverview.fromJson,
      );

  /// GET /api/usrah — cached offline (W4-fix4). One body carries both the
  /// roster and the announcements; `usrah: null` = not in an usrah yet.
  Future<ApiCached<(Usrah?, List<Announcement>)>> usrah({String? scope}) =>
      _cachedGet(
        '/api/usrah',
        key: 'dawah/usrah',
        scope: scope,
        parse: _parseUsrah,
      );

  static (Usrah?, List<Announcement>) _parseUsrah(Map<String, dynamic> j) {
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

  /// GET /api/reviews — cached offline (W4-fix4).
  Future<ApiCached<List<WeeklyReview>>> reviews({String? scope}) =>
      _cachedGet(
        '/api/reviews',
        key: 'dawah/reviews',
        scope: scope,
        parse: _parseReviews,
      );

  static List<WeeklyReview> _parseReviews(Map<String, dynamic> j) =>
      ((j['reviews'] as List?) ?? [])
          .whereType<Map>()
          .map((e) => WeeklyReview.fromJson(e.cast<String, dynamic>()))
          .toList();

  // ── Assessments (W4i — the assessee's own acknowledgment flow) ──────────────

  /// GET /api/assessments/me — own (assessee) assessments, every status,
  /// with scores. The dawah tab's assessment cards read this.
  Future<List<AssessmentDetail>> myAssessments() async {
    final j = await _req('GET', '/api/assessments/me');
    return ((j['assessments'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => AssessmentDetail.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/assessments/:id/confirm-request — issue the OTP to the
  /// ASSESSEE's own phone (the auth OTP service, same throttle + hashing).
  Future<OtpResponse> assessmentConfirmRequest(String id) async {
    final j = await _req('POST', '/api/assessments/$id/confirm-request');
    return OtpResponse(
      ok: j['ok'] as bool? ?? false,
      devCode: j['devCode'] as String?,
    );
  }

  /// POST /api/assessments/:id/confirm {code} — verify → the result becomes
  /// FINAL (status confirmed + the OTP-confirmed signature).
  Future<AssessmentDetail> assessmentConfirm({
    required String id,
    required String code,
  }) async {
    final j = await _req(
      'POST',
      '/api/assessments/$id/confirm',
      body: {'code': code},
    );
    return AssessmentDetail.fromJson(j['assessment'] as Map<String, dynamic>);
  }

  /// POST /api/assessments/:id/decline {reason?} — the assessee refuses the
  /// result (the invigilator is notified server-side).
  Future<AssessmentDetail> assessmentDecline({
    required String id,
    String? reason,
  }) async {
    final j = await _req(
      'POST',
      '/api/assessments/$id/decline',
      body: {
        if (reason != null && reason.isNotEmpty) 'reason': reason,
      },
    );
    return AssessmentDetail.fromJson(j['assessment'] as Map<String, dynamic>);
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

  /// GET /api/announcements — the Foundation's own notices (public; a
  /// gender-addressed one only for that gender).
  Future<List<Announcement>> foundationAnnouncements() async {
    final j = await _req('GET', '/api/announcements');
    return ((j['announcements'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => Announcement.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/masala/mine — my questions and their answers (signed in).
  Future<List<MasalaItem>> myMasala() async {
    final j = await _req('GET', '/api/masala/mine');
    return ((j['questions'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => MasalaItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/feedback — [context] ("app 1.0.0+12 · Android 13 …") lets the
  /// admin read a tester's report with the device it came from.
  Future<void> feedback(String message, {String? context}) => _req(
    'POST',
    '/api/feedback',
    body: {'message': message, if (context != null && context.isNotEmpty) 'context': context},
  );

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

  // ── Ilm engagement (B4/B9): courses, quizzes, usrah questions, live quiz ────

  /// GET /api/courses — public catalog (lesson counts + enrollment stats).
  Future<List<CourseSummary>> courses() async {
    final j = await _req('GET', '/api/courses');
    return ((j['courses'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => CourseSummary.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/courses/:id — course with lesson bodies + my progress.
  Future<CourseDetailResponse> courseDetail(String id) async {
    final j = await _req('GET', '/api/courses/$id');
    return CourseDetailResponse.fromJson(j);
  }

  /// GET /api/enrollments — my enrollment rows (progress per course).
  Future<List<EnrollmentItem>> enrollments() async {
    final j = await _req('GET', '/api/enrollments');
    return ((j['enrollments'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => EnrollmentItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/enroll — idempotent enrollment (login).
  Future<void> enroll(String courseId) =>
      _req('POST', '/api/enroll', body: {'courseId': courseId});

  /// PATCH /api/enroll — persist the done-lesson list (login).
  Future<void> saveCourseProgress(String courseId, List<String> done) => _req(
    'PATCH',
    '/api/enroll',
    body: {
      'courseId': courseId,
      'progressJson': jsonEncode({'done': done}),
    },
  );

  /// GET /api/content/:pack — the pack document the admin CMS edits. The
  /// route answers `{pack, data}`; reading the top level (as quizPack did)
  /// found nothing, so the app silently showed an EMPTY quiz list.
  Future<Map<String, dynamic>?> contentPackData(String key) async {
    final j = await _req('GET', '/api/content/${Uri.encodeComponent(key)}');
    final data = j['data'];
    return data is Map ? data.cast<String, dynamic>() : null;
  }

  /// The quiz pack from the server (see [contentPackData]).
  Future<List<Quiz>> quizPack() async {
    final data = await contentPackData('quizzes');
    return ((data?['quizzes'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => Quiz.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/quiz-attempt — record a finished self-paced quiz (login).
  Future<void> submitQuizAttempt({
    required String quizId,
    required int score,
    required int total,
  }) => _req(
    'POST',
    '/api/quiz-attempt',
    body: {'quizId': quizId, 'score': score, 'total': total},
  );

  /// GET /api/quiz-attempts — my attempt history (login).
  Future<List<QuizAttemptItem>> quizAttempts() async {
    final j = await _req('GET', '/api/quiz-attempts');
    return ((j['attempts'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => QuizAttemptItem.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// GET /api/usrah/quiz-results — how my usrah's members did in the quizzes
  /// (usrah_head+; RLS scopes the rows to same-gender members I supervise).
  Future<UsrahQuizResults> usrahQuizResults() async {
    final j = await _req('GET', '/api/usrah/quiz-results');
    return UsrahQuizResults.fromJson(j);
  }

  /// GET /api/usrah-questions — own usrah's board (RLS, newest first).
  Future<List<UsrahQuestion>> usrahQuestions() async {
    final j = await _req('GET', '/api/usrah-questions');
    return ((j['questions'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => UsrahQuestion.fromJson(e.cast<String, dynamic>()))
        .toList();
  }

  /// POST /api/usrah-questions — ask inside own usrah (login).
  Future<UsrahQuestion> askUsrahQuestion({
    required String question,
    String category = 'general',
  }) async {
    final j = await _req(
      'POST',
      '/api/usrah-questions',
      body: {'question': question, 'category': category},
    );
    return UsrahQuestion.fromJson(
      (j['question'] as Map).cast<String, dynamic>(),
    );
  }

  /// POST /api/usrah-questions/:id/answers — the usrah head answers.
  Future<UsrahQuestion> answerUsrahQuestion({
    required String id,
    required String answer,
  }) async {
    final j = await _req(
      'POST',
      '/api/usrah-questions/$id/answers',
      body: {'answer': answer},
    );
    return UsrahQuestion.fromJson(
      (j['question'] as Map).cast<String, dynamic>(),
    );
  }

  /// GET /api/dawah/requirements — live next-level checklist (daee+),
  /// cached offline (W4-fix4).
  Future<ApiCached<DawahRequirements>> dawahRequirements({String? scope}) =>
      _cachedGet(
        '/api/dawah/requirements',
        key: 'dawah/requirements',
        scope: scope,
        parse: DawahRequirements.fromJson,
      );

  /// GET /api/quiz/live-token?quizId=… — HMAC room token for the API's own
  /// socket.io gateway (apps/api/src/engagement/quiz.gateway.ts).
  Future<QuizLiveTokenResponse> quizLiveToken([String quizId = '']) async {
    final j = await _req(
      'GET',
      '/api/quiz/live-token',
      query: quizId.isEmpty ? null : {'quizId': quizId},
    );
    return QuizLiveTokenResponse.fromJson(j);
  }

  /// GET /api/search?q=…&limit= — unified content search over meili
  /// (public; W4j). Throws ApiException(0) when the network is down and
  /// 503 when the server's search engine is unavailable — both cases are
  /// the caller's cue to fall back to the bundled-pack matcher.
  Future<SearchResults> search(String q, {int limit = 20}) async {
    final j = await _req(
      'GET',
      '/api/search',
      query: {'q': q, 'limit': limit.toString()},
    );
    return SearchResults.fromJson(j);
  }
}
