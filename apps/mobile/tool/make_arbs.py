#!/usr/bin/env python3
"""One-shot migration: kStringTable (Dart) → ARB files (bn/en/ar).

Parses lib/l10n/app_strings.dart's `kStringTable` map, merges the new keys
(sweep additions) from NEW_KEYS below, and writes:
  lib/l10n/app_bn.arb  (template)
  lib/l10n/app_en.arb
  lib/l10n/app_ar.arb

Re-runnable: the Dart table is read verbatim; ordering = table order then new
keys. Values are Dart string literals (with escapes + adjacent-literal
concatenation); they are unescaped and re-emitted as JSON strings.

NOTE: the old kStringTable in app_strings.dart is removed once the generated
AppLocalizations lands — after that this script's NEW_KEYS half is the living
catalog and app_bn.arb itself becomes the source (edit ARBs directly).
"""
import json
import re
import sys
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / "lib/l10n"

# ── New keys (B7 sweep of hard-coded widget literals + enum label keys) ─────
NEW_KEYS = {
    # app chrome
    "app_title": {"bn": "সুন্নাহ লাইফ", "en": "Sunnah Life", "ar": "سنّة لايف"},
    "boot_failed": {"bn": "শুরু করা যায়নি", "en": "Failed to start", "ar": "تعذّر بدء التشغيل"},
    "org_footer": {
        "bn": "আস-সুন্নাহ ফাউন্ডেশন · দাওয়াতুস সুন্নাহ",
        "en": "As-Sunnah Foundation · Dawatus Sunnah",
        "ar": "مؤسسة السنة · دعوة السنة",
    },
    "onb_org": {
        "bn": "আস-সুন্নাহ ফাউন্ডেশন — দাওয়াতুস সুন্নাহ",
        "en": "As-Sunnah Foundation — Dawatus Sunnah",
        "ar": "مؤسسة السنة — دعوة السنة",
    },
    "onb_bismillah_start": {
        "bn": "বিসমিল্লাহ — শুরু করুন",
        "en": "Bismillah — let's begin",
        "ar": "بسم الله — لنبدأ",
    },
    "onb_bd_defaults": {
        "bn": "বাংলাদেশের জন্য ডিফল্ট: করাচি পদ্ধতি ও হানাফি আসর। সব হিসাব আপনার ফোনেই হয় — ইন্টারনেট ছাড়াও কাজ করবে।",
        "en": "Defaults for Bangladesh: Karachi method, Hanafi Asr. Everything is computed on your phone — works offline.",
        "ar": "الافتراضي لبنغلاديش: طريقة كراتشي ومذهب حنفي في العصر. تُحسب المواقيت على هاتفك — يعمل دون إنترنت.",
    },
    # language picker descriptions
    "lang_desc_bn": {
        "bn": "বাংলাদেশের প্রধান ভাষা",
        "en": "The main language of Bangladesh",
        "ar": "اللغة الرئيسية في بنغلاديش",
    },
    "lang_desc_en": {
        "bn": "ইংরেজি",
        "en": "English",
        "ar": "الإنجليزية",
    },
    "lang_desc_ar": {
        "bn": "আরবি — ডান থেকে বাম",
        "en": "Arabic — fully right-to-left",
        "ar": "بالدعم الكامل للاتجاه من اليمين إلى اليسار",
    },
    # country / city picker
    "country_bd": {"bn": "বাংলাদেশ", "en": "Bangladesh", "ar": "بنغلاديش"},
    "country_abroad": {"bn": "বিদেশ", "en": "Abroad", "ar": "الخارج"},
    "country_intl": {"bn": "আন্তর্জাতিক", "en": "International", "ar": "دولي"},
    "city_picker_title": {
        "bn": "শহর নির্বাচন করুন",
        "en": "Choose your city",
        "ar": "اختر مدينتك",
    },
    "city_no_match": {
        "bn": "কোনো শহর মেলেনি — বানান দেখে নিন বা মূল তালিকা থেকে বাছুন",
        "en": "No city matched — check the spelling or pick from the main list",
        "ar": "لا توجد مدينة مطابقة — تحقق من التهجئة أو اختر من القائمة الرئيسة",
    },
    # waqt names
    "waqt_fajr": {"bn": "ফজর", "en": "Fajr", "ar": "الفجر"},
    "waqt_sunrise": {"bn": "সূর্যোদয়", "en": "Sunrise", "ar": "الشروق"},
    "waqt_ishraq": {"bn": "ইশরাক", "en": "Ishraq", "ar": "الإشراق"},
    "waqt_duha": {"bn": "দুহা", "en": "Duha", "ar": "الضحى"},
    "waqt_dhuhr": {"bn": "যোহর", "en": "Dhuhr", "ar": "الظهر"},
    "waqt_asr": {"bn": "আসর", "en": "Asr", "ar": "العصر"},
    "waqt_maghrib": {"bn": "মাগরিব", "en": "Maghrib", "ar": "المغرب"},
    "waqt_sunset": {"bn": "সূর্যাস্ত", "en": "Sunset", "ar": "الغروب"},
    "waqt_isha": {"bn": "এশা", "en": "Isha", "ar": "العشاء"},
    "waqt_tahajjud": {"bn": "তাহাজ্জুদ", "en": "Tahajjud", "ar": "التهجد"},
    # gregorian months
    "month_1": {"bn": "জানুয়ারি", "en": "January", "ar": "يناير"},
    "month_2": {"bn": "ফেব্রুয়ারি", "en": "February", "ar": "فبراير"},
    "month_3": {"bn": "মার্চ", "en": "March", "ar": "مارس"},
    "month_4": {"bn": "এপ্রিল", "en": "April", "ar": "أبريل"},
    "month_5": {"bn": "মে", "en": "May", "ar": "مايو"},
    "month_6": {"bn": "জুন", "en": "June", "ar": "يونيو"},
    "month_7": {"bn": "জুলাই", "en": "July", "ar": "يوليو"},
    "month_8": {"bn": "আগস্ট", "en": "August", "ar": "أغسطس"},
    "month_9": {"bn": "সেপ্টেম্বর", "en": "September", "ar": "سبتمبر"},
    "month_10": {"bn": "অক্টোবর", "en": "October", "ar": "أكتوبر"},
    "month_11": {"bn": "নভেম্বর", "en": "November", "ar": "نوفمبر"},
    "month_12": {"bn": "ডিসেম্বর", "en": "December", "ar": "ديسمبر"},
    # home
    "prayer_offline_chip": {
        "bn": "সব হিসাব অফলাইনে আপনার ফোনেই হয়",
        "en": "All times are computed offline on your phone",
        "ar": "تُحسب جميع المواقيت دون اتصال على هاتفك",
    },
    "prayer_bell_enable": {
        "bn": "ঘণ্টি চালু করুন",
        "en": "Turn the bell on",
        "ar": "تشغيل الجرس",
    },
    "prayer_bell_disable": {
        "bn": "ঘণ্টি বন্ধ করুন",
        "en": "Turn the bell off",
        "ar": "إيقاف الجرس",
    },
    # roles / levels / madhhab / methods (enum label keys)
    "role_user": {"bn": "সাধারণ ব্যবহারকারী", "en": "Member", "ar": "عضو"},
    "role_daee": {"bn": "দায়ী", "en": "Da'ee", "ar": "داعٍ"},
    "role_usrah_head": {"bn": "উসরা প্রধান", "en": "Usrah head", "ar": "رئيس الحلقة"},
    "role_invigilator": {"bn": "পরিদর্শক", "en": "Invigilator", "ar": "مشرف"},
    "role_full_admin": {"bn": "প্রধান অ্যাডমিন", "en": "Admin", "ar": "المدير العام"},
    "level_none": {"bn": "শুরুর পর্যায়", "en": "Beginning stage", "ar": "مرحلة البداية"},
    "level_muhibbus_sunnah": {
        "bn": "মুহিব্বুস সুন্নাহ",
        "en": "Muhibbus Sunnah",
        "ar": "محيبّ السنة",
    },
    "level_farze_ain_1": {
        "bn": "ফরযে আইন — ক্যাটাগরি ১",
        "en": "Farze Ain — category 1",
        "ar": "فرض عين — الفئة الأولى",
    },
    "level_farze_ain_2": {
        "bn": "ফরযে আইন — ক্যাটাগরি ২",
        "en": "Farze Ain — category 2",
        "ar": "فرض عين — الفئة الثانية",
    },
    "madhhab_hanafi": {"bn": "হানাফি", "en": "Hanafi", "ar": "الحنفي"},
    "madhhab_shafii": {"bn": "শাফেয়ি", "en": "Shafi'i", "ar": "الشافعي"},
    "method_karachi": {
        "bn": "করাচি (১৮°/১৮°)",
        "en": "Karachi (18°/18°)",
        "ar": "كراتشي (١٨°/١٨°)",
    },
    "method_mwl": {
        "bn": "মুসলিম ওয়ার্ল্ড লীগ",
        "en": "Muslim World League",
        "ar": "رابطة العالم الإسلامي",
    },
    "method_isna": {
        "bn": "ISNA (উত্তর আমেরিকা)",
        "en": "ISNA (North America)",
        "ar": "إسنا (أمريكا الشمالية)",
    },
    "method_egypt": {"bn": "মিসরীয়", "en": "Egyptian", "ar": "الهيئة المصرية"},
    "method_makkah": {
        "bn": "উম্মুল কুরা (মক্কা)",
        "en": "Umm al-Qura (Makkah)",
        "ar": "أم القرى (مكة)",
    },
    "method_dubai": {"bn": "দুবাই", "en": "Dubai", "ar": "دبي"},
    # amal categories
    "cat_salah": {"bn": "নামাজ", "en": "Salah", "ar": "الصلاة"},
    "cat_quran": {"bn": "কুরআন", "en": "Qur'an", "ar": "القرآن"},
    "cat_dhikr": {"bn": "যিকর ও দোয়া", "en": "Dhikr & Dua", "ar": "الذكر والدعاء"},
    "cat_akhlaq": {"bn": "আখলাক", "en": "Akhlaq", "ar": "الأخلاق"},
    "cat_dawat": {"bn": "দাওয়াত", "en": "Da'wah", "ar": "الدعوة"},
    "cat_lifestyle": {"bn": "জীবনাচরণ", "en": "Lifestyle", "ar": "نمط الحياة"},
    "cat_sunnah": {
        "bn": "সাপ্তাহিক ও মাসিক সুন্নাহ",
        "en": "Weekly & monthly sunnahs",
        "ar": "السنن الأسبوعية والشهرية",
    },
    "cat_personal": {"bn": "ব্যক্তিগত লক্ষ্য", "en": "Personal goals", "ar": "أهداف شخصية"},
    # amal extras
    "target_label": {"bn": "লক্ষ্য", "en": "Target", "ar": "الهدف"},
    "amal_done": {"bn": "হয়েছে", "en": "Done", "ar": "تم"},
    "amal_not_done": {"bn": "হয়নি", "en": "Not done", "ar": "لم يتم"},
    "amal_auto_logged": {
        "bn": "স্বয়ংক্রিয়ভাবে লেখা হয়েছে",
        "en": "Logged automatically",
        "ar": "سُجّل تلقائيًا",
    },
    "amal_unlock_reason": {
        "bn": "মোবাইল অ্যাপ থেকে অনুরোধ",
        "en": "Requested from the mobile app",
        "ar": "طلب من تطبيق الهاتف",
    },
    "cadence_weekly_fri": {"bn": "শুক্রবার", "en": "Fridays", "ar": "يوم الجمعة"},
    "cadence_weekly_mon_thu": {
        "bn": "সোম ও বৃহস্পতিবার",
        "en": "Mondays & Thursdays",
        "ar": "الاثنين والخميس",
    },
    "cadence_ayyam_beez": {
        "bn": "আইয়ামে বীজ (১৩–১৫)",
        "en": "Ayyam al-Beez (13–15)",
        "ar": "أيام البيض (١٣–١٥)",
    },
    "tilawat_target_pages": {
        "bn": "পৃষ্ঠা",
        "en": "pages",
        "ar": "صفحة",
    },
    "tilawat_target_general": {
        "bn": "তিলাওয়াত: ১ পৃষ্ঠা",
        "en": "Tilawat: 1 page",
        "ar": "التلاوة: صفحة واحدة",
    },
    "tilawat_target_hafez": {
        "bn": "তিলাওয়াত: ১ পারা",
        "en": "Tilawat: 1 juz",
        "ar": "التلاوة: جزء واحد",
    },
    "tilawat_target_alim": {
        "bn": "তিলাওয়াত: ১০ পৃষ্ঠা",
        "en": "Tilawat: 10 pages",
        "ar": "التلاوة: ١٠ صفحات",
    },
    # dawah
    "dawah_tab_usrah": {"bn": "উসরা", "en": "Usrah", "ar": "الحلقة"},
    "dawah_tab_reviews": {"bn": "রিভিউ", "en": "Reviews", "ar": "المراجعات"},
    "dawah_share_message": {
        "bn": "আসসালামু আলাইকুম। সুন্নাহ লাইফ অ্যাপে আমার সাথে যুক্ত হোন:",
        "en": "Assalamu alaikum. Join me on the Sunnah Life app:",
        "ar": "السلام عليكم. انضم إليّ في تطبيق سنّة لايف:",
    },
    "dawah_no_usrah": {
        "bn": "আপনি এখনো কোনো উসরায় যুক্ত নন — অ্যাডমিন যুক্ত করলে এখানে দেখা যাবে",
        "en": "You are not in an usrah yet — once an admin adds you it shows up here",
        "ar": "لست في حلقة بعد — ستظهر هنا حين يضيفك المسؤول",
    },
    "dawah_no_reviews": {
        "bn": "এখনো কোনো সাপ্তাহিক রিভিউ হয়নি",
        "en": "No weekly reviews yet",
        "ar": "لا توجد مراجعات أسبوعية بعد",
    },
    "dawah_week": {"bn": "সপ্তাহ", "en": "Week", "ar": "الأسبوع"},
    "review_status_overdue": {"bn": "বিলম্বিত", "en": "Overdue", "ar": "متأخرة"},
    "review_status_pending": {"bn": "অপেক্ষমাণ", "en": "Pending", "ar": "معلقة"},
    # ilm
    "badge_new": {"bn": "নতুন", "en": "New", "ar": "جديد"},
    "quran_juz": {"bn": "জুয়", "en": "Juz", "ar": "الجزء"},
    "sunnah_cat_all": {"bn": "সব", "en": "All", "ar": "الكل"},
    "sunnah_cat_daily": {
        "bn": "দৈনন্দিন সুন্নাহ",
        "en": "Daily sunnahs",
        "ar": "السنن اليومية",
    },
    "sunnah_cat_forgotten": {
        "bn": "বিস্মৃত সুন্নাহ",
        "en": "Forgotten sunnahs",
        "ar": "السنن المهجورة",
    },
    "sunnah_cat_salah": {
        "bn": "নামাজের সুন্নাহ",
        "en": "Salah sunnahs",
        "ar": "سنن الصلاة",
    },
    "iman_branch_heart": {
        "bn": "অন্তরের ঈমান",
        "en": "Iman of the heart",
        "ar": "إيمان القلب",
    },
    "iman_branch_tongue": {
        "bn": "জবানের ঈমান",
        "en": "Iman of the tongue",
        "ar": "إيمان اللسان",
    },
    "iman_branch_body": {
        "bn": "দেহের ঈমান",
        "en": "Iman of the body",
        "ar": "إيمان الجوارح",
    },
    # self-test / quiz
    "quiz_minutes": {"bn": "মিনিট", "en": "min", "ar": "دقيقة"},
    "quiz_questions": {"bn": "প্রশ্ন", "en": "questions", "ar": "سؤالًا"},
    "quiz_great": {
        "bn": "আলহামদুলিল্লাহ — দুর্দান্ত!",
        "en": "Alhamdulillah — excellent!",
        "ar": "الحمد لله — ممتاز!",
    },
    "quiz_needs_more": {
        "bn": "আরও একটু পড়া দরকার — আবার চেষ্টা করুন",
        "en": "A little more study is needed — try again",
        "ar": "تحتاج مزيدًا من الدراسة — أعد المحاولة",
    },
    # more screens
    "unit_km": {"bn": "কিমি", "en": "km", "ar": "كم"},
    "feedback_hint": {
        "bn": "আপনার মতামত লিখুন…",
        "en": "Write your feedback…",
        "ar": "اكتب ملاحظاتك…",
    },
    "live_sisters_only": {
        "bn": "শুধু বোনদের সেশন",
        "en": "Sisters-only session",
        "ar": "جلسة للنساء فقط",
    },
    "live_host": {"bn": "উপস্থাপক", "en": "Host", "ar": "المقدّم"},
    "live_will_remind": {
        "bn": "মনে করিয়ে দেওয়া হবে ইনশাআল্লাহ",
        "en": "In sha Allah you will be reminded",
        "ar": "سنذكّرك إن شاء الله",
    },
    "qibla_north": {"bn": "উত্তর", "en": "North", "ar": "الشمال"},
    "qibla_dial_hint": {
        "bn": "ডায়াল ঘোরান — তীরটি যেন উপরে থাকে",
        "en": "Rotate the dial — keep the arrow on top",
        "ar": "أدر القرص — اجعل السهم في الأعلى",
    },
    "qibla_dial": {"bn": "ডায়াল", "en": "Dial", "ar": "القرص"},
    "masala_note": {
        "bn": "দ্বীনি মাসআলা লিখে জানান — মুফতি সাহেব ইনশাআল্লাহ উত্তর দিবেন।",
        "en": "Send your religious question — the mufti will answer, in sha Allah.",
        "ar": "أرسل مسألتك الشرعية — وسيجيب المفتي إن شاء الله.",
    },
    "masala_phone": {
        "bn": "মোবাইল (ঐচ্ছিক)",
        "en": "Mobile (optional)",
        "ar": "الهاتف (اختياري)",
    },
    "masala_offline": {
        "bn": "অফলাইনে পাঠানো যাবে না — ইন্টারনেট সংযোগ দরকার",
        "en": "Cannot be sent offline — internet required",
        "ar": "لا يمكن الإرسال دون اتصال — يلزم الإنترنت",
    },
    # profile
    "profile_app_section": {"bn": "অ্যাপ", "en": "App", "ar": "التطبيق"},
    "gender_admin_only": {
        "bn": "শুধু অ্যাডমিন পরিবর্তন করতে পারেন",
        "en": "only an admin can change it",
        "ar": "يمكن للمسؤول وحده تغييره",
    },
    "hijri_increase": {
        "bn": "হিজরি সমন্বয় বাড়ান",
        "en": "Increase Hijri adjustment",
        "ar": "زيادة تعديل الهجري",
    },
    "hijri_decrease": {
        "bn": "হিজরি সমন্বয় কমান",
        "en": "Decrease Hijri adjustment",
        "ar": "إنقاص تعديل الهجري",
    },
    "increase": {"bn": "বাড়ান", "en": "Increase", "ar": "زيادة"},
    "decrease": {"bn": "কমান", "en": "Decrease", "ar": "إنقاص"},
    "onb_setup": {"bn": "সেটআপ", "en": "setup", "ar": "الإعداد"},
    # compass points
    "compass_n": {"bn": "উত্তর", "en": "North", "ar": "الشمال"},
    "compass_ne": {"bn": "উত্তর-পূর্ব", "en": "Northeast", "ar": "الشمال الشرقي"},
    "compass_e": {"bn": "পূর্ব", "en": "East", "ar": "الشرق"},
    "compass_se": {"bn": "দক্ষিণ-পূর্ব", "en": "Southeast", "ar": "الجنوب الشرقي"},
    "compass_s": {"bn": "দক্ষিণ", "en": "South", "ar": "الجنوب"},
    "compass_sw": {"bn": "দক্ষিণ-পশ্চিম", "en": "Southwest", "ar": "الجنوب الغربي"},
    "compass_w": {"bn": "পশ্চিম", "en": "West", "ar": "الغرب"},
    "compass_nw": {"bn": "উত্তর-পশ্চিম", "en": "Northwest", "ar": "الشمال الغربي"},
    # zakat extras
    "zakat_percent_note": {
        "bn": "সম্পদের ২.৫%",
        "en": "2.5% of wealth",
        "ar": "2.5% من المال",
    },
    "zakat_net": {"bn": "নেট", "en": "net", "ar": "الصافي"},
    "zakat_donation_link": {
        "bn": "দানের লিংক",
        "en": "Donation link",
        "ar": "رابط التبرع",
    },
    "live_programs_count": {
        "bn": "টি প্রোগ্রাম",
        "en": "programs",
        "ar": "برنامجًا",
    },
    # ── C-W4a: global chrome (header panels, contact, bottom bar) ──────────
    "header_notifications": {
        "bn": "নোটিফিকেশন",
        "en": "Notifications",
        "ar": "الإشعارات",
    },
    "header_reminders": {"bn": "রিমাইন্ডার", "en": "Reminders", "ar": "تذكيرات"},
    "notifications_guest_hint": {
        "bn": "সাইন ইন করলে উসরা ঘোষণা, সাপ্তাহিক রিভিউ ও লাইভ রিমাইন্ডার এখানে দেখা যাবে।",
        "en": "Sign in to see usrah announcements, weekly reviews and live reminders here.",
        "ar": "سجّل الدخول لعرض إعلانات الأسرة والمراجعات الأسبوعية وتذكيرات البث هنا.",
    },
    "notifications_empty": {
        "bn": "এখনো কোনো ঘোষণা নেই",
        "en": "No announcements yet",
        "ar": "لا توجد إعلانات بعد",
    },
    "notifications_announcements": {
        "bn": "ঘোষণা",
        "en": "Announcements",
        "ar": "إعلانات",
    },
    "notifications_live": {
        "bn": "লাইভ অনুষ্ঠান",
        "en": "Live programs",
        "ar": "برامج مباشرة",
    },
    "reminders_empty": {
        "bn": "এখনো কোনো রিমাইন্ডার নেই",
        "en": "No reminders yet",
        "ar": "لا توجد تذكيرات بعد",
    },
    "reminder_mark_done": {
        "bn": "সম্পন্ন করুন",
        "en": "Mark done",
        "ar": "وضع علامة تم",
    },
    "reminder_due": {"bn": "এখন", "en": "Due", "ar": "الآن"},
    "reminder_overdue": {
        "bn": "মেয়াদ পেরিয়েছে",
        "en": "Overdue",
        "ar": "متأخر",
    },
    "reminder_upcoming": {"bn": "আসছে", "en": "Upcoming", "ar": "قادم"},
    "contact_title": {"bn": "যোগাযোগ", "en": "Contact us", "ar": "تواصل معنا"},
    "contact_call": {"bn": "কল করুন", "en": "Call", "ar": "اتصال"},
    "contact_website": {
        "bn": "ওয়েবসাইট",
        "en": "Website",
        "ar": "الموقع الإلكتروني",
    },
    "contact_call_failed": {
        "bn": "কল করা যায়নি",
        "en": "Could not place the call",
        "ar": "تعذّر إجراء الاتصال",
    },
    # ── C-W4b: home sections per spec order ─────────────────────────────────
    "quick_access": {"bn": "দ্রুত প্রবেশ", "en": "Quick access", "ar": "وصول سريع"},
    "quick_quran_desc": {
        "bn": "সূরা ও অনুবাদ",
        "en": "Surahs & translation",
        "ar": "السور والترجمة",
    },
    "quick_duas_desc": {
        "bn": "দৈনন্দিন দোয়া",
        "en": "Everyday duas",
        "ar": "أدعية يومية",
    },
    "quick_amal_desc": {
        "bn": "মুহাসাবা ডায়েরি",
        "en": "Muhasaba diary",
        "ar": "يومية المحاسبة",
    },
    "quick_live_desc": {
        "bn": "সরাসরি অনুষ্ঠান",
        "en": "Live programs",
        "ar": "برامج مباشرة",
    },
    "most_used": {
        "bn": "সর্বাধিক ব্যবহৃত",
        "en": "Most used",
        "ar": "الأكثر استخدامًا",
    },
    "most_used_empty": {
        "bn": "গত ৩০ দিনে সবচেয়ে বেশি লেখা আমলগুলো এখানে দেখা যাবে — আজকের ডায়েরি থেকে শুরু করুন",
        "en": "Your most-logged amals of the last 30 days appear here — start from today's diary",
        "ar": "تظهر هنا أكثر عباداتك تسجيلًا خلال آخر ٣٠ يومًا — ابدأ بيومية اليوم",
    },
    "most_used_log_today": {
        "bn": "আজ লিখুন",
        "en": "Log today",
        "ar": "سجّل اليوم",
    },
    "most_used_days": {"bn": "দিন", "en": "days", "ar": "يوم"},
    "countdown_to_schedule": {
        "bn": "সময়সূচি দেখুন",
        "en": "View schedule",
        "ar": "عرض المواقيت",
    },
    "next_bell_chip": {
        "bn": "পরবর্তী বেল",
        "en": "Next bell",
        "ar": "الجرس القادم",
    },
    "live_next": {"bn": "পরবর্তী লাইভ", "en": "Next live", "ar": "البث القادم"},
    "live_join_hint": {
        "bn": "দেখতে ট্যাপ করুন",
        "en": "Tap to watch",
        "ar": "اضغط للمشاهدة",
    },
    "ilm_courses_desc": {
        "bn": "শেখার কোর্স ও লেসন",
        "en": "Courses & lessons",
        "ar": "دروس ومقررات",
    },
    "ilm_quizzes_desc": {
        "bn": "আত্মমূল্যায়ন কুইজ",
        "en": "Self-assessment quizzes",
        "ar": "اختبارات ذاتية",
    },
    # ── W4c: personal-goal lifecycle ──────────────────────────────────────────
    "goals_title": {"bn": "আমার লক্ষ্য", "en": "My Goals", "ar": "أهدافي"},
    "goals_new": {"bn": "নতুন লক্ষ্য", "en": "New goal", "ar": "هدف جديد"},
    "goals_amal_picker": {
        "bn": "আমল নির্বাচন করুন",
        "en": "Choose an amal",
        "ar": "اختر عبادة",
    },
    "goals_amal_short": {"bn": "আমল", "en": "Amal", "ar": "العبادة"},
    "goals_title_label": {
        "bn": "লক্ষ্যের নাম",
        "en": "Goal title",
        "ar": "عنوان الهدف",
    },
    "goals_target_label": {
        "bn": "লক্ষ্য মাত্রা (ঐচ্ছিক)",
        "en": "Target (optional)",
        "ar": "الهدف (اختياري)",
    },
    "goals_note_label": {
        "bn": "নোট (ঐচ্ছিক)",
        "en": "Note (optional)",
        "ar": "ملاحظة (اختياري)",
    },
    "goals_submit": {"bn": "প্রস্তাব করুন", "en": "Propose", "ar": "اقترح"},
    "goals_signin_needed": {
        "bn": "লক্ষ্য সংরক্ষণ ও অনুমোদনের জন্য সাইন-ইন দরকার",
        "en": "Sign in to set and track goals",
        "ar": "سجّل الدخول لتحديد الأهداف ومتابعتها",
    },
    "goals_empty": {
        "bn": "এখনো কোনো লক্ষ্য নেই — প্রথম লক্ষ্য ঠিক করুন",
        "en": "No goals yet — set your first one",
        "ar": "لا أهداف بعد — حدّد هدفك الأول",
    },
    "goals_open_label": {
        "bn": "খোলা লক্ষ্য",
        "en": "Open goals",
        "ar": "أهداف مفتوحة",
    },
    "goal_status_proposed": {
        "bn": "অপেক্ষমাণ",
        "en": "Pending review",
        "ar": "بانتظار المراجعة",
    },
    "goal_status_approved": {
        "bn": "অনুমোদিত",
        "en": "Approved",
        "ar": "معتمد",
    },
    "goal_status_rejected": {
        "bn": "বাতিল",
        "en": "Rejected",
        "ar": "مرفوض",
    },
    "goal_status_completed": {
        "bn": "সম্পন্ন",
        "en": "Completed",
        "ar": "مكتمل",
    },
    "goal_status_withdrawn": {
        "bn": "প্রত্যাহৃত",
        "en": "Withdrawn",
        "ar": "مسحوب",
    },
    "goals_reject_reason_label": {
        "bn": "কারণ",
        "en": "Reason",
        "ar": "السبب",
    },
    "goals_queue_title": {
        "bn": "লক্ষ্য অনুমোদনের অপেক্ষায়",
        "en": "Goal approvals",
        "ar": "طلبات اعتماد الأهداف",
    },
    "goals_queue_empty": {
        "bn": "কোনো অপেক্ষমাণ লক্ষ্য নেই",
        "en": "No pending goals",
        "ar": "لا أهداف بانتظار الاعتماد",
    },
    "goals_approve": {"bn": "অনুমোদন", "en": "Approve", "ar": "اعتماد"},
    "goals_reject": {"bn": "বাতিল", "en": "Reject", "ar": "رفض"},
    "goals_reject_hint": {
        "bn": "বাতিলের কারণ লিখুন (ঐচ্ছিক)",
        "en": "Reject reason (optional)",
        "ar": "سبب الرفض (اختياري)",
    },
    "goals_member_label": {"bn": "সদস্য", "en": "Member", "ar": "العضو"},
    "goals_remove": {"bn": "সরান", "en": "Remove", "ar": "إزالة"},
    "goals_remove_confirm": {
        "bn": "লক্ষ্যটি তালিকা থেকে সরানো হবে?",
        "en": "Remove this goal from your list?",
        "ar": "إزالة هذا الهدف من القائمة؟",
    },
    "goals_proposed_toast": {
        "bn": "লক্ষ্য প্রস্তাবিত — উসরা প্রধানের অনুমোদনের অপেক্ষায়",
        "en": "Proposed — awaiting your usrah head's approval",
        "ar": "تم الاقتراح — بانتظار اعتماد رئيس الأسر",
    },
    "goals_approved_toast": {
        "bn": "অনুমোদিত হয়েছে",
        "en": "Approved",
        "ar": "تم الاعتماد",
    },
    "goals_rejected_toast": {
        "bn": "বাতিল হয়েছে",
        "en": "Rejected",
        "ar": "تم الرفض",
    },
    # ── W4c: custom checklist (local, per-day) ─────────────────────────────────
    "checklist_title": {
        "bn": "নিজের তালিকা",
        "en": "My checklist",
        "ar": "قائمتي",
    },
    "checklist_hint": {
        "bn": "নতুন কাজ লিখুন",
        "en": "Add a task",
        "ar": "أضف مهمة",
    },
    "checklist_add": {"bn": "যোগ করুন", "en": "Add", "ar": "إضافة"},
    "checklist_remove": {"bn": "মুছুন", "en": "Delete", "ar": "حذف"},
    "checklist_remove_confirm": {
        "bn": "কাজটি মুছে ফেলা হবে?",
        "en": "Delete this item?",
        "ar": "حذف هذا البند؟",
    },
    "checklist_local_note": {
        "bn": "শুধু এই ডিভাইসে সংরক্ষিত",
        "en": "Stays on this device only",
        "ar": "يبقى على هذا الجهاز فقط",
    },
}


def strip_comments(src: str) -> str:
    """Remove // comments while respecting quoted strings."""
    out = []
    i, n = 0, len(src)
    quote = None  # current quote char or None
    while i < n:
        c = src[i]
        if quote:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(src[i + 1])
                i += 2
                continue
            if c == quote:
                quote = None
            i += 1
        else:
            if c == "'" or c == '"':
                quote = c
                out.append(c)
                i += 1
            elif c == "/" and i + 1 < n and src[i + 1] == "/":
                j = src.find("\n", i)
                i = n if j < 0 else j
            else:
                out.append(c)
                i += 1
    return "".join(out)


def unescape(s: str) -> str:
    return (
        s.replace("\\'", "'")
        .replace('\\"', '"')
        .replace("\\\\", "\\")
        .replace("\\n", "\n")
        .replace("\\t", "\t")
    )


def parse_table(src: str):
    src = strip_comments(src)
    m = re.search(r"kStringTable\s*=\s*\{(.*)\};?\s*$", src, re.S)
    if not m:
        return {}
    body = m.group(1)
    entry_re = re.compile(r"'([a-z0-9_]+)':\s*\{", re.S)
    results = {}
    pos = 0
    while True:
        em = entry_re.search(body, pos)
        if not em:
            break
        start = em.end()
        depth, i = 1, start
        while depth > 0 and i < len(body):
            if body[i] == "{":
                depth += 1
            elif body[i] == "}":
                depth -= 1
            i += 1
        chunk = body[start : i - 1]
        pos = i
        vals = {}
        strlit = r"(?:'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*\")"
        for lang in ("bn", "en", "ar"):
            lm = re.search(r"Lang\." + lang + r":\s*((?:" + strlit + r"\s*)+)", chunk)
            if lm:
                parts = re.findall(strlit, lm.group(1))
                vals[lang] = unescape("".join(p[1:-1] for p in parts))
        results[em.group(1)] = vals
    return results


KEY_MAP_BEGIN = "// ─── BEGIN GENERATED KEY MAP (tool/make_arbs.py --keymap) ───────────────────"
KEY_MAP_END = "// ─── END GENERATED KEY MAP ──────────────────────────────────────────────────"


def write_keymap():
    """Regenerate the _translate switch in app_strings.dart from the generated
    AppLocalizations abstract getters (getter name == ARB key, identity)."""
    gen = OUT / "generated" / "app_localizations.dart"
    if not gen.exists():
        sys.exit("run `flutter gen-l10n` first — generated class missing")
    src = gen.read_text(encoding="utf-8")
    # abstract members: `String get <name>;`
    getters = re.findall(r"^\s+String get ([A-Za-z0-9_]+);", src, re.M)
    if not getters:
        sys.exit("no getters found in generated AppLocalizations")
    arb = json.loads((OUT / "app_bn.arb").read_text(encoding="utf-8"))
    arb_keys = [k for k in arb if not k.startswith("@")]
    if set(getters) != set(arb_keys):
        sys.exit(
            f"getter/key drift: only-generated={set(getters) - set(arb_keys)} "
            f"only-arb={set(arb_keys) - set(getters)}"
        )
    lines = [KEY_MAP_BEGIN]
    lines.append("String _translate(AppLocalizations l, String key) => switch (key) {")
    for name in arb_keys:  # keep ARB order
        lines.append(f"  '{name}' => l.{name},")
    lines.append("  _ => key, // unknown keys surface themselves (never in shipped ARBs)")
    lines.append("};")
    lines.append(KEY_MAP_END)
    block = "\n".join(lines)
    strings_path = OUT / "app_strings.dart"
    old = strings_path.read_text(encoding="utf-8")
    if KEY_MAP_BEGIN not in old or KEY_MAP_END not in old:
        sys.exit("key-map markers not found in app_strings.dart")
    start = old.index(KEY_MAP_BEGIN)
    end = old.index(KEY_MAP_END) + len(KEY_MAP_END)
    new = old[:start] + block + old[end:]
    strings_path.write_text(new, encoding="utf-8")
    print(f"keymap written: {len(arb_keys)} keys → app_strings.dart _translate")


def main():
    if "--keymap" in sys.argv:
        write_keymap()
        return
    table = parse_table((OUT / "app_strings.dart").read_text(encoding="utf-8"))
    arb_path = OUT / "app_bn.arb"
    if table:
        missing = [
            k
            for k, v in table.items()
            if not all(v.get(l, "").strip() for l in ("bn", "en", "ar"))
        ]
        if missing:
            sys.exit(f"incomplete entries in kStringTable: {missing}")
        dupes = [k for k in NEW_KEYS if k in table]
        if dupes:
            sys.exit(f"NEW_KEYS collide with the table: {dupes}")
        table.update(NEW_KEYS)
        print(
            f"total keys: {len(table)} (table {len(table) - len(NEW_KEYS)} + new {len(NEW_KEYS)})"
        )
    elif arb_path.exists():
        # kStringTable is gone (migrated): app_bn.arb is the living catalog —
        # merge in any NEW_KEYS not present yet.
        arbs = {
            loc: {
                k: v
                for k, v in json.loads(
                    (OUT / f"app_{loc}.arb").read_text(encoding="utf-8")
                ).items()
                if not k.startswith("@")
            }
            for loc in ("bn", "en", "ar")
        }
        table = {
            k: {loc: arbs[loc][k] for loc in ("bn", "en", "ar")}
            for k in arbs["bn"]
        }
        missing = [
            k
            for k, v in table.items()
            if not all(str(v.get(loc, "")).strip() for loc in ("bn", "en", "ar"))
        ]
        if missing:
            sys.exit(f"ARB entries missing a locale: {missing}")
        added = {k: v for k, v in NEW_KEYS.items() if k not in table}
        table.update(added)
        print(f"total keys: {len(table)} (arb merge mode, +{len(added)} new)")
    else:
        table = dict(NEW_KEYS)
        print(f"total keys: {len(table)} (new-keys mode; table already migrated)")
    for loc in ("bn", "en", "ar"):
        out = {"@@locale": loc}
        for k, v in table.items():
            out[k] = v[loc]
        path = OUT / f"app_{loc}.arb"
        path.write_text(
            json.dumps(out, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        print(f"wrote {path} ({len(out) - 1} messages)")


if __name__ == "__main__":
    main()
