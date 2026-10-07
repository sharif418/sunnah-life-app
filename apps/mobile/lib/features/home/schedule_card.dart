/// আজকের সময়সূচি — one card (2026-10-07 redesign, design খ, approved with
/// the Foundation). Replaces the nine equal rows + the separate forbidden
/// card:
///
///  * the five fard waqts — start–end, এখন / পরবর্তী, past ones quiet, and
///    each waqt's adhan bell (filled = on);
///  * the nafl times as WINDOWS (when one CAN pray) — sunrise, Ishraq from,
///    Duha until the zawal window, Tahajjud until Fajr — each keeping its own
///    bell, as before;
///  * the three forbidden windows, the one in force marked;
///  * in Ramadan, Sehri's end and Iftar on top; on Friday Dhuhr reads জুমা.
///
/// Bell gestures are unchanged: tap → the timing sheet, long-press → toggle.
library;

import 'package:flutter/material.dart';

import '../../core/calendars.dart';
import '../../core/day_card.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../state/prayer_state.dart';
import '../shared/widgets.dart';
import 'sun_arc_card.dart' show clockOnly, waqtLabel;

class PrayerScheduleCard extends StatelessWidget {
  const PrayerScheduleCard({
    super.key,
    required this.prayer,
    required this.bells,
    required this.bn,
    required this.friday,
    required this.ramadan,
    required this.onBell,
    required this.onBellLongPress,
  });

  final PrayerNow prayer;
  final Set<String> bells;
  final bool bn;
  final bool friday;
  final bool ramadan;
  final void Function(PrayerKey key) onBell;
  final void Function(PrayerKey key) onBellLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    final t = prayer.times;
    final now = prayer.nowMinutes;
    final s = computeDayCard(t, now);
    final faint = cs.onSurfaceVariant.withValues(alpha: 0.62);
    String at(double m) => formatTimeBn(m, bengali: bn);
    String clock(double m) => clockOnly(m, bengali: bn);
    final nafl = naflWindows(t);
    final alert = dark ? const Color(0xFFF2A39A) : SLColors.alert;
    final alertSoft = dark ? const Color(0xFF3A1E1B) : SLColors.alertSoftLight;

    Widget tag(String text, {required bool now}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      decoration: BoxDecoration(
        color: now
            ? cs.surfaceContainerLowest
            : (dark ? const Color(0xFF3B2F14) : SLColors.goldSoftLight),
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        text,
        style: theme.textTheme.labelSmall?.copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: now
              ? cs.primary
              : (dark ? const Color(0xFFD9B25F) : SLColors.lightGoldText),
        ),
      ),
    );

    Widget fardRow(WaqtSpan w) {
      final isNow = s.current == w.key;
      final isNext = !isNow && s.next == w.key;
      final past = !isNow && !isNext && w.key != PrayerKey.isha && now >= w.end;
      final range = w.key == PrayerKey.isha
          ? '${at(w.start)} – ${at(w.end - 1)}'
          : '${at(w.start)} – ${clock(w.end - 1)}';
      return Container(
        key: ValueKey('schedule_row_${w.key.name}'),
        constraints: const BoxConstraints(minHeight: 46),
        padding: const EdgeInsetsDirectional.only(start: SLSpacing.s12),
        decoration: BoxDecoration(
          color: isNow ? cs.primaryContainer : Colors.transparent,
          borderRadius: SLRadius.brMd,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 66,
              child: Text(
                waqtLabel(context, w.key, friday: friday),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: past ? faint : (isNow ? cs.primary : cs.onSurface),
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: SLSpacing.s8,
                runSpacing: 2,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    range,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: past ? faint : cs.onSurface,
                    ),
                  ),
                  if (isNow) tag(context.t('notif_now'), now: true),
                  if (isNext) tag(context.t('notif_next'), now: false),
                ],
              ),
            ),
            PrayerBellButton(
              on: bells.contains(w.key.name),
              onToggle: () => onBell(w.key),
              onLongPress: () => onBellLongPress(w.key),
            ),
          ],
        ),
      );
    }

    Widget naflCell(PrayerKey key, String value) => Padding(
      key: ValueKey('schedule_row_${key.name}'),
      // the values never touch their neighbours, whatever the text scale
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('waqt_${key.name}'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          // a fixed line height: a value that has to shrink to fit keeps its
          // bell level with the others
          SizedBox(
            height: MediaQuery.textScalerOf(context).scale(20),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                maxLines: 1,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
          PrayerBellButton(
            on: bells.contains(key.name),
            size: 18,
            onToggle: () => onBell(key),
            onLongPress: () => onBellLongPress(key),
          ),
        ],
      ),
    );

    final windows = PrayerEngine.forbiddenWindows(t);

    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ramadan)
            Container(
              key: const ValueKey('schedule_ramadan'),
              color: dark ? const Color(0xFF3B2F14) : SLColors.goldSoftLight,
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s12,
                vertical: 10,
              ),
              child: Wrap(
                alignment: WrapAlignment.center,
                spacing: SLSpacing.s12,
                runSpacing: 4,
                children: [
                  Text(
                    context.t('sched_ramadan'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: dark
                          ? const Color(0xFFD9B25F)
                          : SLColors.lightGoldText,
                    ),
                  ),
                  Text(
                    '${context.t('sched_sehri_end')} ${at(t.fajr)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '${context.t('sched_iftar')} ${at(t.maghrib)}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(SLSpacing.s4),
            child: Column(children: [for (final w in fardSpans(t)) fardRow(w)]),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: cs.outline)),
            ),
            padding: const EdgeInsets.fromLTRB(4, 10, 4, 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: naflCell(PrayerKey.sunrise, clock(t.sunrise))),
                Expanded(
                  child: naflCell(
                    PrayerKey.ishraq,
                    context
                        .t('sched_from_fmt')
                        .replaceAll('%t', clock(nafl.ishraq)),
                  ),
                ),
                Expanded(
                  child: naflCell(
                    PrayerKey.duha,
                    '${clock(nafl.duhaStart)}–${clock(nafl.duhaEnd)}',
                  ),
                ),
                Expanded(
                  child: naflCell(
                    PrayerKey.tahajjud,
                    '${clock(nafl.tahajjudStart)}–${clock(nafl.tahajjudEnd - 1)}',
                  ),
                ),
              ],
            ),
          ),
          Container(
            key: const ValueKey('home_forbidden_card'),
            color: alertSoft,
            padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(PhosphorIconsRegular.prohibit, size: 16, color: alert),
                    const SizedBox(width: 6),
                    Text(
                      context.t('prayer_forbidden_title'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: alert,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final (key, from, to) in windows)
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: BoxDecoration(
                            // the window in force stands out
                            color: s.forbiddenKey == key
                                ? alert.withValues(alpha: 0.14)
                                : Colors.transparent,
                            borderRadius: SLRadius.brSm,
                          ),
                          child: Column(
                            children: [
                              Text(
                                context.t('forbidden_short_$key'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: alert,
                                  fontWeight: s.forbiddenKey == key
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                ),
                              ),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${clock(from)}–${clock(to)}',
                                  maxLines: 1,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: alert,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A waqt's adhan bell: tap opens its timing sheet, long-press toggles it.
/// Filled when on, a quiet outline when off.
class PrayerBellButton extends StatelessWidget {
  const PrayerBellButton({
    super.key,
    required this.on,
    required this.onToggle,
    this.onLongPress,
    this.size = 20,
  });
  final bool on;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      toggled: on,
      label: on
          ? context.t('prayer_bell_disable')
          : context.t('prayer_bell_enable'),
      child: InkWell(
        onTap: onToggle,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: SLSpacing.minTapTarget,
          height: SLSpacing.minTapTarget,
          child: Icon(
            on ? PhosphorIconsFill.bell : PhosphorIconsRegular.bell,
            size: size,
            color: on
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ),
    );
  }
}
