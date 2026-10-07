/// ইলম — knowledge hub grid with the 8 content apps.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../shared/contact_fab.dart' show kContactFabClearance;
import '../shared/global_header.dart';
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
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.question,
        title: context.t('ilm_quizzes'),
        route: '/ilm/quizzes',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.broadcast,
        title: context.t('ilm_live_quiz'),
        route: '/ilm/live-quiz',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.bookOpen,
        title: context.t('ilm_quran'),
        route: '/ilm/quran',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.plant,
        title: context.t('ilm_adhkar'),
        route: '/ilm/adhkar',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.hand,
        title: context.t('ilm_duas'),
        route: '/ilm/duas',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.sun,
        title: context.t('ilm_names99'),
        route: '/ilm/names99',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.baby,
        title: context.t('ilm_baby_names'),
        route: '/ilm/islamic-names',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.heart,
        title: context.t('ilm_iman_branches'),
        route: '/ilm/iman-branches',
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.sunHorizon,
        title: context.t('ilm_sunnahs'),
        route: '/ilm/sunnahs',
        badge: _sunnahsNew,
      ),
      _IlmEntry(
        icon: PhosphorIconsRegular.article,
        title: context.t('ilm_articles'),
        route: '/ilm/articles',
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

    Widget badge() => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.tertiary,
        borderRadius: SLRadius.brPill,
      ),
      child: Text(
        context.t('badge_new'),
        style: theme.textTheme.bodySmall?.copyWith(
          // dark ink on gold (white was 2.6:1)
          color: theme.colorScheme.onTertiary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    Widget icon(IconData i) => Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: SLRadius.brMd,
      ),
      child: Icon(i, size: 24, color: theme.colorScheme.primary),
    );

    Widget tile(_IlmEntry e, {bool wide = false}) => AppCard(
      key: ValueKey('ilm_tile_${e.route}'),
      onTap: () => open(e),
      padding: const EdgeInsets.all(SLSpacing.s12),
      child: wide
          ? Row(
              children: [
                icon(e.icon),
                const SizedBox(width: SLSpacing.s12),
                Expanded(
                  child: Text(
                    e.title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (e.badge) badge(),
                const SizedBox(width: SLSpacing.s4),
                DirectionalIcon(
                  PhosphorIconsRegular.caretRight,
                  size: 18,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            )
          : Stack(
              children: [
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      icon(e.icon),
                      const SizedBox(height: SLSpacing.s8),
                      Text(
                        e.title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.badge)
                  PositionedDirectional(top: 0, end: 0, child: badge()),
              ],
            ),
    );

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
              // three groups, two tiles a row; a group's odd last tile
              // runs full width (a lone "আর্টিকেল" used to sit in an empty
              // row at the bottom)
              for (final (gi, group) in groups.indexed) ...[
                SectionHeader(group.$1, icon: group.$2),
                for (var i = 0; i < group.$3.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: SLSpacing.s12),
                    child: i + 1 < group.$3.length
                        ? IntrinsicHeight(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(child: tile(group.$3[i])),
                                const SizedBox(width: SLSpacing.s12),
                                Expanded(child: tile(group.$3[i + 1])),
                              ],
                            ),
                          )
                        : tile(group.$3[i], wide: true),
                  ),
                if (gi < groups.length - 1)
                  const SizedBox(height: SLSpacing.s4),
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
    this.badge = false,
  });
  final IconData icon;
  final String title;
  final String route;
  final bool badge;
}
