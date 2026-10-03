/// C-W4b home section components — the countdown ring hero, the most-used
/// amal card and the quick-access tile. PUBLIC + context-free (labels come
/// in via `S.tr(lang, key)` / plain strings) so the component catalog
/// (catalog_app.dart) and the widget tests can mount them without a
/// ProviderScope; home_screen.dart feeds them live provider data.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../core/most_used.dart';
import '../../core/prayer_engine.dart';
import '../../core/waqt_progress.dart';
import '../../design/design_tokens.dart';
import '../../design/texture.dart';
import '../../design/phosphor_icons.dart';
import '../../l10n/app_strings.dart';
import '../shared/widgets.dart';
import '../../state/prayer_state.dart';

// ── Countdown ring hero ──────────────────────────────────────────────────────

/// The home hero: primary→primaryDeep gradient card. Left: the current-waqt
/// gold pill, the HH:MM:SS countdown (tabular digits, bn via toBn) and the
/// next waqt's name AND time (HOME-01). Right: the waqt ring — the GOLD arc
/// is the REMAINING fraction of the current waqt interval (waqt_progress.dart).
/// Bottom: today's five fard prayers as recorded in the diary (tap → the
/// diary), then the affordance that scrolls the page to the prayer schedule
/// (an IN-PAGE transition — the schedule is a section of the same screen).
/// One fard prayer's state for the hero's today strip.
class HeroPrayerStatus {
  const HeroPrayerStatus({
    required this.label,
    required this.value,
    required this.started,
  });

  /// ফজর / যোহর / …
  final String label;

  /// The diary value: 'jamaat' | 'alone' | 'qaza' | null (unrecorded).
  final String? value;

  /// Whether the waqt has begun (an unstarted waqt is drawn faint).
  final bool started;
}

class CountdownRingHero extends StatelessWidget {
  const CountdownRingHero({
    super.key,
    required this.prayer,
    required this.lang,
    required this.bn,
    this.onShowSchedule,
    this.todayPrayers,
    this.onTapPrayers,
  });

  final PrayerNow prayer;
  final Lang lang;
  final bool bn;

  /// In-page scroll to the schedule section (home passes
  /// Scrollable.ensureVisible on the schedule header's GlobalKey).
  final VoidCallback? onShowSchedule;

  /// Today's five fard prayers as recorded in the diary — the strip at the
  /// bottom of the hero (null: no strip, e.g. the component catalog).
  final List<HeroPrayerStatus>? todayPrayers;

  /// Tapping the strip opens the diary.
  final VoidCallback? onTapPrayers;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interval = waqtInterval(prayer.times, prayer.nowMinutes);
    final currentLabel = _waqtLabel(prayer.currentWaqt);
    final nextLabel = _waqtLabel(prayer.nextKey);
    final nextTime = formatTimeBn(
      prayer.times.byKey(prayer.nextKey),
      bengali: bn,
    );
    const onHero = SLColors.lightPrimaryForeground;

    return Container(
      key: const ValueKey('home_ring_hero'),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SLColors.primary, SLColors.primaryDeep],
        ),
        borderRadius: SLRadius.brXl,
        boxShadow: SLElevation.lifted(theme.brightness == Brightness.dark),
      ),
      // W4f: the whisper-quiet khatam lattice behind the content — 5 %
      // foreground, lines only, clipped to the card's rounded corners.
      child: ClipRRect(
        borderRadius: SLRadius.brXl,
        child: Stack(
          children: [
            const Positioned.fill(child: SLGeometricTexture(opacity: 0.05)),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SLSpacing.s20,
                SLSpacing.s20,
                SLSpacing.s16,
                SLSpacing.s12,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: SLColors.gold,
                                borderRadius: SLRadius.brPill,
                              ),
                              child: Text(
                                '${S.tr(lang, 'prayer_current')}: $currentLabel',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: SLColors.primaryDeep,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(height: SLSpacing.s8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: AlignmentDirectional.centerStart,
                              child: Text(
                                prayer.countdownText(bengali: bn),
                                key: const ValueKey('home_countdown_text'),
                                maxLines: 1,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  color: SLColors.gold,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                            // HOME-01: the next waqt's NAME and TIME
                            Text(
                              '${S.tr(lang, 'prayer_next')}: $nextLabel · $nextTime',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onHero.withValues(alpha: 0.88),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: SLSpacing.s12),
                      SizedBox(
                        width: 84,
                        height: 84,
                        child: CustomPaint(
                          painter: _WaqtRingPainter(
                            fraction: interval.remainingFraction,
                            track: _trackColor(theme),
                            // Explicit resolution (painters get no
                            // BuildContext): the Arabic tree flips the arc's
                            // decay direction with its reading direction.
                            rtl:
                                Directionality.of(context) == TextDirection.rtl,
                          ),
                          child: const Center(
                            child: Icon(
                              PhosphorIconsFill.mosque,
                              color: SLColors.gold,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (todayPrayers != null) ...[
                    const SizedBox(height: SLSpacing.s12),
                    Container(height: 1, color: onHero.withValues(alpha: 0.16)),
                    const SizedBox(height: SLSpacing.s8),
                    Semantics(
                      button: onTapPrayers != null,
                      label: S.tr(lang, 'diary_title'),
                      child: InkWell(
                        key: const ValueKey('home_today_prayers'),
                        onTap: onTapPrayers,
                        borderRadius: SLRadius.brMd,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              for (final p in todayPrayers!)
                                Expanded(
                                  child: _HeroPrayerDot(status: p, lang: lang),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                  // Affordance: smooth in-page scroll to the schedule section.
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      key: const ValueKey('home_to_schedule'),
                      borderRadius: SLRadius.brMd,
                      onTap: onShowSchedule,
                      child: SizedBox(
                        height: SLSpacing.minTapTarget,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              PhosphorIconsRegular.clock,
                              size: 18,
                              color: onHero.withValues(alpha: 0.8),
                            ),
                            const SizedBox(width: SLSpacing.s8),
                            Text(
                              S.tr(lang, 'countdown_to_schedule'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: onHero,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: SLSpacing.s4),
                            DirectionalIcon(
                              PhosphorIconsBold.caretRight,
                              size: 14,
                              color: onHero.withValues(alpha: 0.8),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _waqtLabel(PrayerKey key) => S.tr(lang, 'waqt_${key.name}');

  Color _trackColor(ThemeData theme) =>
      (theme.brightness == Brightness.dark
              ? SLColors.darkAccent
              : SLColors.goldSoftLight)
          .withValues(alpha: theme.brightness == Brightness.dark ? 0.30 : 0.55);
}

/// One prayer in the hero strip: a mark (✓ জামাতে · / একা · ⏲ কাযা · empty
/// = not yet recorded · dashed = waqt not begun) over its name and state.
class _HeroPrayerDot extends StatelessWidget {
  const _HeroPrayerDot({required this.status, required this.lang});
  final HeroPrayerStatus status;
  final Lang lang;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const onHero = SLColors.lightPrimaryForeground;
    final (Widget mark, String state) = switch (status.value) {
      'jamaat' => (
        Container(
          width: 28,
          height: 28,
          decoration: const BoxDecoration(
            color: SLColors.gold,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            PhosphorIconsRegular.check,
            size: 16,
            color: SLColors.primaryDeep,
          ),
        ),
        S.tr(lang, 'amal_jamaat'),
      ),
      'alone' => (
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: SLColors.gold, width: 2),
          ),
          child: Center(
            child: Text(
              '/',
              style: theme.textTheme.titleMedium?.copyWith(
                color: SLColors.gold,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
        ),
        S.tr(lang, 'amal_alone'),
      ),
      'qaza' => (
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: onHero.withValues(alpha: 0.7), width: 2),
          ),
          child: Icon(
            PhosphorIconsRegular.clock,
            size: 15,
            color: onHero.withValues(alpha: 0.85),
          ),
        ),
        S.tr(lang, 'amal_qaza'),
      ),
      _ => (
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: onHero.withValues(alpha: status.started ? 0.7 : 0.3),
              width: status.started ? 2 : 1.5,
            ),
          ),
        ),
        status.started ? S.tr(lang, 'hero_prayer_pending') : '',
      ),
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(height: 2),
        Text(
          status.label,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: theme.textTheme.bodySmall?.copyWith(
            color: onHero,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          state,
          maxLines: 1,
          overflow: TextOverflow.fade,
          softWrap: false,
          style: theme.textTheme.labelSmall?.copyWith(
            color: onHero.withValues(alpha: 0.78),
          ),
        ),
      ],
    );
  }
}

/// The waqt ring — track full circle, gold arc = remaining fraction of the
/// interval, round caps, sweeping clockwise from 12 o'clock in LTR and
/// MIRRORED (counter-clockwise) under RTL so the decay direction follows the
/// reading direction.
class _WaqtRingPainter extends CustomPainter {
  _WaqtRingPainter({
    required this.fraction,
    required this.track,
    required this.rtl,
  });

  /// 0..1 — REMAINING of the current waqt interval.
  final double fraction;
  final Color track;

  /// Resolved by the widget via Directionality.of — painters get no context.
  final bool rtl;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final inset = stroke / 2 + 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = SLColors.gold;
    canvas.drawArc(rect, 0, math.pi * 2, false, base);
    // RTL sweeps negative = the mirrored decay direction for Arabic.
    final sweep = math.pi * 2 * fraction.clamp(0.0, 1.0) * (rtl ? -1 : 1);
    canvas.drawArc(rect, -math.pi / 2, sweep, false, fill);
  }

  @override
  bool shouldRepaint(_WaqtRingPainter old) =>
      old.fraction != fraction || old.track != track || old.rtl != rtl;
}

// ── Most-used amal card ──────────────────────────────────────────────────────

/// One সর্বাধিক ব্যবহৃত card: amal title, the "N দিন" usage chip and the
/// আজ লিখুন quick-log button (hidden for free-text amals — quickLogValue
/// decides, never the card).
class MostUsedCard extends StatelessWidget {
  const MostUsedCard({
    super.key,
    required this.item,
    required this.currentValue,
    required this.lang,
    required this.onQuickLog,
  });

  final MostUsedAmal item;
  final Object? currentValue;
  final Lang lang;

  /// Receives the quick-log VALUE computed by quickLogValue — the write
  /// itself (amalProvider.write with source 'quick:home') stays in the
  /// screen so this widget stays catalog/test mountable.
  final void Function(Object value) onQuickLog;

  bool get bn => lang == Lang.bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = item.def;
    final title = bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn;
    final quickValue = quickLogValue(def, currentValue);

    return AppCard(
      key: ValueKey('most_used_card_${def.key}'),
      child: SizedBox(
        width: 168,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            Container(
              key: ValueKey('most_used_days_${def.key}'),
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.tertiaryContainer,
                borderRadius: SLRadius.brPill,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    PhosphorIconsFill.fire,
                    size: 14,
                    color: SLColors.goldDeep,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      '${bn ? toBn(item.daysUsed) : '${item.daysUsed}'} '
                      '${S.tr(lang, 'most_used_days')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (quickValue != null) ...[
              const SizedBox(height: SLSpacing.s8),
              SizedBox(
                height: SLSpacing.minTapTarget,
                child: FilledButton.tonal(
                  key: ValueKey('most_used_log_${def.key}'),
                  onPressed: () => onQuickLog(quickValue),
                  child: Text(
                    S.tr(lang, 'most_used_log_today'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Quick access tile ────────────────────────────────────────────────────────

/// One দ্রুত প্রবেশ tile — icon in a tinted circle + title + subtitle
/// (bento rhythm; the whole tile is the 44px+ tap target via AppCard's
/// InkWell).
class QuickAccessTile extends StatelessWidget {
  const QuickAccessTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Compact, start-aligned: icon beside a two-line title — six tiles fit
    // in two thumb-lengths instead of three screens of square cards.
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SLSpacing.s12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: SLRadius.brMd,
            ),
            child: Icon(icon, size: 22, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
