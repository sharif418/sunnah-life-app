/// Bengali-first string table (bn / en / ar) — no hardcoded UI text anywhere.
/// Usage: `context.t('key')` or `S.tr(lang, 'key')`.
library;

enum Lang { bn, en, ar }

extension LangX on Lang {
  String get code => switch (this) {
    Lang.bn => 'bn',
    Lang.en => 'en',
    Lang.ar => 'ar',
  };
  bool get isBengali => this == Lang.bn;
  bool get isRtl => this == Lang.ar;
  String get labelNative => switch (this) {
    Lang.bn => 'বাংলা',
    Lang.en => 'English',
    Lang.ar => 'العربية',
  };
  static Lang fromCode(String? code) => switch (code) {
    'en' => Lang.en,
    'ar' => Lang.ar,
    _ => Lang.bn,
  };
}

class S {
  const S._();

  static const Map<String, Map<Lang, String>> _table = kStringTable;

  /// Translate a key; Bengali is the fallback for missing keys.
  static String tr(Lang lang, String key) {
    final entry = _table[key];
    if (entry == null) return key;
    return entry[lang] ?? entry[Lang.bn] ?? key;
  }
}

/// The full string table — public so the completeness test can iterate it.
const Map<String, Map<Lang, String>> kStringTable = {
  // ── Common ──
  'ok': {Lang.bn: 'ঠিক আছে', Lang.en: 'OK', Lang.ar: 'حسنًا'},
  'cancel': {Lang.bn: 'বাতিল', Lang.en: 'Cancel', Lang.ar: 'إلغاء'},
  'save': {Lang.bn: 'সংরক্ষণ', Lang.en: 'Save', Lang.ar: 'حفظ'},
  'retry': {
    Lang.bn: 'আবার চেষ্টা করুন',
    Lang.en: 'Retry',
    Lang.ar: 'أعد المحاولة',
  },
  'next': {Lang.bn: 'পরবর্তী', Lang.en: 'Next', Lang.ar: 'التالي'},
  'back': {Lang.bn: 'পেছনে', Lang.en: 'Back', Lang.ar: 'رجوع'},
  'done': {Lang.bn: 'সম্পন্ন', Lang.en: 'Done', Lang.ar: 'تم'},
  'search': {Lang.bn: 'খুঁজুন', Lang.en: 'Search', Lang.ar: 'بحث'},
  'share': {Lang.bn: 'শেয়ার', Lang.en: 'Share', Lang.ar: 'مشاركة'},
  'copy': {Lang.bn: 'কপি', Lang.en: 'Copy', Lang.ar: 'نسخ'},
  'copied': {Lang.bn: 'কপি হয়েছে', Lang.en: 'Copied', Lang.ar: 'تم النسخ'},
  'see_all': {Lang.bn: 'সব দেখুন', Lang.en: 'See all', Lang.ar: 'عرض الكل'},
  'loading': {
    Lang.bn: 'লোড হচ্ছে…',
    Lang.en: 'Loading…',
    Lang.ar: 'جار التحميل…',
  },
  'empty_generic': {
    Lang.bn: 'এখনো কিছু নেই',
    Lang.en: 'Nothing here yet',
    Lang.ar: 'لا يوجد شيء بعد',
  },
  'error_generic': {
    Lang.bn: 'কিছু একটা সমস্যা হয়েছে',
    Lang.en: 'Something went wrong',
    Lang.ar: 'حدث خطأ ما',
  },
  'offline': {
    Lang.bn: 'অফলাইন — পরিবর্তনগুলো সেভ থাকবে, নেট এলে সিঙ্ক হবে',
    Lang.en: 'Offline — changes are saved and will sync later',
    Lang.ar: 'غير متصل — ستُحفظ التغييرات وتُزامن لاحقًا',
  },
  'offline_short': {Lang.bn: 'অফলাইন', Lang.en: 'Offline', Lang.ar: 'غير متصل'},
  'online': {Lang.bn: 'অনলাইন', Lang.en: 'Online', Lang.ar: 'متصل'},
  'guest': {Lang.bn: 'গেস্ট', Lang.en: 'Guest', Lang.ar: 'زائر'},
  'version': {Lang.bn: 'সংস্করণ', Lang.en: 'Version', Lang.ar: 'إصدار'},

  // ── Nav tabs ──
  'tab_home': {Lang.bn: 'হোম', Lang.en: 'Home', Lang.ar: 'الرئيسية'},
  'tab_amal': {Lang.bn: 'আমল', Lang.en: 'Amal', Lang.ar: 'الأعمال'},
  'tab_dawah': {Lang.bn: 'দাওয়াত', Lang.en: "Da'wah", Lang.ar: 'الدعوة'},
  'tab_ilm': {Lang.bn: 'ইলম', Lang.en: 'Ilm', Lang.ar: 'العلم'},
  'tab_more': {Lang.bn: 'আরও', Lang.en: 'More', Lang.ar: 'المزيد'},

  // ── Onboarding ──
  'onb_title': {
    Lang.bn: 'সুন্নাহ লাইফে স্বাগতম',
    Lang.en: 'Welcome to Sunnah Life',
    Lang.ar: 'مرحبًا بك في سنّة لايف',
  },
  'onb_step1_title': {
    Lang.bn: 'ভাষা নির্বাচন করুন',
    Lang.en: 'Choose your language',
    Lang.ar: 'اختر لغتك',
  },
  'onb_step2_title': {
    Lang.bn: 'আপনার পরিচয়',
    Lang.en: 'About you',
    Lang.ar: 'عنك',
  },
  'onb_name': {Lang.bn: 'নাম', Lang.en: 'Name', Lang.ar: 'الاسم'},
  'onb_name_hint': {
    Lang.bn: 'যেমন: আব্দুল্লাহ',
    Lang.en: 'e.g. Abdullah',
    Lang.ar: 'مثال: عبدالله',
  },
  'onb_gender': {Lang.bn: 'লিঙ্গ', Lang.en: 'Gender', Lang.ar: 'الجنس'},
  'onb_male': {
    Lang.bn: 'ভাই (পুরুষ)',
    Lang.en: 'Brother (Male)',
    Lang.ar: 'أخ (ذكر)',
  },
  'onb_female': {
    Lang.bn: 'বোন (নারী)',
    Lang.en: 'Sister (Female)',
    Lang.ar: 'أخت (أنثى)',
  },
  'onb_female_privacy': {
    Lang.bn:
        'বোনদের প্রতি আমাদের অঙ্গীকার: আপনার নাম, আমল ও পরিচয় কেবল মহিলা পরিদর্শক ও '
        'মহিলা উসরা প্রধান দেখতে পারবেন। ছেলে পরিদর্শক বা অ্যাডমিন-ও মহিলা সদস্যের তথ্য '
        'দেখার সুযোগ পাবেন না — এটি ডেটাবেস স্তরেই নিশ্চিত করা হয়েছে।',
    Lang.en:
        'Our pledge to sisters: your name, amal and identity are visible only to female '
        'supervisors and female usrah heads. Male supervisors and admins can never see female '
        'member data — enforced in the database itself.',
    Lang.ar:
        'تعهدنا لأخواتنا: اسمك وأعمالك وبياناتك لا تراها إلا المشرفات ورئيسات الحلقات من النساء، '
        'ولا يمكن للمشرفين أو المسؤولين من الرجال رؤية بيانات العضوات — وهذا مضمون في قاعدة البيانات نفسها.',
  },
  'onb_step3_title': {
    Lang.bn: 'অবস্থান ও মাযহাব',
    Lang.en: 'Location & madhhab',
    Lang.ar: 'الموقع والمذهب',
  },
  'onb_city': {Lang.bn: 'শহর', Lang.en: 'City', Lang.ar: 'المدينة'},
  'onb_city_search': {
    Lang.bn: 'শহরের নাম লিখুন…',
    Lang.en: 'Type a city name…',
    Lang.ar: 'اكتب اسم المدينة…',
  },
  'onb_madhhab': {
    Lang.bn: 'মাযহাব (আসর)',
    Lang.en: 'Madhhab (Asr)',
    Lang.ar: 'المذهب (العصر)',
  },
  'onb_method': {
    Lang.bn: 'হিসাব পদ্ধতি',
    Lang.en: 'Calculation method',
    Lang.ar: 'طريقة الحساب',
  },
  'onb_custom_location': {
    Lang.bn: 'নিজের অক্ষাংশ-দ্রাঘিমাংশ',
    Lang.en: 'Custom latitude/longitude',
    Lang.ar: 'إحداثيات مخصصة',
  },
  'onb_lat': {Lang.bn: 'অক্ষাংশ', Lang.en: 'Latitude', Lang.ar: 'خط العرض'},
  'onb_lng': {Lang.bn: 'দ্রাঘিমাংশ', Lang.en: 'Longitude', Lang.ar: 'خط الطول'},
  'onb_start': {
    Lang.bn: 'শুরু করুন — গেস্ট হিসেবে',
    Lang.en: 'Start as guest',
    Lang.ar: 'ابدأ كزائر',
  },
  'onb_signin': {
    Lang.bn: 'সাইন ইন',
    Lang.en: 'Sign in',
    Lang.ar: 'تسجيل الدخول',
  },

  // ── Auth ──
  'auth_title': {
    Lang.bn: 'ফোন দিয়ে সাইন ইন',
    Lang.en: 'Sign in with phone',
    Lang.ar: 'الدخول بالهاتف',
  },
  'auth_phone': {
    Lang.bn: 'মোবাইল নম্বর',
    Lang.en: 'Phone number',
    Lang.ar: 'رقم الهاتف',
  },
  'auth_phone_hint': {
    Lang.bn: '০১XXXXXXXXX',
    Lang.en: '01XXXXXXXXX',
    Lang.ar: '٠١XXXXXXXXX',
  },
  'auth_request_otp': {
    Lang.bn: 'কোড পাঠান',
    Lang.en: 'Send code',
    Lang.ar: 'أرسل الرمز',
  },
  'auth_otp': {
    Lang.bn: 'ভেরিফিকেশন কোড',
    Lang.en: 'Verification code',
    Lang.ar: 'رمز التحقق',
  },
  'auth_verify': {Lang.bn: 'যাচাই করুন', Lang.en: 'Verify', Lang.ar: 'تحقق'},
  'auth_dev_code': {
    Lang.bn: 'ডেভ কোড',
    Lang.en: 'Dev code',
    Lang.ar: 'رمز التطوير',
  },
  'auth_signout': {
    Lang.bn: 'সাইন আউট',
    Lang.en: 'Sign out',
    Lang.ar: 'تسجيل الخروج',
  },
  'auth_guest_note': {
    Lang.bn: 'গেস্ট হিসেবে থাকলে আমল শুধু এই ফোনে সেভ থাকবে। সাইন ইন করলে সব একসাথে চলে আসবে।',
    Lang.en: 'As a guest your amal stays on this phone only. Sign in and everything carries over.',
    Lang.ar:
        'كزائر تبقى أعمالك على هذا الهاتف فقط. عند الدخول تُنقل جميع بياناتك.',
  },
  'auth_invalid_phone': {
    Lang.bn: 'সঠিক মোবাইল নম্বর দিন',
    Lang.en: 'Enter a valid phone number',
    Lang.ar: 'أدخل رقم هاتف صحيحًا',
  },

  // ── Home / prayer ──
  'prayer_next': {
    Lang.bn: 'পরবর্তী ওয়াক্ত',
    Lang.en: 'Next prayer',
    Lang.ar: 'الصلاة التالية',
  },
  'prayer_remaining': {
    Lang.bn: 'বাকি',
    Lang.en: 'remaining',
    Lang.ar: 'المتبقي',
  },
  'prayer_schedule': {
    Lang.bn: 'আজকের সময়সূচি',
    Lang.en: "Today's schedule",
    Lang.ar: 'مواعيد اليوم',
  },
  'prayer_current': {Lang.bn: 'চলছে', Lang.en: 'Current', Lang.ar: 'الحالية'},
  'prayer_forbidden_times': {
    Lang.bn: 'নিষিদ্ধ সময় — নামাজ পড়া নিষেধ',
    Lang.en: 'Forbidden times — no prayer',
    Lang.ar: 'أوقات النهي عن الصلاة',
  },
  'prayer_forbidden_sunrise': {
    Lang.bn: 'সূর্যোদয় ওঠা-নামার সময়',
    Lang.en: 'While the sun rises/sets',
    Lang.ar: 'أثناء شروق الشمس',
  },
  'prayer_forbidden_zawal': {
    Lang.bn: 'যাওয়াল — সূর্য মাথার উপর',
    Lang.en: 'Zawal — sun at zenith',
    Lang.ar: 'الزوال — الشمس في كبد السماء',
  },
  'prayer_forbidden_sunset': {
    Lang.bn: 'সূর্যাস্তের সময়',
    Lang.en: 'While the sun sets',
    Lang.ar: 'أثناء غروب الشمس',
  },
  'prayer_bell_hint': {
    Lang.bn: 'ঘণ্টি চাপুন — এই ওয়াক্তের আগে নোটিফিকেশন',
    Lang.en: 'Tap the bell to be notified',
    Lang.ar: 'اضغط الجرس للتنبيه',
  },
  'prayer_bell_on': {
    Lang.bn: 'ঘণ্টি চালু আছে',
    Lang.en: 'Bell on',
    Lang.ar: 'الجرس مفعّل',
  },
  'prayer_prompt_title': {
    Lang.bn: 'আপনার নামাজ হয়েছে?',
    Lang.en: 'Did you pray?',
    Lang.ar: 'هل صليت؟',
  },
  'prayer_prompt_done_jamaat': {
    Lang.bn: 'জামাতে হয়েছে',
    Lang.en: 'Prayed in jamaat',
    Lang.ar: 'صليت في جماعة',
  },
  'prayer_post_salat': {
    Lang.bn: 'নামাজের পরের আমল লিখে ফেলুন — ২০ মিনিট আগেই জিজ্ঞেস করেছিলাম',
    Lang.en: 'Log your prayer — we asked 20 minutes after the waqt began',
    Lang.ar: 'سجّل صلاتك — سألناك بعد ٢٠ دقيقة من دخول الوقت',
  },

  // ── Amal ──
  'amal_today': {Lang.bn: 'আজকের আমল', Lang.en: 'Today', Lang.ar: 'اليوم'},
  'amal_month': {
    Lang.bn: 'মাসের গ্রিড',
    Lang.en: 'Month grid',
    Lang.ar: 'شبكة الشهر',
  },
  'amal_jamaat': {Lang.bn: 'জামাতে', Lang.en: 'Jamaat', Lang.ar: 'جماعة'},
  'amal_alone': {Lang.bn: 'একা', Lang.en: 'Alone', Lang.ar: 'منفردًا'},
  'amal_qaza': {Lang.bn: 'কাযা', Lang.en: 'Qaza', Lang.ar: 'قضاء'},
  'amal_locked': {Lang.bn: 'লক', Lang.en: 'Locked', Lang.ar: 'مقفل'},
  'amal_locked_msg': {
    Lang.bn: 'এই দিনের আমল লক হয়ে গেছে — পরের দিন ইশরাকের পর দিন বন্ধ হয়।',
    Lang.en: 'This day is locked — days close after the next day\'s Ishraq.',
    Lang.ar: 'هذا اليوم مقفل — تُغلق الأيام بعد إشراق اليوم التالي.',
  },
  'amal_unlock_request': {
    Lang.bn: 'আনলক চাই',
    Lang.en: 'Request unlock',
    Lang.ar: 'طلب فتح',
  },
  'amal_unlock_requested': {
    Lang.bn: 'উসরা প্রধানকে আনলকের অনুরোধ পাঠানো হয়েছে',
    Lang.en: 'Unlock request sent to your usrah head',
    Lang.ar: 'أُرسل طلب الفتح لرئيس حلقتك',
  },
  'amal_streak': {
    Lang.bn: 'ধারাবাহিকতা',
    Lang.en: 'Streak',
    Lang.ar: 'التتابع',
  },
  'amal_days': {Lang.bn: 'দিন', Lang.en: 'days', Lang.ar: 'أيام'},
  'amal_sync_pending': {
    Lang.bn: 'টি পরিবর্তন সিঙ্ক বাকি',
    Lang.en: 'changes pending sync',
    Lang.ar: 'تغييرات بانتظار المزامنة',
  },
  'amal_synced': {
    Lang.bn: 'সব সিঙ্ক হয়েছে',
    Lang.en: 'All synced',
    Lang.ar: 'تمت المزامنة',
  },
  'amal_completion': {
    Lang.bn: 'সম্পন্নতা',
    Lang.en: 'Completion',
    Lang.ar: 'الإنجاز',
  },
  'amal_habit_builder': {
    Lang.bn: 'অভ্যাস গড়ার চ্যালেঞ্জ',
    Lang.en: 'Habit builder',
    Lang.ar: 'بناء العادات',
  },
  'amal_habit_builder_desc': {
    Lang.bn: '৭ দিন ধরে প্রতিদিন একটি আমল — স্ট্রিক ধরে রাখুন',
    Lang.en: 'One amal every day for 7 days — keep the streak',
    Lang.ar: 'عمل واحد كل يوم لمدة أسبوع — حافظ على التتابع',
  },
  'amal_self_test': {
    Lang.bn: 'ইমান ও তাকওয়া সেলফ-টেস্ট',
    Lang.en: 'Iman & Taqwa self-test',
    Lang.ar: 'اختبار الإيمان والتقوى',
  },
  'amal_no_defs': {
    Lang.bn: 'আমল ক্যাটালগ খালি — সাইন ইন করলে সম্পূর্ণ তালিকা আসবে',
    Lang.en: 'Amal catalog is empty — sign in for the full list',
    Lang.ar: 'قائمة الأعمال فارغة — سجّل الدخول للقائمة الكاملة',
  },
  'amal_target_reached': {
    Lang.bn: 'লক্ষ্য পূরণ',
    Lang.en: 'Target reached',
    Lang.ar: 'تم تحقيق الهدف',
  },
  'amal_locked_icon': {
    Lang.bn: '🔒 লক',
    Lang.en: '🔒 Locked',
    Lang.ar: '🔒 مقفل',
  },

  // ── Dawah ──
  'dawah_member_code': {
    Lang.bn: 'আমার মেম্বার কোড',
    Lang.en: 'My member code',
    Lang.ar: 'رمز العضوية',
  },
  'dawah_referral': {
    Lang.bn: 'রেফারেল লিংক',
    Lang.en: 'Referral link',
    Lang.ar: 'رابط الإحالة',
  },
  'dawah_madu': {Lang.bn: 'আমার মাদউ', Lang.en: 'My madu', Lang.ar: 'مدعوّيّ'},
  'dawah_invited': {
    Lang.bn: 'মোট দাওয়াত দিয়েছি',
    Lang.en: 'Total invited',
    Lang.ar: 'إجمالي المدعوين',
  },
  'dawah_usrah': {Lang.bn: 'আমার উসরা', Lang.en: 'My usrah', Lang.ar: 'حلقتي'},
  'dawah_usrah_head': {
    Lang.bn: 'উসরা প্রধান',
    Lang.en: 'Usrah head',
    Lang.ar: 'رئيس الحلقة',
  },
  'dawah_members': {Lang.bn: 'সদস্য', Lang.en: 'Members', Lang.ar: 'الأعضاء'},
  'dawah_announcements': {
    Lang.bn: 'ঘোষণা ও প্রশ্ন',
    Lang.en: 'Announcements',
    Lang.ar: 'الإعلانات',
  },
  'dawah_reviews': {
    Lang.bn: 'সাপ্তাহিক রিভিউ ইতিহাস',
    Lang.en: 'Weekly review history',
    Lang.ar: 'سجل المراجعات',
  },
  'dawah_my_level': {
    Lang.bn: 'আমার স্তর',
    Lang.en: 'My level',
    Lang.ar: 'مستواي',
  },
  'dawah_months_in_level': {
    Lang.bn: 'এই স্তরে মাস',
    Lang.en: 'Months in level',
    Lang.ar: 'أشهر في المستوى',
  },
  'dawah_requirements': {
    Lang.bn: 'উন্নতির শর্তাবলি',
    Lang.en: 'Requirements',
    Lang.ar: 'الشروط',
  },
  'dawah_next_level': {
    Lang.bn: 'পরবর্তী স্তর',
    Lang.en: 'Next level',
    Lang.ar: 'المستوى التالي',
  },
  'dawah_assessments': {
    Lang.bn: 'মূল্যায়নের ইতিহাস',
    Lang.en: 'Assessment history',
    Lang.ar: 'سجل التقييمات',
  },
  'dawah_level_none_next': {
    Lang.bn:
        'দায়ী হিসেবে নিজেকে গড়ে তুলুন — মেম্বার কোড শেয়ার করে দাওয়াত দিন',
    Lang.en: 'Grow as a daee — share your member code',
    Lang.ar: 'انمِ نفسك داعيًا — شارك رمز عضويتك',
  },

  // ── Ilm ──
  'ilm_quran': {Lang.bn: 'আল-কুরআন', Lang.en: 'Quran', Lang.ar: 'القرآن'},
  'ilm_adhkar': {Lang.bn: 'আযকার', Lang.en: 'Adhkar', Lang.ar: 'الأذكار'},
  'ilm_duas': {
    Lang.bn: 'দোয়া ভাণ্ডার',
    Lang.en: 'Du\'a library',
    Lang.ar: 'مستودع الأدعية',
  },
  'ilm_names99': {
    Lang.bn: 'আল্লাহর ৯৯ নাম',
    Lang.en: '99 Names of Allah',
    Lang.ar: 'أسماء الله الحسنى',
  },
  'ilm_baby_names': {
    Lang.bn: 'ইসলামিক নাম',
    Lang.en: 'Islamic baby names',
    Lang.ar: 'أسماء إسلامية',
  },
  'ilm_iman_branches': {
    Lang.bn: 'ঈমানের ৭০ শাখা',
    Lang.en: '70 branches of Iman',
    Lang.ar: 'سبعون شعبة من الإيمان',
  },
  'ilm_sunnahs': {
    Lang.bn: 'সুন্নাহ ও বিস্মৃত সুন্নাহ',
    Lang.en: 'Sunnahs & forgotten sunnahs',
    Lang.ar: 'السنن المهجورة',
  },
  'ilm_articles': {Lang.bn: 'আর্টিকেল', Lang.en: 'Articles', Lang.ar: 'مقالات'},
  'quran_reader': {
    Lang.bn: 'কুরআন পড়ুন',
    Lang.en: 'Read Quran',
    Lang.ar: 'اقرأ القرآن',
  },
  'quran_translation_toggle': {
    Lang.bn: 'বাংলা অনুবাদ',
    Lang.en: 'Bengali translation',
    Lang.ar: 'الترجمة البنغالية',
  },
  'quran_bookmark': {
    Lang.bn: 'বুকমার্ক',
    Lang.en: 'Bookmark',
    Lang.ar: 'علامة',
  },
  'quran_resume': {
    Lang.bn: 'শেষ পড়া থেকে শুরু করুন',
    Lang.en: 'Resume last read',
    Lang.ar: 'أكمل من حيث توقفت',
  },
  'quran_tilawat_logged': {
    Lang.bn: 'তিলাওয়াত আমলনামায় যোগ হয়েছে',
    Lang.en: 'Tilawat added to your diary',
    Lang.ar: 'أُضيف التلاوة إلى سجلك',
  },
  'adhkar_morning': {
    Lang.bn: 'সকালের আযকার',
    Lang.en: 'Morning adhkar',
    Lang.ar: 'أذكار الصباح',
  },
  'adhkar_evening': {
    Lang.bn: 'সন্ধ্যার আযকার',
    Lang.en: 'Evening adhkar',
    Lang.ar: 'أذكار المساء',
  },
  'adhkar_complete': {
    Lang.bn: 'সেট সম্পূর্ণ — আমলনামায় টিক দেওয়া হলো',
    Lang.en: 'Set complete — diary ticked',
    Lang.ar: 'أكملت المجموعة — سُجلت في سجلك',
  },
  'adhkar_tap_count': {
    Lang.bn: 'গণনার জন্য চাপুন',
    Lang.en: 'Tap to count',
    Lang.ar: 'اضغط للعد',
  },
  'names_boy': {Lang.bn: 'ছেলে', Lang.en: 'Boy', Lang.ar: 'ولد'},
  'names_girl': {Lang.bn: 'মেয়ে', Lang.en: 'Girl', Lang.ar: 'بنت'},
  'quiz_start': {Lang.bn: 'শুরু করুন', Lang.en: 'Start', Lang.ar: 'ابدأ'},
  'quiz_result': {Lang.bn: 'ফলাফল', Lang.en: 'Result', Lang.ar: 'النتيجة'},
  'quiz_correct': {Lang.bn: 'সঠিক!', Lang.en: 'Correct!', Lang.ar: 'صحيح!'},
  'quiz_wrong': {Lang.bn: 'ভুল', Lang.en: 'Wrong', Lang.ar: 'خطأ'},
  'quiz_retry': {
    Lang.bn: 'আবার দিন',
    Lang.en: 'Try again',
    Lang.ar: 'أعد المحاولة',
  },

  // ── More ──
  'more_zakat': {
    Lang.bn: 'যাকাত ক্যালকুলেটর',
    Lang.en: 'Zakat calculator',
    Lang.ar: 'حاسبة الزكاة',
  },
  'more_qibla': {
    Lang.bn: 'কিবলা কম্পাস',
    Lang.en: 'Qibla compass',
    Lang.ar: 'بوصلة القبلة',
  },
  'more_mosque': {
    Lang.bn: 'আমার মসজিদ',
    Lang.en: 'My mosque',
    Lang.ar: 'مسجدي',
  },
  'more_masala': {
    Lang.bn: 'মাসআলা জিজ্ঞাসা',
    Lang.en: 'Ask a masala',
    Lang.ar: 'اسأل مسألة',
  },
  'more_live': {
    Lang.bn: 'লাইভ প্রোগ্রাম',
    Lang.en: 'Live programs',
    Lang.ar: 'برامج مباشرة',
  },
  'more_faq': {
    Lang.bn: 'জিজ্ঞাসা (FAQ)',
    Lang.en: 'FAQ',
    Lang.ar: 'الأسئلة الشائعة',
  },
  'more_about': {
    Lang.bn: 'আমাদের সম্পর্কে',
    Lang.en: 'About',
    Lang.ar: 'عن التطبيق',
  },
  'more_feedback': {
    Lang.bn: 'মতামত দিন',
    Lang.en: 'Feedback',
    Lang.ar: 'ملاحظاتك',
  },
  'more_profile': {
    Lang.bn: 'প্রোফাইল',
    Lang.en: 'Profile',
    Lang.ar: 'الملف الشخصي',
  },
  'zakat_gold': {
    Lang.bn: 'স্বর্ণ (গ্রাম)',
    Lang.en: 'Gold (grams)',
    Lang.ar: 'الذهب (غرام)',
  },
  'zakat_silver': {
    Lang.bn: 'রূপা (গ্রাম)',
    Lang.en: 'Silver (grams)',
    Lang.ar: 'الفضة (غرام)',
  },
  'zakat_cash': {
    Lang.bn: 'নগদ ও ব্যাংক',
    Lang.en: 'Cash & bank',
    Lang.ar: 'النقد والبنك',
  },
  'zakat_investments': {
    Lang.bn: 'ব্যবসা ও বিনিয়োগ',
    Lang.en: 'Business & investments',
    Lang.ar: 'الأعمال والاستثمارات',
  },
  'zakat_debts': {
    Lang.bn: 'ঋণ (বাদ যাবে)',
    Lang.en: 'Debts (deducted)',
    Lang.ar: 'الديون (تُخصم)',
  },
  'zakat_nisab': {
    Lang.bn: 'নিসাব (৮৫ গ্রাম স্বর্ণ)',
    Lang.en: 'Nisab (85g gold)',
    Lang.ar: 'النصاب (٨٥غ ذهب)',
  },
  'zakat_payable': {
    Lang.bn: 'যাকাত দিতে হবে',
    Lang.en: 'Zakat payable',
    Lang.ar: 'الزكاة الواجبة',
  },
  'zakat_below_nisab': {
    Lang.bn: 'নিসাব পরিমাণ সম্পদ নেই — যাকাত ফরজ নয়',
    Lang.en: 'Below nisab — zakat is not due',
    Lang.ar: 'أقل من النصاب — لا زكاة',
  },
  'zakat_donate': {Lang.bn: 'দান করুন', Lang.en: 'Donate', Lang.ar: 'تبرع'},
  'qibla_distance': {
    Lang.bn: 'কাবা থেকে দূরত্ব',
    Lang.en: 'Distance from Kaaba',
    Lang.ar: 'المسافة من الكعبة',
  },
  'qibla_note': {
    Lang.bn: 'ফোন সমতলে ধরে উত্তর দিক ঠিক করে নিন, তারপর তীরের দিকে মুখ করুন',
    Lang.en: 'Hold the phone flat, align north, then face the arrow',
    Lang.ar: 'أمسك الهاتف أفقيًا ووجّه الشمال ثم استدر نحو السهم',
  },
  'masala_question': {
    Lang.bn: 'আপনার প্রশ্ন লিখুন',
    Lang.en: 'Your question',
    Lang.ar: 'اكتب سؤالك',
  },
  'masala_your_name': {
    Lang.bn: 'আপনার নাম',
    Lang.en: 'Your name',
    Lang.ar: 'اسمك',
  },
  'masala_sent': {
    Lang.bn: 'প্রশ্ন পাঠানো হয়েছে — মুফতি সাহেব উত্তর দিলে জানানো হবে',
    Lang.en: 'Question sent — you will be notified of the answer',
    Lang.ar: 'أُرسل السؤال — سيتم إخطارك بالجواب',
  },
  'feedback_sent': {
    Lang.bn: 'ধন্যবাদ! মতামত পাঠানো হয়েছে',
    Lang.en: 'Thanks! Feedback sent',
    Lang.ar: 'شكرًا! أُرسلت ملاحظاتك',
  },
  'live_now': {Lang.bn: 'এখন লাইভ', Lang.en: 'Live now', Lang.ar: 'مباشر الآن'},
  'live_upcoming': {Lang.bn: 'আসছে', Lang.en: 'Upcoming', Lang.ar: 'قادم'},
  'live_past': {Lang.bn: 'সমাপ্ত', Lang.en: 'Past', Lang.ar: 'انتهى'},
  'live_notify': {
    Lang.bn: 'মনে করিয়ে দিন',
    Lang.en: 'Remind me',
    Lang.ar: 'ذكّرني',
  },
  'profile_theme': {Lang.bn: 'থিম', Lang.en: 'Theme', Lang.ar: 'السمة'},
  'profile_theme_light': {Lang.bn: 'লাইট', Lang.en: 'Light', Lang.ar: 'فاتح'},
  'profile_theme_dark': {Lang.bn: 'ডার্ক', Lang.en: 'Dark', Lang.ar: 'داكن'},
  'profile_theme_system': {
    Lang.bn: 'সিস্টেম',
    Lang.en: 'System',
    Lang.ar: 'النظام',
  },
  'profile_language': {Lang.bn: 'ভাষা', Lang.en: 'Language', Lang.ar: 'اللغة'},
  'profile_category': {
    Lang.bn: 'ক্যাটাগরি',
    Lang.en: 'Category',
    Lang.ar: 'الفئة',
  },
  'profile_category_general': {
    Lang.bn: 'সাধারণ',
    Lang.en: 'General',
    Lang.ar: 'عام',
  },
  'profile_category_hafez': {
    Lang.bn: 'হাফেজ',
    Lang.en: 'Hafez',
    Lang.ar: 'حافظ',
  },
  'profile_category_alim': {Lang.bn: 'আলেম', Lang.en: 'Alim', Lang.ar: 'عالم'},
  'profile_female_privacy_title': {
    Lang.bn: 'বোনদের গোপনীয়তার নিশ্চয়তা',
    Lang.en: 'Sisters\' privacy guarantee',
    Lang.ar: 'ضمان خصوصية الأخوات',
  },
  'app_about': {
    Lang.bn:
        'সুন্নাহ লাইফ — আস-সুন্নাহ ফাউন্ডেশনের দাওয়াতুস সুন্নাহ বিভাগের পক্ষ থেকে। '
        'নামাজ, আমল, ইলম আর তারবিয়াত — সব এক অ্যাপে।',
    Lang.en:
        'Sunnah Life — from the Dawatus Sunnah department of As-Sunnah Foundation. '
        'Prayer, amal, ilm and tarbiyah in one app.',
    Lang.ar: 'سنّة لايف — من قسم دعوة السنة بمؤسسة السنة. الصلاة والأعمال والعلم والتربية في تطبيق واحد.',
  },

  // ── Additional screen keys ──
  'today_vs': {Lang.bn: 'আজ', Lang.en: 'Today', Lang.ar: 'اليوم'},
  'today_progress': {
    Lang.bn: 'আজকের অগ্রগতি',
    Lang.en: "Today's progress",
    Lang.ar: 'تقدم اليوم',
  },
  'month_prev': {
    Lang.bn: 'আগের মাস',
    Lang.en: 'Previous month',
    Lang.ar: 'الشهر السابق',
  },
  'month_next': {
    Lang.bn: 'পরের মাস',
    Lang.en: 'Next month',
    Lang.ar: 'الشهر التالي',
  },
  'day_detail': {
    Lang.bn: 'দিনের বিবরণ',
    Lang.en: 'Day detail',
    Lang.ar: 'تفاصيل اليوم',
  },
  'habit_pick': {
    Lang.bn: 'আমল বাছুন',
    Lang.en: 'Pick an amal',
    Lang.ar: 'اختر عملًا',
  },
  'tilawat_session': {
    Lang.bn: 'তিলাওয়াত সেশন',
    Lang.en: 'Recitation session',
    Lang.ar: 'جلسة تلاوة',
  },
  'tilawat_minutes': {
    Lang.bn: 'মিনিট পড়েছেন',
    Lang.en: 'minutes read',
    Lang.ar: 'دقيقة قراءة',
  },
  'tilawat_pages': {
    Lang.bn: 'পৃষ্ঠা হিসেবে লিখুন',
    Lang.en: 'Log as pages',
    Lang.ar: 'سجّل كصفحات',
  },
  'dawah_gate_title': {
    Lang.bn: 'দাওয়াত কেন্দ্র',
    Lang.en: "Da'wah hub",
    Lang.ar: 'مركز الدعوة',
  },
  'dawah_signin_needed': {
    Lang.bn: 'দাওয়াত কেন্দ্র ব্যবহার করতে সাইন ইন করুন — দায়ী, উসরা প্রধান ও পরিদর্শকদের জন্য।',
    Lang.en: "Sign in to use the Da'wah hub — for daees, usrah heads and invigilators.",
    Lang.ar:
        'سجّل الدخول لاستخدام مركز الدعوة — للدعاة ورؤساء الحلقات والمشرفين.',
  },
  'dawah_role_needed': {
    Lang.bn: 'এই অংশটি দায়ী ও তত্ত্বাবধায়কদের জন্য। আপনার একাউন্টে এখনো দায়ীর ভূমিকা নেই।',
    Lang.en: 'This section is for daees and supervisors. Your account does not have the role yet.',
    Lang.ar: 'هذا القسم للدعاة والمشرفين. حسابك لا يملك هذه الصلاحية بعد.',
  },
  'quran_surahs': {Lang.bn: 'সূরা', Lang.en: 'Surahs', Lang.ar: 'السور'},
  'quran_ayahs': {Lang.bn: 'আয়াত', Lang.en: 'ayahs', Lang.ar: 'آية'},
  'quran_bismillah': {
    Lang.bn: 'বিসমিল্লাহির রাহমানির রাহীম',
    Lang.en: 'Bismillah',
    Lang.ar: 'بسم الله الرحمن الرحيم',
  },
  'more_share_app': {
    Lang.bn: 'অ্যাপ শেয়ার করুন',
    Lang.en: 'Share app',
    Lang.ar: 'شارك التطبيق',
  },
  'more_share_text': {
    Lang.bn: 'সুন্নাহ লাইফ — নামাজের সময়, আমলনামা, কুরআন আর তারবিয়াত এক অ্যাপে। https://sunnahlife.app',
    Lang.en: 'Sunnah Life — prayer times, amal diary, Quran and tarbiyah in one app. https://sunnahlife.app',
    Lang.ar: 'سنّة لايف — مواقيت الصلاة وسجل الأعمال والقرآن والتربية في تطبيق واحد. https://sunnahlife.app',
  },
  'send': {Lang.bn: 'পাঠান', Lang.en: 'Send', Lang.ar: 'إرسال'},
  'not_available_offline': {
    Lang.bn: 'এই অংশে ইন্টারনেট লাগবে — অনুগ্রহ করে সংযোগ দিন',
    Lang.en: 'This section needs internet — please connect',
    Lang.ar: 'هذا القسم يحتاج اتصالًا بالإنترنت',
  },
  'categories': {
    Lang.bn: 'ক্যাটাগরি',
    Lang.en: 'Categories',
    Lang.ar: 'الفئات',
  },
  'exact_alarm_title': {
    Lang.bn: 'নামাজের নিখুঁত অ্যালার্ম',
    Lang.en: 'Exact prayer alarms',
    Lang.ar: 'منبّهات الصلاة الدقيقة',
  },
  'exact_alarm_desc': {
    Lang.bn: 'ফোন ঘুমিয়ে থাকলেও ঠিক সময়ে ঘণ্টি বাজাতে অনুমতি দিন।',
    Lang.en: 'Allow alarms to ring exactly on time even when the phone dozes.',
    Lang.ar: 'اسمح للمنبّه بالرنين في وقته بالضبط حتى أثناء سكون الهاتف.',
  },
  'exact_alarm_grant': {
    Lang.bn: 'অনুমতি দিন',
    Lang.en: 'Grant',
    Lang.ar: 'السماح',
  },
  'hijri_adjust': {
    Lang.bn: 'হিজরি সমন্বয় (দিন)',
    Lang.en: 'Hijri adjust (days)',
    Lang.ar: 'تعديل الهجري (أيام)',
  },
  'prayer_please_login': {
    Lang.bn: 'অ্যাকাউন্টে সেভ হবে',
    Lang.en: 'Will be saved to your account',
    Lang.ar: 'سيُحفظ في حسابك',
  },
  'all_set': {
    Lang.bn: 'সব ঠিক আছে',
    Lang.en: 'All set',
    Lang.ar: 'كل شيء جاهز',
  },
};
