/// আযকার — morning, evening and after-salah adhkar with per-item repetition
/// counters and the auto-tick into the amal diary.
///
/// Reworked 2026-10-09 after the phone test ("tapping feels wrong"):
/// - the pack is loaded ONCE (a fresh future per build flashed the skeleton
///   and threw the reader back to the top on every tap);
/// - one tab per period, opening on the one due now (morning Fajr–Dhuhr,
///   after-salah Dhuhr–Asr, evening from Asr); `focus`
///   (/ilm/adhkar?set=post_salat) still opens straight onto one period;
/// - counts survive leaving the screen — kept per day, cleared at midnight;
/// - long-press takes one count back, each set can be reset;
/// - finishing a dhikr moves on to the next; the reference and the virtue
///   (ফযীলত) are shown;
/// - the diary row says "কমপক্ষে ৫ টি": morning/evening tick once five
///   dhikr are complete (after-salah: the whole set), written with the
///   catalog's auto source (`auto:adhkar:<period>`).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/content_models.dart';
import '../../state/amal_state.dart';
import '../../state/prayer_state.dart';
import '../shared/widgets.dart';

/// The adhkar periods: (period in the pack, title key, diary amal key).
const _periods = [
  ('morning', 'adhkar_morning', 'adhkar_morning'),
  ('evening', 'adhkar_evening', 'adhkar_evening'),
  ('post_salat', 'adhkar_post_salat', 'post_salat_tasbih'),
];

/// Dhikr done before morning/evening counts as done in the diary — the
/// paper row reads "কমপক্ষে ৫ টি".
const kAdhkarDiaryMinimum = 5;

const _prefsKey = 'adhkar_counts_v1';

/// The period due at [minutes] (minutes after midnight) given the day's
/// prayer times: morning Fajr–Dhuhr, after-salah Dhuhr–Asr, evening from
/// Asr through the night.
String adhkarPeriodAt(
  double minutes, {
  required double fajr,
  required double dhuhr,
  required double asr,
}) {
  if (minutes >= fajr && minutes < dhuhr) return 'morning';
  if (minutes >= dhuhr && minutes < asr) return 'post_salat';
  return 'evening';
}

class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key, this.focus});

  /// A set period to show alone (e.g. 'post_salat'); null shows the tabs.
  final String? focus;

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<DhikrSet>> _future = ContentPack.adhkar();

  /// `<set id>:<item id>` → count, for [_day].
  final Map<String, int> _counts = <String, int>{};
  String _day = dateKey(DateTime.now());

  /// One key per dhikr, to bring the next one into view.
  final Map<String, GlobalKey> _itemKeys = {};

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map || j['day'] != _day) return; // a new day starts at 0
      final counts = j['counts'];
      if (counts is! Map || !mounted) return;
      setState(() {
        for (final e in counts.entries) {
          final v = e.value;
          if (v is num) _counts['${e.key}'] = v.toInt();
        }
      });
    } catch (_) {
      // storage unavailable — counting still works for this visit
    }
  }

  Future<void> _save() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode({'day': _day, 'counts': _counts}),
      );
    } catch (_) {}
  }

  /// Past midnight while the screen is open: yesterday's counts go.
  void _rollDay() {
    final today = dateKey(DateTime.now());
    if (today != _day) {
      _day = today;
      _counts.clear();
    }
  }

  int _countOf(DhikrSet set, DhikrItem item) =>
      _counts['${set.id}:${item.id}'] ?? 0;

  int _doneItems(DhikrSet set) =>
      set.items.where((i) => _countOf(set, i) >= i.count).length;

  GlobalKey _keyFor(DhikrSet set, DhikrItem item) =>
      _itemKeys.putIfAbsent('${set.id}:${item.id}', GlobalKey.new);

  void _tap(DhikrSet set, DhikrItem item, String period, String amalKey) {
    _rollDay();
    final current = _countOf(set, item);
    if (current >= item.count) return;
    final next = current + 1;
    final finished = next >= item.count;
    // a firmer buzz when a dhikr is complete (light taps are silent on many
    // low-end phones)
    finished ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick();
    setState(() => _counts['${set.id}:${item.id}'] = next);
    _save();
    if (!finished) return;

    // the diary tick: five for morning/evening, the whole set after salah
    final done = _doneItems(set);
    final needed = period == 'post_salat'
        ? set.items.length
        : (kAdhkarDiaryMinimum < set.items.length
              ? kAdhkarDiaryMinimum
              : set.items.length);
    if (done == needed) _tickAmal(amalKey, period);

    // move on to the next unfinished dhikr
    final i = set.items.indexOf(item);
    final nextItem = set.items
        .skip(i + 1)
        .where((x) => _countOf(set, x) < x.count)
        .firstOrNull;
    if (nextItem != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _keyFor(set, nextItem).currentContext;
        if (ctx != null && ctx.mounted) {
          Scrollable.ensureVisible(
            ctx,
            alignment: 0.08,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  void _undo(DhikrSet set, DhikrItem item) {
    _rollDay();
    final current = _countOf(set, item);
    if (current <= 0) return;
    HapticFeedback.selectionClick();
    setState(() => _counts['${set.id}:${item.id}'] = current - 1);
    _save();
  }

  Future<void> _reset(DhikrSet set) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.t('adhkar_reset_title')),
        content: Text(context.t('adhkar_reset_body')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.t('adhkar_reset')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      for (final i in set.items) {
        _counts.remove('${set.id}:${i.id}');
      }
    });
    _save();
  }

  Future<void> _tickAmal(String amalKey, String period) async {
    final today = dateKey(DateTime.now());
    if (ref.read(amalProvider).entries[today]?[amalKey]?.value == true) return;
    final err = await ref
        .read(amalProvider.notifier)
        .write(amalKey, today, true, 'auto:adhkar:$period');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(err ?? context.t('adhkar_diary_ticked'))),
    );
  }

  Widget _periodList(List<DhikrSet> sets, String period, String amalKey) {
    final bn = context.isBn;
    final list = sets.where((s) => s.period == period).toList();
    if (list.isEmpty) {
      return EmptyState(
        message: context.t('empty_generic'),
        icon: PhosphorIconsRegular.plant,
      );
    }
    final today = dateKey(DateTime.now());
    final ticked = ref.watch(
      amalProvider.select((s) => s.entries[today]?[amalKey]?.value == true),
    );
    return ListView(
      key: PageStorageKey('adhkar_$period'),
      padding: const EdgeInsets.fromLTRB(
        SLSpacing.s16,
        SLSpacing.s12,
        SLSpacing.s16,
        SLSpacing.s32,
      ),
      children: [
        // how to use it, once at the top
        Row(
          children: [
            Icon(
              PhosphorIconsRegular.handTap,
              size: 18,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: SLSpacing.s8),
            Expanded(
              child: Text(
                context.t('adhkar_hint'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: SLSpacing.s12),
        for (final set in list) ...[
          _DhikrSetCard(
            set: set,
            countOf: (i) => _countOf(set, i),
            doneItems: _doneItems(set),
            ticked: ticked,
            bengali: bn,
            keyFor: (i) => _keyFor(set, i),
            onTap: (i) => _tap(set, i, period, amalKey),
            onUndo: (i) => _undo(set, i),
            onReset: () => _reset(set),
          ),
          const SizedBox(height: SLSpacing.s12),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final focus = widget.focus;
    final known = _periods.any((p) => p.$1 == focus);
    final body = FutureBuilder<List<DhikrSet>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Skeleton(height: 80, count: 5);
        }
        final sets = snap.data ?? const <DhikrSet>[];
        if (sets.isEmpty) {
          return EmptyState(
            message: context.t('empty_generic'),
            icon: PhosphorIconsRegular.plant,
          );
        }
        if (focus != null && known) {
          final p = _periods.firstWhere((p) => p.$1 == focus);
          return _periodList(sets, p.$1, p.$3);
        }
        return TabBarView(
          children: [for (final p in _periods) _periodList(sets, p.$1, p.$3)],
        );
      },
    );

    if (focus != null && known) {
      final p = _periods.firstWhere((p) => p.$1 == focus);
      return Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(context.t(p.$2)),
        ),
        body: body,
      );
    }

    // open on the period due now
    final prayer = ref.read(prayerProvider);
    final due = prayer == null
        ? 'morning'
        : adhkarPeriodAt(
            prayer.nowMinutes,
            fajr: prayer.times.fajr,
            dhuhr: prayer.times.dhuhr,
            asr: prayer.times.asr,
          );
    return DefaultTabController(
      length: _periods.length,
      initialIndex: _periods.indexWhere((p) => p.$1 == due),
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(context.t('ilm_adhkar')),
          bottom: TabBar(
            tabs: [
              for (final p in _periods)
                // short tab names (the full set titles clipped in a tab)
                Tab(
                  key: ValueKey('adhkar_tab_${p.$1}'),
                  text: context.t('adhkar_tab_${p.$1}'),
                ),
            ],
          ),
        ),
        body: body,
      ),
    );
  }
}

class _DhikrSetCard extends StatelessWidget {
  const _DhikrSetCard({
    required this.set,
    required this.countOf,
    required this.doneItems,
    required this.ticked,
    required this.bengali,
    required this.keyFor,
    required this.onTap,
    required this.onUndo,
    required this.onReset,
  });
  final DhikrSet set;
  final int Function(DhikrItem) countOf;
  final int doneItems;
  final bool ticked;
  final bool bengali;
  final GlobalKey Function(DhikrItem) keyFor;
  final void Function(DhikrItem) onTap;
  final void Function(DhikrItem) onUndo;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    String n(int v) => bengali ? toBn(v) : '$v';
    final total = set.items.length;
    final allDone = doneItems == total;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      set.titleBn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        '${n(doneItems)}/${n(total)} ${context.t('adhkar_done_of')}',
                        if (set.totalMin != null)
                          context
                              .t('adhkar_minutes_fmt')
                              .replaceAll('%n', n(set.totalMin!)),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (doneItems > 0)
                IconButton(
                  key: ValueKey('adhkar_reset_${set.id}'),
                  tooltip: context.t('adhkar_reset'),
                  onPressed: onReset,
                  icon: Icon(
                    PhosphorIconsRegular.arrowCounterClockwise,
                    color: cs.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          ClipRRect(
            borderRadius: SLRadius.brPill,
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : doneItems / total,
              minHeight: 6,
              backgroundColor: cs.outline,
            ),
          ),
          if (ticked || allDone) ...[
            const SizedBox(height: SLSpacing.s8),
            Row(
              key: ValueKey('adhkar_ticked_${set.id}'),
              children: [
                Icon(
                  PhosphorIconsFill.checkCircle,
                  size: 18,
                  color: cs.primary,
                ),
                const SizedBox(width: SLSpacing.s4),
                Expanded(
                  child: Text(
                    context.t(
                      ticked ? 'adhkar_ticked_today' : 'adhkar_set_complete',
                    ),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          for (final item in set.items)
            Padding(
              key: keyFor(item),
              padding: const EdgeInsets.only(top: SLSpacing.s12),
              child: _DhikrItemRow(
                key: ValueKey('dhikr_${item.id}'),
                item: item,
                count: countOf(item),
                bengali: bengali,
                onTap: () => onTap(item),
                onUndo: () => onUndo(item),
              ),
            ),
        ],
      ),
    );
  }
}

class _DhikrItemRow extends StatefulWidget {
  const _DhikrItemRow({
    super.key,
    required this.item,
    required this.count,
    required this.bengali,
    required this.onTap,
    required this.onUndo,
  });
  final DhikrItem item;
  final int count;
  final bool bengali;
  final VoidCallback onTap;
  final VoidCallback onUndo;

  @override
  State<_DhikrItemRow> createState() => _DhikrItemRowState();
}

class _DhikrItemRowState extends State<_DhikrItemRow> {
  bool _showVirtue = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final item = widget.item;
    final count = widget.count;
    final bengali = widget.bengali;
    String n(int v) => bengali ? toBn(v) : '$v';
    final done = count >= item.count;
    final progress = item.count <= 0 ? 1.0 : count / item.count;
    final virtue = item.virtue?.trim() ?? '';
    return Semantics(
      button: true,
      label: '${item.translationBn} — ${n(count)}/${n(item.count)}',
      hint: context.t('adhkar_hint'),
      child: InkWell(
        onTap: done ? null : widget.onTap,
        onLongPress: count > 0 ? widget.onUndo : null,
        borderRadius: SLRadius.brMd,
        child: Container(
          padding: const EdgeInsets.all(SLSpacing.s12),
          decoration: BoxDecoration(
            // the cream page ground, so each dhikr is its own tile on the
            // white card (surfaceContainerLow IS the card colour)
            color: done ? cs.primaryContainer : cs.surface,
            borderRadius: SLRadius.brMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                child: Text(
                  item.arabic,
                  style: SLType.dua(color: cs.onSurface),
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              // the reading aid most users lean on — body size, not a caption
              Text(
                item.translitBn,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: SLSpacing.s4),
              Text(item.translationBn, style: theme.textTheme.bodyMedium),
              if (item.reference.trim().isNotEmpty) ...[
                const SizedBox(height: SLSpacing.s4),
                Text(
                  '— ${item.reference}',
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
                ),
              ],
              if (virtue.isNotEmpty) ...[
                const SizedBox(height: SLSpacing.s4),
                InkWell(
                  onTap: () => setState(() => _showVirtue = !_showVirtue),
                  borderRadius: SLRadius.brSm,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsRegular.sparkle,
                          size: 16,
                          color: cs.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          context.t('dhikr_virtue'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Icon(
                          _showVirtue
                              ? PhosphorIconsBold.caretDown
                              : PhosphorIconsRegular.caretRight,
                          size: 14,
                          color: cs.primary,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_showVirtue)
                  Text(
                    virtue,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                  ),
              ],
              const SizedBox(height: SLSpacing.s8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: SLRadius.brPill,
                      child: LinearProgressIndicator(
                        value: progress.clamp(0, 1),
                        minHeight: 8,
                        backgroundColor: cs.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: SLSpacing.s12),
                  // the count as a pill: the whole tile is the tap target,
                  // the pill says so (a hand while counting, a tick when done)
                  Container(
                    constraints: const BoxConstraints(minHeight: 36),
                    padding: const EdgeInsets.symmetric(
                      horizontal: SLSpacing.s12,
                    ),
                    decoration: BoxDecoration(
                      color: done ? cs.primary : cs.primaryContainer,
                      borderRadius: SLRadius.brPill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          done
                              ? PhosphorIconsBold.check
                              : PhosphorIconsRegular.handTap,
                          size: 18,
                          color: done ? cs.onPrimary : cs.primary,
                        ),
                        const SizedBox(width: SLSpacing.s4),
                        Text(
                          '${n(count)} / ${n(item.count)}',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: done ? cs.onPrimary : cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
