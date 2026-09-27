/// আল্লাহর ৯৯ নাম — list with meanings.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

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
              icon: Icons.brightness_7_outlined,
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
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: names.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: Icons.search,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: names.length,
                        itemBuilder: (context, i) {
                          final n = names[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s12,
                              vertical: SLSpacing.s8,
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 36,
                                  child: Text(
                                    bn ? toBn(n.id) : '${n.id}',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.arabic,
                                        style: SLType.dua(
                                          color: theme.colorScheme.onSurface,
                                        ),
                                        textDirection: TextDirection.rtl,
                                      ),
                                      Text(
                                        n.translitBn,
                                        style: theme.textTheme.bodyMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Text(
                                        n.meaningBn,
                                        style: theme.textTheme.bodySmall,
                                      ),
                                    ],
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
