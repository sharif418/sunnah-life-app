// GENERATED from packages/design-tokens/tokens.json — do not edit by hand.
// Single source of truth for Sunnah Life's visual language on Flutter.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SLColors {
  // Brand
  static const Color primary = Color(0xFF1F4D3D);
  static const Color primaryDeep = Color(0xFF173A2E);
  static const Color primarySoftLight = Color(0xFFEAF0EC);
  static const Color gold = Color(0xFFC99A3B);
  static const Color goldDeep = Color(0xFFB7791F);
  static const Color goldSoftLight = Color(0xFFF6ECD8);
  static const Color success = Color(0xFF2E7D5B);
  static const Color warning = Color(0xFFB7791F);
  static const Color alert = Color(0xFFC0392B);
  static const Color alertSoftLight = Color(0xFFFCE4E4);

  // Light theme semantics
  static const Color lightBackground = Color(0xFFF7F4EC);
  static const Color lightForeground = Color(0xFF222222);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardForeground = Color(0xFF222222);
  static const Color lightPopover = Color(0xFFFFFFFF);
  static const Color lightPopoverForeground = Color(0xFF222222);
  static const Color lightPrimary = Color(0xFF1F4D3D);
  static const Color lightPrimaryForeground = Color(0xFFF7F4EC);
  static const Color lightPrimarySoft = Color(0xFFEAF0EC);
  static const Color lightSecondary = Color(0xFFEFE9DC);
  static const Color lightSecondaryForeground = Color(0xFF1F4D3D);
  static const Color lightMuted = Color(0xFFF1EDE2);
  static const Color lightMutedForeground = Color(0xFF666666);
  static const Color lightAccent = Color(0xFFC99A3B);
  static const Color lightAccentForeground = Color(0xFF3B2B0E);
  static const Color lightDestructive = Color(0xFFC0392B);
  static const Color lightDestructiveForeground = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE4DCCB);
  static const Color lightInput = Color(0xFFE4DCCB);
  static const Color lightRing = Color(0xFF1F4D3D);
  static const Color lightSuccess = Color(0xFF2E7D5B);
  static const Color lightSuccessForeground = Color(0xFFF7F4EC);
  static const Color lightWarning = Color(0xFFB7791F);
  static const Color lightWarningForeground = Color(0xFFFFFFFF);
  static const Color lightGold = Color(0xFFC99A3B);
  static const Color lightGoldForeground = Color(0xFF3B2B0E);
  static const Color lightGoldSoft = Color(0xFFF6ECD8);
  static const Color lightAlert = Color(0xFFC0392B);
  static const Color lightAlertSoft = Color(0xFFFCE4E4);

  // Dark theme semantics
  static const Color darkBackground = Color(0xFF0E1613);
  static const Color darkForeground = Color(0xFFF1EDE3);
  static const Color darkCard = Color(0xFF16211C);
  static const Color darkCardForeground = Color(0xFFF1EDE3);
  static const Color darkPopover = Color(0xFF16211C);
  static const Color darkPopoverForeground = Color(0xFFF1EDE3);
  static const Color darkPrimary = Color(0xFF4C9B72);
  static const Color darkPrimaryForeground = Color(0xFF0B140F);
  static const Color darkPrimarySoft = Color(0xFF1A2B23);
  static const Color darkSecondary = Color(0xFF1C2A24);
  static const Color darkSecondaryForeground = Color(0xFFD8E5DD);
  static const Color darkMuted = Color(0xFF1A2620);
  static const Color darkMutedForeground = Color(0xFF9FAAA2);
  static const Color darkAccent = Color(0xFFD9B25F);
  static const Color darkAccentForeground = Color(0xFF241A05);
  static const Color darkDestructive = Color(0xFFE06A5A);
  static const Color darkDestructiveForeground = Color(0xFF1A0505);
  static const Color darkBorder = Color(0xFF26382F);
  static const Color darkInput = Color(0xFF26382F);
  static const Color darkRing = Color(0xFF4C9B72);
  static const Color darkSuccess = Color(0xFF4C9B72);
  static const Color darkSuccessForeground = Color(0xFF0B140F);
  static const Color darkWarning = Color(0xFFD9B25F);
  static const Color darkWarningForeground = Color(0xFF241A05);
  static const Color darkGold = Color(0xFFD9B25F);
  static const Color darkGoldForeground = Color(0xFF241A05);
  static const Color darkGoldSoft = Color(0xFF2A2416);
  static const Color darkAlert = Color(0xFFE06A5A);
  static const Color darkAlertSoft = Color(0xFF3A211D);
}

class SLSpacing {
  static const double unit = 8.0;
  static double of(int units) => units * unit;
  static const double s4 = 4.0;
  static const double s8 = 8.0;
  static const double s12 = 12.0;
  static const double s16 = 16.0;
  static const double s20 = 20.0;
  static const double s24 = 24.0;
  static const double s32 = 32.0;
  static const double s40 = 40.0;
  static const double s48 = 48.0;
  static const double s56 = 56.0;
  static const double s64 = 64.0;
  static const double minTapTarget = 44.0;
}

class SLRadius {
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 20.0;
  static const double pill = 999.0;
  static final Radius rSm = Radius.circular(sm);
  static final Radius rMd = Radius.circular(md);
  static final Radius rLg = Radius.circular(lg);
  static final Radius rXl = Radius.circular(xl);
  static final BorderRadius brSm = BorderRadius.circular(sm);
  static final BorderRadius brMd = BorderRadius.circular(md);
  static final BorderRadius brLg = BorderRadius.circular(lg);
  static final BorderRadius brXl = BorderRadius.circular(xl);
  static final BorderRadius brPill = BorderRadius.circular(pill);
}

class SLMotion {
  static const Duration fast = Duration(milliseconds: 120);
  static const Duration base = Duration(milliseconds: 200);
  static const Duration slow = Duration(milliseconds: 320);
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}

class SLElevation {
  static List<BoxShadow> card(bool dark) => [
    BoxShadow(
      color: Color(0x0D1F4D3D),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x081F4D3D),
      blurRadius: 2,
      offset: const Offset(0, 1),
    ),
  ];
  static List<BoxShadow> lifted(bool dark) => [
    BoxShadow(
      color: Color(0x1F1F4D3D),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
    BoxShadow(
      color: Color(0x141F4D3D),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
}

class SLType {
  static const double caption = 12;
  static const double body = 16;
  static const double bodyLarge = 18;
  static const double heading = 20;
  static const double headingLarge = 24;
  static const double display = 28;

  /// Bengali-first text theme using Google Fonts (Hind Siliguri).
  static TextTheme textTheme(TextTheme base) => base.copyWith(
    displaySmall: GoogleFonts.hindSiliguri(
      fontSize: 28,
      height: 1.35,
      fontWeight: FontWeight.w700,
    ),
    headlineMedium: GoogleFonts.hindSiliguri(
      fontSize: 24,
      height: 1.4,
      fontWeight: FontWeight.w700,
    ),
    titleMedium: GoogleFonts.hindSiliguri(
      fontSize: 20,
      height: 1.45,
      fontWeight: FontWeight.w600,
    ),
    bodyLarge: GoogleFonts.hindSiliguri(fontSize: 18, height: 1.6),
    bodyMedium: GoogleFonts.hindSiliguri(fontSize: 16, height: 1.6),
    bodySmall: GoogleFonts.hindSiliguri(fontSize: 12, height: 1.5),
  );

  /// Uthmani Qur'an text.
  static TextStyle quran({Color? color}) =>
      GoogleFonts.amiriQuran(fontSize: 26, height: 2.2, color: color);

  /// Arabic du'a text.
  static TextStyle dua({Color? color}) =>
      GoogleFonts.amiri(fontSize: 20, height: 2.1, color: color);
}

/// Light ThemeData built from the tokens (cream + deep green + gold).
ThemeData buildSunnahLightTheme() {
  final scheme = ColorScheme.light(
    primary: SLColors.lightPrimary,
    onPrimary: SLColors.lightPrimaryForeground,
    primaryContainer: SLColors.lightPrimarySoft,
    secondary: SLColors.lightSecondary,
    onSecondary: SLColors.lightSecondaryForeground,
    surface: SLColors.lightBackground,
    onSurface: SLColors.lightForeground,
    surfaceContainerLowest: SLColors.lightCard,
    surfaceContainerLow: SLColors.lightCard,
    surfaceContainer: SLColors.lightCard,
    error: SLColors.lightDestructive,
    onError: SLColors.lightDestructiveForeground,
    outline: SLColors.lightBorder,
    outlineVariant: SLColors.lightBorder,
    tertiary: SLColors.lightGold,
    onTertiary: SLColors.lightGoldForeground,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SLColors.lightBackground,
    textTheme: SLType.textTheme(
      ThemeData(brightness: Brightness.light).textTheme,
    ),
    splashFactory: InkSparkle.splashFactory,
    dividerColor: SLColors.lightBorder,
  ).applyThemeTweaks(Brightness.light);
}

/// Dark ThemeData built from the tokens (deep green-black).
ThemeData buildSunnahDarkTheme() {
  final scheme = ColorScheme.dark(
    primary: SLColors.darkPrimary,
    onPrimary: SLColors.darkPrimaryForeground,
    primaryContainer: SLColors.darkPrimarySoft,
    secondary: SLColors.darkSecondary,
    onSecondary: SLColors.darkSecondaryForeground,
    surface: SLColors.darkBackground,
    onSurface: SLColors.darkForeground,
    surfaceContainerLowest: SLColors.darkCard,
    surfaceContainerLow: SLColors.darkCard,
    surfaceContainer: SLColors.darkCard,
    error: SLColors.darkDestructive,
    onError: SLColors.darkDestructiveForeground,
    outline: SLColors.darkBorder,
    outlineVariant: SLColors.darkBorder,
    tertiary: SLColors.darkGold,
    onTertiary: SLColors.darkGoldForeground,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: SLColors.darkBackground,
    textTheme: SLType.textTheme(
      ThemeData(brightness: Brightness.dark).textTheme,
    ),
    dividerColor: SLColors.darkBorder,
  ).applyThemeTweaks(Brightness.dark);
}

extension _ThemeTweaks on ThemeData {
  ThemeData applyThemeTweaks(Brightness brightness) => copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: brightness == Brightness.light
          ? SLColors.lightBackground
          : SLColors.darkBackground,
      foregroundColor: brightness == Brightness.light
          ? SLColors.lightForeground
          : SLColors.darkForeground,
      elevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: brightness == Brightness.light
          ? SLColors.lightCard
          : SLColors.darkCard,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: SLRadius.brLg,
        side: BorderSide(
          color: brightness == Brightness.light
              ? SLColors.lightBorder
              : SLColors.darkBorder,
          width: 1,
        ),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, SLSpacing.minTapTarget),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, SLSpacing.minTapTarget),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: brightness == Brightness.light
          ? SLColors.lightCard
          : SLColors.darkCard,
      border: OutlineInputBorder(
        borderRadius: SLRadius.brMd,
        borderSide: BorderSide(
          color: brightness == Brightness.light
              ? SLColors.lightBorder
              : SLColors.darkBorder,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s4,
        vertical: SLSpacing.s12,
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: SLRadius.brPill),
      side: BorderSide(
        color: brightness == Brightness.light
            ? SLColors.lightBorder
            : SLColors.darkBorder,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: brightness == Brightness.light
          ? SLColors.lightCard
          : SLColors.darkCard,
      indicatorColor: brightness == Brightness.light
          ? SLColors.lightPrimarySoft
          : SLColors.darkPrimarySoft,
      height: 68,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(SLRadius.lg)),
      ),
      showDragHandle: true,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
    ),
  );
}
