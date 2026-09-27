/// হোম — prayer hub: date bar (city + Gregorian + Bangla + Hijri), the
/// countdown card (current waqt + HH:MM:SS), the 9-row schedule with per-row
/// bells, the 3 forbidden-time cards, the post-prayer tristate prompt and the
/// exact-alarm permission card.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
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

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  Set<String> _bells = <String>{};
  bool? _exactAlarmsGranted;

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

    final now = DateTime.now();
    final bnDate = banglaDate(now);
    final hijri = hijriDate(now, adjustDays: profile.hijriAdjust);
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
            // ── Date bar ──
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    city?.nameBn ?? profile.city,
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                SyncBadge(),
              ],
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${bn ? toBn(now.day) : now.day} ${bn ? gregMonthsBn[now.month - 1] : now.month} '
              '${bn ? toBn(now.year) : now.year} · ${bnDate.formatted} · ${hijri.formatted}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),

            // ── Countdown card ──
            _CountdownCard(prayer: prayer, lang: lang, bn: bn),
            const SizedBox(height: SLSpacing.s16),

            // ── Post-prayer prompt ──
            if (prayer.postPrayerKey != null)
              _PostPrayerPrompt(prayer: prayer, bn: bn),

            // ── Exact alarm permission ──
            if (_exactAlarmsGranted == false) ...[
              const SizedBox(height: SLSpacing.s12),
              _ExactAlarmCard(onGrant: _checkExactAlarms),
            ],

            // ── Forbidden times ──
            SectionHeader(
              context.t('prayer_forbidden_times'),
              icon: Icons.block_outlined,
            ),
            _ForbiddenTimes(prayer: prayer, bn: bn),

            // ── Schedule ──
            SectionHeader(
              context.t('prayer_schedule'),
              icon: Icons.schedule_outlined,
            ),
            _Schedule(
              prayer: prayer,
              bells: _bells,
              bn: bn,
              onBell: _toggleBell,
            ),
            const SizedBox(height: SLSpacing.s24),
            Center(
              child: Text(
                'সব হিসাব অফলাইনে আপনার ফোনেই হয় · ${city?.nameEn ?? ''} ${bn ? toBn(profile.lat.toStringAsFixed(2)) : profile.lat.toStringAsFixed(2)}°, ${bn ? toBn(profile.lng.toStringAsFixed(2)) : profile.lng.toStringAsFixed(2)}°',
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

// ── Countdown card ───────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  const _CountdownCard({
    required this.prayer,
    required this.lang,
    required this.bn,
  });
  final PrayerNow prayer;
  final Lang lang;
  final bool bn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = prayer.times;
    final currentLabel = _prayerLabel(prayer.currentWaqt, lang);
    final nextLabel = _prayerLabel(prayer.nextKey, lang);
    final nextAt = formatTimeBn(t.byKey(prayer.nextKey), bengali: bn);
    return Container(
      padding: const EdgeInsets.all(SLSpacing.s24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [SLColors.primary, SLColors.primaryDeep],
        ),
        borderRadius: SLRadius.brXl,
        boxShadow: SLElevation.lifted(theme.brightness == Brightness.dark),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: SLColors.gold,
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  '${context.t('prayer_current')}: $currentLabel',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: SLColors.primaryDeep,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const Spacer(),
              Icon(
                Icons.nightlight_outlined,
                size: 18,
                color: SLColors.lightPrimaryForeground.withValues(alpha: 0.8),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s12),
          Text(
            '${context.t('prayer_next')} — $nextLabel',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: SLColors.lightPrimaryForeground,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            prayer.countdownText(bengali: bn),
            style: theme.textTheme.displaySmall?.copyWith(
              color: SLColors.gold,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            '$nextLabel ${bn ? '' : 'at '}$nextAt',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: SLColors.lightPrimaryForeground.withValues(alpha: 0.85),
            ),
          ),
        ],
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
  });
  final PrayerNow prayer;
  final Set<String> bells;
  final bool bn;
  final void Function(PrayerKey key) onBell;

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
              _BellButton(on: bellOn, onToggle: () => onBell(key)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  const _BellButton({required this.on, required this.onToggle});
  final bool on;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      label: on ? 'ঘণ্টি বন্ধ করুন' : 'ঘণ্টি চালু করুন',
      child: InkWell(
        onTap: onToggle,
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

String _prayerLabel(PrayerKey key, Lang lang) => switch (lang) {
  Lang.bn => prayerLabelsBn[key]!,
  Lang.ar => prayerLabelsAr[key]!,
  Lang.en => prayerLabelsEn[key]!,
};
