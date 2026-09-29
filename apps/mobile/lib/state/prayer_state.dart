/// Prayer live state: today's times, ticking countdown, current waqt,
/// forbidden-window flags, post-prayer prompt, notification scheduling and
/// home-widget pushes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bell_schedule.dart';
import '../core/bn_digits.dart';
import '../core/date_keys.dart';
import '../core/prayer_engine.dart';
import '../services/platform_channels.dart';
import '../services/prayer_bell_scheduler.dart';
import '../services/widget_snapshot.dart';
import 'providers.dart';

class PrayerNow {
  const PrayerNow({
    required this.dateKey,
    required this.times,
    required this.nowMinutes,
    required this.currentWaqt,
    required this.nextKey,
    required this.minutesToNext,
    required this.forbiddenLabel,
    required this.postPrayerKey,
  });

  final String dateKey;
  final PrayerTimesBundle times;
  final double nowMinutes;
  final PrayerKey currentWaqt;
  final PrayerKey nextKey;
  final double minutesToNext;
  final String? forbiddenLabel;
  final PrayerKey? postPrayerKey;

  /// "HH:MM:SS" remaining in Bengali digits (or latin when the app is en).
  String countdownText({bool bengali = true}) {
    var secs = (minutesToNext * 60).round();
    if (secs < 0) secs = 0;
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    String two(int v) => bengali
        ? toBn(v.toString().padLeft(2, '0'))
        : v.toString().padLeft(2, '0');
    if (h > 0) {
      final hh = bengali ? toBn(h) : '$h';
      return '$hh:${two(m)}:${two(s)}';
    }
    return '${two(m)}:${two(s)}';
  }
}

class PrayerNotifier extends Notifier<PrayerNow?> {
  Timer? _ticker;

  /// The dateKey the bell window was last refreshed for — the rolling
  /// re-arm trigger as the day rolls over (profile-change reschedules come
  /// through the profile listener below).
  String? _lastScheduleDay;

  @override
  PrayerNow? build() {
    ref.onDispose(() => _ticker?.cancel());
    // City / method / madhhab changes shift every computed time — cancel +
    // re-arm the whole window (name/theme changes must NOT thrash alarms).
    ref.listen(profileProvider, (prev, next) {
      if (prev == null) return;
      if (_bellConfigOf(prev).scheduleKey !=
          _bellConfigOf(next).scheduleKey) {
        unawaited(refreshBells());
      }
    });
    _scheduleTick();
    return computeNow();
  }

  void _scheduleTick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = computeNow();
      if (next == null) return;
      // C-W4b: state flows EVERY second — the home countdown ring + HH:MM:SS
      // tick at second granularity (nowMinutes carries the seconds fraction).
      // The side-effect paths (bell re-arm, home-widget platform push +
      // snapshot disk write) stay gated on the minute/date boundary below,
      // so nothing writes to disk or crosses the channel 60× more often
      // than before.
      if (state == null) {
        state = next;
        _onStateChanged();
        return;
      }
      final boundary = next.dateKey != state!.dateKey ||
          next.nowMinutes.floor() != state!.nowMinutes.floor();
      state = next;
      if (boundary) _onStateChanged();
    });
  }

  PrayerNow? computeNow() {
    final profile = ref.read(profileProvider);
    final now = DateTime.now();
    final today = dateKey(now);
    final times = PrayerEngine.compute(
      today,
      lat: profile.lat,
      lng: profile.lng,
      tz: profile.tz,
      method: profile.method,
      madhhab: profile.madhhab,
    );
    final nowMinutes = now.hour * 60.0 + now.minute + now.second / 60.0;
    final (nextKey, mins) = PrayerEngine.nextPrayer(times, nowMinutes);
    return PrayerNow(
      dateKey: today,
      times: times,
      nowMinutes: nowMinutes,
      currentWaqt: PrayerEngine.currentWaqt(times, nowMinutes),
      nextKey: nextKey,
      minutesToNext: mins,
      forbiddenLabel: PrayerEngine.inForbiddenWindow(times, nowMinutes),
      postPrayerKey: PrayerEngine.activePostPrayerPrompt(times, nowMinutes),
    );
  }

  void _onStateChanged() {
    final s = state;
    if (s == null) return;
    if (_lastScheduleDay != s.dateKey) {
      _lastScheduleDay = s.dateKey;
      unawaited(refreshBells());
    }
    _updateWidget(s);
    // Persist the next-prayer snapshot for the home widget (C-W3f reads
    // it from Kotlin; survives app death). Fire-and-forget, swallowed.
    unawaited(
      WidgetSnapshotService.write(
        city: ref.read(profileProvider).city,
        dateKey: s.dateKey,
        times: s.times,
        nextKey: s.nextKey,
      ),
    );
  }

  PrayerBellConfig _bellConfigOf(ProfileState profile) => PrayerBellConfig(
    lat: profile.lat,
    lng: profile.lng,
    tz: profile.tz,
    method: profile.method,
    madhhab: profile.madhhab,
  );

  /// (Re)arm the rolling 3-day bell window with the CURRENT profile.
  /// Called on app start, day rollover, profile change, bell toggle,
  /// per-waqt minute change and app resume. Passes the city through so the
  /// same refresh also rewrites the widget snapshot (C-W3f).
  Future<void> refreshBells() async {
    try {
      final profile = ref.read(profileProvider);
      await PrayerBellScheduler.refresh(
        PrayerBellConfig(
          lat: profile.lat,
          lng: profile.lng,
          tz: profile.tz,
          method: profile.method,
          madhhab: profile.madhhab,
        ),
        city: profile.city,
      );
    } catch (e) {
      debugPrint('bell window refresh failed: $e');
    }
  }

  /// Toggle a waqt bell; reschedules immediately.
  Future<bool> toggleBell(PrayerKey key, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bell_${key.name}', enabled ? '1' : '0');
    if (!enabled) {
      await PrayerBellScheduler.disableBell(key);
    } else {
      // Days already armed under the old prefs are skipped by refresh —
      // force a clean re-arm so the new bell is scheduled right away.
      PrayerBellScheduler.forceReschedule();
      await refreshBells();
    }
    return enabled;
  }

  /// Persist per-waqt lead/lag minutes and re-arm this waqt's alarms
  /// (called by the Home bell-timing sheet).
  Future<void> updateBellMinutes(
    PrayerKey key, {
    int? bellMinutes,
    int? postMinutes,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (bellMinutes != null) {
      await prefs.setInt(bellMinutesPrefKey(key), bellMinutes);
    }
    if (postMinutes != null) {
      await prefs.setInt(postPrayerMinutesPrefKey(key), postMinutes);
    }
    PrayerBellScheduler.forceReschedule();
    await refreshBells();
  }

  void _updateWidget(PrayerNow s) {
    WidgetChannel.updateNextPrayer(
      prayerName: prayerLabelsBn[s.nextKey] ?? '',
      countdown:
          '${toBn((s.minutesToNext ~/ 60))} ঘ '
          '${toBn((s.minutesToNext % 60).round())} মি',
    );
  }
}

final prayerProvider = NotifierProvider<PrayerNotifier, PrayerNow?>(
  PrayerNotifier.new,
);
