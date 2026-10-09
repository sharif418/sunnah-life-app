/// সুন্নাহ ও বিস্মৃত সুন্নাহ — category-filtered list with references.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../core/date_keys.dart';
import '../../core/bn_digits.dart';
import '../../services/platform_channels.dart' show SystemChannel;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class SunnahsScreen extends StatefulWidget {
  const SunnahsScreen({super.key});

  @override
  State<SunnahsScreen> createState() => _SunnahsScreenState();
}

class _SunnahsScreenState extends State<SunnahsScreen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<SunnahItem>> _future = ContentPack.sunnahs();
  String _category = 'all';

  /// Sunnahs the member marked as practised today (cleared at midnight) —
  /// the list was read-only: nothing to DO with a sunnah once read.
  Set<String> _doneToday = <String>{};
  static const _doneKey = 'sunnah_done_v1';

  @override
  void initState() {
    super.initState();
    _loadDone();
  }

  Future<void> _loadDone() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_doneKey);
      if (raw == null) return;
      final j = jsonDecode(raw);
      if (j is! Map || j['day'] != dateKey(DateTime.now())) return;
      final ids = (j['ids'] as List? ?? const []).whereType<String>();
      if (mounted) setState(() => _doneToday = ids.toSet());
    } catch (_) {}
  }

  Future<void> _toggleDone(String id) async {
    HapticFeedback.selectionClick();
    setState(() {
      _doneToday = {..._doneToday};
      if (!_doneToday.remove(id)) _doneToday.add(id);
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(
        _doneKey,
        jsonEncode({
          'day': dateKey(DateTime.now()),
          'ids': _doneToday.toList(),
        }),
      );
    } catch (_) {}
  }

  static const _cats = <String, (String, IconData)>{
    'all': ('sunnah_cat_all', PhosphorIconsRegular.infinity),
    'daily': ('sunnah_cat_daily', PhosphorIconsRegular.sun),
    'forgotten': ('sunnah_cat_forgotten', PhosphorIconsRegular.sunHorizon),
    'salah': ('sunnah_cat_salah', PhosphorIconsRegular.mosque),
  };

  /// "আজ Nটি সুন্নাহ পালন করেছেন" — or how to use the ticks.
  Widget _todayStrip(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final n = _doneToday.length;
    return Container(
      key: const ValueKey('sunnah_today_strip'),
      padding: const EdgeInsets.all(SLSpacing.s12),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: SLRadius.brMd,
      ),
      child: Row(
        children: [
          Icon(
            n > 0
                ? PhosphorIconsFill.checkCircle
                : PhosphorIconsRegular.sparkle,
            color: cs.primary,
          ),
          const SizedBox(width: SLSpacing.s8),
          Expanded(
            child: Text(
              n > 0
                  ? context
                        .t('sunnah_today_count')
                        .replaceAll('%n', context.isBn ? toBn(n) : '$n')
                  : context.t('sunnah_today_hint'),
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: n > 0 ? FontWeight.w700 : FontWeight.w400,
                color: n > 0 ? cs.primary : cs.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_sunnahs')),
      ),
      body: FutureBuilder<List<SunnahItem>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 6);
          }
          final items = snap.data ?? const <SunnahItem>[];
          if (items.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.sunHorizon,
            );
          }
          final visible = _category == 'all'
              ? items
              : items.where((s) => s.category == _category).toList();
          return Column(
            children: [
              SizedBox(
                height: MediaQuery.textScalerOf(context).scale(48),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                  ),
                  children: [
                    for (final c in _cats.keys)
                      Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        // the chip's fill says which is chosen — a check
                        // mark was drawn on top of the icon
                        child: FilterChip(
                          showCheckmark: false,
                          avatar: Icon(
                            _cats[c]!.$2,
                            size: 16,
                            color: theme.colorScheme.primary,
                          ),
                          label: Text(context.t(_cats[c]!.$1)),
                          selected: _category == c,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: visible.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: PhosphorIconsRegular.magnifyingGlass,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length + 1,
                        itemBuilder: (context, i) {
                          if (i == 0) return _todayStrip(context);
                          final s = visible[i - 1];
                          final done = _doneToday.contains(s.id);
                          return AppCard(
                            key: ValueKey('sunnah_${s.id}'),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        s.titleBn,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                    ),
                                    // which kind, in words (a lone icon
                                    // here looked like a button)
                                    if (_cats[s.category] != null &&
                                        _category == 'all') ...[
                                      const SizedBox(width: SLSpacing.s8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: SLSpacing.s8,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: theme
                                              .colorScheme
                                              .primaryContainer,
                                          borderRadius: SLRadius.brPill,
                                        ),
                                        child: Text(
                                          context.t(_cats[s.category]!.$1),
                                          style: theme.textTheme.bodySmall
                                              ?.copyWith(
                                                color:
                                                    theme.colorScheme.primary,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: SLSpacing.s4),
                                Text(
                                  s.detailBn,
                                  style: theme.textTheme.bodyMedium,
                                ),
                                if (s.reference?.isNotEmpty ?? false)
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: SLSpacing.s4,
                                    ),
                                    child: Text(
                                      '— ${s.reference}',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.primary,
                                          ),
                                    ),
                                  ),
                                const SizedBox(height: SLSpacing.s8),
                                // the card's one action: a clear green
                                // button (the grey chip read as disabled),
                                // filled once done — tap again to undo
                                Row(
                                  children: [
                                    _DoneButton(
                                      key: ValueKey('sunnah_done_${s.id}'),
                                      done: done,
                                      label: context.t(
                                        done
                                            ? 'sunnah_done_today'
                                            : 'sunnah_mark_done',
                                      ),
                                      onPressed: () => _toggleDone(s.id),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: context.t('share'),
                                      onPressed: () => SystemChannel.shareText(
                                        [
                                          s.titleBn,
                                          s.detailBn,
                                          if (s.reference?.isNotEmpty ?? false)
                                            '— ${s.reference}',
                                        ].join('\n\n'),
                                      ),
                                      icon: const Icon(
                                        PhosphorIconsRegular.shareNetwork,
                                        size: 20,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DoneButton extends StatelessWidget {
  const _DoneButton({
    super.key,
    required this.done,
    required this.label,
    required this.onPressed,
  });
  final bool done;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = Text(
      label,
      style: theme.textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: done ? cs.onPrimaryContainer : cs.primary,
      ),
    );
    const size = Size(0, SLSpacing.minTapTarget);
    return done
        ? FilledButton.tonalIcon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(minimumSize: size),
            icon: Icon(
              PhosphorIconsFill.checkCircle,
              size: 18,
              color: cs.primary,
            ),
            label: text,
          )
        : OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              minimumSize: size,
              side: BorderSide(color: cs.primary),
            ),
            icon: Icon(
              PhosphorIconsRegular.checkCircle,
              size: 18,
              color: cs.primary,
            ),
            label: text,
          );
  }
}
