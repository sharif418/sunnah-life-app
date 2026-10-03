/// "৩ অক্টোবর · রাত ৮:৩০" — a server timestamp (UTC ISO) in the device's
/// local time, Bengali digits and day-part when the app speaks Bengali.
/// Empty for an unparseable string (a broken row never breaks a card).
library;

import 'package:flutter/widgets.dart';

import '../../core/bn_digits.dart';
import '../../core/calendars.dart' show formatTimeBn;
import 'widgets.dart' show L10nX;

String whenBn(BuildContext context, String iso) {
  final t = DateTime.tryParse(iso)?.toLocal();
  if (t == null) return '';
  final bn = context.isBn;
  return '${bn ? toBn(t.day) : t.day} ${context.t('month_${t.month}')} · '
      '${formatTimeBn(t.hour * 60.0 + t.minute, bengali: bn)}';
}
