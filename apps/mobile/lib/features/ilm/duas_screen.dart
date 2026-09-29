/// দোয়া ভাণ্ডার — searchable du'a library grouped by category.
library;

import 'package:flutter/material.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class DuasScreen extends StatefulWidget {
  const DuasScreen({super.key});

  @override
  State<DuasScreen> createState() => _DuasScreenState();
}

class _DuasScreenState extends State<DuasScreen> {
  String _query = '';
  String? _category;
  (List<DuaCategory>, List<DuaItem>)? _loaded;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_duas')),
      ),
      body: FutureBuilder<(List<DuaCategory>, List<DuaItem>)>(
        future: _loaded == null ? ContentPack.duas() : Future.value(_loaded),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 80, count: 5);
          }
          final (cats, items) =
              snap.data ?? (const <DuaCategory>[], const <DuaItem>[]);
          _loaded = (cats, items);
          final q = _query.trim();
          final visible = q.isEmpty
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
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                    isDense: true,
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: FilterChip(
                        label: Text(context.t('see_all')),
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
                    : ListView.builder(
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final d = visible[i];
                          return AppCard(
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
                                Text(
                                  d.arabic,
                                  style: SLType.dua(
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  textDirection: TextDirection.rtl,
                                  textAlign: TextAlign.right,
                                ),
                                if (d.translitBn?.isNotEmpty ?? false) ...[
                                  const SizedBox(height: SLSpacing.s4),
                                  Text(
                                    d.translitBn!,
                                    style: theme.textTheme.bodySmall,
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
