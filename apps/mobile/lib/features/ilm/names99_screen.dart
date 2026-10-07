/// আল্লাহর ৯৯ নাম — list with meanings.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class Names99Screen extends StatefulWidget {
  const Names99Screen({super.key});

  @override
  State<Names99Screen> createState() => _Names99ScreenState();
}

class _Names99ScreenState extends State<Names99Screen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_names99')),
      ),
      body: FutureBuilder<List<NameOfAllah>>(
        future: ContentPack.names99(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 8);
          }
          var names = snap.data ?? const <NameOfAllah>[];
          if (names.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.sun,
            );
          }
          final q = _query.trim();
          if (q.isNotEmpty) {
            names = names
                .where(
                  (n) =>
                      n.translitBn.contains(q) ||
                      n.meaningBn.contains(q) ||
                      n.arabic.contains(q),
                )
                .toList();
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
                    prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: names.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: PhosphorIconsRegular.magnifyingGlass,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: names.length,
                        itemBuilder: (context, i) {
                          final n = names[i];
                          // number chip · the name and its meaning · the
                          // Arabic large on the right, where the eye reads it
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s12,
                              vertical: SLSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: FittedBox(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        bn ? toBn(n.id) : '${n.id}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SLSpacing.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.translitBn,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.meaningBn,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: SLSpacing.s12),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.38,
                                  ),
                                  child: Text(
                                    n.arabic,
                                    style: SLType.dua(
                                      color: theme.colorScheme.primary,
                                    ).copyWith(fontSize: 26, height: 1.6),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
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
