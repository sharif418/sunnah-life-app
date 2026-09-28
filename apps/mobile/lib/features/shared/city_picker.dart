/// City picker sheet — all 64 BD districts + international cities, with
/// Bengali/English search and a GPS option (manual coordinates fallback).
library;

import 'package:flutter/material.dart';

import '../../core/cities.dart';
import '../../design/design_tokens.dart';
import '../../l10n/app_strings.dart';
import 'widgets.dart';

/// Opens the city picker and returns the chosen [CityEntry], or null.
Future<CityEntry?> showCityPicker(BuildContext context) {
  return showModalBottomSheet<CityEntry>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const _CityPickerSheet(),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final query = _query.trim().toLowerCase();
    final bd = kCities.where((c) => c.isBd).toList();
    final intl = kCities.where((c) => !c.isBd).toList();
    List<CityEntry> filtered(String q, List<CityEntry> src) => q.isEmpty
        ? src
        : src
              .where(
                (c) =>
                    c.nameBn.contains(_query.trim()) ||
                    c.nameEn.toLowerCase().contains(q),
              )
              .toList();

    Widget tile(CityEntry c) {
      final lang = context.lang;
      return SizedBox(
        height: SLSpacing.minTapTarget + 8,
        child: ListTile(
          title: Text(c.nameBn, style: theme.textTheme.bodyLarge),
          subtitle: Text(
            '${c.nameEn} — ${c.isBd ? S.tr(lang, 'country_bd') : S.tr(lang, 'country_abroad')} · UTC${c.tz >= 0 ? '+' : ''}${c.tz}',
            style: theme.textTheme.bodySmall,
          ),
          dense: true,
          onTap: () => Navigator.of(context).pop(c),
        ),
      );
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      builder: (context, scrollController) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: SLSpacing.s16),
        child: Column(
          children: [
            Text(
              context.t('city_picker_title'),
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: SLSpacing.s12),
            TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: context.t('onb_city_search'),
                prefixIcon: const Icon(Icons.search),
                isDense: true,
              ),
            ),
            const SizedBox(height: SLSpacing.s8),
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  if (filtered(query, bd).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SLSpacing.s4,
                        horizontal: SLSpacing.s4,
                      ),
                      child: Text(
                        context.t('country_bd'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...filtered(query, bd).map(tile),
                  ],
                  if (filtered(query, intl).isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: SLSpacing.s4,
                        horizontal: SLSpacing.s4,
                      ),
                      child: Text(
                        context.t('country_intl'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                    ...filtered(query, intl).map(tile),
                  ],
                  if (filtered(query, bd).isEmpty &&
                      filtered(query, intl).isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(SLSpacing.s32),
                      child: Text(
                        context.t('city_no_match'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
