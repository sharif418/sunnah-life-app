/// Global chrome (C-W4a): the shared header for the five MAIN tab screens.
/// Row 1 (NAV-01): the Sunnah Life brand mark + name, then the action
/// cluster — notification bell, reminder clock, profile, sync badge.
/// Row 2 (NAV-02): the tappable city (city picker) and the triple calendar
/// date bar (Gregorian + Bangla + Hijri with the effective ±4 adjustment
/// from C-W3g); it wraps to two lines on narrow phones.
///
/// The date-bar logic moved here VERBATIM from home_screen.dart (it was
/// home-only before) — the home screen now consumes this header instead of
/// duplicating it. Sub-screens (readers, sub-hubs) keep their own AppBars;
/// only the five tab roots mount this widget.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/bn_digits.dart';
import '../../core/calendars.dart';
import '../../core/cities.dart';
import '../../design/phosphor_icons.dart';
import '../../design/brand_mark.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider, inboxUnreadProvider;
import 'city_picker.dart';
import 'notifications_sheet.dart';
import 'reminders_sheet.dart';
import 'widgets.dart';

class GlobalHeader extends ConsumerWidget {
  const GlobalHeader({super.key});

  /// Same city-pick path the profile screen uses — a pick updates the
  /// profile (lat/lng/tz), so prayer times, the header and the bells all
  /// follow automatically.
  Future<void> _pickCity(BuildContext context, WidgetRef ref) async {
    final picked = await showCityPicker(context);
    if (picked == null) return;
    await ref
        .read(profileProvider.notifier)
        .update(
          city: picked.nameBn,
          lat: picked.lat,
          lng: picked.lng,
          tz: picked.tz,
        );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(profileProvider);
    final lang = context.lang;
    final bn = context.isBn;
    final now = ref.watch(headerNowProvider);
    final bnDate = banglaDate(now);
    // C-W3g: user ±2 + admin /api/config ±2 (clamped ±4) — the admin's
    // moon-sighting correction propagates to every rendered Hijri date.
    final hijri = hijriDate(
      now,
      adjustDays: ref.watch(effectiveHijriAdjustProvider),
    );
    final city = findCity(profile.city);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SLSpacing.s16,
        SLSpacing.s8,
        SLSpacing.s4,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SLBrandMark(size: 32),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  context.t('app_name'),
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                  softWrap: false,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              _HeaderAction(
                icon: PhosphorIconsRegular.bell,
                tooltipKey: 'header_notifications',
                onTap: () => showNotificationsSheet(context),
                dot: ref.watch(inboxUnreadProvider) > 0,
              ),
              _HeaderAction(
                icon: PhosphorIconsRegular.clock,
                tooltipKey: 'header_reminders',
                onTap: () => showRemindersSheet(context),
              ),
              _HeaderAction(
                icon: PhosphorIconsRegular.userCircle,
                tooltipKey: 'more_profile',
                onTap: () => context.push('/more/profile'),
              ),
              // C-W3d: sync state (idle/syncing/pending/dead + the sheet on
              // tap) lives in the header trailing — the most natural spot.
              const SyncBadge(),
            ],
          ),
          // the prototype's order: the city as a small outlined pill (tap to
          // change), then the three calendars on one quiet line
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                key: const ValueKey('header_city'),
                borderRadius: SLRadius.brPill,
                onTap: () => _pickCity(context, ref),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: SLSpacing.minTapTarget),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: 1,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: SLRadius.brPill,
                        border: Border.all(color: theme.colorScheme.outline),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.mapPin,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            city?.nameBn ?? profile.city,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            PhosphorIconsBold.caretDown,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Text(
                '${bn ? toBn(now.day) : now.day} ${S.tr(lang, 'month_${now.month}')} '
                '${bn ? toBn(now.year) : now.year} · ${bnDate.formatted} · ${hijri.formatted}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Compact 40×44 header action — 44 keeps the vertical tap target, 40 keeps
/// five clusters fitting on a 360 dp phone.
class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.tooltipKey,
    required this.onTap,
    this.dot = false,
  });

  final IconData icon;
  final String tooltipKey;
  final VoidCallback onTap;

  /// An unread marker (the bell, when the inbox has unread messages).
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.t(tooltipKey),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SLRadius.sm),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(icon, size: 22, color: cs.onSurfaceVariant),
              if (dot)
                Positioned(
                  key: const ValueKey('header_unread_dot'),
                  top: 10,
                  right: 9,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: cs.error,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 1.5),
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

/// The five root tabs' frame (BNAV-01): the [GlobalHeader] above [body],
/// sliding away while the member scrolls DOWN the content and coming back
/// the moment they scroll UP (or reach the top) — the header used to either
/// stay pinned (আমল, দাওয়াত — a fifth of a small screen) or scroll away for
/// good (হোম, ইলম, আরও).
class ScrollAwareHeader extends StatefulWidget {
  const ScrollAwareHeader({super.key, required this.body});
  final Widget body;

  @override
  State<ScrollAwareHeader> createState() => _ScrollAwareHeaderState();
}

class _ScrollAwareHeaderState extends State<ScrollAwareHeader> {
  bool _visible = true;

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false; // chips rows, tab swipes
    if (n is! ScrollUpdateNotification) return false;
    final delta = n.scrollDelta ?? 0;
    final nearTop = n.metrics.pixels <= n.metrics.minScrollExtent + 24;
    // a small dead-band so a resting finger does not flicker the header
    if (delta > 4 && !nearTop && _visible) setState(() => _visible = false);
    if ((delta < -4 || nearTop) && !_visible) setState(() => _visible = true);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRect(
          child: AnimatedAlign(
            key: const ValueKey('scroll_aware_header'),
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.bottomCenter,
            heightFactor: _visible ? 1 : 0,
            child: const GlobalHeader(),
          ),
        ),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: _onScroll,
            child: widget.body,
          ),
        ),
      ],
    );
  }
}
