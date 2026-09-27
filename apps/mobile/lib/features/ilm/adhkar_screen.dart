/// আযকার — morning/evening adhkar with per-item repetition counters
/// (haptics on every tap) and the auto-tick into the amal diary when a set
/// completes (source auto:adhkar:morning / auto:adhkar:evening).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../state/amal_state.dart';
import '../shared/widgets.dart';

class AdhkarScreen extends ConsumerStatefulWidget {
  const AdhkarScreen({super.key});

  @override
  ConsumerState<AdhkarScreen> createState() => _AdhkarScreenState();
}

class _AdhkarScreenState extends ConsumerState<AdhkarScreen> {
  final Map<String, int> _counts = <String, int>{};

  @override
  Widget build(BuildContext context) {
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_adhkar')),
      ),
      body: FutureBuilder<List<DhikrSet>>(
        future: ContentPack.adhkar(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 80, count: 5);
          }
          final sets = snap.data ?? const <DhikrSet>[];
          if (sets.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: Icons.spa_outlined,
            );
          }
          final morning = sets.where((s) => s.period == 'morning').toList();
          final evening = sets.where((s) => s.period == 'evening').toList();
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              for (final (title, list, amalKey) in [
                (context.t('adhkar_morning'), morning, 'adhkar_morning'),
                (context.t('adhkar_evening'), evening, 'adhkar_evening'),
              ]) ...[
                if (list.isNotEmpty) ...[
                  SectionHeader(title, icon: Icons.wb_twilight_outlined),
                  for (final set in list)
                    _DhikrSetCard(
                      set: set,
                      counts: _counts,
                      bengali: bn,
                      onChanged: () => setState(() {}),
                      onComplete: () => _tickAmal(amalKey, set, title),
                    ),
                  const SizedBox(height: SLSpacing.s12),
                ],
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _tickAmal(String amalKey, DhikrSet set, String title) async {
    final today = dateKey(DateTime.now());
    final err = await ref
        .read(amalProvider.notifier)
        .write(amalKey, today, true, 'auto:$amalKey');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          err ?? '$title — ${context.t('adhkar_complete')}',
        ),
      ),
    );
  }
}

class _DhikrSetCard extends StatelessWidget {
  const _DhikrSetCard({
    required this.set,
    required this.counts,
    required this.bengali,
    required this.onChanged,
    required this.onComplete,
  });
  final DhikrSet set;
  final Map<String, int> counts;
  final bool bengali;
  final VoidCallback onChanged;
  final VoidCallback onComplete;

  bool _allDone() =>
      set.items.every((i) => (counts['${set.id}:${i.id}'] ?? 0) >= i.count);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  set.titleBn,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (_allDone())
                Icon(
                  Icons.check_circle,
                  color: theme.colorScheme.primary,
                  size: 22,
                ),
            ],
          ),
          for (final item in set.items)
            Padding(
              padding: const EdgeInsets.only(top: SLSpacing.s12),
              child: _DhikrItemRow(
                set: set,
                item: item,
                count: counts['${set.id}:${item.id}'] ?? 0,
                bengali: bengali,
                onTap: () {
                  final current = counts['${set.id}:${item.id}'] ?? 0;
                  if (current >= item.count) return;
                  HapticFeedback.lightImpact();
                  counts['${set.id}:${item.id}'] = current + 1;
                  onChanged();
                  if (set.items.every(
                    (i) => (counts['${set.id}:${i.id}'] ?? 0) >= i.count,
                  )) {
                    onComplete();
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _DhikrItemRow extends StatelessWidget {
  const _DhikrItemRow({
    required this.set,
    required this.item,
    required this.count,
    required this.bengali,
    required this.onTap,
  });
  final DhikrSet set;
  final DhikrItem item;
  final int count;
  final bool bengali;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = count >= item.count;
    final progress = item.count <= 0 ? 1.0 : count / item.count;
    return InkWell(
      onTap: done ? null : onTap,
      borderRadius: SLRadius.brMd,
      child: Container(
        padding: const EdgeInsets.all(SLSpacing.s12),
        decoration: BoxDecoration(
          color: done
              ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: SLRadius.brMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.arabic,
              style: SLType.dua(color: theme.colorScheme.onSurface),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(item.translitBn, style: theme.textTheme.bodySmall),
            const SizedBox(height: 2),
            Text(item.translationBn, style: theme.textTheme.bodyMedium),
            const SizedBox(height: SLSpacing.s8),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: progress.clamp(0, 1),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: SLSpacing.s8),
                Text(
                  '${bengali ? toBn(count) : count} / ${bengali ? toBn(item.count) : item.count}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: SLSpacing.s4),
                Icon(
                  done ? Icons.check_circle : Icons.touch_app_outlined,
                  size: 18,
                  color: done
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
