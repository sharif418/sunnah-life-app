/// মাসের গ্রিড — month navigation, streak + category rings, a 7-column
/// calendar (each day tinted by how much of the diary it holds — the
/// at-a-glance view a phone can show), and the full paper-style grid (rows
/// in the paper diary's order, then the extras; columns = days; it opens
/// scrolled to today). Tapping a day opens its detail sheet; a locked day
/// offers "আনলক চাই".
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../core/amal_engine.dart';
import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../core/diary_layout.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider;
import '../shared/widgets.dart';
import 'amal_widgets.dart';
import '../../design/phosphor_icons.dart';

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
                    // Mirrors under RTL (previous points "backwards").
                    icon: const DirectionalIcon(PhosphorIconsRegular.caretLeft),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        _monthLabel(context),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('month_next'),
                    onPressed: () => _shiftMonth(1),
                    icon: const DirectionalIcon(PhosphorIconsRegular.caretRight),
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
                                label: context.t(cat.labelKey),
                                bengali: bn,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: SLSpacing.s16),
              _MonthCalendar(
                days: days,
                today: today,
                defs: defs,
                entries: entries,
                profile: profile,
                hijriAdjust: ref.watch(effectiveHijriAdjustProvider),
                bengali: bn,
              ),
              const SizedBox(height: SLSpacing.s20),
              Text(
                context.t('month_paper_grid'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              MonthHeatmap(
                defs: () {
                  final (:paper, :extras) = layoutDiary(defs);
                  return [
                    for (final g in paper)
                      for (final r in g.rows) r.def,
                    ...extras,
                  ];
                }(),
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

  String _monthLabel(BuildContext context) {
    final d = parseKey(_anchor);
    final lang = context.lang;
    final y = lang.isBengali ? toBn(d.year) : '${d.year}';
    final m = S.tr(lang, 'month_${d.month}');
    return '$m $y';
  }
}

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

  static const double cellSize = 26.0;
  static const double cellStride = 28.0; // cell + 2px margins
  static const double headerHeight = 26.0;
  static const double labelWidth = 156.0;

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
                    fontSize: 11,
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
                semanticsLabel:
                    '${bengali ? toBn(int.parse(day.substring(8))) : day.substring(8)} · ${def.titleBn}',
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
                            fontSize: 12,
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
              // open on today (a few days of context to its left)
              controller: ScrollController(
                initialScrollOffset: () {
                  final i = days.indexOf(today);
                  return i <= 3 ? 0.0 : (i - 3) * cellStride;
                }(),
              ),
              scrollDirection: Axis.horizontal,
              itemCount: days.length,
              itemBuilder: (context, i) => dayColumn(days[i]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDay(BuildContext context, WidgetRef ref, String day) =>
      openDay(context, ref, day);

  /// The day-detail sheet (also opened from the calendar).
  Future<void> openDay(BuildContext context, WidgetRef ref, String day) async {
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
                    avatar: const Icon(PhosphorIconsRegular.lockSimple, size: 14),
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
                        '${_valueLabel(context, entry.value, def)} · ${entry.source}',
                        style: theme.textTheme.bodySmall,
                      ),
                trailing: _PointsDot(points: points),
              ),
            if (locked) ...[
              const SizedBox(height: SLSpacing.s12),
              FilledButton.icon(
                icon: const Icon(PhosphorIconsRegular.lockSimpleOpen),
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

  String _valueLabel(BuildContext context, Object? value, AmalDefinition def) =>
      switch (value) {
        'jamaat' => context.t('amal_jamaat'),
        'alone' => context.t('amal_alone'),
        'qaza' => context.t('amal_qaza'),
        true => context.t('amal_done'),
        false => context.t('amal_not_done'),
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
          .amalUnlock(
            user.id,
            day,
            reason: context.t('amal_unlock_reason'),
          );
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
    return Icon(PhosphorIconsFill.circle, size: 12, color: color);
  }
}

/// The month at a glance: weekday header + one tinted square per day —
/// empty, partial (gold) or full (green) by the share of that day's due
/// diary rows that carry an answer; today ringed, future days muted.
class _MonthCalendar extends ConsumerWidget {
  const _MonthCalendar({
    required this.days,
    required this.today,
    required this.defs,
    required this.entries,
    required this.profile,
    required this.hijriAdjust,
    required this.bengali,
  });
  final List<String> days;
  final String today;
  final List<AmalDefinition> defs;
  final List<AmalEntry> entries;
  final ProfileState profile;
  final int hijriAdjust;
  final bool bengali;

  double _share(String day) {
    final due = defs.where((d) => isAmalDay(d, day, hijriAdjust: hijriAdjust));
    var total = 0, sum = 0.0;
    for (final d in due) {
      total++;
      AmalEntry? e;
      for (final x in entries) {
        if (x.date == day && x.amalKey == d.key) {
          e = x;
          break;
        }
      }
      sum += cellPoints(e?.value, d, profile.category);
    }
    return total == 0 ? 0 : sum / total;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (days.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final first = parseKey(days.first);
    final lead = first.weekday % 7; // Sunday-first weeks (BD calendars)
    final heat = MonthHeatmap(
      defs: defs,
      entries: entries,
      days: days,
      today: today,
      profile: profile,
      bengali: bengali,
    );
    String n(int v) => bengali ? toBn(v) : '$v';
    final weekdays = [for (var i = 0; i < 7; i++) context.t('weekday_short_$i')];

    return Column(
      key: const ValueKey('month_calendar'),
      children: [
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: SLSpacing.s4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          children: [
            for (var i = 0; i < lead; i++) const SizedBox.shrink(),
            for (final day in days)
              () {
                final future = day.compareTo(today) > 0;
                final share = future ? 0.0 : _share(day);
                final (Color bg, Color fg) = future
                    ? (Colors.transparent, cs.onSurfaceVariant.withValues(alpha: 0.6))
                    : share >= 0.8
                    ? (cs.primary, cs.onPrimary)
                    : share > 0
                    ? (cs.tertiary.withValues(alpha: 0.35 + share * 0.5), cs.onSurface)
                    : (cs.outline, cs.onSurface);
                return InkWell(
                  key: ValueKey('month_day_$day'),
                  borderRadius: SLRadius.brSm,
                  onTap: future ? null : () => heat.openDay(context, ref, day),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: bg,
                      borderRadius: SLRadius.brSm,
                      border: day == today
                          ? Border.all(color: cs.primary, width: 2.5)
                          : null,
                    ),
                    child: Text(
                      n(int.parse(day.substring(8))),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg,
                        fontWeight: day == today ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }(),
          ],
        ),
        const SizedBox(height: SLSpacing.s8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final (c, key) in [
              (cs.outline, 'month_legend_none'),
              (cs.tertiary.withValues(alpha: 0.6), 'month_legend_some'),
              (cs.primary, 'month_legend_full'),
            ]) ...[
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(color: c, borderRadius: SLRadius.brSm),
              ),
              const SizedBox(width: 4),
              Text(context.t(key), style: theme.textTheme.bodySmall),
              const SizedBox(width: SLSpacing.s12),
            ],
          ],
        ),
      ],
    );
  }
}
