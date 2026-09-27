/// Amal widgets — the interactive diary controls: tristate chips, boolean
/// toggles, count steppers with quick-100, quantity inputs, heatmap cells,
/// streak badges, completion rings.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design/design_tokens.dart';
import '../../core/bn_digits.dart';
import '../../core/amal_engine.dart';
import '../../models/domain.dart';
import '../shared/widgets.dart';

/// জামাতে / একা / কাযা — the salat tristate chip row (44dp targets).
class TriStateChips extends StatelessWidget {
  const TriStateChips({
    super.key,
    required this.value,
    required this.onChanged,
    required this.labels,
    this.enabled = true,
  });
  final String? value; // jamaat | alone | qaza
  final ValueChanged<String?> onChanged;
  final TriStateLabels labels;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget chip(String key, String label, IconData icon, Color active) {
      final selected = value == key;
      return Expanded(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: Semantics(
            button: true,
            selected: selected,
            label: label,
            child: Material(
              color: selected
                  ? active
                  : theme.colorScheme.surfaceContainerHighest,
              borderRadius: SLRadius.brMd,
              child: InkWell(
                onTap: enabled
                    ? () {
                        HapticFeedback.selectionClick();
                        onChanged(selected ? null : key);
                      }
                    : null,
                borderRadius: SLRadius.brMd,
                child: SizedBox(
                  height: SLSpacing.minTapTarget,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: selected
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            maxLines: 1,
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
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(
          'jamaat',
          labels.jamaat,
          Icons.groups_outlined,
          theme.colorScheme.primary,
        ),
        chip(
          'alone',
          labels.alone,
          Icons.person_outline,
          theme.colorScheme.secondary,
        ),
        chip('qaza', labels.qaza, Icons.schedule, theme.colorScheme.error),
      ],
    );
  }
}

class TriStateLabels {
  const TriStateLabels({
    required this.jamaat,
    required this.alone,
    required this.qaza,
  });
  final String jamaat;
  final String alone;
  final String qaza;
}

/// Large boolean toggle (সুন্নাহ / অভ্যাস rows).
class AmalToggle extends StatelessWidget {
  const AmalToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.semanticsLabel,
  });
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  /// What this toggle controls (usually the amal title) — announced by
  /// screen readers instead of a bare "switch".
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      toggled: value,
      button: true,
      label: semanticsLabel,
      child: Switch(
        value: value,
        onChanged: enabled
            ? (v) {
                HapticFeedback.selectionClick();
                onChanged(v);
              }
            : null,
        activeThumbColor: theme.colorScheme.primary,
      ),
    );
  }
}

/// Count stepper with the quick-১০০ action (durood / istighfar).
class CountStepper extends StatelessWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.target,
    required this.onChanged,
    required this.unit,
    required this.quickCount,
    this.enabled = true,
    this.bengali = true,
  });
  final int value;
  final int target;
  final ValueChanged<int> onChanged;
  final String unit;
  final int quickCount;
  final bool enabled;
  final bool bengali;

  String _n(Object v) => bengali ? toBn(v) : '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = value >= target;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _step(
          context,
          Icons.remove,
          () => onChanged((value - 1).clamp(0, 1 << 30)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${_n(value)} ${reached ? '✔' : ''}',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: reached
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_n(target)} $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        _step(
          context,
          Icons.add,
          () => onChanged((value + 1).clamp(0, 1 << 30)),
        ),
        if (quickCount > 0) ...[
          const SizedBox(width: SLSpacing.s8),
          OutlinedButton(
            onPressed: enabled
                ? () {
                    HapticFeedback.mediumImpact();
                    onChanged(quickCount);
                  }
                : null,
            child: Text('${_n(quickCount)} ✔'),
          ),
        ],
      ],
    );
  }

  Widget _step(BuildContext context, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final increase = icon == Icons.add;
    return Semantics(
      button: true,
      label: increase
          ? context.t('increase')
          : context.t('decrease'),
      child: InkWell(
        onTap: enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: SLSpacing.minTapTarget,
          height: SLSpacing.minTapTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

/// Quantity input (tilawat: পৃষ্ঠা / পারা) with target context.
class QuantityInput extends StatefulWidget {
  const QuantityInput({
    super.key,
    required this.value,
    required this.target,
    required this.unit,
    required this.onChanged,
    this.enabled = true,
    this.bengali = true,
  });
  final double value;
  final double target;
  final String unit;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final bool bengali;

  @override
  State<QuantityInput> createState() => _QuantityInputState();
}

class _QuantityInputState extends State<QuantityInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.value == 0 ? '' : toBn(widget.value),
    );
  }

  @override
  void didUpdateWidget(covariant QuantityInput old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value &&
        toEnDigits(_controller.text) !=
            (widget.value == 0 ? '' : widget.value.toString())) {
      _controller.text = widget.value == 0 ? '' : toBn(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parsed = double.tryParse(toEnDigits(raw)) ?? 0;
    widget.onChanged(parsed.clamp(0, 999));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reached = widget.value >= widget.target;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          context,
          Icons.remove,
          () => widget.onChanged(math.max(0, widget.value - 0.5)),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: SLSpacing.s8),
          width: 84,
          child: TextField(
            enabled: widget.enabled,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textAlign: TextAlign.center,
            controller: _controller,
            style: theme.textTheme.titleMedium,
            onSubmitted: _commit,
            decoration: InputDecoration(
              suffixText: widget.unit,
              suffixStyle: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              isDense: true,
            ),
          ),
        ),
        _btn(context, Icons.add, () => widget.onChanged(widget.value + 0.5)),
        const SizedBox(width: SLSpacing.s4),
        if (reached)
          Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 20),
      ],
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final increase = icon == Icons.add;
    return Semantics(
      button: true,
      label: increase
          ? context.t('increase')
          : context.t('decrease'),
      child: InkWell(
        onTap: widget.enabled ? onTap : null,
        customBorder: const CircleBorder(),
        child: Container(
          width: SLSpacing.minTapTarget,
          height: SLSpacing.minTapTarget,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primaryContainer,
          ),
          child: Icon(icon, color: theme.colorScheme.primary),
        ),
      ),
    );
  }
}

String toEnDigits(String raw) => raw.replaceAllMapped(
  RegExp('[০-৯]'),
  (m) => '${'০১২৩৪৫৬৭৮৯'.indexOf(m.group(0)!)}',
);

/// One heatmap cell in the month grid (paper-diary layout).
class HeatmapCell extends StatelessWidget {
  const HeatmapCell({
    super.key,
    required this.points,
    this.onTap,
    this.isToday = false,
    this.locked = false,
    this.bengali = true,
    this.semanticsLabel,
  });
  final double points; // 0 | 0.5 | 1
  final VoidCallback? onTap;
  final bool isToday;
  final bool locked;
  final bool bengali;

  /// Screen-reader description (day + amal) — cells are 22px, well below the
  /// 44px target, so the semantics node carries the meaning instead.
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Color color;
    if (points >= 1) {
      color = theme.colorScheme.primary;
    } else if (points > 0) {
      color = theme.colorScheme.tertiary;
    } else {
      color = theme.colorScheme.surfaceContainerHighest;
    }
    return Semantics(
      button: onTap != null,
      label: semanticsLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 22,
          height: 22,
          margin: const EdgeInsets.all(1),
          decoration: BoxDecoration(
            color: color,
            borderRadius: SLRadius.brSm,
            border: isToday
                ? Border.all(color: theme.colorScheme.primary, width: 2)
                : null,
          ),
          child: locked
              ? Icon(
                  Icons.lock,
                  size: 12,
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
      ),
    );
  }
}

/// Streak badge — "৭ দিন 🔥".
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days, this.bengali = true});
  final int days;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (days <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SLSpacing.s8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiaryContainer,
        borderRadius: SLRadius.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_outlined,
            size: 16,
            color: SLColors.goldDeep,
          ),
          const SizedBox(width: 4),
          Text(
            '${bengali ? toBn(days) : '$days'} 🔥',
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Category completion ring (custom painter).
class CompletionRing extends StatelessWidget {
  const CompletionRing({
    super.key,
    required this.pct,
    required this.label,
    this.size = 56,
    this.bengali = true,
  });
  final int pct;
  final String label;
  final double size;
  final bool bengali;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: size + 24,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              painter: _RingPainter(
                pct: pct,
                color: theme.colorScheme.primary,
                track: theme.colorScheme.surfaceContainerHighest,
              ),
              child: Center(
                child: Text(
                  '${bengali ? toBn(pct) : '$pct'}%',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.pct, required this.color, required this.track});
  final int pct;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = 6.0;
    final inset = stroke / 2 + 1;
    final r = Rect.fromLTWH(
      inset,
      inset,
      size.width - 2 * inset,
      size.height - 2 * inset,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    final fill = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(r, 0, math.pi * 2, false, base);
    canvas.drawArc(r, -math.pi / 2, math.pi * 2 * (pct / 100.0), false, fill);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.pct != pct || old.color != color || old.track != track;
}

/// Compute display points for one cell (used by grids + tests).
double cellPoints(Object? value, AmalDefinition def, UserCategory category) =>
    amalPoints(value, def, category);
