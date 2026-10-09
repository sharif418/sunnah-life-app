/// The home prayer card (2026-10-07 redesign, approved with the Foundation;
/// prototype: the "নামাজ কার্ড ও ফন্ট" canvas). Replaces the countdown ring.
///
///  * the sky — the sun (by day) or the moon (by night) on its arc from
///    sunrise to sunset, a faint mosque, the running waqt and the next one in
///    one narrow centred column the orb never crosses (geometry below);
///  * the forbidden window, only while it lasts;
///  * the running waqt's span, a progress bar and the time left;
///  * today's five fard prayers as written in the diary (tap → the diary);
///  * the link down to the full schedule and its bells.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
import '../../core/day_card.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../state/prayer_state.dart';
import '../shared/widgets.dart';
import 'home_sections.dart' show HeroPrayerStatus;

/// Waqt label with Friday's Jumu'ah in place of Dhuhr.
String waqtLabel(BuildContext context, PrayerKey key, {required bool friday}) =>
    key == PrayerKey.dhuhr && friday
    ? context.t('jumuah')
    : context.t('waqt_${key.name}');

/// "১১:৪৬" (Bengali, no day part) / "11:46 AM".
String clockOnly(double minutes, {required bool bengali}) {
  if (!bengali) return formatTimeBn(minutes, bengali: false);
  final m = ((minutes.round() % 1440) + 1440) % 1440;
  final h = (m ~/ 60) % 12 == 0 ? 12 : (m ~/ 60) % 12;
  return toBn('$h:${(m % 60).toString().padLeft(2, '0')}');
}

/// "২ ঘণ্টা ৯ মিনিট বাকি".
String timeLeftText(
  BuildContext context,
  int minutes, {
  required bool bengali,
}) {
  String n(int v) => bengali ? toBn(v) : '$v';
  final h = minutes ~/ 60, m = minutes % 60;
  final parts = <String>[
    if (h > 0) '${n(h)} ${context.t('sun_hours')}',
    '${n(m)} ${context.t('sun_minutes')}',
  ];
  return '${parts.join(' ')} ${context.t('sun_left')}';
}

class SunArcPrayerCard extends StatelessWidget {
  const SunArcPrayerCard({
    super.key,
    required this.prayer,
    required this.bn,
    required this.friday,
    this.todayPrayers,
    this.onTapPrayers,
    this.onShowSchedule,
  });

  final PrayerNow prayer;
  final bool bn;

  /// Friday: Dhuhr reads জুমা.
  final bool friday;

  /// The five fard prayers as recorded in the diary (null: no strip).
  final List<HeroPrayerStatus>? todayPrayers;
  final VoidCallback? onTapPrayers;

  /// In-page scroll to the schedule (its bells live there).
  final VoidCallback? onShowSchedule;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = prayer.times;
    final s = computeDayCard(t, prayer.nowMinutes);
    String label(PrayerKey k) => waqtLabel(context, k, friday: friday);
    String at(double m) => formatTimeBn(m, bengali: bn);

    final current = s.current;
    final spanName = current != null
        ? label(current)
        : context.t(friday ? 'sun_wait_jumuah' : 'sun_wait_dhuhr');
    final spanRange = current == PrayerKey.isha
        ? '${at(s.spanStart)} – ${at(s.spanEnd - 1)}'
        : current != null
        ? '${at(s.spanStart)} – ${clockOnly(s.spanEnd - 1, bengali: bn)}'
        : '${context.t('waqt_sunrise')} ${clockOnly(t.sunrise, bengali: bn)} – '
              '${label(PrayerKey.dhuhr)} ${clockOnly(t.dhuhr, bengali: bn)}';

    return Container(
      key: const ValueKey('home_sun_card'),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(SLRadius.xl),
        border: Border.all(color: cs.outline),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A173A2E),
            blurRadius: 18,
            offset: Offset(0, 6),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Sky(
            state: s,
            times: t,
            bn: bn,
            nowLabel: context.t(
              current != null ? 'sun_now_running' : 'sun_now',
            ),
            nowName: current != null
                ? label(current)
                : context.t('sun_after_sunrise'),
            nextLine: '${label(s.next)} · ${at(t.byKey(s.next))}',
          ),
          if (s.forbiddenKey != null)
            Container(
              key: const ValueKey('home_forbidden_now'),
              color: theme.brightness == Brightness.dark
                  ? const Color(0xFF3A1E1B)
                  : SLColors.alertSoftLight,
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s16,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.prohibit,
                    size: 18,
                    color: _alert(theme),
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Text(
                      '${context.t('sun_forbidden_now')} — '
                      '${context.t('forbidden_short_${s.forbiddenKey}')}, '
                      '${context.t('sun_until_fmt').replaceAll('%t', at(s.forbiddenEnd!))}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _alert(theme),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              14,
              SLSpacing.s16,
              SLSpacing.s16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  spacing: SLSpacing.s8,
                  children: [
                    Text(
                      spanName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      spanRange,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: SLRadius.brPill,
                  child: LinearProgressIndicator(
                    value: s.fraction,
                    minHeight: 10,
                    color: cs.primary,
                    backgroundColor: theme.brightness == Brightness.dark
                        ? const Color(0xFF22312A)
                        : const Color(0xFFECE6D8),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _success(theme),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 2,
                      child: Text(
                        context.t(
                          current != null
                              ? 'sun_running'
                              : 'sun_ishraq_duha_time',
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: _success(theme),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    // the time left never pushes the row over: on a small
                    // phone at large text it shrinks a little instead
                    Flexible(
                      flex: 3,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          timeLeftText(context, s.minutesLeft, bengali: bn),
                          key: const ValueKey('home_waqt_left'),
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (todayPrayers != null)
            _TodayStrip(
              prayers: todayPrayers!,
              times: t,
              current: current,
              bn: bn,
              onTap: onTapPrayers,
            ),
          if (onShowSchedule != null)
            InkWell(
              key: const ValueKey('home_to_schedule'),
              onTap: onShowSchedule,
              child: Container(
                constraints: const BoxConstraints(
                  minHeight: SLSpacing.minTapTarget,
                ),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: cs.outline)),
                ),
                alignment: Alignment.center,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.t('countdown_to_schedule'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 4),
                    DirectionalIcon(
                      PhosphorIconsRegular.caretRight,
                      size: 16,
                      color: cs.primary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Color _alert(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFFF2A39A)
    : SLColors.alert;

Color _success(ThemeData theme) => theme.brightness == Brightness.dark
    ? const Color(0xFF5DBB8A)
    : SLColors.success;

// ── the sky ────────────────────────────────────────────────────────────────

class _Sky extends StatelessWidget {
  const _Sky({
    required this.state,
    required this.times,
    required this.bn,
    required this.nowLabel,
    required this.nowName,
    required this.nextLine,
  });
  final DayCardState state;
  final PrayerTimesBundle times;
  final bool bn;
  final String nowLabel;
  final String nowName;
  final String nextLine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final night = !state.isDay;
    final (Color bg, Color fg, Color sub, Color arc, Color mosque) = night
        ? (
            dark ? const Color(0xFF0B1A14) : SLColors.primaryDeep,
            const Color(0xFFF7F4EC),
            const Color(0xFFC9D6CE),
            const Color(0x59F6ECD8),
            const Color(0x12F6ECD8),
          )
        : dark
        ? (
            const Color(0xFF1A2B23),
            const Color(0xFFF1EDE3),
            const Color(0xFFA9B6AE),
            const Color(0x73D9B25F),
            const Color(0x0FF1EDE3),
          )
        : (
            SLColors.primarySoftLight,
            SLColors.primaryDeep,
            const Color(0xFF4E6258),
            const Color(0x73B7791F),
            const Color(0x141F4D3D),
          );
    // taller under large text so the centred column never clips
    final height = math.max(168.0, MediaQuery.textScalerOf(context).scale(140));
    final small = theme.textTheme.bodySmall?.copyWith(color: sub, fontSize: 12);

    return Semantics(
      container: true,
      label: '$nowLabel $nowName. ${context.t('sun_next')}: $nextLine',
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          child: LayoutBuilder(
            builder: (context, box) {
              final w = box.maxWidth;
              final base = height - 18; // the horizon
              final rx = (w - 40) / 2;
              final ry = math.min(128.0, base - 22);
              final f = state.orbFraction;
              final ox = w / 2 - rx * math.cos(f * math.pi);
              // seated ON the horizon at either end (never centred on it),
              // so it never covers the sunrise / sunset labels below
              final oy = math.min(base - ry * math.sin(f * math.pi), base - 15);
              // at the zenith the sun itself marks midday: its label steps
              // aside instead of being covered
              final nearNoon = state.isDay && (f - 0.5).abs() < 0.09;
              return Container(
                color: bg,
                child: Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _SkyPainter(
                          arc: arc,
                          mosque: mosque,
                          baseline: base,
                          rx: rx,
                          ry: ry,
                          stars: night,
                        ),
                      ),
                    ),
                    Positioned(
                      left: ox - 15,
                      top: oy - 15,
                      width: 30,
                      height: 30,
                      child: night
                          ? const Icon(
                              PhosphorIconsFill.moon,
                              size: 26,
                              color: Color(0xFFF6ECD8),
                            )
                          : const Icon(
                              PhosphorIconsFill.sun,
                              size: 30,
                              color: Color(0xFFE8B04A),
                            ),
                    ),
                    // the narrow centred column (188 wide): wherever the
                    // orb is level with it, the arc has already lifted it
                    // above the column's top
                    Positioned(
                      left: (w - 196) / 2,
                      width: 196,
                      top: 60,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(nowLabel, style: small),
                          Text(
                            nowName,
                            key: const ValueKey('home_sun_now'),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontSize: 26,
                              height: 1.3,
                              fontWeight: FontWeight.w700,
                              color: fg,
                            ),
                          ),
                          // one line, always: under large text it shrinks a
                          // little instead of dropping the time onto the
                          // horizon
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: '${context.t('sun_next')}: ',
                                    style: TextStyle(color: sub),
                                  ),
                                  TextSpan(text: nextLine),
                                ],
                              ),
                              maxLines: 1,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontSize: 14,
                                color: fg,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!nearNoon)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 8,
                        child: Text(
                          '${context.t('sun_noon')} ${clockOnly(times.dhuhr - 1, bengali: bn)}',
                          textAlign: TextAlign.center,
                          style: small,
                        ),
                      ),
                    Positioned(
                      left: 10,
                      bottom: 2,
                      child: Text(
                        '${context.t('waqt_sunrise')} ${clockOnly(times.sunrise, bengali: bn)}',
                        style: small,
                      ),
                    ),
                    Positioned(
                      right: 10,
                      bottom: 2,
                      child: Text(
                        '${context.t('waqt_sunset')} ${clockOnly(times.sunset, bengali: bn)}',
                        style: small,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SkyPainter extends CustomPainter {
  _SkyPainter({
    required this.arc,
    required this.mosque,
    required this.baseline,
    required this.rx,
    required this.ry,
    required this.stars,
  });
  final Color arc;
  final Color mosque;
  final double baseline;
  final double rx;
  final double ry;
  final bool stars;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // faint mosque on the horizon: dome, two side halls, two minarets
    final m = Paint()..color = mosque;
    final dome = Path()
      ..moveTo(cx - 29, baseline)
      ..lineTo(cx - 29, baseline - 34)
      ..quadraticBezierTo(cx - 29, baseline - 60, cx, baseline - 72)
      ..quadraticBezierTo(cx + 29, baseline - 60, cx + 29, baseline - 34)
      ..lineTo(cx + 29, baseline)
      ..close();
    canvas.drawPath(dome, m);
    for (final dx in [-59.0, 37.0]) {
      canvas.drawRect(Rect.fromLTWH(cx + dx, baseline - 24, 22, 24), m);
    }
    for (final dx in [-79.0, 71.0]) {
      canvas.drawRect(Rect.fromLTWH(cx + dx, baseline - 62, 8, 62), m);
      canvas.drawRect(Rect.fromLTWH(cx + dx + 3, baseline - 72, 2, 10), m);
    }
    // the dashed path of the sun
    final p = Paint()
      ..color = arc
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    const steps = 60;
    for (var i = 0; i < steps; i += 2) {
      final a0 = math.pi * i / steps, a1 = math.pi * (i + 1) / steps;
      canvas.drawLine(
        Offset(cx - rx * math.cos(a0), baseline - ry * math.sin(a0)),
        Offset(cx - rx * math.cos(a1), baseline - ry * math.sin(a1)),
        p,
      );
    }
    canvas.drawLine(
      Offset(12, baseline),
      Offset(size.width - 12, baseline),
      Paint()
        ..color = arc
        ..strokeWidth = 1,
    );
    if (stars) {
      final st = Paint()..color = const Color(0xFFF6ECD8);
      for (final (fx, y) in const [
        (0.11, 30.0),
        (0.22, 62.0),
        (0.34, 22.0),
        (0.66, 34.0),
        (0.79, 70.0),
        (0.89, 26.0),
        (0.55, 44.0),
        (0.17, 104.0),
      ]) {
        canvas.drawCircle(Offset(size.width * fx, y), 1.3, st);
      }
    }
  }

  @override
  bool shouldRepaint(_SkyPainter old) =>
      old.arc != arc ||
      old.mosque != mosque ||
      old.baseline != baseline ||
      old.rx != rx ||
      old.ry != ry ||
      old.stars != stars;
}

// ── today's five, as written in the diary ──────────────────────────────────

class _TodayStrip extends StatelessWidget {
  const _TodayStrip({
    required this.prayers,
    required this.times,
    required this.current,
    required this.bn,
    this.onTap,
  });
  final List<HeroPrayerStatus> prayers;
  final PrayerTimesBundle times;
  final PrayerKey? current;
  final bool bn;
  final VoidCallback? onTap;

  static const _keys = [
    PrayerKey.fajr,
    PrayerKey.dhuhr,
    PrayerKey.asr,
    PrayerKey.maghrib,
    PrayerKey.isha,
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return InkWell(
      key: const ValueKey('home_today_strip'),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: cs.outline)),
        ),
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Row(
          children: [
            for (var i = 0; i < prayers.length && i < _keys.length; i++)
              Expanded(
                child: _StripCell(
                  status: prayers[i],
                  time: clockOnly(times.byKey(_keys[i]), bengali: bn),
                  isNow: current == _keys[i],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StripCell extends StatelessWidget {
  const _StripCell({
    required this.status,
    required this.time,
    required this.isNow,
  });
  final HeroPrayerStatus status;
  final String time;
  final bool isNow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final success = _success(theme);
    final (Widget mark, String state) = switch (status.value) {
      'jamaat' => (
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(color: success, shape: BoxShape.circle),
          child: const Icon(
            PhosphorIconsBold.check,
            size: 14,
            color: Colors.white,
          ),
        ),
        context.t('amal_jamaat'),
      ),
      'alone' => (
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: success, width: 2),
          ),
          child: Icon(PhosphorIconsBold.check, size: 13, color: success),
        ),
        context.t('amal_alone'),
      ),
      'qaza' => (
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: SLColors.goldDeep, width: 2),
          ),
          child: const Icon(
            PhosphorIconsRegular.clock,
            size: 13,
            color: SLColors.goldDeep,
          ),
        ),
        context.t('amal_qaza'),
      ),
      _ => (
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: isNow
                  ? cs.primary
                  : cs.onSurfaceVariant.withValues(
                      alpha: status.started ? 0.6 : 0.3,
                    ),
              width: isNow ? 2 : 1.5,
            ),
          ),
        ),
        status.started ? context.t('hero_prayer_pending') : '',
      ),
    };
    return Semantics(
      label: '${status.label} $time ${state.isEmpty ? '' : '· $state'}',
      child: ExcludeSemantics(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isNow ? cs.primaryContainer : Colors.transparent,
            borderRadius: SLRadius.brMd,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                status.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 14,
                  fontWeight: isNow ? FontWeight.w700 : FontWeight.w600,
                  color: isNow ? cs.primary : cs.onSurface,
                ),
              ),
              // (no start time here: the card above says the current and
              // next waqt, the schedule below lists every time — a third
              // set of times made the hero busy; the reader still hears it)
              const SizedBox(height: 6),
              mark,
              const SizedBox(height: 2),
              Text(
                state,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
