/// হোম — prayer hub: global header (C-W4a), the countdown ring hero
/// (C-W4b) flying to the schedule, the 9-row schedule with per-row bells,
/// the 3 forbidden-time cards, the post-prayer tristate prompt, the
/// exact-alarm permission card, most-used amals, quick access, Ilm,
/// today's amal preview and the live preview.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/bell_schedule.dart';
import '../../core/calendars.dart' show formatTimeBn;
import '../../core/cities.dart';
import '../../core/date_keys.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../../state/amal_state.dart';
import '../../state/prayer_state.dart';
import '../../state/providers.dart';
import '../../services/platform_channels.dart';
import '../../l10n/app_strings.dart';
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
    final today = dateKey(DateTime.now());
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
