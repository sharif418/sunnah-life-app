/// ইমান ও তাকওয়া সেলফ-টেস্ট — bundled quiz runner (guest-friendly; scores
/// stay on-device — the server quiz-attempt endpoint requires an account).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

class SelfTestScreen extends ConsumerStatefulWidget {
  const SelfTestScreen({super.key});

  @override
  ConsumerState<SelfTestScreen> createState() => _SelfTestScreenState();
}

class _SelfTestScreenState extends ConsumerState<SelfTestScreen> {
  List<Quiz>? _quizzes;

  @override
  Widget build(BuildContext context) {
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('amal_self_test')),
      ),
      body: FutureBuilder<List<Quiz>>(
        future: _quizzes == null
            ? ContentPack.quizzes()
            : Future.value(_quizzes),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 80, count: 3);
          }
          final quizzes = snap.data ?? const <Quiz>[];
          if (quizzes.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: Icons.quiz_outlined,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              for (final quiz in quizzes)
                AppCard(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => _QuizRunner(quiz: quiz)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quiz.titleBn,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (quiz.descBn?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 4),
                        Text(
                          quiz.descBn!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                      const SizedBox(height: SLSpacing.s8),
                      Text(
                        '${bn ? toBn(quiz.questions.length) : quiz.questions.length} ${context.t('quiz_questions')} · ${bn ? toBn(quiz.minutes) : quiz.minutes} ${context.t('quiz_minutes')}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _QuizRunner extends StatefulWidget {
  const _QuizRunner({required this.quiz});
  final Quiz quiz;

  @override
  State<_QuizRunner> createState() => _QuizRunnerState();
}

class _QuizRunnerState extends State<_QuizRunner> {
  int _index = 0;
  int? _chosen;
  int _score = 0;
  bool _finished = false;

  void _answer(int i) {
    if (_chosen != null) return;
    setState(() => _chosen = i);
    if (i == widget.quiz.questions[_index].answerIndex) {
      setState(() => _score++);
    }
  }

  void _next() {
    if (_index < widget.quiz.questions.length - 1) {
      setState(() {
        _index++;
        _chosen = null;
      });
    } else {
      setState(() => _finished = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final questions = widget.quiz.questions;

    if (_finished) {
      final pct = (100 * _score / questions.length).round();
      return Scaffold(
        appBar: AppBar(title: Text(context.t('quiz_result'))),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(SLSpacing.s32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  pct >= 70 ? Icons.emoji_events : Icons.school_outlined,
                  size: 64,
                  color: pct >= 70
                      ? theme.colorScheme.tertiary
                      : theme.colorScheme.primary,
                ),
                const SizedBox(height: SLSpacing.s16),
                Text(
                  '${bn ? toBn(_score) : _score} / ${bn ? toBn(questions.length) : questions.length} — ${bn ? toBn(pct) : pct}%',
                  style: theme.textTheme.headlineMedium,
                ),
                const SizedBox(height: SLSpacing.s8),
                Text(
                  pct >= 70
                      ? context.t('quiz_great')
                      : context.t('quiz_needs_more'),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: SLSpacing.s24),
                FilledButton(
                  onPressed: () => setState(() {
                    _index = 0;
                    _chosen = null;
                    _score = 0;
                    _finished = false;
                  }),
                  child: Text(context.t('quiz_retry')),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final q = questions[_index];
    final correct = _chosen != null && _chosen == q.answerIndex;
    return Scaffold(
      appBar: AppBar(title: Text(widget.quiz.titleBn)),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: SLRadius.brPill,
                  child: LinearProgressIndicator(
                    value: (_index + 1) / questions.length,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: SLSpacing.s12),
              Text(
                '${bn ? toBn(_index + 1) : _index + 1}/${bn ? toBn(questions.length) : questions.length}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s16),
          Text(q.questionBn, style: theme.textTheme.titleMedium),
          const SizedBox(height: SLSpacing.s16),
          for (var i = 0; i < q.options.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: SLSpacing.s8),
              child: _OptionTile(
                label: q.options[i],
                state: _chosen == null
                    ? null
                    : (i == q.answerIndex
                          ? _OptionState.correct
                          : (i == _chosen ? _OptionState.wrong : null)),
                onTap: () => _answer(i),
              ),
            ),
          if (_chosen != null) ...[
            if (q.explanationBn?.isNotEmpty ?? false)
              Padding(
                padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                child: Text(
                  q.explanationBn!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            FilledButton(
              onPressed: _next,
              child: Text(
                // Direction-agnostic arrow (mirrors automatically in RTL).
                '${correct ? context.t('quiz_correct') : context.t('quiz_wrong')} →',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum _OptionState { correct, wrong }

class _OptionTile extends StatelessWidget {
  const _OptionTile({required this.label, required this.onTap, this.state});
  final String label;
  final VoidCallback onTap;
  final _OptionState? state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (state) {
      _OptionState.correct => theme.colorScheme.primary,
      _OptionState.wrong => theme.colorScheme.error,
      null => theme.colorScheme.surfaceContainerLow,
    };
    return Material(
      color: color,
      borderRadius: SLRadius.brMd,
      child: InkWell(
        onTap: state == null ? onTap : null,
        borderRadius: SLRadius.brMd,
        child: Container(
          constraints: const BoxConstraints(
            minHeight: SLSpacing.minTapTarget + 8,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: SLSpacing.s12,
          ),
          decoration: BoxDecoration(
            borderRadius: SLRadius.brMd,
            border: Border.all(color: color, width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
              if (state == _OptionState.correct)
                Icon(Icons.check_circle, color: theme.colorScheme.onPrimary)
              else if (state == _OptionState.wrong)
                Icon(Icons.cancel, color: theme.colorScheme.onError),
            ],
          ),
        ),
      ),
    );
  }
}
