/// মাসের গ্রিড — the 31-day paper-diary heatmap (rows = amals, columns =
/// days), month navigation, day-detail sheet, streaks, category rings and
/// the locking rule with 🔒 + "আনলক চাই".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
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

class MonthGridScreen extends ConsumerStatefulWidget {
  const MonthGridScreen({super.key});

  @override
  ConsumerState<MonthGridScreen> createState() => _MonthGridScreenState();
}

class _MonthGridScreenState extends ConsumerState<MonthGridScreen> {
  late String _anchor; // any date-key inside the shown month

  @override
  void initState() {
    super.initState();
    _anchor = dateKey(DateTime.now());
  }

  void _shiftMonth(int delta) {
    final d = parseKey(_anchor);
    setState(() {
      _anchor = dateKey(DateTime(d.year, d.month + delta, 1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final defsAsync = ref.watch(amalDefinitionsProvider);
    final amal = ref.watch(amalProvider);
    final profile = ref.watch(profileProvider);
    final today = dateKey(DateTime.now());
    final bn = context.isBn;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('amal_month')),
      ),
      body: defsAsync.when(
        loading: () => const Skeleton(height: 72, count: 6),
        error: (e, _) => ErrorState(
          message: '$e',
          onRetry: () => ref.invalidate(amalDefinitionsProvider),
        ),
        data: (defs) {
          if (defs.isEmpty) {
            return EmptyState(message: context.t('amal_no_defs'));
          }
          final days = monthDayKeys(_anchor);
          final entries = [
            for (final day in amal.entries.keys)
              for (final e in (amal.entries[day] ?? {}).values) e,
          ];
          final monthEntries = entries
              .where((e) => e.date.startsWith(_anchor.substring(0, 7)))
              .toList();
          final streak = currentStreak(entries, defs, profile.category, today);
          final byCat = completionByCategory(
            monthEntries,
            defs,
            profile.category,
            days.isEmpty ? today : days.last,
          );

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              // Month nav
              Row(
                children: [
                  IconButton(
                    tooltip: context.t('month_prev'),
                    onPressed: () => _shiftMonth(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthLabel(bn),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('month_next'),
                    onPressed: () => _shiftMonth(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: SLSpacing.s8),
              Row(
                children: [
                  StreakBadge(days: streak, bengali: bn),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: SizedBox(
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
                                label: cat.labelBn,
                                bengali: bn,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SLSpacing.s12),
              MonthHeatmap(
                defs: defs,
                entries: entries,
                days: days,
                today: today,
                profile: profile,
                bengali: bn,
              ),
              const SizedBox(height: SLSpacing.s8),
              Text(
                context.t('amal_locked_msg'),
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

  String _monthLabel(bool bn) {
    final d = parseKey(_anchor);
    final y = bn ? toBn(d.year) : '${d.year}';
    final m = bn ? gregMonthsBn[d.month - 1] : _gregMonthsEn[d.month - 1];
    return '$m $y';
  }
}

const List<String> _gregMonthsEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// The reusable heatmap widget (public — also exercised by widget tests):
/// day-number header row + one row per amal, horizontally scrollable, with a
/// fixed label column. 22px cells, paper-diary look.
class MonthHeatmap extends ConsumerWidget {
  const MonthHeatmap({
    super.key,
    required this.defs,
    required this.entries,
    required this.days,
    required this.today,
    required this.profile,
    this.bengali = true,
    this.onDayTap,
  });

  final List<AmalDefinition> defs;
  final List<AmalEntry> entries;
  final List<String> days;
  final String today;
  final ProfileState profile;
  final bool bengali;
  final void Function(String day)? onDayTap;

  static const double cellSize = 22.0;
  static const double cellStride = 24.0; // cell + 2px margins
  static const double headerHeight = 22.0;
  static const double labelWidth = 128.0;

  AmalEntry? _entryFor(String day, String amalKey) {
    for (final e in entries) {
      if (e.date == day && e.amalKey == amalKey) return e;
    }
    return null;
  }

  bool _isLocked(String day) =>
      day != today &&
      isDateLocked(
        day,
        DateTime.now(),
        lat: profile.lat,
        lng: profile.lng,
        tz: profile.tz,
        method: profile.method,
        madhhab: profile.madhhab,
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final rows = defs.length;
    final gridHeight = rows * cellStride + headerHeight + 4;

    Widget dayColumn(String day) {
      final isToday = day == today;
      final locked = _isLocked(day);
      return SizedBox(
        width: cellStride,
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Center(
                child: Text(
                  bengali
                      ? toBn(int.parse(day.substring(8)))
                      : day.substring(8),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 9,
                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w500,
                    color: isToday
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
            for (final def in defs)
              HeatmapCell(
                points: cellPoints(
                  _entryFor(day, def.key)?.value,
                  def,
                  profile.category,
                ),
                locked: locked,
                isToday: isToday,
                onTap: () => _openDay(context, ref, day),
              ),
            const SizedBox(height: 4),
          ],
        ),
      );
    }

    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Fixed label column
          SizedBox(
            width: labelWidth,
            child: Column(
              children: [
                const SizedBox(height: headerHeight),
                for (final def in defs)
                  SizedBox(
                    height: cellStride,
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(end: 6),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          bengali || def.titleBn.isNotEmpty
                              ? def.titleBn
                              : def.titleEn,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
              ],
            ),
          ),
          // Scrollable day columns
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, i) => dayColumn(days[i]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDay(BuildContext context, WidgetRef ref, String day) async {
    final theme = Theme.of(context);
    final locked = _isLocked(day);
    final dayEntries = <(AmalDefinition, AmalEntry?, double)>[
      for (final def in defs)
        (
          def,
          _entryFor(day, def.key),
          cellPoints(_entryFor(day, def.key)?.value, def, profile.category),
        ),
    ];
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        builder: (context, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            0,
            SLSpacing.s16,
            SLSpacing.s24,
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.isBn ? toBn(day) : day,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                if (locked)
                  Chip(
                    avatar: const Icon(Icons.lock, size: 14),
                    label: Text(context.t('amal_locked')),
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: SLSpacing.s8),
            for (final (def, entry, points) in dayEntries)
              ListTile(
                dense: true,
                title: Text(def.titleBn, style: theme.textTheme.bodyMedium),
                subtitle: entry == null
                    ? null
                    : Text(
                        '${_valueLabel(entry.value, def)} · ${entry.source}',
                        style: theme.textTheme.bodySmall,
                      ),
                trailing: _PointsDot(points: points),
              ),
            if (locked) ...[
              const SizedBox(height: SLSpacing.s12),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open),
                label: Text(context.t('amal_unlock_request')),
                onPressed: () => _requestUnlock(context, ref, day),
              ),
              const SizedBox(height: SLSpacing.s8),
            ],
          ],
        ),
      ),
    );
  }

  String _valueLabel(Object? value, AmalDefinition def) => switch (value) {
    'jamaat' => 'জামাতে',
    'alone' => 'একা',
    'qaza' => 'কাযা',
    true => 'হয়েছে',
    false => 'হয়নি',
    num n => '${bengali ? toBn(n) : n} ${def.unit ?? ''}',
    String s => s,
    _ => '—',
  };

  Future<void> _requestUnlock(
    BuildContext context,
    WidgetRef ref,
    String day,
  ) async {
    final auth = ref.read(authProvider);
    final user = auth.userOrNull;
    if (user == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('dawah_signin_needed'))),
        );
      }
      return;
    }
    try {
      await ref
          .read(apiProvider)
          .amalUnlock(user.id, day, reason: 'মোবাইল অ্যাপ থেকে অনুরোধ');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('amal_unlock_requested'))),
        );
        Navigator.of(context).pop();
      }
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _PointsDot extends StatelessWidget {
  const _PointsDot({required this.points});
  final double points;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = points >= 1
        ? theme.colorScheme.primary
        : points > 0
        ? theme.colorScheme.tertiary
        : theme.colorScheme.outline;
    return Icon(Icons.circle, size: 12, color: color);
  }
}
