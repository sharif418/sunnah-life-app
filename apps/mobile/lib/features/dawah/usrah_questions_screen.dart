/// উসরার প্রশ্নোত্তর — the usrah question board (B9). Members ask inside
/// their own usrah (POST /api/usrah-questions, RLS), the usrah head (role
/// rank ≥ 2) answers (POST /api/usrah-questions/:id/answers). The board is
/// only ever the caller's OWN usrah — server-side row-level security.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

/// The six board categories (API enum) in display order.
const List<String> _kCategories = [
  'general',
  'aqeedah',
  'salah',
  'quran',
  'muamalah',
  'tarbiyah',
];

class UsrahQuestionsScreen extends ConsumerStatefulWidget {
  const UsrahQuestionsScreen({super.key});

  @override
  ConsumerState<UsrahQuestionsScreen> createState() =>
      _UsrahQuestionsScreenState();
}

class _UsrahQuestionsScreenState extends ConsumerState<UsrahQuestionsScreen> {
  final _questionCtrl = TextEditingController();
  final _answerCtrl = TextEditingController();
  String _category = 'general';
  bool _sending = false;

  /// The question whose inline answer editor is open (head only).
  String? _openAnswerId;

  @override
  void dispose() {
    _questionCtrl.dispose();
    _answerCtrl.dispose();
    super.dispose();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ── actions ────────────────────────────────────────────────────────────────

  Future<void> _ask() async {
    final text = _questionCtrl.text.trim();
    if (text.length < 8) {
      _snack(context.t('usrah_q_ask_hint'));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref
          .read(apiProvider)
          .askUsrahQuestion(question: text, category: _category);
      if (!mounted) return;
      _questionCtrl.clear();
      _snack(context.t('usrah_q_sent'));
      ref.invalidate(usrahQuestionsProvider);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _submitAnswer(UsrahQuestion q) async {
    final text = _answerCtrl.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).answerUsrahQuestion(id: q.id, answer: text);
      if (!mounted) return;
      _answerCtrl.clear();
      setState(() => _openAnswerId = null);
      _snack(context.t('usrah_q_answered'));
      ref.invalidate(usrahQuestionsProvider);
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // ── build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    Widget body;
    if (auth.status == AuthStatus.loading) {
      body = const Skeleton(height: 96, count: 4);
    } else if (!auth.signedIn) {
      body = _Gate(
        title: context.t('usrah_q_title'),
        hint: context.t('usrah_q_hint'),
        actionLabel: context.t('onb_signin'),
        onAction: () => context.push('/auth'),
      );
    } else {
      // Usrah head / invigilator / full admin may answer (ROLE_RANK >= 2).
      final isHead = (auth.user?.role.rank ?? 0) >= 2;
      final questions =
          ref.watch(usrahQuestionsProvider).value ?? const <UsrahQuestion>[];
      body = RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(usrahQuestionsProvider);
          await ref.read(usrahQuestionsProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.all(SLSpacing.s16),
          children: [
            _AskForm(
              controller: _questionCtrl,
              category: _category,
              sending: _sending,
              onCategory: (c) => setState(() => _category = c),
              onSend: _ask,
            ),
            const SizedBox(height: SLSpacing.s16),
            if (questions.isEmpty)
              EmptyState(
                message: context.t('usrah_q_empty'),
                icon: PhosphorIconsRegular.chats,
              )
            else
              for (final q in questions) ...[
                _QuestionCard(
                  question: q,
                  isHead: isHead,
                  open: _openAnswerId == q.id,
                  sending: _sending,
                  answerController: _answerCtrl,
                  onToggleAnswer: () => setState(() {
                    _openAnswerId = _openAnswerId == q.id ? null : q.id;
                    _answerCtrl.clear();
                  }),
                  onSubmitAnswer: () => _submitAnswer(q),
                ),
                const SizedBox(height: SLSpacing.s12),
              ],
            const SizedBox(height: SLSpacing.s24),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('usrah_q_title')),
        actions: [
          IconButton(
            tooltip: context.t('retry'),
            icon: const Icon(PhosphorIconsRegular.arrowClockwise),
            onPressed: () => ref.invalidate(usrahQuestionsProvider),
          ),
        ],
      ),
      body: body,
    );
  }
}

// ── signed-out gate ──────────────────────────────────────────────────────────

class _Gate extends StatelessWidget {
  const _Gate({
    required this.title,
    required this.hint,
    required this.actionLabel,
    required this.onAction,
  });
  final String title;
  final String hint;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(SLSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              PhosphorIconsRegular.chats,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: SLSpacing.s16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(PhosphorIconsRegular.signIn, size: 18),
              label: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

// ── ask form ─────────────────────────────────────────────────────────────────

class _AskForm extends StatelessWidget {
  const _AskForm({
    required this.controller,
    required this.category,
    required this.sending,
    required this.onCategory,
    required this.onSend,
  });
  final TextEditingController controller;
  final String category;
  final bool sending;
  final ValueChanged<String> onCategory;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            style: theme.textTheme.bodyMedium,
            decoration: InputDecoration(
              hintText: context.t('usrah_q_ask_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          Wrap(
            spacing: SLSpacing.s8,
            runSpacing: SLSpacing.s8,
            children: [
              for (final c in _kCategories)
                _CategoryChip(
                  labelKey:
                      UsrahQuestion.categoryLabelKeys[c] ??
                      'usrah_q_cat_general',
                  selected: category == c,
                  onTap: () => onCategory(c),
                ),
            ],
          ),
          const SizedBox(height: SLSpacing.s12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: sending ? null : onSend,
              icon: sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(PhosphorIconsRegular.paperPlaneTilt, size: 18),
              label: Text(
                context.t(sending ? 'usrah_q_sending' : 'usrah_q_send'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.labelKey,
    required this.selected,
    required this.onTap,
  });
  final String labelKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: selected ? theme.colorScheme.primary : Colors.transparent,
      borderRadius: SLRadius.brPill,
      child: InkWell(
        onTap: onTap,
        borderRadius: SLRadius.brPill,
        child: Container(
          constraints: const BoxConstraints(minHeight: 36),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: SLRadius.brPill,
            border: Border.all(
              color: selected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.outline,
            ),
          ),
          // shrink-wrap: a Center here took the Wrap's full width, so every
          // chip sat on its own line
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.t(labelKey),
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── question card ─────────────────────────────────────────────────────────────

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.question,
    required this.isHead,
    required this.open,
    required this.sending,
    required this.answerController,
    required this.onToggleAnswer,
    required this.onSubmitAnswer,
  });
  final UsrahQuestion question;
  final bool isHead;
  final bool open;
  final bool sending;
  final TextEditingController answerController;
  final VoidCallback onToggleAnswer;
  final VoidCallback onSubmitAnswer;

  static String _date(String iso) =>
      iso.length >= 10 ? iso.substring(0, 10) : iso;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final q = question;

    return AppCard(
      padding: const EdgeInsets.all(SLSpacing.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // header: category + author + date
          Wrap(
            spacing: SLSpacing.s8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  context.t(q.categoryLabelKey),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Text(
                [
                  if (q.authorName != null && q.authorName!.isNotEmpty)
                    q.authorName!,
                  _date(q.createdAt),
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          Text(
            q.question,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.6,
            ),
          ),

          // answered → the published answer block
          if (q.answer != null && q.answer!.isNotEmpty) ...[
            const SizedBox(height: SLSpacing.s12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(SLSpacing.s12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: SLRadius.brMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${q.answeredByName ?? ''} — ${context.t('usrah_q_answered_by')}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s4),
                  Text(
                    q.answer!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.6),
                  ),
                  if (q.answeredAt != null && q.answeredAt!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: SLSpacing.s4),
                      child: Text(
                        _date(q.answeredAt!),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: SLSpacing.s12),
            if (isHead && open)
              // head: inline answer editor
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: answerController,
                    minLines: 3,
                    maxLines: 6,
                    autofocus: true,
                    textInputAction: TextInputAction.newline,
                    style: theme.textTheme.bodyMedium,
                    decoration: InputDecoration(
                      hintText: context.t('usrah_q_answer_hint'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  Row(
                    children: [
                      Expanded(
                        // Rebuilds as the head types (empty → disabled).
                        child: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: answerController,
                          builder: (context, value, _) => FilledButton.icon(
                            onPressed: sending || value.text.trim().isEmpty
                                ? null
                                : onSubmitAnswer,
                            icon: sending
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    PhosphorIconsRegular.paperPlaneTilt,
                                    size: 16,
                                  ),
                            label: Text(context.t('usrah_q_answer_submit')),
                          ),
                        ),
                      ),
                      const SizedBox(width: SLSpacing.s8),
                      OutlinedButton(
                        onPressed: onToggleAnswer,
                        child: Text(context.t('cancel')),
                      ),
                    ],
                  ),
                ],
              )
            else if (isHead)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: onToggleAnswer,
                  icon: const Icon(PhosphorIconsRegular.pencilSimple, size: 18),
                  label: Text(context.t('usrah_q_answer_hint')),
                ),
              )
            else
              // member: awaiting the head's answer
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.tertiary.withValues(
                          alpha: 0.14,
                        ),
                        borderRadius: SLRadius.brPill,
                      ),
                      child: Text(
                        context.t('usrah_q_awaiting'),
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.tertiary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }
}
