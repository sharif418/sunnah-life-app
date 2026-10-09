/// অভ্যাস গড়ার চ্যালেঞ্জ — single-amal tracker + 7-day habit builder.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/amal_engine.dart';
import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';
import 'amal_widgets.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class HabitBuilderScreen extends ConsumerStatefulWidget {
  const HabitBuilderScreen({super.key});

  @override
  ConsumerState<HabitBuilderScreen> createState() => _HabitBuilderScreenState();
}

class _HabitBuilderScreenState extends ConsumerState<HabitBuilderScreen> {
  String? _selectedKey;
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final defsAsync = ref.watch(amalDefinitionsProvider);
    final amal = ref.watch(amalProvider);
    final profile = ref.watch(profileProvider);
    final today = dateKey(DateTime.now());
    final bn = context.isBn;
    final entries = [
      for (final day in amal.entries.keys)
        for (final e in (amal.entries[day] ?? {}).values) e,
    ];

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('amal_habit_builder')),
      ),
      body: defsAsync.when(
        loading: () => const Skeleton(height: 72, count: 4),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(amalDefinitionsProvider),
        ),
        data: (defs) {
          if (defs.isEmpty) {
            return EmptyState(message: context.t('amal_no_defs'));
          }
          final selected = defs.firstWhere(
            (d) => d.key == _selectedKey,
            orElse: () => defs.first,
          );
          final progress = habitProgress(
            selected.key,
            entries,
            selected,
            profile.category,
            today,
            days: _days,
          );
          final todayEntry = amal.entry(today, selected.key);
          final doneToday =
              todayEntry != null &&
              amalPoints(todayEntry.value, selected, profile.category) >= 1;
          final lastDays = List.generate(
            _days,
            (i) => addDays(today, -(_days - 1 - i)),
          );

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              Text(
                context.t('habit_pick'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: SLSpacing.s8),
              DropdownButtonFormField<String>(
                initialValue: selected.key,
                isExpanded: true,
                items: [
                  for (final d in defs)
                    DropdownMenuItem(value: d.key, child: Text(d.titleBn)),
                ],
                onChanged: (v) => setState(() => _selectedKey = v),
              ),
              const SizedBox(height: SLSpacing.s16),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 7,
                    label: Text(
                      '${bn ? toBn(7) : 7} ${context.t('amal_days')}',
                    ),
                  ),
                  ButtonSegment(
                    value: 21,
                    label: Text(
                      '${bn ? toBn(21) : 21} ${context.t('amal_days')}',
                    ),
                  ),
                  ButtonSegment(
                    value: 40,
                    label: Text(
                      '${bn ? toBn(40) : 40} ${context.t('amal_days')}',
                    ),
                  ),
                ],
                selected: {_days},
                onSelectionChanged: (s) => setState(() => _days = s.first),
              ),
              const SizedBox(height: SLSpacing.s16),
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            selected.titleBn,
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (progress.streak > 0)
                          StreakBadge(days: progress.streak, bengali: bn),
                      ],
                    ),
                    const SizedBox(height: SLSpacing.s8),
                    ClipRRect(
                      borderRadius: SLRadius.brPill,
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(
                          begin: 0,
                          end: progress.daysChecked / progress.daysTarget,
                        ),
                        duration: SLMotion.slow,
                        curve: SLMotion.standard,
                        builder: (context, v, _) =>
                            LinearProgressIndicator(value: v, minHeight: 10),
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      '${bn ? toBn(progress.daysChecked) : progress.daysChecked} / ${bn ? toBn(progress.daysTarget) : progress.daysTarget} ${context.t('amal_days')}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (final day in lastDays)
                          _DayDot(
                            day: day,
                            done: _dayDone(
                              entries,
                              selected,
                              profile.category,
                              day,
                              today,
                            ),
                            isToday: day == today,
                            bengali: bn,
                          ),
                      ],
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon: Icon(doneToday ? PhosphorIconsRegular.check : PhosphorIconsRegular.listChecks),
                        label: Text(
                          doneToday
                              ? context.t('all_set')
                              : context.t('habit_mark_today'),
                        ),
                        onPressed: doneToday
                            ? null
                            : () => _markToday(selected),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              Text(
                context.t('amal_habit_builder_desc'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _dayDone(
    List<AmalEntry> entries,
    AmalDefinition def,
    UserCategory category,
    String day,
    String today,
  ) {
    if (day == today) return false; // today handled by the button
    AmalEntry? found;
    for (final e in entries) {
      if (e.date == day && e.amalKey == def.key) found = e;
    }
    return found != null && amalPoints(found.value, def, category) >= 1;
  }

  Future<void> _markToday(AmalDefinition def) async {
    final today = dateKey(DateTime.now());
    Object value = switch (def.inputType) {
      AmalInputType.tristate => 'jamaat',
      AmalInputType.boolean => true,
      _ => def.targetFor(ref.read(profileProvider).category),
    };
    await ref
        .read(amalProvider.notifier)
        .write(def.key, today, value, 'manual');
    if (mounted) setState(() {});
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.day,
    required this.done,
    required this.isToday,
    required this.bengali,
  });
  final String day;
  final bool done;
  final bool isToday;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dayNum = int.parse(day.substring(8));
    return Semantics(
      label:
          '${bengali ? toBn(dayNum) : dayNum}${done ? ' · ${context.t('amal_done')}' : ''}',
      child: Column(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: done ? theme.colorScheme.primary : null,
              border: Border.all(
                color: isToday
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
                width: isToday ? 2 : 1,
              ),
            ),
            child: Center(
              child: done
                  // W4f dark pass — onPrimary (cream in light, near-black in
                  // dark), never raw Colors.white: the dark primary is a
                  // LIGHT green and white on it fails contrast.
                  ? Icon(
                      PhosphorIconsRegular.check,
                      size: 18,
                      color: theme.colorScheme.onPrimary,
                    )
                  : Text(
                      bengali ? toBn(dayNum) : '$dayNum',
                      style: theme.textTheme.bodySmall,
                    ),
            ),
          ),
          // the weekday under the date, so the ringed circle reads as
          // "today" and not "day ৭ of the challenge"
          const SizedBox(height: 4),
          Text(
            context.t('weekday_short_${parseKey(day).weekday % 7}'),
            style: theme.textTheme.labelSmall?.copyWith(
              color: isToday
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
