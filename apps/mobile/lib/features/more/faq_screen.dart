/// জিজ্ঞাসা (FAQ) — expandable question list from the FAQ pack (shape
/// {items: [{q, a, group}]}; bn-first content — the questions/answers are
/// Bengali on purpose). The pack is admin-managed: ContentPack serves the
/// approved server copy (kept on the phone), the bundle until then.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/design_tokens.dart';
import '../../models/content_models.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class FaqEntry {
  const FaqEntry({required this.q, required this.a, this.group});
  final String q;
  final String a;

  /// salat | amal | dawah | ilm | app — the section it is listed under
  /// (missing → অন্যান্য).
  final String? group;

  factory FaqEntry.fromJson(Map<String, dynamic> j) => FaqEntry(
    q: j['q'] as String? ?? '',
    a: j['a'] as String? ?? '',
    group: j['group'] as String?,
  );
}

/// Asset loader — `rootBundle` in the app; tests inject `dart:io` reads
/// (the QuranRepository seam: rootBundle platform-channel responses cannot
/// complete inside a widget test's fake-async zone, so tests pre-warm the
/// pack under `tester.runAsync`). NOTE the cache design: the memo is the
/// decoded DATA, not the future — a future completed inside runAsync's
/// real-async zone never resolves fake-zone listeners (the quran repository
/// memoizes data for exactly this reason).
class FaqRepository {
  FaqRepository._();

  /// Tests only: read the asset directly (see the note above). Null in the
  /// app → the pack comes through [ContentPack] (server copy / phone / bundle).
  static Future<String> Function(String path)? _loadAsset;

  /// Completed cache — plain data, zone-free. Reopening the screen after a
  /// load resolves on the next microtask in whatever zone asks.
  static List<FaqEntry>? _cache;

  /// Single-flight for concurrent same-zone opens.
  static Future<List<FaqEntry>>? _loading;

  @visibleForTesting
  static set assetLoaderForTesting(
    Future<String> Function(String path) loader,
  ) {
    _loadAsset = loader;
    _cache = null;
    _loading = null;
  }

  @visibleForTesting
  static void resetForTesting() {
    _loadAsset = null;
    _cache = null;
    _loading = null;
  }

  static List<FaqEntry> _entriesOf(Object? decoded) =>
      decoded is Map<String, dynamic>
      ? ((decoded['items'] as List?) ?? const [])
            .whereType<Map>()
            .map((e) => FaqEntry.fromJson(e.cast<String, dynamic>()))
            .toList()
      : const <FaqEntry>[];

  static Future<List<FaqEntry>> entries() {
    final loader = _loadAsset;
    // the app: ContentPack keeps (and refreshes) the decoded pack itself
    if (loader == null) {
      return ContentPack.document('faq.json').then(_entriesOf);
    }
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= () async {
      try {
        final raw = await loader('assets/content/faq.json');
        final list = _entriesOf(jsonDecode(raw));
        _cache = list;
        _loading = null;
        return list;
      } catch (e) {
        debugPrint('faq.json load failed: $e');
        // A failed load must not poison future opens — drop the memo.
        _loading = null;
        rethrow;
      }
    }();
  }
}

class FaqScreen extends StatefulWidget {
  const FaqScreen({super.key});

  @override
  State<FaqScreen> createState() => _FaqScreenState();
}

class _FaqScreenState extends State<FaqScreen> {
  Future<List<FaqEntry>>? _future;

  @override
  void initState() {
    super.initState();
    _future = FaqRepository.entries();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('more_faq')),
      ),
      body: FutureBuilder<List<FaqEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Skeleton(height: 72, count: 6);
          }
          if (snapshot.hasError) {
            return ErrorState(
              message: '${snapshot.error}',
              onRetry: () => setState(() {
                // The failed memo was dropped inside the repository —
                // this call refetches from the asset.
                _future = FaqRepository.entries();
              }),
            );
          }
          final items = snapshot.data ?? const <FaqEntry>[];
          if (items.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: PhosphorIconsRegular.question,
            );
          }
          // grouped under section headers in the order they first appear
          // (16 identical rows in one run were hard to scan)
          final groups = <String, List<FaqEntry>>{};
          for (final e in items) {
            groups.putIfAbsent(e.group ?? 'other', () => []).add(e);
          }
          Widget entry(FaqEntry e) => Padding(
            padding: const EdgeInsets.only(bottom: SLSpacing.s8),
            child: AppCard(
              padding: EdgeInsets.zero,
              child: Theme(
                // No default divider — the card carries its own rhythm.
                data: theme.copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  initiallyExpanded: false,
                  tilePadding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                    vertical: SLSpacing.s4,
                  ),
                  childrenPadding: const EdgeInsets.fromLTRB(
                    SLSpacing.s16,
                    0,
                    SLSpacing.s16,
                    SLSpacing.s12,
                  ),
                  title: Text(
                    e.q,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  children: [
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        e.a,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              0,
              SLSpacing.s16,
              SLSpacing.s24,
            ),
            children: [
              for (final g in groups.entries) ...[
                SectionHeader(
                  context.t('faq_group_${g.key}') == 'faq_group_${g.key}'
                      ? context.t('faq_group_other')
                      : context.t('faq_group_${g.key}'),
                  icon: switch (g.key) {
                    'salat' => PhosphorIconsRegular.mosque,
                    'amal' => PhosphorIconsRegular.listChecks,
                    'dawah' => PhosphorIconsRegular.usersThree,
                    'ilm' => PhosphorIconsRegular.bookOpen,
                    'app' => PhosphorIconsRegular.deviceMobile,
                    _ => PhosphorIconsRegular.question,
                  },
                ),
                for (final e in g.value) entry(e),
              ],
              // nothing here answered it: the two ways to ask a person
              const SizedBox(height: SLSpacing.s16),
              AppCard(
                key: const ValueKey('faq_more_help'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('faq_more_title'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s4),
                    Text(
                      context.t('faq_more_body'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s12),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/more/masala'),
                            icon: const Icon(
                              PhosphorIconsRegular.chatCircle,
                              size: 18,
                            ),
                            label: Text(context.t('faq_ask_masala')),
                          ),
                        ),
                        const SizedBox(width: SLSpacing.s8),
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: () => context.push('/more/support'),
                            icon: const Icon(
                              PhosphorIconsRegular.headset,
                              size: 18,
                            ),
                            label: Text(context.t('faq_ask_support')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
