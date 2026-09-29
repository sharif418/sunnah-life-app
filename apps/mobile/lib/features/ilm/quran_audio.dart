/// Qur'an recitation audio — per-ayah URLs, reciter catalog, jump math.
///
/// The admin-config `audioBase` (packages/content/app-config.json) points at
/// download.quranicaudio.com, which hosts PER-SURAH files only — live-verified
/// while building W3a: `{audioBase}/001.mp3` → 200 (audio/mpeg, 839808 B)
/// while `{audioBase}/001001.mp3` → 404. Per-ayah playback (per-ayah play
/// button, auto-advance, cached re-listens) cannot be served from that host,
/// so the URL shape here is the task spec's documented fallback: the
/// everyayah.com per-ayah layout
///   `https://everyayah.com/data/<reciter>/<surah3><ayah3>.mp3`
/// (each reciter folder below was live-verified 200 on 001001/001007/002286).
/// `AppConfig.audioBase` remains the on/off GATE: when an admin clears it the
/// audio affordances disappear from the reader; when the owner later points
/// it at a per-ayah CDN, `ayahAudioUrl` is the single place to switch.
library;

import '../../core/bn_digits.dart' show parseBnDigits;

/// Per-ayah recitation CDN (see the library doc for why audioBase alone
/// cannot back per-ayah playback).
const String kAyahAudioBase = 'https://everyayah.com/data';

/// SharedPreferences key for the persisted reciter choice.
const String kQuranReciterPrefKey = 'quran_reciter';

class ReciterOption {
  const ReciterOption({
    required this.id,
    required this.path,
    required this.nameBn,
    required this.nameEn,
    required this.nameAr,
  });
  final String id;
  final String path;
  final String nameBn;
  final String nameEn;
  final String nameAr;

  /// Display name for the ambient app language (bn/en/ar; anything else → bn).
  String nameFor(String lang) => switch (lang) {
    'en' => nameEn,
    'ar' => nameAr,
    _ => nameBn,
  };
}

/// Well-known reciters on the per-ayah CDN. Alafasy is the default — it is
/// the same reciter the bundled app-config picks on quranicaudio
/// (`mishaari_raashid_al_3afaasee`).
const List<ReciterOption> kQuranReciters = [
  ReciterOption(
    id: 'alafasy',
    path: 'Alafasy_128kbps',
    nameBn: 'মিশারি রশিদ আল-আফাসি',
    nameEn: 'Mishary Rashid Alafasy',
    nameAr: 'مشاري راشد العفاسي',
  ),
  ReciterOption(
    id: 'husary',
    path: 'Husary_128kbps',
    nameBn: 'মাহমুদ খলিল আল-হুসারি',
    nameEn: 'Mahmoud Khalil Al-Husary',
    nameAr: 'محمود خليل الحصري',
  ),
  ReciterOption(
    id: 'minshawi',
    path: 'Minshawy_Murattal_128kbps',
    nameBn: 'মুহাম্মদ সিদ্দিক আল-মিনশাবি',
    nameEn: 'Mohamed Siddiq El-Minshawi',
    nameAr: 'محمد صديق المنشاوي',
  ),
  ReciterOption(
    id: 'sudais',
    path: 'Abdurrahmaan_As-Sudais_192kbps',
    nameBn: 'আব্দুর রহমান আস-সুদাইস',
    nameEn: 'Abdurrahmaan As-Sudais',
    nameAr: 'عبد الرحمن السديس',
  ),
];

/// The persisted reciter id → option (unknown/null ids fall back to Alafasy).
ReciterOption reciterById(String? id) {
  for (final r in kQuranReciters) {
    if (r.id == id) return r;
  }
  return kQuranReciters.first;
}

/// Per-ayah recitation URL:
/// `{kAyahAudioBase}/{reciter path}/{surah padded 3}{ayah padded 3}.mp3`.
String ayahAudioUrl({
  required ReciterOption reciter,
  required int surah,
  required int ayah,
}) {
  final s = surah.clamp(1, 114).toString().padLeft(3, '0');
  final a = ayah.clamp(1, 286).toString().padLeft(3, '0');
  return '$kAyahAudioBase/${reciter.path}/$s$a.mp3';
}

/// Coarse scroll estimate for "jump to ayah N" — the cheap first step before
/// `Scrollable.ensureVisible` lands the exact offset on the next frame:
/// ayah 0 → top, the last ayah → the very bottom, linear in between (ayah
/// heights vary, hence estimate-then-correct). Always inside [0, maxExtent].
double estimateJumpOffset({
  required int ayahIndex,
  required int totalAyahs,
  required double maxScrollExtent,
}) {
  if (totalAyahs <= 1 || maxScrollExtent <= 0) return 0;
  final t = (ayahIndex / (totalAyahs - 1)).clamp(0.0, 1.0);
  return t * maxScrollExtent;
}

/// Parses the go-to-ayah dialog input (Bengali or ASCII digits).
/// Re-exported seam so the reader imports one module for ayah math.
int? parseAyahInput(String input) => parseBnDigits(input);
