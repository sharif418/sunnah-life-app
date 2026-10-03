/// The paper muhasaba diary's layout — the Today screen's backbone.
///
/// Source of truth: packages/content/diary-instructions.json (`paperLayout`
/// + `instructions`), the Foundation's paper diary VERBATIM. Mirrored here as
/// constants so the diary renders synchronously (no asset round-trip on the
/// most-opened screen); test/diary_layout_test.dart fails if this mirror and
/// the JSON ever drift apart.
library;

import '../models/domain.dart';

class PaperRow {
  const PaperRow(this.labelBn, this.amalKeys);
  final String labelBn;

  /// Catalog keys that fill this row — the first one present wins on paper;
  /// in the app every present key renders as its own row.
  final List<String> amalKeys;
}

class PaperGroup {
  const PaperGroup(this.groupBn, this.rows, {this.noteBn});
  final String groupBn;
  final String? noteBn;
  final List<PaperRow> rows;
}

const List<PaperGroup> kPaperDiaryLayout = [
  PaperGroup('সালাত ট্র্যাকার', [
    PaperRow('ফজর', ['salat_fajr']),
    PaperRow('যোহর', ['salat_dhuhr']),
    PaperRow('আসর', ['salat_asr']),
    PaperRow('মাগরিব', ['salat_maghrib']),
    PaperRow('এশা', ['salat_isha']),
  ], noteBn: 'জামাতে আদায় করলে ✔, একাকী করলে /, কাযা হলে □ চিহ্ন ব্যবহার করুন'),
  PaperGroup('বিতর', [
    PaperRow('বিতর সালাত আদায় করেছি', ['salat_witr']),
  ]),
  PaperGroup('সুন্নাহ ও নফল সালাত', [
    PaperRow('সুন্নাতে মুয়াক্কাদাহ (দৈনিক ১২ রাকাত) আদায় করেছি', ['sunnah_muakkadah_12']),
  ]),
  PaperGroup('জিকর ও তিলাওয়াত', [
    PaperRow('সকালের মাসনূন আযকার (কমপক্ষে ৫ টি)', ['adhkar_morning']),
    PaperRow('সন্ধ্যার মাসনূন আযকার (কমপক্ষে ৫ টি)', ['adhkar_evening']),
  ]),
  PaperGroup('ইলম বা জ্ঞানার্জন', [
    PaperRow('কুরআন তিলাওয়াত বা কায়দা (সময় লিখুন)', ['tilawat_minutes', 'tilawat']),
  ]),
  PaperGroup('করণীয়-বর্জনীয় কাজ (হারাম বর্জন)', [
    PaperRow('কমপক্ষে ১ জনের সাথে ঈমানী মুজাকারা করেছি', ['muzakara_imani']),
    PaperRow('সালাত ধীরস্থিরভাবে পড়েছি (প্রতি রাকাত ২.৫ মিনিট)', ['salat_slowly']),
    PaperRow('হারাম বিনোদন (নাটক, সিনেমা, মিউজিক) থেকে বিরত থেকেছি', ['avoided_entertainment']),
    PaperRow('রাত ১০:৩০ টার মধ্যে বিছানায় গিয়েছি', ['bed_by_1030']),
    PaperRow('আজ ইশরাকের সালাতের পূর্বে ঘুমাইনি', ['no_sleep_before_ishraq']),
  ]),
  PaperGroup('সাপ্তাহিক আমল', [
    PaperRow('শুক্রবার সূরা কাহফ তিলাওয়াত করেছি', ['kahf_friday']),
    PaperRow('শুক্রবার মাগরিবের পূর্বে দোয়া করেছি', ['dua_before_maghrib_friday']),
    PaperRow('সোম ও বৃহস্পতিবার থেকে কমপক্ষে ১ দিন রোযা রেখেছি', ['fast_mon_thu']),
    PaperRow('আজ একজন আত্মীয়ের খোঁজ নিয়েছি', ['check_relative']),
  ]),
  PaperGroup('মাসিক আমল', [
    PaperRow('আইয়্যামে বীজের রোযা রেখেছি', ['ayyam_beez']),
  ]),
];

/// The paper diary's নির্দেশনাবলী (back cover), verbatim.
const List<String> kDiaryInstructionsBn = [
  'প্রতিদিনের আমল সম্পন্ন হলে নির্ধারিত ঘরে টিক (✔) দিন; অসম্পন্ন থাকলে ক্রস (✗) দিন। সালাত ট্র্যাকারে জামাতে আদায় করলে (✔), একাকী আদায় করলে (/), কাযা হলে (□) চিহ্ন ব্যবহার করুন।',
  'প্রতিদিনের ঘর অবশ্যই সেদিনই পূরণ করতে হবে। পরের দিনের জন্য মুলতবি রাখা কোনোক্রমেই গ্রহণযোগ্য নয়।',
  'কুরআন তিলাওয়াত ও নফল সালাতের ঘরে পরিমাণ ও রাকাত সংখ্যা সুস্পষ্টভাবে লিপিবদ্ধ করুন।',
  'প্রতি ৭ দিন অন্তর নির্ধারিত দায়িত্বশীলের নিকট ডায়েরি উপস্থাপন করতে হবে এবং প্রয়োজনীয় মূল্যায়ন ও পরামর্শ গ্রহণ করতে হবে।',
  'ডায়েরি পূরণে সর্বোচ্চ সত্যতা ও আমানতদারিতা বজায় রাখা আবশ্যক। ইহা আল্লাহর সন্তুষ্টি লাভের একটি গুরুত্বপূর্ণ মাধ্যম।',
  'কোনো আমল ছুটে গেলে হতাশ না হয়ে তাওবা করুন এবং পরবর্তী দিন থেকে নতুন উদ্যমে আবার শুরু করুন।',
];

const String kDiaryCoverQuoteAr = 'الكَيِّسُ مَن دانَ نفسَه وعمِلَ لما بعدَ الموتِ';
const String kDiaryCoverQuoteBn =
    'প্রকৃত বুদ্ধিমান সেই ব্যক্তি, যে নিজের নফসের হিসাব গ্রহণ করে এবং মৃত্যুর পরবর্তী জীবনের জন্য আমল করে (তিরমিযী: ২৪৫৯)';

/// One diary row bound to a definition. [labelBn] is the paper's wording
/// when the paper row maps to exactly this one amal, else null (the
/// definition's own title is used).
class DiaryRow {
  const DiaryRow(this.def, this.labelBn);
  final AmalDefinition def;
  final String? labelBn;
}

class DiaryGroup {
  const DiaryGroup(this.titleBn, this.rows, {this.noteBn});
  final String titleBn;
  final String? noteBn;
  final List<DiaryRow> rows;
}

/// Split today's definitions into the paper's groups (paper order, paper
/// wording) and the extras the paper doesn't have (catalog order). Groups
/// with nothing due today drop out — the Friday rows only appear on Friday.
({List<DiaryGroup> paper, List<AmalDefinition> extras}) layoutDiary(
  List<AmalDefinition> todayDefs, {
  List<PaperGroup> layout = kPaperDiaryLayout,
}) {
  final byKey = {for (final d in todayDefs) d.key: d};
  final used = <String>{};
  final groups = <DiaryGroup>[];
  for (final g in layout) {
    final rows = <DiaryRow>[];
    for (final r in g.rows) {
      final present = [
        for (final k in r.amalKeys)
          if (byKey[k] != null) byKey[k]!,
      ];
      for (final d in present) {
        used.add(d.key);
        rows.add(DiaryRow(d, present.length == 1 ? r.labelBn : null));
      }
    }
    if (rows.isNotEmpty) groups.add(DiaryGroup(g.groupBn, rows, noteBn: g.noteBn));
  }
  return (
    paper: groups,
    extras: [for (final d in todayDefs) if (!used.contains(d.key)) d],
  );
}
