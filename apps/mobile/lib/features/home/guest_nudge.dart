/// The weekly guest sign-up nudge. A guest's diary lives on ONE phone; an
/// account backs it up, opens the usrah and the da'ee journey. The ask is
/// framed as what the member gains, shows at most once a week ("পরে" hides
/// it for seven days), and a weekly Friday reminder carries the same
/// message to guests who don't open the app (cancelled on sign-in).
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    show DateTimeComponents;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bell_schedule.dart' show Nid;
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../services/notification_service.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

const _kDismissedAtKey = 'sl_guest_nudge_dismissed_at';
const kGuestNudgeEvery = Duration(days: 7);

/// Whether the card is due: a guest who hasn't tapped "পরে" in the last
/// seven days. Invalidated on dismiss.
final guestNudgeDueProvider = FutureProvider<bool>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.status != AuthStatus.guest) return false;
  try {
    final prefs = await SharedPreferences.getInstance();
    final at = prefs.getInt(_kDismissedAtKey);
    if (at == null) return true;
    final since = DateTime.now().difference(
      DateTime.fromMillisecondsSinceEpoch(at),
    );
    return since >= kGuestNudgeEvery;
  } catch (_) {
    return true;
  }
});

class GuestNudgeCard extends ConsumerWidget {
  const GuestNudgeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(guestNudgeDueProvider).valueOrNull != true) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // Its own block with air above (it used to sit flush under the schedule
    // card): a soft green-tinted panel, a shield badge, the three gains as
    // icon rows, then the one action.
    return Padding(
      padding: const EdgeInsets.only(top: SLSpacing.s24),
      child: Container(
        key: const ValueKey('guest_nudge'),
        padding: const EdgeInsets.all(SLSpacing.s16),
        decoration: BoxDecoration(
          color: dark
              ? Color.alphaBlend(cs.primary.withValues(alpha: 0.16), cs.surface)
              : cs.primaryContainer,
          borderRadius: SLRadius.brLg,
          border: Border.all(color: cs.primary.withValues(alpha: 0.28)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.shieldCheck,
                    size: 24,
                    color: cs.onPrimary,
                  ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('guest_nudge_title'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          height: 1.3,
                        ),
                      ),
                      Text(
                        context.t('guest_nudge_sub'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s12),
            for (final (icon, key) in const [
              (PhosphorIconsRegular.cloudCheck, 'guest_nudge_backup'),
              (PhosphorIconsRegular.usersThree, 'guest_nudge_usrah'),
              (PhosphorIconsRegular.trendUp, 'guest_nudge_journey'),
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: dark ? cs.primaryContainer : cs.surface,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: cs.primary),
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.t(key),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: SLSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('guest_nudge_signup'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: () => context.push('/auth'),
                    icon: const Icon(PhosphorIconsRegular.userPlus, size: 18),
                    label: Text(context.t('guest_nudge_cta')),
                  ),
                ),
                const SizedBox(width: SLSpacing.s8),
                TextButton(
                  key: const ValueKey('guest_nudge_later'),
                  style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                  onPressed: () async {
                    try {
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setInt(
                        _kDismissedAtKey,
                        DateTime.now().millisecondsSinceEpoch,
                      );
                    } catch (_) {
                      // storage unavailable — it simply shows again
                    }
                    ref.invalidate(guestNudgeDueProvider);
                  },
                  child: Text(context.t('guest_nudge_later')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The next Friday 10:00 local after [now] (today counts if still before).
DateTime nextGuestNudgeAt(DateTime now) {
  var d = DateTime(now.year, now.month, now.day, 10);
  while (d.weekday != DateTime.friday || !d.isAfter(now)) {
    d = d.add(const Duration(days: 1));
  }
  return d;
}

/// Weekly reminder for guests (Friday 10:00, repeating), cancelled for a
/// signed-in member. Phones only; never throws.
Future<void> syncGuestNudgeReminder({required bool guest}) async {
  if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
  try {
    final n = NotificationService.instance;
    await n.init();
    await n.cancel(Nid.guestNudge);
    if (!guest) return;
    await n.zoned(
      id: Nid.guestNudge,
      title: 'আপনার আমলের হিসাব নিরাপদ রাখুন',
      body: 'একটি অ্যাকাউন্ট খুললে ডায়েরি সংরক্ষিত থাকবে, উসরায় যুক্ত হতে পারবেন — এক মিনিট লাগে।',
      when: nextGuestNudgeAt(DateTime.now()),
      channel: 'sunnah_life_general',
      matchComponents: DateTimeComponents.dayOfWeekAndTime,
      payload: '/auth',
    );
  } catch (e) {
    debugPrint('[guest-nudge] reminder sync failed: $e');
  }
}
