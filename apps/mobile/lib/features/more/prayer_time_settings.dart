/// Prayer-time settings sheets (profile → অবস্থান ও মাযহাব):
///  • the calculation method — each with one line on what it is for, the
///    Islamic Foundation Bangladesh method marked recommended;
///  • "নিজের মসজিদের সাথে মেলান" — ± minutes per farz waqt, each row
///    showing the calculated time and the reader's own; edits are saved on
///    «সংরক্ষণ করুন» (a dismissed sheet changes nothing).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../core/prayer_adjust.dart';
import '../../core/prayer_engine.dart';
import '../../core/date_keys.dart';
import '../../design/design_tokens.dart';
import '../../design/phosphor_icons.dart';
import '../../models/domain.dart';
import '../../state/providers.dart';
import '../home/sun_arc_card.dart' show clockOnly;
import '../shared/widgets.dart';

/// "ফজর +২ · মাগরিব +৫" / "সমন্বয় নেই".
String prayerAdjustSummary(BuildContext context, PrayerAdjust a) {
  if (a.isEmpty) return context.t('adjust_none');
  final bn = context.isBn;
  return [
    for (final k in PrayerAdjust.keys)
      if (a.of(k) != 0)
        '${context.t('waqt_${k.name}')} ${_signed(a.of(k), bn)}',
  ].join(' · ');
}

String _signed(int v, bool bn) {
  final sign = v > 0 ? '+' : (v < 0 ? '−' : '');
  final n = v.abs();
  return '$sign${bn ? toBn(n) : '$n'}';
}

String _methodDescKey(CalcMethod m) => 'method_desc_${m.json}';

Future<void> showMethodPicker(BuildContext context, WidgetRef ref) async {
  final current = ref.read(profileProvider).method;
  final picked = await showModalBottomSheet<CalcMethod>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) {
      final theme = Theme.of(sheet);
      final cs = theme.colorScheme;
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheet).height * 0.85,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              0,
              SLSpacing.s16,
              SLSpacing.s16,
            ),
            children: [
              Text(
                sheet.t('onb_method'),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s4),
              Text(
                sheet.t('method_pick_hint'),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: SLSpacing.s12),
              for (final m in CalcMethod.values)
                _MethodOption(
                  method: m,
                  selected: m == current,
                  recommended: m == CalcMethod.ifb,
                  onTap: () => Navigator.pop(sheet, m),
                ),
            ],
          ),
        ),
      );
    },
  );
  if (picked != null && picked != current) {
    await ref.read(profileProvider.notifier).update(method: picked);
  }
}

class _MethodOption extends StatelessWidget {
  const _MethodOption({
    required this.method,
    required this.selected,
    required this.recommended,
    required this.onTap,
  });
  final CalcMethod method;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s8),
      child: Material(
        color: selected ? cs.primaryContainer : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: SLRadius.brMd,
          side: BorderSide(color: selected ? cs.primary : cs.outline),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Semantics(
            selected: selected,
            button: true,
            child: Padding(
              padding: const EdgeInsets.all(SLSpacing.s12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(
                      selected
                          ? PhosphorIconsFill.checkCircle
                          : PhosphorIconsRegular.circle,
                      size: 22,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: SLSpacing.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: SLSpacing.s8,
                          runSpacing: 2,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              context.t(method.labelKey),
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (recommended)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: SLRadius.brPill,
                                ),
                                child: Text(
                                  context.t('method_recommended'),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.onPrimary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t(_methodDescKey(method)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showPrayerAdjustSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _PrayerAdjustSheet(),
  );
}

class _PrayerAdjustSheet extends ConsumerStatefulWidget {
  const _PrayerAdjustSheet();

  @override
  ConsumerState<_PrayerAdjustSheet> createState() => _PrayerAdjustSheetState();
}

class _PrayerAdjustSheetState extends ConsumerState<_PrayerAdjustSheet> {
  late PrayerAdjust _draft = ref.read(profileProvider).prayerAdjust;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final profile = ref.watch(profileProvider);
    // today's calculated times without the reader's minutes
    final calc = PrayerEngine.compute(
      dateKey(DateTime.now()),
      lat: profile.lat,
      lng: profile.lng,
      tz: profile.tz,
      method: profile.method,
      madhhab: profile.madhhab,
    );
    final changed = _draft != profile.prayerAdjust;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            0,
            SLSpacing.s16,
            SLSpacing.s16,
          ),
          children: [
            Text(
              context.t('adjust_title'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s4),
            Text(
              context.t('adjust_hint'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s12),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (final (i, k) in PrayerAdjust.keys.indexed) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        color: cs.outline.withValues(alpha: 0.6),
                      ),
                    _AdjustRow(
                      waqt: k,
                      calculated: calc.byKey(k),
                      minutes: _draft.of(k),
                      bengali: bn,
                      onChanged: (v) =>
                          setState(() => _draft = _draft.withValue(k, v)),
                    ),
                  ],
                ],
              ),
            ),
            if (_draft.anyEarlier) ...[
              const SizedBox(height: SLSpacing.s12),
              Container(
                padding: const EdgeInsets.all(SLSpacing.s12),
                decoration: BoxDecoration(
                  // a calm caution, not an error: a soft tint, the text in the alert ink
                  color: cs.error.withValues(alpha: 0.08),
                  border: Border.all(color: cs.error.withValues(alpha: 0.35)),
                  borderRadius: SLRadius.brMd,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      PhosphorIconsRegular.warningCircle,
                      size: 18,
                      color: cs.error,
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Expanded(
                      child: Text(
                        context.t('adjust_earlier_warning'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: SLSpacing.s12),
            Text(
              context.t('adjust_where'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),
            // the primary takes the remaining width (a bigger, surer
            // target) and wraps first at large text on a narrow phone
            Row(
              children: [
                TextButton(
                  onPressed: _draft.isEmpty
                      ? null
                      : () => setState(() => _draft = const PrayerAdjust()),
                  child: Text(context.t('adjust_reset')),
                ),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: FilledButton(
                    onPressed: () async {
                      if (changed) {
                        await ref
                            .read(profileProvider.notifier)
                            .update(prayerAdjust: _draft);
                      }
                      if (context.mounted) Navigator.pop(context);
                    },
                    child: Text(
                      context.t('adjust_save'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustRow extends StatelessWidget {
  const _AdjustRow({
    required this.waqt,
    required this.calculated,
    required this.minutes,
    required this.bengali,
    required this.onChanged,
  });
  final PrayerKey waqt;
  final double calculated;
  final int minutes;
  final bool bengali;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final name = context.t('waqt_${waqt.name}');
    final calc = clockOnly(calculated, bengali: bengali);
    final mine = clockOnly(calculated + minutes, bengali: bengali);
    final raw = minutes == 0
        ? context.t('adjust_calc_only').replaceAll('%c', calc)
        : context
              .t('adjust_calc_mine')
              .replaceAll('%c', calc)
              .replaceAll('%m', mine);
    // each label stays with its time — a long line breaks only at the dot
    final line = raw
        .split(' · ')
        .map((part) => part.replaceAll(' ', ' '))
        .join(' · ');
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(
        SLSpacing.s16,
        SLSpacing.s8,
        SLSpacing.s4,
        SLSpacing.s8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  line,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: minutes == 0 ? cs.onSurfaceVariant : cs.primary,
                    fontWeight: minutes == 0 ? null : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: context.t('adjust_minus_a11y').replaceAll('%w', name),
            onPressed: minutes <= PrayerAdjust.min
                ? null
                : () => onChanged(minutes - 1),
            icon: const Icon(PhosphorIconsRegular.minusCircle),
          ),
          SizedBox(
            width: 40,
            child: Text(
              minutes == 0 ? (bengali ? '০' : '0') : _signed(minutes, bengali),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: minutes == 0 ? cs.onSurfaceVariant : cs.onSurface,
              ),
            ),
          ),
          IconButton(
            tooltip: context.t('adjust_plus_a11y').replaceAll('%w', name),
            onPressed: minutes >= PrayerAdjust.max
                ? null
                : () => onChanged(minutes + 1),
            icon: const Icon(PhosphorIconsRegular.plusCircle),
          ),
        ],
      ),
    );
  }
}
