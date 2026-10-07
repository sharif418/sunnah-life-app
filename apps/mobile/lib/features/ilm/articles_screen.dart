/// আর্টিকেল — list + inline reader.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class ArticlesScreen extends StatefulWidget {
  const ArticlesScreen({super.key});

  @override
  State<ArticlesScreen> createState() => _ArticlesScreenState();
}

class _ArticlesScreenState extends State<ArticlesScreen> {
  String? _openId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_articles')),
      ),
      body: FutureBuilder<List<ArticleItem>>(
        future: ContentPack.articles(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 88, count: 5);
          }
          final items = snap.data ?? const <ArticleItem>[];
          if (items.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.article,
            );
          }
          final open = _openId == null
              ? null
              : items.where((a) => a.id == _openId).firstOrNull;
          if (open != null) {
            return ListView(
              padding: const EdgeInsets.all(SLSpacing.s16),
              children: [
                TextButton.icon(
                  // Mirrors automatically under RTL (back = forward arrow).
                  icon: const DirectionalIcon(PhosphorIconsRegular.arrowLeft),
                  label: Text(context.t('back')),
                  onPressed: () => setState(() => _openId = null),
                ),
                Text(
                  open.titleBn,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  [
                    if (open.category?.isNotEmpty ?? false) open.category,
                    if (open.readMinutes != null)
                      '${bn ? toBn(open.readMinutes!) : open.readMinutes} মিনিট',
                    if (open.publishedAt?.isNotEmpty ?? false)
                      open.publishedAt!.substring(0, 10),
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: SLSpacing.s12),
                Text(
                  open.bodyBn,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                ),
                const SizedBox(height: SLSpacing.s24),
                OutlinedButton(
                  onPressed: () => setState(() => _openId = null),
                  child: Text(context.t('back')),
                ),
              ],
            );
          }
          return ListView.separated(
            separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s12),
            padding: const EdgeInsets.all(SLSpacing.s16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final cat = a.category ?? '';
              final catKey = 'article_cat_$cat';
              final catLabel = context.t(catKey) == catKey
                  ? cat
                  : context.t(catKey);
              return AppCard(
                onTap: () => setState(() => _openId = a.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // the category as a Bengali pill (it used to print
                        // the raw slug: "tarbiyah")
                        if (cat.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: SLRadius.brPill,
                            ),
                            child: Text(
                              catLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        const Spacer(),
                        if (a.readMinutes != null) ...[
                          Icon(
                            PhosphorIconsRegular.clock,
                            size: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${bn ? toBn(a.readMinutes!) : a.readMinutes} ${context.t('article_read_min')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      a.titleBn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      a.excerptBn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s8),
                    Row(
                      children: [
                        Text(
                          context.t('article_read'),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        DirectionalIcon(
                          PhosphorIconsBold.caretRight,
                          size: 14,
                          color: theme.colorScheme.primary,
                        ),
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
}
