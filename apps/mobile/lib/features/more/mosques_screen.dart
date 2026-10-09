/// আমার মসজিদ — two things in one place:
///  • "আমার মসজিদ": the mosques the reader starred (kept on the phone);
///  • "কাছের মসজিদ": every mosque within 5 km, anywhere in Bangladesh
///    (GET /api/mosques/near: OpenStreetMap + the Foundation's verified
///    list), measured from the phone's location or the profile city.
/// Each says how far, how long on foot and which way ("২৪০ মিটার · হেঁটে
/// ~৩ মিনিট · উত্তর-পূর্বে"); a tap opens the mosque: directions (Google
/// Maps), the map, star. Without internet: the last list near here, else
/// the Foundation's bundled list. The ম্যাপ view is the offline radar.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/external_urls.dart';
import '../../core/location_service.dart';
import '../../core/mosque_format.dart';
import '../../core/qibla.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/content_models.dart';
import '../../services/mosque_store.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'mosque_radar.dart';

/// Pure: mosques sorted by great-circle distance from (lat, lng).
/// Exported for unit tests (sorting from real coords vs city fallback).
List<MosqueInfo> sortMosquesByDistance(
  Iterable<MosqueInfo> mosques,
  double lat,
  double lng,
) {
  final list = mosques.toList();
  list.sort(
    (a, b) => distanceKm(
      lat,
      lng,
      a.lat,
      a.lng,
    ).compareTo(distanceKm(lat, lng, b.lat, b.lng)),
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

/// Where the nearby list came from.
enum _NearSource { live, cachedOffline, curatedOffline }

/// What the distances are measured from: still finding the phone, the
/// phone's own fix, or (no location) the profile city's centre — then no
/// distance is shown, it would not be the reader's.
enum _Where { locating, gps, city }

const _firstPage = 15;

class MosquesScreen extends ConsumerStatefulWidget {
  const MosquesScreen({super.key});

  @override
  ConsumerState<MosquesScreen> createState() => _MosquesScreenState();
}

class _MosquesScreenState extends ConsumerState<MosquesScreen>
    with WidgetsBindingObserver {
  static const _store = MosqueStore();

  CitySnap? _fix;
  _Where _where = _Where.locating;

  /// Why there is no fix (city mode): decides the primer's button.
  LocationGate _gate = LocationGate.requestPermission;
  bool _locating = false;
  bool _mapView = false;
  bool _showAll = false;
  String? _selectedId;

  List<MosqueInfo> _saved = const [];
  List<MosqueInfo> _near = const [];
  _NearSource _source = _NearSource.live;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadSaved());
    unawaited(_start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Back from the phone's settings (permission or location turned on):
  /// try again without another tap.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _where == _Where.city &&
        (_gate == LocationGate.openSettings ||
            _gate == LocationGate.openLocationSettings)) {
      unawaited(_start());
    }
  }

  ({double lat, double lng, bool fromGps}) get _origin {
    final p = ref.read(profileProvider);
    return mosqueListOrigin(_where == _Where.gps ? _fix : null, p.lat, p.lng);
  }

  /// The origin for distances, or null when there is no fix (city mode) —
  /// a distance from the city centre would not be the reader's.
  ({double lat, double lng})? get _distanceOrigin =>
      _where == _Where.gps ? (lat: _fix!.lat, lng: _fix!.lng) : null;

  Future<void> _loadSaved() async {
    final list = await _store.saved();
    if (mounted) setState(() => _saved = list);
  }

  /// Opening the screen never pops a permission dialog. With permission
  /// already given, the phone's last known fix shows the list at once and
  /// a fresh fix refines it; without, the screen offers to use location.
  Future<void> _start() async {
    final loc = ref.read(locationServiceProvider);
    final gate = await loc.currentGate();
    if (!mounted) return;
    if (gate != LocationGate.fetchPosition) {
      _toCity(gate);
      return;
    }
    if (_where != _Where.gps) setState(() => _where = _Where.locating);
    final last = await loc.lastKnownSnapIfGranted();
    if (!mounted) return;
    if (last != null) _useFix(last);
    final fresh = await loc.currentSnapIfGranted();
    if (!mounted) return;
    if (fresh != null) {
      final moved =
          _fix == null ||
          distanceKm(_fix!.lat, _fix!.lng, fresh.lat, fresh.lng) > 0.05;
      if (moved) {
        _useFix(fresh);
      } else {
        setState(() => _fix = fresh); // same place, better accuracy
      }
    } else if (_fix == null) {
      _toCity(LocationGate.blocked);
    }
  }

  void _useFix(CitySnap snap) {
    setState(() {
      _fix = snap;
      _where = _Where.gps;
    });
    unawaited(_loadNear());
  }

  void _toCity(LocationGate why) {
    setState(() {
      _where = _Where.city;
      _gate = why;
      _mapView = false;
    });
  }

  /// The nearby list: the server, else the last list near here, else the
  /// Foundation's own (bundled) list.
  Future<void> _loadNear() async {
    // only the reader's own fix makes a list "near"
    if (_where != _Where.gps) return;
    final seq = ++_seq;
    final o = _origin;
    setState(() {
      _loading = true;
      _showAll = false;
    });
    List<MosqueInfo> list;
    _NearSource source;
    try {
      final res = await ref
          .read(apiProvider)
          .mosquesNear(o.lat, o.lng)
          .timeout(const Duration(seconds: 12));
      list = res.mosques;
      source = _NearSource.live;
      unawaited(_store.rememberNear(o.lat, o.lng, list));
    } catch (_) {
      final cached = await _store.nearFromCache(o.lat, o.lng);
      if (cached != null) {
        list = cached;
        source = _NearSource.cachedOffline;
      } else {
        final pack = await ContentPack.mosques().catchError(
          (_) => <MosqueInfo>[],
        );
        list = sortMosquesByDistance(
          pack,
          o.lat,
          o.lng,
        ).where((m) => distanceKm(o.lat, o.lng, m.lat, m.lng) <= 30).toList();
        source = _NearSource.curatedOffline;
      }
    }
    if (!mounted || seq != _seq) return;
    setState(() {
      _near = sortMosquesByDistance(list, o.lat, o.lng);
      _source = source;
      _loading = false;
    });
  }

  Future<void> _locate() async {
    setState(() => _locating = true);
    try {
      final snap = await ref.read(locationServiceProvider).currentCitySnap();
      if (mounted) _useFix(snap);
    } on LocationFailureException catch (e) {
      if (mounted) {
        if (_where == _Where.city) {
          setState(
            () => _gate = switch (e.failure) {
              LocationFailure.permissionDeniedForever =>
                LocationGate.openSettings,
              LocationFailure.serviceOff => LocationGate.openLocationSettings,
              _ => LocationGate.requestPermission,
            },
          );
        }
        final msg = switch (e.failure) {
          LocationFailure.serviceOff => context.t('gps_service_off'),
          LocationFailure.permissionDenied => context.t(
            'gps_permission_denied',
          ),
          LocationFailure.permissionDeniedForever => context.t(
            'gps_permission_denied_forever',
          ),
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

  bool _isSaved(MosqueInfo m) => _saved.any((s) => s.id == m.id);

  Future<void> _toggleSaved(MosqueInfo m) async {
    final saved = _isSaved(m);
    final next = saved
        ? _saved.where((s) => s.id != m.id).toList()
        : [..._saved, m];
    setState(() => _saved = next);
    await _store.setSaved(next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            context.t(saved ? 'mosques_removed_snack' : 'mosques_saved_snack'),
          ),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<void> _open(String url) async {
    final ok = await openExternalApp(url);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('donation_open_failed'))),
      );
    }
  }

  Future<void> _showMosque(MosqueInfo m) {
    final o = _distanceOrigin;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => _MosqueSheet(
          mosque: m,
          origin: o,
          saved: _isSaved(m),
          onDirections: () => _open(mapsDirectionsUrl(m.lat, m.lng)),
          onMap: () => _open(mapsPlaceUrl(m.lat, m.lng)),
          onToggleSaved: () async {
            await _toggleSaved(m);
            setSheet(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final o = _origin;
    final d = _distanceOrigin;
    final cityMode = _where == _Where.city;
    // The one answer people come for first: the nearest mosque (saved or
    // not — its star says which). Then the reader's own, then the rest.
    final nearest = !cityMode && _near.isNotEmpty ? _near.first : null;
    final mine = [
      for (final m
          in d == null ? _saved : sortMosquesByDistance(_saved, d.lat, d.lng))
        if (m.id != nearest?.id) m,
    ];
    final savedIds = {for (final s in _saved) s.id};
    final rest = [
      for (final m in _near)
        if (m.id != nearest?.id && !savedIds.contains(m.id)) m,
    ];
    final shown = _showAll ? rest : rest.take(_firstPage).toList();

    Widget tile(MosqueInfo m) => _MosqueTile(
      mosque: m,
      origin: d,
      saved: _isSaved(m),
      onTap: () => _showMosque(m),
      onToggleSaved: () => _toggleSaved(m),
    );

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_mosque')),
      ),
      body: RefreshIndicator(
        onRefresh: cityMode ? _start : _loadNear,
        child: ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            // the compass view needs the reader's own position
            if (_where == _Where.gps) _viewToggle(context),
            _whereCard(context, theme, bn),
            if (!cityMode && !_loading && _source != _NearSource.live)
              _OfflineNote(
                text: context.t(
                  _source == _NearSource.cachedOffline
                      ? 'mosques_offline'
                      : 'mosques_offline_curated',
                ),
              ),
            if (_mapView && _where == _Where.gps)
              ..._radar(context, theme, bn, o)
            else if (cityMode) ...[
              // without a position there is no "near": the reader's own
              // mosques (no distance), and Google Maps, which can use the
              // phone's location itself
              if (mine.isNotEmpty) ...[
                SectionHeader(
                  context.t('mosques_my'),
                  icon: PhosphorIconsRegular.star,
                ),
                for (final m in mine) tile(m),
              ],
              const SizedBox(height: SLSpacing.s8),
              OutlinedButton.icon(
                icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
                label: Text(context.t('mosques_maps_search')),
                onPressed: () => _open(mapsSearchUrl('mosque')),
              ),
            ] else ...[
              if (_loading) ...[
                const SizedBox(height: SLSpacing.s8),
                const Skeleton(height: 168),
                const SizedBox(height: SLSpacing.s16),
                const Skeleton(height: 64, count: 3),
              ] else if (nearest == null)
                _HintCard(text: context.t('mosques_none'))
              else ...[
                const SizedBox(height: SLSpacing.s8),
                _NearestCard(
                  key: const ValueKey('mosque_nearest'),
                  mosque: nearest,
                  origin: d!,
                  saved: _isSaved(nearest),
                  onTap: () => _showMosque(nearest),
                  onDirections: () =>
                      _open(mapsDirectionsUrl(nearest.lat, nearest.lng)),
                  onToggleSaved: () => _toggleSaved(nearest),
                ),
                // ── আমার মসজিদ (only once there is one) ──
                if (mine.isNotEmpty) ...[
                  SectionHeader(
                    context.t('mosques_my'),
                    icon: PhosphorIconsRegular.star,
                  ),
                  for (final m in mine) tile(m),
                ],
                // ── the rest, nearest first ──
                if (rest.isNotEmpty) ...[
                  SectionHeader(
                    context.t('mosques_more_nearby'),
                    icon: PhosphorIconsRegular.mosque,
                    action: Text(
                      context
                          .t('mosques_nearby_count')
                          .replaceAll(
                            '%n',
                            bn ? toBn(_near.length) : '${_near.length}',
                          ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (_saved.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                      child: Text(
                        context.t('mosques_star_tip'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final m in shown) tile(m),
                  if (!_showAll && rest.length > _firstPage)
                    Padding(
                      padding: const EdgeInsets.only(top: SLSpacing.s4),
                      child: TextButton(
                        onPressed: () => setState(() => _showAll = true),
                        child: Text(
                          context
                              .t('mosques_show_more')
                              .replaceAll(
                                '%n',
                                bn
                                    ? toBn(rest.length - _firstPage)
                                    : '${rest.length - _firstPage}',
                              ),
                        ),
                      ),
                    ),
                ],
              ],
              const SizedBox(height: SLSpacing.s12),
              OutlinedButton.icon(
                icon: const Icon(
                  PhosphorIconsRegular.magnifyingGlass,
                  size: 18,
                ),
                label: Text(context.t('mosque_search_more')),
                onPressed: () =>
                    _open(mapsNearbySearchUrl('mosque', o.lat, o.lng)),
              ),
            ],
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('mosques_attribution'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _radar(
    BuildContext context,
    ThemeData theme,
    bool bn,
    ({double lat, double lng, bool fromGps}) o,
  ) {
    final seen = <String>{};
    final pins = [
      for (final m in [..._saved, ..._near])
        if (seen.add(m.id)) m,
    ];
    final near = sortMosquesByDistance(pins, o.lat, o.lng).take(15).toList();
    if (near.isEmpty) {
      return [
        if (_loading)
          const Skeleton(height: 240)
        else
          _HintCard(text: context.t('mosques_none')),
      ];
    }
    final selected = near.firstWhere(
      (m) => m.id == _selectedId,
      orElse: () => near.first,
    );
    return [
      AppCard(
        child: MosqueRadar(
          mosques: near,
          lat: o.lat,
          lng: o.lng,
          selectedId: selected.id,
          onSelect: (m) => setState(() => _selectedId = m.id),
        ),
      ),
      const SizedBox(height: SLSpacing.s8),
      _MosqueTile(
        key: const ValueKey('mosque_selected'),
        mosque: selected,
        origin: _distanceOrigin,
        saved: _isSaved(selected),
        onTap: () => _showMosque(selected),
        onToggleSaved: () => _toggleSaved(selected),
      ),
      const SizedBox(height: SLSpacing.s4),
      FilledButton.icon(
        key: const ValueKey('mosque_directions'),
        icon: const Icon(PhosphorIconsRegular.navigationArrow, size: 18),
        label: Text(context.t('mosque_directions_btn')),
        onPressed: () => _open(mapsDirectionsUrl(selected.lat, selected.lng)),
      ),
    ];
  }

  Widget _viewToggle(BuildContext context) => Padding(
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

  /// Where the distances come from. With a fix: a quiet line and a
  /// re-locate button. Without: a primer that says why location helps and
  /// offers it (or the settings that can turn it back on).
  Widget _whereCard(BuildContext context, ThemeData theme, bool bn) {
    final cs = theme.colorScheme;
    if (_where == _Where.locating) {
      return Padding(
        padding: const EdgeInsets.only(bottom: SLSpacing.s8),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: SLSpacing.s12),
            Expanded(
              child: Text(
                context.t('mosques_locating'),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (_where == _Where.gps) {
      final acc = _fix!.accuracyM.round();
      return Padding(
        padding: const EdgeInsets.only(bottom: SLSpacing.s4),
        child: Row(
          children: [
            Icon(PhosphorIconsRegular.crosshair, size: 20, color: cs.primary),
            const SizedBox(width: SLSpacing.s8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    // a good fix needs no number (and the Bengali font has
                    // no ± sign); a rough one says so
                    acc > 100
                        ? context
                              .t('mosques_from_location_rough')
                              .replaceAll('%m', bn ? toBn(acc) : '$acc')
                        : context.t('mosques_from_location'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    context.t('mosques_privacy'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (_locating)
              const Padding(
                padding: EdgeInsets.all(SLSpacing.s12),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else
              IconButton(
                tooltip: context.t('mosques_relocate'),
                onPressed: _locate,
                icon: const Icon(PhosphorIconsRegular.arrowsClockwise),
              ),
          ],
        ),
      );
    }
    // no fix: the primer — why location helps, and the one way to turn it on
    final (label, hint, onPressed) = switch (_gate) {
      LocationGate.openSettings => (
        context.t('mosques_primer_settings'),
        context.t('mosques_primer_settings_hint'),
        () => unawaited(LocationService.openAppSettings()),
      ),
      LocationGate.openLocationSettings => (
        context.t('mosques_primer_gps_off'),
        context.t('mosques_primer_gps_off_hint'),
        () => unawaited(LocationService.openLocationSettings()),
      ),
      _ => (
        context.t('mosques_primer_btn'),
        context.t('mosques_primer_body'),
        () => unawaited(_locate()),
      ),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: Container(
        key: const ValueKey('mosques_primer'),
        padding: const EdgeInsets.all(SLSpacing.s16),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.08),
          borderRadius: SLRadius.brLg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    PhosphorIconsRegular.crosshair,
                    size: 22,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    context.t('mosques_primer_title'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(hint, style: theme.textTheme.bodyMedium),
            const SizedBox(height: SLSpacing.s12),
            if (_locating)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(SLSpacing.s8),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else
              FilledButton.icon(
                onPressed: onPressed,
                icon: const Icon(PhosphorIconsRegular.crosshair, size: 18),
                label: Text(label),
              ),
          ],
        ),
      ),
    );
  }
}

/// "২৪০ মিটার · হেঁটে ~৩ মিনিট · উত্তর-পূর্বে"
String? _meta(
  BuildContext context,
  MosqueInfo m,
  ({double lat, double lng})? origin,
) {
  if (origin == null) return null;
  final (:lat, :lng) = origin;
  final bn = context.isBn;
  final metres = distanceKm(lat, lng, m.lat, m.lng) * 1000;
  return [
    distanceLabel(metres, bengali: bn),
    ?walkLabel(metres, bengali: bn),
    if (metres >= 30)
      directionWord(bearingDeg(lat, lng, m.lat, m.lng), bengali: bn),
  ].join(' · ');
}

String _place(MosqueInfo m) => [
  if (m.addressBn.trim().isNotEmpty) m.addressBn.trim(),
  if ((m.area ?? '').trim().isNotEmpty && !m.addressBn.contains(m.area!.trim()))
    m.area!.trim(),
].join(', ');

/// "সবচেয়ে কাছে": the nearest mosque as the screen's one clear answer —
/// how far, on foot, which way, and the way there in one tap.
class _NearestCard extends StatelessWidget {
  const _NearestCard({
    super.key,
    required this.mosque,
    required this.origin,
    required this.saved,
    required this.onTap,
    required this.onDirections,
    required this.onToggleSaved,
  });
  final MosqueInfo mosque;
  final ({double lat, double lng}) origin;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onDirections;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final place = _place(mosque);
    final metres =
        distanceKm(origin.lat, origin.lng, mosque.lat, mosque.lng) * 1000;
    final rest = [
      ?walkLabel(metres, bengali: bn),
      if (metres >= 30)
        directionWord(
          bearingDeg(origin.lat, origin.lng, mosque.lat, mosque.lng),
          bengali: bn,
        ),
    ].join(' · ');
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsetsDirectional.fromSTEB(
        SLSpacing.s16,
        SLSpacing.s12,
        SLSpacing.s4,
        SLSpacing.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SLSpacing.s8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.10),
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  context.t('mosques_nearest'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (mosque.verified) ...[
                const SizedBox(width: SLSpacing.s8),
                _VerifiedBadge(),
              ],
              const Spacer(),
              _StarButton(saved: saved, onPressed: onToggleSaved),
            ],
          ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: SLSpacing.s12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  mosque.named ? mosque.nameBn : context.t('mosques_unnamed'),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: mosque.named ? null : cs.onSurfaceVariant,
                  ),
                ),
                if (place.isNotEmpty)
                  Text(
                    place,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: SLSpacing.s12),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: distanceLabel(metres, bengali: bn),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: cs.primary,
                        ),
                      ),
                      if (rest.isNotEmpty)
                        TextSpan(
                          text: '  ·  $rest',
                          style: theme.textTheme.bodyMedium,
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: SLSpacing.s12),
                FilledButton.icon(
                  key: const ValueKey('mosque_nearest_directions'),
                  icon: const Icon(
                    PhosphorIconsRegular.navigationArrow,
                    size: 18,
                  ),
                  label: Text(context.t('mosque_directions_btn')),
                  onPressed: onDirections,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StarButton extends StatelessWidget {
  const _StarButton({required this.saved, required this.onPressed});
  final bool saved;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.t('mosques_star_a11y'),
    onPressed: onPressed,
    icon: Icon(
      saved ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
      color: saved
          ? SLColors.goldDeep
          : Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// One row: name (and where), the distance on the trailing side where the
/// eye compares it down the list, and the star.
class _MosqueTile extends StatelessWidget {
  const _MosqueTile({
    super.key,
    required this.mosque,
    required this.origin,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });
  final MosqueInfo mosque;

  /// Null without the reader's own fix: no distance then.
  final ({double lat, double lng})? origin;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final o = origin;
    final metres = o == null
        ? null
        : distanceKm(o.lat, o.lng, mosque.lat, mosque.lng) * 1000;
    final where = [
      if (_place(mosque).isNotEmpty) _place(mosque),
      if (metres != null && metres >= 30)
        directionWord(
          bearingDeg(o!.lat, o.lng, mosque.lat, mosque.lng),
          bengali: bn,
        ),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(
          SLSpacing.s16,
          SLSpacing.s12,
          SLSpacing.s4,
          SLSpacing.s12,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: mosque.named
                              ? mosque.nameBn
                              : context.t('mosques_unnamed'),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: mosque.named ? null : cs.onSurfaceVariant,
                          ),
                        ),
                        if (mosque.verified) ...[
                          const TextSpan(text: '  '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: _VerifiedBadge(),
                          ),
                        ],
                      ],
                    ),
                    // three lines: long mapped names ("Kalachadpur
                    // Paschimpara Jame Masjid") at large text
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (where.isNotEmpty)
                    Text(
                      where,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (metres != null) ...[
              const SizedBox(width: SLSpacing.s8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    distanceLabel(metres, bengali: bn),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (walkLabel(metres, bengali: bn) case final walk?)
                    Semantics(
                      label: walk,
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            PhosphorIconsRegular.personSimpleWalk,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          Text(
                            walk
                                .replaceFirst(bn ? 'হেঁটে ' : '', '')
                                .replaceFirst(' walk', ''),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
            _StarButton(saved: saved, onPressed: onToggleSaved),
          ],
        ),
      ),
    );
  }
}

class _VerifiedBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: SLRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(PhosphorIconsRegular.sealCheck, size: 12, color: cs.primary),
          const SizedBox(width: 2),
          Text(
            context.t('mosques_verified'),
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: cs.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MosqueSheet extends StatelessWidget {
  const _MosqueSheet({
    required this.mosque,
    required this.origin,
    required this.saved,
    required this.onDirections,
    required this.onMap,
    required this.onToggleSaved,
  });
  final MosqueInfo mosque;
  final ({double lat, double lng})? origin;
  final bool saved;
  final VoidCallback onDirections;
  final VoidCallback onMap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final place = _place(mosque);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s20,
          0,
          SLSpacing.s20,
          SLSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              mosque.named ? mosque.nameBn : context.t('mosques_unnamed'),
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if ((mosque.nameEn ?? '').isNotEmpty &&
                mosque.nameEn != mosque.nameBn)
              Text(
                mosque.nameEn!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            if (mosque.verified) ...[
              const SizedBox(height: SLSpacing.s4),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _VerifiedBadge(),
              ),
            ],
            if (place.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s8),
              Text(place, style: theme.textTheme.bodyMedium),
            ],
            if (_meta(context, mosque, origin) case final meta?) ...[
              const SizedBox(height: SLSpacing.s8),
              Text(
                meta,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const SizedBox(height: SLSpacing.s16),
            FilledButton.icon(
              icon: const Icon(PhosphorIconsRegular.navigationArrow, size: 18),
              label: Text(context.t('mosque_directions_btn')),
              onPressed: onDirections,
            ),
            const SizedBox(height: SLSpacing.s8),
            OutlinedButton.icon(
              icon: Icon(
                saved ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                size: 18,
                color: saved ? SLColors.goldDeep : null,
              ),
              label: Text(context.t(saved ? 'mosques_unsave' : 'mosques_save')),
              onPressed: onToggleSaved,
            ),
            TextButton.icon(
              icon: const Icon(PhosphorIconsRegular.mapPin, size: 18),
              label: Text(context.t('mosques_show_on_map')),
              onPressed: onMap,
            ),
          ],
        ),
      ),
    );
  }
}

class _HintCard extends StatelessWidget {
  const _HintCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: SLSpacing.s8),
      padding: const EdgeInsets.all(SLSpacing.s16),
      decoration: BoxDecoration(
        borderRadius: SLRadius.brLg,
        border: Border.all(color: theme.colorScheme.outline),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SLSpacing.s8),
      child: Row(
        children: [
          Icon(
            PhosphorIconsRegular.wifiSlash,
            size: 16,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
