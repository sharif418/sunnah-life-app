/// মাসআলা জিজ্ঞাসা — question form → POST /api/masala (guest-friendly), and
/// for a signed-in member "আমার প্রশ্ন ও উত্তর": their questions with the
/// Foundation's answers (GET /api/masala/mine). An answer also arrives in
/// the bell's inbox and as a push.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../state/providers.dart';
import '../shared/when_bn.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class MasalaScreen extends ConsumerStatefulWidget {
  const MasalaScreen({super.key});

  @override
  ConsumerState<MasalaScreen> createState() => _MasalaScreenState();
}

class _MasalaScreenState extends ConsumerState<MasalaScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _question = TextEditingController();
  bool _sending = false;
  bool _sent = false;
  late Future<List<MasalaItem>?> _mine = _loadMine();

  Future<List<MasalaItem>?> _loadMine() async {
    if (!ref.read(authProvider).signedIn) return null;
    try {
      return await ref.read(apiProvider).myMasala();
    } on ApiException {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _name.text = ref.read(profileProvider).name;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _question.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    try {
      await ref.read(apiProvider).masala(
            name: _name.text.trim(),
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            question: _question.text.trim(),
          );
      setState(() {
        _sent = true;
        _mine = _loadMine();
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_masala')),
      ),
      body: _sent
          ? ListView(
              padding: const EdgeInsets.all(SLSpacing.s16),
              children: [
                const SizedBox(height: SLSpacing.s16),
                Icon(PhosphorIconsRegular.envelopeSimpleOpen,
                    size: 64, color: theme.colorScheme.primary),
                const SizedBox(height: SLSpacing.s16),
                Text(
                  context.t('masala_sent'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: SLSpacing.s16),
                _MyQuestions(future: _mine),
              ],
            )
          : Form(
              key: _form,
              child: ListView(
                padding: const EdgeInsets.all(SLSpacing.s16),
                children: [
                  Text(
                    context.t('masala_note'),
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: SLSpacing.s16),
                  TextFormField(
                    controller: _name,
                    decoration: InputDecoration(
                      labelText: context.t('masala_your_name'),
                      isDense: true,
                    ),
                    validator: (v) =>
                        (v?.trim().isEmpty ?? true) ? context.t('masala_your_name') : null,
                  ),
                  const SizedBox(height: SLSpacing.s12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.t('masala_phone'),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s12),
                  TextFormField(
                    controller: _question,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: context.t('masala_question'),
                      alignLabelWithHint: true,
                    ),
                    validator: (v) => (v?.trim().length ?? 0) < 10
                        ? context.t('masala_question')
                        : null,
                  ),
                  const SizedBox(height: SLSpacing.s16),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(PhosphorIconsRegular.paperPlaneTilt),
                    label: Text(context.t('send')),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  // centred on every line (a Center around a wrapping Text
                  // left-aligned its second line)
                  Text(
                    context.t('masala_offline'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: SLSpacing.s24),
                  _MyQuestions(future: _mine),
                ],
              ),
            ),
    );
  }

}

/// "আমার প্রশ্ন ও উত্তর" — newest first; an answered one shows the answer,
/// a pending one says it is with the scholars. Nothing for guests.
class _MyQuestions extends StatelessWidget {
  const _MyQuestions({required this.future});
  final Future<List<MasalaItem>?> future;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<List<MasalaItem>?>(
      future: future,
      builder: (context, snap) {
        final items = snap.data;
        if (items == null || items.isEmpty) return const SizedBox.shrink();
        return Column(
          key: const ValueKey('masala_mine'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeader(context.t('masala_mine'), icon: PhosphorIconsRegular.chatCircle),
            for (final q in items)
              Padding(
                padding: const EdgeInsets.only(bottom: SLSpacing.s8),
                child: AppCard(
                  key: ValueKey('masala_q_${q.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              whenBn(context, q.createdAt),
                              style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(
                              color: q.answered ? cs.primary : cs.tertiaryContainer,
                              borderRadius: SLRadius.brPill,
                            ),
                            child: Text(
                              context.t(q.answered ? 'masala_answered' : 'masala_pending'),
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: q.answered ? cs.onPrimary : cs.onTertiaryContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SLSpacing.s8),
                      Text(q.question, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                      if (q.answered) ...[
                        const SizedBox(height: SLSpacing.s8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(SLSpacing.s12),
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.07),
                            borderRadius: SLRadius.brMd,
                            border: BorderDirectional(start: BorderSide(color: cs.primary, width: 3)),
                          ),
                          child: Text(q.answer!, style: theme.textTheme.bodyMedium),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
