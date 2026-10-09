/// ইলম — knowledge hub grid with the 8 content apps.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../shared/global_header.dart';
import '../../models/quran_models.dart';
import '../../state/providers.dart';
import '../../state/remote_state.dart';
import '../../core/bn_digits.dart';
import '../shared/widgets.dart';
import '../../design/phosphor_icons.dart';

class IlmScreen extends StatefulWidget {
  const IlmScreen({super.key});

  @override
  State<IlmScreen> createState() => _IlmScreenState();
}

class _IlmScreenState extends State<IlmScreen> {
  bool _sunnahsNew = false;

  @override
  void initState() {
    super.initState();
    _checkNewBadge();
  }

  Future<void> _checkNewBadge() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _sunnahsNew = !prefs.containsKey('sunnahs_seen'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final entries = <_IlmEntry>[
      _IlmEntry(
        icon: PhosphorIconsRegular.graduationCap,
        title: context.t('ilm_courses'),
        route: '/ilm/courses',
        subtitle: context.t('ilm_desc_courses'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.question,
        title: context.t('ilm_quizzes'),
        route: '/ilm/quizzes',
        subtitle: context.t('ilm_desc_quizzes'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.broadcast,
        title: context.t('ilm_live_quiz'),
        route: '/ilm/live-quiz',
        subtitle: context.t('ilm_desc_live_quiz'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.bookOpen,
        title: context.t('ilm_quran'),
        route: '/ilm/quran',
        subtitle: context.t('ilm_desc_quran'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.plant,
        title: context.t('ilm_adhkar'),
        route: '/ilm/adhkar',
        subtitle: context.t('ilm_desc_adhkar'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.hand,
        title: context.t('ilm_duas'),
        route: '/ilm/duas',
        subtitle: context.t('ilm_desc_duas'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.sun,
        title: context.t('ilm_names99'),
        route: '/ilm/names99',
        subtitle: context.t('ilm_desc_names99'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.baby,
        title: context.t('ilm_baby_names'),
        route: '/ilm/islamic-names',
        subtitle: context.t('ilm_desc_islamic_names'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.heart,
        title: context.t('ilm_iman_branches'),
        route: '/ilm/iman-branches',
        subtitle: context.t('ilm_desc_iman_branches'),
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.sunHorizon,
        title: context.t('ilm_sunnahs'),
        route: '/ilm/sunnahs',
        subtitle: context.t('ilm_desc_sunnahs'),
        badge: _sunnahsNew,
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.article,
        title: context.t('ilm_articles'),
        route: '/ilm/articles',
        subtitle: context.t('ilm_desc_articles'),
      ),
    ];

    _IlmEntry e(String route) => entries.firstWhere((x) => x.route == route);
    final groups = <(String, IconData, List<_IlmEntry>)>[
      (
        context.t('ilm_group_learn'),
        PhosphorIconsRegular.graduationCap,
        [
          e('/ilm/courses'),
          e('/ilm/quizzes'),
          e('/ilm/live-quiz'),
          e('/ilm/articles'),
        ],
      ),
      (
        context.t('ilm_group_quran'),
        PhosphorIconsRegular.bookOpen,
        [e('/ilm/quran'), e('/ilm/adhkar'), e('/ilm/duas'), e('/ilm/sunnahs')],
      ),
      (
        context.t('ilm_group_know'),
        PhosphorIconsRegular.sparkle,
        [e('/ilm/names99'), e('/ilm/islamic-names'), e('/ilm/iman-branches')],
      ),
    ];

    Future<void> open(_IlmEntry e) async {
      if (e.route == '/ilm/sunnahs') {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('sunnahs_seen', true);
        setState(() => _sunnahsNew = false);
      }
      if (!context.mounted) return;
      context.push(e.route);
    }

    return Scaffold(
      body: SafeArea(
        bottom: false,
        // the shared header, hiding while scrolling down (BNAV-01)
        child: ScrollAwareHeader(
          body: ListView(
            // W5: the list must scroll CLEAR of the floating contact button
            // (52 + 16 + 12 = 80dp) — it used to cover the last rows' chevrons.
            padding: const EdgeInsets.fromLTRB(
              SLSpacing.s16,
              SLSpacing.s8,
              SLSpacing.s16,
              kContactFabClearance,
            ),
            children: [
              Text(
                context.t('tab_ilm'),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: SLSpacing.s16),
              // W4j — the search entry: a field-shaped card (the tab has no
              // AppBar — the global header owns the top chrome).
              Padding(
                padding: const EdgeInsets.only(bottom: SLSpacing.s16),
                child: AppCard(
                  onTap: () => context.push('/ilm/search'),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIconsRegular.magnifyingGlass,
                        size: 22,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: SLSpacing.s12),
                      Expanded(
                        child: Text(
                          context.t('search_hint'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Icon(
                        PhosphorIconsRegular.caretRight,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              // where the member left off: the Qur'an place and an
              // unfinished course (the tiles carried no state at all)
              const _ContinueSection(),
              // three headed groups of full-width rows — the More tab's
              // pattern (one way of listing places across the app): a name
              // and a one-line hint per row, the whole row tappable, nothing
              // squeezed into a tile at large text sizes
              for (final group in groups) ...[
                SectionHeader(group.$1, icon: group.$2),
                MenuGroupCard(
                  rows: [
                    for (final e in group.$3)
                      MenuRow(
                        key: ValueKey('ilm_tile_${e.route}'),
                        icon: e.icon,
                        title: e.title,
                        subtitle: e.subtitle,
                        badge: e.badge ? context.t('badge_new') : null,
                        onTap: () => open(e),
                      ),
                  ],
                ),
                const SizedBox(height: SLSpacing.s8),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IlmEntry {
  const _IlmEntry({
    required this.icon,
    required this.title,
    required this.route,
    required this.subtitle,
    this.badge = false,
  });
  final IconData icon;
  final String title;
  final String route;

  /// One line of what is inside (rows say what they hold; tiles could not).
  final String subtitle;
  final bool badge;
}

/// "চালিয়ে যান" — the last Qur'an place and the first unfinished course;
/// nothing when there is neither.
class _ContinueSection extends ConsumerStatefulWidget {
  const _ContinueSection();

  @override
  ConsumerState<_ContinueSection> createState() => _ContinueSectionState();
}

class _ContinueSectionState extends ConsumerState<_ContinueSection> {
  (String surah, int ayah, int number)? _quran;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final row = await ref.read(dbProvider).lastReadEntry();
      if (row == null) return;
      final metas = await QuranRepository.metaOnly();
      final m = metas.where((x) => x.number == row.surah).firstOrNull;
      if (!mounted || m == null) return;
      setState(() => _quran = (m.nameBn, row.ayah, row.surah));
    } catch (_) {
      // no place to show
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final bn = context.isBn;
    String n(int v) => bn ? toBn(v) : '$v';
    final courses = ref.watch(coursePackProvider).valueOrNull ?? const [];
    final enrolled = ref.watch(enrollmentsProvider).valueOrNull ?? const [];
    final open = <(String title, int done, int total, String id)>[
      for (final e in enrolled)
        for (final c in courses.where((c) => c.id == e.courseId))
          if (c.lessonCount > 0 && e.done.length < c.lessonCount)
            (c.titleBn, e.done.length, c.lessonCount, c.id),
    ];
    final quran = _quran;
    if (quran == null && open.isEmpty) return const SizedBox.shrink();

    Widget row({
      required Key key,
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
      double? progress,
    }) => AppCard(
      key: key,
      onTap: onTap,
      padding: const EdgeInsets.all(SLSpacing.s12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: SLRadius.brMd,
            ),
            child: Icon(icon, size: 22, color: cs.onPrimary),
          ),
          const SizedBox(width: SLSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                if (progress != null) ...[
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: SLRadius.brPill,
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: cs.outline,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: SLSpacing.s8),
          DirectionalIcon(
            PhosphorIconsRegular.caretRight,
            color: cs.onSurfaceVariant,
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          context.t('ilm_continue'),
          icon: PhosphorIconsRegular.arrowClockwise,
        ),
        if (quran != null)
          row(
            key: const ValueKey('ilm_continue_quran'),
            icon: PhosphorIconsRegular.bookOpen,
            title: context.t('quran_continue'),
            subtitle: '${quran.$1} · ${context.t('quran_ayah')} ${n(quran.$2)}',
            onTap: () => context.push('/ilm/quran'),
          ),
        for (final c in open.take(1)) ...[
          if (quran != null) const SizedBox(height: SLSpacing.s8),
          row(
            key: const ValueKey('ilm_continue_course'),
            icon: PhosphorIconsRegular.graduationCap,
            title: c.$1,
            subtitle: context
                .t('ilm_course_progress_fmt')
                .replaceAll('%d', n(c.$2))
                .replaceAll('%t', n(c.$3)),
            progress: c.$2 / c.$3,
            onTap: () => context.push('/ilm/courses/${c.$4}'),
          ),
        ],
        const SizedBox(height: SLSpacing.s8),
      ],
    );
  }
}
