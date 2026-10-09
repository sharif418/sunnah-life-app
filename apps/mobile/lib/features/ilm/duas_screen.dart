/// দোয়া ভাণ্ডার — searchable du'a library grouped by category.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../services/platform_channels.dart' show SystemChannel;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key, this.highlightId});

  /// From a search result (`?id=`): that item is shown first, framed.
  final String? highlightId;

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<(List<DuaCategory>, List<DuaItem>)> _future =
      ContentPack.duas();
  String _query = '';

  /// A category key, `_fav` for প্রিয়, or null for all.
  String? _category;
  Set<String> _favs = <String>{};
  static const _favKey = 'dua_favourites';
  static const _favFilter = '_fav';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          final l = p.getStringList(_favKey) ?? const <String>[];
          if (mounted) setState(() => _favs = l.toSet());
        })
        .catchError((_) {});
  }

  Future<void> _toggleFav(String id) async {
    setState(() {
      _favs = {..._favs};
      if (!_favs.remove(id)) _favs.add(id);
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_favKey, _favs.toList());
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_duas')),
      ),
      body: FutureBuilder<(List<DuaCategory>, List<DuaItem>)>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 80, count: 5);
          }
          final (cats, items) =
              snap.data ?? (const <DuaCategory>[], const <DuaItem>[]);
          final q = _query.trim();
          // the chosen chip narrows the list, the search looks inside it
          // (search used to ignore the chip while it still looked selected)
          var visible = switch (_category) {
            null => items,
            _favFilter => items.where((d) => _favs.contains(d.id)).toList(),
            final c => items.where((d) => d.category == c).toList(),
          };
          if (q.isNotEmpty) {
            visible = visible
                .where(
                  (d) =>
                      d.titleBn.contains(q) ||
                      d.translationBn.contains(q) ||
                      (d.translitBn?.contains(q) ?? false) ||
                      d.arabic.contains(q),
                )
                .toList();
          }
          // a search result's item first (only while not searching here)
          final hl = widget.highlightId;
          if (hl != null && _query.trim().isEmpty) {
            final hit = visible.where((x) => x.id == hl).firstOrNull;
            if (hit != null) {
              visible = [hit, ...visible.where((x) => !identical(x, hit))];
            }
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SLSpacing.s16,
                  vertical: SLSpacing.s8,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: context.t('search'),
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(44),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        label: Text(context.t('sunnah_cat_all')),
                        selected: _category == null,
                        onSelected: (_) => setState(() => _category = null),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        key: const ValueKey('dua_filter_fav'),
                        avatar: const Icon(PhosphorIconsFill.heart, size: 16),
                        label: Text(context.t('dua_favourites')),
                        selected: _category == _favFilter,
                        onSelected: (_) =>
                            setState(() => _category = _favFilter),
                      ),
                    ),
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          label: Text(c.labelBn),
                          selected: _category == c.key,
                          onSelected: (_) => setState(() => _category = c.key),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        message: context.t(
                          _category == _favFilter && q.isEmpty
                              ? 'dua_favourites_empty'
                              : 'empty_generic',
                        ),
                        icon: _category == _favFilter
                            ? PhosphorIconsRegular.heart
                            : PhosphorIconsRegular.hand,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final d = visible[i];
                          final card = DuaCard(
                            dua: d,
                            favourite: _favs.contains(d.id),
                            onFavourite: () => _toggleFav(d.id),
                          );
                          return SearchHitFrame(
                            hit: i == 0 && widget.highlightId == d.id,
                            child: card,
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// One dua: the title with a favourite heart, the Arabic, the reading aid,
/// the meaning and the source, the ফযীলত on demand (29 of 32 have one —
/// none was shown), and copy / share.
class DuaCard extends StatefulWidget {
  const DuaCard({
    super.key,
    required this.dua,
    required this.favourite,
    required this.onFavourite,
  });
  final DuaItem dua;
  final bool favourite;
  final VoidCallback onFavourite;

  @override
  State<DuaCard> createState() => _DuaCardState();
}

class _DuaCardState extends State<DuaCard> {
  bool _showVirtue = false;

  String get _shareText {
    final d = widget.dua;
    return [
      d.titleBn,
      d.arabic,
      if ((d.translitBn ?? '').isNotEmpty) d.translitBn!,
      d.translationBn,
      if (d.reference.isNotEmpty) '— ${d.reference}',
    ].join('\n\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final d = widget.dua;
    final virtue = d.virtue?.trim() ?? '';
    return AppCard(
      key: ValueKey('dua_${d.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    d.titleBn,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              IconButton(
                key: ValueKey('dua_fav_${d.id}'),
                tooltip: context.t('dua_favourite'),
                onPressed: widget.onFavourite,
                icon: Icon(
                  widget.favourite
                      ? PhosphorIconsFill.heart
                      : PhosphorIconsRegular.heart,
                  color: widget.favourite ? cs.error : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          // room above the Arabic (its tall marks nearly touched a wrapped
          // title at large text)
          const SizedBox(height: SLSpacing.s12),
          // full width: a short dua used to sit on the LEFT
          SizedBox(
            width: double.infinity,
            child: Text(
              d.arabic,
              style: SLType.dua(color: cs.onSurface),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
          ),
          if (d.translitBn?.isNotEmpty ?? false) ...[
            const SizedBox(height: SLSpacing.s8),
            Text(
              d.translitBn!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s4),
          Text(d.translationBn, style: theme.textTheme.bodyMedium),
          if (d.reference.isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s4),
            Text(
              '— ${d.reference}',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.primary),
            ),
          ],
          if (virtue.isNotEmpty && _showVirtue) ...[
            const SizedBox(height: SLSpacing.s8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SLSpacing.s12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: SLRadius.brMd,
              ),
              child: Text(
                virtue,
                style: theme.textTheme.bodySmall?.copyWith(height: 1.6),
              ),
            ),
          ],
          const SizedBox(height: SLSpacing.s4),
          Wrap(
            spacing: SLSpacing.s4,
            children: [
              if (virtue.isNotEmpty)
                TextButton.icon(
                  key: ValueKey('dua_virtue_${d.id}'),
                  onPressed: () => setState(() => _showVirtue = !_showVirtue),
                  icon: const Icon(PhosphorIconsRegular.sparkle, size: 18),
                  label: Text(context.t('dhikr_virtue')),
                ),
              TextButton.icon(
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: _shareText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(context.t('copied'))),
                    );
                  }
                },
                icon: const Icon(PhosphorIconsRegular.copy, size: 18),
                label: Text(context.t('copy')),
              ),
              TextButton.icon(
                onPressed: () => SystemChannel.shareText(_shareText),
                icon: const Icon(PhosphorIconsRegular.shareNetwork, size: 18),
                label: Text(context.t('share')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
