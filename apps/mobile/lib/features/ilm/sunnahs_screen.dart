/// সুন্নাহ ও বিস্মৃত সুন্নাহ — category-filtered list with references.
library;

import 'package:flutter/material.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class SunnahsScreen extends StatefulWidget {
  const SunnahsScreen({super.key});

  @override
  State<SunnahsScreen> createState() => _SunnahsScreenState();
}

class _SunnahsScreenState extends State<SunnahsScreen> {
  String _category = 'all';

  static const _cats = <String, (String, IconData)>{
    'all': ('sunnah_cat_all', PhosphorIconsRegular.infinity),
    'daily': ('sunnah_cat_daily', PhosphorIconsRegular.sun),
    'forgotten': ('sunnah_cat_forgotten', PhosphorIconsRegular.sunHorizon),
    'salah': ('sunnah_cat_salah', PhosphorIconsRegular.mosque),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_sunnahs')),
      ),
      body: FutureBuilder<List<SunnahItem>>(
        future: ContentPack.sunnahs(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 6);
          }
          final items = snap.data ?? const <SunnahItem>[];
          if (items.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.sunHorizon,
            );
          }
          final visible = _category == 'all'
              ? items
              : items.where((s) => s.category == _category).toList();
          return Column(
            children: [
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  children: [
                    for (final c in _cats.keys)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: FilterChip(
                          avatar: Icon(
                            _cats[c]!.$2,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(context.t(_cats[c]!.$1)),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: PhosphorIconsRegular.magnifyingGlass,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        itemBuilder: (context, i) {
                          final s = visible[i];
                          return AppCard(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.titleBn,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    Icon(
                                      _cats[s.category]?.$2 ??
                                          PhosphorIconsRegular.star,
                                      size: 18,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: SLSpacing.s4),
                                Text(
                                  s.detailBn,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (s.reference?.isNotEmpty ?? false)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: SLSpacing.s4,
                                    ),
                                    child: Text(
                                      '— ${s.reference}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
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
