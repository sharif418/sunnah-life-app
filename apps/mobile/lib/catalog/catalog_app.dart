/// Component catalog — the Widgetbook substitute (run with:
/// `flutter run -t lib/catalog/catalog_app.dart`). Lists every custom
/// component in BOTH themes + LTR/RTL, so visual review needs no tooling.
///
/// Decision note: the task mandates a lean pubspec (Widgetbook adds ~40
/// transitive deps and pins conflicting build/analysis versions in this
/// sandbox). This hand-rolled catalog keeps the same capability — a
/// browsable gallery of every custom widget, light + dark — at zero
/// dependency cost.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../core/bn_digits.dart';
import '../core/date_keys.dart';
import '../core/prayer_engine.dart';
import '../design/design_tokens.dart';
import '../features/amal/amal_widgets.dart';
import '../features/home/home_sections.dart';
import '../features/shared/widgets.dart';
import '../l10n/app_strings.dart';
import '../models/domain.dart';
import '../state/prayer_state.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const CatalogApp());
}

class _CatalogState extends StatefulWidget {
  const _CatalogState();

  @override
  State<_CatalogState> createState() => _CatalogStateState();
}

class _CatalogStateState extends State<_CatalogState> {
  ThemeMode _mode = ThemeMode.light;
  bool _rtl = false;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunnah Life — Component Catalog',
      debugShowCheckedModeBanner: false,
      theme: buildSunnahLightTheme(),
      darkTheme: buildSunnahDarkTheme(),
      themeMode: _mode,
      builder: (context, child) => Directionality(
        textDirection: _rtl ? TextDirection.rtl : TextDirection.ltr,
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('সুন্নাহ লাইফ — কম্পোনেন্ট ক্যাটালগ'),
            actions: [
              IconButton(
                tooltip: 'Light / Dark',
                icon: Icon(
                  _mode == ThemeMode.light
                      ? Icons.dark_mode_outlined
                      : Icons.light_mode_outlined,
                ),
                onPressed: () => setState(
                  () => _mode = _mode == ThemeMode.light
                      ? ThemeMode.dark
                      : ThemeMode.light,
                ),
              ),
              IconButton(
                tooltip: 'RTL',
                icon: const Icon(Icons.swap_horiz),
                isSelected: _rtl,
                onPressed: () => setState(() => _rtl = !_rtl),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.all(SLSpacing.s16),
            children: [
              _CatalogSection(
                title: 'Buttons & Chips',
                children: [
                  _WrapRow(
                    children: [
                      _P(
                        'FilledButton',
                        child: FilledButton(
                          onPressed: () {},
                          child: Text('প্রাইমারি'),
                        ),
                      ),
                      _P(
                        'OutlinedButton',
                        child: OutlinedButton(
                          onPressed: () {},
                          child: Text('সেকেন্ডারি'),
                        ),
                      ),
                      _P(
                        'TextButton',
                        child: TextButton(
                          onPressed: () {},
                          child: Text('টেক্সট'),
                        ),
                      ),
                      _P('Chip', child: Chip(label: Text('চিপ'))),
                      _P(
                        'ActionChip',
                        child: ActionChip(
                          avatar: Icon(Icons.grid_view_outlined, size: 18),
                          label: Text('মাসের গ্রিড'),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              _CatalogSection(
                title: 'TriStateChips (জামাতে / একা / কাযা)',
                children: [
                  _TriStateDemo(),
                  SizedBox(height: SLSpacing.s8),
                  _TriStateDemo(initial: 'jamaat'),
                  SizedBox(height: SLSpacing.s8),
                  _TriStateDemo(enabled: false),
                ],
              ),
              _CatalogSection(
                title: 'AmalToggle',
                children: [
                  _AmalToggleDemo(),
                  SizedBox(height: SLSpacing.s8),
                  _AmalToggleDemo(initial: true),
                ],
              ),
              _CatalogSection(
                title: 'CountStepper (quick-১০০)',
                children: [_CountStepperDemo()],
              ),
              _CatalogSection(
                title: 'QuantityInput (tilawat)',
                children: [_QuantityDemo()],
              ),
              _CatalogSection(
                title: 'HeatmapCell (0 / 0.5 / 1 / today / locked)',
                children: [_HeatmapDemo()],
              ),
              _CatalogSection(
                title: 'StreakBadge',
                children: [
                  _WrapRow(
                    children: [
                      _P('7 দিন', child: StreakBadge(days: 7)),
                      _P('21 দিন', child: StreakBadge(days: 21)),
                      _P('0', child: StreakBadge(days: 0)),
                    ],
                  ),
                ],
              ),
              _CatalogSection(
                title: 'CompletionRing',
                children: [
                  _WrapRow(
                    children: [
                      _P(
                        'নামাজ ৮০%',
                        child: CompletionRing(pct: 80, label: 'নামাজ'),
                      ),
                      _P(
                        'কুরআন ৪৫%',
                        child: CompletionRing(pct: 45, label: 'কুরআন'),
                      ),
                      _P(
                        'যিকর ১০০%',
                        child: CompletionRing(pct: 100, label: 'যিকর'),
                      ),
                    ],
                  ),
                ],
              ),
              _CatalogSection(
                title: 'States (empty / error / skeleton)',
                children: [
                  EmptyState(
                    message: 'এখনো কিছু নেই',
                    icon: Icons.inbox_outlined,
                  ),
                  SizedBox(height: SLSpacing.s8),
                  ErrorState(
                    message: 'কিছু একটা সমস্যা হয়েছে',
                    onRetry: () {},
                  ),
                  SizedBox(height: SLSpacing.s8),
                  Skeleton(height: 56, count: 2),
                ],
              ),
              _CatalogSection(
                title: 'Cards & Headers',
                children: [
                  SectionHeader(
                    'আজকের সময়সূচি',
                    icon: Icons.schedule_outlined,
                  ),
                  AppCard(
                    child: Text(
                      'AppCard — ক্রিম ব্যাকগ্রাউন্ডে সাদা কার্ড, ১৬px রেডিয়াস',
                    ),
                  ),
                  SizedBox(height: SLSpacing.s8),
                  SyncBadge(),
                ],
              ),
              _CatalogSection(
                title: 'CountdownRingHero (C-W4b — ওয়াক্ত রিং)',
                children: [_RingHeroDemo()],
              ),
              _CatalogSection(
                title: 'Bengali numerals (toBn)',
                children: [_BnDigitsDemo()],
              ),
              SizedBox(height: SLSpacing.s32),
            ],
          ),
        ),
      ),
    );
  }
}

class CatalogApp extends StatelessWidget {
  const CatalogApp({super.key});

  @override
  Widget build(BuildContext context) => const _CatalogState();
}

class _CatalogSection extends StatelessWidget {
  const _CatalogSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

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
          ...children,
        ],
      ),
    );
  }
}

class _WrapRow extends StatelessWidget {
  const _WrapRow({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: SLSpacing.s12,
    runSpacing: SLSpacing.s12,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: children,
  );
}

class _P extends StatelessWidget {
  const _P(this.label, {required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      child,
      const SizedBox(height: 4),
      Text(
        label,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
      ),
    ],
  );
}

class _TriStateDemo extends StatefulWidget {
  const _TriStateDemo({this.initial, this.enabled = true});
  final String? initial;
  final bool enabled;

  @override
  State<_TriStateDemo> createState() => _TriStateDemoState();
}

class _TriStateDemoState extends State<_TriStateDemo> {
  late String? _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return TriStateChips(
      value: _value,
      enabled: widget.enabled,
      labels: TriStateLabels(
        jamaat: S.tr(Lang.bn, 'amal_jamaat'),
        alone: S.tr(Lang.bn, 'amal_alone'),
        qaza: S.tr(Lang.bn, 'amal_qaza'),
      ),
      onChanged: (v) => setState(() => _value = v),
    );
  }
}

class _AmalToggleDemo extends StatefulWidget {
  const _AmalToggleDemo({this.initial = false});
  final bool initial;

  @override
  State<_AmalToggleDemo> createState() => _AmalToggleDemoState();
}

class _AmalToggleDemoState extends State<_AmalToggleDemo> {
  late bool _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'সকালের মাসনূন আযকার',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        AmalToggle(value: _value, onChanged: (v) => setState(() => _value = v)),
      ],
    );
  }
}

class _CountStepperDemo extends StatefulWidget {
  const _CountStepperDemo();

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
  const _QuantityDemo();

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

class _HeatmapDemo extends StatelessWidget {
  const _HeatmapDemo();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        HeatmapCell(points: 0),
        HeatmapCell(points: 0.5),
        HeatmapCell(points: 1),
        HeatmapCell(points: 0, isToday: true),
        HeatmapCell(points: 1, locked: true),
      ],
    );
  }
}

/// C-W4b ring hero with a REAL Dhaka prayer bundle computed at build time —
/// the arc + HH:MM:SS snapshot of "now" (the live screen ticks them via
/// prayerProvider's per-second state).
class _RingHeroDemo extends StatelessWidget {
  const _RingHeroDemo();

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final times = PrayerEngine.compute(
      dateKey(now),
      lat: 23.8103,
      lng: 90.4125,
      tz: 6.0,
      method: CalcMethod.karachi,
      madhhab: Madhhab.hanafi,
    );
    final nowMinutes = now.hour * 60.0 + now.minute + now.second / 60.0;
    final (nextKey, minsToNext) = PrayerEngine.nextPrayer(times, nowMinutes);
    return CountdownRingHero(
      prayer: PrayerNow(
        dateKey: dateKey(now),
        times: times,
        nowMinutes: nowMinutes,
        currentWaqt: PrayerEngine.currentWaqt(times, nowMinutes),
        nextKey: nextKey,
        minutesToNext: minsToNext,
        forbiddenLabel: null,
        postPrayerKey: null,
      ),
      lang: Lang.bn,
      bn: true,
      onShowSchedule: () {},
    );
  }
}

class _BnDigitsDemo extends StatelessWidget {
  const _BnDigitsDemo();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: SLSpacing.s12,
      runSpacing: SLSpacing.s8,
      children: [
        for (final v in [0, 5, 19, 100, 1446, 3.75])
          Text(
            toBn(v),
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
          ),
      ],
    );
  }
}
