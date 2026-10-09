/// How far, how long on foot, and which way — said the way people say it.
/// "২৪০ মিটার · হেঁটে ~৩ মিনিট · উত্তর-পূর্বে" (whole kilometres used to
/// show a mosque 300 m away as "০ কিমি"). Pure — unit tested.
library;

import 'bn_digits.dart';

/// Metres → "২৪০ মিটার" (to the 10 m) under 1 km, "১.৪ কিমি" under 10 km,
/// "১২ কিমি" beyond.
String distanceLabel(double metres, {bool bengali = true}) {
  String n(String s) => bengali ? toBn(s) : s;
  if (metres < 1000) {
    final m = ((metres / 10).round() * 10).clamp(10, 990);
    return '${n('$m')} ${bengali ? 'মিটার' : 'm'}';
  }
  final km = metres / 1000;
  final s = km < 10 ? km.toStringAsFixed(1) : km.round().toString();
  return '${n(s)} ${bengali ? 'কিমি' : 'km'}';
}

/// Walking time at ~80 m a minute (an unhurried pace), only where walking
/// is the answer (≤ 3 km); null beyond.
String? walkLabel(double metres, {bool bengali = true}) {
  if (metres > 3000) return null;
  final min = (metres / 80).ceil().clamp(1, 60);
  return bengali ? 'হেঁটে ~${toBn('$min')} মিনিট' : '~$min min walk';
}

/// A compass bearing (0 = north, clockwise) → one of eight Bengali
/// directions in the locative ("উত্তরে", "দক্ষিণ-পশ্চিমে").
String directionWord(double bearingDeg, {bool bengali = true}) {
  const bn = [
    'উত্তরে',
    'উত্তর-পূর্বে',
    'পূর্বে',
    'দক্ষিণ-পূর্বে',
    'দক্ষিণে',
    'দক্ষিণ-পশ্চিমে',
    'পশ্চিমে',
    'উত্তর-পশ্চিমে',
  ];
  const en = [
    'north',
    'north-east',
    'east',
    'south-east',
    'south',
    'south-west',
    'west',
    'north-west',
  ];
  final i = (((bearingDeg % 360) + 360) % 360 / 45).round() % 8;
  return (bengali ? bn : en)[i];
}
