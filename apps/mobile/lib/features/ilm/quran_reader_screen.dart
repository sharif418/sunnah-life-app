/// কুরআন পাঠক — surah list → Uthmani reader with Bengali translation
/// toggle, ayah bookmarks, last-read resume, tilawat auto-log
/// (session minutes → diary quantity entry, source auto:quran:tilawat),
/// go-to-ayah (two-step jump) and per-ayah recitation audio (W3a).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/bn_digits.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart' show LangX;
import '../../models/quran_models.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart' show configProvider;
import '../shared/widgets.dart';
import 'quran_audio.dart';
import 'quran_tilawat_sheet.dart';
import '../../design/phosphor_icons.dart';

class QuranReaderScreen extends ConsumerStatefulWidget {
  const QuranReaderScreen({super.key});

  @override
  ConsumerState<QuranReaderScreen> createState() => _QuranReaderScreenState();
}

class _QuranReaderScreenState extends ConsumerState<QuranReaderScreen> {
  String _query = '';
  (int, int)? _lastRead;

  /// Memoized once (W3a): the search field lives OUTSIDE the FutureBuilder,
  /// so keystrokes rebuild the filtered list — never the TextField — and the
  /// keyboard stays open; the future identity never changes mid-session.
  late final Future<List<SurahMeta>> _surahsFuture;

  @override
  void initState() {
    super.initState();
    _surahsFuture = QuranRepository.surahList();
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
      body: Column(
        children: [
          // Stable across list rebuilds — typing never unmounts the field.
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
                prefixIcon: const Icon(PhosphorIconsRegular.magnifyingGlass),
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
                      avatar: const Icon(PhosphorIconsFill.bookmark, size: 18),
                      label: Text(context.t('quran_resume')),
                      onPressed: () => _openSurah(_lastRead!.$1),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: FutureBuilder<List<SurahMeta>>(
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
                final filtered = QuranRepository.filterSurahs(surahs, _query);
                return ListView.builder(
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
                );
              },
            ),
          ),
        ],
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

  /// Memoized in initState (W3a): the AppBar-title and body FutureBuilders
  /// share ONE future, and the translation toggle / bookmark writes /
  /// audio state changes only setState — the future identity never changes,
  /// so the list never rebuilds from scratch (no jump back to the top).
  late final Future<Surah> _surahFuture;
  final ScrollController _scroll = ScrollController();

  /// Per-ayah-item keys (0-based list index → key) so the two-step jump can
  /// `Scrollable.ensureVisible` the exact item after the coarse estimate.
  final Map<int, GlobalKey> _ayahKeys = <int, GlobalKey>{};

  // ── Recitation audio (W3a) ──────────────────────────────────────────────────
  AudioPlayer? _player;
  StreamSubscription<ProcessingState>? _processingSub;
  int? _playingAyah;

  /// The current ayah is held mid-way (pause, not stop): its button
  /// resumes from where it was instead of starting the ayah over.
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
    _surahFuture.then((surah) {
      if (!mounted) return;
      _totalAyahs = surah.ayahs.length;
      // Resume-from-last-read: only when the reader was opened through the
      // resume chip (lastReadAyah was passed and belongs to this surah).
      final target = widget.lastReadAyah;
      if (target != null && target >= 1 && target <= _totalAyahs) {
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

  // ── Go-to-ayah: coarse estimate → exact ensureVisible ─────────────────────

  Future<void> _jumpToAyah(int ayah) async {
    final surah = await _surahFuture;
    final idx = (ayah - 1).clamp(0, surah.ayahs.length - 1);
    // Let the resolved future paint a frame first so the scrollable has
    // real extents and the target item is built.
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(
      estimateJumpOffset(
        ayahIndex: idx,
        totalAyahs: surah.ayahs.length,
        maxScrollExtent: _scroll.position.maxScrollExtent,
      ),
    );
    // After the estimate lands, the lazily-built target exists — snap to it
    // exactly (and keep it near the top rather than hiding under the AppBar).
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    final ctx = _ayahKeys[idx]?.currentContext;
    if (ctx != null && ctx.mounted) {
      await Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 0.15,
      );
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
          // Bengali digits are accepted by parseAyahInput on submit.
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            hintText:
                '${context.t('quran_goto_ayah_hint')} (1–${context.isBn ? toBn(surah.ayahs.length) : surah.ayahs.length})',
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
      if ((_playingAyah != ayah || _paused) && mounted) {
        setState(() {
          _playingAyah = ayah;
          _paused = false;
        });
      } else {
        _playingAyah = ayah;
        _paused = false;
      }
      // LockCachingAudioSource caches each ayah on disk after the first
      // play — re-listening is instant and offline once cached.
      await _player!.setAudioSource(
        // The experimental tag is just_audio's API-stability marker; the
        // class has shipped stable on Android/iOS for years.
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

  void _toggleAudio(int ayah) {
    final player = _player;
    if (_playingAyah == ayah && player != null) {
      // the pause icon pauses (it used to stop — the next tap restarted the
      // ayah from its first word); a paused ayah resumes
      if (_paused) {
        setState(() => _paused = false);
        unawaited(player.play());
      } else {
        setState(() => _paused = true);
        unawaited(player.pause());
      }
    } else {
      unawaited(_playAyah(ayah));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bn = context.isBn;
    final audio = _audioEnabled;
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
            future: _surahFuture,
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
                icon: const Icon(PhosphorIconsRegular.translate),
              ),
            ),
            IconButton(
              tooltip: context.t('quran_goto_ayah'),
              icon: const Icon(PhosphorIconsRegular.crosshair),
              onPressed: _showGoToAyah,
            ),
            if (audio) ...[
              IconButton(
                tooltip: context.t('quran_reciter'),
                icon: const Icon(PhosphorIconsRegular.userSound),
                onPressed: _pickReciter,
              ),
              if (_playingAyah != null)
                IconButton(
                  tooltip: context.t('quran_stop_audio'),
                  icon: Icon(
                    PhosphorIconsRegular.stopCircle,
                    color: theme.colorScheme.tertiary,
                  ),
                  onPressed: _stopAudio,
                ),
            ],
          ],
        ),
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
            return ListView.builder(
              controller: _scroll,
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
                final playing = _playingAyah == ayah.numberInSurah;
                final tile = AnimatedContainer(
                  key: _ayahKeys.putIfAbsent(i, GlobalKey.new),
                  duration: SLMotion.base,
                  curve: SLMotion.standard,
                  padding: const EdgeInsets.symmetric(
                    horizontal: SLSpacing.s8,
                    vertical: SLSpacing.s4,
                  ),
                  decoration: BoxDecoration(
                    // Playing ayah glows in the gold accent.
                    color: playing
                        ? theme.colorScheme.tertiary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: SLRadius.brMd,
                  ),
                  margin: const EdgeInsets.only(bottom: SLSpacing.s16),
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
                              '${context.t('quran_juz')} ${bn ? toBn(ayah.juz!) : ayah.juz}',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          if (audio)
                            Semantics(
                              toggled: playing,
                              label: context.t('quran_play_ayah'),
                              child: IconButton(
                                tooltip: context.t('quran_play_ayah'),
                                iconSize: 18,
                                isSelected: playing,
                                onPressed: () =>
                                    _toggleAudio(ayah.numberInSurah),
                                icon: Icon(
                                  playing && !_paused
                                      ? PhosphorIconsRegular.pauseCircle
                                      : PhosphorIconsRegular.playCircle,
                                  color: playing
                                      ? theme.colorScheme.tertiary
                                      : null,
                                ),
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
                                marked ? PhosphorIconsFill.bookmark : PhosphorIconsRegular.bookmark,
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
                if (i != 0 || !surah.bismillahPre) return tile;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      key: const ValueKey('quran_basmala'),
                      padding: const EdgeInsets.only(
                        top: SLSpacing.s4,
                        bottom: SLSpacing.s16,
                      ),
                      child: Text(
                        'بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ',
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                        style: SLType.quran(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    tile,
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
