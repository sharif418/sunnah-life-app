/// আল্লাহর ৯৯ নাম — list with meanings.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../services/platform_channels.dart' show SystemChannel;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class Names99Screen extends StatefulWidget {
  const Names99Screen({super.key, this.highlightId});

  /// From a search result (`?id=`): that item is shown first, framed.
  final String? highlightId;

  @override
  State<Names99Screen> createState() => _Names99ScreenState();
}

class _Names99ScreenState extends State<Names99Screen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<NameOfAllah>> _future = ContentPack.names99();
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_names99')),
      ),
      body: FutureBuilder<List<NameOfAllah>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 8);
          }
          var names = snap.data ?? const <NameOfAllah>[];
          if (names.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.sun,
            );
          }
          // a search result's item first (only while not searching here)
          final hl = widget.highlightId;
          if (hl != null && _query.trim().isEmpty) {
            final hit = names.where((x) => '${x.id}' == hl).firstOrNull;
            if (hit != null) {
              names = [hit, ...names.where((x) => !identical(x, hit))];
            }
          }
          final q = _query.trim();
          if (q.isNotEmpty) {
            names = names
                .where(
                  (n) =>
                      n.translitBn.contains(q) ||
                      n.meaningBn.contains(q) ||
                      n.arabic.contains(q),
                )
                .toList();
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SLSpacing.s16,
                  vertical: SLSpacing.s8,
                ),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: context.t('search'),
                    prefixIcon: const Icon(
                      PhosphorIconsRegular.magnifyingGlass,
                    ),
                    isDense: true,
                  ),
                ),
              ),
              Expanded(
                child: names.isEmpty
                    ? EmptyState(
                        message: context.t('empty_generic'),
                        icon: PhosphorIconsRegular.magnifyingGlass,
                      )
                    : ListView.separated(
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: names.length,
                        itemBuilder: (context, i) {
                          final n = names[i];
                          // number chip · the name and its meaning · the
                          // Arabic large on the right, where the eye reads it
                          final card = AppCard(
                            onTap: () =>
                                showNameOfAllahSheet(context, names, i),
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s12,
                              vertical: SLSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 34,
                                  height: 34,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primaryContainer,
                                    shape: BoxShape.circle,
                                  ),
                                  child: FittedBox(
                                    child: Padding(
                                      padding: const EdgeInsets.all(4),
                                      child: Text(
                                        bn ? toBn(n.id) : '${n.id}',
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                              color: theme.colorScheme.primary,
                                            ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: SLSpacing.s12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.translitBn,
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(
                                              fontWeight: FontWeight.w700,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.meaningBn,
                                        style: theme.textTheme.bodySmall
                                            ?.copyWith(
                                              color: theme
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: SLSpacing.s12),
                                ConstrainedBox(
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.sizeOf(context).width * 0.38,
                                  ),
                                  child: Text(
                                    n.arabic,
                                    style: SLType.dua(
                                      color: theme.colorScheme.primary,
                                    ).copyWith(fontSize: 26, height: 1.6),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ],
                            ),
                          );
                          return SearchHitFrame(
                            hit: i == 0 && widget.highlightId == '${n.id}',
                            child: card,
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

/// One name large — Arabic, reading, meaning, virtue — swiping to the
/// next and previous (the rows used to do nothing when tapped).
Future<void> showNameOfAllahSheet(
  BuildContext context,
  List<NameOfAllah> names,
  int index,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _NameSheet(names: names, index: index),
);

class _NameSheet extends StatefulWidget {
  const _NameSheet({required this.names, required this.index});
  final List<NameOfAllah> names;
  final int index;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final PageController _pages = PageController(initialPage: widget.index);
  late int _at = widget.index;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  String _text(NameOfAllah n) => [
    n.arabic,
    n.translitBn,
    n.meaningBn,
    if ((n.virtue ?? '').isNotEmpty) n.virtue!,
  ].join('\n');

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    final total = widget.names.length;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                key: const ValueKey('name99_pages'),
                controller: _pages,
                itemCount: total,
                onPageChanged: (i) => setState(() => _at = i),
                itemBuilder: (context, i) {
                  final n = widget.names[i];
                  return SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SLSpacing.s24,
                    ),
                    child: Column(
                      children: [
                        Text(
                          bn ? toBn(n.id) : '${n.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: SLSpacing.s8),
                        Text(
                          n.arabic,
                          textDirection: TextDirection.rtl,
                          style: SLType.dua(color: cs.primary)
                              .copyWith(fontSize: 44, height: 1.6),
                        ),
                        Text(
                          n.translitBn,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: SLSpacing.s8),
                        Text(
                          n.meaningBn,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.6,
                          ),
                        ),
                        if ((n.virtue ?? '').isNotEmpty) ...[
                          const SizedBox(height: SLSpacing.s12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(SLSpacing.s12),
                            decoration: BoxDecoration(
                              color: cs.primaryContainer,
                              borderRadius: SLRadius.brMd,
                            ),
                            child: Text(
                              n.virtue!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SLSpacing.s8,
                0,
                SLSpacing.s8,
                SLSpacing.s8,
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.t('name_prev'),
                    onPressed: _at > 0
                        ? () => _pages.previousPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          )
                        : null,
                    icon: const DirectionalIcon(PhosphorIconsRegular.caretLeft),
                  ),
                  Expanded(
                    child: Text(
                      '${bn ? toBn(_at + 1) : _at + 1} / ${bn ? toBn(total) : total}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('copy'),
                    onPressed: () async {
                      await Clipboard.setData(
                        ClipboardData(text: _text(widget.names[_at])),
                      );
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(context.t('copied'))),
                        );
                      }
                    },
                    icon: const Icon(PhosphorIconsRegular.copy),
                  ),
                  IconButton(
                    tooltip: context.t('share'),
                    onPressed: () =>
                        SystemChannel.shareText(_text(widget.names[_at])),
                    icon: const Icon(PhosphorIconsRegular.shareNetwork),
                  ),
                  IconButton(
                    key: const ValueKey('name99_next'),
                    tooltip: context.t('name_next'),
                    onPressed: _at < total - 1
                        ? () => _pages.nextPage(
                            duration: const Duration(milliseconds: 240),
                            curve: Curves.easeOutCubic,
                          )
                        : null,
                    icon: const DirectionalIcon(
                      PhosphorIconsRegular.caretRight,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
