/// হোম — prayer hub: global header (C-W4a), the countdown ring hero
/// (C-W4b) flying to the schedule, the 9-row schedule with per-row bells,
/// the 3 forbidden-time cards, the post-prayer tristate prompt, the
/// exact-alarm permission card, most-used amals, quick access, Ilm,
/// today's amal preview and the live preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/bell_schedule.dart';
import '../../core/calendars.dart' show hijriDate;
import '../../core/cities.dart';
import '../../core/amal_engine.dart' show currentStreak, isAmalDay;
import '../../core/date_keys.dart';
import '../../core/diary_layout.dart';
import '../../core/most_used.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/prayer_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart'
    show
        effectiveHijriAdjustProvider,
        coursePackProvider,
        quizPackProvider,
        liveProvider;
import '../../services/platform_channels.dart';
import '../../l10n/app_strings.dart';
import '../amal/amal_widgets.dart'
    show StreakBadge, TriStateChips, TriStateLabels;
import '../shared/widgets.dart';
import '../shared/global_header.dart';
import '../shared/live_program_card.dart';
import 'guest_nudge.dart';
import 'home_sections.dart';
import 'schedule_card.dart';
import 'sun_arc_card.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Set<String> _bells = <String>{};
  bool? _exactAlarmsGranted;

  /// The schedule section header's key — the countdown ring hero's
  /// "সময়সূচি দেখুন" affordance scrolls it into view (the in-page hero
  /// transition; the schedule is a section of THIS screen, so no route
  /// Hero tag is involved).

  @override
  void initState() {
    super.initState();
    _loadPrefs();
    _checkExactAlarms();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final bells = prefs
        .getKeys()
        .where((k) => k.startsWith('bell_') && prefs.getString(k) == '1')
        .map((k) => k.substring(5))
        .toSet();
    if (mounted) setState(() => _bells = bells);
  }

  Future<void> _checkExactAlarms() async {
    final granted = await PrayerChannel.canScheduleExactAlarms();
    if (mounted) setState(() => _exactAlarmsGranted = granted);
  }

  Future<void> _toggleBell(PrayerKey key) async {
    final enabled = !_bells.contains(key.name);
    await ref.read(prayerProvider.notifier).toggleBell(key, enabled);
    setState(() {
      if (enabled) {
        _bells = {..._bells, key.name};
      } else {
        _bells = _bells.where((b) => b != key.name).toSet();
      }
    });
  }

  /// The bell sheet (HOME-02a: a TAP on the bell opens it — a long-press was
  /// undiscoverable): on/off for this waqt's alarm, lead minutes before the
  /// waqt + lag minutes before the diary prompt, persisted per waqt.
  Future<void> _openBellTiming(PrayerKey key) async {
    var on = _bells.contains(key.name);
    final prefs = await SharedPreferences.getInstance();
    var bell = bellMinutesFor(
      key,
      stored: prefs.getInt(bellMinutesPrefKey(key)),
    );
    var post = postPrayerMinutesFor(
      key,
      stored: prefs.getInt(postPrayerMinutesPrefKey(key)),
    );
    var dirty = false;
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final theme = Theme.of(sheetContext);
          final sheetBn = sheetContext.isBn;
          String mins(int v) => sheetBn ? toBn(v) : '$v';
          Widget row(
            String labelKey,
            int value,
            int min,
            int max,
            int divisions,
            void Function(int) set,
          ) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SLSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${sheetContext.t(labelKey)} — ${mins(value)} ${sheetContext.t('quiz_minutes')}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: value.toDouble(),
                min: min.toDouble(),
                max: max.toDouble(),
                divisions: divisions,
                label: mins(value),
                onChanged: (v) => setSheet(() => set(v.round())),
                onChangeEnd: (_) => dirty = true,
              ),
            ],
          );
          return Padding(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s4,
              SLSpacing.s16,
              SLSpacing.s16,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sheetContext.t('bell_minutes_title')} — ${_prayerLabel(key, sheetContext.lang)}',
                  style: theme.textTheme.titleMedium,
                ),
                SwitchListTile(
                  key: const ValueKey('bell_sheet_switch'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(sheetContext.t('bell_on_for_waqt')),
                  value: on,
                  onChanged: (v) async {
                    await _toggleBell(key);
                    setSheet(() => on = v);
                  },
                ),
                row('bell_minutes_before', bell, 0, 60, 60, (v) => bell = v),
                row('bell_minutes_after', post, 5, 120, 23, (v) => post = v),
                const SizedBox(height: SLSpacing.s8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton.icon(
                      onPressed: () => setSheet(() {
                        bell = kDefaultBellMinutes;
                        post = kDefaultPostPrayerMinutes;
                        dirty = true;
                      }),
                      icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                      label: Text(sheetContext.t('bell_minutes_reset')),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: Text(sheetContext.t('bell_minutes_done')),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    if (dirty) {
      await ref
          .read(prayerProvider.notifier)
          .updateBellMinutes(key, bellMinutes: bell, postMinutes: post);
    }
  }

  /// Smooth in-page scroll from the ring hero to the schedule section
  /// (C-W4b hero interpretation: the schedule lives on the same screen, so
  /// the "flight" is an animated ensureVisible, not a route Hero).
  @override
  Widget build(BuildContext context) {
    final prayer = ref.watch(prayerProvider);
    final profile = ref.watch(profileProvider);
    final bn = context.isBn;

    if (prayer == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: SLSpacing.s12),
              Text(context.t('loading')),
            ],
          ),
        ),
      );
    }

    final city = findCity(profile.city);
    final today = parseKey(prayer.dateKey);
    final friday = today.weekday == DateTime.friday;
    final ramadan =
        hijriDate(
          DateTime.now(),
          adjustDays: ref.watch(effectiveHijriAdjustProvider),
        ).monthIndex ==
        8;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // the shared header, hiding while scrolling down (BNAV-01)
        child: ScrollAwareHeader(
          showDate: true,
          body: ListView(
            // the schedule now sits below the muhasaba card + quick access; a
            // lazily-built list would leave it unbuilt and the hero's
            // "সময়সূচি দেখুন" (ensureVisible on its key) a dead tap — keep the
            // first screens of the page built
            scrollCacheExtent: const ScrollCacheExtent.pixels(2400),
            // W5: the list must scroll CLEAR of the floating contact button
            // (52 + 16 + 12 = 80dp) — it used to cover the last rows' chevrons.
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s8,
              SLSpacing.s16,
              kContactFabClearance,
            ),
            children: [
              // ── the prayer card: the sun on its arc, the running waqt and
              // the time left, today's five from the diary (2026-10-07) ──
              SunArcPrayerCard(
                prayer: prayer,
                bn: bn,
                friday: friday,
                todayPrayers: [
                  for (final key in const [
                    PrayerKey.fajr,
                    PrayerKey.dhuhr,
                    PrayerKey.asr,
                    PrayerKey.maghrib,
                    PrayerKey.isha,
                  ])
                    HeroPrayerStatus(
                      label: waqtLabel(context, key, friday: friday),
                      value: switch (ref
                          .watch(amalProvider)
                          .entry(prayer.dateKey, 'salat_${key.name}')
                          ?.value) {
                        final String v when v.isNotEmpty => v,
                        _ => null,
                      },
                      started: prayer.nowMinutes >= prayer.times.byKey(key),
                    ),
                ],
                onTapPrayers: () => context.go('/amal'),
              ),
              const SizedBox(height: SLSpacing.s16),

              // ── আজকের মুহাসাবা (the prototype's order: the diary first) ──
              const _AmalPreviewSection(),

              // ── দ্রুত প্রবেশ ──
              const _QuickAccessGrid(),

              // ── Schedule ──
              // with the reader's own minutes in force, say so — the times
              // then differ from a printed mosque calendar on purpose
              SectionHeader(
                context.t('prayer_schedule'),
                icon: PhosphorIconsRegular.clock,
                action: ref.watch(
                      profileProvider.select((p) => p.prayerAdjust.isEmpty),
                    )
                    ? null
                    : InkWell(
                        key: const ValueKey('home_adjust_note'),
                        borderRadius: SLRadius.brPill,
                        onTap: () => context.push('/more/profile'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: SLSpacing.s8,
                            vertical: SLSpacing.s8,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIconsRegular.mosque,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.t('adjust_on_home'),
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              PrayerScheduleCard(
                prayer: prayer,
                bells: _bells,
                bn: bn,
                friday: friday,
                ramadan: ramadan,
                onBell: _openBellTiming,
                onBellLongPress: _toggleBell, // quick toggle for those who know
              ),

              // ── the weekly guest sign-up nudge (hidden for members) ──
              const GuestNudgeCard(),

              // ── Post-prayer prompt ──
              if (prayer.postPrayerKey != null)
                PostPrayerPrompt(prayer: prayer, bn: bn),

              // ── Exact alarm permission ──
              if (_exactAlarmsGranted == false) ...[
                const SizedBox(height: SLSpacing.s12),
                _ExactAlarmCard(onGrant: _checkExactAlarms),
              ],

              // ── সর্বাধিক ব্যবহৃত (C-W4b) ──
              // Offline-first: ranked from the LOCAL Drift window (no API);
              // guests see their own history, quick-log writes locally.
              const _MostUsedSection(),

              // ── Ilm (C-W4b) ──
              const _IlmSection(),

              // ── Live preview (C-W4b) — public data; hidden when nothing
              // upcoming or while it loads/offline-fails.
              const _LivePreviewSection(),

              const SizedBox(height: SLSpacing.s24),
              Center(
                child: Text(
                  '${context.t('prayer_offline_chip')} · ${(bn ? city?.nameBn : city?.nameEn) ?? ''} ${bn ? toBn(profile.lat.toStringAsFixed(2)) : profile.lat.toStringAsFixed(2)}°, ${bn ? toBn(profile.lng.toStringAsFixed(2)) : profile.lng.toStringAsFixed(2)}°',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
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

// ── সর্বাধিক ব্যবহৃত (most-used) ───────────────────────────────────────────

class _MostUsedSection extends ConsumerWidget {
  const _MostUsedSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final defs =
        ref.watch(amalDefinitionsProvider).valueOrNull ??
        const <AmalDefinition>[];
    final amal = ref.watch(amalProvider);
    final lang = context.lang;
    final today = dateKey(ref.watch(headerNowProvider));
    // Flatten the provider's date→(key→entry) window — mostUsedAmals itself
    // windows to the last 30 days and counts DISTINCT full-point days.
    final entries = [
      for (final day in amal.entries.keys)
        for (final e in (amal.entries[day] ?? const {}).values) e,
    ];
    final ranked = mostUsedAmals(
      entries,
      defs,
      category: profile.category,
      today: today,
      limit: 3, // HOME-04: the user's three most-used
    );
    // nothing to rank yet (day one): the section stays out of the way — the
    // muhasaba card above already invites the first entry
    if (ranked.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(context.t('most_used'), icon: PhosphorIconsFill.fire),
        if (ranked.isEmpty)
          // A quiet one-line hint, not a full-screen illustration: on day one
          // this section has nothing to rank yet.
          AppCard(
            onTap: () => context.go('/amal'),
            child: Row(
              children: [
                Icon(
                  PhosphorIconsRegular.listChecks,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    context.t('most_used_empty'),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          MostUsedList(
            items: ranked,
            valueOf: (key) => amal.entry(today, key)?.value,
            lang: lang,
            category: profile.category,
            onQuickLog: (def, value) => ref
                .read(amalProvider.notifier)
                .write(def.key, today, value, 'quick:home'),
          ),
      ],
    );
  }
}

// ── দ্রুত প্রবেশ (quick access) ───────────────────────────────────────────

class _QuickAccessGrid extends StatelessWidget {
  const _QuickAccessGrid();

  @override
  Widget build(BuildContext context) {
    final tiles =
        <({IconData icon, String title, String subtitle, String route})>[
          // HOME-05: সালাত পরবর্তী দোয়া, সকাল-সন্ধ্যার যিকির, কুরআন,
          // মুহাসাবা চেকলিস্ট, আমল ট্র্যাকার — plus লাইভ.
          (
            icon: PhosphorIconsFill.handHeart,
            title: context.t('quick_post_salah'),
            subtitle: context.t('quick_post_salah_desc'),
            route: '/ilm/adhkar?set=post_salat',
          ),
          (
            icon: PhosphorIconsRegular.sunHorizon,
            title: context.t('quick_adhkar'),
            subtitle: context.t('quick_adhkar_desc'),
            route: '/ilm/adhkar',
          ),
          (
            icon: PhosphorIconsFill.bookOpenText,
            title: context.t('ilm_quran'),
            subtitle: context.t('quick_quran_desc'),
            route: '/ilm/quran',
          ),
          // (the diary is the muhasaba card's own button just above, and the
          // আমল tab — this slot opens what Home could not reach before)
          (
            icon: PhosphorIconsRegular.compass,
            title: context.t('more_qibla'),
            subtitle: context.t('quick_qibla_desc'),
            route: '/more/qibla',
          ),
          (
            icon: PhosphorIconsFill.chartPieSlice,
            title: context.t('quick_tracker'),
            subtitle: context.t('quick_tracker_desc'),
            route: '/amal/month',
          ),
          (
            icon: PhosphorIconsRegular.broadcast,
            title: context.t('more_live'),
            subtitle: context.t('quick_live_desc'),
            route: '/more/live',
          ),
        ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          context.t('quick_access'),
          icon: PhosphorIconsRegular.squaresFour,
        ),
        // Pairs of tiles in equal-height rows (IntrinsicHeight): heights
        // follow the text scale instead of a fixed grid aspect ratio.
        for (var i = 0; i < tiles.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: SLSpacing.s8),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final tile in tiles.skip(i).take(2)) ...[
                    if (tile != tiles[i]) const SizedBox(width: SLSpacing.s8),
                    Expanded(
                      child: QuickAccessTile(
                        icon: tile.icon,
                        title: tile.title,
                        subtitle: tile.subtitle,
                        onTap: () => context.push(tile.route),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ── সব দেখুন action (see_all) ─────────────────────────────────────────────

/// The SectionHeader action for sections that have a destination —
/// 'সব দেখুন →' (44px target, direction-aware caret).
class _SeeAllButton extends StatelessWidget {
  const _SeeAllButton(this.route);

  final String route;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        minimumSize: const Size(44, SLSpacing.minTapTarget),
        padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s8),
      ),
      onPressed: () => context.push(route),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            context.t('see_all'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 2),
          DirectionalIcon(
            PhosphorIconsBold.caretRight,
            size: 14,
            color: Theme.of(context).colorScheme.primary,
          ),
        ],
      ),
    );
  }
}

// ── Ilm (courses + quizzes) ────────────────────────────────────────────────

class _IlmSection extends ConsumerWidget {
  const _IlmSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    // The existing lightweight packs (bundled-asset fallback when offline)
    // — counts only; no new API surface.
    final courseCount = ref
        .watch(coursePackProvider)
        .maybeWhen(data: (c) => c.length, orElse: () => null);
    final quizCount = ref
        .watch(quizPackProvider)
        .maybeWhen(data: (q) => q.length, orElse: () => null);

    Widget card({
      required IconData icon,
      required String title,
      required String desc,
      required int? count,
      required String countUnit,
      required String route,
    }) {
      return AppCard(
        onTap: () => context.push(route),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: SLRadius.brMd,
              ),
              child: Icon(icon, size: 22, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              desc,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (count != null && count > 0) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(
                '${bn ? toBn(count) : '$count'} $countUnit',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          context.t('tab_ilm'),
          icon: PhosphorIconsRegular.graduationCap,
          action: _SeeAllButton('/ilm'),
        ),
        // equal heights, tops aligned (one card has a count line, the
        // other may not)
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: card(
                  icon: PhosphorIconsFill.graduationCap,
                  title: context.t('ilm_courses'),
                  desc: context.t('ilm_courses_desc'),
                  count: courseCount,
                  countUnit: context.t('ilm_courses'),
                  route: '/ilm/courses',
                ),
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: card(
                  icon: PhosphorIconsFill.chartPieSlice,
                  title: context.t('ilm_quizzes'),
                  desc: context.t('ilm_quizzes_desc'),
                  count: quizCount,
                  countUnit: context.t('ilm_quizzes'),
                  route: '/ilm/quizzes',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Today's amal preview ────────────────────────────────────────────────────

class _AmalPreviewSection extends ConsumerWidget {
  const _AmalPreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';
    final profile = ref.watch(profileProvider);
    final defs =
        ref.watch(amalDefinitionsProvider).valueOrNull ??
        const <AmalDefinition>[];
    final amal = ref.watch(amalProvider);
    final today = dateKey(ref.watch(headerNowProvider));
    // Same grouping rule as today_screen: effective hijri adjust (user ±2 +
    // admin ±2) decides ayyam-beez cadence membership.
    final todayDefs = defs
        .where(
          (d) => isAmalDay(
            d,
            today,
            hijriAdjust: ref.watch(effectiveHijriAdjustProvider),
          ),
        )
        .toList();
    final entries = [
      for (final day in amal.entries.keys)
        for (final e in (amal.entries[day] ?? const {}).values) e,
    ];
    // HOME-09 counts the PAPER diary's rows — the same total the আমল tab's
    // ring shows.
    final paperDefs = [
      for (final g in layoutDiary(todayDefs).paper)
        for (final r in g.rows) r.def,
    ];
    final preview = todayAmalPreview(
      entries,
      paperDefs,
      profile.category,
      today,
    );
    final streak = currentStreak(entries, defs, profile.category, today);

    // what is due right now: started, unrecorded waqts + the adhkar window
    // (minute granularity — not every 1-second prayer tick)
    final clock = ref.watch(
      prayerProvider.select(
        (p) => p == null
            ? null
            : (
                minute: p.nowMinutes.floor(),
                times: [
                  ('fajr', p.times.fajr),
                  ('dhuhr', p.times.dhuhr),
                  ('asr', p.times.asr),
                  ('maghrib', p.times.maghrib),
                  ('isha', p.times.isha),
                ],
                dhuhr: p.times.dhuhr,
                fajr: p.times.fajr,
                asr: p.times.asr,
              ),
      ),
    );
    final pending = <String>[];
    if (clock != null) {
      for (final (w, start) in clock.times) {
        final v = amal.entry(today, 'salat_$w')?.value;
        if (clock.minute >= start && (v == null || v == '')) {
          pending.add(context.t('waqt_$w'));
        }
      }
      final morning = clock.minute >= clock.fajr && clock.minute < clock.dhuhr;
      final evening = clock.minute >= clock.asr;
      if (morning && amal.entry(today, 'adhkar_morning')?.value != true) {
        pending.add(context.t('home_pending_morning_adhkar'));
      }
      if (evening && amal.entry(today, 'adhkar_evening')?.value != true) {
        pending.add(context.t('home_pending_evening_adhkar'));
      }
    }
    final allDone = preview.total > 0 && preview.completed >= preview.total;

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s16),
      child: AppCard(
        key: const ValueKey('home_amal_preview'),
        onTap: () => context.go('/amal'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('home_muhasaba_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                StreakBadge(days: streak, bengali: bn),
              ],
            ),
            const SizedBox(height: SLSpacing.s12),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: preview.total == 0
                          ? 0
                          : preview.completed / preview.total,
                      minHeight: 8,
                      backgroundColor: cs.outline,
                      color: cs.primary,
                    ),
                  ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Text(
                  '${n(preview.completed)}/${n(preview.total)}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              allDone
                  ? context.t('home_muhasaba_all_done')
                  : pending.isEmpty
                  ? context.t('home_muhasaba_on_track')
                  : '${context.t('home_muhasaba_pending')}: ${pending.join(', ')}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s12),
            FilledButton.icon(
              key: const ValueKey('home_muhasaba_open'),
              onPressed: () => context.go('/amal'),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
              label: Text(
                context.t(
                  preview.completed == 0
                      ? 'home_muhasaba_start'
                      : 'home_muhasaba_continue',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live preview ────────────────────────────────────────────────────────────

class _LivePreviewSection extends ConsumerWidget {
  const _LivePreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live is PUBLIC data; the section stays hidden while loading/offline
    // and when nothing is live or upcoming (home degrades like the other
    // sections do for guests — the full list lives at /more/live).
    // HOME-10: a program that is live NOW wins over the next upcoming one.
    final programs = ref.watch(liveProvider).valueOrNull ?? const [];
    LiveProgramItem? pick(String status) =>
        (programs.where((p) => p.status == status).toList()
              ..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
            .firstOrNull;
    final p = pick('live') ?? pick('upcoming');
    if (p == null) return const SizedBox.shrink();
    final isLive = p.status == 'live';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          context.t('more_live'),
          icon: PhosphorIconsRegular.broadcast,
          action: _SeeAllButton('/more/live'),
        ),
        LiveProgramCard(
          key: const ValueKey('home_live_preview'),
          program: p,
          statusLabel: context.t(isLive ? 'live_now' : 'live_next'),
          chipKey: const ValueKey('home_live_chip'),
          watchKey: const ValueKey('home_live_watch'),
          onTap: () => context.push('/more/live'),
          onRemind: () =>
              requestLiveReminder(context, ref.read(apiProvider), p.id),
          onJoinQuiz: () => context.push('/ilm/live-quiz'),
        ),
      ],
    );
  }
}

// ── Post-prayer prompt (20 min after the waqt begins) ───────────────────────

class PostPrayerPrompt extends ConsumerWidget {
  const PostPrayerPrompt({super.key, required this.prayer, required this.bn});
  final PrayerNow prayer;
  final bool bn;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final key = prayer.postPrayerKey!;
    final label = _prayerLabel(key, context.lang);
    final today = dateKey(ref.watch(headerNowProvider));
    final entry = ref.watch(
      amalProvider.select((s) => s.entry(today, 'salat_${key.name}')),
    );
    final value = entry?.value;

    return Container(
      margin: const EdgeInsets.only(top: SLSpacing.s12),
      padding: const EdgeInsets.all(SLSpacing.s16),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.12),
        borderRadius: SLRadius.brLg,
        border: Border.all(color: theme.colorScheme.tertiary, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                PhosphorIconsRegular.checkCircle,
                color: theme.colorScheme.tertiary,
                size: 20,
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  '$label — ${context.t('prayer_prompt_title')}',
                  style: theme.textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t(
              value is String && value.isNotEmpty
                  ? 'prayer_prompt_saved'
                  : 'prayer_prompt_sub',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          // The diary's own জামাতে / একা / কাযা chips: every label always
          // readable (the old buttons drew primary text on a primary fill —
          // two of three were blank — and the chosen one went grey and
          // clipped to "জা…"). Tapping the chosen one again clears it.
          TriStateChips(
            key: const ValueKey('home_post_prayer_chips'),
            value: value is String && value.isNotEmpty ? value : null,
            idleColor: theme.brightness == Brightness.dark
                ? SLColors.darkCard
                : SLColors.lightCard,
            labels: TriStateLabels(
              jamaat: context.t('amal_jamaat'),
              alone: context.t('amal_alone'),
              qaza: context.t('amal_qaza'),
            ),
            onChanged: (v) => ref
                .read(amalProvider.notifier)
                .write(
                  'salat_${key.name}',
                  today,
                  v ?? '',
                  'auto:prayer:${key.name}',
                ),
          ),
        ],
      ),
    );
  }
}

// ── Exact-alarm card ────────────────────────────────────────────────────────

class _ExactAlarmCard extends StatelessWidget {
  const _ExactAlarmCard({required this.onGrant});
  final Future<void> Function() onGrant;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Row(
        children: [
          Icon(PhosphorIconsRegular.alarm, color: theme.colorScheme.primary),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('exact_alarm_title'),
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 2),
                Text(
                  context.t('exact_alarm_desc'),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          FilledButton.tonal(
            onPressed: () async {
              final opened = await PrayerChannel.requestExactAlarmPermission();
              if (!opened && context.mounted) {
                await onGrant();
              }
            },
            child: Text(context.t('exact_alarm_grant')),
          ),
        ],
      ),
    );
  }
}

String _prayerLabel(PrayerKey key, Lang lang) => S.tr(lang, 'waqt_${key.name}');
