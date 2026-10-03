/// Amal widgets — the interactive diary controls: tristate chips, boolean
/// toggles, count steppers with quick-100, quantity inputs, heatmap cells,
/// streak badges, completion rings.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design/design_tokens.dart';
import '../../core/bn_digits.dart';
import '../../core/amal_engine.dart';
import '../../models/domain.dart';
import '../../state/remote_state.dart' show leaderboardMeProvider;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

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
    // Selected fills form a ladder: জামাতে green, একা gold, কাযা red — each
    // with its own readable on-color (the old একা fill was `secondary` cream
    // under `onPrimary` cream text, 1.1:1).
    Widget chip(
      String key,
      String label,
      IconData icon,
      Color active,
      Color onActive,
    ) {
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
                                ? onActive
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            maxLines: 1,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? onActive
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
          PhosphorIconsRegular.usersThree,
          theme.colorScheme.primary,
          theme.colorScheme.onPrimary,
        ),
        chip(
          'alone',
          labels.alone,
          PhosphorIconsRegular.user,
          theme.colorScheme.tertiary,
          theme.colorScheme.onTertiary,
        ),
        chip(
          'qaza',
          labels.qaza,
          PhosphorIconsRegular.clock,
          theme.colorScheme.error,
          theme.colorScheme.onError,
        ),
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

/// Count stepper with the quick-১০০ action (durood / istighfar) — a
/// compact trailing cluster for the one-line diary rows: [−] value [+]
/// with the target under the value and the quick button at the end.
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
          PhosphorIconsRegular.minus,
          () => onChanged((value - 1).clamp(0, 1 << 30)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _n(value),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: reached
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reached) ...[
                    const SizedBox(width: 2),
                    Icon(
                      PhosphorIconsFill.checkCircle,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
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
          PhosphorIconsRegular.plus,
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
            child: Text(_n(quickCount)),
          ),
        ],
      ],
    );
  }

  Widget _step(BuildContext context, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final increase = icon == PhosphorIconsRegular.plus;
    return Semantics(
      button: true,
      label: increase ? context.t('increase') : context.t('decrease'),
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

/// Quantity input (tilawat পৃষ্ঠা/পারা, minutes) — a compact, NORMAL-height
/// numeric field that always shows the current value with the unit inline,
/// between − / + steppers. The value is editable directly (tap → keyboard);
/// steppers nudge by a half unit (0.5).
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
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _fmt(widget.value));
    _focus = FocusNode();
    // Commit on blur as well as on submit — a stray keyboard dismissal
    // must not swallow a typed number.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commit(_controller.text);
    });
  }

  /// 1.0 renders as ১ (not ১.০); halves keep their fraction (০.৫).
  String _fmt(double v) {
    final s = v == v.truncateToDouble() ? v.toInt().toString() : v.toString();
    return widget.bengali ? toBn(s) : s;
  }

  @override
  void didUpdateWidget(covariant QuantityInput old) {
    super.didUpdateWidget(old);
    // Steppers wrote a new value (or a sync landed): refresh the field
    // unless the user is mid-edit (focus) with the same digits typed.
    final typed = double.tryParse(toEnDigits(_controller.text)) ?? 0;
    if (!_focus.hasFocus && typed != widget.value) {
      _controller.text = _fmt(widget.value);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _commit(String raw) {
    final parsed = double.tryParse(toEnDigits(raw)) ?? 0;
    final clamped = parsed.clamp(0.0, 999.0);
    if (clamped != widget.value) widget.onChanged(clamped);
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
          PhosphorIconsRegular.minus,
          () => widget.onChanged(math.max(0, widget.value - 0.5)),
        ),
        const SizedBox(width: SLSpacing.s8),
        // The compact field: fixed normal height, value + unit inline.
        GestureDetector(
          onTap: widget.enabled ? _focus.requestFocus : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s8),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: SLRadius.brMd,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 40,
                  child: TextField(
                    enabled: widget.enabled,
                    focusNode: _focus,
                    controller: _controller,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    onSubmitted: (raw) {
                      _commit(raw);
                      _focus.unfocus();
                    },
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    widget.unit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (reached) ...[
                  const SizedBox(width: 4),
                  Icon(
                    PhosphorIconsFill.checkCircle,
                    color: theme.colorScheme.primary,
                    size: 16,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(width: SLSpacing.s8),
        _btn(
          context,
          PhosphorIconsRegular.plus,
          () => widget.onChanged(widget.value + 0.5),
        ),
      ],
    );
  }

  Widget _btn(BuildContext context, IconData icon, VoidCallback onTap) {
    final theme = Theme.of(context);
    final increase = icon == PhosphorIconsRegular.plus;
    return Semantics(
      button: true,
      label: increase ? context.t('increase') : context.t('decrease'),
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

/// The SHORT inline unit for a quantity/count amal row — the catalog's unit
/// carries the full teaching note ("পৃষ্ঠা/পারা — হাফেজ: ১ পারা …"), which is
/// right for the diary hint but must not be stuffed into a compact control.
/// হাফেজ counts পারা; everyone else পৃষ্ঠা; beginners use the
/// tilawat-minutes ramp (মিনিট) — the unit switch stays the ramp card.
String displayUnitFor(AmalDefinition def, UserCategory category) {
  final raw = def.unit ?? '';
  if (raw.isEmpty) return '';
  if (raw.contains('পৃষ্ঠা/পারা')) {
    return category == UserCategory.hafez ? 'পারা' : 'পৃষ্ঠা';
  }
  final head = raw.split('—').first.trim();
  return head.isEmpty ? raw : head;
}

/// W4c tilawat beginner card — shown for the tilawat_minutes amal while
/// the user has <7 days of tilawat-minutes history (computed locally):
/// a শুরু chip, the "আজ ৫ মিনিট দিয়ে শুরু করুন" ramp copy, the day-n/৭
/// ramp chip, a +৫ মিনিট quick-log and the full QuantityInput for precise
/// entry. After day 7 the row reverts to the normal quantity amal.
class TilawatBeginnerCard extends StatelessWidget {
  const TilawatBeginnerCard({
    super.key,
    required this.title,
    required this.value,
    required this.target,
    required this.unit,
    required this.daysDone,
    required this.bengali,
    required this.onChanged,
    this.enabled = true,
  });

  /// Amal title (bn first — the diary convention).
  final String title;

  /// Today's logged minutes (0 when untouched).
  final double value;

  /// The amal target in minutes (catalog: 10).
  final double target;

  /// The amal unit label (মিনিট).
  final String unit;

  /// Completed ramp days (0–6 while the card is visible).
  final int daysDone;

  final bool bengali;
  final ValueChanged<double> onChanged;
  final bool enabled;

  static const int rampDays = 7;

  String _n(Object v) => bengali ? toBn(v) : '$v';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final day = (daysDone + 1).clamp(1, rampDays);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: SLColors.gold.withValues(alpha: 0.18),
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  context.t('tilawat_begin_chip'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? SLColors.darkGoldText
                        : SLColors.lightGoldText,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                key: const ValueKey('tilawat_ramp_chip'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer,
                  borderRadius: SLRadius.brPill,
                ),
                child: Text(
                  '${context.t('tilawat_ramp_day')} ${_n(day)}/${_n(rampDays)}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s4),
          Text(
            context.t('tilawat_begin_copy'),
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: SLSpacing.s8),
          Row(
            children: [
              FilledButton.icon(
                key: const ValueKey('tilawat_begin_add5'),
                onPressed: enabled
                    ? () {
                        HapticFeedback.mediumImpact();
                        onChanged((value + 5).clamp(0, 999));
                      }
                    : null,
                icon: const Icon(PhosphorIconsRegular.plus, size: 18),
                label: Text('+${_n(5)} ${context.t('tilawat_begin_minutes')}'),
              ),
              const SizedBox(width: SLSpacing.s8),
              Expanded(
                child: Text(
                  '${_n(value)} $unit',
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: value > 0
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SLSpacing.s8),
          SizedBox(
            width: double.infinity,
            child: QuantityInput(
              value: value,
              target: target,
              unit: unit,
              enabled: enabled,
              bengali: bengali,
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}

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
                  PhosphorIconsRegular.lockSimple,
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
            PhosphorIconsFill.fire,
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

/// W4c leaderboard band card — the member's gender-scoped percentile band
/// (config-gated). Consumes leaderboardMeProvider: while the flag is off,
/// the user is a guest, the server 404s (flag off) or the network fails,
/// the provider is null and this renders NOTHING (never an error wall).
class LeaderboardBandCard extends ConsumerWidget {
  const LeaderboardBandCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return ref
        .watch(leaderboardMeProvider)
        .when(
          data: (me) {
            if (me == null) return const SizedBox.shrink();
            // Band label colors double as TEXT colors on a 15% tint of
            // themselves, so each must be an ink (≥ 4.5:1 on the card) —
            // the old tertiary gold / secondary cream bands were 2.6:1 and
            // ~1.1:1.
            final dark = theme.brightness == Brightness.dark;
            final color = switch (me.band) {
              LeaderboardBand.top10 =>
                dark ? SLColors.darkGoldText : SLColors.lightGoldText,
              LeaderboardBand.top25 => theme.colorScheme.primary,
              LeaderboardBand.top50 =>
                dark ? SLColors.darkSuccess : SLColors.lightSuccess,
              LeaderboardBand.top75 => theme.colorScheme.onSurfaceVariant,
              LeaderboardBand.bottom => theme.colorScheme.onSurfaceVariant,
            };
            return Padding(
              padding: const EdgeInsets.only(top: SLSpacing.s8),
              child: AppCard(
                key: const ValueKey('leaderboard_band_card'),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIconsRegular.chartBar,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: SLSpacing.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('leaderboard_title'),
                            style: theme.textTheme.bodySmall,
                          ),
                          Text(
                            '${context.t('leaderboard_points')}: ${bn ? toBn(me.myPointsDisplay) : me.myPointsDisplay} · '
                            '${bn ? toBn(me.windowDays) : me.windowDays} ${context.t('leaderboard_window_days')}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      key: ValueKey('leaderboard_band_chip_${me.band.json}'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: SLRadius.brPill,
                      ),
                      child: Text(
                        context.t(me.band.labelKey),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
        );
  }
}
