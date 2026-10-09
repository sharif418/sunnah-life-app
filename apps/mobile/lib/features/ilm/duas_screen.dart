/// দোয়া ভাণ্ডার — searchable du'a library grouped by category.
library;

import 'package:flutter/material.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
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
  String? _category;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
          var visible = q.isEmpty
              ? (_category == null
                    ? items
                    : items.where((d) => d.category == _category).toList())
              : items
                    .where(
                      (d) =>
                          d.titleBn.contains(q) ||
                          d.translationBn.contains(q) ||
                          d.translitBn?.contains(q) == true,
                    )
                    .toList();
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
                        message: context.t('empty_generic'),
                        icon: PhosphorIconsRegular.hand,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final d = visible[i];
                          final card = AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  d.titleBn,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: SLSpacing.s8),
                                // full width: a short dua used to sit on
                                // the LEFT (the column is start-aligned)
                                SizedBox(
                                  width: double.infinity,
                                  child: Text(
                                    d.arabic,
                                    style: SLType.dua(
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                                if (d.translitBn?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: SLSpacing.s8),
                                  Text(
                                    d.translitBn!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: SLSpacing.s4),
                                Text(
                                  d.translationBn,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                const SizedBox(height: SLSpacing.s4),
                                Text(
                                  '— ${d.reference}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
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
