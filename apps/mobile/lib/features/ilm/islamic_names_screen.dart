/// ইসলামিক নাম — baby-name lists with the boy/girl filter.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

class IslamicNamesScreen extends StatefulWidget {
  const IslamicNamesScreen({super.key});

  @override
  State<IslamicNamesScreen> createState() => _IslamicNamesScreenState();
}

class _IslamicNamesScreenState extends State<IslamicNamesScreen> {
  bool _girls = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_baby_names')),
      ),
      body: FutureBuilder<List<IslamicName>>(
        future: ContentPack.islamicNames(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 8);
          }
          final names = snap.data ?? const <IslamicName>[];
          if (names.isEmpty) {
            return EmptyState(
                message: context.t('empty_generic'),
                icon: Icons.child_care_outlined);
          }
          var visible = names
              .where((n) => n.gender == (_girls ? 'girl' : 'boy'))
              .toList();
          final q = _query.trim();
          if (q.isNotEmpty) {
            visible = visible
                .where((n) =>
                    n.name.contains(q) || n.meaningBn.contains(q))
                .toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16, vertical: SLSpacing.s8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        onChanged: (v) => setState(() => _query = v),
                        decoration: InputDecoration(
                          hintText: context.t('search'),
                          prefixIcon: const Icon(Icons.search),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    SegmentedButton<bool>(
                      segments: [
                        ButtonSegment(
                          value: false,
                          icon: const Icon(Icons.boy_outlined, size: 18),
                          label: Text(context.t('names_boy')),
                        ),
                        ButtonSegment(
                          value: true,
                          icon: const Icon(Icons.girl_outlined, size: 18),
                          label: Text(context.t('names_girl')),
                        ),
                      ],
                      selected: {_girls},
                      onSelectionChanged: (s) =>
                          setState(() => _girls = s.first),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: Icons.search)
                    : ListView.separated(
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        itemBuilder: (context, i) {
                          final n = visible[i];
                          return AppCard(
                            padding: const EdgeInsets.symmetric(
                                horizontal: SLSpacing.s12,
                                vertical: SLSpacing.s8),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(n.name,
                                          style: theme.textTheme.bodyLarge
                                              ?.copyWith(
                                                  fontWeight:
                                                      FontWeight.w700)),
                                      Text(n.meaningBn,
                                          style:
                                              theme.textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                                Text(
                                  bn ? toBn(i + 1) : '${i + 1}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.outline),
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
