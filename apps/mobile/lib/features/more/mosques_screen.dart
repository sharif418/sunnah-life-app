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

const _firstPage = 15;

class MosquesScreen extends ConsumerStatefulWidget {
  const MosquesScreen({super.key});

  @override
  ConsumerState<MosquesScreen> createState() => _MosquesScreenState();
}

class _MosquesScreenState extends ConsumerState<MosquesScreen> {
  static const _store = MosqueStore();

  CitySnap? _fix;
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
    unawaited(_loadSaved());
    unawaited(_loadNear());
    // Silent probe: uses location only if permission is ALREADY granted —
    // opening this screen never pops a permission dialog.
    unawaited(_silentProbe());
  }

  ({double lat, double lng, bool fromGps}) get _origin {
    final p = ref.read(profileProvider);
    return mosqueListOrigin(_fix, p.lat, p.lng);
  }

  Future<void> _loadSaved() async {
    final list = await _store.saved();
    if (mounted) setState(() => _saved = list);
  }

  Future<void> _silentProbe() async {
    final snap = await const LocationService().currentSnapIfGranted();
    if (mounted && snap != null) {
      setState(() => _fix = snap);
      unawaited(_loadNear());
    }
  }

  /// The nearby list: the server, else the last list near here, else the
  /// Foundation's own (bundled) list.
  Future<void> _loadNear() async {
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
      final snap = await const LocationService().currentCitySnap();
      if (mounted) {
        setState(() => _fix = snap);
        unawaited(_loadNear());
      }
    } on LocationFailureException catch (e) {
      if (mounted) {
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
    final o = _origin;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => _MosqueSheet(
          mosque: m,
          originLat: o.lat,
          originLng: o.lng,
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
    // the origin follows the profile city when no GPS fix is in use
    ref.listen(profileProvider.select((p) => (p.lat, p.lng)), (prev, next) {
      if (_fix == null && prev != next) unawaited(_loadNear());
    });
    final o = _origin;
    final savedIds = {for (final s in _saved) s.id};
    final nearby = [
      for (final m in _near)
        if (!savedIds.contains(m.id)) m,
    ];
    final shown = _showAll ? nearby : nearby.take(_firstPage).toList();

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_mosque')),
      ),
      body: RefreshIndicator(
        onRefresh: _loadNear,
        child: ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            _viewToggle(context),
            _originCard(context, theme, bn, o.fromGps),
            if (!_loading && _source != _NearSource.live)
              _OfflineNote(
                text: context.t(
                  _source == _NearSource.cachedOffline
                      ? 'mosques_offline'
                      : 'mosques_offline_curated',
                ),
              ),
            if (_mapView)
              ..._radar(context, theme, bn, o)
            else ...[
              // ── আমার মসজিদ ──
              SectionHeader(
                context.t('mosques_my'),
                icon: PhosphorIconsRegular.star,
              ),
              if (_saved.isEmpty)
                _HintCard(text: context.t('mosques_my_empty'))
              else
                for (final m in sortMosquesByDistance(_saved, o.lat, o.lng))
                  _MosqueTile(
                    mosque: m,
                    originLat: o.lat,
                    originLng: o.lng,
                    saved: true,
                    onTap: () => _showMosque(m),
                    onToggleSaved: () => _toggleSaved(m),
                  ),
              // ── কাছের মসজিদ ──
              SectionHeader(
                context.t('mosques_nearby'),
                icon: PhosphorIconsRegular.mosque,
                action: _loading || nearby.isEmpty
                    ? null
                    : Text(
                        context
                            .t('mosques_nearby_count')
                            .replaceAll(
                              '%n',
                              bn ? toBn(nearby.length) : '${nearby.length}',
                            ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
              ),
              if (_loading)
                const Skeleton(height: 76, count: 4)
              else if (nearby.isEmpty)
                _HintCard(text: context.t('mosques_none'))
              else ...[
                for (final m in shown)
                  _MosqueTile(
                    mosque: m,
                    originLat: o.lat,
                    originLng: o.lng,
                    saved: false,
                    onTap: () => _showMosque(m),
                    onToggleSaved: () => _toggleSaved(m),
                  ),
                if (!_showAll && nearby.length > _firstPage)
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
                                  ? toBn(nearby.length - _firstPage)
                                  : '${nearby.length - _firstPage}',
                            ),
                      ),
                    ),
                  ),
              ],
            ],
            const SizedBox(height: SLSpacing.s12),
            OutlinedButton.icon(
              icon: const Icon(PhosphorIconsRegular.magnifyingGlass, size: 18),
              label: Text(context.t('mosque_search_more')),
              onPressed: () =>
                  _open(mapsNearbySearchUrl('mosque', o.lat, o.lng)),
            ),
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
        originLat: o.lat,
        originLng: o.lng,
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

  /// Where the distances are measured from, the switch, and what that
  /// means (city centre → less exact; GPS → not stored anywhere).
  Widget _originCard(
    BuildContext context,
    ThemeData theme,
    bool bn,
    bool fromGps,
  ) {
    final profile = ref.watch(profileProvider);
    final label = fromGps
        ? '${context.t('mosques_from_location')} (±${bn ? toBn(_fix!.accuracyM.round()) : _fix!.accuracyM.round()} ${context.t('unit_m')})'
        : '${context.t('mosques_from_city')}: ${profile.city}';
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s4),
      child: Card(
        margin: EdgeInsets.zero,
        color: theme.colorScheme.primary.withValues(alpha: 0.08),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s12,
            SLSpacing.s8,
            SLSpacing.s12,
            SLSpacing.s8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // the switch as a real button that drops to its own line when
              // space runs out (it read as one sentence: "…ঢাকা আমার কাছাকাছি")
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: SLSpacing.s4,
                spacing: SLSpacing.s8,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fromGps
                            ? PhosphorIconsRegular.crosshair
                            : PhosphorIconsRegular.buildings,
                        size: 20,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: SLSpacing.s8),
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  if (_locating)
                    const Padding(
                      padding: EdgeInsets.all(SLSpacing.s12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  else
                    OutlinedButton.icon(
                      onPressed: () {
                        if (fromGps) {
                          setState(() => _fix = null); // back to city center
                          unawaited(_loadNear());
                        } else {
                          _locate();
                        }
                      },
                      icon: Icon(
                        fromGps
                            ? PhosphorIconsRegular.buildings
                            : PhosphorIconsRegular.crosshair,
                        size: 18,
                      ),
                      label: Text(
                        fromGps
                            ? context.t('mosques_use_city')
                            : context.t('mosques_near_me'),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: SLSpacing.s4),
                child: Text(
                  context.t(fromGps ? 'mosques_privacy' : 'mosques_city_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
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

/// "২৪০ মিটার · হেঁটে ~৩ মিনিট · উত্তর-পূর্বে"
String _meta(BuildContext context, MosqueInfo m, double lat, double lng) {
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

class _MosqueTile extends StatelessWidget {
  const _MosqueTile({
    super.key,
    required this.mosque,
    required this.originLat,
    required this.originLng,
    required this.saved,
    required this.onTap,
    required this.onToggleSaved,
  });
  final MosqueInfo mosque;
  final double originLat;
  final double originLng;
  final bool saved;
  final VoidCallback onTap;
  final VoidCallback onToggleSaved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final place = _place(mosque);
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsetsDirectional.fromSTEB(
          SLSpacing.s12,
          SLSpacing.s12,
          SLSpacing.s4,
          SLSpacing.s12,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: SLRadius.brMd,
              ),
              child: Icon(
                PhosphorIconsFill.mosque,
                size: 22,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: SLSpacing.s12),
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
                  if (place.isNotEmpty)
                    Text(
                      place,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  const SizedBox(height: 2),
                  Text(
                    _meta(context, mosque, originLat, originLng),
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: context.t('mosques_star_a11y'),
              onPressed: onToggleSaved,
              icon: Icon(
                saved ? PhosphorIconsFill.star : PhosphorIconsRegular.star,
                color: saved ? SLColors.goldDeep : cs.onSurfaceVariant,
              ),
            ),
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
    required this.originLat,
    required this.originLng,
    required this.saved,
    required this.onDirections,
    required this.onMap,
    required this.onToggleSaved,
  });
  final MosqueInfo mosque;
  final double originLat;
  final double originLng;
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
            const SizedBox(height: SLSpacing.s8),
            Text(
              _meta(context, mosque, originLat, originLng),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
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
