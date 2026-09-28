/// Prayer live state: today's times, ticking countdown, current waqt,
/// forbidden-window flags, post-prayer prompt, notification scheduling and
/// home-widget pushes.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/bn_digits.dart';
import '../core/date_keys.dart';
import '../core/prayer_engine.dart';
import '../services/notification_service.dart';
import '../services/platform_channels.dart';
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
  String? _scheduledFor;

  @override
  PrayerNow? build() {
    ref.onDispose(() => _ticker?.cancel());
    _scheduleTick();
    return computeNow();
  }

  void _scheduleTick() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final next = computeNow();
      if (next != null) {
        if (state == null ||
            next.dateKey != state!.dateKey ||
            next.nowMinutes.floor() != state!.nowMinutes.floor()) {
          state = next;
          _onStateChanged();
        }
      }
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
    if (_scheduledFor != s.dateKey) {
      _scheduledFor = s.dateKey;
      _scheduleDayAlarms(s);
    }
    _updateWidget(s);
  }

  /// Schedule the day's notifications once per date:
  ///  · bell 10 min before each enabled waqt (zoned schedules)
  ///  · post-prayer prompt 20 min after each farz waqt begins
  ///  · exact alarm for the next farz prayer via the platform channel.
  Future<void> _scheduleDayAlarms(PrayerNow s) async {
    try {
      await NotificationService.instance.init();
    } catch (e) {
      debugPrint('notification init failed: $e');
      return;
    }
    final now = DateTime.now();
    final bells = await _enabledBells();
    for (final key in farzPrayers) {
      final minutes = s.times.byKey(key);
      final waqtAt = _dateTimeAt(s.dateKey, minutes, now);

      if (bells.contains(key.name) && waqtAt.isAfter(now)) {
        final bellAt = waqtAt.subtract(const Duration(minutes: 10));
        if (bellAt.isAfter(now)) {
          await NotificationService.instance.zoned(
            id: Nid.waqtBellBase + key.index,
            title: '${prayerLabelsBn[key]} — ওয়াক্ত হচ্ছে',
            body:
                '১০ মিনিট পরে ${prayerLabelsBn[key]}-এর সময় হবে — প্রস্তুত হোন',
            when: bellAt,
          );
        }
      }
      final promptAt = waqtAt.add(const Duration(minutes: 20));
      if (promptAt.isAfter(now)) {
        await NotificationService.instance.zoned(
          id: Nid.postPrayerBase + key.index,
          title: '${prayerLabelsBn[key]} — জামাতে / একা / কাযা?',
          body: 'নামাজ হয়ে গেলে আমলনামায় লিখে ফেলুন',
          when: promptAt,
        );
      }
    }
    // Exact alarm for the upcoming farz prayer (Kotlin AlarmManager).
    final nextAt = _dateTimeAt(s.dateKey, s.times.byKey(s.nextKey), now);
    if (nextAt.isAfter(now)) {
      await PrayerChannel.scheduleExactAlarm(
        id: 900 + s.nextKey.index,
        epochMillis: nextAt.millisecondsSinceEpoch,
        title: '${prayerLabelsBn[s.nextKey]} — ওয়াক্ত',
        body: '${prayerLabelsBn[s.nextKey]}-এর সময় হয়েছে',
      );
    }
  }

  /// The local "wall clock" DateTime for a minutes-from-midnight value on
  /// [day] — the device clock is assumed to be in the city timezone (the
  /// standard case; the manual tz in the profile also shifts notifications).
  DateTime _dateTimeAt(String day, double minutes, DateTime now) {
    final d = parseKey(day);
    return DateTime(
      d.year,
      d.month,
      d.day,
      minutes ~/ 60,
      (minutes % 60).round(),
    );
  }

  Future<Set<String>> _enabledBells() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('bell_'));
    return keys
        .where((k) => prefs.getString(k) == '1')
        .map((k) => k.substring(5))
        .toSet();
  }

  /// Toggle a waqt bell; reschedules immediately.
  Future<bool> toggleBell(PrayerKey key, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bell_${key.name}', enabled ? '1' : '0');
    if (!enabled) {
      await NotificationService.instance.cancel(Nid.waqtBellBase + key.index);
    } else {
      _scheduledFor = null; // force reschedule
      _onStateChanged();
    }
    return enabled;
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
