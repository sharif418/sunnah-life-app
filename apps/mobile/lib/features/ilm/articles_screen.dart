/// আর্টিকেল — the list, and the reader as its own page
/// (/ilm/articles/:id: system back returns to the list; search opens an
/// article directly).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<ArticleItem>> _future = ContentPack.articles();

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
        future: _future,
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
                onTap: () =>
                    context.push('/ilm/articles/${Uri.encodeComponent(a.id)}'),
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

/// "tarbiyah" → তারবিয়াহ (an unknown slug shows as written).
String articleCategoryLabel(BuildContext context, String? cat) {
  final c = cat ?? '';
  if (c.isEmpty) return '';
  final key = 'article_cat_$c';
  final t = context.t(key);
  return t == key ? c : t;
}

/// "2025-11-18" → ১৮ নভেম্বর ২০২৫ (null when it does not parse — never a
/// RangeError on a short string).
String? articleDate(BuildContext context, String? iso) {
  final d = iso == null ? null : DateTime.tryParse(iso);
  if (d == null) return null;
  final bn = context.isBn;
  String n(int v) => bn ? toBn(v) : '$v';
  return '${n(d.day)} ${context.t('month_${d.month}')} ${n(d.year)}';
}

class ArticleReaderScreen extends StatefulWidget {
  const ArticleReaderScreen({super.key, required this.id});
  final String id;

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  late final Future<List<ArticleItem>> _future = ContentPack.articles();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_articles')),
      ),
      body: FutureBuilder<List<ArticleItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 88, count: 4);
          }
          final a = (snap.data ?? const <ArticleItem>[])
              .where((x) => x.id == widget.id)
              .firstOrNull;
          if (a == null) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.article,
            );
          }
          final cat = articleCategoryLabel(context, a.category);
          final date = articleDate(context, a.publishedAt);
          // paragraphs as written (blank-line separated), each its own block
          final paras = a.bodyBn
              .split(RegExp(r'\n\s*\n'))
              .map((p) => p.trim())
              .where((p) => p.isNotEmpty)
              .toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s8,
              SLSpacing.s16,
              SLSpacing.s32,
            ),
            children: [
              if (cat.isNotEmpty)
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SLSpacing.s8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: SLRadius.brPill,
                    ),
                    child: Text(
                      cat,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: SLSpacing.s8),
              Text(
                a.titleBn,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              Text(
                [
                  if (a.readMinutes != null)
                    '${bn ? toBn(a.readMinutes!) : a.readMinutes} ${context.t('article_read_min')}',
                  ?date,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const Divider(height: SLSpacing.s32),
              for (final p in paras)
                Padding(
                  padding: const EdgeInsets.only(bottom: SLSpacing.s16),
                  child: Text(
                    p,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.8),
                  ),
                ),
              const SizedBox(height: SLSpacing.s8),
              OutlinedButton.icon(
                onPressed: () => context.pop(),
                icon: const DirectionalIcon(PhosphorIconsRegular.arrowLeft),
                label: Text(context.t('article_back_to_list')),
              ),
            ],
          );
        },
      ),
    );
  }
}
