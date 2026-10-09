/// ঈমানের ৭০ শাখা — grouped by heart / tongue / body.
library;

import 'package:flutter/material.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../amal/iman_check_screen.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class ImanBranchesScreen extends StatefulWidget {
  const ImanBranchesScreen({super.key});

  @override
  State<ImanBranchesScreen> createState() => _ImanBranchesScreenState();
}

class _ImanBranchesScreenState extends State<ImanBranchesScreen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<ImanBranch>> _future = ContentPack.imanBranches();

  void _openSelfCheck() =>
      Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ImanCheckScreen()));

  void _showBranch(ImanBranch b) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final group = _groupLabels[b.group];
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s24,
            0,
            SLSpacing.s24,
            SLSpacing.s16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (group != null)
                Row(
                  children: [
                    Icon(group.$2, size: 18, color: cs.primary),
                    const SizedBox(width: SLSpacing.s4),
                    Text(
                      context.t(group.$1),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: SLSpacing.s8),
              Text(
                b.titleBn,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (b.detailBn?.isNotEmpty ?? false) ...[
                const SizedBox(height: SLSpacing.s8),
                Text(
                  b.detailBn!,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                ),
              ],
              const SizedBox(height: SLSpacing.s16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  _openSelfCheck();
                },
                icon: const Icon(PhosphorIconsRegular.sealCheck),
                label: Text(context.t('iman_check_cta_title')),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 8);
          }
          final branches = snap.data ?? const <ImanBranch>[];
          if (branches.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.heart,
            );
          }
          // One card per group, a row per branch (70 cards edge to edge
          // read as one long smear); the number in a fixed-width chip so the
          // titles line up past ৯, the root (০) marked মূল.
          Widget row(ImanBranch b) => InkWell(
            key: ValueKey('iman_branch_${b.id}'),
            onTap: () => _showBranch(b),
            child: Padding(
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
            ),
          );

          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              // the branches are also a mirror: the self-check (it was
              // reachable only from the diary's self-test screen)
              AppCard(
                key: const ValueKey('iman_check_cta'),
                onTap: _openSelfCheck,
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        PhosphorIconsRegular.sealCheck,
                        color: theme.colorScheme.onPrimary,
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('iman_check_cta_title'),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            context.t('iman_check_cta_body'),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    DirectionalIcon(
                      PhosphorIconsRegular.caretRight,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
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
                        for (final (i, b)
                            in branches.where((b) => b.group == g).indexed) ...[
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
