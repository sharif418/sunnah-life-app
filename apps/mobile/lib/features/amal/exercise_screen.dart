/// শরীরচর্চা — the exercise log (AMOL-14).
///
/// A session (হাঁটা, দৌড়, সাইকেল …, minutes) ADDS to the day's diary amal
/// `exercise_minutes`, so it syncs, counts in the review and the month grid
/// like any diary entry — the log is not a second source of truth. The
/// per-session detail (type, time) stays on this phone (SharedPreferences,
/// last 14 days) to show today's list and let a mistaken session be undone.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../state/amal_state.dart';
import '../shared/widgets.dart';

/// The diary amal the log feeds.
const String kExerciseAmalKey = 'exercise_minutes';

/// Daily target when the catalog has none (the catalog says 20).
const int kExerciseDailyTarget = 20;

/// WHO: at least 150 minutes of moderate activity a week.
const int kExerciseWeeklyTarget = 150;

const String kExerciseSessionsPref = 'exercise_sessions_v1';

/// The kinds of exercise, in the order the chips show them.
const List<(String, IconData)> kExerciseTypes = [
  ('walk', PhosphorIconsRegular.personSimpleWalk),
  ('run', PhosphorIconsRegular.personSimpleRun),
  ('bike', PhosphorIconsRegular.personSimpleBike),
  ('workout', PhosphorIconsRegular.barbell),
  ('sport', PhosphorIconsRegular.soccerBall),
  ('swim', PhosphorIconsRegular.personSimpleSwim),
  ('other', PhosphorIconsRegular.dotsThreeOutline),
];

IconData exerciseIcon(String type) => kExerciseTypes
    .firstWhere((t) => t.$1 == type, orElse: () => kExerciseTypes.last)
    .$2;

class ExerciseSession {
  const ExerciseSession({
    required this.type,
    required this.minutes,
    required this.at,
  });
  final String type;
  final int minutes;
  final DateTime at;

  Map<String, Object> toJson() => {
    't': type,
    'm': minutes,
    'at': at.toIso8601String(),
  };

  static ExerciseSession? fromJson(Object? j) {
    if (j is! Map) return null;
    final m = j['m'];
    final at = DateTime.tryParse('${j['at']}');
    if (m is! num || at == null) return null;
    return ExerciseSession(type: '${j['t']}', minutes: m.toInt(), at: at);
  }
}

/// date → that day's sessions. Pure (de)serialisation, unit-tested.
Map<String, List<ExerciseSession>> decodeExerciseSessions(String? raw) {
  if (raw == null || raw.isEmpty) return {};
  try {
    final j = jsonDecode(raw);
    if (j is! Map) return {};
    return {
      for (final e in j.entries)
        '${e.key}': [
          for (final s in (e.value is List ? e.value as List : const []))
            ExerciseSession.fromJson(s),
        ].whereType<ExerciseSession>().toList(),
    };
  } on FormatException {
    return {};
  }
}

/// Keeps the last [keepDays] days only (the phone is not an archive — the
/// minutes themselves live in the diary).
String encodeExerciseSessions(
  Map<String, List<ExerciseSession>> byDate,
  String today, {
  int keepDays = 14,
}) {
  final from = addDays(today, -(keepDays - 1));
  return jsonEncode({
    for (final e in byDate.entries)
      if (e.key.compareTo(from) >= 0 && e.value.isNotEmpty)
        e.key: [for (final s in e.value) s.toJson()],
  });
}

/// The diary value as whole minutes (quantity entries may be num/string).
int exerciseMinutesOf(Object? value) {
  if (value is num) return value.round();
  if (value is String) return num.tryParse(value)?.round() ?? 0;
  return 0;
}

class ExerciseScreen extends ConsumerStatefulWidget {
  const ExerciseScreen({super.key});

  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  Map<String, List<ExerciseSession>> _sessions = {};
  String _type = 'walk';
  int _minutes = 20;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(
      () => _sessions = decodeExerciseSessions(
        prefs.getString(kExerciseSessionsPref),
      ),
    );
  }

  Future<void> _persist(String today) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kExerciseSessionsPref,
      encodeExerciseSessions(_sessions, today),
    );
  }

  /// Adds [delta] minutes (negative to undo) to today's diary entry.
  Future<bool> _addToDiary(String today, int delta) async {
    final current = exerciseMinutesOf(
      ref.read(amalProvider).entries[today]?[kExerciseAmalKey]?.value,
    );
    final next = (current + delta).clamp(0, 24 * 60);
    final locked = await ref
        .read(amalProvider.notifier)
        .write(kExerciseAmalKey, today, next, 'exercise');
    if (locked != null && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(locked)));
      return false;
    }
    return true;
  }

  Future<void> _addSession(String today) async {
    if (_minutes <= 0 || _saving) return;
    setState(() => _saving = true);
    final ok = await _addToDiary(today, _minutes);
    if (ok) {
      final session = ExerciseSession(
        type: _type,
        minutes: _minutes,
        at: DateTime.now(),
      );
      setState(
        () => _sessions = {
          ..._sessions,
          today: [...?_sessions[today], session],
        },
      );
      await _persist(today);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.t('exercise_type_$_type')} · '
              '${_n(_minutes)} ${context.t('exercise_min')} — '
              '${context.t('exercise_saved')}',
            ),
          ),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _undo(String today, int index) async {
    final list = [...?_sessions[today]];
    if (index >= list.length) return;
    final removed = list.removeAt(index);
    final ok = await _addToDiary(today, -removed.minutes);
    if (!ok) return;
    setState(() => _sessions = {..._sessions, today: list});
    await _persist(today);
  }

  String _n(int v) => context.isBn ? toBn(v) : '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final amal = ref.watch(amalProvider);
    final today = dateKey(DateTime.now());
    int minutesOn(String day) =>
        exerciseMinutesOf(amal.entries[day]?[kExerciseAmalKey]?.value);
    final todayMin = minutesOn(today);
    final week = [for (var i = 6; i >= 0; i--) addDays(today, -i)];
    final weekTotal = week.fold<int>(0, (a, d) => a + minutesOn(d));
    final weekMax = week
        .map(minutesOn)
        .fold<int>(kExerciseDailyTarget, (a, b) => b > a ? b : a);
    final todaySessions = _sessions[today] ?? const <ExerciseSession>[];
    final reached = todayMin >= kExerciseDailyTarget;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('exercise_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          // ── today ────────────────────────────────────────────────────
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('exercise_today'),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _n(todayMin),
                      key: const ValueKey('exercise_today_minutes'),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: cs.primary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Text(
                      '/ ${_n(kExerciseDailyTarget)} ${context.t('exercise_min')}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s12),
                ClipRRect(
                  borderRadius: SLRadius.brPill,
                  child: LinearProgressIndicator(
                    value: (todayMin / kExerciseDailyTarget).clamp(0, 1),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  reached
                      ? context.t('exercise_goal_done')
                      : '${context.t('exercise_more')} ${_n(kExerciseDailyTarget - todayMin)} '
                            '${context.t('exercise_min')}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: reached ? SLColors.success : cs.onSurfaceVariant,
                    fontWeight: reached ? FontWeight.w600 : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // ── log a session ────────────────────────────────────────────
          SectionHeader(
            context.t('exercise_add'),
            icon: PhosphorIconsRegular.heartbeat,
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: SLSpacing.s8,
                  runSpacing: SLSpacing.s8,
                  children: [
                    for (final (type, icon) in kExerciseTypes)
                      ChoiceChip(
                        key: ValueKey('exercise_type_$type'),
                        avatar: Icon(icon, size: 18),
                        label: Text(context.t('exercise_type_$type')),
                        selected: _type == type,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _type = type),
                      ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s16),
                Row(
                  children: [
                    IconButton.outlined(
                      tooltip: context.t('exercise_less'),
                      onPressed: _minutes > 5
                          ? () => setState(() => _minutes -= 5)
                          : null,
                      icon: const Icon(PhosphorIconsRegular.minus),
                    ),
                    Expanded(
                      child: Text(
                        '${_n(_minutes)} ${context.t('exercise_min')}',
                        key: const ValueKey('exercise_minutes_value'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton.outlined(
                      tooltip: context.t('exercise_more_btn'),
                      onPressed: _minutes < 240
                          ? () => setState(() => _minutes += 5)
                          : null,
                      icon: const Icon(PhosphorIconsRegular.plus),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: SLSpacing.s8,
                  children: [
                    for (final m in const [10, 15, 20, 30, 45, 60])
                      ChoiceChip(
                        label: Text(_n(m)),
                        selected: _minutes == m,
                        showCheckmark: false,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const ValueKey('exercise_add_button'),
                    onPressed: _saving ? null : () => _addSession(today),
                    icon: const Icon(PhosphorIconsRegular.plus),
                    label: Text(context.t('exercise_add_button')),
                  ),
                ),
              ],
            ),
          ),

          // ── today's sessions ─────────────────────────────────────────
          if (todaySessions.isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s16),
            SectionHeader(context.t('exercise_sessions_today')),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < todaySessions.length; i++)
                    ListTile(
                      leading: Icon(
                        exerciseIcon(todaySessions[i].type),
                        color: cs.primary,
                      ),
                      title: Text(
                        context.t('exercise_type_${todaySessions[i].type}'),
                      ),
                      subtitle: Text(
                        '${_n(todaySessions[i].minutes)} ${context.t('exercise_min')} · '
                        '${_clock(todaySessions[i].at)}',
                      ),
                      trailing: IconButton(
                        tooltip: context.t('exercise_undo'),
                        onPressed: () => _undo(today, i),
                        icon: const Icon(PhosphorIconsRegular.x),
                      ),
                    ),
                ],
              ),
            ),
          ],

          // ── last 7 days ──────────────────────────────────────────────
          const SizedBox(height: SLSpacing.s16),
          SectionHeader(context.t('exercise_week')),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // a week of zeros drew 90px of white over flat stubs — say
                // it in a line instead
                if (weekTotal == 0)
                  Row(
                    key: const ValueKey('exercise_week_empty'),
                    children: [
                      Icon(
                        PhosphorIconsRegular.personSimpleRun,
                        size: 22,
                        color: cs.primary,
                      ),
                      const SizedBox(width: SLSpacing.s12),
                      Expanded(
                        child: Text(
                          context.t('exercise_week_empty'),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  SizedBox(
                    height: 132,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final day in week)
                          Expanded(
                            child: _DayBar(
                              label: context.t(
                                'weekday_short_${parseKey(day).weekday % 7}',
                              ),
                              value: _n(minutesOn(day)),
                              fraction: minutesOn(day) / weekMax,
                              reached: minutesOn(day) >= kExerciseDailyTarget,
                              today: day == today,
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: SLSpacing.s12),
                Text(
                  '${context.t('exercise_week_total')}: ${_n(weekTotal)} / '
                  '${_n(kExerciseWeeklyTarget)} ${context.t('exercise_min')}',
                  key: const ValueKey('exercise_week_total'),
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  context.t('exercise_week_note'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),
          Text(
            context.t('exercise_hadith'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s32),
        ],
      ),
    );
  }

  String _clock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return context.isBn ? toBn('$h:$m') : '$h:$m';
  }
}

class _DayBar extends StatelessWidget {
  const _DayBar({
    required this.label,
    required this.value,
    required this.fraction,
    required this.reached,
    required this.today,
  });
  final String label;
  final String value;
  final double fraction;
  final bool reached;
  final bool today;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Semantics(
      label: '$label $value',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(value, style: theme.textTheme.labelSmall),
            const SizedBox(height: 2),
            Flexible(
              child: FractionallySizedBox(
                heightFactor: fraction.clamp(0.04, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    // a day with nothing stays a quiet stub (gold = some)
                    color: reached
                        ? cs.primary
                        : fraction > 0
                        ? cs.tertiary
                        : cs.outline,
                    borderRadius: SLRadius.brSm,
                  ),
                ),
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: today ? FontWeight.w800 : FontWeight.w500,
                color: today ? cs.primary : cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
