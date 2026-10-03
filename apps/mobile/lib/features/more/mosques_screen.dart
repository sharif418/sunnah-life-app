/// আমার মসজিদ — bundled mosque list, distance-sorted either from the
/// profile city center (default) or from the real GPS fix when the user
/// allows location. Two views (FEAT-12): তালিকা and ম্যাপ — the map is a
/// tile-free radar (mosque_radar.dart: offline, no new dependency); every
/// mosque offers "পথ দেখুন" (Google Maps directions), and "আশেপাশের আরও
/// মসজিদ" searches Maps for the ones the bundled pack does not list.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/external_urls.dart';
import '../../core/location_service.dart';
import '../../core/qibla.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'mosque_radar.dart';
import '../../design/phosphor_icons.dart';

/// Pure: mosques sorted by great-circle distance from (lat, lng).
/// Exported for unit tests (sorting from real coords vs city fallback).
List<MosqueInfo> sortMosquesByDistance(
  Iterable<MosqueInfo> mosques,
  double lat,
  double lng,
) {
  final list = mosques.toList();
  list.sort(
    (a, b) => distanceKm(lat, lng, a.lat, a.lng).compareTo(
      distanceKm(lat, lng, b.lat, b.lng),
    ),
  );
  return list;
}

/// Pure: the origin the list is measured from — the GPS fix when present,
/// the profile city center otherwise.
({double lat, double lng, bool fromGps}) mosqueListOrigin(
  CitySnap? fix,
  double cityLat,
  double cityLng,
) => fix == null
    ? (lat: cityLat, lng: cityLng, fromGps: false)
    : (lat: fix.lat, lng: fix.lng, fromGps: true);

class MosquesScreen extends ConsumerStatefulWidget {
  const MosquesScreen({super.key});

  @override
  ConsumerState<MosquesScreen> createState() => _MosquesScreenState();
}

class _MosquesScreenState extends ConsumerState<MosquesScreen> {
  CitySnap? _fix;
  bool _locating = false;
  bool _mapView = false;
  String? _selectedId;

  Future<void> _open(String url) async {
    final ok = await openExternalApp(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('donation_open_failed'))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // Silent probe: uses location only if permission is ALREADY granted —
    // opening this screen never pops a permission dialog.
    _silentProbe();
  }

  Future<void> _silentProbe() async {
    final snap = await const LocationService().currentSnapIfGranted();
    if (mounted && snap != null) setState(() => _fix = snap);
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final snap = await const LocationService().currentCitySnap();
      if (mounted) setState(() => _fix = snap);
    } on LocationFailureException catch (e) {
      if (mounted) {
        final msg = switch (e.failure) {
          LocationFailure.serviceOff => context.t('gps_service_off'),
          LocationFailure.permissionDenied => context.t('gps_permission_denied'),
          LocationFailure.permissionDeniedForever =>
            context.t('gps_permission_denied_forever'),
          LocationFailure.timeout ||
          LocationFailure.unavailable => context.t('gps_unavailable'),
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), duration: const Duration(seconds: 3)),
        );
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_mosque')),
      ),
      body: FutureBuilder<List<MosqueInfo>>(
        future: ContentPack.mosques(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 5);
          }
          final mosques = snap.data ?? const <MosqueInfo>[];
          if (mosques.isEmpty) {
            return EmptyState(
                message: context.t('empty_generic'),
                icon: PhosphorIconsRegular.mosque);
          }
          final origin = mosqueListOrigin(_fix, profile.lat, profile.lng);
          final sorted = sortMosquesByDistance(
            mosques,
            origin.lat,
            origin.lng,
          );
          if (_mapView) {
            final near = sorted.take(15).toList();
            final selected = near.firstWhere(
              (m) => m.id == _selectedId,
              orElse: () => near.first,
            );
            final km = distanceKm(origin.lat, origin.lng, selected.lat, selected.lng);
            final kmText = km.toStringAsFixed(1);
            return ListView(
              padding: const EdgeInsets.all(SLSpacing.s16),
              children: [
                _modeHeader(context, theme, bn, profile),
                AppCard(
                  child: MosqueRadar(
                    mosques: near,
                    lat: origin.lat,
                    lng: origin.lng,
                    selectedId: selected.id,
                    onSelect: (m) => setState(() => _selectedId = m.id),
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                AppCard(
                  key: const ValueKey('mosque_selected'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selected.nameBn,
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      Text(selected.addressBn, style: theme.textTheme.bodySmall),
                      const SizedBox(height: SLSpacing.s4),
                      Text(
                        '${bn ? toBn(kmText) : kmText} ${context.t('unit_km')}',
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: SLSpacing.s8),
                      FilledButton.icon(
                        key: const ValueKey('mosque_directions'),
                        icon: const Icon(PhosphorIconsRegular.navigationArrow, size: 18),
                        label: Text(context.t('mosque_directions_btn')),
                        onPressed: () => _open(mapsDirectionsUrl(selected.lat, selected.lng)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                OutlinedButton.icon(
                  icon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
                  label: Text(context.t('mosque_search_more')),
                  onPressed: () => _open(mapsNearbySearchUrl('mosque', origin.lat, origin.lng)),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(SLSpacing.s16),
            itemCount: sorted.length + 1, // +1 for the mode header
            itemBuilder: (context, i) {
              if (i == 0) return _modeHeader(context, theme, bn, profile);
              final m = sorted[i - 1];
              final km = distanceKm(origin.lat, origin.lng, m.lat, m.lng);
              final bearing = bearingDeg(origin.lat, origin.lng, m.lat, m.lng);
              return AppCard(
                onTap: () => _open(mapsDirectionsUrl(m.lat, m.lng)),
                padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s12, vertical: SLSpacing.s8),
                child: Row(
                  children: [
                    Icon(PhosphorIconsFill.mosque,
                        size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.nameBn,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(m.addressBn,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    // Direction arrow: bearing mosque-from-user (true north),
                    // so the row orients the user without a map.
                    Semantics(
                      label: context.t('mosque_direction'),
                      child: Transform.rotate(
                        angle: bearing * math.pi / 180,
                        child: Icon(
                          PhosphorIconsRegular.navigationArrow,
                          size: 18,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Column(
                      children: [
                        Text(
                          '${bn ? toBn(km.round()) : km.round()}',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text(context.t('unit_km'), style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Active-mode label + the switch: "near me" (prompts) ↔ city center.
  Widget _modeHeader(
    BuildContext context,
    ThemeData theme,
    bool bn,
    ProfileState profile,
  ) {
    final fromGps = _fix != null;
    final label = fromGps
        ? '${context.t('mosques_from_location')} (±${bn ? toBn(_fix!.accuracyM.round()) : _fix!.accuracyM.round()} ${context.t('unit_m')})'
        : '${context.t('mosques_from_city')}: ${profile.city}';
    final toggle = Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: SegmentedButton<bool>(
        key: const ValueKey('mosque_view_toggle'),
        segments: [
          ButtonSegment(
            value: false,
            icon: const Icon(PhosphorIconsRegular.listChecks, size: 18),
            label: Text(context.t('mosque_view_list')),
          ),
          ButtonSegment(
            value: true,
            icon: const Icon(PhosphorIconsRegular.compass, size: 18),
            label: Text(context.t('mosque_view_map')),
          ),
        ],
        selected: {_mapView},
        onSelectionChanged: (s) => setState(() => _mapView = s.first),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [toggle, _originCard(context, theme, fromGps, label)],
    );
  }

  Widget _originCard(
    BuildContext context,
    ThemeData theme,
    bool fromGps,
    String label,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s12),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s12, vertical: SLSpacing.s4),
          child: Row(
            children: [
              Icon(
                fromGps ? PhosphorIconsRegular.crosshair : PhosphorIconsRegular.buildings,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (_locating)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                TextButton(
                  onPressed: () {
                    if (fromGps) {
                      setState(() => _fix = null); // back to city center
                    } else {
                      _locate();
                    }
                  },
                  child: Text(
                    fromGps
                        ? context.t('mosques_use_city')
                        : context.t('mosques_near_me'),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
