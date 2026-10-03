/// ঈমান আত্মমূল্যায়ন (AMOL-11) — the 70 branches of iman (the bundled
/// iman-branches pack) as a private muhasaba: each branch "আছে আলহামদুলিল্লাহ"
/// / "চেষ্টা করছি" / "এখনো নয়". The result is framed as a mirror, not a
/// verdict — the overall share, each group (heart / tongue / body), and the
/// branches to work on next. Answers stay on this phone (SharedPreferences);
/// retaking keeps the last result to compare against.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';

const kImanCheckPrefsKey = 'sl_iman_check_v1';

/// 2 = আছে, 1 = চেষ্টা করছি, 0 = এখনো নয়.
typedef ImanAnswers = Map<int, int>;

/// Share of the full mark (every branch "আছে" = 100). Pure — unit tested.
int imanScorePct(ImanAnswers answers, Iterable<int> ids) {
  final list = ids.toList();
  if (list.isEmpty) return 0;
  final got = list.fold<int>(0, (s, id) => s + (answers[id] ?? 0));
  return (got * 100 / (2 * list.length)).round();
}

/// The saved result: answers + when. Null when never taken (or unreadable).
Future<({ImanAnswers answers, DateTime at})?> loadImanCheck() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(kImanCheckPrefsKey);
    if (raw == null) return null;
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final answers = <int, int>{
      for (final e in (j['answers'] as Map<String, dynamic>).entries)
        int.parse(e.key): (e.value as num).toInt(),
    };
    return (answers: answers, at: DateTime.parse(j['at'] as String));
  } catch (_) {
    return null;
  }
}

Future<void> _saveImanCheck(ImanAnswers answers) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      kImanCheckPrefsKey,
      jsonEncode({
        'answers': {for (final e in answers.entries) '${e.key}': e.value},
        'at': DateTime.now().toIso8601String(),
      }),
    );
  } catch (_) {
    // storage unavailable — the result still shows this session
  }
}

const _groups = <String, (String, IconData)>{
  'heart': ('iman_branch_heart', PhosphorIconsRegular.heart),
  'tongue': ('iman_branch_tongue', PhosphorIconsRegular.userSound),
  'body': ('iman_branch_body', PhosphorIconsRegular.personArmsSpread),
};

class ImanCheckScreen extends StatefulWidget {
  const ImanCheckScreen({super.key, this.branches});

  /// Test seam; the bundled pack otherwise.
  final List<ImanBranch>? branches;

  @override
  State<ImanCheckScreen> createState() => _ImanCheckScreenState();
}

class _ImanCheckScreenState extends State<ImanCheckScreen> {
  late final Future<List<ImanBranch>> _branches =
      widget.branches != null ? Future.value(widget.branches) : ContentPack.imanBranches();
  final ImanAnswers _answers = {};
  ({ImanAnswers answers, DateTime at})? _previous;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    loadImanCheck().then((p) {
      if (mounted) setState(() => _previous = p);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('iman_check_appbar')),
      ),
      body: FutureBuilder<List<ImanBranch>>(
        future: _branches,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 6);
          }
          final branches = [
            for (final b in snap.data ?? const <ImanBranch>[])
              if (b.id != 0) b, // 0 is the root ("ঈমান (মূল)"), not a branch to rate
          ];
          if (branches.isEmpty) {
            return EmptyState(message: context.t('empty_generic'), icon: PhosphorIconsRegular.heart);
          }
          return _showResult
              ? _result(context, branches)
              : _questions(context, branches);
        },
      ),
    );
  }

  Widget _questions(BuildContext context, List<ImanBranch> branches) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';
    final done = branches.where((b) => _answers.containsKey(b.id)).length;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(SLSpacing.s16, SLSpacing.s8, SLSpacing.s16, SLSpacing.s8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('iman_check_intro'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: SLSpacing.s8),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: SLRadius.brPill,
                      child: LinearProgressIndicator(
                        value: done / branches.length,
                        minHeight: 8,
                        backgroundColor: theme.colorScheme.outline,
                      ),
                    ),
                  ),
                  const SizedBox(width: SLSpacing.s8),
                  Text(
                    '${n(done)}/${n(branches.length)}',
                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(SLSpacing.s16, 0, SLSpacing.s16, SLSpacing.s16),
            children: [
              for (final g in _groups.keys)
                if (branches.any((b) => b.group == g)) ...[
                  SectionHeader(context.t(_groups[g]!.$1), icon: _groups[g]!.$2),
                  for (final b in branches.where((b) => b.group == g))
                    Padding(
                      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                      child: AppCard(
                        key: ValueKey('iman_q_${b.id}'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(b.titleBn, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                            if ((b.detailBn ?? '').isNotEmpty)
                              Text(
                                b.detailBn!,
                                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                              ),
                            const SizedBox(height: SLSpacing.s8),
                            Wrap(
                              spacing: SLSpacing.s8,
                              runSpacing: SLSpacing.s8,
                              children: [
                                for (final (v, key) in const [
                                  (2, 'iman_check_have'),
                                  (1, 'iman_check_trying'),
                                  (0, 'iman_check_not_yet'),
                                ])
                                  ChoiceChip(
                                    key: ValueKey('iman_a_${b.id}_$v'),
                                    label: Text(context.t(key)),
                                    selected: _answers[b.id] == v,
                                    // a solid fill per answer (the tint alone
                                    // was ~1.1:1 — the old একা-chip problem);
                                    // "এখনো নয়" is neutral, never red
                                    selectedColor: _fill(theme.colorScheme, v).$1,
                                    checkmarkColor: _fill(theme.colorScheme, v).$2,
                                    labelStyle: _answers[b.id] == v
                                        ? TextStyle(
                                            color: _fill(theme.colorScheme, v).$2,
                                            fontWeight: FontWeight.w700,
                                          )
                                        : null,
                                    onSelected: (_) => setState(() => _answers[b.id] = v),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(SLSpacing.s16, SLSpacing.s8, SLSpacing.s16, SLSpacing.s8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const ValueKey('iman_check_finish'),
                onPressed: done == branches.length
                    ? () async {
                        await _saveImanCheck(_answers);
                        if (mounted) setState(() => _showResult = true);
                      }
                    : null,
                child: Text(
                  done == branches.length
                      ? context.t('iman_check_see_result')
                      : context
                            .t('iman_check_left')
                            .replaceAll('%n%', n(branches.length - done)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _result(BuildContext context, List<ImanBranch> branches) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';
    final pct = imanScorePct(_answers, branches.map((b) => b.id));
    final prev = _previous;
    final prevPct = prev == null ? null : imanScorePct(prev.answers, branches.map((b) => b.id));
    final focus = [for (final b in branches) if (_answers[b.id] == 0) b];
    final trying = [for (final b in branches) if (_answers[b.id] == 1) b];

    return ListView(
      key: const ValueKey('iman_check_result'),
      padding: const EdgeInsets.all(SLSpacing.s16),
      children: [
        AppCard(
          child: Column(
            children: [
              Text(
                '${n(pct)}%',
                style: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w800, color: cs.primary),
              ),
              Text(context.t('iman_check_result_caption'), textAlign: TextAlign.center),
              if (prevPct != null) ...[
                const SizedBox(height: SLSpacing.s4),
                Text(
                  context.t('iman_check_previous').replaceAll('%n%', n(prevPct)),
                  style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: SLSpacing.s8),
        for (final g in _groups.keys)
          if (branches.any((b) => b.group == g))
            Padding(
              padding: const EdgeInsets.only(bottom: SLSpacing.s8),
              child: Row(
                children: [
                  Icon(_groups[g]!.$2, size: 20, color: cs.primary),
                  const SizedBox(width: SLSpacing.s8),
                  SizedBox(width: 110, child: Text(context.t(_groups[g]!.$1))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: SLRadius.brPill,
                      child: LinearProgressIndicator(
                        value: imanScorePct(_answers, branches.where((b) => b.group == g).map((b) => b.id)) / 100,
                        minHeight: 8,
                        backgroundColor: cs.outline,
                        color: cs.tertiary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        if (focus.isNotEmpty) ...[
          SectionHeader(context.t('iman_check_focus'), icon: PhosphorIconsRegular.flagBanner),
          for (final b in focus) _BranchLine(b: b, color: cs.error),
        ],
        if (trying.isNotEmpty) ...[
          SectionHeader(context.t('iman_check_keep_going'), icon: PhosphorIconsRegular.trendUp),
          for (final b in trying) _BranchLine(b: b, color: cs.tertiary),
        ],
        const SizedBox(height: SLSpacing.s8),
        Text(
          context.t('iman_check_private'),
          style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: SLSpacing.s8),
        OutlinedButton(
          onPressed: () => setState(() {
            _previous = (answers: Map.of(_answers), at: DateTime.now());
            _answers.clear();
            _showResult = false;
          }),
          child: Text(context.t('iman_check_retake')),
        ),
      ],
    );
  }
}

(Color, Color) _fill(ColorScheme cs, int v) => switch (v) {
  2 => (cs.primary, cs.onPrimary),
  1 => (cs.tertiary, cs.onTertiary),
  _ => (cs.onSurfaceVariant, cs.surface),
};

class _BranchLine extends StatelessWidget {
  const _BranchLine({required this.b, required this.color});
  final ImanBranch b;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(child: Text(b.titleBn, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
