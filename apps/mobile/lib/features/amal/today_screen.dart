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
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'amal_widgets.dart';

class AmalHubScreen extends ConsumerWidget {
  const AmalHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final defsAsync = ref.watch(amalDefinitionsProvider);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: defsAsync.when(
          loading: () => const Skeleton(height: 72, count: 6),
          error: (e, _) => ErrorState(
            message: '$e',
            onRetry: () => ref.invalidate(amalDefinitionsProvider),
          ),
          data: (defs) => _TodayView(defs: defs),
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
        .where((d) => isAmalDay(d, today, hijriAdjust: profile.hijriAdjust))
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

    // Group by category preserving catalog order.
    final groups = <AmalCategory, List<AmalDefinition>>{};
    for (final d in todayDefs) {
      groups.putIfAbsent(d.category, () => []).add(d);
    }

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
            const SizedBox(width: SLSpacing.s8),
            SyncBadge(),
          ],
        ),
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

        // Category sections
        for (final cat in groups.keys) ...[
          SectionHeader(context.t(cat.labelKey), icon: _categoryIcon(cat)),
          for (final def in groups[cat]!)
            _AmalRow(def: def, today: today, bn: bn),
          const SizedBox(height: SLSpacing.s4),
        ],

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

  static IconData _categoryIcon(AmalCategory cat) => switch (cat) {
    AmalCategory.salah => Icons.mosque_outlined,
    AmalCategory.quran => Icons.menu_book_outlined,
    AmalCategory.dhikr => Icons.spa_outlined,
    AmalCategory.akhlaq => Icons.volunteer_activism_outlined,
    AmalCategory.dawat => Icons.campaign_outlined,
    AmalCategory.lifestyle => Icons.bedtime_outlined,
    AmalCategory.sunnah => Icons.star_outline,
    AmalCategory.personal => Icons.flag_outlined,
  };
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
