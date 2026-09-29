/// ইলম — knowledge hub grid with the 8 content apps.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design/design_tokens.dart';
import '../shared/global_header.dart';
import '../shared/widgets.dart';

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
        icon: Icons.school_outlined,
        title: context.t('ilm_courses'),
        route: '/ilm/courses',
      ),
      _IlmEntry(
        icon: Icons.quiz_outlined,
        title: context.t('ilm_quizzes'),
        route: '/ilm/quizzes',
      ),
      _IlmEntry(
        icon: Icons.wifi_tethering_outlined,
        title: context.t('ilm_live_quiz'),
        route: '/ilm/live-quiz',
      ),
      _IlmEntry(
        icon: Icons.menu_book_outlined,
        title: context.t('ilm_quran'),
        route: '/ilm/quran',
      ),
      _IlmEntry(
        icon: Icons.spa_outlined,
        title: context.t('ilm_adhkar'),
        route: '/ilm/adhkar',
      ),
      _IlmEntry(
        icon: Icons.front_hand_outlined,
        title: context.t('ilm_duas'),
        route: '/ilm/duas',
      ),
      _IlmEntry(
        icon: Icons.brightness_7_outlined,
        title: context.t('ilm_names99'),
        route: '/ilm/names99',
      ),
      _IlmEntry(
        icon: Icons.child_care_outlined,
        title: context.t('ilm_baby_names'),
        route: '/ilm/islamic-names',
      ),
      _IlmEntry(
        icon: Icons.favorite_outline,
        title: context.t('ilm_iman_branches'),
        route: '/ilm/iman-branches',
      ),
      _IlmEntry(
        icon: Icons.wb_twilight_outlined,
        title: context.t('ilm_sunnahs'),
        route: '/ilm/sunnahs',
        badge: _sunnahsNew,
      ),
      _IlmEntry(
        icon: Icons.article_outlined,
        title: context.t('ilm_articles'),
        route: '/ilm/articles',
      ),
    ];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            SLSpacing.s16,
            SLSpacing.s8,
            SLSpacing.s16,
            SLSpacing.s24,
          ),
          children: [
            // C-W4a: the shared global header (logo, location, triple
            // calendar, notification/reminder/profile, sync badge).
            const GlobalHeader(),
            Text(
              context.t('tab_ilm'),
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: SLSpacing.s16),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: SLSpacing.s12,
                crossAxisSpacing: SLSpacing.s12,
                // 1.3 — Hind Siliguri's real Bengali metrics wrap the longest
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
