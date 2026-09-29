/// আমল — Today view: the paper-diary Muhasaba screen. Definitions from the
/// API (signed in) with the bundled fallback for guests; grouped by
/// category; cadence-aware rows; optimistic writes + sync badge; streak +
/// completion rings; links to Month grid / Habit builder / Self-tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/amal_engine.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../db/database.dart' show CustomChecklistItem;
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/checklist_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider;
import '../shared/widgets.dart';
import '../shared/global_header.dart';
import 'amal_widgets.dart';

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
    final today = dateKey(DateTime.now());
    final bn = context.isBn;

    if (defs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: SLSpacing.s32),
          EmptyState(message: context.t('amal_no_defs'), icon: Icons.menu_book),
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
      padding: const EdgeInsets.fromLTRB(
        SLSpacing.s16,
        SLSpacing.s8,
        SLSpacing.s16,
        SLSpacing.s24,
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
                    formatDayHeaderBn(DateTime.now(), bengali: bn),
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
              avatar: const Icon(Icons.grid_view_outlined, size: 18),
              label: Text(context.t('amal_month')),
              onPressed: () => context.push('/amal/month'),
            ),
            ActionChip(
              avatar: const Icon(
                Icons.local_fire_department_outlined,
                size: 18,
              ),
              label: Text(context.t('amal_habit_builder')),
              onPressed: () => context.push('/amal/habit'),
            ),
            ActionChip(
              avatar: const Icon(Icons.quiz_outlined, size: 18),
              label: Text(context.t('amal_self_test')),
              onPressed: () => context.push('/amal/self-test'),
            ),
            // W4c: আমার লক্ষ্য — propose → head approval → status chips.
            ActionChip(
              avatar: const Icon(Icons.flag_outlined, size: 18),
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
                  Text(
                    '${context.t('amal_streak')}: ${bn ? toBn(streak) : streak} ${context.t('amal_days')}',
                    style: Theme.of(context).textTheme.bodyMedium,
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
        for (final groupKey in groups.keys) ...[
          SectionHeader(context.t(groupKey), icon: _groupIcon(groupKey)),
          for (final def in groups[groupKey]!)
            def.key == kTilawatMinutesKey &&
                    tilawatDays < TilawatBeginnerCard.rampDays
                ? _TilawatBeginnerRow(
                    def: def,
                    today: today,
                    bn: bn,
                    daysDone: tilawatDays,
                  )
                : _AmalRow(def: def, today: today, bn: bn),
          const SizedBox(height: SLSpacing.s4),
        ],

        // W4c: নিজের তালিকা — per-day custom checklist (local-only,
        // offline-first; no API surface by design).
        SectionHeader(context.t('checklist_title'), icon: Icons.checklist),
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
    'group_fard' => Icons.mosque_outlined,
    'group_salah_sunnah' => Icons.stars_outlined,
    'group_nafl' => Icons.wb_twilight_outlined,
    'cat_quran' => Icons.menu_book_outlined,
    'cat_dhikr' => Icons.spa_outlined,
    'cat_akhlaq' => Icons.volunteer_activism_outlined,
    'cat_dawat' => Icons.campaign_outlined,
    'cat_lifestyle' => Icons.bedtime_outlined,
    'cat_sunnah' => Icons.star_outline,
    _ => Icons.flag_outlined,
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
        unit: def.unit ?? '',
        daysDone: daysDone,
        bengali: bn,
        onChanged: (v) =>
            ref.read(amalProvider.notifier).write(def.key, today, v, 'manual'),
      ),
    );
  }
}

class _AmalRow extends ConsumerWidget {
  const _AmalRow({required this.def, required this.today, required this.bn});
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

    String subtitle = '';
    if (def.cadence != 'daily' && def.cadence != 'weekly:any') {
      subtitle = _cadenceLabel(def.cadence, context);
    } else if (def.inputType == AmalInputType.count ||
        def.inputType == AmalInputType.quantity) {
      final target = def.targetFor(profile.category);
      subtitle =
          '${context.t('target_label')}: ${bn ? toBn(target.toInt()) : target.toInt()} ${def.unit ?? ''}';
    }

    Widget control;
    switch (def.inputType) {
      case AmalInputType.tristate:
        control = TriStateChips(
          value: value is String ? value : null,
          labels: TriStateLabels(
            jamaat: context.t('amal_jamaat'),
            alone: context.t('amal_alone'),
            qaza: context.t('amal_qaza'),
          ),
          onChanged: (v) => notifier.write(def.key, today, v ?? '', 'manual'),
        );
      case AmalInputType.boolean:
        control = AmalToggle(
          value: value == true,
          onChanged: (v) => notifier.write(def.key, today, v, 'manual'),
          semanticsLabel: def.titleBn,
        );
      case AmalInputType.count:
        control = CountStepper(
          value: value is num ? value.toInt() : 0,
          target: def.targetFor(profile.category).toInt(),
          unit: def.unit ?? '',
          quickCount: _quickCount(def),
          bengali: bn,
          onChanged: (v) => notifier.write(def.key, today, v, 'manual'),
        );
      case AmalInputType.quantity:
        control = QuantityInput(
          value: value is num ? value.toDouble() : 0,
          target: def.targetFor(profile.category).toDouble(),
          unit: def.unit ?? '',
          bengali: bn,
          onChanged: (v) => notifier.write(def.key, today, v, 'manual'),
        );
      case AmalInputType.text:
        control = const SizedBox.shrink();
    }

    return AppCard(
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
                      bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn,
                      style: Theme.of(context).textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle.isNotEmpty)
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
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
                    Icons.auto_awesome,
                    size: 16,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          SizedBox(width: double.infinity, child: control),
        ],
      ),
    );
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
                icon: const Icon(Icons.add),
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
