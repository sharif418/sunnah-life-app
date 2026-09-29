/// হোম — prayer hub: global header (C-W4a), the countdown ring hero
/// (C-W4b) flying to the schedule, the 9-row schedule with per-row bells,
/// the 3 forbidden-time cards, the post-prayer tristate prompt, the
/// exact-alarm permission card, most-used amals, quick access, Ilm,
/// today's amal preview and the live preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/bell_schedule.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../core/cities.dart';
import '../../core/amal_engine.dart' show isAmalDay;
import '../../core/date_keys.dart';
import '../../core/most_used.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/amal_state.dart';
import '../../state/prayer_state.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart'
    show effectiveHijriAdjustProvider, coursePackProvider, quizPackProvider, liveProvider;
import '../../services/platform_channels.dart';
import '../../l10n/app_strings.dart';
import '../amal/amal_widgets.dart' show CompletionRing;
import '../shared/widgets.dart';
import '../shared/global_header.dart';
import 'home_sections.dart';

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
  final GlobalKey _scheduleKey = GlobalKey();

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

  /// Per-waqt bell timing (long-press on the bell): lead minutes before the
  /// waqt + lag minutes before the diary prompt, persisted per waqt.
  Future<void> _openBellTiming(PrayerKey key) async {
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
          String mins(int v) =>
              sheetBn ? toBn(v) : '$v';
          Widget row(String labelKey, int value, int min, int max, int divisions, void Function(int) set) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: SLSpacing.s4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${sheetContext.t(labelKey)} — ${mins(value)} ${sheetContext.t('quiz_minutes')}',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
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
                row(
                  'bell_minutes_before',
                  bell,
                  0,
                  60,
                  60,
                  (v) => bell = v,
                ),
                row(
                  'bell_minutes_after',
                  post,
                  5,
                  120,
                  23,
                  (v) => post = v,
                ),
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
                      icon: const Icon(Icons.restart_alt),
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
  void _showSchedule() {
    final ctx = _scheduleKey.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: SLMotion.slow,
      curve: SLMotion.standard,
      alignment: 0.1,
    );
  }

  @override
  Widget build(BuildContext context) {
    final prayer = ref.watch(prayerProvider);
    final profile = ref.watch(profileProvider);
    final lang = context.lang;
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

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s16,
            SLSpacing.s24,
          ),
          children: [
            // ── Global header (C-W4a): logo, location, triple calendar,
            // notification/reminder/profile actions, sync badge. The date-bar
            // logic that used to live here moved into it — no duplication.
            const GlobalHeader(),

            // ── Countdown ring hero (C-W4b) ──
            // Same gradient family as the old countdown card, now a RING:
            // the gold arc = REMAINING of the current waqt interval, the
            // HH:MM:SS + arc tick every second (prayerProvider's per-second
            // state), and the affordance row flies to the schedule below.
            CountdownRingHero(
              prayer: prayer,
              lang: lang,
              bn: bn,
              onShowSchedule: _showSchedule,
            ),
            const SizedBox(height: SLSpacing.s16),

            // ── Schedule (the hero's in-page destination) ──
            SectionHeader(
              key: _scheduleKey,
              context.t('prayer_schedule'),
              icon: Icons.schedule_outlined,
            ),
            _Schedule(
              prayer: prayer,
              bells: _bells,
              bn: bn,
              onBell: _toggleBell,
              onBellLongPress: _openBellTiming,
            ),

            // ── Forbidden times ──
            SectionHeader(
              context.t('prayer_forbidden_times'),
              icon: Icons.block_outlined,
            ),
            _ForbiddenTimes(prayer: prayer, bn: bn),

            // ── Post-prayer prompt ──
            if (prayer.postPrayerKey != null)
              _PostPrayerPrompt(prayer: prayer, bn: bn),

            // ── Exact alarm permission ──
            if (_exactAlarmsGranted == false) ...[
              const SizedBox(height: SLSpacing.s12),
              _ExactAlarmCard(onGrant: _checkExactAlarms),
            ],

            // ── সর্বাধিক ব্যবহৃত (C-W4b) ──
            // Offline-first: ranked from the LOCAL Drift window (no API);
            // guests see their own history, quick-log writes locally.
            const _MostUsedSection(),

            // ── দ্রুত প্রবেশ (C-W4b) ──
            const _QuickAccessGrid(),

            // ── Ilm (C-W4b) ──
            const _IlmSection(),

            // ── Today's amal preview (C-W4b) ──
            const _AmalPreviewSection(),

            // ── Live preview (C-W4b) — public data; hidden when nothing
            // upcoming or while it loads/offline-fails.
            const _LivePreviewSection(),

            const SizedBox(height: SLSpacing.s24),
            Center(
              child: Text(
                '${context.t('prayer_offline_chip')} · ${city?.nameEn ?? ''} ${bn ? toBn(profile.lat.toStringAsFixed(2)) : profile.lat.toStringAsFixed(2)}°, ${bn ? toBn(profile.lng.toStringAsFixed(2)) : profile.lng.toStringAsFixed(2)}°',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
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
        ref.watch(amalDefinitionsProvider).valueOrNull ?? const <AmalDefinition>[];
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
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(context.t('most_used'), icon: PhosphorIconsFill.fire),
        if (ranked.isEmpty)
          EmptyState(
            message: context.t('most_used_empty'),
            icon: PhosphorIconsRegular.listChecks,
          )
        else
          SizedBox(
            height: 176,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: ranked.length,
              separatorBuilder: (_, _) => const SizedBox(width: SLSpacing.s8),
              itemBuilder: (context, i) {
                final item = ranked[i];
                return MostUsedCard(
                  item: item,
                  currentValue: amal.entry(today, item.def.key)?.value,
                  lang: lang,
                  onQuickLog: (value) => ref
                      .read(amalProvider.notifier)
                      .write(item.def.key, today, value, 'quick:home'),
                );
              },
            ),
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
    final tiles = <({IconData icon, String title, String subtitle, String route})>[
      (
        icon: PhosphorIconsFill.bookOpenText,
        title: context.t('ilm_quran'),
        subtitle: context.t('quick_quran_desc'),
        route: '/ilm/quran',
      ),
      (
        icon: PhosphorIconsFill.handHeart,
        title: context.t('ilm_duas'),
        subtitle: context.t('quick_duas_desc'),
        route: '/ilm/duas',
      ),
      (
        icon: PhosphorIconsFill.clipboardText,
        title: context.t('tab_amal'),
        subtitle: context.t('quick_amal_desc'),
        route: '/amal',
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
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: SLSpacing.s8,
            crossAxisSpacing: SLSpacing.s8,
            childAspectRatio: 1.0,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, i) {
            final tile = tiles[i];
            return QuickAccessTile(
              icon: tile.icon,
              title: tile.title,
              subtitle: tile.subtitle,
              onTap: () => context.push(tile.route),
            );
          },
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                shape: BoxShape.circle,
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
        Row(
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
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    final defs =
        ref.watch(amalDefinitionsProvider).valueOrNull ?? const <AmalDefinition>[];
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
    final preview = todayAmalPreview(
      entries,
      todayDefs,
      profile.category,
      today,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          context.t('tab_amal'),
          icon: PhosphorIconsRegular.listChecks,
          action: _SeeAllButton('/amal'),
        ),
        AppCard(
          key: const ValueKey('home_amal_preview'),
          onTap: () => context.push('/amal'),
          child: Row(
            children: [
              CompletionRing(
                pct: preview.pct,
                label: context.t('amal_today'),
                size: 64,
                bengali: bn,
              ),
              const SizedBox(width: SLSpacing.s16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${bn ? toBn(preview.completed) : preview.completed}/'
                      '${bn ? toBn(preview.total) : preview.total} '
                      '${context.t('done')}',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      context.t('today_progress'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const DirectionalIcon(Icons.chevron_right),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Live preview ────────────────────────────────────────────────────────────

class _LivePreviewSection extends ConsumerWidget {
  const _LivePreviewSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // Live is PUBLIC data; the section stays hidden while loading/offline
    // and when nothing is upcoming (home degrades like the other sections
    // do for guests — the full list lives at /more/live).
    final upcoming = ref.watch(liveProvider).maybeWhen(
          data: (programs) =>
              (programs.where((p) => p.status == 'upcoming').toList()
                    ..sort((a, b) => a.startsAt.compareTo(b.startsAt)))
                  .firstOrNull,
          orElse: () => null,
        );
    if (upcoming == null) return const SizedBox.shrink();
    final p = upcoming;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          context.t('more_live'),
          icon: PhosphorIconsRegular.broadcast,
          action: _SeeAllButton('/more/live'),
        ),
        AppCard(
          key: const ValueKey('home_live_preview'),
          onTap: () => context.push('/more/live'),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  PhosphorIconsRegular.broadcast,
                  size: 22,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          key: const ValueKey('home_live_chip'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: SLSpacing.s8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: SLColors.gold.withValues(alpha: 0.18),
                            borderRadius: SLRadius.brPill,
                          ),
                          child: Text(
                            context.t('live_next'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: SLColors.goldDeep,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      p.titleBn,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      _liveWhen(p.startsAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      context.t('live_join_hint'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Day/time line in the Live screen's convention (ISO → 'YYYY-MM-DD HH:MM'),
  /// length-guarded so a short/odd server string never crashes home.
  static String _liveWhen(String startsAt) => startsAt.length >= 16
      ? startsAt.substring(0, 16).replaceAll('T', ' ')
      : startsAt;
}

// ── Post-prayer prompt (20 min after the waqt begins) ───────────────────────

class _PostPrayerPrompt extends ConsumerWidget {
  const _PostPrayerPrompt({required this.prayer, required this.bn});
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

    Widget option(String v, String text, IconData icon, Color color) {
      final selected = value == v;
      return Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: selected ? color : null,
              foregroundColor: selected
                  ? theme.colorScheme.onPrimary
                  : theme.colorScheme.primary,
              minimumSize: const Size.fromHeight(SLSpacing.minTapTarget + 4),
            ),
            onPressed: selected
                ? null
                : () => ref
                      .read(amalProvider.notifier)
                      .write(
                        'salat_${key.name}',
                        today,
                        v,
                        'auto:prayer:${key.name}',
                      ),
            icon: Icon(icon, size: 18),
            label: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      );
    }

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
              Icon(Icons.task_alt, color: theme.colorScheme.tertiary, size: 20),
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
            context.t('prayer_post_salat'),
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: SLSpacing.s12),
          Row(
            children: [
              option(
                'jamaat',
                context.t('amal_jamaat'),
                Icons.groups_outlined,
                theme.colorScheme.primary,
              ),
              option(
                'alone',
                context.t('amal_alone'),
                Icons.person_outline,
                theme.colorScheme.secondary,
              ),
              option(
                'qaza',
                context.t('amal_qaza'),
                Icons.schedule,
                theme.colorScheme.error,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Forbidden times ───────────────────────────────────────────────────────────

class _ForbiddenTimes extends StatelessWidget {
  const _ForbiddenTimes({required this.prayer, required this.bn});
  final PrayerNow prayer;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final t = prayer.times;
    final windows = [
      (context.t('prayer_forbidden_sunrise'), t.sunrise - 15, t.sunrise + 20),
      (context.t('prayer_forbidden_zawal'), t.dhuhr - 10, t.dhuhr + 5),
      (context.t('prayer_forbidden_sunset'), t.sunset - 15, t.sunset + 5),
    ];
    final theme = Theme.of(context);
    return Column(
      children: [
        for (final (label, from, to) in windows)
          Container(
            margin: const EdgeInsets.only(bottom: SLSpacing.s8),
            padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s12,
              vertical: SLSpacing.s8,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.errorContainer.withValues(alpha: 0.35),
              borderRadius: SLRadius.brMd,
              border: Border.all(color: theme.colorScheme.error, width: 1),
            ),
            child: Row(
              children: [
                Icon(Icons.block, color: theme.colorScheme.error, size: 18),
                const SizedBox(width: SLSpacing.s8),
                Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
                Text(
                  '${formatTimeBn(from, bengali: bn)} — ${formatTimeBn(to, bengali: bn)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ── Schedule ────────────────────────────────────────────────────────────────

class _Schedule extends StatelessWidget {
  const _Schedule({
    required this.prayer,
    required this.bells,
    required this.bn,
    required this.onBell,
    required this.onBellLongPress,
  });
  final PrayerNow prayer;
  final Set<String> bells;
  final bool bn;
  final void Function(PrayerKey key) onBell;
  final void Function(PrayerKey key) onBellLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (var i = 0; i < scheduleOrder.length; i++)
            _row(
              context,
              theme,
              scheduleOrder[i],
              isLast: i == scheduleOrder.length - 1,
            ),
        ],
      ),
    );
  }

  Widget _row(
    BuildContext context,
    ThemeData theme,
    PrayerKey key, {
    required bool isLast,
  }) {
    final mins = prayer.times.byKey(key);
    final isCurrent = key == prayer.currentWaqt;
    final isNext = key == prayer.nextKey;
    final label = _prayerLabel(key, context.lang);
    final bellOn = bells.contains(key.name);
    return Opacity(
      opacity: isCurrent || isNext || key == PrayerKey.tahajjud ? 1 : 0.75,
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent
              ? theme.colorScheme.primaryContainer
              : Colors.transparent,
          borderRadius: !isLast ? SLRadius.brMd : null,
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: 0,
          ),
          minVerticalPadding: 6,
          leading: isCurrent
              ? Icon(
                  Icons.radio_button_checked,
                  color: theme.colorScheme.primary,
                  size: 20,
                )
              : Icon(
                  Icons.circle_outlined,
                  color: theme.colorScheme.outline,
                  size: 12,
                ),
          title: Text(
            label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
              color: isCurrent ? theme.colorScheme.primary : null,
            ),
          ),
          subtitle: isNext
              ? Text(
                  context.t('prayer_next'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                )
              : null,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatTimeBn(mins, bengali: bn),
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: SLSpacing.s4),
              _BellButton(
                on: bellOn,
                onToggle: () => onBell(key),
                onLongPress: () => onBellLongPress(key),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({
    required this.on,
    required this.onToggle,
    this.onLongPress,
  });
  final bool on;
  final VoidCallback onToggle;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      toggled: on,
      label: on
          ? context.t('prayer_bell_disable')
          : context.t('prayer_bell_enable'),
      child: InkWell(
        onTap: onToggle,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: SLSpacing.minTapTarget,
          height: SLSpacing.minTapTarget,
          child: Icon(
            on ? Icons.notifications_active : Icons.notifications_none,
            size: 20,
            color: on ? theme.colorScheme.tertiary : theme.colorScheme.outline,
          ),
        ),
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
          Icon(Icons.alarm, color: theme.colorScheme.primary),
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

String _prayerLabel(PrayerKey key, Lang lang) =>
    S.tr(lang, 'waqt_${key.name}');
