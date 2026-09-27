/// Bengali numeral conversion — mirrors src/lib/calendars.ts `toBn()`.
const List<String> kBnDigits = [
  '০',
  '১',
  '২',
  '৩',
  '৪',
  '৫',
  '৬',
  '৭',
  '৮',
  '৯',
];

/// Convert any number or numeric string to Bengali digits: 123 → ১২৩.
String toBn(Object value) {
  return value.toString().replaceAllMapped(
    RegExp(r'[0-9]'),
    (m) => kBnDigits[int.parse(m.group(0)!)],
  );
}

/// Digit formatter that follows the app language.
String fmtNum(Object value, {bool bengali = true}) =>
    bengali ? toBn(value) : value.toString();

/// Two-digit zero-padded key fragment in Bengali digits (e.g. 5 → ০৫).
String pad2Bn(int n) => toBn(n.toString().padLeft(2, '0'));
