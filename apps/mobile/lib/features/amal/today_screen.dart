/// আমল — Today view: the paper-diary Muhasaba screen. Definitions from the
/// API (signed in) with the bundled fallback for guests; grouped by
/// category; cadence-aware rows; optimistic writes + sync badge; streak +
/// completion rings; links to Month grid / Habit builder / Self-tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/amal_engine.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../../db/database.dart' show CustomChecklistItem;
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/checklist_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider;
import '../shared/widgets.dart';
import '../shared/global_header.dart';
import 'amal_widgets.dart';
import '../../design/phosphor_icons.dart';

class AmalHubScreen extends ConsumerWidget {
  const AmalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defsAsync = ref.watch(amalDefinitionsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // C-W4a: the shared global header (logo, location, triple
            // calendar, notification/reminder/profile, sync badge).
            const GlobalHeader(),
            Expanded(
              child: defsAsync.when(
                loading: () => const Skeleton(height: 72, count: 6),
                error: (e, _) => ErrorState(
                  message: '$e',
                  onRetry: () => ref.invalidate(amalDefinitionsProvider),
                ),
                data: (defs) => _TodayView(defs: defs),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView({required this.defs});
  final List<AmalDefinition> defs;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final amal = ref.watch(amalProvider);
    final today = dateKey(ref.watch(headerNowProvider));
    final bn = context.isBn;

    if (defs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: SLSpacing.s32),
          EmptyState(message: context.t('amal_no_defs'), icon: PhosphorIconsRegular.bookOpen),
        ],
      );
    }

    final todayDefs = defs
        .where(
          (d) => isAmalDay(
            d,
            today,
            // C-W3g: user ±2 + admin config ±2 — ayyam-beez dates follow the
            // same effective adjustment as the rendered Hijri date bar.
            hijriAdjust: ref.watch(effectiveHijriAdjustProvider),
          ),
        )
        .toList();
    final entries = [
      for (final day in amal.entries.keys)
        for (final e in (amal.entries[day] ?? {}).values) e,
    ];
    final streak = currentStreak(entries, defs, profile.category, today);
    final completion = completionPct(
      entries.where((e) => e.date == today).toList(),
      todayDefs,
      profile.category,
      [today],
    );
    final byCat = completionByCategory(
      entries.where((e) => e.date == today).toList(),
      todayDefs,
      profile.category,
      today,
    );

    // Group for display preserving catalog order — W4c: the salah amals
    // split into ফরয / সালাতের সুন্নত / নফল presentation groups
    // (amalGroupKey); every other category keeps its own SectionHeader.
    final groups = <String, List<AmalDefinition>>{};
    for (final d in todayDefs) {
      groups.putIfAbsent(amalGroupKey(d), () => []).add(d);
    }
    // W4c: the tilawat beginner ramp counts days of tilawat-minutes history
    // LOCALLY from the diary entries — no backend involvement.
    final tilawatDays = tilawatMinutesDaysDone(entries);

    return ListView(
      // W5: scroll clear of the floating contact button (80dp) — it used
      // to cover the last rows.
      padding: const EdgeInsets.fromLTRB(
        SLSpacing.s16,
        SLSpacing.s8,
        SLSpacing.s16,
        kContactFabClearance,
      ),
      children: [
        // Header: date + streak + sync
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('amal_today'),
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatDayHeaderBn(ref.watch(headerNowProvider), bengali: bn),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            StreakBadge(days: streak, bengali: bn),
          ],
        ),

        // W4c: gender-scoped percentile band — compact card under the streak
        // header; hidden entirely while the flag is off / guest / 404.
        const LeaderboardBandCard(),
        const SizedBox(height: SLSpacing.s8),

        // Quick links
        Wrap(
          spacing: SLSpacing.s8,
          runSpacing: SLSpacing.s8,
          children: [
            ActionChip(
              avatar: const Icon(PhosphorIconsRegular.squaresFour, size: 18),
              label: Text(context.t('amal_month')),
              onPressed: () => context.push('/amal/month'),
            ),
            ActionChip(
              avatar: const Icon(
                PhosphorIconsFill.fire,
                size: 18,
              ),
              label: Text(context.t('amal_habit_builder')),
              onPressed: () => context.push('/amal/habit'),
            ),
            ActionChip(
              avatar: const Icon(PhosphorIconsRegular.question, size: 18),
              label: Text(context.t('amal_self_test')),
              onPressed: () => context.push('/amal/self-test'),
            ),
            // W4c: আমার লক্ষ্য — propose → head approval → status chips.
            ActionChip(
              avatar: const Icon(PhosphorIconsRegular.flagBanner, size: 18),
              label: Text(context.t('goals_title')),
              onPressed: () => context.push('/amal/goals'),
            ),
          ],
        ),
        const SizedBox(height: SLSpacing.s8),

        // Completion + rings
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.t('amal_completion'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          bn ? '${toBn(completion)}%' : '$completion%',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                        ),
                      ],
                    ),
                  ),
                  // V2: flexible + ellipsis — the long ধারাবাহিকতা label no
                  // longer overflows on narrow phones.
                  Flexible(
                    child: Text(
                      '${context.t('amal_streak')}: ${bn ? toBn(streak) : streak} ${context.t('amal_days')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SLSpacing.s8),
              SizedBox(
                height: 86,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final cat in byCat.keys)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(
                          end: SLSpacing.s12,
                        ),
                        child: CompletionRing(
                          pct: byCat[cat] ?? 0,
                          label: context.t(cat.labelKey),
                          bengali: bn,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: SLSpacing.s4),

        // Category sections (W4c group headers: ফরয / সালাতের সুন্নত / নফল / …)
        // V2 density: every non-tristate amal is a compact ONE-LINE row and
        // each category renders ONE card with dividers between rows — the
        // diary reads in one thumb-scroll. The salat tristate rows keep
        // their taller chips layout (they're good); the tilawat beginner
        // ramp keeps its own prominent card while active.
        for (final groupKey in groups.keys) ...[
          SectionHeader(context.t(groupKey), icon: _groupIcon(groupKey)),
          if (groups[groupKey]!.any(
            (d) =>
                d.key == kTilawatMinutesKey &&
                tilawatDays < TilawatBeginnerCard.rampDays,
          ))
            _TilawatBeginnerRow(
              def: groups[groupKey]!.firstWhere(
                (d) => d.key == kTilawatMinutesKey,
              ),
              today: today,
              bn: bn,
              daysDone: tilawatDays,
            ),
          if (groups[groupKey]!.any(
            (d) =>
                !(d.key == kTilawatMinutesKey &&
                    tilawatDays < TilawatBeginnerCard.rampDays),
          ))
            _AmalGroupCard(
              defs: groups[groupKey]!
                  .where(
                    (d) =>
                        !(d.key == kTilawatMinutesKey &&
                            tilawatDays < TilawatBeginnerCard.rampDays),
                  )
                  .toList(),
              today: today,
              bn: bn,
            ),
          const SizedBox(height: SLSpacing.s4),
        ],

        // W4c: নিজের তালিকা — per-day custom checklist (local-only,
        // offline-first; no API surface by design).
        SectionHeader(context.t('checklist_title'), icon: PhosphorIconsRegular.listChecks),
        _CustomChecklistSection(today: today, bn: bn),

        const SizedBox(height: SLSpacing.s8),
        Text(
          context.t('amal_locked_msg'),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  static IconData _groupIcon(String key) => switch (key) {
    'group_fard' => PhosphorIconsRegular.mosque,
    'group_salah_sunnah' => PhosphorIconsRegular.star,
    'group_nafl' => PhosphorIconsRegular.sunHorizon,
    'cat_quran' => PhosphorIconsRegular.bookOpen,
    'cat_dhikr' => PhosphorIconsRegular.plant,
    'cat_akhlaq' => PhosphorIconsRegular.handHeart,
    'cat_dawat' => PhosphorIconsRegular.megaphone,
    'cat_lifestyle' => PhosphorIconsRegular.moon,
    'cat_sunnah' => PhosphorIconsRegular.star,
    _ => PhosphorIconsRegular.flagBanner,
  };
}

/// W4c: the tilawat_minutes row while the user is inside the 7-day beginner
/// ramp — the শুরু card instead of the plain quantity row. Writes go through
/// the same optimistic amalProvider.write path.
class _TilawatBeginnerRow extends ConsumerWidget {
  const _TilawatBeginnerRow({
    required this.def,
    required this.today,
    required this.bn,
    required this.daysDone,
  });
  final AmalDefinition def;
  final String today;
  final bool bn;
  final int daysDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final value = ref.watch(amalProvider).entry(today, def.key)?.value;
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: TilawatBeginnerCard(
        title: bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn,
        value: value is num ? value.toDouble() : 0,
        target: def.targetFor(profile.category).toDouble(),
        unit: displayUnitFor(def, profile.category),
        daysDone: daysDone,
        bengali: bn,
        onChanged: (v) =>
            ref.read(amalProvider.notifier).write(def.key, today, v, 'manual'),
      ),
    );
  }
}

/// V2 density: ONE card per category — compact one-line rows (56–64 dp)
/// with dividers between them; the whole boolean row toggles on tap.
/// Tristate (salat fard) rows keep their taller chips layout inside the
/// same card; count/quantity rows carry their trailing control and stack
/// under the title when the row gets too narrow (360 dp phones).
class _AmalGroupCard extends ConsumerWidget {
  const _AmalGroupCard({
    required this.defs,
    required this.today,
    required this.bn,
  });
  final List<AmalDefinition> defs;
  final String today;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < defs.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16,
                endIndent: SLSpacing.s16,
                color: Theme.of(
                  context,
                ).dividerColor.withValues(alpha: 0.6),
              ),
            _AmalGroupRow(def: defs[i], today: today, bn: bn),
          ],
        ],
      ),
    );
  }
}

/// One row of the group card — dispatches by input type.
class _AmalGroupRow extends ConsumerWidget {
  const _AmalGroupRow({
    required this.def,
    required this.today,
    required this.bn,
  });
  final AmalDefinition def;
  final String today;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final amal = ref.watch(amalProvider);
    final entry = amal.entry(today, def.key);
    final value = entry?.value;
    final notifier = ref.read(amalProvider.notifier);
    final theme = Theme.of(context);

    final (title, hint) = _titleAndHint(context, def, profile.category);

    switch (def.inputType) {
      case AmalInputType.tristate:
        // The salat rows keep their layout: title line, chips below.
        return Padding(
          key: ValueKey('amal_row_${def.key}'),
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s12,
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
                        Text(
                          title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (hint.isNotEmpty)
                          Text(
                            hint,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (entry?.source.startsWith('auto:') ?? false)
                    Tooltip(
                      message:
                          '${context.t('amal_auto_logged')} (${entry!.source})',
                      child: Icon(
                        PhosphorIconsRegular.sparkle,
                        size: 16,
                        color: theme.colorScheme.tertiary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: SLSpacing.s8),
              TriStateChips(
                value: value is String ? value : null,
                labels: TriStateLabels(
                  jamaat: context.t('amal_jamaat'),
                  alone: context.t('amal_alone'),
                  qaza: context.t('amal_qaza'),
                ),
                onChanged: (v) =>
                    notifier.write(def.key, today, v ?? '', 'manual'),
              ),
            ],
          ),
        );

      case AmalInputType.boolean:
        // Compact one-line row — the WHOLE row toggles (one-thumb diary).
        return Semantics(
          toggled: value == true,
          button: true,
          label: title,
          child: InkWell(
            key: ValueKey('amal_row_${def.key}'),
            onTap: () {
              HapticFeedback.selectionClick();
              notifier.write(def.key, today, value != true, 'manual');
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s4),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s12,
                    vertical: SLSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (hint.isNotEmpty)
                              Text(
                                hint,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      AmalToggle(
                        value: value == true,
                        onChanged: (v) =>
                            notifier.write(def.key, today, v, 'manual'),
                        semanticsLabel: def.titleBn,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );

      case AmalInputType.count:
        return _compactRow(
          context,
          title: title,
          hint: hint,
          auto: entry?.source.startsWith('auto:') ?? false,
          autoSource: entry?.source,
          control: CountStepper(
            value: value is num ? value.toInt() : 0,
            target: def.targetFor(profile.category).toInt(),
            unit: displayUnitFor(def, profile.category),
            quickCount: _quickCount(def),
            bengali: bn,
            onChanged: (v) => notifier.write(def.key, today, v, 'manual'),
          ),
        );

      case AmalInputType.quantity:
        return _compactRow(
          context,
          title: title,
          hint: hint,
          auto: entry?.source.startsWith('auto:') ?? false,
          autoSource: entry?.source,
          control: QuantityInput(
            value: value is num ? value.toDouble() : 0,
            target: def.targetFor(profile.category).toDouble(),
            unit: displayUnitFor(def, profile.category),
            bengali: bn,
            onChanged: (v) => notifier.write(def.key, today, v, 'manual'),
          ),
        );

      case AmalInputType.text:
        return const SizedBox.shrink();
    }
  }

  /// Adaptive compact row: control trails the title when there is room,
  /// stacks under it on narrow phones (360 dp + large text scales).
  Widget _compactRow(
    BuildContext context, {
    required String title,
    required String hint,
    required bool auto,
    required String? autoSource,
    required Widget control,
  }) {
    final theme = Theme.of(context);
    final titleColumn = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (auto) ...[
              const SizedBox(width: 4),
              Tooltip(
                message:
                    '${context.t('amal_auto_logged')} (${autoSource ?? ''})',
                child: Icon(
                  PhosphorIconsRegular.sparkle,
                  size: 16,
                  color: theme.colorScheme.tertiary,
                ),
              ),
            ],
          ],
        ),
        if (hint.isNotEmpty)
          Text(
            hint,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
      ],
    );

    return Padding(
      key: ValueKey('amal_row_${def.key}'),
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s16,
        vertical: SLSpacing.s8,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 340;
          if (stacked) {
            return ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  titleColumn,
                  const SizedBox(height: SLSpacing.s4),
                  control,
                ],
              ),
            );
          }
          return ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Row(
              children: [
                Expanded(child: titleColumn),
                const SizedBox(width: SLSpacing.s8),
                control,
              ],
            ),
          );
        },
      ),
    );
  }

  (String, String) _titleAndHint(
    BuildContext context,
    AmalDefinition def,
    UserCategory category,
  ) {
    final title = bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn;
    var subtitle = '';
    if (def.cadence != 'daily' && def.cadence != 'weekly:any') {
      subtitle = _cadenceLabel(def.cadence, context);
    } else if (def.inputType == AmalInputType.count ||
        def.inputType == AmalInputType.quantity) {
      final target = def.targetFor(category);
      subtitle =
          '${context.t('target_label')}: ${bn ? toBn(target.toInt()) : target.toInt()} ${displayUnitFor(def, category)}';
    }
    return (title, subtitle);
  }

  static int _quickCount(AmalDefinition def) {
    final t = def.targetFor(UserCategory.general).toInt();
    return t >= 100 ? 100 : (t > 0 ? t : 100);
  }

  static String _cadenceLabel(String cadence, BuildContext context) =>
      switch (cadence) {
        'weekly:fri' => context.t('cadence_weekly_fri'),
        'weekly:mon_thu' => context.t('cadence_weekly_mon_thu'),
        'monthly:ayyam_beez' => context.t('cadence_ayyam_beez'),
        _ => '',
      };
}

/// W4c: নিজের তালিকা — one day's custom checklist. Add-field + check-off
/// rows + delete on long-press; per-day filtering by dateKey (only today's
/// items ever render here). Rows carry the 44dp minimum tap target.
class _CustomChecklistSection extends ConsumerStatefulWidget {
  const _CustomChecklistSection({required this.today, required this.bn});
  final String today;
  final bool bn;

  @override
  ConsumerState<_CustomChecklistSection> createState() =>
      _CustomChecklistSectionState();
}

class _CustomChecklistSectionState extends ConsumerState<_CustomChecklistSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    _controller.clear();
    await ref.read(checklistProvider.notifier).add(title);
  }

  Future<void> _confirmRemove(
    BuildContext context,
    CustomChecklistItem item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        content: Text(dialogContext.t('checklist_remove_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(dialogContext.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(dialogContext.t('checklist_remove')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(checklistProvider.notifier).remove(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final notifier = ref.read(checklistProvider.notifier);
    final items = ref.watch(
      checklistProvider.select((s) => s[widget.today] ?? const []),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('checklist_add_field'),
                  controller: _controller,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _add(),
                  decoration: InputDecoration(
                    hintText: context.t('checklist_hint'),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: SLSpacing.s8),
              IconButton.filledTonal(
                key: const ValueKey('checklist_add_button'),
                tooltip: context.t('checklist_add'),
                icon: const Icon(PhosphorIconsRegular.plus),
                onPressed: _add,
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          for (final item in items)
            Semantics(
              button: true,
              toggled: item.done,
              label: item.title,
              child: InkWell(
                key: ValueKey('checklist_item_${item.id}'),
                onTap: () => notifier.toggle(item),
                onLongPress: () => _confirmRemove(context, item),
                borderRadius: SLRadius.brMd,
                child: SizedBox(
                  height: SLSpacing.minTapTarget,
                  child: Row(
                    children: [
                      Checkbox(
                        value: item.done,
                        onChanged: (_) => notifier.toggle(item),
                      ),
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: item.done
                                ? theme.colorScheme.onSurfaceVariant
                                : theme.colorScheme.onSurface,
                            decoration: item.done
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('checklist_local_note'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
