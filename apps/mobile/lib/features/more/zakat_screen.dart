/// যাকাত ক্যালকুলেটর — gold/silver/cash/investments/debts inputs;
/// nisab = 85g gold (server-configurable price, offline fallback);
/// CTA opens the donation link in the in-app browser (Chrome Custom Tabs).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/external_urls.dart';
import '../../design/design_tokens.dart';
import '../../state/remote_state.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

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
      orElse: () => kFallbackDonationUrl,
    );
    final canDonate = isLaunchableHttpUrl(donationUrl);

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
      final s = groupLakh(v.round());
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
                field(
                  _gold,
                  context.t('zakat_gold'),
                  PhosphorIconsRegular.wallet,
                ),
                const SizedBox(height: SLSpacing.s8),
                field(
                  _silver,
                  context.t('zakat_silver'),
                  PhosphorIconsRegular.circlesThree,
                ),
                const SizedBox(height: SLSpacing.s8),
                field(
                  _cash,
                  context.t('zakat_cash'),
                  PhosphorIconsRegular.creditCard,
                ),
                const SizedBox(height: SLSpacing.s8),
                field(
                  _invest,
                  context.t('zakat_investments'),
                  PhosphorIconsRegular.trendUp,
                ),
                const SizedBox(height: SLSpacing.s8),
                // No Phosphor 2.1 equivalent (struck-through coin) — the
                // one Material glyph left in the zakat form.
                field(_debts, context.t('zakat_debts'), Icons.money_off),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          AppCard(
            child: Column(
              children: [
                // Label above the figure: at 360dp / 1.3x text the old
                // single row overflowed by 119px.
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text('${context.t('zakat_nisab')}:'),
                ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    '৳${money(nisab)} (${bn ? toBn(85) : 85}g × ৳${money(goldPrice)})',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: SLSpacing.s4),
                const Divider(),
                const SizedBox(height: SLSpacing.s4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: Text('${context.t('zakat_payable')}:')),
                    const SizedBox(width: SLSpacing.s8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerEnd,
                        child: Text(
                          eligible ? '৳${money(zakat)}' : '৳${money(0)}',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: eligible
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s4),
                Text(
                  eligible
                      ? '${context.t('zakat_percent_note')} (${context.t('zakat_net')} ৳${money(net)})'
                      : context.t('zakat_below_nisab'),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          if (eligible && canDonate)
            FilledButton.icon(
              icon: const Icon(PhosphorIconsFill.handHeart),
              label: Text(context.t('zakat_donate')),
              onPressed: () async {
                // C-W3g: in-app browser (Chrome Custom Tabs on Android /
                // SFSafariViewController on iOS); external browser fallback
                // lives inside openInAppBrowser.
                final opened = await openInAppBrowser(donationUrl);
                if (!context.mounted) return;
                if (!opened) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('donation_open_failed'))),
                  );
                }
              },
            ),
          const SizedBox(height: SLSpacing.s8),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    '${context.t('zakat_donation_link')}: $donationUrl',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                // Copy affordance kept (genuinely useful for sharing the
                // link on), alongside the new open action.
                IconButton(
                  tooltip: context.t('copy'),
                  icon: Icon(
                    PhosphorIconsRegular.copy,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: donationUrl));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(context.t('copied'))),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
