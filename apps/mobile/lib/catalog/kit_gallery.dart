/// W4f — the in-app kit gallery: the debug-only `/__gallery` route (the
/// Widgetbook substitute — see catalog_app.dart for the standalone variant).
///
/// NOT user surface: the route is registered only when `!kReleaseMode`
/// (app.dart) and linked from NOTHING. Open it in a debug run by pushing the
/// path — e.g. set `initialLocation: '/__gallery'` temporarily, or call
/// `context.go('/__gallery')` from the DevTools evaluator.
///
/// Renders the shared-kit catalog — buttons in states, TriStateChips,
/// CountStepper, QuantityInput, StreakBadge, CompletionRing,
/// LeaderboardBandCard, AppCard/SectionHeader, the illustrated states,
/// OfflineBanner, Skeleton, SLGeometricTexture (plain + over the hero
/// gradient) — with a local light/dark toggle so a designer can flip modes
/// without touching the profile. The toggle is a local `Theme` override;
/// the surrounding app is untouched.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/design_tokens.dart';
import '../design/phosphor_icons.dart';
import '../design/texture.dart';
import '../features/amal/amal_widgets.dart';
import '../features/shared/widgets.dart';
import '../l10n/app_strings.dart';
import '../models/leaderboard.dart';
import '../state/remote_state.dart' show leaderboardMeProvider;

class KitGalleryScreen extends StatefulWidget {
  const KitGalleryScreen({super.key});

  @override
  State<KitGalleryScreen> createState() => _KitGalleryScreenState();
}

class _KitGalleryScreenState extends State<KitGalleryScreen> {
  bool _dark = false;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark ? buildSunnahDarkTheme() : buildSunnahLightTheme(),
      child: Builder(
        // Builder so the Scaffold itself resolves against the override.
        builder: (context) => Scaffold(
          appBar: AppBar(
            leading: const BackButton(),
            title: const Text('কিট গ্যালারি /__gallery'),
            actions: [
              IconButton(
                tooltip: 'Light / Dark',
                icon: Icon(
                  _dark
                      ? PhosphorIconsRegular.sun
                      : PhosphorIconsRegular.moonStars,
                ),
                onPressed: () => setState(() => _dark = !_dark),
              ),
            ],
          ),
          // Material re-establishes DefaultTextStyle from the overridden
          // theme — bare Text below follows the toggle too.
          body: Material(
            type: MaterialType.transparency,
            child: ListView(
              padding: const EdgeInsets.all(SLSpacing.s16),
              children: [
                _GallerySection(
                  title: 'Buttons — states',
                  child: Wrap(
                    spacing: SLSpacing.s12,
                    runSpacing: SLSpacing.s12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: Text(S.tr(Lang.bn, 'ok')),
                      ),
                      FilledButton(
                        onPressed: null,
                        child: Text(S.tr(Lang.bn, 'ok')),
                      ),
                      FilledButton.tonal(
                        onPressed: () {},
                        child: Text(S.tr(Lang.bn, 'next')),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: Text(S.tr(Lang.bn, 'cancel')),
                      ),
                      OutlinedButton(
                        onPressed: null,
                        child: Text(S.tr(Lang.bn, 'cancel')),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: Text(S.tr(Lang.bn, 'see_all')),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(PhosphorIconsRegular.arrowClockwise),
                      ),
                      const IconButton(
                        onPressed: null,
                        icon: Icon(PhosphorIconsRegular.arrowClockwise),
                      ),
                    ],
                  ),
                ),
                _GallerySection(
                  title: 'TriStateChips — জামাতে / একা / কাযা',
                  child: _TriStateDemo(),
                ),
                _GallerySection(
                  title: 'CountStepper + QuantityInput',
                  child: Column(
                    children: [
                      _CountStepperDemo(),
                      const SizedBox(height: SLSpacing.s12),
                      _QuantityDemo(),
                    ],
                  ),
                ),
                _GallerySection(
                  title: 'StreakBadge + CompletionRing',
                  child: Wrap(
                    spacing: SLSpacing.s16,
                    runSpacing: SLSpacing.s12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      StreakBadge(days: 7),
                      StreakBadge(days: 21),
                      CompletionRing(pct: 80, label: 'নামাজ'),
                      CompletionRing(pct: 45, label: 'কুরআন'),
                      CompletionRing(pct: 100, label: 'যিকর'),
                    ],
                  ),
                ),
                _GallerySection(
                  title: 'LeaderboardBandCard (banded)',
                  child: ProviderScope(
                    overrides: [
                      leaderboardMeProvider.overrideWith(
                        (ref) async => const LeaderboardMe(
                          band: LeaderboardBand.top10,
                          myPoints: 312,
                          windowDays: 30,
                        ),
                      ),
                    ],
                    child: const LeaderboardBandCard(),
                  ),
                ),
                _GallerySection(
                  title: 'Cards + SectionHeader',
                  child: Column(
                    children: [
                      SectionHeader(
                        S.tr(Lang.bn, 'prayer_schedule'),
                        icon: PhosphorIconsRegular.clock,
                      ),
                      AppCard(
                        child: Text(S.tr(Lang.bn, 'most_used_empty')),
                      ),
                    ],
                  ),
                ),
                _GallerySection(
                  title: 'States — illustrated empty / error / offline',
                  child: Column(
                    children: [
                      EmptyState(
                        message: S.tr(Lang.bn, 'support_empty'),
                        icon: PhosphorIconsRegular.headset,
                        actionLabel: S.tr(Lang.bn, 'support_new_thread'),
                        onAction: () {},
                      ),
                      const SizedBox(height: SLSpacing.s8),
                      ErrorState(
                        message: S.tr(Lang.bn, 'error_generic'),
                        onRetry: () {},
                      ),
                      const SizedBox(height: SLSpacing.s12),
                      OfflineBanner(
                        fetchedAt: DateTime.now().subtract(
                          const Duration(minutes: 5),
                        ),
                        // Pinned so the ago-label doesn't drift while a
                        // designer reads the panel.
                        now: DateTime.now(),
                      ),
                    ],
                  ),
                ),
                _GallerySection(
                  title: 'Skeleton',
                  child: const Skeleton(height: 56, count: 2),
                ),
                _GallerySection(
                  title: 'SLGeometricTexture — hero gradient (5%)',
                  child: Container(
                    height: 120,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [SLColors.primary, SLColors.primaryDeep],
                      ),
                      borderRadius:
                          BorderRadius.all(Radius.circular(SLRadius.lg)),
                    ),
                    child: const Stack(
                      children: [
                        SLGeometricTexture(),
                        Center(
                          child: Text(
                            'আজকের ওয়াক্ত',
                            style: TextStyle(
                              fontFamily: kAppFontFamily,
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: SLColors.lightPrimaryForeground,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _GallerySection(
                  title: 'SLGeometricTexture — inspection (25% on soft)',
                  child: Container(
                    height: 120,
                    decoration: BoxDecoration(
                      color: _dark
                          ? SLColors.darkPrimarySoft
                          : SLColors.lightPrimarySoft,
                      borderRadius:
                          BorderRadius.all(Radius.circular(SLRadius.lg)),
                    ),
                    child: const SLGeometricTexture(opacity: 0.25),
                  ),
                ),
                const SizedBox(height: SLSpacing.s32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GallerySection extends StatelessWidget {
  const _GallerySection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SLSpacing.s24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: SLRadius.brPill,
            ),
            child: Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: SLSpacing.s12),
          child,
        ],
      ),
    );
  }
}

class _TriStateDemo extends StatefulWidget {
  @override
  State<_TriStateDemo> createState() => _TriStateDemoState();
}

class _TriStateDemoState extends State<_TriStateDemo> {
  String? _value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TriStateChips(
          value: _value,
          labels: TriStateLabels(
            jamaat: S.tr(Lang.bn, 'amal_jamaat'),
            alone: S.tr(Lang.bn, 'amal_alone'),
            qaza: S.tr(Lang.bn, 'amal_qaza'),
          ),
          onChanged: (v) => setState(() => _value = v),
        ),
        const SizedBox(height: SLSpacing.s8),
        TriStateChips(
          value: 'jamaat',
          enabled: false,
          labels: TriStateLabels(
            jamaat: S.tr(Lang.bn, 'amal_jamaat'),
            alone: S.tr(Lang.bn, 'amal_alone'),
            qaza: S.tr(Lang.bn, 'amal_qaza'),
          ),
          onChanged: (_) {},
        ),
      ],
    );
  }
}

class _CountStepperDemo extends StatefulWidget {
  @override
  State<_CountStepperDemo> createState() => _CountStepperDemoState();
}

class _CountStepperDemoState extends State<_CountStepperDemo> {
  int _value = 40;

  @override
  Widget build(BuildContext context) {
    return CountStepper(
      value: _value,
      target: 100,
      unit: 'বার',
      quickCount: 100,
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

class _QuantityDemo extends StatefulWidget {
  @override
  State<_QuantityDemo> createState() => _QuantityDemoState();
}

class _QuantityDemoState extends State<_QuantityDemo> {
  double _value = 0.5;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'তিলাওয়াত (লক্ষ্য: ১ পৃষ্ঠা)',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        QuantityInput(
          value: _value,
          target: 1,
          unit: 'পৃষ্ঠা',
          onChanged: (v) => setState(() => _value = v),
        ),
      ],
    );
  }
}
