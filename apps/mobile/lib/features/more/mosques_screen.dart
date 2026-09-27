/// আমার মসজিদ — bundled mosque list sorted by distance from the profile city.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/qibla.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

class MosquesScreen extends ConsumerWidget {
  const MosquesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_mosque')),
      ),
      body: FutureBuilder<List<MosqueInfo>>(
        future: ContentPack.mosques(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 5);
          }
          final mosques = snap.data ?? const <MosqueInfo>[];
          if (mosques.isEmpty) {
            return EmptyState(
                message: context.t('empty_generic'),
                icon: Icons.mosque_outlined);
          }
          final sorted = [...mosques]..sort((a, b) => distanceKm(
                  profile.lat, profile.lng, a.lat, a.lng)
              .compareTo(distanceKm(profile.lat, profile.lng, b.lat, b.lng)));
          return ListView.builder(
            padding: const EdgeInsets.all(SLSpacing.s16),
            itemCount: sorted.length,
            itemBuilder: (context, i) {
              final m = sorted[i];
              final km =
                  distanceKm(profile.lat, profile.lng, m.lat, m.lng);
              return AppCard(
                padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s12, vertical: SLSpacing.s8),
                child: Row(
                  children: [
                    Icon(Icons.mosque,
                        size: 32, color: theme.colorScheme.primary),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.nameBn,
                              style: theme.textTheme.bodyLarge
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          Text(m.addressBn,
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '${bn ? toBn(km.round()) : km.round()}',
                          style: theme.textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        Text('কিমি', style: theme.textTheme.bodySmall),
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
