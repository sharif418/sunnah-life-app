/// অনুসন্ধান (W4j) — the Ilm tab's unified content search over the five
/// packs (duas / adhkar / 99 names / Islamic names / articles). The API's
/// meili search answers online; when the network is down (status 0) or the
/// server's search engine is unavailable (503) the SAME bundled packs the
/// ilm screens render answer locally (search_offline.dart — normalized
/// substring, no typo tolerance — the gold strip below says exactly that).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/search.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'search_offline.dart';

/// Where a result row navigates — the pack's own screen (the existing
/// routes; no item-level deep links exist in the ilm section yet).
String searchRouteFor(SearchKind kind) => switch (kind) {
  SearchKind.dua => '/ilm/duas',
  SearchKind.dhikr => '/ilm/adhkar',
  SearchKind.name99 => '/ilm/names99',
  SearchKind.islamicName => '/ilm/islamic-names',
  SearchKind.article => '/ilm/articles',
};

class IlmSearchScreen extends ConsumerStatefulWidget {
  const IlmSearchScreen({super.key});

  @override
  ConsumerState<IlmSearchScreen> createState() => _IlmSearchScreenState();
}

class _IlmSearchScreenState extends ConsumerState<IlmSearchScreen> {
  final TextEditingController _field = TextEditingController();
  Timer? _debounce;
  int _seq = 0; // stale-response guard (debounced queries race)
  String _query = '';
  bool _busy = false;
  bool _offline = false; // the rows came from the bundled packs
  String? _error;
  List<SearchHit> _rows = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(v));
  }

  Future<void> _run(String raw) async {
    final q = raw.trim();
    final seq = ++_seq;
    if (q.length < 2) {
      if (!mounted) return;
      setState(() {
        _rows = const [];
        _offline = false;
        _busy = false;
        _error = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final res = await ref.read(apiProvider).search(q);
      if (!mounted || seq != _seq) return;
      setState(() {
        _rows = res.results;
        _offline = false;
        _busy = false;
      });
    } on ApiException catch (e) {
      if (!mounted || seq != _seq) return;
      if (e.status == 0 || e.status == 503) {
        // Offline (network down) or the server's search engine is
        // unavailable — the bundled packs answer locally.
        try {
          final local = await searchBundledPacks(q);
          if (!mounted || seq != _seq) return;
          setState(() {
            _rows = local;
            _offline = true;
            _busy = false;
          });
          return;
        } catch (_) {
          // fall through to the error state
        }
      }
      setState(() {
        _busy = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final shortQuery = _query.trim().length < 2;

    Widget body;
    if (_busy) {
      body = const Skeleton(height: 84, count: 5);
    } else if (_error != null) {
      body = ErrorState(
        message: _error!,
        icon: PhosphorIconsRegular.magnifyingGlass,
        onRetry: () => _run(_query),
      );
    } else if (shortQuery) {
      // a few ready searches instead of an empty page that only repeated
      // the hint (tapping one fills the field and searches)
      const topics = [
        'সকালের যিকির',
        'ঘুমের দোয়া',
        'খাওয়ার দোয়া',
        'তাহাজ্জুদ',
        'আর-রহমান',
        'সুন্নাহ',
        'ধৈর্য',
        'মুহাসাবা',
      ];
      body = ListView(
        padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
        children: [
          SectionHeader(
            context.t('search_try'),
            icon: PhosphorIconsRegular.sparkle,
          ),
          Wrap(
            spacing: SLSpacing.s8,
            runSpacing: SLSpacing.s8,
            children: [
              for (final t in topics)
                ActionChip(
                  avatar: const Icon(
                    PhosphorIconsRegular.magnifyingGlass,
                    size: 16,
                  ),
                  label: Text(t),
                  onPressed: () {
                    _field.text = t;
                    _field.selection = TextSelection.collapsed(
                      offset: t.length,
                    );
                    _debounce?.cancel();
                    setState(() => _query = t);
                    _run(t);
                  },
                ),
            ],
          ),
        ],
      );
    } else if (_rows.isEmpty) {
      body = EmptyState(
        message: context.t('search_no_results'),
        icon: PhosphorIconsRegular.magnifyingGlass,
      );
    } else {
      body = ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          SLSpacing.s4,
          SLSpacing.s16,
          SLSpacing.s24,
        ),
        itemCount: _rows.length,
        itemBuilder: (context, i) {
          final hit = _rows[i];
          return AppCard(
            onTap: () => context.push(searchRouteFor(hit.kind)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    // the light/dark soft-primary pair the madu-tree chips use
                    color: theme.brightness == Brightness.dark
                        ? SLColors.darkPrimarySoft
                        : SLColors.primarySoftLight,
                    borderRadius: SLRadius.brPill,
                  ),
                  child: Text(
                    hit.kindLabelBn,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  hit.title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (hit.subtitle?.isNotEmpty ?? false) ...[
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    hit.subtitle!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('search_title')),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(SLSpacing.s16),
            child: TextField(
              controller: _field,
              autofocus: true,
              onChanged: _onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (v) {
                _debounce?.cancel();
                _run(v);
              },
              decoration: InputDecoration(
                hintText: context.t('search_hint'),
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                isDense: true,
              ),
            ),
          ),
          // the honest offline marker — the SAME gold-on-cream idiom the
          // OfflineBanner uses, without its "last updated" stamp (nothing
          // came over the network; the rows are the app's own bundled packs)
          if (_offline)
            Container(
              margin: const EdgeInsets.fromLTRB(
                SLSpacing.s16,
                0,
                SLSpacing.s16,
                SLSpacing.s8,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s12,
                vertical: SLSpacing.s8,
              ),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? SLColors.darkGoldSoft
                    : SLColors.goldSoftLight,
                borderRadius: SLRadius.brMd,
              ),
              child: Row(
                children: [
                  Icon(
                    PhosphorIconsRegular.wifiSlash,
                    size: 16,
                    color: theme.brightness == Brightness.dark
                        ? SLColors.darkGoldText
                        : SLColors.lightGoldText,
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Text(
                      context.t('search_offline_note'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? SLColors.darkGoldText
                            : SLColors.lightGoldText,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
