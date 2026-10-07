/// C-W4b home section components — the prayer status of the card's today
/// strip, the most-used amal card and the quick-access tile (the prayer card
/// itself lives in sun_arc_card.dart since the 2026-10-07 redesign). PUBLIC + context-free (labels come
/// in via `S.tr(lang, key)` / plain strings) so the component catalog
/// (catalog_app.dart) and the widget tests can mount them without a
/// ProviderScope; home_screen.dart feeds them live provider data.
library;


import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../core/most_used.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../l10n/app_strings.dart';
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
