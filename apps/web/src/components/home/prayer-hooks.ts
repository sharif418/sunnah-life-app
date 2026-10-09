"use client";

// Shared prayer-day hooks — the ONE file intentionally shared between the
// home/ and more/ view folders (Home dashboard + More → নামাজের সেটিংস preview).

import { useEffect, useMemo, useState } from "react";
import { useApp } from "@/lib/store";
import { CITIES } from "@/lib/cities";
import { toBn } from "@/lib/calendars";
import { computePrayerTimes, nextPrayer } from "@/lib/prayer-times";
import type { PrayerConfig, PrayerKey } from "@/types/domain";

/** Ticking clock — updates every `intervalMs` (default 1s), cleaned up on unmount. */
export function useNow(intervalMs = 1000): Date {
  const [now, setNow] = useState<Date>(() => new Date());
  useEffect(() => {
    const id = setInterval(() => setNow(new Date()), intervalMs);
    return () => clearInterval(id);
  }, [intervalMs]);
  return now;
}

/** PrayerConfig derived from the store profile (city timezone when known). */
export function usePrayerConfig(): PrayerConfig {
  const profile = useApp((s) => s.profile);
  return useMemo(() => {
    const city = CITIES.find((c) => c.nameEn === profile.city);
    const tzOffsetHours = city?.tz ?? -new Date().getTimezoneOffset() / 60;
    return {
      lat: profile.lat,
      lng: profile.lng,
      city: profile.city,
      method: profile.method,
      madhhab: profile.madhhab,
      tzOffsetHours,
      adjust: profile.prayerAdjust ?? {},
    };
  }, [profile.city, profile.lat, profile.lng, profile.madhhab, profile.method, profile.prayerAdjust]);
}

/** "y-m-d" দিন-কি → dateParts (computePrayerTimes-এর ইনপুট)। */
function parseDayKey(key: string): { y: number; m: number; d: number } {
  const [y, m, d] = key.split("-").map(Number);
  return { y, m, d };
}

/** Today's full schedule + next-waqt info for a ticking `now`. */
export function usePrayerDay(now: Date) {
  const cfg = usePrayerConfig();
  // দিন-কি বদলালে তবেই দিনের সময়সূচি নতুন করে হিসাব হয় (সেকেন্ডে নয়)।
  const dayKey = `${now.getFullYear()}-${now.getMonth() + 1}-${now.getDate()}`;
  const times = useMemo(() => computePrayerTimes(parseDayKey(dayKey), cfg), [dayKey, cfg]);
  const next = useMemo(() => nextPrayer(now, cfg), [now, cfg]);
  return { cfg, times, next };
}

/** The six timeline rows (৫ ওয়াক্ত + সূর্যোদয়) in display order. */
export const SCHEDULE_ROWS: PrayerKey[] = ["fajr", "sunrise", "dhuhr", "asr", "maghrib", "isha"];
