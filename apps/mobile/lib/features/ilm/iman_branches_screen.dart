/// ঈমানের ৭০ শাখা — grouped by heart / tongue / body.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class ImanBranchesScreen extends StatelessWidget {
  const ImanBranchesScreen({super.key});

  static const _groupLabels = <String, (String, IconData)>{
    'heart': ('iman_branch_heart', PhosphorIconsRegular.heart),
    'tongue': ('iman_branch_tongue', PhosphorIconsRegular.userSound),
    'body': ('iman_branch_body', PhosphorIconsRegular.personArmsSpread),
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
                icon: PhosphorIconsRegular.heart);
          }
          // One card per group, a row per branch (70 cards edge to edge
          // read as one long smear); the number in a fixed-width chip so the
          // titles line up past ৯, the root (০) marked মূল.
          Widget row(ImanBranch b) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SLSpacing.s12,
              vertical: SLSpacing.s12,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: b.id == 0
                      ? Icon(
                          PhosphorIconsRegular.sealCheck,
                          size: 18,
                          color: theme.colorScheme.primary,
                        )
                      : FittedBox(
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Text(
                              bn ? toBn(b.id) : '${b.id}',
                              style: theme.textTheme.bodySmall?.copyWith(
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        b.titleBn,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                      if (b.detailBn?.isNotEmpty ?? false)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            b.detailBn!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              height: 1.45,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              for (final g in _groupLabels.keys)
                if (branches.any((b) => b.group == g)) ...[
                  SectionHeader(
                    '${context.t(_groupLabels[g]!.$1)} (${bn ? toBn(branches.where((b) => b.group == g).length) : branches.where((b) => b.group == g).length})',
                    icon: _groupLabels[g]!.$2,
                  ),
                  AppCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final (i, b) in branches
                            .where((b) => b.group == g)
                            .indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              indent: SLSpacing.s12 + 32 + SLSpacing.s12,
                              color: theme.colorScheme.outlineVariant,
                            ),
                          row(b),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                ],
            ],
          );
        },
      ),
    );
  }

}
