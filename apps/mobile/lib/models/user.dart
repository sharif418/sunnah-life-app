/// User + account enums — port of the User/Role/Gender/Level group in
/// src/types/domain.ts. JSON string forms match the API wire format.
library;

/// M/F, plus the pre-onboarding sentinel for social-sign-in accounts that
/// were created without a gender — the app routes those to the one-time
/// gender+name completion screen (PATCH /api/me), after which it is locked.
enum Gender { m, f, unspecified }

enum Role { user, daee, usrahHead, invigilator, fullAdmin }

enum Level { none, muhibbusSunnah, farzeAin1, farzeAin2 }

enum UserCategory { general, hafez, alim }

enum Madhhab { hanafi, shafii }

enum CalcMethod { ifb, karachi, mwl, isna, egypt, makkah, dubai }

extension GenderJson on Gender {
  String get json => switch (this) {
    Gender.m => 'M',
    Gender.f => 'F',
    Gender.unspecified => 'unspecified',
  };
  static Gender fromJson(String v) => switch (v) {
    'M' => Gender.m,
    'F' => Gender.f,
    _ => Gender.unspecified,
  };

  /// True while the account still needs the gender+name onboarding step.
  bool get needsCompletion => this == Gender.unspecified;
}

extension RoleJson on Role {
  String get json => switch (this) {
    Role.user => 'user',
    Role.daee => 'daee',
    Role.usrahHead => 'usrah_head',
    Role.invigilator => 'invigilator',
    Role.fullAdmin => 'full_admin',
  };
  static Role fromJson(String v) => switch (v) {
    'daee' => Role.daee,
    'usrah_head' => Role.usrahHead,
    'invigilator' => Role.invigilator,
    'full_admin' => Role.fullAdmin,
    _ => Role.user,
  };

  /// ARB key for the localized role label (was hard-coded Bengali).
  String get labelKey => switch (this) {
    Role.user => 'role_user',
    Role.daee => 'role_daee',
    Role.usrahHead => 'role_usrah_head',
    Role.invigilator => 'role_invigilator',
    Role.fullAdmin => 'role_full_admin',
  };

  /// Da'wah engine access starts at daee (ROLE_RANK >= 1 in domain.ts).
  int get rank => switch (this) {
    Role.user => 0,
    Role.daee => 1,
    Role.usrahHead => 2,
    Role.invigilator => 2,
    Role.fullAdmin => 3,
  };

  /// usrah_head and above — the mentor-approval surface (goal decisions,
  /// reviews.submit). Mirrors GuardService.isSupervisor server-side
  /// (ROLE_RANK >= ROLE_RANK["usrah_head"]).
  bool get isSupervisor => rank >= Role.usrahHead.rank;
}

extension LevelJson on Level {
  String get json => switch (this) {
    Level.none => 'none',
    Level.muhibbusSunnah => 'muhibbus_sunnah',
    Level.farzeAin1 => 'farze_ain_1',
    Level.farzeAin2 => 'farze_ain_2',
  };
  static Level fromJson(String v) => switch (v) {
    'muhibbus_sunnah' => Level.muhibbusSunnah,
    'farze_ain_1' => Level.farzeAin1,
    'farze_ain_2' => Level.farzeAin2,
    _ => Level.none,
  };

  /// ARB key for the localized level label (was hard-coded Bengali).
  String get labelKey => switch (this) {
    Level.none => 'level_none',
    Level.muhibbusSunnah => 'level_muhibbus_sunnah',
    Level.farzeAin1 => 'level_farze_ain_1',
    Level.farzeAin2 => 'level_farze_ain_2',
  };
}

extension UserCategoryJson on UserCategory {
  String get json => name;
  static UserCategory fromJson(String v) => v == 'hafez'
      ? UserCategory.hafez
      : (v == 'alim' ? UserCategory.alim : UserCategory.general);
}

extension MadhhabJson on Madhhab {
  String get json => this == Madhhab.hanafi ? 'hanafi' : 'shafii';
  static Madhhab fromJson(String v) =>
      v == 'shafii' ? Madhhab.shafii : Madhhab.hanafi;

  /// ARB key for the localized label (was hard-coded Bengali).
  String get labelKey =>
      this == Madhhab.hanafi ? 'madhhab_hanafi' : 'madhhab_shafii';
}

extension CalcMethodJson on CalcMethod {
  String get json => switch (this) {
    CalcMethod.ifb => 'ifb',
    CalcMethod.karachi => 'karachi',
    CalcMethod.mwl => 'mwl',
    CalcMethod.isna => 'isna',
    CalcMethod.egypt => 'egypt',
    CalcMethod.makkah => 'makkah',
    CalcMethod.dubai => 'dubai',
  };
  static CalcMethod fromJson(String v) => switch (v) {
    'ifb' => CalcMethod.ifb,
    'mwl' => CalcMethod.mwl,
    'isna' => CalcMethod.isna,
    'egypt' => CalcMethod.egypt,
    'makkah' => CalcMethod.makkah,
    'dubai' => CalcMethod.dubai,
    _ => CalcMethod.karachi,
  };

  /// ARB key for the localized label (was hard-coded Bengali).
  String get labelKey => switch (this) {
    CalcMethod.ifb => 'method_ifb',
    CalcMethod.karachi => 'method_karachi',
    CalcMethod.mwl => 'method_mwl',
    CalcMethod.isna => 'method_isna',
    CalcMethod.egypt => 'method_egypt',
    CalcMethod.makkah => 'method_makkah',
    CalcMethod.dubai => 'method_dubai',
  };
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.gender,
    required this.role,
    required this.category,
    this.phone,
    this.email,
    this.photoUrl,
    this.memberCode,
    this.referredById,
    this.usrahId,
    this.level = Level.none,
    this.levelStartedAt,
    this.district,
    this.workplace,
    this.department,
    this.language = 'bn',
    this.madhhab = Madhhab.hanafi,
    this.calcMethod = CalcMethod.ifb,
    this.lat,
    this.lng,
    this.city,
    this.prayerAdjust,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String id;

  /// ± minutes per farz waqt as the server keeps it ({"fajr": 2, …}) —
  /// read through PrayerAdjust.parse.
  final Map<String, dynamic>? prayerAdjust;
  final String? phone;
  final String? email;
  final String name;
  final String? photoUrl;
  final Gender gender;
  final Role role;
  final UserCategory category;
  final String? memberCode;
  final String? referredById;
  final String? usrahId;
  final Level level;
  final String? levelStartedAt;
  final String? district;
  final String? workplace;
  final String? department;
  final String language;
  final Madhhab madhhab;
  final CalcMethod calcMethod;
  final double? lat;
  final double? lng;
  final String? city;
  final String createdAt;
  final String lastActiveAt;

  bool get canSeeDawah =>
      role == Role.daee ||
      role == Role.usrahHead ||
      role == Role.invigilator ||
      role == Role.fullAdmin;

  factory User.fromJson(Map<String, dynamic> j) => User(
    id: j['id'] as String,
    phone: j['phone'] as String?,
    email: j['email'] as String?,
    name: j['name'] as String? ?? '',
    photoUrl: j['photoUrl'] as String?,
    gender: GenderJson.fromJson(j['gender'] as String? ?? 'M'),
    role: RoleJson.fromJson(j['role'] as String? ?? 'user'),
    category: UserCategoryJson.fromJson(j['category'] as String? ?? 'general'),
    memberCode: j['memberCode'] as String?,
    referredById: j['referredById'] as String?,
    usrahId: j['usrahId'] as String?,
    level: LevelJson.fromJson(j['level'] as String? ?? 'none'),
    levelStartedAt: j['levelStartedAt'] as String?,
    district: j['district'] as String?,
    workplace: j['workplace'] as String?,
    department: j['department'] as String?,
    language: j['language'] as String? ?? 'bn',
    madhhab: MadhhabJson.fromJson(j['madhhab'] as String? ?? 'hanafi'),
    calcMethod: CalcMethodJson.fromJson(
      j['calcMethod'] as String? ?? 'ifb',
    ),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    city: j['city'] as String?,
    prayerAdjust: (j['prayerAdjust'] as Map?)?.cast<String, dynamic>(),
    createdAt: j['createdAt'] as String? ?? '',
    lastActiveAt: j['lastActiveAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'phone': phone,
    'email': email,
    'name': name,
    'photoUrl': photoUrl,
    'gender': gender.json,
    'role': role.json,
    'category': category.json,
    'memberCode': memberCode,
    'referredById': referredById,
    'usrahId': usrahId,
    'level': level.json,
    'levelStartedAt': levelStartedAt,
    'district': district,
    'workplace': workplace,
    'department': department,
    'language': language,
    'madhhab': madhhab.json,
    'calcMethod': calcMethod.json,
    'lat': lat,
    'lng': lng,
    'city': city,
    'prayerAdjust': ?prayerAdjust,
    'createdAt': createdAt,
    'lastActiveAt': lastActiveAt,
  };
}
