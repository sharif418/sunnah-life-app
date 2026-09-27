/// ঈমানের ৭০ শাখা — grouped by heart / tongue / body.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

class ImanBranchesScreen extends StatelessWidget {
  const ImanBranchesScreen({super.key});

  static const _groupLabels = <String, (String, IconData)>{
    'heart': ('iman_branch_heart', Icons.favorite_outline),
    'tongue': ('iman_branch_tongue', Icons.record_voice_over_outlined),
    'body': ('iman_branch_body', Icons.accessibility_new_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_iman_branches')),
      ),
      body: FutureBuilder<List<ImanBranch>>(
        future: ContentPack.imanBranches(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 8);
          }
          final branches = snap.data ?? const <ImanBranch>[];
          if (branches.isEmpty) {
            return EmptyState(
                message: context.t('empty_generic'),
                icon: Icons.favorite_outline);
          }
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              for (final g in _groupLabels.keys) ...[
                if (branches.any((b) => b.group == g)) ...[
                  SectionHeader(
                    '${context.t(_groupLabels[g]!.$1)} (${bn ? toBn(branches.where((b) => b.group == g).length) : branches.where((b) => b.group == g).length})',
                    icon: _groupLabels[g]!.$2,
                  ),
                  for (final b in branches.where((b) => b.group == g))
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                          horizontal: SLSpacing.s12, vertical: SLSpacing.s8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bn ? toBn(b.id) : '${b.id}',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.primary),
                          ),
                          const SizedBox(width: SLSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(b.titleBn,
                                    style: theme.textTheme.bodyLarge),
                                if (b.detailBn?.isNotEmpty ?? false)
                                  Text(
                                    b.detailBn!,
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: SLSpacing.s8),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

}
