/// জিজ্ঞাসা (FAQ) — expandable question list from the bundled asset
/// (assets/content/faq.json, shape {items: [{q, a}]}; bn-first content —
/// the questions/answers are Bengali on purpose).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../design/design_tokens.dart';
import '../shared/widgets.dart';

class FaqEntry {
  const FaqEntry({required this.q, required this.a});
  final String q;
  final String a;

  factory FaqEntry.fromJson(Map<String, dynamic> j) =>
      FaqEntry(q: j['q'] as String? ?? '', a: j['a'] as String? ?? '');
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

  static Future<String> Function(String path) _loadAsset =
      rootBundle.loadString;

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
    _loadAsset = rootBundle.loadString;
    _cache = null;
    _loading = null;
  }

  static Future<List<FaqEntry>> entries() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _loading ??= () async {
      try {
        final raw = await _loadAsset('assets/content/faq.json');
        final decoded = jsonDecode(raw);
        final list = decoded is Map<String, dynamic>
            ? ((decoded['items'] as List?) ?? const [])
                  .whereType<Map>()
                  .map((e) => FaqEntry.fromJson(e.cast<String, dynamic>()))
                  .toList()
            : const <FaqEntry>[];
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
              icon: Icons.help_outline,
            );
          }
          return ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              for (final e in items)
                Padding(
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
                              style: theme.textTheme.bodySmall?.copyWith(
                                height: 1.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
