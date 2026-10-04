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
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: SLSpacing.s12,
                  crossAxisSpacing: SLSpacing.s12,
                  // 1.3 — Noto Sans Bengali's real Bengali metrics wrap the longest
                  // labels to three lines; the tofu-era 1.55 clipped them.
                  childAspectRatio: 1.3,
                ),
                itemCount: entries.length,
                itemBuilder: (context, i) {
                  final e = entries[i];
                  return AppCard(
                    onTap: () async {
                      if (e.route == '/ilm/sunnahs') {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool('sunnahs_seen', true);
                        setState(() => _sunnahsNew = false);
                      }
                      if (!context.mounted) return;
                      context.push(e.route);
                    },
                    child: Stack(
                      children: [
                        Center(
                          // W4f overflow sweep — the fixed aspect-ratio cell
                          // can't grow with 1.3× text (longest labels wrap
                          // to three lines); the tile shrinks to fit instead
                          // of spilling (identity at normal sizes).
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  e.icon,
                                  size: 28,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(height: SLSpacing.s4 + 2),
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
                        ),
                        if (e.badge)
                          PositionedDirectional(
                            top: 0,
                            end: 0,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.tertiary,
                                borderRadius: SLRadius.brPill,
                              ),
                              child: Text(
                                context.t('badge_new'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
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
