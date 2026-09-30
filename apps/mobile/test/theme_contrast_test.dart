// Theme text-color contrast — W5.
//
// The W5 font-golden bug: ListTile/chip theme styles were color-less, and
// because component themes REPLACE their M3 defaults (unlike textTheme
// roles, which ThemeData merges over typography colors), the labels ended
// up with near-white text on the cream surface. This pins the fix: the
// EFFECTIVE rendered color of a ListTile title/subtitle and a chip label
// must contrast ≥ 4.5:1 (WCAG AA) against the surface they sit on, in both
// the light and the dark theme.
//
// Contrast is computed per WCAG relative luminance
// (https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sunnah_life/design/design_tokens.dart';

/// sRGB 8-bit channel → linear luminance component.
double _linearize(int channel8) {
  final c = channel8 / 255.0;
  return c <= 0.04045 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
}

double luminance(Color c) {
  return 0.2126 * _linearize((c.r * 255.0).round().clamp(0, 255)) +
      0.7152 * _linearize((c.g * 255.0).round().clamp(0, 255)) +
      0.0722 * _linearize((c.b * 255.0).round().clamp(0, 255));
}

/// WCAG contrast ratio between two colors.
double contrastRatio(Color a, Color b) {
  final lighter = math.max(luminance(a), luminance(b));
  final darker = math.min(luminance(a), luminance(b));
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets(
      'ListTile + chip labels — effective contrast ≥ 4.5:1 ($brightness)',
      (tester) async {
        final theme = brightness == Brightness.light
            ? buildSunnahLightTheme()
            : buildSunnahDarkTheme();

        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: ListView(
                children: const [
                  ListTile(
                    title: Text('শিরোনাম'),
                    subtitle: Text('উপশিরোনাম'),
                  ),
                  ActionChip(
                    label: Text('চিপ'),
                    onPressed: null,
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final bg = theme.scaffoldBackgroundColor;

        Color effectiveColor(String text) {
          final rp = tester.renderObject<RenderParagraph>(find.text(text));
          final color = rp.text.style?.color;
          expect(color, isNotNull, reason: '"$text" has no effective color');
          return color!;
        }

        // The reported bug #1: invisible ListTile titles/subtitles.
        expect(
          contrastRatio(effectiveColor('শিরোনাম'), bg),
          greaterThan(4.5),
          reason: 'ListTile title must contrast ≥ 4.5:1 against the '
              'scaffold background',
        );
        expect(
          contrastRatio(effectiveColor('উপশিরোনাম'), bg),
          greaterThan(4.5),
          reason: 'ListTile subtitle must contrast ≥ 4.5:1',
        );

        // The reported bug #2: near-invisible chip labels. ActionChips in
        // this app render with a transparent background over the scaffold
        // (chipTheme sets no backgroundColor), so the effective backdrop
        // is the scaffold color.
        expect(
          contrastRatio(effectiveColor('চিপ'), bg),
          greaterThan(4.5),
          reason: 'chip label must contrast ≥ 4.5:1 against the scaffold '
              'background it floats over',
        );
      },
    );
  }
}
