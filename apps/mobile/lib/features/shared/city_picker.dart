/// City picker sheet — all 64 BD districts + international cities, with
/// Bengali/English search and a "find with GPS" option that snaps the fix to
/// the nearest district (manual list always remains the fallback).
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../core/cities.dart';
import '../../core/location_service.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import 'widgets.dart';
import '../../design/phosphor_icons.dart';

/// Opens the city picker and returns the chosen [CityEntry], or null.
Future<CityEntry?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<CityEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

/// GPS row lifecycle: idle → locating → confirm (tap to accept the snap) or
/// error (friendly message + recovery buttons; the list stays usable).
enum _GpsPhase { idle, locating, confirm, error }

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';
  _GpsPhase _gps = _GpsPhase.idle;
  CitySnap? _snap;
  LocationFailure? _gpsError;

  Future<void> _locate() async {
    setState(() => _gps = _GpsPhase.locating);
    try {
      final snap = await const LocationService().currentCitySnap();
      if (!mounted) return;
      setState(() {
        _snap = snap;
        _gps = _GpsPhase.confirm;
      });
    } on LocationFailureException catch (e) {
      if (!mounted) return;
      setState(() {
        _gpsError = e.failure;
        _gps = _GpsPhase.error;
      });
    }
  }

  Widget _gpsRow(BuildContext context) {
    final bn = context.isBn;
    String num(Object v) => bn ? toBn(v) : v.toString();

    switch (_gps) {
      case _GpsPhase.idle:
        return _GpsCard(
          icon: PhosphorIconsRegular.crosshair,
          title: context.t('gps_find_city'),
          subtitle: context.t('gps_find_city_hint'),
          onTap: _locate,
        );
      case _GpsPhase.locating:
        return _GpsCard(
          icon: null, // spinner
          title: context.t('gps_locating'),
          subtitle: null,
          onTap: null,
        );
      case _GpsPhase.confirm:
        final s = _snap!;
        return _GpsCard(
          icon: PhosphorIconsFill.mapPin,
          title:
              '${context.t('gps_your_location')}: ${s.city.nameBn}'
              '${s.approximate ? ' (${context.t('gps_approx')})' : ''}',
          subtitle:
              '±${num(s.accuracyM.round())} ${context.t('unit_m')}'
              '${s.approximate ? ' · ${context.t('gps_approx_note')}' : ''} · '
              '${context.t('gps_tap_confirm')}',
          onTap: () => Navigator.of(context).pop(s.city),
          highlight: true,
        );
      case _GpsPhase.error:
        final failure = _gpsError ?? LocationFailure.unavailable;
        final message = switch (failure) {
          LocationFailure.serviceOff => context.t('gps_service_off'),
          LocationFailure.permissionDenied => context.t('gps_permission_denied'),
          LocationFailure.permissionDeniedForever =>
            context.t('gps_permission_denied_forever'),
          LocationFailure.timeout ||
          LocationFailure.unavailable => context.t('gps_unavailable'),
        };
        return _GpsCard(
          // No Phosphor 2.1 equivalent (slashed location pin) — the one
          // Material glyph left in the city picker.
          icon: Icons.location_off_outlined,
          title: message,
          subtitle: null,
          onTap: _locate, // the row itself is the retry
          action: switch (failure) {
            LocationFailure.permissionDeniedForever => TextButton(
              onPressed: LocationService.openAppSettings,
              child: Text(context.t('gps_open_settings')),
            ),
            LocationFailure.serviceOff => TextButton(
              onPressed: LocationService.openLocationSettings,
              child: Text(context.t('gps_open_location_settings')),
            ),
            _ => null,
          },
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final bn = context.isBn;
    final bd = kCities.where((c) => c.isBd).toList();
    final intl = kCities.where((c) => !c.isBd).toList();
    List<CityEntry> filtered(String q, List<CityEntry> src) => q.isEmpty
        ? src
        : src
              .where(
                (c) =>
                    c.nameBn.contains(_query.trim()) ||
                    c.nameEn.toLowerCase().contains(q),
              )
              .toList();

    Widget tile(CityEntry c) {
      final lang = context.lang;
      return SizedBox(
        height: SLSpacing.minTapTarget + 8,
        child: ListTile(
          title: Text(c.nameBn, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            '${c.nameEn} — ${c.isBd ? S.tr(lang, 'country_bd') : S.tr(lang, 'country_abroad')} · UTC${c.tz >= 0 ? '+' : ''}${bn ? toBn(c.tz) : c.tz}',
            style: theme.textTheme.bodySmall,
          ),
          dense: true,
          onTap: () => Navigator.of(context).pop(c),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
        child: Column(
          children: [
            Text(
              context.t('city_picker_title'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SLSpacing.s12),
            _gpsRow(context),
            const SizedBox(height: SLSpacing.s8),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.t('onb_city_search'),
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                isDense: true,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (filtered(query, bd).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SLSpacing.s4,
                        horizontal: SLSpacing.s4,
                      ),
                      child: Text(
                        context.t('country_bd'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...filtered(query, bd).map(tile),
                  ],
                  if (filtered(query, intl).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SLSpacing.s4,
                        horizontal: SLSpacing.s4,
                      ),
                      child: Text(
                        context.t('country_intl'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...filtered(query, intl).map(tile),
                  ],
                  if (filtered(query, bd).isEmpty &&
                      filtered(query, intl).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(SLSpacing.s32),
                      child: Text(
                        context.t('city_no_match'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of the GPS flow — card-shaped, tappable, with an optional trailing
/// action (settings deep-link) that stops propagation.
class _GpsCard extends StatelessWidget {
  const _GpsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.action,
    this.highlight = false,
  });

  final IconData? icon; // null → progress spinner (locating)
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? action;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final leading = icon == null
        ? SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Icon(
            icon,
            size: 22,
            color: highlight
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          );
    final card = Card(
      margin: EdgeInsets.zero,
      color: highlight ? theme.colorScheme.primary.withValues(alpha: 0.08) : null,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: SLSpacing.s8,
          ),
          child: Row(
            children: [
              leading,
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: highlight ? FontWeight.w700 : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: SLSpacing.s4),
                action!,
              ] else if (onTap != null)
                Icon(
                  PhosphorIconsRegular.caretRight,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
            ],
          ),
        ),
      ),
    );
    // Note: the trailing settings deep-link sits inside the row, but the
    // innermost gesture-arena winner (the button) takes the tap — the row's
    // own InkWell only fires on the rest of the row.
    return card;
  }
}
