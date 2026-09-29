/// Leaderboard models (W4c) — port of apps/api/src/leaderboard/
/// leaderboard.controller.ts: the member's own gender-scoped percentile
/// band over the last-30-day amal points. No lists, no names — the band
/// is all the member ever learns (privacy by design, server-side).
library;

enum LeaderboardBand { top10, top25, top50, top75, bottom }

extension LeaderboardBandJson on LeaderboardBand {
  String get json => name;
  static LeaderboardBand fromJson(String v) => switch (v) {
    'top25' => LeaderboardBand.top25,
    'top50' => LeaderboardBand.top50,
    'top75' => LeaderboardBand.top75,
    'bottom' => LeaderboardBand.bottom,
    _ => LeaderboardBand.top10,
  };

  /// ARB key for the localized band chip label (শীর্ষ ১০% … নিচের ২৫%).
  String get labelKey => switch (this) {
    LeaderboardBand.top10 => 'leaderboard_band_top10',
    LeaderboardBand.top25 => 'leaderboard_band_top25',
    LeaderboardBand.top50 => 'leaderboard_band_top50',
    LeaderboardBand.top75 => 'leaderboard_band_top75',
    LeaderboardBand.bottom => 'leaderboard_band_bottom',
  };
}

/// GET /api/leaderboard/me → { band, myPoints, windowDays }.
class LeaderboardMe {
  const LeaderboardMe({
    required this.band,
    required this.myPoints,
    required this.windowDays,
  });
  final LeaderboardBand band;
  final num myPoints;
  final int windowDays;

  /// Whole-number points render without the trailing .0.
  num get myPointsDisplay =>
      myPoints % 1 == 0 ? myPoints.toInt() : myPoints.toDouble();

  factory LeaderboardMe.fromJson(Map<String, dynamic> j) => LeaderboardMe(
    band: LeaderboardBandJson.fromJson(j['band'] as String? ?? 'top10'),
    myPoints: j['myPoints'] as num? ?? 0,
    windowDays: (j['windowDays'] as num?)?.toInt() ?? 30,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'band': band.json,
    'myPoints': myPoints,
    'windowDays': windowDays,
  };
}
