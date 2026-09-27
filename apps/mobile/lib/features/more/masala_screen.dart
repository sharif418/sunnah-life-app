/// মাসআলা জিজ্ঞাসা — question form → POST /api/masala (guest-friendly).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../api/api_client.dart';
import '../../design/design_tokens.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';

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
      setState(() => _sent = true);
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
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(SLSpacing.s32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.mark_email_read_outlined,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: SLSpacing.s16),
                    Text(
                      context.t('masala_sent'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
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
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.send_outlined),
                    label: Text(context.t('send')),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  Center(
                    child: Text(
                      context.t('masala_offline'),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

}
