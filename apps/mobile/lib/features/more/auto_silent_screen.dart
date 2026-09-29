/// অটো-সাইলেন্ট (C-W3e) — DND access explain + grant flow, master switch,
/// silent-duration picker and the per-waqt (five farz) enable matrix.
/// The windows themselves are armed by PrayerBellScheduler alongside the
/// W3b bells (same rolling-window triggers); this screen only persists the
/// prefs and forces a re-arm.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/auto_silent.dart';
import '../../core/bn_digits.dart';
import '../../core/prayer_engine.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../services/platform_channels.dart';
import '../../services/prayer_bell_scheduler.dart';
import '../../state/prayer_state.dart';
import '../shared/widgets.dart';

class AutoSilentScreen extends ConsumerStatefulWidget {
  const AutoSilentScreen({super.key});

  @override
  ConsumerState<AutoSilentScreen> createState() => _AutoSilentScreenState();
}

class _AutoSilentScreenState extends ConsumerState<AutoSilentScreen>
    with WidgetsBindingObserver {
  /// null = probe in flight / unknown.
  bool? _dndGranted;
  bool _enabled = false;
  final Set<PrayerKey> _waqts = <PrayerKey>{...farzPrayers};
  int _minutes = kDefaultAutoSilentMinutes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _recheckDnd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user returns from the system DND-access screen (no result is
    // delivered there) — re-check whether they granted.
    if (state == AppLifecycleState.resumed) _recheckDnd();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = AutoSilentPrefs.fromStorage(
      boolAt: prefs.getBool,
      intAt: prefs.getInt,
    );
    if (mounted) {
      setState(() {
        _enabled = settings.enabled;
        _waqts
          ..clear()
          ..addAll(settings.waqts);
        _minutes = settings.minutes;
      });
    }
  }

  Future<void> _recheckDnd() async {
    final granted = await PrayerChannel.isDndGranted();
    if (mounted) setState(() => _dndGranted = granted);
  }

  Future<void> _requestAccess() async {
    await PrayerChannel.requestDndAccess();
    // The settings screen has no result callback — poll once more in case
    // the user comes straight back; the resume observer covers the rest.
    await _recheckDnd();
  }

  /// The waqt whose silent window (under the given — pre-change —
  /// settings) is active right now, or null. Dart-side check: the Kotlin
  /// engaged-flag knows THAT we silenced, not WHICH waqt silenced.
  PrayerKey? _activeWindowKey(Set<PrayerKey> waqts, int minutes) {
    final prayer = ref.read(prayerProvider);
    if (prayer == null) return null;
    final now = prayer.nowMinutes;
    for (final key in waqts) {
      final start = prayer.times.byKey(key);
      if (now >= start && now < start + minutes) return key;
    }
    return null;
  }

  /// After a settings change: if the ringer is silenced inside a window
  /// that no longer has a future restore edge (master off, waqt off, or
  /// minutes shortened past now), restore it NOW — otherwise the ringer
  /// would stay priority-only until the user notices. A safe no-op when
  /// this app isn't the one silencing (the Kotlin engaged-flag).
  Future<void> _restoreIfOrphaned(PrayerKey? wasActive) async {
    if (wasActive == null) return;
    final prayer = ref.read(prayerProvider);
    if (prayer == null) return;
    final stillCovered =
        _enabled && _waqts.contains(wasActive) && prayer.nowMinutes < prayer.times.byKey(wasActive) + _minutes;
    if (!stillCovered) {
      await PrayerChannel.setAutoSilent(false);
    }
  }

  /// Persist a change + force the scheduler to re-arm the silent windows
  /// (ids are deterministic, so re-arming replaces in place — but a waqt
  /// switched off would leave its old edges pending, so cancel the whole
  /// deterministic space first; a settings change is a rare user action).
  Future<void> _onSettingsChanged() async {
    await PrayerBellScheduler.cancelAutoSilentWindows();
    PrayerBellScheduler.forceSilentReschedule();
    await ref.read(prayerProvider.notifier).refreshBells();
  }

  Future<void> _toggleMaster(bool on) async {
    final wasActive = on ? null : _activeWindowKey(_waqts, _minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoSilentEnabledPrefKey, on);
    if (mounted) setState(() => _enabled = on);
    await _onSettingsChanged();
    // Feature off mid-window: every pending edge was just canceled —
    // restore the ringer if a jama'at window has it silenced right now
    // (the Kotlin side only clears a silence it started — the user's own
    // DND survives).
    if (wasActive != null) {
      await PrayerChannel.setAutoSilent(false);
    }
  }

  Future<void> _toggleWaqt(PrayerKey key, bool on) async {
    final wasActive = _activeWindowKey(_waqts, _minutes);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(autoSilentWaqtPrefKey(key), on);
    if (mounted) {
      setState(() {
        if (on) {
          _waqts.add(key);
        } else {
          _waqts.remove(key);
        }
      });
    }
    await _onSettingsChanged();
    await _restoreIfOrphaned(wasActive);
  }

  Future<void> _setMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    // The slider mutates the shown value live — recover the PREVIOUS
    // persisted minutes to judge whether an active window got orphaned.
    final oldMinutes = autoSilentMinutesFor(
      stored: prefs.getInt(autoSilentMinutesPrefKey),
    );
    final wasActive = _activeWindowKey(_waqts, oldMinutes);
    final clamped = autoSilentMinutesFor(stored: value);
    await prefs.setInt(autoSilentMinutesPrefKey, clamped);
    if (mounted) setState(() => _minutes = clamped);
    await _onSettingsChanged();
    await _restoreIfOrphaned(wasActive);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final granted = _dndGranted ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_autosilent')),
        actions: [
          IconButton(
            tooltip: context.t('autosilent_recheck'),
            onPressed: _recheckDnd,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          // ── Explain + permission ──
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.do_not_disturb_on,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Text(
                        context.t('autosilent_explain_title'),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  context.t('autosilent_explain_body'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
                const SizedBox(height: SLSpacing.s12),
                Row(
                  children: [
                    Icon(
                      granted ? Icons.check_circle : Icons.error_outline,
                      size: 18,
                      color: granted
                          ? theme.colorScheme.tertiary
                          : theme.colorScheme.error,
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Expanded(
                      child: Text(
                        '${context.t('autosilent_dnd_status')}: '
                        '${context.t(granted ? 'autosilent_granted' : 'autosilent_not_granted')}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (!granted) ...[
                  const SizedBox(height: SLSpacing.s12),
                  FilledButton.icon(
                    icon: const Icon(Icons.admin_panel_settings_outlined),
                    label: Text(context.t('autosilent_grant')),
                    onPressed: _requestAccess,
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    context.t('autosilent_return_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // ── Master switch ──
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              context.t('autosilent_master'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            subtitle: _enabled && !granted
                ? Text(
                    context.t('autosilent_not_granted'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.error),
                  )
                : null,
            value: _enabled,
            onChanged: _toggleMaster,
          ),
          const SizedBox(height: SLSpacing.s8),

          // ── Duration + per-waqt matrix (visible once enabled) ──
          if (_enabled) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${context.t('autosilent_minutes_label')} — '
                    '${bn ? toBn(_minutes) : '$_minutes'} '
                    '${context.t('autosilent_minutes_suffix')}',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _minutes.toDouble(),
                    min: kMinAutoSilentMinutes.toDouble(),
                    max: kMaxAutoSilentMinutes.toDouble(),
                    divisions:
                        kMaxAutoSilentMinutes - kMinAutoSilentMinutes,
                    label: bn ? toBn(_minutes) : '$_minutes',
                    onChanged: (v) => setState(() => _minutes = v.round()),
                    onChangeEnd: (v) => _setMinutes(v.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s4),
              child: Text(context.t('autosilent_waqts_title')),
            ),
            const SizedBox(height: SLSpacing.s4),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final key in farzPrayers)
                    SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: SLSpacing.s16,
                      ),
                      title: Text(S.tr(context.lang, 'waqt_${key.name}')),
                      value: _waqts.contains(key),
                      onChanged: (on) => _toggleWaqt(key, on),
                    ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('autosilent_reboot_note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
