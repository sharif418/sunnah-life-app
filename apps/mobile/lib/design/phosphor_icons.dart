/// Phosphor icon data for the C-W4a/C-W4b components (vendored).
///
/// WHY VENDORED: the pub package `phosphor_flutter` (latest 2.1.0 — also
/// its current git HEAD, byte-identical) does not compile under this repo's
/// Flutter pin (3.47.5): `IconData` became a `final` class, and
/// `class PhosphorIconData extends IconData` fails the test compiler
/// (verified empirically — `flutter analyze` is lenient but `flutter test`
/// hard-fails). Upstream has not shipped a fixed release.
///
/// Instead of dropping the Phosphor look, the three font files the new
/// chrome needs (Regular / Fill / Bold) are vendored into assets/fonts with
/// the upstream MIT license (assets/fonts/PHOSPHOR-LICENSE.txt), and the
/// glyph table below is hand-written for exactly the icons the NEW
/// components use — plain `IconData` values (no subclassing). Code points
/// are stable across Phosphor styles by design.
///
/// Existing screens keep their Material icons — the migration to one icon
/// set is the incremental W4f plan. Do NOT grow this file casually; one
/// entry per actually-used glyph.
library;

import 'package:flutter/widgets.dart';

/// Phosphor Bold weight (assets/fonts/Phosphor-Bold.ttf).
class PhosphorIconsBold {
  const PhosphorIconsBold._();

  static const IconData caretDown =
      IconData(0xe136, fontFamily: 'PhosphorBold');
  static const IconData caretRight =
      IconData(0xe13a, fontFamily: 'PhosphorBold');
  static const IconData mapPin = IconData(0xe316, fontFamily: 'PhosphorBold');
}

/// Phosphor Regular weight (assets/fonts/Phosphor.ttf).
class PhosphorIconsRegular {
  const PhosphorIconsRegular._();

  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorRegular');
  static const IconData bellSlash =
      IconData(0xe0d4, fontFamily: 'PhosphorRegular');
  static const IconData broadcast =
      IconData(0xe0f2, fontFamily: 'PhosphorRegular');
  static const IconData clock = IconData(0xe19a, fontFamily: 'PhosphorRegular');
  static const IconData clockUser =
      IconData(0xedec, fontFamily: 'PhosphorRegular');
  static const IconData checkCircle =
      IconData(0xe184, fontFamily: 'PhosphorRegular');
  static const IconData globe = IconData(0xe288, fontFamily: 'PhosphorRegular');
  static const IconData headset =
      IconData(0xe584, fontFamily: 'PhosphorRegular');
  static const IconData listChecks =
      IconData(0xeadc, fontFamily: 'PhosphorRegular');
  static const IconData playCircle =
      IconData(0xe3d2, fontFamily: 'PhosphorRegular');
  static const IconData starAndCrescent =
      IconData(0xecf4, fontFamily: 'PhosphorRegular');
  static const IconData bookOpen =
      IconData(0xe0e6, fontFamily: 'PhosphorRegular');
  static const IconData megaphone =
      IconData(0xe324, fontFamily: 'PhosphorRegular');
  static const IconData graduationCap =
      IconData(0xe62c, fontFamily: 'PhosphorRegular');
  static const IconData squaresFour =
      IconData(0xe464, fontFamily: 'PhosphorRegular');
  static const IconData userCircle =
      IconData(0xe4c4, fontFamily: 'PhosphorRegular');
}

/// Phosphor Fill weight (assets/fonts/Phosphor-Fill.ttf).
class PhosphorIconsFill {
  const PhosphorIconsFill._();

  static const IconData bell = IconData(0xe0ce, fontFamily: 'PhosphorFill');
  static const IconData bookOpen = IconData(0xe0e6, fontFamily: 'PhosphorFill');
  static const IconData bookOpenText =
      IconData(0xe8f2, fontFamily: 'PhosphorFill');
  static const IconData broadcast =
      IconData(0xe0f2, fontFamily: 'PhosphorFill');
  static const IconData caretDown =
      IconData(0xe136, fontFamily: 'PhosphorFill');
  static const IconData caretRight =
      IconData(0xe13a, fontFamily: 'PhosphorFill');
  static const IconData chartPieSlice =
      IconData(0xe15a, fontFamily: 'PhosphorFill');
  static const IconData clipboardText =
      IconData(0xe198, fontFamily: 'PhosphorFill');
  static const IconData fire = IconData(0xe242, fontFamily: 'PhosphorFill');
  static const IconData graduationCap =
      IconData(0xe62c, fontFamily: 'PhosphorFill');
  static const IconData handHeart =
      IconData(0xe810, fontFamily: 'PhosphorFill');
  static const IconData headset = IconData(0xe584, fontFamily: 'PhosphorFill');
  static const IconData mapPin = IconData(0xe316, fontFamily: 'PhosphorFill');
  static const IconData megaphone =
      IconData(0xe324, fontFamily: 'PhosphorFill');
  static const IconData phone = IconData(0xe3b8, fontFamily: 'PhosphorFill');
  static const IconData squaresFour =
      IconData(0xe464, fontFamily: 'PhosphorFill');
  static const IconData starAndCrescent =
      IconData(0xecf4, fontFamily: 'PhosphorFill');
}
