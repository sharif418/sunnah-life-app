/// Sync sheet (C-W3d) — the utility surface behind the SyncBadge: pending +
/// dead counts, last sync time + message, the dead-entries list with
/// per-row retry/discard, and a manual "sync now" (flush + pull).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/sync_policy.dart';
import '../../design/design_tokens.dart';
import '../../state/amal_state.dart';
import '../../state/providers.dart' show dbProvider;
import '../../db/database.dart';
import 'widgets.dart';

/// Injectable clock — production reads the wall clock, the golden test
/// pins it so the relative "last synced" label is deterministic.
final syncClockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Dead outbox rows for the sheet's problem list. AutoDispose: dies with the
/// sheet; retry/discard invalidate it for a fresh read.
final deadOutboxProvider = FutureProvider.autoDispose<List<OutboxRow>>(
  (ref) => ref.watch(dbProvider).deadRows(),
);

Future<void> showSyncSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const SyncSheet(),
  );
}

class SyncSheet extends ConsumerWidget {
  const SyncSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sync = ref.watch(syncProvider);
    final theme = Theme.of(context);
    final bn = context.isBn;
    final now = ref.watch(syncClockProvider)();
    final deadRows = ref.watch(deadOutboxProvider).valueOrNull ?? const <OutboxRow>[];
    final defs = ref.watch(amalDefinitionsProvider).valueOrNull;
    String labelOf(String amalKey) =>
        defs?.where((d) => d.key == amalKey).firstOrNull?.titleBn ?? amalKey;

    return SafeArea(
      minimum: const EdgeInsets.only(bottom: SLSpacing.s16),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.8,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s20),
          children: [
            Text(
              context.t('sync_sheet_title'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SLSpacing.s12),

            // Counts + last synced.
            Row(
              children: [
                Icon(
                  sync.dead > 0
                      ? Icons.cloud_off_outlined
                      : Icons.cloud_done_outlined,
                  size: 20,
                  color: sync.dead > 0
                      ? theme.colorScheme.error
                      : theme.colorScheme.primary,
                ),
                const SizedBox(width: SLSpacing.s8),
                Expanded(
                  child: Text(
                    '${toBn(sync.pending)} ${context.t('amal_sync_pending')}',
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              '${context.t('sync_last_synced')}: '
              '${sync.lastSyncedAt == null ? context.t('sync_never') : formatAgoBn(now.difference(sync.lastSyncedAt!), bengali: bn)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (_message(sync, context) != null) ...[
              const SizedBox(height: SLSpacing.s8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Expanded(
                    child: Text(
                      _message(sync, context)!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: SLSpacing.s16),
            FilledButton.icon(
              onPressed: sync.syncing
                  ? null
                  : () => ref.read(syncProvider.notifier).syncNow(),
              icon: sync.syncing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.sync, size: 18),
              label: Text(context.t('sync_now')),
            ),

            // Dead entries: amal label + date + reason, retry + discard.
            if (deadRows.isNotEmpty) ...[
              const SizedBox(height: SLSpacing.s16),
              Text(
                '${context.t('sync_failed_entries')} (${toBn(deadRows.length)})',
                style: theme.textTheme.titleSmall
                    ?.copyWith(color: theme.colorScheme.error),
              ),
              const SizedBox(height: SLSpacing.s4),
              for (final row in deadRows)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    '${labelOf(row.amalKey)} · ${toBnDateKey(row.date, bn)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: row.lastError == null
                      ? null
                      : Text(
                          row.lastError!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: context.t('retry'),
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: () {
                          ref.read(syncProvider.notifier).retryDead(row.id);
                          ref.invalidate(deadOutboxProvider);
                        },
                      ),
                      IconButton(
                        tooltip: context.t('sync_dead_discard'),
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: () {
                          ref.read(syncProvider.notifier).discardDead(row.id);
                          ref.invalidate(deadOutboxProvider);
                        },
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  String? _message(SyncState sync, BuildContext context) {
    if (sync.messageKey != null) return context.t(sync.messageKey!);
    return sync.lastMessage;
  }
}

/// Bengali date-key digits for the dead-row list ("২০২৫-০৬-১৫").
String toBnDateKey(String key, bool bengali) =>
    bengali ? toBn(key) : key;
