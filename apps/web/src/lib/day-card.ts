// The home prayer card's arithmetic — the web port of the app's
// lib/core/day_card.dart (keep the two in step). Which fard waqt is running
// and until when, how much is left, where the sun (or moon) sits on the
// day's arc, and the forbidden window in force.
//
// A fard waqt ends where the NEXT begins, except Fajr, which ends at
// sunrise. Between sunrise and Dhuhr no fard runs (Ishraq and Duha time).

import { forbiddenWindows } from "@/lib/prayer-times";
import type { PrayerKey, PrayerTimes } from "@/types/domain";

export type FardKey = "fajr" | "dhuhr" | "asr" | "maghrib" | "isha";
export const FARD: FardKey[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

export interface WaqtSpan {
  key: FardKey;
  start: number;
  end: number; // Isha's end is past 1440
}

export function fardSpans(t: PrayerTimes): WaqtSpan[] {
  return [
    { key: "fajr", start: t.fajr, end: t.sunrise },
    { key: "dhuhr", start: t.dhuhr, end: t.asr },
    { key: "asr", start: t.asr, end: t.maghrib },
    { key: "maghrib", start: t.maghrib, end: t.isha },
    { key: "isha", start: t.isha, end: t.fajr + 1440 },
  ];
}

export interface DayCardState {
  current: FardKey | null;
  next: FardKey;
  spanStart: number;
  spanEnd: number;
  fraction: number;
  minutesLeft: number;
  isDay: boolean;
  orbFraction: number;
  forbiddenKey: "sunrise" | "zawal" | "sunset" | null;
  forbiddenEnd: number | null;
}

export function computeDayCard(t: PrayerTimes, now: number): DayCardState {
  const n = now < t.fajr ? now + 1440 : now;
  const cur = fardSpans(t).find((s) => n >= s.start && n < s.end) ?? null;
  const start = cur ? cur.start : t.sunrise;
  const end = cur ? cur.end : t.dhuhr;
  const next: FardKey = cur ? FARD[(FARD.indexOf(cur.key) + 1) % FARD.length] : "dhuhr";
  const at = cur ? n : now;
  const fraction = Math.min(1, Math.max(0, (at - start) / (end - start)));
  const minutesLeft = Math.max(0, Math.min(1440, Math.ceil(end - at)));
  const isDay = now >= t.sunrise && now <= t.sunset;
  const dayLen = t.sunset - t.sunrise;
  const orb = isDay ? (now - t.sunrise) / dayLen : ((now - t.sunset + 1440) % 1440) / (1440 - dayLen);
  const f = forbiddenWindows(t).find((w) => now >= w.from && now < w.to) ?? null;
  return {
    current: cur?.key ?? null,
    next,
    spanStart: start,
    spanEnd: end,
    fraction,
    minutesLeft,
    isDay,
    orbFraction: Math.min(1, Math.max(0, orb)),
    forbiddenKey: f?.key ?? null,
    forbiddenEnd: f?.to ?? null,
  };
}

/** When the nafl prayers CAN be prayed: Duha until the zawal window,
 *  Tahajjud until Fajr. */
export function naflWindows(t: PrayerTimes) {
  const zawalStart = forbiddenWindows(t)[1].from;
  return { ishraq: t.ishraq, duhaStart: t.duha, duhaEnd: zawalStart, tahajjudStart: t.tahajjud, tahajjudEnd: t.fajr };
}

export type { PrayerKey };
