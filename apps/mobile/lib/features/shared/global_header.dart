/// Global chrome (C-W4a): the shared header for the five MAIN tab screens —
/// logo mark, tappable location row (city picker), the triple calendar date
/// bar (Gregorian + Bangla + Hijri with the effective ±4 adjustment from
/// C-W3g), and the trailing action cluster: notification bell, reminder
/// clock, profile, sync badge.
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
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show effectiveHijriAdjustProvider;
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
    await ref.read(profileProvider.notifier).update(
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
              // Logo mark — the splash monogram (gold circle + star), no new
              // asset generation.
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(
                  color: SLColors.gold,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Icon(
                    Icons.star,
                    color: SLColors.primaryDeep,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: InkWell(
                  borderRadius: SLRadius.brSm,
                  onTap: () => _pickCity(context, ref),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          PhosphorIconsFill.mapPin,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            city?.nameBn ?? profile.city,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          PhosphorIconsBold.caretDown,
                          size: 14,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              _HeaderAction(
                icon: PhosphorIconsRegular.bell,
                tooltipKey: 'header_notifications',
                onTap: () => showNotificationsSheet(context),
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
          const SizedBox(height: 2),
          Text(
            '${bn ? toBn(now.day) : now.day} ${S.tr(lang, 'month_${now.month}')} '
            '${bn ? toBn(now.year) : now.year} · ${bnDate.formatted} · ${hijri.formatted}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
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
  });

  final IconData icon;
  final String tooltipKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.t(tooltipKey),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SLRadius.sm),
        child: SizedBox(
          width: 40,
          height: 44,
          child: Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
