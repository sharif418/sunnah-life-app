/// কুইজ — self-paced quiz list with attempt history + the player (B9).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../api/api_client.dart';
import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';
import 'upcoming_quizzes.dart';
import '../../design/phosphor_icons.dart';

/// Digit formatter following the app language (bn → Bengali numerals).
String _n(BuildContext context, Object value) =>
    context.isBn ? toBn(value) : value.toString();

class QuizzesScreen extends ConsumerWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild when the session flips so the attempt chips follow sign-in.
    ref.watch(authProvider);
    final quizzesAsync = ref.watch(quizPackProvider);
    final attemptsAsync = ref.watch(quizAttemptsProvider);

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_quizzes')),
      ),
      body: quizzesAsync.when(
        loading: () => const Skeleton(height: 148, count: 4),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s24),
            ErrorState(
              message: e is ApiException
                  ? e.message
                  : context.t('quizzes_load_failed'),
              onRetry: () => ref.invalidate(quizPackProvider),
            ),
          ],
        ),
        data: (quizzes) {
          if (quizzes.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                EmptyState(
                  message:
                      '${context.t('quizzes_empty_title')}\n'
                      '${context.t('quizzes_empty_hint')}',
                  icon: PhosphorIconsRegular.question,
                ),
              ],
            );
          }
          final attempts = attemptsAsync.valueOrNull;
          // AMOL-17: scheduled live quizzes first, then the practice list
          return ListView.builder(
            padding: const EdgeInsets.all(SLSpacing.s16),
            itemCount: quizzes.length + 1,
            itemBuilder: (context, i) => i == 0
                ? const UpcomingQuizzesSection()
                : _quizCard(
                    context,
                    quizzes[i - 1],
                    attempts?.where((a) => a.quizId == quizzes[i - 1].id).toList(),
                  ),
          );
        },
      ),
    );
  }

  Widget _quizCard(BuildContext context, Quiz q, List<QuizAttemptItem>? mine) {
    final theme = Theme.of(context);
    QuizAttemptItem? best;
    QuizAttemptItem? last;
    if (mine != null && mine.isNotEmpty) {
      double ratio(QuizAttemptItem a) => a.total == 0 ? 0 : a.score / a.total;
      best = mine.reduce((a, b) => ratio(a) >= ratio(b) ? a : b);
      last = mine.reduce(
        (a, b) => a.createdAt.compareTo(b.createdAt) >= 0 ? a : b,
      );
    }
    final meta = [
      '${_n(context, q.questions.length)} ${context.t('quiz_questions')}',
      '${_n(context, q.minutes)} ${context.t('quiz_minutes')}',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s12),
      child: AppCard(
        onTap: () => context.push('/ilm/quizzes/${q.id}'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    q.titleBn,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (q.live) ...[
                  const SizedBox(width: SLSpacing.s8),
                  _GoldChip(context.t('quiz_live_eligible')),
                ],
              ],
            ),
            if (q.descBn?.isNotEmpty ?? false) ...[
              const SizedBox(height: SLSpacing.s4),
              Text(
                q.descBn!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: SLSpacing.s4),
            Text(meta, style: theme.textTheme.bodySmall),
            if (best != null && last != null) ...[
              const SizedBox(height: SLSpacing.s8),
              Row(
                children: [
                  _GoldChip(
                    '${context.t('quiz_best')} '
                    '${_n(context, best.score)}/${_n(context, best.total)}',
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Flexible(
                    child: Text(
                      '${context.t('quiz_last')}: '
                      '${_n(context, last.score)}/${_n(context, last.total)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: SLSpacing.s12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.push('/ilm/quizzes/${q.id}'),
                child: Text(context.t('quiz_play')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gold pill (live-eligible / best-score chip) — mirrors the status pills.
class _GoldChip extends StatelessWidget {
  const _GoldChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary.withValues(alpha: 0.15),
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        label,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.tertiary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class QuizPlayerScreen extends ConsumerStatefulWidget {
  const QuizPlayerScreen({super.key, required this.quizId});

  final String quizId;

  @override
  ConsumerState<QuizPlayerScreen> createState() => _QuizPlayerScreenState();
}

class _QuizPlayerScreenState extends ConsumerState<QuizPlayerScreen> {
  int _index = 0;
  int? _picked;
  int _score = 0;
  bool _finished = false;
  bool _submitted = false;
  bool _savedToServer = false;
  String? _saveNote;

  void _reset() {
    setState(() {
      _index = 0;
      _picked = null;
      _score = 0;
      _finished = false;
      _submitted = false;
      _savedToServer = false;
      _saveNote = null;
    });
  }

  void _backToList() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/ilm/quizzes');
    }
  }

  void _pick(QuizQuestion q, int i) {
    if (_picked != null) return; // options lock after the first tap
    setState(() {
      _picked = i;
      if (i == q.answerIndex) _score++;
    });
  }

  Future<void> _finish(Quiz quiz) async {
    final guestNote = context.t('quiz_result_local');
    setState(() => _finished = true);
    if (_submitted) return;
    _submitted = true;
    if (ref.read(authProvider).signedIn) {
      try {
        await ref
            .read(apiProvider)
            .submitQuizAttempt(
              quizId: widget.quizId,
              score: _score,
              total: quiz.questions.length,
            );
        ref.invalidate(quizAttemptsProvider);
        if (!mounted) return;
        setState(() {
          _savedToServer = true;
          _saveNote = context.t('quiz_result_saved');
        });
        return;
      } catch (_) {
        // Offline — treat the run like a guest's (local note only).
      }
    }
    if (mounted) setState(() => _saveNote = guestNote);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(quizPackProvider);
    final quiz = async.valueOrNull
        ?.where((q) => q.id == widget.quizId)
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(
          quiz?.titleBn ?? context.t('ilm_quizzes'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: async.when(
        loading: () => const Skeleton(height: 96, count: 5),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: SLSpacing.s24),
            ErrorState(
              message: e is ApiException
                  ? e.message
                  : context.t('quizzes_load_failed'),
              onRetry: () => ref.invalidate(quizPackProvider),
            ),
          ],
        ),
        data: (quizzes) {
          if (quiz == null) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                ErrorState(
                  message: context.t('quizzes_load_failed'),
                  onRetry: () => ref.invalidate(quizPackProvider),
                ),
              ],
            );
          }
          if (quiz.questions.isEmpty) {
            return ListView(
              children: [
                const SizedBox(height: SLSpacing.s24),
                EmptyState(
                  message: context.t('quizzes_empty_title'),
                  icon: PhosphorIconsRegular.question,
                ),
              ],
            );
          }
          return _finished
              ? _buildResult(context, quiz)
              : _buildQuestion(context, quiz);
        },
      ),
    );
  }

  Widget _buildQuestion(BuildContext context, Quiz quiz) {
    final theme = Theme.of(context);
    final total = quiz.questions.length;
    final q = quiz.questions[_index];
    final answered = _picked != null;
    final correctPick = answered && _picked == q.answerIndex;

    return SafeArea(
      top: false,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s12,
              SLSpacing.s16,
              SLSpacing.s4,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.12),
                    borderRadius: SLRadius.brPill,
                  ),
                  child: Text(
                    '${context.t('quiz_question_of')} '
                    '${_n(context, _index + 1)}/${_n(context, total)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: (_index + 1) / total,
                      minHeight: 4,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(SLSpacing.s16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(q.questionBn, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: SLSpacing.s16),
                  for (var i = 0; i < q.options.length; i++)
                    _optionRow(context, q, i),
                  if (answered && !correctPick) ...[
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      '${context.t('quiz_correct_was')}: '
                      '${q.options[q.answerIndex]}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                  if (answered && (q.explanationBn?.isNotEmpty ?? false)) ...[
                    const SizedBox(height: SLSpacing.s12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(SLSpacing.s12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondary,
                        borderRadius: SLRadius.brMd,
                      ),
                      child: Text(
                        '${context.t('quiz_explanation')}: ${q.explanationBn}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (answered)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SLSpacing.s16,
                SLSpacing.s8,
                SLSpacing.s16,
                SLSpacing.s16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    if (_index + 1 < total) {
                      setState(() {
                        _index++;
                        _picked = null;
                      });
                    } else {
                      _finish(quiz);
                    }
                  },
                  child: Text(
                    context.t(
                      _index + 1 < total ? 'quiz_next_question' : 'quiz_finish',
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _optionRow(BuildContext context, QuizQuestion q, int i) {
    final theme = Theme.of(context);
    final answered = _picked != null;
    final isCorrect = answered && i == q.answerIndex;
    final isWrongPick = answered && i == _picked && i != q.answerIndex;

    final Color rowBg;
    final Color rowBorder;
    final Color rowFg;
    final Color circleBg;
    final Color circleFg;
    Widget? trailing;
    var dimmed = false;
    if (isCorrect) {
      rowBg = theme.colorScheme.primary.withValues(alpha: 0.10);
      rowBorder = theme.colorScheme.primary;
      rowFg = theme.colorScheme.primary;
      circleBg = theme.colorScheme.primary;
      circleFg = theme.colorScheme.onPrimary;
      trailing = Icon(
        PhosphorIconsFill.checkCircle,
        size: 22,
        color: theme.colorScheme.primary,
      );
    } else if (isWrongPick) {
      rowBg = theme.colorScheme.error.withValues(alpha: 0.08);
      rowBorder = theme.colorScheme.error;
      rowFg = theme.colorScheme.error;
      circleBg = theme.colorScheme.error;
      circleFg = theme.colorScheme.onError;
      trailing = Icon(PhosphorIconsRegular.xCircle, size: 22, color: theme.colorScheme.error);
    } else {
      rowBg = theme.colorScheme.surfaceContainerLow;
      rowBorder = theme.colorScheme.outline;
      rowFg = theme.colorScheme.onSurface;
      circleBg = theme.colorScheme.surfaceContainerHighest;
      circleFg = theme.colorScheme.onSurfaceVariant;
      dimmed = answered;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: rowBg,
        borderRadius: SLRadius.brMd,
        child: InkWell(
          onTap: answered ? null : () => _pick(q, i),
          borderRadius: SLRadius.brMd,
          child: Opacity(
            opacity: dimmed ? 0.55 : 1.0,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s12,
                vertical: SLSpacing.s12,
              ),
              decoration: BoxDecoration(
                borderRadius: SLRadius.brMd,
                border: Border.all(
                  color: rowBorder,
                  width: isCorrect || isWrongPick ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: circleBg,
                    ),
                    child: Center(
                      child: Text(
                        _n(context, i + 1),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: circleFg,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: Text(
                      q.options[i],
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: rowFg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: SLSpacing.s8),
                    trailing,
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResult(BuildContext context, Quiz quiz) {
    final theme = Theme.of(context);
    final total = quiz.questions.length;
    final great = total > 0 && _score / total >= 0.8;
    final ringColor = great
        ? theme.colorScheme.primary
        : theme.colorScheme.tertiary;

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(SLSpacing.s24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: '${_n(context, _score)}/${_n(context, total)}',
                child: SizedBox(
                  width: 168,
                  height: 168,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 168,
                        height: 168,
                        child: CircularProgressIndicator(
                          value: _score / total,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: ringColor,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      Text(
                        '${_n(context, _score)}/${_n(context, total)}',
                        style: theme.textTheme.displaySmall?.copyWith(
                          color: ringColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: SLSpacing.s16),
              Text(
                context.t(great ? 'quiz_great' : 'quiz_needs_more'),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (_saveNote != null) ...[
                const SizedBox(height: SLSpacing.s8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _savedToServer
                          ? PhosphorIconsRegular.cloudCheck
                          : PhosphorIconsRegular.cloudSlash,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: SLSpacing.s4),
                    Flexible(
                      child: Text(
                        _saveNote!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: SLSpacing.s24),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: const Icon(PhosphorIconsRegular.arrowCounterClockwise),
                  onPressed: _reset,
                  label: Text(context.t('quiz_play_again')),
                ),
              ),
              const SizedBox(height: SLSpacing.s8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _backToList,
                  child: Text(context.t('quiz_back_to_list')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
