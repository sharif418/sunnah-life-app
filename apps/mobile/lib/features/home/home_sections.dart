/// C-W4b home section components — the prayer status of the card's today
/// strip, the most-used amal list and the quick-access tile (the prayer card
/// itself lives in sun_arc_card.dart since the 2026-10-07 redesign). PUBLIC + context-free (labels come
/// in via `S.tr(lang, key)` / plain strings) so the component catalog
/// (catalog_app.dart) and the widget tests can mount them without a
/// ProviderScope; home_screen.dart feeds them live provider data.
library;

import 'package:flutter/material.dart';

import '../../core/amal_engine.dart' show amalPoints;
import '../../core/bn_digits.dart';
import '../../core/most_used.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../l10n/app_strings.dart';
import '../../models/domain.dart';
import '../shared/widgets.dart';

// ── Countdown ring hero ──────────────────────────────────────────────────────

/// One fard prayer's state for the prayer card's today strip.
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

// ── Most-used amals ──────────────────────────────────────────────────────────

/// The সর্বাধিক ব্যবহৃত list (2026-10-07): ONE card, a row per amal — its
/// icon, the title, "গত ৩০ দিনে N দিন", and on the right either the আজ লিখুন
/// quick-log button or a quiet "আজ হয়েছে" once today's entry earns full
/// points. (The old side-scrolling 168-wide cards left half of each card
/// empty and slid under the contact button.)
class MostUsedList extends StatelessWidget {
  const MostUsedList({
    super.key,
    required this.items,
    required this.valueOf,
    required this.lang,
    required this.category,
    required this.onQuickLog,
  });

  final List<MostUsedAmal> items;

  /// Today's diary value for an amal key.
  final Object? Function(String amalKey) valueOf;
  final Lang lang;
  final UserCategory category;

  /// Receives the def and the quick-log VALUE computed by quickLogValue —
  /// the write itself stays in the screen so this widget stays
  /// catalog/test mountable.
  final void Function(AmalDefinition def, Object value) onQuickLog;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (i, item) in items.indexed) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16 + 40 + SLSpacing.s12,
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            MostUsedRow(
              item: item,
              currentValue: valueOf(item.def.key),
              lang: lang,
              category: category,
              onQuickLog: (v) => onQuickLog(item.def, v),
            ),
          ],
        ],
      ),
    );
  }
}

IconData amalCategoryIcon(AmalCategory c) => switch (c) {
  AmalCategory.salah => PhosphorIconsRegular.mosque,
  AmalCategory.quran => PhosphorIconsFill.bookOpenText,
  AmalCategory.dhikr => PhosphorIconsRegular.handHeart,
  AmalCategory.akhlaq => PhosphorIconsRegular.heart,
  AmalCategory.dawat => PhosphorIconsRegular.megaphone,
  AmalCategory.lifestyle => PhosphorIconsRegular.heartbeat,
  AmalCategory.sunnah => PhosphorIconsRegular.starAndCrescent,
  AmalCategory.personal => PhosphorIconsRegular.sparkle,
};

class MostUsedRow extends StatelessWidget {
  const MostUsedRow({
    super.key,
    required this.item,
    required this.currentValue,
    required this.lang,
    required this.onQuickLog,
    this.category = UserCategory.general,
  });

  final MostUsedAmal item;
  final Object? currentValue;
  final Lang lang;
  final UserCategory category;
  final void Function(Object value) onQuickLog;

  bool get bn => lang == Lang.bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final def = item.def;
    final title = bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn;
    final done =
        currentValue != null && amalPoints(currentValue, def, category) >= 1;
    final quickValue = done ? null : quickLogValue(def, currentValue);
    final goldInk = theme.brightness == Brightness.dark
        ? SLColors.darkGoldText
        : SLColors.lightGoldText;

    return Padding(
      key: ValueKey('most_used_card_${def.key}'),
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s16,
        vertical: SLSpacing.s12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              amalCategoryIcon(def.category),
              size: 20,
              color: cs.primary,
            ),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Icon(
                        PhosphorIconsFill.fire,
                        size: 14,
                        color: goldInk,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        S
                            .tr(lang, 'most_used_days_fmt')
                            .replaceAll(
                              '%n',
                              bn ? toBn(item.daysUsed) : '${item.daysUsed}',
                            ),
                        key: ValueKey('most_used_days_${def.key}'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          if (done)
            Semantics(
              key: ValueKey('most_used_done_${def.key}'),
              label: S.tr(lang, 'most_used_done'),
              child: Tooltip(
                message: S.tr(lang, 'most_used_done'),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsBold.check,
                    size: 18,
                    color: cs.onPrimary,
                  ),
                ),
              ),
            )
          else if (quickValue != null)
            FilledButton.tonal(
              key: ValueKey('most_used_log_${def.key}'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(44, SLSpacing.minTapTarget),
                padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s12),
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => onQuickLog(quickValue),
              child: Text(S.tr(lang, 'most_used_log_today')),
            ),
        ],
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
    // The prototype's tile: a tinted icon square on top, then the full name
    // and a one-line hint below. Side-by-side icon + text truncated the
    // names on a 360 dp phone ("সালাত পরবর্তী দো…").
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(SLSpacing.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: SLRadius.brMd,
            ),
            child: Icon(icon, size: 20, color: theme.colorScheme.primary),
          ),
          const SizedBox(height: SLSpacing.s8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
