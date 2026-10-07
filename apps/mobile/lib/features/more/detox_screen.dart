/// সোশ্যাল মিডিয়া ডিটক্স (W4d) — the Guard-module seed: permission
/// explainer → usage-access grant flow → today's total screen time + the
/// top apps (Android UsageStatsManager over sunnahlife/usage), plus a
/// daily reminder (flutter_local_notifications zonedSchedule with
/// DateTimeComponents.time). iOS/desktop/tests render an honest
/// "supported on Android only" state (UsageChannel.hasPermission → null).
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bell_schedule.dart' show Nid;
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../services/notification_service.dart';
import '../../services/platform_channels.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

const String _kPrefReminderOn = 'detox_reminder_on';
const String _kPrefReminderHour = 'detox_reminder_h';
const String _kPrefReminderMinute = 'detox_reminder_m';
const int _kDefaultReminderHour = 21; // রাতে — দিন শেষে হিসাবের সময়

class DetoxScreen extends StatefulWidget {
  const DetoxScreen({super.key});

  @override
  State<DetoxScreen> createState() => _DetoxScreenState();
}

class _DetoxScreenState extends State<DetoxScreen> with WidgetsBindingObserver {
  /// null = probe in flight / platform without the channel.
  bool? _permission;
  UsageToday? _stats;
  bool _reminderOn = false;
  int _hour = _kDefaultReminderHour;
  int _minute = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadPrefs();
    _recheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The user returns from the system usage-access screen (no result is
    // delivered there) — re-check whether they granted, then refresh stats.
    if (state == AppLifecycleState.resumed) _recheck();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _reminderOn = prefs.getBool(_kPrefReminderOn) ?? false;
      _hour = prefs.getInt(_kPrefReminderHour) ?? _kDefaultReminderHour;
      _minute = prefs.getInt(_kPrefReminderMinute) ?? 0;
    });
  }

  Future<void> _recheck() async {
    final granted = await UsageChannel.hasPermission();
    if (!mounted) return;
    setState(() => _permission = granted);
    if (granted == true) await _loadStats();
  }

  Future<void> _loadStats() async {
    final stats = await UsageChannel.todayStats();
    if (!mounted) return;
    setState(() => _stats = stats);
  }

  Future<void> _requestAccess() async {
    await UsageChannel.openSettings();
    // The settings screen has no result callback — poll once more in case
    // the user comes straight back; the resume observer covers the rest.
    await _recheck();
  }

  /// (Re)arm the daily reminder — one stable id (Nid.detoxReminder) so a
  /// re-schedule replaces in place. Best-effort: a plugin-unavailable
  /// platform (tests) persists the pref and logs, like the bells.
  Future<void> _applyReminder() async {
    // Notification strings resolved BEFORE the first await — context must
    // not cross an async gap.
    final title = context.t('detox_notif_title');
    final body = context.t('detox_notif_body');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kPrefReminderOn, _reminderOn);
    await prefs.setInt(_kPrefReminderHour, _hour);
    await prefs.setInt(_kPrefReminderMinute, _minute);
    try {
      await NotificationService.instance.init();
      await NotificationService.instance.cancel(Nid.detoxReminder);
      if (_reminderOn) {
        final now = DateTime.now();
        var when = DateTime(now.year, now.month, now.day, _hour, _minute);
        if (!when.isAfter(now)) {
          when = when.add(const Duration(days: 1));
        }
        await NotificationService.instance.zoned(
          id: Nid.detoxReminder,
          title: title,
          body: body,
          when: when,
          channel: 'sunnah_life_general',
          matchComponents: DateTimeComponents.time,
          payload: 'local',
        );
      }
    } catch (e) {
      // Plugin unavailable (tests / stubbed platforms) — the pref stays
      // persisted and the UI stays truthful; a real device schedules fine.
      debugPrint('detox reminder schedule failed: $e');
    }
  }

  Future<void> _toggleReminder(bool on) async {
    setState(() => _reminderOn = on);
    await _applyReminder();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await _applyReminder();
  }

  String _formatTime(BuildContext context) {
    String two(int v) => v.toString().padLeft(2, '0');
    final text = '${two(_hour)}:${two(_minute)}';
    return context.isBn ? toBn(text) : text;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = _permission ?? false;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        // a long title scales down on a small phone with large text
        // instead of losing its last word to "…"
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: AlignmentDirectional.centerStart,
          child: Text(context.t('more_detox')),
        ),
        actions: [
          IconButton(
            tooltip: context.t('detox_recheck'),
            onPressed: _recheck,
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          // ── Explainer — why screen-time matters for the mission ──
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.shield,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Text(
                        context.t('detox_explain_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  context.t('detox_explain_body'),
                  style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s16),

          // ── Platform gate ──
          if (_permission == null)
            AppCard(
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.deviceMobile,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: Text(
                      context.t('detox_android_only'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // ── Permission card ──
          else if (!granted) ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        granted ? PhosphorIconsFill.checkCircle : PhosphorIconsRegular.warningCircle,
                        size: 18,
                        color: granted
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                      ),
                      const SizedBox(width: SLSpacing.s8),
                      Expanded(
                        child: Text(
                          '${context.t('detox_perm_status')}: '
                          '${context.t('detox_perm_not_granted')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: SLSpacing.s12),
                  FilledButton.icon(
                    icon: const Icon(PhosphorIconsRegular.shieldCheck),
                    label: Text(context.t('detox_grant')),
                    onPressed: _requestAccess,
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    context.t('detox_return_hint'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ]
          // ── Today's report ──
          else ...[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('detox_today_total'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${context.isBn ? toBn(_stats?.totalMinutes ?? 0) : _stats?.totalMinutes ?? 0} '
                    '${context.t('detox_minutes_short')}',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(context.t('detox_top_apps')),
            const SizedBox(height: SLSpacing.s4),
            AppCard(
              padding: EdgeInsets.zero,
              child: (_stats?.apps.isEmpty ?? true)
                  ? Padding(
                      padding: const EdgeInsets.all(SLSpacing.s16),
                      child: Text(
                        context.t('detox_no_usage'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < _stats!.apps.length; i++) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: SLSpacing.s16,
                              endIndent: SLSpacing.s16,
                              color: Theme.of(context).dividerColor
                                  .withValues(alpha: 0.6),
                            ),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s16,
                              vertical: SLSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _stats!.apps[i].label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${context.isBn ? toBn(_stats!.apps[i].minutes) : _stats!.apps[i].minutes} '
                                  '${context.t('detox_minutes_short')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
            ),
          ],
          const SizedBox(height: SLSpacing.s16),

          // ── Daily reminder (works on every platform — local notif) ──
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  title: Text(
                    context.t('detox_reminder'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: _reminderOn,
                  onChanged: _toggleReminder,
                ),
                if (_reminderOn)
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: SLSpacing.s16,
                    ),
                    dense: true,
                    title: Text(context.t('detox_reminder_time')),
                    trailing: Text(
                      _formatTime(context),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: _pickTime,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
