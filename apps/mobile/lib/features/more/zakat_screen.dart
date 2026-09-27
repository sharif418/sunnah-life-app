/// যাকাত ক্যালকুলেটর — gold/silver/cash/investments/debts inputs;
/// nisab = 85g gold (server-configurable price, offline fallback);
/// CTA shows the donation link.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';

class ZakatScreen extends ConsumerStatefulWidget {
  const ZakatScreen({super.key});

  @override
  ConsumerState<ZakatScreen> createState() => _ZakatScreenState();
}

class _ZakatScreenState extends ConsumerState<ZakatScreen> {
  final _gold = TextEditingController();
  final _silver = TextEditingController();
  final _cash = TextEditingController();
  final _invest = TextEditingController();
  final _debts = TextEditingController();

  @override
  void dispose() {
    _gold.dispose();
    _silver.dispose();
    _cash.dispose();
    _invest.dispose();
    _debts.dispose();
    super.dispose();
  }

  double _num(TextEditingController c) =>
      double.tryParse(c.text.replaceAll(',', '.')) ?? 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final config = ref.watch(configProvider);

    final goldPrice = config.maybeWhen(
      data: (c) => c.goldPerGramBdt,
      orElse: () => kFallbackGoldPerGramBdt,
    );
    final silverPrice = config.maybeWhen(
      data: (c) => c.silverPerGramBdt,
      orElse: () => kFallbackSilverPerGramBdt,
    );
    final donationUrl = config.maybeWhen(
      data: (c) => c.donationUrl,
      orElse: () => 'https://sunnahlife.app',
    );

    // Nisab per the task rule: 85 grams of gold.
    final nisab = 85 * goldPrice;
    final wealth =
        _num(_gold) * goldPrice +
        _num(_silver) * silverPrice +
        _num(_cash) +
        _num(_invest);
    final net = wealth - _num(_debts);
    final eligible = net >= nisab && nisab > 0;
    final zakat = eligible ? net * 0.025 : 0.0;

    String money(double v) {
      final s = v.round().toString();
      return bn ? toBn(s) : s;
    }

    Widget field(TextEditingController c, String label, IconData icon) {
      return TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
        ],
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          isDense: true,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_zakat')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(SLSpacing.s16),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                field(_gold, context.t('zakat_gold'), Icons.wallet_giftcard),
                const SizedBox(height: SLSpacing.s8),
                field(_silver, context.t('zakat_silver'), Icons.workspaces),
                const SizedBox(height: SLSpacing.s8),
                field(_cash, context.t('zakat_cash'), Icons.payments_outlined),
                const SizedBox(height: SLSpacing.s8),
                field(
                  _invest,
                  context.t('zakat_investments'),
                  Icons.trending_up,
                ),
                const SizedBox(height: SLSpacing.s8),
                field(_debts, context.t('zakat_debts'), Icons.money_off),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          AppCard(
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${context.t('zakat_nisab')}:'),
                    Text(
                      '৳${money(nisab)} (${bn ? toBn(85) : 85}g × ৳${money(goldPrice)})',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s4),
                const Divider(),
                const SizedBox(height: SLSpacing.s4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('${context.t('zakat_payable')}:'),
                    Text(
                      eligible ? '৳${money(zakat)}' : '৳${money(0)}',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: eligible
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  eligible
                      ? 'সম্পদের ২.৫% (নেট ৳${money(net)})'
                      : context.t('zakat_below_nisab'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          if (eligible)
            FilledButton.icon(
              icon: const Icon(Icons.volunteer_activism),
              label: Text(context.t('zakat_donate')),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: donationUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${context.t('zakat_donate')}: $donationUrl (${context.t('copied')})',
                      ),
                    ),
                  );
                }
              },
            ),
          const SizedBox(height: SLSpacing.s8),
          Center(
            child: Text(
              'দানের লিংক: $donationUrl',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
