/// ইসলামিক নাম — baby-name lists with the boy/girl filter.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../../core/bn_digits.dart';
import '../../services/platform_channels.dart' show SystemChannel;
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class IslamicNamesScreen extends StatefulWidget {
  const IslamicNamesScreen({super.key, this.highlightId});

  /// From a search result (`?id=`): that name is shown first, framed, on
  /// its own gender's tab.
  final String? highlightId;

  @override
  State<IslamicNamesScreen> createState() => _IslamicNamesScreenState();
}

class _IslamicNamesScreenState extends State<IslamicNamesScreen> {
  // Loaded ONCE: a FutureBuilder handed a fresh ContentPack future in
  // build() fell back to the skeleton on every setState — each tap or
  // keystroke rebuilt the list (scroll jumped to the top, the search
  // field lost its text and the keyboard).
  late final Future<List<IslamicName>> _future = ContentPack.islamicNames();
  bool _girls = false;
  String _query = '';
  bool _highlightApplied = false;

  /// The parents' shortlist (name ids), kept on the phone.
  Set<String> _shortlist = <String>{};
  bool _onlyShortlist = false;
  static const _shortlistKey = 'islamic_name_shortlist';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance()
        .then((p) {
          final l = p.getStringList(_shortlistKey) ?? const <String>[];
          if (mounted) setState(() => _shortlist = l.toSet());
        })
        .catchError((_) {});
  }

  Future<void> _toggleShortlist(IslamicName n) async {
    final id = '${n.id}';
    setState(() {
      _shortlist = {..._shortlist};
      if (!_shortlist.remove(id)) _shortlist.add(id);
    });
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(_shortlistKey, _shortlist.toList());
    } catch (_) {}
  }

  void _showName(IslamicName n) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = '${n.name} — ${n.meaningBn}';
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final kept = _shortlist.contains('${n.id}');
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SLSpacing.s24,
                0,
                SLSpacing.s24,
                SLSpacing.s16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    n.gender == 'girl'
                        ? PhosphorIconsRegular.genderFemale
                        : PhosphorIconsRegular.genderMale,
                    color: cs.primary,
                  ),
                  Text(
                    n.name,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: SLSpacing.s8),
                  Text(
                    n.meaningBn,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
                  ),
                  if ((n.genderNote ?? '').isNotEmpty) ...[
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      n.genderNote!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: SLSpacing.s16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          key: const ValueKey('name_shortlist_toggle'),
                          onPressed: () async {
                            await _toggleShortlist(n);
                            setSheet(() {});
                          },
                          icon: Icon(
                            kept
                                ? PhosphorIconsFill.heart
                                : PhosphorIconsRegular.heart,
                          ),
                          label: Text(
                            context.t(
                              kept
                                  ? 'names_shortlisted'
                                  : 'names_shortlist_add',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: SLSpacing.s8),
                      IconButton.filledTonal(
                        tooltip: context.t('copy'),
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: text));
                          if (sheetContext.mounted) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(content: Text(sheetContext.t('copied'))),
                            );
                          }
                        },
                        icon: const Icon(PhosphorIconsRegular.copy),
                      ),
                      IconButton.filledTonal(
                        tooltip: context.t('share'),
                        onPressed: () => SystemChannel.shareText(text),
                        icon: const Icon(PhosphorIconsRegular.shareNetwork),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('ilm_baby_names')),
      ),
      body: FutureBuilder<List<IslamicName>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 8);
          }
          final names = snap.data ?? const <IslamicName>[];
          if (names.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.baby,
            );
          }
          final hl = widget.highlightId;
          final hit = hl == null
              ? null
              : names.where((n) => '${n.id}' == hl).firstOrNull;
          if (hit != null && !_highlightApplied) {
            // open on the found name's own tab
            _highlightApplied = true;
            _girls = hit.gender == 'girl';
          }
          final q = _query.trim();
          // searching looks through BOTH lists (a girl's name typed on the
          // boys' tab used to answer "nothing here")
          var visible = q.isEmpty && !_onlyShortlist
              ? names
                    .where((n) => n.gender == (_girls ? 'girl' : 'boy'))
                    .toList()
              : names
                    .where(
                      (n) =>
                          q.isEmpty ||
                          n.name.contains(q) ||
                          n.meaningBn.contains(q),
                    )
                    .toList();
          if (_onlyShortlist) {
            visible = visible
                .where((n) => _shortlist.contains('${n.id}'))
                .toList();
          }
          if (hit != null && q.isEmpty && visible.contains(hit)) {
            visible = [hit, ...visible.where((x) => !identical(x, hit))];
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
                child: Wrap(
                  spacing: SLSpacing.s8,
                  runSpacing: SLSpacing.s4,
                  children: [
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: const Icon(
                        PhosphorIconsRegular.genderMale,
                        size: 16,
                      ),
                      label: Text(context.t('names_boy')),
                      selected: !_girls && !_onlyShortlist,
                      onSelected: (_) => setState(() {
                        _girls = false;
                        _onlyShortlist = false;
                      }),
                    ),
                    ChoiceChip(
                      showCheckmark: false,
                      avatar: const Icon(
                        PhosphorIconsRegular.genderFemale,
                        size: 16,
                      ),
                      label: Text(context.t('names_girl')),
                      selected: _girls && !_onlyShortlist,
                      onSelected: (_) => setState(() {
                        _girls = true;
                        _onlyShortlist = false;
                      }),
                    ),
                    ChoiceChip(
                      showCheckmark: false,
                      key: const ValueKey('names_shortlist_filter'),
                      avatar: const Icon(PhosphorIconsFill.heart, size: 16),
                      label: Text(
                        '${context.t('names_shortlist')} (${context.isBn ? toBn(_shortlist.length) : _shortlist.length})',
                      ),
                      selected: _onlyShortlist,
                      onSelected: (_) =>
                          setState(() => _onlyShortlist = !_onlyShortlist),
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
                        padding: const EdgeInsets.all(SLSpacing.s16),
                        itemCount: visible.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: SLSpacing.s8),
                        itemBuilder: (context, i) {
                          final n = visible[i];
                          // the list position meant nothing and, at large
                          // text, ran into the meaning — name + meaning only
                          final card = AppCard(
                            onTap: () => _showName(n),
                            padding: const EdgeInsets.symmetric(
                              horizontal: SLSpacing.s16,
                              vertical: SLSpacing.s12,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        n.name,
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
                                if (_shortlist.contains('${n.id}'))
                                  Icon(
                                    PhosphorIconsFill.heart,
                                    color: theme.colorScheme.error,
                                    size: 20,
                                  ),
                              ],
                            ),
                          );
                          return SearchHitFrame(
                            hit: i == 0 && hit != null && identical(n, hit),
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
