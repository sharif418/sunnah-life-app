/// কুরআন — the surah / para / bookmark lists and the reader.
///
/// Reworked 2026-10-09 (Ilm audit, phase 2):
/// - lists: সূরা (meaning, মাক্কী/মাদানী, loose search), পারা (the 30
///   para starts from the pack), বুকমার্ক; a "চালিয়ে পড়ুন" card naming the
///   surah and ayah;
/// - reader: a surah header + the Basmala; the place is saved as the
///   reader scrolls (it used to be saved only on a tap); the para is shown
///   where it begins, not on every ayah; tapping an ayah opens its actions
///   (play from here, bookmark, copy, share); text sizes and the translation
///   toggle are kept; the playing ayah stays in view with a mini player at
///   the bottom (play/pause, previous, next, stop) and a "play the surah"
///   button; the next surah is offered at the end;
/// - tilawat auto-log (session minutes → diary, source auto:quran:tilawat),
///   go-to-ayah and per-ayah audio as before.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart' show LangX;
import '../../models/quran_models.dart';
import '../../services/platform_channels.dart' show SystemChannel;
import '../../state/providers.dart';
import '../../state/remote_state.dart' show configProvider;
import '../shared/widgets.dart';
import 'quran_audio.dart';
import 'quran_tilawat_sheet.dart';
import '../../design/phosphor_icons.dart';

// ── reading preferences ─────────────────────────────────────────────────────

const _kArabicSize = 'quran_arabic_size';
const _kTransSize = 'quran_trans_size';
const _kShowTrans = 'quran_show_trans';

class QuranReadingPrefs {
  const QuranReadingPrefs({
    this.arabic = 26,
    this.translation = 15,
    this.showTranslation = true,
  });
  final double arabic;
  final double translation;
  final bool showTranslation;

  QuranReadingPrefs copyWith({
    double? arabic,
    double? translation,
    bool? showTranslation,
  }) => QuranReadingPrefs(
    arabic: arabic ?? this.arabic,
    translation: translation ?? this.translation,
    showTranslation: showTranslation ?? this.showTranslation,
  );

  static Future<QuranReadingPrefs> load() async {
    try {
      final p = await SharedPreferences.getInstance();
      return QuranReadingPrefs(
        arabic: p.getDouble(_kArabicSize) ?? 26,
        translation: p.getDouble(_kTransSize) ?? 15,
        showTranslation: p.getBool(_kShowTrans) ?? true,
      );
    } catch (_) {
      return const QuranReadingPrefs();
    }
  }

  Future<void> save() async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setDouble(_kArabicSize, arabic);
      await p.setDouble(_kTransSize, translation);
      await p.setBool(_kShowTrans, showTranslation);
    } catch (_) {}
  }
}

String _n(BuildContext context, int v) => context.isBn ? toBn(v) : '$v';

// ── the lists ───────────────────────────────────────────────────────────────

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  String _query = '';
  (int, int)? _lastRead;
  List<(int, int)> _bookmarks = const [];

  /// Memoized once (W3a): the search field lives OUTSIDE the FutureBuilder,
  /// so keystrokes rebuild the filtered list — never the TextField — and the
  /// keyboard stays open; the future identity never changes mid-session.
  late final Future<List<SurahMeta>> _surahsFuture;
  late final Future<List<JuzStart>> _juzFuture;

  @override
  void initState() {
    super.initState();
    _surahsFuture = QuranRepository.surahList();
    _juzFuture = QuranRepository.juzStarts();
    _reloadPlace();
  }

  /// The resume card and the bookmark list — again after every visit to
  /// the reader (the old chip was read once and went stale).
  Future<void> _reloadPlace() async {
    final db = ref.read(dbProvider);
    final row = await db.lastReadEntry();
    final marks = (await db.bookmarks()).toList()
      ..sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    if (!mounted) return;
    setState(() {
      _lastRead = row == null ? null : (row.surah, row.ayah);
      _bookmarks = marks;
    });
  }

  Future<void> _open(int surah, {int? ayah}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SurahReaderScreen(surahNumber: surah, startAyah: ayah),
      ),
    );
    await _reloadPlace();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: Text(context.t('quran_reader')),
          bottom: TabBar(
            tabs: [
              Tab(text: context.t('quran_tab_surah')),
              Tab(text: context.t('quran_tab_para')),
              Tab(text: context.t('quran_tab_bookmarks')),
            ],
          ),
        ),
        body: FutureBuilder<List<SurahMeta>>(
          future: _surahsFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Skeleton(height: 64, count: 8);
            }
            final surahs = snap.data ?? const <SurahMeta>[];
            if (surahs.isEmpty) {
              return EmptyState(
                message: context.t('empty_generic'),
                icon: PhosphorIconsRegular.bookOpen,
              );
            }
            final byNumber = {for (final s in surahs) s.number: s};
            return TabBarView(
              children: [
                _surahTab(surahs, byNumber),
                _paraTab(byNumber),
                _bookmarkTab(byNumber),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _surahTab(List<SurahMeta> surahs, Map<int, SurahMeta> byNumber) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final filtered = QuranRepository.filterSurahs(surahs, _query);
    final last = _lastRead;
    final lastMeta = last == null ? null : byNumber[last.$1];
    return Column(
      children: [
        // Stable across list rebuilds — typing never unmounts the field.
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s12,
            SLSpacing.s16,
            SLSpacing.s4,
          ),
          child: TextField(
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: context.t('quran_search_hint'),
              prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
              isDense: true,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s8,
              SLSpacing.s16,
              SLSpacing.s24,
            ),
            itemCount: filtered.length + (lastMeta != null ? 1 : 0),
            separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s8),
            itemBuilder: (context, i) {
              if (lastMeta != null && i == 0) {
                // where the reader stopped, by name
                return AppCard(
                  key: const ValueKey('quran_resume_card'),
                  onTap: () => _open(last.$1, ayah: last.$2),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          PhosphorIconsRegular.bookOpen,
                          color: cs.onPrimary,
                        ),
                      ),
                      const SizedBox(width: SLSpacing.s12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.t('quran_continue'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              '${lastMeta.nameBn} · ${context.t('quran_ayah')} ${_n(context, last!.$2)}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      DirectionalIcon(
                        PhosphorIconsRegular.caretRight,
                        color: cs.onSurfaceVariant,
                      ),
                    ],
                  ),
                );
              }
              final s = filtered[i - (lastMeta != null ? 1 : 0)];
              return AppCard(
                onTap: () => _open(s.number),
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
                        color: cs.primaryContainer,
                        borderRadius: SLRadius.brMd,
                      ),
                      child: Text(
                        _n(context, s.number),
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
                            '${s.revelationBn} · ${_n(context, s.ayahCount)} ${context.t('quran_ayahs')}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                          if (s.meaningBn.isNotEmpty)
                            Text(
                              s.meaningBn,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: SLSpacing.s8),
                    Text(s.name, style: SLType.dua(color: cs.primary)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _paraTab(Map<int, SurahMeta> byNumber) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return FutureBuilder<List<JuzStart>>(
      future: _juzFuture,
      builder: (context, snap) {
        final starts = snap.data;
        if (starts == null) return const Skeleton(height: 56, count: 8);
        return ListView.separated(
          padding: const EdgeInsets.all(SLSpacing.s16),
          itemCount: starts.length,
          separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s8),
          itemBuilder: (context, i) {
            final j = starts[i];
            final meta = byNumber[j.surah];
            return AppCard(
              key: ValueKey('quran_para_${j.juz}'),
              onTap: () => _open(j.surah, ayah: j.ayah),
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
                      color: cs.primaryContainer,
                      borderRadius: SLRadius.brMd,
                    ),
                    child: Text(
                      _n(context, j.juz),
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
                          '${context.t('quran_juz')} ${_n(context, j.juz)}',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          context
                              .t('quran_para_starts_fmt')
                              .replaceAll('%s', meta?.nameBn ?? '${j.surah}')
                              .replaceAll('%a', _n(context, j.ayah)),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DirectionalIcon(
                    PhosphorIconsRegular.caretRight,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _bookmarkTab(Map<int, SurahMeta> byNumber) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    if (_bookmarks.isEmpty) {
      return ListView(
        children: [
          const SizedBox(height: SLSpacing.s24),
          EmptyState(
            icon: PhosphorIconsRegular.bookmark,
            message: context.t('quran_bookmarks_empty'),
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(SLSpacing.s16),
      itemCount: _bookmarks.length,
      separatorBuilder: (_, _) => const SizedBox(height: SLSpacing.s8),
      itemBuilder: (context, i) {
        final (surah, ayah) = _bookmarks[i];
        final meta = byNumber[surah];
        return AppCard(
          onTap: () => _open(surah, ayah: ayah),
          child: Row(
            children: [
              Icon(PhosphorIconsFill.bookmark, color: cs.primary),
              const SizedBox(width: SLSpacing.s12),
              Expanded(
                child: Text(
                  '${meta?.nameBn ?? surah} · ${context.t('quran_ayah')} ${_n(context, ayah)}',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              DirectionalIcon(
                PhosphorIconsRegular.caretRight,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── the reader ──────────────────────────────────────────────────────────────

class SurahReaderScreen extends ConsumerStatefulWidget {
  const SurahReaderScreen({
    super.key,
    required this.surahNumber,
    this.startAyah,
  });
  final int surahNumber;

  /// Open scrolled to this ayah (the resume card, a para, a bookmark).
  final int? startAyah;

  @override
  ConsumerState<SurahReaderScreen> createState() => _SurahReaderScreenState();
}

class _SurahReaderScreenState extends ConsumerState<SurahReaderScreen> {
  QuranReadingPrefs _prefs = const QuranReadingPrefs();
  DateTime _sessionStart = DateTime.now();
  Set<(int, int)> _bookmarks = <(int, int)>{};

  /// Memoized in initState (W3a): the AppBar-title and body FutureBuilders
  /// share ONE future, so the list never rebuilds from scratch.
  late final Future<Surah> _surahFuture;
  late final Future<List<SurahMeta>> _metaFuture = QuranRepository.surahList();
  final ScrollController _scroll = ScrollController();
  final GlobalKey _listKey = GlobalKey();

  /// Per-ayah-item keys (0-based list index → key) so the two-step jump can
  /// `Scrollable.ensureVisible` the exact item after the coarse estimate.
  final Map<int, GlobalKey> _ayahKeys = <int, GlobalKey>{};

  /// The ayah last saved as the reading place (avoids rewriting it).
  int? _savedAyah;

  /// The member dragged the list recently: the audio does not pull it away.
  DateTime _userScrolledAt = DateTime(2000);

  // ── Recitation audio (W3a) ──────────────────────────────────────────────────
  AudioPlayer? _player;
  StreamSubscription<ProcessingState>? _processingSub;
  int? _playingAyah;

  /// The current ayah is held mid-way (pause, not stop).
  bool _paused = false;
  int _totalAyahs = 0;
  ReciterOption _reciter = kQuranReciters.first;

  @override
  void initState() {
    super.initState();
    _sessionStart = DateTime.now();
    _surahFuture = QuranRepository.surah(widget.surahNumber);
    _loadBookmarks();
    _loadReciter();
    QuranReadingPrefs.load().then((p) {
      if (mounted) setState(() => _prefs = p);
    });
    _surahFuture.then((surah) {
      if (!mounted) return;
      _totalAyahs = surah.ayahs.length;
      final target = widget.startAyah;
      if (target != null && target > 1 && target <= _totalAyahs) {
        unawaited(_jumpToAyah(target));
      }
    });
  }

  @override
  void dispose() {
    _processingSub?.cancel();
    unawaited(_player?.dispose());
    _scroll.dispose();
    super.dispose();
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
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t(add ? 'quran_bookmarked' : 'quran_bookmark_removed'),
        ),
      ),
    );
  }

  // ── the reading place, saved as the member reads ─────────────────────────

  /// The ayah at the top of the screen.
  int? _topAyah() {
    final listBox = _listKey.currentContext?.findRenderObject() as RenderBox?;
    if (listBox == null || !listBox.attached) return null;
    final top = listBox.localToGlobal(Offset.zero).dy;
    int? best;
    double bestDy = double.infinity;
    for (final e in _ayahKeys.entries) {
      final box = e.value.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      final bottom = y + box.size.height;
      // the first ayah whose bottom is still below the list's top edge
      if (bottom > top + 24 && y < bestDy) {
        bestDy = y;
        best = e.key;
      }
    }
    return best == null ? null : best + 1;
  }

  void _saveReadingPlace() {
    final ayah = _topAyah();
    if (ayah == null || ayah == _savedAyah) return;
    _savedAyah = ayah;
    unawaited(ref.read(dbProvider).saveLastRead(widget.surahNumber, ayah));
  }

  Future<void> _logTilawat() async {
    _saveReadingPlace();
    final minutes = DateTime.now()
        .difference(_sessionStart)
        .inMinutes
        .clamp(0, 180);
    if (minutes >= 1 && mounted) {
      await showTilawatSheet(
        context,
        ref,
        minutes: minutes,
        onLogged: () => _sessionStart = DateTime.now(),
      );
    }
  }

  // ── Go-to-ayah: coarse estimate → exact ensureVisible ─────────────────────

  Future<void> _jumpToAyah(int ayah) async {
    final surah = await _surahFuture;
    final idx = (ayah - 1).clamp(0, surah.ayahs.length - 1);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(
      estimateJumpOffset(
        ayahIndex: idx,
        totalAyahs: surah.ayahs.length,
        maxScrollExtent: _scroll.position.maxScrollExtent,
      ),
    );
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    await _ensureVisible(idx);
  }

  Future<void> _ensureVisible(int index) async {
    final ctx = _ayahKeys[index]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        alignment: 0.12,
      );
    } else if (_scroll.hasClients && _totalAyahs > 0) {
      // not built yet: estimate, then snap
      _scroll.jumpTo(
        estimateJumpOffset(
          ayahIndex: index,
          totalAyahs: _totalAyahs,
          maxScrollExtent: _scroll.position.maxScrollExtent,
        ),
      );
      await WidgetsBinding.instance.endOfFrame;
      final again = _ayahKeys[index]?.currentContext;
      if (again != null && again.mounted) {
        await Scrollable.ensureVisible(again, alignment: 0.12);
      }
    }
  }

  Future<void> _showGoToAyah() async {
    final surah = await _surahFuture;
    if (!mounted) return;
    final controller = TextEditingController();
    final submitted = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.t('quran_goto_ayah')),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText:
                '${context.t('quran_goto_ayah_hint')} (1–${_n(context, surah.ayahs.length)})',
          ),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(context.t('ok')),
          ),
        ],
      ),
    );
    if (submitted == null) return;
    final n = parseAyahInput(submitted);
    if (n == null || n < 1 || n > surah.ayahs.length) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('quran_invalid_ayah'))),
        );
      }
      return;
    }
    await _jumpToAyah(n);
  }

  // ── text size ─────────────────────────────────────────────────────────────

  Future<void> _showTextSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheet) {
          final theme = Theme.of(sheetContext);
          void apply(QuranReadingPrefs p) {
            setSheet(() {});
            setState(() => _prefs = p);
            unawaited(p.save());
          }

          return SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  SLSpacing.s16,
                  0,
                  SLSpacing.s16,
                  SLSpacing.s16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      context.t('quran_text_size'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: SLSpacing.s8),
                    Text(
                      'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: SLType.quran(color: theme.colorScheme.onSurface)
                          .copyWith(fontSize: _prefs.arabic),
                    ),
                    Text(context.t('quran_arabic_size')),
                    Slider(
                      key: const ValueKey('quran_arabic_slider'),
                      min: 22,
                      max: 40,
                      divisions: 9,
                      value: _prefs.arabic.clamp(22, 40),
                      onChanged: (v) => apply(_prefs.copyWith(arabic: v)),
                    ),
                    Text(context.t('quran_translation_size')),
                    Slider(
                      min: 14,
                      max: 22,
                      divisions: 8,
                      value: _prefs.translation.clamp(14, 22),
                      onChanged: (v) => apply(_prefs.copyWith(translation: v)),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(context.t('quran_translation_toggle')),
                      value: _prefs.showTranslation,
                      onChanged: (v) =>
                          apply(_prefs.copyWith(showTranslation: v)),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── ayah actions ──────────────────────────────────────────────────────────

  String _ayahText(Surah surah, Ayah ayah) => [
    ayah.text,
    if ((ayah.translationBn ?? '').isNotEmpty) ayah.translationBn!,
    '— ${surah.meta.nameBn} ${_n(context, surah.meta.number)}:${_n(context, ayah.numberInSurah)}',
  ].join('\n\n');

  Future<void> _showAyahActions(Surah surah, Ayah ayah, bool audio) async {
    final marked = _bookmarks.contains((
      widget.surahNumber,
      ayah.numberInSurah,
    ));
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
              child: Text(
                '${surah.meta.nameBn} · ${context.t('quran_ayah')} ${_n(context, ayah.numberInSurah)}',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            if (audio)
              ListTile(
                key: const ValueKey('ayah_action_play'),
                leading: const Icon(PhosphorIconsRegular.playCircle),
                title: Text(context.t('quran_play_from_here')),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  unawaited(_playAyah(ayah.numberInSurah));
                },
              ),
            ListTile(
              key: const ValueKey('ayah_action_bookmark'),
              leading: Icon(
                marked
                    ? PhosphorIconsFill.bookmark
                    : PhosphorIconsRegular.bookmark,
              ),
              title: Text(
                context.t(marked ? 'quran_bookmark_remove' : 'quran_bookmark'),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(_toggleBookmark(ayah.numberInSurah));
              },
            ),
            ListTile(
              key: const ValueKey('ayah_action_copy'),
              leading: const Icon(PhosphorIconsRegular.copy),
              title: Text(context.t('copy')),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await Clipboard.setData(
                  ClipboardData(text: _ayahText(surah, ayah)),
                );
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(context.t('copied'))));
                }
              },
            ),
            ListTile(
              key: const ValueKey('ayah_action_share'),
              leading: const Icon(PhosphorIconsRegular.shareNetwork),
              title: Text(context.t('share')),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(SystemChannel.shareText(_ayahText(surah, ayah)));
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Recitation audio ───────────────────────────────────────────────────────

  /// audioBase is the config gate: empty/absent → no audio affordances.
  bool get _audioEnabled =>
      (ref.watch(configProvider).valueOrNull?.audioBase ?? '').isNotEmpty;

  Future<void> _loadReciter() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(kQuranReciterPrefKey);
      if (id != null && mounted) {
        setState(() => _reciter = reciterById(id));
      }
    } on Exception {
      // Prefs unavailable → keep the default reciter.
    }
  }

  void _ensurePlayer() {
    final existing = _player;
    if (existing != null) return;
    final player = AudioPlayer();
    _player = player;
    // Auto-advance: when an ayah finishes, play the next one until the
    // surah ends (idle/stop states never emit `completed`).
    _processingSub = player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) _onAyahCompleted();
    });
  }

  void _onAyahCompleted() {
    final current = _playingAyah;
    if (current == null) return;
    if (current < _totalAyahs) {
      unawaited(_playAyah(current + 1));
    } else {
      unawaited(_stopAudio());
    }
  }

  Future<void> _playAyah(int ayah) async {
    try {
      _ensurePlayer();
      if (mounted) {
        setState(() {
          _playingAyah = ayah;
          _paused = false;
        });
      } else {
        _playingAyah = ayah;
        _paused = false;
      }
      // the recited ayah stays in view — unless the member is scrolling
      if (DateTime.now().difference(_userScrolledAt) >
          const Duration(seconds: 4)) {
        unawaited(_ensureVisible(ayah - 1));
      }
      // LockCachingAudioSource caches each ayah on disk after the first
      // play — re-listening is instant and offline once cached.
      await _player!.setAudioSource(
        // ignore: experimental_member_use
        LockCachingAudioSource(
          Uri.parse(
            ayahAudioUrl(
              reciter: _reciter,
              surah: widget.surahNumber,
              ayah: ayah,
            ),
          ),
        ),
      );
      await _player!.play();
    } on Exception {
      // Network/404/source errors surface a SnackBar — never a crash.
      await _stopAudio();
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('quran_audio_error'))));
      }
    }
  }

  Future<void> _stopAudio() async {
    if (mounted && _playingAyah != null) {
      setState(() {
        _playingAyah = null;
        _paused = false;
      });
    } else {
      _playingAyah = null;
      _paused = false;
    }
    try {
      await _player?.stop();
    } on Exception {
      // A failed stop leaves nothing playing anyway.
    }
  }

  void _pauseResume() {
    final player = _player;
    if (player == null || _playingAyah == null) return;
    if (_paused) {
      setState(() => _paused = false);
      unawaited(player.play());
    } else {
      setState(() => _paused = true);
      unawaited(player.pause());
    }
  }

  Future<void> _pickReciter() async {
    final lang = context.lang.code;
    final picked = await showModalBottomSheet<ReciterOption>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.only(bottom: SLSpacing.s16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
              child: Text(
                context.t('quran_reciter'),
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final r in kQuranReciters)
              ListTile(
                title: Text(r.nameFor(lang)),
                trailing: r.id == _reciter.id
                    ? Icon(
                        PhosphorIconsFill.checkCircle,
                        color: Theme.of(sheetContext).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheetContext).pop(r),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    if (mounted) setState(() => _reciter = picked);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kQuranReciterPrefKey, picked.id);
    } on Exception {
      // Persisting the choice is best-effort; the session keeps it anyway.
    }
    // A reciter switch mid-playback restarts from a clean slate.
    await _stopAudio();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  Widget _surahHeader(Surah surah) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final m = surah.meta;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          key: const ValueKey('quran_surah_header'),
          margin: const EdgeInsets.only(bottom: SLSpacing.s16),
          padding: const EdgeInsets.all(SLSpacing.s16),
          decoration: BoxDecoration(
            color: cs.primaryContainer,
            borderRadius: SLRadius.brLg,
          ),
          child: Column(
            children: [
              Text(
                m.name,
                textDirection: TextDirection.rtl,
                style: SLType.dua(color: cs.primary).copyWith(fontSize: 26),
              ),
              Text(
                m.nameBn,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (m.meaningBn.isNotEmpty)
                Text(
                  m.meaningBn,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              const SizedBox(height: SLSpacing.s4),
              Text(
                '${m.revelationBn} · ${_n(context, m.ayahCount)} ${context.t('quran_ayahs')}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        if (surah.bismillahPre)
          Padding(
            key: const ValueKey('quran_basmala'),
            padding: const EdgeInsets.only(bottom: SLSpacing.s16),
            child: Text(
              'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: SLType.quran(color: cs.primary)
                  .copyWith(fontSize: _prefs.arabic),
            ),
          ),
      ],
    );
  }

  Widget _miniPlayer() {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final ayah = _playingAyah!;
    return Material(
      key: const ValueKey('quran_mini_player'),
      color: cs.surfaceContainerLowest,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: SLSpacing.s12,
            vertical: SLSpacing.s4,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t('quran_ayah')} ${_n(context, ayah)} / ${_n(context, _totalAyahs)}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      _reciter.nameFor(context.lang.code),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.t('quran_prev_ayah'),
                onPressed: ayah > 1 ? () => _playAyah(ayah - 1) : null,
                icon: Transform.flip(
                  flipX: true,
                  child: const Icon(PhosphorIconsRegular.skipForward),
                ),
              ),
              IconButton.filled(
                key: const ValueKey('quran_mini_pause'),
                tooltip: context.t(
                  _paused ? 'quran_resume_audio' : 'quran_pause',
                ),
                onPressed: _pauseResume,
                icon: Icon(
                  _paused
                      ? PhosphorIconsRegular.play
                      : PhosphorIconsRegular.pauseCircle,
                ),
              ),
              IconButton(
                tooltip: context.t('quran_next_ayah'),
                onPressed: ayah < _totalAyahs
                    ? () => _playAyah(ayah + 1)
                    : null,
                icon: const Icon(PhosphorIconsRegular.skipForward),
              ),
              IconButton(
                tooltip: context.t('quran_stop_audio'),
                onPressed: _stopAudio,
                icon: const Icon(PhosphorIconsRegular.stopCircle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final audio = _audioEnabled;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _logTilawat();
        if (context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: const BackButton(),
          title: FutureBuilder<Surah>(
            future: _surahFuture,
            builder: (context, snap) => Text(
              snap.data?.meta.nameBn ?? context.t('quran_reader'),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          actions: [
            if (audio)
              IconButton(
                key: const ValueKey('quran_play_surah'),
                tooltip: context.t('quran_play_surah'),
                icon: const Icon(PhosphorIconsRegular.playCircle),
                onPressed: () => _playAyah(_topAyah() ?? 1),
              ),
            IconButton(
              key: const ValueKey('quran_text_settings'),
              tooltip: context.t('quran_text_size'),
              icon: const Icon(Icons.format_size),
              onPressed: _showTextSettings,
            ),
            IconButton(
              tooltip: context.t('quran_goto_ayah'),
              icon: const Icon(PhosphorIconsRegular.crosshair),
              onPressed: _showGoToAyah,
            ),
            if (audio)
              IconButton(
                tooltip: context.t('quran_reciter'),
                icon: const Icon(PhosphorIconsRegular.userSound),
                onPressed: _pickReciter,
              ),
          ],
        ),
        bottomNavigationBar: _playingAyah == null ? null : _miniPlayer(),
        body: FutureBuilder<Surah>(
          future: _surahFuture,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Skeleton(height: 96, count: 5);
            }
            if (snap.hasError) {
              return ErrorState(message: '${snap.error}');
            }
            final surah = snap.data!;
            final next = widget.surahNumber < 114
                ? widget.surahNumber + 1
                : null;
            return NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollStartNotification && n.dragDetails != null) {
                  _userScrolledAt = DateTime.now();
                }
                if (n is ScrollEndNotification) {
                  // after the frame that lays out the new offset (at the
                  // notification the boxes may still sit where they were)
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) _saveReadingPlace();
                  });
                  WidgetsBinding.instance.scheduleFrame();
                }
                return false;
              },
              child: ListView.builder(
                key: _listKey,
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(
                  SLSpacing.s16,
                  SLSpacing.s12,
                  SLSpacing.s16,
                  SLSpacing.s32,
                ),
                itemCount: surah.ayahs.length + 1,
                itemBuilder: (context, i) {
                  if (i == surah.ayahs.length) {
                    return _endOfSurah(next);
                  }
                  final ayah = surah.ayahs[i];
                  final marked = _bookmarks.contains((
                    widget.surahNumber,
                    ayah.numberInSurah,
                  ));
                  final playing = _playingAyah == ayah.numberInSurah;
                  // the para only where it begins (it was on every ayah)
                  final prevJuz = i == 0 ? null : surah.ayahs[i - 1].juz;
                  final juzStarts = ayah.juz != null && ayah.juz != prevJuz;
                  final tile = AnimatedContainer(
                    key: _ayahKeys.putIfAbsent(i, GlobalKey.new),
                    duration: SLMotion.base,
                    curve: SLMotion.standard,
                    padding: const EdgeInsets.fromLTRB(
                      SLSpacing.s8,
                      SLSpacing.s4,
                      SLSpacing.s8,
                      SLSpacing.s8,
                    ),
                    decoration: BoxDecoration(
                      // the recited ayah: a gold wash and a gold edge
                      color: playing
                          ? cs.tertiary.withValues(alpha: 0.16)
                          : Colors.transparent,
                      borderRadius: SLRadius.brMd,
                      border: playing
                          ? Border(
                              left: BorderSide(color: cs.tertiary, width: 3),
                            )
                          : null,
                    ),
                    margin: const EdgeInsets.only(bottom: SLSpacing.s12),
                    child: InkWell(
                      key: ValueKey('ayah_${ayah.numberInSurah}'),
                      borderRadius: SLRadius.brMd,
                      onTap: () => _showAyahActions(surah, ayah, audio),
                      onLongPress: () => _showAyahActions(surah, ayah, audio),
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
                                  color: cs.primaryContainer,
                                  borderRadius: SLRadius.brPill,
                                ),
                                child: Text(
                                  _n(context, ayah.numberInSurah),
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (juzStarts) ...[
                                const SizedBox(width: SLSpacing.s8),
                                Text(
                                  '${context.t('quran_juz')} ${_n(context, ayah.juz!)}',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: cs.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              if (marked)
                                Icon(
                                  PhosphorIconsFill.bookmark,
                                  size: 20,
                                  color: cs.primary,
                                ),
                              Icon(
                                PhosphorIconsRegular.dotsThreeOutline,
                                size: 22,
                                color: cs.onSurfaceVariant,
                              ),
                            ],
                          ),
                          const SizedBox(height: SLSpacing.s4),
                          Text(
                            ayah.text,
                            style: SLType.quran(color: cs.onSurface)
                                .copyWith(fontSize: _prefs.arabic),
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                          ),
                          if (_prefs.showTranslation &&
                              (ayah.translationBn?.isNotEmpty ?? false)) ...[
                            const SizedBox(height: SLSpacing.s4),
                            Text(
                              ayah.translationBn!,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: _prefs.translation,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                  if (i != 0) return tile;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [_surahHeader(surah), tile],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _endOfSurah(int? next) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: SLSpacing.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.t('quran_surah_end'),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          if (next != null) ...[
            const SizedBox(height: SLSpacing.s12),
            FutureBuilder<List<SurahMeta>>(
              future: _metaFuture,
              builder: (_, snap) {
                final name = snap.data
                    ?.where((s) => s.number == next)
                    .firstOrNull
                    ?.nameBn;
                return FilledButton.tonalIcon(
                  key: const ValueKey('quran_next_surah'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const DirectionalIcon(PhosphorIconsRegular.arrowRight),
                  label: Text(
                    '${context.t('quran_next_surah')}${name == null ? '' : ': $name'}',
                  ),
                  onPressed: () async {
                    await _logTilawat();
                    if (!mounted) return;
                    await Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => SurahReaderScreen(surahNumber: next),
                      ),
                    );
                  },
                );
              },
            ),
          ],
          SizedBox(height: math.max(0, MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}
