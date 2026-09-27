/// কুরআন পাঠক — surah list → Uthmani reader with Bengali translation
/// toggle, ayah bookmarks, last-read resume, and tilawat auto-log
/// (session minutes → diary quantity entry, source auto:quran:tilawat).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../models/quran_models.dart';
import '../../state/providers.dart';
import '../shared/widgets.dart';
import 'quran_tilawat_sheet.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  String _query = '';
  (int, int)? _lastRead;

  @override
  void initState() {
    super.initState();
    _loadLastRead();
  }

  Future<void> _loadLastRead() async {
    final row = await ref.read(dbProvider).lastReadEntry();
    if (row != null && mounted) {
      setState(() => _lastRead = (row.surah, row.ayah));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text(context.t('quran_reader')),
      ),
      body: FutureBuilder<List<SurahMeta>>(
        future: QuranRepository.surahList(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Skeleton(height: 64, count: 8);
          }
          final surahs = snap.data ?? const <SurahMeta>[];
          if (surahs.isEmpty) {
            return EmptyState(
              message: context.t('empty_generic'),
              icon: Icons.menu_book_outlined,
            );
          }
          final q = _query.trim();
          final filtered = q.isEmpty
              ? surahs
              : surahs
                    .where(
                      (s) =>
                          s.nameBn.contains(q) ||
                          s.englishName.toLowerCase().contains(
                            q.toLowerCase(),
                          ) ||
                          '${s.number}' == q,
                    )
                    .toList();
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
                    hintText:
                        '${context.t('search')} — ${context.t('quran_surahs')}',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                  ),
                ),
              ),
              if (_lastRead != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                    vertical: SLSpacing.s4,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: ActionChip(
                          avatar: const Icon(Icons.bookmark, size: 18),
                          label: Text(context.t('quran_resume')),
                          onPressed: () => _openSurah(_lastRead!.$1),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s16,
                    vertical: SLSpacing.s4,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final s = filtered[i];
                    return AppCard(
                      onTap: () => _openSurah(s.number),
                      padding: const EdgeInsets.symmetric(
                        horizontal: SLSpacing.s12,
                        vertical: SLSpacing.s8,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: SLRadius.brMd,
                            ),
                            child: Text(
                              bn ? toBn(s.number) : '${s.number}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: SLSpacing.s12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.nameBn,
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${s.englishName} · ${bn ? toBn(s.ayahCount) : s.ayahCount} ${context.t('quran_ayahs')}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            s.name,
                            style: SLType.dua(color: theme.colorScheme.primary),
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

  void _openSurah(int n) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _SurahReaderScreen(
          surahNumber: n,
          lastReadAyah: _lastRead?.$1 == n ? _lastRead!.$2 : null,
        ),
      ),
    );
  }
}

class _SurahReaderScreen extends ConsumerStatefulWidget {
  const _SurahReaderScreen({required this.surahNumber, this.lastReadAyah});
  final int surahNumber;
  final int? lastReadAyah;

  @override
  ConsumerState<_SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<_SurahReaderScreen> {
  bool _showTranslation = true;
  DateTime _sessionStart = DateTime.now();
  Set<(int, int)> _bookmarks = <(int, int)>{};

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _loadBookmarks();
  }

  Future<void> _loadBookmarks() async {
    final marks = await ref.read(dbProvider).bookmarks();
    if (mounted) setState(() => _bookmarks = marks);
  }

  Future<void> _toggleBookmark(int ayah) async {
    final key = (widget.surahNumber, ayah);
    final add = !_bookmarks.contains(key);
    await ref.read(dbProvider).toggleBookmark(widget.surahNumber, ayah, add);
    await _loadBookmarks();
  }

  Future<bool> _confirmExit() async {
    final minutes = DateTime.now()
        .difference(_sessionStart)
        .inMinutes
        .clamp(0, 180);
    if (minutes >= 1 && mounted) {
      await showTilawatSheet(
        context,
        ref,
        minutes: minutes,
        onLogged: _resetSession,
      );
    }
    return true;
  }

  void _resetSession() {
    _sessionStart = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final can = await _confirmExit();
        if (can && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: FutureBuilder<Surah>(
            future: QuranRepository.surah(widget.surahNumber),
            builder: (context, snap) => Text(
              snap.data?.meta.nameBn ?? context.t('quran_reader'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          actions: [
            Semantics(
              toggled: _showTranslation,
              label: context.t('quran_translation_toggle'),
              child: IconButton(
                tooltip: context.t('quran_translation_toggle'),
                isSelected: _showTranslation,
                onPressed: () =>
                    setState(() => _showTranslation = !_showTranslation),
                icon: const Icon(Icons.translate),
              ),
            ),
          ],
        ),
        body: FutureBuilder<Surah>(
          future: QuranRepository.surah(widget.surahNumber),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Skeleton(height: 96, count: 5);
            }
            if (snap.hasError) {
              return ErrorState(message: '${snap.error}');
            }
            final surah = snap.data!;
            return ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: SLSpacing.s16,
                vertical: SLSpacing.s12,
              ),
              itemCount: surah.ayahs.length,
              itemBuilder: (context, i) {
                final ayah = surah.ayahs[i];
                final marked = _bookmarks.contains((
                  widget.surahNumber,
                  ayah.numberInSurah,
                ));
                return Padding(
                  padding: const EdgeInsets.only(bottom: SLSpacing.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primaryContainer,
                              borderRadius: SLRadius.brPill,
                            ),
                            child: Text(
                              bn
                                  ? toBn(ayah.numberInSurah)
                                  : '${ayah.numberInSurah}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Spacer(),
                          if (ayah.juz != null)
                            Text(
                              'জুয ${bn ? toBn(ayah.juz!) : ayah.juz}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          Semantics(
                            toggled: marked,
                            label: context.t('quran_bookmark'),
                            child: IconButton(
                              tooltip: context.t('quran_bookmark'),
                              iconSize: 18,
                              isSelected: marked,
                              onPressed: () {
                                _toggleBookmark(ayah.numberInSurah);
                                ref
                                    .read(dbProvider)
                                    .saveLastRead(
                                      widget.surahNumber,
                                      ayah.numberInSurah,
                                    );
                              },
                              icon: Icon(
                                marked ? Icons.bookmark : Icons.bookmark_border,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: SLSpacing.s4),
                      InkWell(
                        onTap: () {
                          ref
                              .read(dbProvider)
                              .saveLastRead(
                                widget.surahNumber,
                                ayah.numberInSurah,
                              );
                        },
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              ayah.text,
                              style: SLType.quran(
                                color: theme.colorScheme.onSurface,
                              ),
                              textDirection: TextDirection.rtl,
                              textAlign: TextAlign.right,
                            ),
                            if (_showTranslation &&
                                (ayah.translationBn?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: SLSpacing.s4),
                              Text(
                                ayah.translationBn!,
                                style: theme.textTheme.bodyMedium,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
