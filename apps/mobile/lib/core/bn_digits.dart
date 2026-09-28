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

/// Parse user-typed digits into an int — accepts ASCII (`7`, `286`) and
/// Bengali (`৭`, `২৮৬`) numerals, trims surrounding whitespace, tolerates an
/// optional ASCII `+` sign. Returns null for anything else (mixed scripts,
/// empty, non-digits) so callers can surface an error instead of guessing.
int? parseBnDigits(String input) {
  final s = input.trim();
  if (s.isEmpty) return null;
  var value = 0;
  var seenDigit = false;
  var sawAscii = false;
  var sawBn = false;
  for (var i = 0; i < s.length; i++) {
    final code = s.codeUnitAt(i);
    final int digit;
    if (i == 0 && code == 0x2B) {
      // leading '+'
      continue;
    } else if (code >= 0x30 && code <= 0x39) {
      digit = code - 0x30;
      sawAscii = true;
    } else if (code >= 0x09E6 && code <= 0x09EF) {
      digit = code - 0x09E6;
      sawBn = true;
    } else {
      return null;
    }
    if (sawAscii && sawBn) return null; // '1৭' is a typo, never 17
    seenDigit = true;
    value = value * 10 + digit;
  }
  return seenDigit ? value : null;
}
