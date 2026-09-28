/// Reminder panel (C-W4a) — the header clock's bottom sheet.
///
/// Mirrors the web shell's bell sheet data (GET /api/reminders —
/// ApiClient.reminders()), extended with the mobile task's lifecycle ask:
/// every row derives a due / overdue / upcoming / done state
/// (core/reminder_states.dart — pure, unit-tested) and unread rows carry a
/// mark-done action (PATCH /api/reminders read=true — the only mutation the
/// API offers; "done" IS "read" server-side, no richer lifecycle exists).
/// Guests get the sign-in hint (the endpoint is user-scoped).
///
/// The fetch happens when the sheet OPENS (not eagerly on tab screens) and
/// the mark-done write is optimistic — the row flips instantly and a failed
/// PATCH reverts it with a snackbar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../design/phosphor_icons.dart';

import '../../api/api_client.dart';
import '../../core/reminder_states.dart';
import '../../design/design_tokens.dart';
import '../../models/live.dart';
import '../../state/providers.dart';
import 'widgets.dart';

Future<void> showRemindersSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _RemindersSheet(),
  );
}

class _RemindersSheet extends ConsumerStatefulWidget {
  const _RemindersSheet();

  @override
  ConsumerState<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends ConsumerState<_RemindersSheet> {
  List<ReminderItem>? _items;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await ref.read(apiProvider).reminders();
      if (!mounted) return;
      setState(() {
        _items = items..sort(
              (a, b) => reminderSort(a, b, DateTime.now()),
            );
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _markDone(ReminderItem item) async {
    // Optimistic: flip locally, revert on failure.
    setState(() {
      _items = [
        for (final r in _items ?? const <ReminderItem>[])
          r.id == item.id ? _copyAsRead(r) : r,
      ];
    });
    try {
      await ref.read(apiProvider).readReminder(item.id);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _items = [
          for (final r in _items ?? const <ReminderItem>[])
            r.id == item.id ? item : r,
        ];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    }
  }

  static ReminderItem _copyAsRead(ReminderItem r) => ReminderItem(
        id: r.id,
        kind: r.kind,
        title: r.title,
        body: r.body,
        link: r.link,
        scheduledAt: r.scheduledAt,
        read: true,
        createdAt: r.createdAt,
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final signedIn = ref.watch(authProvider.select((s) => s.signedIn));

    Widget body;
    if (!signedIn) {
      body = EmptyState(
        message: context.t('notifications_guest_hint'),
        icon: PhosphorIconsRegular.clockUser,
      );
    } else if (_loading) {
      body = const SizedBox(
        height: 160,
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if ((_items ?? const []).isEmpty) {
      body = EmptyState(
        message: context.t('reminders_empty'),
        icon: PhosphorIconsRegular.clock,
      );
    } else {
      body = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in _items!)
            _ReminderRow(item: item, onMarkDone: () => _markDone(item)),
        ],
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          SLSpacing.s16,
          0,
          SLSpacing.s16,
          SLSpacing.s16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('header_reminders'),
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: SLSpacing.s4),
            Flexible(child: SingleChildScrollView(child: body)),
          ],
        ),
      ),
    );
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({required this.item, required this.onMarkDone});
  final ReminderItem item;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = reminderUiState(item, DateTime.now());
    final (chipKey, color) = switch (state) {
      ReminderUiState.done => ('done', theme.colorScheme.outline),
      ReminderUiState.overdue => (
          'reminder_overdue',
          theme.colorScheme.error
        ),
      ReminderUiState.due => ('reminder_due', theme.colorScheme.tertiary),
      ReminderUiState.upcoming => (
          'reminder_upcoming',
          theme.colorScheme.primary
        ),
    };
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  context.t(chipKey),
                  style: theme.textTheme.bodySmall?.copyWith(color: color),
                ),
              ),
              const Spacer(),
              if (item.scheduledAt != null && item.scheduledAt!.length >= 16)
                Text(
                  item.scheduledAt!.substring(0, 16).replaceAll('T', ' '),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            item.title,
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if ((item.body ?? '').isNotEmpty)
            Text(
              item.body!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (state != ReminderUiState.done)
            Padding(
              padding: const EdgeInsets.only(top: SLSpacing.s8),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: onMarkDone,
                  icon: const Icon(PhosphorIconsRegular.checkCircle),
                  label: Text(context.t('reminder_mark_done')),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
