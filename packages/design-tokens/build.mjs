#!/usr/bin/env node
// ─────────────────────────────────────────────────────────────────────────────
// @sunnahlife/design-tokens — single source of truth builder.
//   node build.mjs          → dist/tokens.json + dist/tailwind.css + dist/flutter/design_tokens.dart
//   node build.mjs --check  → verify the web app's globals.css matches tokens.json
// ─────────────────────────────────────────────────────────────────────────────
import { readFileSync, writeFileSync, mkdirSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, join } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const tokens = JSON.parse(readFileSync(join(__dirname, "tokens.json"), "utf8"));

// camelCase helper
const camel = (s) => s.replace(/[-_](\w)/g, (_, c) => c.toUpperCase());
const dartColor = (hex) => `Color(0xFF${hex.replace("#", "").toUpperCase()})`;
const kebab = (s) => s.replace(/([a-z0-9])([A-Z])/g, "$1-$2").toLowerCase();

mkdirSync(join(__dirname, "dist/flutter"), { recursive: true });
writeFileSync(join(__dirname, "dist/tokens.json"), JSON.stringify(tokens, null, 2));

// ── 1) Tailwind CSS reference (parity with web app globals.css) ─────────────
const cssVars = (mode) =>
  Object.entries(tokens.color[mode])
    .map(([k, v]) => `  --${kebab(k)}: ${(v ?? "").toLowerCase()};`)
    .join("\n");

const tailwindCss = `/* GENERATED from packages/design-tokens/tokens.json — do not edit by hand.
   Reference parity block: the web app (src/app/globals.css) implements these
   exact values; \`node build.mjs --check\` enforces the sync. */
:root {
${cssVars("light")}
  --radius-sm: ${tokens.radius.sm}px;
  --radius-md: ${tokens.radius.md}px;
  --radius-lg: ${tokens.radius.lg}px;
  --radius-xl: ${tokens.radius.xl}px;
}
.dark {
${cssVars("dark")}
}
`;
writeFileSync(join(__dirname, "dist/tailwind.css"), tailwindCss);

// ── 2) Flutter design_tokens.dart ───────────────────────────────────────────
const L = tokens.color.light, D = tokens.color.dark, B = tokens.color.brand;
const fhex = (c) => c.replace("#", "").toUpperCase();
const dart = `// GENERATED from packages/design-tokens/tokens.json — do not edit by hand.
// Single source of truth for Sunnah Life's visual language on Flutter.
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SLColors {
  // Brand
  ${Object.entries(B).map(([k, v]) => `static const Color ${camel(k)} = ${dartColor(v)};`).join("\n  ")}

  // Light theme semantics
  ${Object.entries(L).filter(([k]) => !k.startsWith("chart")).map(([k, v]) => `static const Color light${camel(k).replace(/^./, (m) => m.toUpperCase())} = ${dartColor(v)};`).join("\n  ")}

  // Dark theme semantics
  ${Object.entries(D).filter(([k]) => !k.startsWith("chart")).map(([k, v]) => `static const Color dark${camel(k).replace(/^./, (m) => m.toUpperCase())} = ${dartColor(v)};`).join("\n  ")}
}

class SLSpacing {
  static const double unit = ${tokens.spacing.unit}.0;
  static double of(int units) => units * unit;
  ${tokens.spacing.scale.map((s) => `static const double s${s} = ${s}.0;`).join("\n  ")}
  static const double minTapTarget = ${tokens.tapTarget}.0;
}

class SLRadius {
  static const double sm = ${tokens.radius.sm}.0;
  static const double md = ${tokens.radius.md}.0;
  static const double lg = ${tokens.radius.lg}.0;
  static const double xl = ${tokens.radius.xl}.0;
  static const double pill = ${tokens.radius.pill}.0;
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
  static const Duration fast = Duration(milliseconds: ${tokens.motion.durations.fast});
  static const Duration base = Duration(milliseconds: ${tokens.motion.durations.base});
  static const Duration slow = Duration(milliseconds: ${tokens.motion.durations.slow});
  static const Curve standard = Cubic(0.2, 0.0, 0.0, 1.0);
  static const Curve decelerate = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve accelerate = Cubic(0.3, 0.0, 0.8, 0.15);
}

class SLElevation {
  static List<BoxShadow> card(bool dark) => [
        BoxShadow(
          color: Color(0x0D${fhex(B.primary)}),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: Color(0x08${fhex(B.primary)}),
          blurRadius: 2,
          offset: const Offset(0, 1),
        ),
      ];
  static List<BoxShadow> lifted(bool dark) => [
        BoxShadow(
          color: Color(0x1F${fhex(B.primary)}),
          blurRadius: 32,
          offset: const Offset(0, 12),
        ),
        BoxShadow(
          color: Color(0x14${fhex(B.primary)}),
          blurRadius: 4,
          offset: const Offset(0, 2),
        ),
      ];
}

class SLType {
  static const double caption = ${tokens.typography.scale.caption.size};
  static const double body = ${tokens.typography.scale.body.size};
  static const double bodyLarge = ${tokens.typography.scale.bodyLarge.size};
  static const double heading = ${tokens.typography.scale.heading.size};
  static const double headingLarge = ${tokens.typography.scale.headingLarge.size};
  static const double display = ${tokens.typography.scale.display.size};

  /// Bengali-first text theme using Google Fonts (Hind Siliguri).
  static TextTheme textTheme(TextTheme base) => base.copyWith(
        displaySmall: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.display.size}, height: ${tokens.typography.scale.display.lineHeight},
            fontWeight: FontWeight.w700),
        headlineMedium: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.headingLarge.size}, height: ${tokens.typography.scale.headingLarge.lineHeight},
            fontWeight: FontWeight.w700),
        titleMedium: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.heading.size}, height: ${tokens.typography.scale.heading.lineHeight},
            fontWeight: FontWeight.w600),
        bodyLarge: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.bodyLarge.size}, height: ${tokens.typography.scale.bodyLarge.lineHeight}),
        bodyMedium: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.body.size}, height: ${tokens.typography.scale.body.lineHeight}),
        bodySmall: GoogleFonts.hindSiliguri(
            fontSize: ${tokens.typography.scale.caption.size}, height: ${tokens.typography.scale.caption.lineHeight}),
      );

  /// Uthmani Qur'an text.
  static TextStyle quran({Color? color}) => GoogleFonts.amiriQuran(
        fontSize: ${tokens.typography.scale.quran.size},
        height: ${tokens.typography.scale.quran.lineHeight},
        color: color,
      );

  /// Arabic du'a text.
  static TextStyle dua({Color? color}) => GoogleFonts.amiri(
        fontSize: ${tokens.typography.scale.dua.size},
        height: ${tokens.typography.scale.dua.lineHeight},
        color: color,
      );
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
    textTheme: SLType.textTheme(ThemeData(brightness: Brightness.light).textTheme),
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
    textTheme: SLType.textTheme(ThemeData(brightness: Brightness.dark).textTheme),
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
          color: brightness == Brightness.light ? SLColors.lightCard : SLColors.darkCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: SLRadius.brLg,
            side: BorderSide(
              color: brightness == Brightness.light ? SLColors.lightBorder : SLColors.darkBorder,
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
          fillColor: brightness == Brightness.light ? SLColors.lightCard : SLColors.darkCard,
          border: OutlineInputBorder(
            borderRadius: SLRadius.brMd,
            borderSide: BorderSide(
              color: brightness == Brightness.light ? SLColors.lightBorder : SLColors.darkBorder,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s4, vertical: SLSpacing.s3),
        ),
        chipTheme: ChipThemeData(
          shape: RoundedRectangleBorder(borderRadius: SLRadius.brPill),
          side: BorderSide(
            color: brightness == Brightness.light ? SLColors.lightBorder : SLColors.darkBorder,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: brightness == Brightness.light ? SLColors.lightCard : SLColors.darkCard,
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
`;
writeFileSync(join(__dirname, "dist/flutter/design_tokens.dart"), dart);

// ── 3) --check: globals.css parity guard ─────────────────────────────────────
if (process.argv.includes("--check")) {
  const css = readFileSync(join(__dirname, "../../apps/web/src/app/globals.css"), "utf8").toLowerCase();
  // globals.css implements the semantic light/dark roles; brand extras (deep variants)
  // are token-level conveniences only.
  const all = [...Object.values(L), ...Object.values(D)];
  const missing = [...new Set(all.filter((hex) => !css.includes(hex.toLowerCase())))];
  if (missing.length) {
    console.error("✗ globals.css is OUT OF SYNC with tokens.json — missing:", missing);
    process.exit(1);
  }
  console.log(`✓ globals.css in sync with tokens.json (${all.length} color values verified)`);
} else {
  console.log("✓ design-tokens built: dist/tokens.json, dist/tailwind.css, dist/flutter/design_tokens.dart");
}
