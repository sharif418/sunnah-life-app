/// আর্টিকেল — list + inline reader.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

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
              icon: Icons.article_outlined,
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
                  icon: const Icon(Icons.arrow_back),
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
          return ListView.builder(
            padding: const EdgeInsets.all(SLSpacing.s16),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              return AppCard(
                onTap: () => setState(() => _openId = a.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (a.category?.isNotEmpty ?? false)
                      Text(
                        a.category!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    Text(
                      a.titleBn,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      a.excerptBn,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                    if (a.readMinutes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: SLSpacing.s4),
                        child: Text(
                          '${bn ? toBn(a.readMinutes!) : a.readMinutes} মিনিট পড়া',
                          style: theme.textTheme.bodySmall,
                        ),
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
