/// User + account enums — port of the User/Role/Gender/Level group in
/// src/types/domain.ts. JSON string forms match the API wire format.
library;

enum Gender { m, f }

enum Role { user, daee, usrahHead, invigilator, fullAdmin }

enum Level { none, muhibbusSunnah, farzeAin1, farzeAin2 }

enum UserCategory { general, hafez, alim }

enum Madhhab { hanafi, shafii }

enum CalcMethod { karachi, mwl, isna, egypt, makkah, dubai }

extension GenderJson on Gender {
  String get json => this == Gender.m ? 'M' : 'F';
  static Gender fromJson(String v) => v == 'M' ? Gender.m : Gender.f;
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
  String get labelBn => switch (this) {
    Role.user => 'সাধারণ ব্যবহারকারী',
    Role.daee => 'দায়ী',
    Role.usrahHead => 'উসরা প্রধান',
    Role.invigilator => 'পরিদর্শক',
    Role.fullAdmin => 'প্রধান অ্যাডমিন',
  };

  /// Da'wah engine access starts at daee (ROLE_RANK >= 1 in domain.ts).
  int get rank => switch (this) {
    Role.user => 0,
    Role.daee => 1,
    Role.usrahHead => 2,
    Role.invigilator => 2,
    Role.fullAdmin => 3,
  };
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
  String get labelBn => switch (this) {
    Level.none => 'শুরুর পর্যায়',
    Level.muhibbusSunnah => 'মুহিব্বুস সুন্নাহ',
    Level.farzeAin1 => 'ফরযে আইন — ক্যাটাগরি ১',
    Level.farzeAin2 => 'ফরযে আইন — ক্যাটাগরি ২',
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
  String get labelBn => this == Madhhab.hanafi ? 'হানাফি' : 'শাফেয়ি';
}

extension CalcMethodJson on CalcMethod {
  String get json => switch (this) {
    CalcMethod.karachi => 'karachi',
    CalcMethod.mwl => 'mwl',
    CalcMethod.isna => 'isna',
    CalcMethod.egypt => 'egypt',
    CalcMethod.makkah => 'makkah',
    CalcMethod.dubai => 'dubai',
  };
  static CalcMethod fromJson(String v) => switch (v) {
    'mwl' => CalcMethod.mwl,
    'isna' => CalcMethod.isna,
    'egypt' => CalcMethod.egypt,
    'makkah' => CalcMethod.makkah,
    'dubai' => CalcMethod.dubai,
    _ => CalcMethod.karachi,
  };
  String get labelBn => switch (this) {
    CalcMethod.karachi => 'করাচি (১৮°/১৮°)',
    CalcMethod.mwl => 'মুসলিম ওয়ার্ল্ড লীগ',
    CalcMethod.isna => 'ISNA (উত্তর আমেরিকা)',
    CalcMethod.egypt => 'মিসরীয়',
    CalcMethod.makkah => 'উম্মুল কুরা (মক্কা)',
    CalcMethod.dubai => 'দুবাই',
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
    this.calcMethod = CalcMethod.karachi,
    this.lat,
    this.lng,
    this.city,
    required this.createdAt,
    required this.lastActiveAt,
  });

  final String id;
  final String? phone;
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
      j['calcMethod'] as String? ?? 'karachi',
    ),
    lat: (j['lat'] as num?)?.toDouble(),
    lng: (j['lng'] as num?)?.toDouble(),
    city: j['city'] as String?,
    createdAt: j['createdAt'] as String? ?? '',
    lastActiveAt: j['lastActiveAt'] as String? ?? '',
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'phone': phone,
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
    'createdAt': createdAt,
    'lastActiveAt': lastActiveAt,
  };
}
