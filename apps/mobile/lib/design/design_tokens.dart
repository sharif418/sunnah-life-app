// GENERATED from packages/design-tokens/tokens.json — do not edit by hand.
// Single source of truth for Sunnah Life's visual language on Flutter.
import 'package:flutter/material.dart';

/// The app's Bengali-first family. On a DEVICE the pubspec declaration makes
/// the engine register the family before the first frame. NOTE (W5):
/// `flutter test` does NOT load pubspec-declared families — golden tests
/// warm them explicitly through test/golden_fonts.dart (warmAppFonts),
/// and test/tofu_guard_test.dart fails if the glyphs ever go missing.
const String kAppFontFamily = 'SolaimanLipi';

/// Per-glyph fallback for the few symbols SolaimanLipi lacks (… • − ✓ ≥):
/// the bundled Noto Sans Bengali, never a platform font (tofu on some
/// phones). Every style that names [kAppFontFamily] carries it.
const List<String> kAppFontFallback = ['NotoSansBengali'];

/// Uthmani Qur'an family (pubspec-declared, bundled TTF).
const String kQuranFontFamily = 'AmiriQuran';

/// Arabic du'a family (pubspec-declared, bundled TTF).
const String kArabicFontFamily = 'Amiri';

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
  static const Color alert = Color(0xFFB93527);
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
  static const Color lightAlert = Color(0xFFB93527);
  static const Color lightAlertSoft = Color(0xFFFCE4E4);
  static const Color lightGoldText = Color(0xFF7A5414);

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
  static const Color darkGoldText = Color(0xFFD9B25F);
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

/// A family-bearing component style. IMPORTANT (W5, verified against the
/// SDK): ThemeData merges the textTheme roles over typography.black/white,
/// so a color-less textTheme role still resolves a color — but COMPONENT
/// themes (ListTileThemeData.titleTextStyle, ChipThemeData.labelStyle,
/// DialogThemeData.titleTextStyle…) REPLACE their M3 defaults wholesale:
/// a color-less style there leaves the label with NO color and the engine
/// paints it near-white on the cream surface. That was the W5 bug —
/// invisible ListTile titles and near-invisible chip labels, hidden until
/// the goldens started rendering real glyphs. Every component style now
/// passes an explicit token color. (The inputDecorationTheme styles below
/// are the verified exception — see the comment there.)
TextStyle _appFontStyle(double size, [FontWeight? weight, Color? color]) =>
    TextStyle(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      fontSize: size,
      fontWeight: weight,
      height: 1.45,
      color: color,
    );

class SLType {
  // The scale matches the approved prototype (2026-10-04). Noto Sans
  // Bengali (the face then) has a tall x-height: at the old 18/20 the diary rows and card
  // titles read a size too big and every screen looked crowded next to the
  // prototype. Body text stays at the 15-16 floor for older eyes.
  static const double caption = 13;
  static const double body = 15;
  static const double bodyLarge = 16;
  static const double heading = 17;
  static const double headingLarge = 24;
  static const double display = 28;

  // The six token-scale styles the app's own chrome renders with.
  static const TextStyle _displayStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 28,
    height: 1.35,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _headingLargeStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 24,
    height: 1.4,
    fontWeight: FontWeight.w700,
  );
  static const TextStyle _headingStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 17,
    height: 1.45,
    fontWeight: FontWeight.w600,
  );
  static const TextStyle _bodyLargeStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 16,
    height: 1.55,
  );
  static const TextStyle _bodyStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 15,
    height: 1.55,
  );
  static const TextStyle _captionStyle = TextStyle(
    fontFamily: kAppFontFamily,
    fontFamilyFallback: kAppFontFallback,
    fontSize: 13,
    height: 1.45,
  );

  /// Bengali-first text theme — EVERY role carries the bundled Noto Sans Bengali
  /// family so no Material component (tab bars, chips, buttons, snackbars,
  /// dialogs, list tiles, inputs, menus…) ever falls back to the platform
  /// font (mixed typefaces on a real phone, tofu in bundle-only renders).
  /// The six app-styled roles use the token scale; the remaining M3 roles
  /// keep their default size/weight/letter-spacing and only swap the family
  /// plus a Bengali-appropriate line-height.
  static TextTheme textTheme(TextTheme base) => base.copyWith(
    // Token-scale roles (what app chrome asks for by name).
    displaySmall: _displayStyle,
    headlineMedium: _headingLargeStyle,
    titleMedium: _headingStyle,
    bodyLarge: _bodyLargeStyle,
    bodyMedium: _bodyStyle,
    bodySmall: _captionStyle,
    // M3 roles — family + Bengali line-height, default metrics otherwise.
    displayLarge: base.displayLarge?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.35,
    ),
    displayMedium: base.displayMedium?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.35,
    ),
    headlineLarge: base.headlineLarge?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.4,
    ),
    headlineSmall: base.headlineSmall?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.45,
    ),
    titleLarge: base.titleLarge?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.45,
    ),
    titleSmall: base.titleSmall?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.5,
    ),
    labelLarge: base.labelLarge?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.45,
    ),
    labelMedium: base.labelMedium?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.45,
    ),
    labelSmall: base.labelSmall?.copyWith(
      fontFamily: kAppFontFamily,
      fontFamilyFallback: kAppFontFallback,
      height: 1.45,
    ),
  );

  /// Uthmani Qur'an text.
  static TextStyle quran({Color? color}) => TextStyle(
    fontFamily: kQuranFontFamily,
    fontSize: 26,
    height: 2.2,
    color: color,
  );

  /// Arabic du'a text.
  static TextStyle dua({Color? color}) => TextStyle(
    fontFamily: kArabicFontFamily,
    fontSize: 20,
    height: 2.1,
    color: color,
  );
}

/// Light ThemeData built from the tokens (cream + deep green + gold).
ThemeData buildSunnahLightTheme() {
  final scheme = ColorScheme.light(
    primary: SLColors.lightPrimary,
    onPrimary: SLColors.lightPrimaryForeground,
    primaryContainer: SLColors.lightPrimarySoft,
    // unset, ColorScheme.light falls back to onPrimary (white) — unreadable
    // on the pale container (FAB labels). primaryDeep: 10.8:1.
    onPrimaryContainer: SLColors.primaryDeep,
    secondary: SLColors.lightSecondary,
    onSecondary: SLColors.lightSecondaryForeground,
    surface: SLColors.lightBackground,
    onSurface: SLColors.lightForeground,
    // unset, onSurfaceVariant falls back to onSurface (#222): every
    // "muted" caption, hint and secondary line rendered as dark as the
    // title. The token's muted ink: 5.7:1 on the card, 5.3:1 on cream.
    onSurfaceVariant: SLColors.lightMutedForeground,
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
    primaryTextTheme: SLType.textTheme(
      ThemeData(brightness: Brightness.light).primaryTextTheme,
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
    onPrimaryContainer: SLColors.darkForeground,
    secondary: SLColors.darkSecondary,
    onSecondary: SLColors.darkSecondaryForeground,
    surface: SLColors.darkBackground,
    onSurface: SLColors.darkForeground,
    onSurfaceVariant: SLColors.darkMutedForeground,
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
    primaryTextTheme: SLType.textTheme(
      ThemeData(brightness: Brightness.dark).primaryTextTheme,
    ),
    dividerColor: SLColors.darkBorder,
  ).applyThemeTweaks(Brightness.dark);
}

extension _ThemeTweaks on ThemeData {
  ThemeData applyThemeTweaks(Brightness brightness) {
    // Role colors for the component themes below — onSurface / its variant /
    // onPrimary / primary from the tokens, per brightness. Selected vs
    // unselected (tab bar, nav bar, chip disabled state) resolve through
    // WidgetState* so the state distinction survives.
    final onSurface = brightness == Brightness.light
        ? SLColors.lightForeground
        : SLColors.darkForeground;
    final onSurfaceVariant = brightness == Brightness.light
        ? SLColors.lightMutedForeground
        : SLColors.darkMutedForeground;
    final onPrimary = brightness == Brightness.light
        ? SLColors.lightPrimaryForeground
        : SLColors.darkPrimaryForeground;
    final primary = brightness == Brightness.light
        ? SLColors.lightPrimary
        : SLColors.darkPrimary;
    final inputRim = brightness == Brightness.light
        ? const Color(0xFF9A907C)
        : const Color(0xFF6B7A72);
    // M3 snackbars sit on the scheme's inverseSurface, which this
    // ColorScheme doesn't control — pin an explicit inverse pair so the
    // content color is always readable (14.2:1 light / 16.1:1 dark).
    final snackBg = brightness == Brightness.light
        ? SLColors.darkCard
        : SLColors.lightCard;
    final snackFg = brightness == Brightness.light
        ? SLColors.darkForeground
        : SLColors.lightForeground;
    return copyWith(
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
      // ── Font consistency + explicit colors (W5): every component theme
      // carries the bundled Noto Sans Bengali family AND a token color — see
      // _appFontStyle for why color-less styles were invisible text.
      tabBarTheme: TabBarThemeData(
        // the underline spans the whole tab (word-wide, it was a 20dp sliver
        // under "সূরা" — hard to see which tab is open, worst in dark)
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: onSurface,
        unselectedLabelColor: onSurfaceVariant,
        labelStyle: _appFontStyle(14, FontWeight.w600, onSurface),
        unselectedLabelStyle: _appFontStyle(
          14,
          FontWeight.w500,
          onSurfaceVariant,
        ),
      ),
      chipTheme: ChipThemeData(
        // WidgetStateColor so the disabled state keeps its own color (the
        // M3 chip default: enabled = onSurfaceVariant, disabled = onSurface).
        labelStyle: _appFontStyle(
          14,
          FontWeight.w500,
          WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? onSurface
                : states.contains(WidgetState.selected)
                ? (brightness == Brightness.light
                      ? SLColors.primaryDeep
                      : SLColors.darkForeground)
                : onSurfaceVariant,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: SLRadius.brPill),
        // selected = the soft green with a green rim and green ink (the
        // label colour is resolved in labelStyle above)
        // (dark: a real green tint — the soft token is almost the card's own
        // colour, so a selected chip differed only by its rim)
        selectedColor: brightness == Brightness.light
            ? SLColors.lightPrimarySoft
            : primary.withValues(alpha: 0.28),
        checkmarkColor: primary,
        side: WidgetStateBorderSide.resolveWith(
          (states) => BorderSide(
            color: states.contains(WidgetState.selected)
                ? primary
                : brightness == Brightness.light
                ? SLColors.lightBorder
                : SLColors.darkBorder,
          ),
        ),
      ),
      // ActionChip reads chipTheme (no separate actionChipTheme on this
      // Flutter pin) — the labelStyle above covers it.
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, SLSpacing.minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
          textStyle: _appFontStyle(14, FontWeight.w600, onPrimary),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, SLSpacing.minTapTarget),
          shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
          textStyle: _appFontStyle(14, FontWeight.w600, primary),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: _appFontStyle(14, FontWeight.w600, primary),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          textStyle: _appFontStyle(14, FontWeight.w600, primary),
        ),
      ),
      // the chosen segment filled green (it was a shade off its neighbours —
      // beige on beige in light, invisible in dark; the tick was the only cue)
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(_appFontStyle(14, null, onSurface)),
          backgroundColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? (brightness == Brightness.light
                      ? SLColors.lightPrimarySoft
                      : primary.withValues(alpha: 0.28))
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateColor.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? (brightness == Brightness.light
                      ? SLColors.primaryDeep
                      : SLColors.darkForeground)
                : onSurfaceVariant,
          ),
          side: WidgetStateBorderSide.resolveWith(
            (states) => BorderSide(
              color: brightness == Brightness.light
                  ? SLColors.lightBorder
                  : SLColors.darkBorder,
            ),
          ),
        ),
      ),
      // empty progress tracks visible in dark (they vanished into the card)
      progressIndicatorTheme: ProgressIndicatorThemeData(
        linearTrackColor: brightness == Brightness.light
            ? SLColors.lightBorder
            : SLColors.darkBorder,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: SLRadius.brMd),
        backgroundColor: snackBg,
        contentTextStyle: _appFontStyle(16, null, snackFg),
      ),
      dialogTheme: DialogThemeData(
        titleTextStyle: _appFontStyle(22, FontWeight.w600, onSurface),
        contentTextStyle: _appFontStyle(16, null, onSurfaceVariant),
      ),
      listTileTheme: ListTileThemeData(
        titleTextStyle: _appFontStyle(16, null, onSurface),
        subtitleTextStyle: _appFontStyle(14, null, onSurfaceVariant),
      ),
      popupMenuTheme: PopupMenuThemeData(
        textStyle: _appFontStyle(14, FontWeight.w500, onSurface),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        textStyle: _appFontStyle(16, null, onSurface),
      ),
      tooltipTheme: TooltipThemeData(
        textStyle: _appFontStyle(12).copyWith(
          color: brightness == Brightness.light
              ? Colors.white
              : SLColors.darkBackground,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        // The M3 FAB container is primaryContainer; readable on it:
        // primaryDeep on lightPrimarySoft (10.8:1), darkForeground on
        // darkPrimarySoft (12.7:1).
        extendedTextStyle: _appFontStyle(
          14,
          FontWeight.w600,
          brightness == Brightness.light
              ? SLColors.primaryDeep
              : SLColors.darkForeground,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: brightness == Brightness.light
            ? SLColors.lightCard
            : SLColors.darkCard,
        border: OutlineInputBorder(
          borderRadius: SLRadius.brMd,
          borderSide: BorderSide(color: inputRim),
        ),
        // The M3 default rim is near-black — it framed every field like a
        // form from another app. inputRim: 3.2:1 light / 3.7:1 dark.
        enabledBorder: OutlineInputBorder(
          borderRadius: SLRadius.brMd,
          borderSide: BorderSide(color: inputRim),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: SLRadius.brMd,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: SLRadius.brMd,
          borderSide: BorderSide(
            color: brightness == Brightness.light
                ? SLColors.lightBorder
                : SLColors.darkBorder,
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SLSpacing.s16,
          vertical: SLSpacing.s12,
        ),
        // Family on every decoration text slot (label/floating/hint/helper/
        // error/prefix/suffix/counter). VERIFIED EXCEPTION to the explicit
        // colors above: the InputDecorator merges these UNDER its M3 default
        // styles, which are WidgetStateTextStyles — the focused (primary)
        // and error (destructive) label colors resolve through that state
        // machine. An explicit color here would freeze the label color
        // across states (input_decorator.dart _getInlineLabelStyle: default
        // merges over state, then this style merges last but is color-less,
        // so the state color survives).
        labelStyle: _appFontStyle(16),
        floatingLabelStyle: _appFontStyle(16, FontWeight.w600),
        // hints are never state-coloured, so an explicit muted ink is safe
        // (a hint as dark as typed text read as a pre-filled field)
        hintStyle: _appFontStyle(16, null, onSurfaceVariant),
        helperStyle: _appFontStyle(12),
        errorStyle: _appFontStyle(12),
        prefixStyle: _appFontStyle(16),
        suffixStyle: _appFontStyle(14),
        counterStyle: _appFontStyle(12),
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
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => _appFontStyle(
            12,
            FontWeight.w600,
            states.contains(WidgetState.selected)
                ? onSurface
                : onSurfaceVariant,
          ),
        ),
      ),
      // bottomSheetTheme carries no text styles by design — sheet content
      // inherits the family through the textTheme roles above.
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SLRadius.lg),
          ),
        ),
        showDragHandle: true,
      ),
    );
  }
}
