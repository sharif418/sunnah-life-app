/// Phosphor icon data (vendored).
///
/// WHY VENDORED: the pub package `phosphor_flutter` (latest 2.1.0 — also
/// its current git HEAD, byte-identical) does not compile under this repo's
/// Flutter pin (3.47.5): `IconData` became a `final` class, and
/// `class PhosphorIconData extends IconData` fails the test compiler
/// (verified empirically — `flutter analyze` is lenient but `flutter test`
/// hard-fails). Upstream has not shipped a fixed release.
///
/// Instead of dropping the Phosphor look, the three font files the app
/// needs (Regular / Fill / Bold) are vendored into assets/fonts with
/// the upstream MIT license (assets/fonts/phosphor-license.txt), and the
/// glyph table below maps the icons the app uses — plain `IconData`
/// values (no subclassing). Code points are stable across Phosphor
/// styles by design.
///
/// W4f: the table grew to the full app surface — every Material icon with
/// a Phosphor equivalent was migrated (Regular for outlined/quiet glyphs,
/// Fill only where the Material original read as solid at small sizes:
/// star, check-circle, fire, trophy, mosque, bookmark, map-pin, circle,
/// hand-heart, minus-circle). The two Material glyphs left in the app
/// (zakat debts, city-picker GPS-off) carry an explicit comment —
/// Phosphor 2.1 has no equivalent. Code-point source of truth: the
/// official @phosphor-icons/web 2.1.1 style sheets, cross-checked against
/// the vendored TTF cmaps — every code point below exists in all three
/// vendored fonts.
library;

import 'package:flutter/widgets.dart';

/// Phosphor Regular weight (assets/fonts/phosphor-regular.ttf).
class PhosphorIconsRegular {
  const PhosphorIconsRegular._();

  static const IconData alarm = IconData(0xe006, fontFamily: 'PhosphorRegular');
  // AMOL-14 exercise log — code points from @phosphor-icons/web 2.1.1
  // (verified present in the vendored regular font)
  static const IconData personSimpleWalk = IconData(
    0xe73a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData personSimpleRun = IconData(
    0xe730,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData personSimpleBike = IconData(
    0xe734,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData personSimpleSwim = IconData(
    0xe736,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData barbell = IconData(
    0xe0b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData soccerBall = IconData(
    0xe716,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData heartbeat = IconData(
    0xe2ac,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData dotsThreeOutline = IconData(
    0xe204,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData appleLogo = IconData(
    0xe516,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowClockwise = IconData(
    0xe036,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowCounterClockwise = IconData(
    0xe038,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowLeft = IconData(
    0xe058,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowRight = IconData(
    0xe06c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowSquareOut = IconData(
    0xe5de,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowsClockwise = IconData(
    0xe094,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData arrowsLeftRight = IconData(
    0xe0a0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData article = IconData(
    0xe0a8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData baby = IconData(0xe774, fontFamily: 'PhosphorRegular');
  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const IconData bellRinging = IconData(
    0xe5e8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bellSlash = IconData(
    0xe0d4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bookOpen = IconData(
    0xe0e6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData bookmark = IconData(
    0xe0e8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData broadcast = IconData(
    0xe0f2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData buildings = IconData(
    0xe102,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData calculator = IconData(
    0xe538,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData calendarBlank = IconData(
    0xe10a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData caretLeft = IconData(
    0xe138,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData caretRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chartBar = IconData(
    0xe150,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chatCircle = IconData(
    0xe168,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData chats = IconData(0xe17c, fontFamily: 'PhosphorRegular');
  static const IconData check = IconData(0xe182, fontFamily: 'PhosphorRegular');
  static const IconData checkCircle = IconData(
    0xe184,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData circle = IconData(
    0xe18a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData circlesThree = IconData(
    0xe192,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData clipboardText = IconData(
    0xe198,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const IconData clockUser = IconData(
    0xedec,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cloudArrowUp = IconData(
    0xe1ae,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cloudCheck = IconData(
    0xe1b0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData cloudSlash = IconData(
    0xe1b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData code = IconData(0xe1bc, fontFamily: 'PhosphorRegular');
  static const IconData compass = IconData(
    0xe1c8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData copy = IconData(0xe1ca, fontFamily: 'PhosphorRegular');
  static const IconData creditCard = IconData(
    0xe1d2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData crosshair = IconData(
    0xe1d6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData deviceMobile = IconData(
    0xe1e0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData dotsNine = IconData(
    0xe1fc,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData envelopeSimple = IconData(
    0xe218,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData envelopeSimpleOpen = IconData(
    0xe21a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData flagBanner = IconData(
    0xe622,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData gear = IconData(0xe270, fontFamily: 'PhosphorRegular');
  static const IconData genderFemale = IconData(
    0xe6e0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData genderMale = IconData(
    0xe6e2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData gitFork = IconData(
    0xe27e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData globe = IconData(0xe288, fontFamily: 'PhosphorRegular');
  static const IconData googleLogo = IconData(
    0xe292,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData graduationCap = IconData(
    0xe62c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData hand = IconData(0xe298, fontFamily: 'PhosphorRegular');
  static const IconData handHeart = IconData(
    0xe810,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData handTap = IconData(
    0xec90,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData headset = IconData(
    0xe584,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData heart = IconData(0xe2a8, fontFamily: 'PhosphorRegular');
  static const IconData hourglass = IconData(
    0xe2b2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData identificationBadge = IconData(
    0xe6f6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData infinity = IconData(
    0xe634,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData info = IconData(0xe2ce, fontFamily: 'PhosphorRegular');
  static const IconData lightning = IconData(
    0xe2de,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData listChecks = IconData(
    0xeadc,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData lockSimple = IconData(
    0xe308,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData lockSimpleOpen = IconData(
    0xe30a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData magnifyingGlass = IconData(
    0xe30c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData mapPin = IconData(
    0xe316,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData medal = IconData(0xe320, fontFamily: 'PhosphorRegular');
  static const IconData megaphone = IconData(
    0xe324,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData minus = IconData(0xe32a, fontFamily: 'PhosphorRegular');
  static const IconData minusCircle = IconData(
    0xe32c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData moon = IconData(0xe330, fontFamily: 'PhosphorRegular');
  static const IconData moonStars = IconData(
    0xe58e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData mosque = IconData(
    0xecee,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData navigationArrow = IconData(
    0xeade,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData paperPlaneTilt = IconData(
    0xe398,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData pauseCircle = IconData(
    0xe3a0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData pencilSimple = IconData(
    0xe3b4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData personArmsSpread = IconData(
    0xecfe,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData phone = IconData(0xe3b8, fontFamily: 'PhosphorRegular');
  static const IconData plant = IconData(0xebae, fontFamily: 'PhosphorRegular');
  static const IconData play = IconData(0xe3d0, fontFamily: 'PhosphorRegular');
  static const IconData playCircle = IconData(
    0xe3d2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData plus = IconData(0xe3d4, fontFamily: 'PhosphorRegular');
  static const IconData plusCircle = IconData(
    0xe3d6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData prohibit = IconData(
    0xe3de,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData pushPin = IconData(
    0xe3e2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData question = IconData(
    0xe3e8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData record = IconData(
    0xe3ee,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData scales = IconData(
    0xe750,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sealCheck = IconData(
    0xe606,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData shareNetwork = IconData(
    0xe408,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData shield = IconData(
    0xe40a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData shieldCheck = IconData(
    0xe40c,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData signIn = IconData(
    0xe428,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData signOut = IconData(
    0xe42a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData skipForward = IconData(
    0xe5a6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sparkle = IconData(
    0xe6a2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData squaresFour = IconData(
    0xe464,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData star = IconData(0xe46a, fontFamily: 'PhosphorRegular');
  static const IconData starAndCrescent = IconData(
    0xecf4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData stopCircle = IconData(
    0xe46e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData sun = IconData(0xe472, fontFamily: 'PhosphorRegular');
  static const IconData sunHorizon = IconData(
    0xe5b6,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData translate = IconData(
    0xe4a2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData trash = IconData(0xe4a6, fontFamily: 'PhosphorRegular');
  static const IconData tray = IconData(0xe4aa, fontFamily: 'PhosphorRegular');
  static const IconData tree = IconData(0xe6da, fontFamily: 'PhosphorRegular');
  static const IconData trendUp = IconData(
    0xe4ae,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData user = IconData(0xe4c2, fontFamily: 'PhosphorRegular');
  static const IconData userCircle = IconData(
    0xe4c4,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData userPlus = IconData(
    0xe4d0,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData userSound = IconData(
    0xeca8,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData users = IconData(0xe4d6, fontFamily: 'PhosphorRegular');
  static const IconData usersThree = IconData(
    0xe68e,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData wallet = IconData(
    0xe68a,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData warningCircle = IconData(
    0xe4e2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData wifiHigh = IconData(
    0xe4ea,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData wifiSlash = IconData(
    0xe4f2,
    fontFamily: 'PhosphorRegular',
  );
  static const IconData x = IconData(0xe4f6, fontFamily: 'PhosphorRegular');
  static const IconData xCircle = IconData(
    0xe4f8,
    fontFamily: 'PhosphorRegular',
  );
}

/// Phosphor Fill weight (assets/fonts/phosphor-fill.ttf).
class PhosphorIconsFill {
  const PhosphorIconsFill._();

  // the home prayer card's sun and moon (2026-10-07)
  static const IconData moon = IconData(0xe330, fontFamily: 'PhosphorFill');
  static const IconData sun = IconData(0xe472, fontFamily: 'PhosphorFill');

  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorFill');
  static const IconData bookOpen = IconData(0xe0e6, fontFamily: 'PhosphorFill');
  static const IconData bookOpenText = IconData(
    0xe8f2,
    fontFamily: 'PhosphorFill',
  );
  static const IconData bookmark = IconData(0xe0e8, fontFamily: 'PhosphorFill');
  static const IconData broadcast = IconData(
    0xe0f2,
    fontFamily: 'PhosphorFill',
  );
  static const IconData chartPieSlice = IconData(
    0xe15a,
    fontFamily: 'PhosphorFill',
  );
  static const IconData checkCircle = IconData(
    0xe184,
    fontFamily: 'PhosphorFill',
  );
  static const IconData circle = IconData(0xe18a, fontFamily: 'PhosphorFill');
  static const IconData clipboardText = IconData(
    0xe198,
    fontFamily: 'PhosphorFill',
  );
  static const IconData fire = IconData(0xe242, fontFamily: 'PhosphorFill');
  static const IconData graduationCap = IconData(
    0xe62c,
    fontFamily: 'PhosphorFill',
  );
  static const IconData handHeart = IconData(
    0xe810,
    fontFamily: 'PhosphorFill',
  );
  static const IconData headset = IconData(0xe584, fontFamily: 'PhosphorFill');
  static const IconData mapPin = IconData(0xe316, fontFamily: 'PhosphorFill');
  static const IconData megaphone = IconData(
    0xe324,
    fontFamily: 'PhosphorFill',
  );
  static const IconData minusCircle = IconData(
    0xe32c,
    fontFamily: 'PhosphorFill',
  );
  static const IconData mosque = IconData(0xecee, fontFamily: 'PhosphorFill');
  static const IconData phone = IconData(0xe3b8, fontFamily: 'PhosphorFill');
  static const IconData squaresFour = IconData(
    0xe464,
    fontFamily: 'PhosphorFill',
  );
  static const IconData star = IconData(0xe46a, fontFamily: 'PhosphorFill');
  static const IconData starAndCrescent = IconData(
    0xecf4,
    fontFamily: 'PhosphorFill',
  );
  static const IconData trophy = IconData(0xe67e, fontFamily: 'PhosphorFill');
}

/// Phosphor Bold weight (assets/fonts/phosphor-bold.ttf).
class PhosphorIconsBold {
  const PhosphorIconsBold._();

  // ticks on the home card's today strip
  static const IconData check = IconData(0xe182, fontFamily: 'PhosphorBold');

  static const IconData caretDown = IconData(
    0xe136,
    fontFamily: 'PhosphorBold',
  );
  static const IconData caretRight = IconData(
    0xe13a,
    fontFamily: 'PhosphorBold',
  );
  static const IconData mapPin = IconData(0xe316, fontFamily: 'PhosphorBold');
}
