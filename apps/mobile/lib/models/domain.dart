/// Sunnah Life domain models — typed Dart port of src/types/domain.ts.
/// Every API boundary uses these classes; no raw Map sprawl is allowed.
///
/// The models live in per-domain files; this barrel keeps the single
/// `package:sunnah_life/models/domain.dart` import working everywhere.
/// (Tests import it with `as domain;` and `hide`/`show` — preserved.)
library;

export 'amal.dart';
export 'assessment.dart';
export 'dawah.dart';
export 'goal.dart';
export 'ilm_engagement.dart';
export 'live.dart';
export 'review.dart';
export 'user.dart';
export 'usrah.dart';
