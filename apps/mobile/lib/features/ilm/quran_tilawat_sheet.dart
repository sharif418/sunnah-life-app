/// তিলাওয়াত সেশন শীট — minutes read → diary quantity entry
/// (source auto:quran:tilawat) with the category-aware tilawat target.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

/// Shows the recitation-session sheet. Returns true when the user logged
/// pages (or dismissed after logging).
Future<bool> showTilawatSheet(
  BuildContext context,
  WidgetRef ref, {
  required int minutes,
  required VoidCallback onLogged,
}) async {
  final profile = ref.read(profileProvider);
  final amal = ref.read(amalProvider.notifier);
  final defs = await ref.read(amalDefinitionsProvider.future);
  final tilawatDef = defs.where((d) => d.key == 'tilawat').firstOrNull;
  final target = tilawatDef?.targetFor(profile.category).toDouble() ?? 1.0;
  final suggested = (minutes / 3).ceil().clamp(1, 999).toDouble();
  var pages = suggested;

  // The definitions read above was async — re-validate the context.
  if (!context.mounted) return false;
  final logged = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Padding(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          0,
          SLSpacing.s16,
          SLSpacing.s24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.t('tilawat_session'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${context.isBn ? toBn(minutes) : minutes} ${context.t('tilawat_minutes')}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('tilawat_pages'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: SLSpacing.s8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.outlined(
                  onPressed: () => setState(
                    () => pages = (pages - 0.5).clamp(0, 999).toDouble(),
                  ),
                  icon: const Icon(Icons.remove),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  child: Text(
                    context.isBn ? toBn(pages) : '$pages',
                    style: Theme.of(context).textTheme.headlineMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton.outlined(
                  onPressed: () => setState(
                    () => pages = (pages + 0.5).clamp(0, 999).toDouble(),
                  ),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
            Text(
              '${context.t('target_label')}: ${context.isBn ? toBn(target.toInt()) : target.toInt()} ${context.t('tilawat_target_pages')}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: SLSpacing.s12),
            FilledButton.icon(
              icon: const Icon(Icons.menu_book_outlined),
              label: Text(context.t('save')),
              onPressed: () async {
                if (pages > 0) {
                  await amal.write(
                    'tilawat',
                    dateKey(DateTime.now()),
                    pages,
                    'auto:quran:tilawat',
                  );
                }
                onLogged();
                if (context.mounted) {
                  Navigator.of(context).pop(true);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.t('quran_tilawat_logged')} (${context.isBn ? toBn(pages) : pages} পৃষ্ঠা)',
                      ),
                    ),
                  );
                }
              },
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(context.t('cancel')),
            ),
          ],
        ),
      ),
    ),
  );
  return logged ?? false;
}
