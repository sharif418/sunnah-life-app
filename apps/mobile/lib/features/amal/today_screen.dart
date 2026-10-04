/// আমল — Today view: the paper-diary Muhasaba screen. Definitions from the
/// API (signed in) with the bundled fallback for guests, laid out in the
/// PAPER diary's groups, order and wording (core/diary_layout.dart) with the
/// app's extra amals in a collapsible card; "এখন যা বাকি" on top; a fard
/// prayer's row opens when its waqt begins; optimistic writes + sync badge;
/// streak + progress ring; links to Month grid / Habit builder / Self-tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/amal_engine.dart';
import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
import '../../core/date_keys.dart';
import '../../core/prayer_engine.dart' show PrayerKey;
import '../../core/diary_layout.dart';
import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../../db/database.dart' show CustomChecklistItem;
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/checklist_state.dart';
import '../../state/prayer_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider;
import '../shared/widgets.dart';
import '../shared/global_header.dart';
import '../dawah/dawah_journey.dart' show LatestReviewCard, latestReviewFor;
import '../ilm/upcoming_quizzes.dart' show UpcomingQuizzesSection;
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
        // the shared header, hiding while scrolling down (BNAV-01)
        child: ScrollAwareHeader(
          body: defsAsync.when(
            loading: () => const Skeleton(height: 72, count: 6),
            error: (e, _) => ErrorState(
              message: '$e',
              onRetry: () => ref.invalidate(amalDefinitionsProvider),
            ),
            data: (defs) => _TodayView(defs: defs),
          ),
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
    final theme = Theme.of(context);

    if (defs.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: SLSpacing.s32),
          EmptyState(
            message: context.t('amal_no_defs'),
            icon: PhosphorIconsRegular.bookOpen,
          ),
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

    // The paper diary is the backbone: its groups, order and wording
    // (lib/core/diary_layout.dart); everything else the app tracks lives in
    // the collapsible অতিরিক্ত আমল card — nothing is dropped.
    final (:paper, :extras) = layoutDiary(todayDefs);
    bool isDone(AmalDefinition d) =>
        amalPoints(amal.entry(today, d.key)?.value, d, profile.category) >= 1;
    final paperRows = [for (final g in paper) ...g.rows];
    final doneCount = paperRows.where((r) => isDone(r.def)).length;
    final extrasDone = extras.where(isDone).length;

    // W4c: the tilawat beginner ramp counts days of tilawat-minutes history
    // LOCALLY from the diary entries — no backend involvement.
    final tilawatDays = tilawatMinutesDaysDone(entries);
    bool inRamp(AmalDefinition d) =>
        d.key == kTilawatMinutesKey &&
        tilawatDays < TilawatBeginnerCard.rampDays;

    String num(int n) => bn ? toBn(n) : '$n';

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
        // ── title + today's progress ring ─────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          context.t('diary_title'),
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      // the paper's নির্দেশনাবলী — an icon beside the title
                      // (its own row cost a whole line)
                      IconButton(
                        key: const ValueKey('diary_instructions_button'),
                        tooltip: context.t('diary_instructions'),
                        visualDensity: VisualDensity.compact,
                        onPressed: () => showDiaryInstructions(context),
                        icon: Icon(
                          PhosphorIconsRegular.info,
                          size: 20,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: SLSpacing.s8,
                    runSpacing: SLSpacing.s4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        formatDayHeaderBn(
                          ref.watch(headerNowProvider),
                          bengali: bn,
                        ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      StreakBadge(days: streak, bengali: bn),
                    ],
                  ),
                ],
              ),
            ),
            _DiaryRing(
              done: doneCount,
              total: paperRows.length,
              label: context
                  .t('diary_done_of')
                  .replaceAll('%done%', num(doneCount))
                  .replaceAll('%total%', num(paperRows.length)),
              text: '${num(doneCount)}/${num(paperRows.length)}',
            ),
          ],
        ),
        const SizedBox(height: SLSpacing.s12),

        // ── shortcuts: one swipeable row, never four stacked lines ────────
        SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final (icon, label, path) in [
                (PhosphorIconsRegular.squaresFour, 'amal_month', '/amal/month'),
                (PhosphorIconsFill.fire, 'amal_habit_builder', '/amal/habit'),
                (
                  PhosphorIconsRegular.question,
                  'amal_self_test',
                  '/amal/self-test',
                ),
                (PhosphorIconsRegular.flagBanner, 'goals_title', '/amal/goals'),
                // AMOL-15: the usrah's question board, for usrah members
                if (ref.watch(authProvider).userOrNull?.usrahId != null)
                  (PhosphorIconsRegular.chats, 'usrah_q_title', '/amal/questions'),
              ])
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: SLSpacing.s8),
                  child: ActionChip(
                    avatar: Icon(icon, size: 18),
                    label: Text(context.t(label)),
                    onPressed: () => context.push(path),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: SLSpacing.s12),

        // (the 'এখন যা বাকি' card repeated the salat rows below — Home's
        // muhasaba card carries what is due now)

        // AMOL-17: the next scheduled quiz (nothing when none is planned)
        const UpcomingQuizzesSection(limit: 1),

        // ── the paper diary, group by group ───────────────────────────────
        for (final group in paper) ...[
          _DiaryGroupHeader(
            title: group.titleBn,
            done: group.rows.where((r) => isDone(r.def)).length,
            total: group.rows.length,
            bn: bn,
          ),
          for (final row in group.rows.where((r) => inRamp(r.def)))
            _TilawatBeginnerRow(
              def: row.def,
              today: today,
              bn: bn,
              daysDone: tilawatDays,
            ),
          if (group.rows.any((r) => !inRamp(r.def)))
            _AmalGroupCard(
              rows: [
                for (final r in group.rows)
                  if (!inRamp(r.def)) r,
              ],
              today: today,
              bn: bn,
            ),
          const SizedBox(height: SLSpacing.s16),
        ],

        // the usrah head's latest weekly comment — feedback where the diary
        // is kept (plain members never saw these: the review tab is under
        // দাওয়াত, which they don't have)
        ...switch (latestReviewFor(ref)) {
          final review? => [
            LatestReviewCard(review: review),
            const SizedBox(height: SLSpacing.s16),
          ],
          _ => const <Widget>[],
        },

        // ── everything beyond the paper ───────────────────────────────────
        if (extras.isNotEmpty) ...[
          _ExtrasCard(
            rows: [for (final d in extras) DiaryRow(d, null)],
            subtitle: context
                .t('diary_extras_sub')
                .replaceAll('%done%', num(extrasDone))
                .replaceAll('%total%', num(extras.length)),
            today: today,
            bn: bn,
          ),
          const SizedBox(height: SLSpacing.s16),
        ],

        // W4c: নিজের তালিকা — per-day custom checklist (local-only,
        // offline-first; no API surface by design).
        SectionHeader(
          context.t('checklist_title'),
          icon: PhosphorIconsRegular.listChecks,
        ),
        _CustomChecklistSection(today: today, bn: bn),

        // W4c: gender-scoped percentile band — hidden entirely while the
        // flag is off / guest / 404.
        const LeaderboardBandCard(),
        const SizedBox(height: SLSpacing.s16),

        // privacy, stated where the data is entered
        Container(
          padding: const EdgeInsets.all(SLSpacing.s12),
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: SLRadius.brMd,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                PhosphorIconsRegular.shieldCheck,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  '${context.t('diary_privacy')} ${context.t('amal_locked_msg')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Today's progress over the paper rows — a small ring with "৯/২০".
class _DiaryRing extends StatelessWidget {
  const _DiaryRing({
    required this.done,
    required this.total,
    required this.label,
    required this.text,
  });
  final int done;
  final int total;
  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  strokeWidth: 6,
                  strokeCap: StrokeCap.round,
                  // the track is the BORDER token: visible in both themes
                  // (the old muted track vanished on the dark card)
                  backgroundColor: theme.colorScheme.outline,
                  color: theme.colorScheme.primary,
                ),
              ),
              FittedBox(
                child: Padding(
                  padding: const EdgeInsets.all(SLSpacing.s8),
                  child: Text(
                    text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A paper group's header: its name in the paper's wording + "৩/৫".
class _DiaryGroupHeader extends StatelessWidget {
  const _DiaryGroupHeader({
    required this.title,
    required this.done,
    required this.total,
    required this.bn,
  });
  final String title;
  final int done;
  final int total;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final complete = done == total;
    return Padding(
      padding: const EdgeInsets.only(
        bottom: SLSpacing.s8,
        left: SLSpacing.s4,
        right: SLSpacing.s4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
          if (complete)
            Icon(
              PhosphorIconsFill.checkCircle,
              size: 18,
              color: theme.colorScheme.primary,
            )
          else
            Text(
              bn ? '${toBn(done)}/${toBn(total)}' : '$done/$total',
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _ExtrasCard extends StatefulWidget {
  const _ExtrasCard({
    required this.rows,
    required this.subtitle,
    required this.today,
    required this.bn,
  });
  final List<DiaryRow> rows;
  final String subtitle;
  final String today;
  final bool bn;

  @override
  State<_ExtrasCard> createState() => _ExtrasCardState();
}

class _ExtrasCardState extends State<_ExtrasCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          Semantics(
            button: true,
            expanded: _open,
            child: InkWell(
              key: const ValueKey('diary_extras_toggle'),
              onTap: () => setState(() => _open = !_open),
              borderRadius: SLRadius.brLg,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 60),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                    vertical: SLSpacing.s8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('diary_extras'),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.subtitle,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _open ? 0.5 : 0,
                        duration: SLMotion.base,
                        child: const Icon(PhosphorIconsBold.caretDown),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_open) ...[
            Divider(
              height: 1,
              color: theme.dividerColor.withValues(alpha: 0.6),
            ),
            for (var i = 0; i < widget.rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: SLSpacing.s16,
                  endIndent: SLSpacing.s16,
                  color: theme.dividerColor.withValues(alpha: 0.6),
                ),
              _AmalGroupRow(
                row: widget.rows[i],
                today: widget.today,
                bn: widget.bn,
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The paper diary's নির্দেশনাবলী, verbatim, with the cover hadith.
Future<void> showDiaryInstructions(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheetContext) {
      final theme = Theme.of(sheetContext);
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              0,
              SLSpacing.s16,
              SLSpacing.s24,
            ),
            children: [
              Text(
                sheetContext.t('diary_instructions_title'),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              Text(
                kDiaryCoverQuoteAr,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: SLType.dua(color: theme.colorScheme.onSurface),
              ),
              Text(
                kDiaryCoverQuoteBn,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SLSpacing.s16),
              for (var i = 0; i < kDiaryInstructionsBn.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: SLSpacing.s12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${toBn(i + 1)}.',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: SLSpacing.s8),
                      Expanded(
                        child: Text(
                          kDiaryInstructionsBn[i],
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    },
  );
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
    required this.rows,
    required this.today,
    required this.bn,
  });
  final List<DiaryRow> rows;
  final String today;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: SLSpacing.s16,
                endIndent: SLSpacing.s16,
                color: Theme.of(context).dividerColor.withValues(alpha: 0.6),
              ),
            _AmalGroupRow(row: rows[i], today: today, bn: bn),
          ],
        ],
      ),
    );
  }
}

/// One row of the group card — dispatches by input type.
class _AmalGroupRow extends ConsumerWidget {
  const _AmalGroupRow({
    required this.row,
    required this.today,
    required this.bn,
  });
  final DiaryRow row;
  final String today;
  final bool bn;

  static const keyPrefix = 'amal_row';

  AmalDefinition get def => row.def;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final amal = ref.watch(amalProvider);
    final entry = amal.entry(today, def.key);
    final value = entry?.value;
    final notifier = ref.read(amalProvider.notifier);
    final theme = Theme.of(context);

    var (title, hint) = _titleAndHint(context, def, profile.category);

    switch (def.inputType) {
      case AmalInputType.tristate:
        // A fard prayer's row shows its waqt time and opens when the waqt
        // begins (today only) — no recording Isha at noon.
        final clock = ref.watch(
          prayerProvider.select(
            (p) => p == null
                ? null
                : (
                    day: p.dateKey,
                    minute: p.nowMinutes.floor(),
                    waqt: _waqtStart(def, p),
                  ),
          ),
        );
        final waqt = clock?.waqt;
        final locked =
            waqt != null && clock!.day == today && clock.minute < waqt;
        if (waqt != null && hint.isEmpty) {
          final time = formatTimeBn(waqt, bengali: bn);
          hint = locked
              ? context.t('diary_opens_at').replaceAll('%time%', time)
              : time;
        }
        final chips = TriStateChips(
          value: value is String ? value : null,
          enabled: !locked,
          labels: TriStateLabels(
            jamaat: context.t('amal_jamaat'),
            alone: context.t('amal_alone'),
            qaza: context.t('amal_qaza'),
          ),
          onChanged: (v) => notifier.write(def.key, today, v ?? '', 'manual'),
        );
        return Padding(
          key: ValueKey('${keyPrefix}_${def.key}'),
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s12,
            SLSpacing.s8,
          ),
          // One line — name + time | the three chips — when the row is
          // wide enough (412dp phones); stacked on 360dp / large text.
          child: LayoutBuilder(
            builder: (context, constraints) {
              final heading = Row(
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
              );
              // one line on a 360dp phone too (the prototype's table row);
              // stacked only when it truly cannot fit (narrow / large text)
              final oneLine = constraints.maxWidth >= 290 &&
                  MediaQuery.textScalerOf(context).scale(1) <= 1.15;
              if (oneLine) {
                return Row(
                  children: [
                    Expanded(child: heading),
                    const SizedBox(width: SLSpacing.s8),
                    SizedBox(
                      width: (constraints.maxWidth * 0.64).clamp(180.0, 216.0),
                      child: chips,
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  heading,
                  const SizedBox(height: SLSpacing.s8),
                  chips,
                ],
              );
            },
          ),
        );

      case AmalInputType.boolean:
        // Compact one-line row — the WHOLE row toggles (one-thumb diary).
        return Semantics(
          toggled: value == true,
          button: true,
          label: title,
          child: InkWell(
            key: ValueKey('${keyPrefix}_${def.key}'),
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
                              maxLines: 2,
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
      key: ValueKey('${keyPrefix}_${def.key}'),
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
    // the paper's wording when the paper row maps to exactly this amal
    final title = row.labelBn != null && bn
        ? row.labelBn!
        : (bn || def.titleBn.isNotEmpty ? def.titleBn : def.titleEn);
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

  /// Start of a fard prayer's waqt (minutes from midnight), from its
  /// `auto:prayer:<key>` source; null for anything else.
  static double? _waqtStart(AmalDefinition def, PrayerNow? prayer) {
    final source = def.autoSource ?? '';
    if (prayer == null || !source.startsWith('auto:prayer:')) return null;
    final key = PrayerKey.values.where((k) => k.name == source.substring(12));
    return key.isEmpty ? null : prayer.times.byKey(key.first);
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

class _CustomChecklistSectionState
    extends ConsumerState<_CustomChecklistSection> {
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
