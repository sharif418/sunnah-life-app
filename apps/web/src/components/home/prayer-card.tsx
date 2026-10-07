"use client";

// The home's prayer block (2026-10-07 redesign, approved with the
// Foundation — the same design as the app's sun_arc_card / schedule_card):
//
//   HomeDateRow   — the Hijri date first, weekday · Gregorian · Bangla and
//                   the time beneath, the city beside it;
//   SunArcCard    — the sun (or moon) on its arc, the running waqt and the
//                   next, the forbidden window while it lasts, the time left,
//                   today's five from the diary, the link to the schedule;
//   ScheduleCard  — five fard waqts with start–end, the nafl windows, the
//                   forbidden times; Friday → জুমা, Ramadan → Sehri/Iftar.

import * as React from "react";
import { Ban, ChevronDown, ChevronRight, Clock, MapPin, Moon } from "lucide-react";
import { useApp } from "@/lib/store";
import { api } from "@/lib/api";
import { translate } from "@/lib/i18n";
import { useHijriAdjust } from "@/hooks/use-hijri-adjust";
import { useNow, usePrayerDay } from "@/components/home/prayer-hooks";
import { LocationSheet, cityLabelBn } from "@/components/home/city-sheet";
import { banglaDate, dateKey, formatTimeBn, gregorianBn, hijriDate, toBn, weekdayBn } from "@/lib/calendars";
import { computeDayCard, fardSpans, naflWindows, FARD, type DayCardState, type FardKey } from "@/lib/day-card";
import { forbiddenWindows } from "@/lib/prayer-times";
import { PRAYER_LABELS_BN, type AmalValue, type PrayerTimes } from "@/types/domain";
import { cn } from "@/lib/utils";

const minutesOf = (d: Date) => d.getHours() * 60 + d.getMinutes() + d.getSeconds() / 60;

/** "১১:৪৬" — the clock without the day part. */
function clockOnly(minutes: number): string {
  const m = ((Math.round(minutes) % 1440) + 1440) % 1440;
  const h = Math.floor(m / 60) % 12 || 12;
  return toBn(`${h}:${String(m % 60).padStart(2, "0")}`);
}

function timeLeft(minutes: number): string {
  const h = Math.floor(minutes / 60);
  const m = minutes % 60;
  return `${h ? `${toBn(h)} ঘণ্টা ` : ""}${toBn(m)} মিনিট বাকি`;
}

function label(key: FardKey | "sunrise" | "ishraq" | "duha" | "tahajjud", friday: boolean): string {
  return key === "dhuhr" && friday ? "জুমা" : PRAYER_LABELS_BN[key];
}

const FORBIDDEN_SHORT: Record<string, string> = { sunrise: "সূর্যোদয়", zawal: "যাওয়াল", sunset: "সূর্যাস্ত" };

/** Shared by the card and the schedule: today, Friday, Ramadan. */
function useDay() {
  const now = useNow(1000);
  const { times } = usePrayerDay(now);
  const hijriAdjust = useHijriAdjust();
  const hijri = hijriDate(now, hijriAdjust);
  return {
    now,
    times,
    state: computeDayCard(times, minutesOf(now)),
    friday: now.getDay() === 5,
    ramadan: hijri.monthIndex === 8,
    hijri,
  };
}

// ── date row ───────────────────────────────────────────────────────────────

export function HomeDateRow() {
  const now = useNow(30_000);
  const hijriAdjust = useHijriAdjust();
  const city = useApp((s) => s.profile.city);
  const [sheetOpen, setSheetOpen] = React.useState(false);
  const hijri = hijriDate(now, hijriAdjust);
  return (
    <div className="space-y-0.5">
      <div className="flex items-center gap-3">
        <h1 className="flex min-w-0 flex-1 items-center gap-2 text-[17px] font-bold leading-snug sm:text-xl">
          <Moon className="size-[18px] shrink-0 text-gold" aria-hidden />
          <span>{hijri.formatted} হিজরি</span>
        </h1>
        <button
          type="button"
          onClick={() => setSheetOpen(true)}
          aria-label="শহর বদলান"
          className="inline-flex h-11 max-w-[50%] shrink-0 items-center gap-1 rounded-full border border-border bg-card px-3 text-sm font-semibold hover:bg-muted"
        >
          <MapPin className="size-4 shrink-0 text-primary" aria-hidden />
          <span className="truncate">{cityLabelBn(city)}</span>
          <ChevronDown className="size-3.5 shrink-0 text-muted-foreground" aria-hidden />
        </button>
      </div>
      <p className="text-sm text-muted-foreground">
        {weekdayBn(now)} · {gregorianBn(now)} · {banglaDate(now).formatted}
        {/* the time, where there is room for it (phones show it in their bar) */}
        <span className="hidden sm:inline"> · এখন {formatTimeBn(minutesOf(now))}</span>
      </p>
      <LocationSheet open={sheetOpen} onOpenChange={setSheetOpen} />
    </div>
  );
}

// ── today's five from the diary ────────────────────────────────────────────

/** Today's salat values: this device's entries, plus the server's for a
 *  signed-in member (merged into the store, unsynced edits winning). */
function useTodaySalat(today: string): Partial<Record<FardKey, AmalValue>> {
  const user = useApp((s) => s.user);
  const amalCache = useApp((s) => s.amalCache);
  const outbox = useApp((s) => s.outbox);
  const hydrate = useApp((s) => s.hydrateFromServer);
  React.useEffect(() => {
    if (!user) return;
    let alive = true;
    api
      .amalEntries(today, today)
      .then((r) => alive && hydrate(r.entries))
      .catch(() => null);
    return () => {
      alive = false;
    };
  }, [user, today, hydrate]);
  return React.useMemo(() => {
    const out: Partial<Record<FardKey, AmalValue>> = {};
    for (const k of FARD) {
      const key = `${today}#salat_${k}`;
      const v = (outbox[key] ?? amalCache[key])?.value;
      if (typeof v === "string" && v) out[k] = v;
    }
    return out;
  }, [amalCache, outbox, today]);
}

// ── the sky ────────────────────────────────────────────────────────────────

function Sky({ s, times, friday }: { s: DayCardState; times: PrayerTimes; friday: boolean }) {
  const night = !s.isDay;
  const f = s.orbFraction;
  // the arc in a 358×168 box: 20 in from each side, horizon at 150
  const x = 179 - 159 * Math.cos(f * Math.PI);
  const y = Math.min(150 - 128 * Math.sin(f * Math.PI), 150 - 15); // seated on the horizon at the ends
  const nearNoon = s.isDay && Math.abs(f - 0.5) < 0.09;
  const tone = night
    ? "bg-[#173A2E] text-[#F7F4EC] dark:bg-[#0B1A14]"
    : "bg-primary-soft text-[#173A2E] dark:text-foreground";
  const sub = night ? "text-[#C9D6CE]" : "text-[#4E6258] dark:text-muted-foreground";
  const arc = night ? "rgba(246,236,216,0.35)" : "rgba(183,121,31,0.45)";
  const mosque = night ? "rgba(246,236,216,0.07)" : "rgba(31,77,61,0.08)";
  const nowLabel = s.current ? "এখন চলছে" : "এখন";
  const nowName = s.current ? label(s.current, friday) : "সূর্যোদয়ের পর";
  const nextLine = `${label(s.next, friday)} · ${formatTimeBn(times[s.next])}`;
  return (
    <div
      className={cn("relative h-[168px] overflow-hidden", tone)}
      role="img"
      aria-label={`${nowLabel} ${nowName}। পরবর্তী: ${nextLine}`}
    >
      <svg className="absolute inset-0 size-full" viewBox="0 0 358 168" preserveAspectRatio="none" aria-hidden>
        <path d="M20 150 A159 128 0 0 1 338 150" fill="none" stroke={arc} strokeWidth="1.6" strokeDasharray="4 5" vectorEffect="non-scaling-stroke" />
        <line x1="12" y1="150" x2="346" y2="150" stroke={arc} strokeWidth="1" vectorEffect="non-scaling-stroke" />
      </svg>
      <svg className="absolute bottom-[18px] left-1/2 -translate-x-1/2" width="180" height="76" viewBox="0 0 180 76" aria-hidden>
        <path
          d="M61 76 V42 Q61 16 90 4 Q119 16 119 42 V76 Z M31 76 V52 H53 V76 Z M127 76 V52 H149 V76 Z M11 76 V14 H19 V76 Z M161 76 V14 H169 V76 Z M14 14 V4 H16 V14 Z M164 14 V4 H166 V14 Z"
          fill={mosque}
        />
      </svg>
      {night
        ? [
            [11, 30],
            [22, 62],
            [34, 22],
            [66, 34],
            [79, 70],
            [89, 26],
            [55, 44],
            [17, 104],
          ].map(([px, py]) => (
            <span key={`${px}-${py}`} className="absolute size-[3px] rounded-full bg-[#F6ECD8]" style={{ left: `${px}%`, top: py }} aria-hidden />
          ))
        : null}
      <span className="absolute size-[30px]" style={{ left: `calc(${(x / 358) * 100}% - 15px)`, top: y - 15 }} aria-hidden>
        {night ? (
          <svg viewBox="0 0 30 30" className="size-full">
            <path d="M23 18.5A9.5 9.5 0 1 1 12 6.5a7.5 7.5 0 0 0 11 12z" fill="#F6ECD8" />
          </svg>
        ) : (
          <svg viewBox="0 0 30 30" className="size-full">
            <circle cx="15" cy="15" r="8" fill="#E8B04A" />
            <g stroke="#E8B04A" strokeWidth="1.8" strokeLinecap="round">
              <path d="M15 2v3M15 25v3M2 15h3M25 15h3M5.8 5.8l2.1 2.1M22.1 22.1l2.1 2.1M5.8 24.2l2.1-2.1M22.1 7.9l2.1-2.1" />
            </g>
          </svg>
        )}
      </span>
      {/* the narrow centred column the orb never crosses */}
      <div className="absolute left-1/2 top-[60px] w-[196px] -translate-x-1/2 text-center" aria-hidden>
        <p className={cn("text-xs", sub)}>{nowLabel}</p>
        <p className="truncate text-[26px] font-bold leading-tight">{nowName}</p>
        <p className="truncate text-sm font-semibold">
          <span className={sub}>পরবর্তী: </span>
          {nextLine}
        </p>
      </div>
      {nearNoon ? null : (
        <p className={cn("absolute inset-x-0 top-2 text-center text-xs", sub)} aria-hidden>
          মধ্যাহ্ন {clockOnly(times.dhuhr - 1)}
        </p>
      )}
      <p className={cn("absolute bottom-0.5 left-2.5 text-xs", sub)} aria-hidden>
        সূর্যোদয় {clockOnly(times.sunrise)}
      </p>
      <p className={cn("absolute bottom-0.5 right-2.5 text-xs", sub)} aria-hidden>
        সূর্যাস্ত {clockOnly(times.sunset)}
      </p>
    </div>
  );
}

// ── the card ───────────────────────────────────────────────────────────────

export function SunArcCard() {
  const { now, times, state: s, friday } = useDay();
  const nav = useApp((st) => st.nav);
  const today = dateKey(now);
  const salat = useTodaySalat(today);
  const nowMin = minutesOf(now);
  const name = s.current ? label(s.current, friday) : friday ? "জুমার অপেক্ষা" : "যোহরের অপেক্ষা";
  const range = s.current
    ? s.current === "isha"
      ? `${formatTimeBn(s.spanStart)} – ${formatTimeBn(s.spanEnd - 1)}`
      : `${formatTimeBn(s.spanStart)} – ${clockOnly(s.spanEnd - 1)}`
    : `সূর্যোদয় ${clockOnly(times.sunrise)} – ${label("dhuhr", friday)} ${clockOnly(times.dhuhr)}`;

  return (
    <section
      aria-label="নামাজের সময়"
      className="overflow-hidden rounded-[20px] border border-border bg-card shadow-lifted"
    >
      <Sky s={s} times={times} friday={friday} />
      {s.forbiddenKey ? (
        <div className="flex items-center gap-2 bg-alert-soft px-4 py-2.5 text-sm font-bold text-alert" role="status">
          <Ban className="size-[18px] shrink-0" aria-hidden />
          এখন নামাজ পড়া নিষেধ — {FORBIDDEN_SHORT[s.forbiddenKey]}, {formatTimeBn(s.forbiddenEnd!)} পর্যন্ত
        </div>
      ) : null}
      <div className="space-y-2.5 px-4 pb-4 pt-3.5">
        <div className="flex flex-wrap items-baseline justify-between gap-x-2">
          <p className="text-lg font-bold">{name}</p>
          <p className="text-[15px] text-muted-foreground">{range}</p>
        </div>
        <div
          className="h-2.5 overflow-hidden rounded-full bg-[#ECE6D8] dark:bg-[#22312A]"
          role="progressbar"
          aria-valuemin={0}
          aria-valuemax={100}
          aria-valuenow={Math.round(s.fraction * 100)}
          aria-label={`${name} — ${timeLeft(s.minutesLeft)}`}
        >
          <div className="h-full rounded-full bg-primary" style={{ width: `${s.fraction * 100}%` }} />
        </div>
        <div className="flex items-center gap-2">
          <span className="size-2.5 shrink-0 rounded-full bg-success" aria-hidden />
          <span className="flex-1 text-sm font-bold text-success">{s.current ? "চলমান" : "ইশরাক ও চাশতের সময়"}</span>
          <span className="text-[17px] font-bold">{timeLeft(s.minutesLeft)}</span>
        </div>
      </div>
      <button
        type="button"
        onClick={() => nav("amal")}
        className="grid w-full grid-cols-5 gap-1 border-t border-border px-1.5 py-2.5 text-start hover:bg-muted/40"
        aria-label="আজকের নামাজ — ডায়েরি খুলুন"
      >
        {FARD.map((k) => (
          <StripCell
            key={k}
            name={label(k, friday)}
            time={clockOnly(times[k])}
            value={salat[k]}
            started={nowMin >= times[k] || (k === "isha" && nowMin < times.fajr)}
            isNow={s.current === k}
          />
        ))}
      </button>
      <a
        href="#home-schedule"
        onClick={(e) => {
          e.preventDefault();
          document.getElementById("home-schedule")?.scrollIntoView({ behavior: "smooth", block: "start" });
        }}
        className="flex min-h-11 items-center justify-center gap-1 border-t border-border text-[15px] font-bold text-primary hover:bg-primary-soft"
      >
        সময়সূচি দেখুন <ChevronRight className="size-4 rtl:rotate-180" aria-hidden />
      </a>
    </section>
  );
}

function StripCell({
  name,
  time,
  value,
  started,
  isNow,
}: {
  name: string;
  time: string;
  value: AmalValue | undefined;
  started: boolean;
  isNow: boolean;
}) {
  const [mark, state] =
    value === "jamaat"
      ? [<span key="m" className="flex size-6 items-center justify-center rounded-full bg-success text-white">✓</span>, "জামাতে"]
      : value === "alone"
        ? [<span key="m" className="flex size-6 items-center justify-center rounded-full border-2 border-success text-xs font-bold text-success">✓</span>, "একা"]
        : value === "qaza"
          ? [
              <span key="m" className="flex size-6 items-center justify-center rounded-full border-2 border-[#B7791F] text-[#B7791F]">
                <Clock className="size-3" aria-hidden />
              </span>,
              "কাযা",
            ]
          : [
              <span
                key="m"
                className={cn(
                  "block size-6 rounded-full border-[1.5px]",
                  isNow ? "border-2 border-primary" : started ? "border-muted-foreground/60" : "border-muted-foreground/30"
                )}
              />,
              started ? "বাকি" : "",
            ];
  return (
    <span
      className={cn("flex flex-col items-center gap-0.5 rounded-xl py-1.5", isNow && "bg-primary-soft")}
      aria-label={`${name} ${time}${state ? ` · ${state}` : ""}`}
    >
      <span className={cn("text-sm font-semibold", isNow && "font-bold text-primary")}>{name}</span>
      <span className="text-xs text-muted-foreground">{time}</span>
      <span className="mt-1 flex justify-center">{mark}</span>
      <span className="h-4 text-[11px] text-muted-foreground">{state}</span>
    </span>
  );
}

// ── the schedule ───────────────────────────────────────────────────────────

export function ScheduleCard() {
  const { now, times, state: s, friday, ramadan } = useDay();
  const lang = useApp((st) => st.profile.language);
  const nowMin = minutesOf(now);
  const nafl = naflWindows(times);
  const windows = forbiddenWindows(times);
  return (
    <section id="home-schedule" aria-labelledby="home-schedule-h" className="scroll-mt-24 space-y-2">
      <h2 id="home-schedule-h" className="flex items-center gap-2 text-lg font-bold">
        <Clock className="size-5 text-primary" aria-hidden /> আজকের সময়সূচি
      </h2>
      <div className="overflow-hidden rounded-2xl border border-border bg-card">
        {ramadan ? (
          <p className="flex flex-wrap justify-center gap-x-3 gap-y-1 bg-gold-soft px-3 py-2.5 text-[15px] font-semibold">
            <span className="font-bold text-gold-text-foreground">রমজান</span>
            <span>সাহরির শেষ {formatTimeBn(times.fajr)}</span>
            <span>ইফতার {formatTimeBn(times.maghrib)}</span>
          </p>
        ) : null}
        <ol className="p-1">
          {fardSpans(times).map((w) => {
            const isNow = s.current === w.key;
            const isNext = !isNow && s.next === w.key;
            const past = !isNow && !isNext && w.key !== "isha" && nowMin >= w.end;
            const range =
              w.key === "isha"
                ? `${formatTimeBn(w.start)} – ${formatTimeBn(w.end - 1)}`
                : `${formatTimeBn(w.start)} – ${clockOnly(w.end - 1)}`;
            return (
              <li
                key={w.key}
                className={cn("flex min-h-[46px] items-center gap-2.5 rounded-xl px-3", isNow && "bg-primary-soft")}
                aria-current={isNow ? "true" : undefined}
              >
                <span className={cn("w-16 shrink-0 font-bold", past ? "text-muted-foreground/70" : isNow ? "text-primary" : "")}>
                  {label(w.key, friday)}
                </span>
                <span className={cn("flex flex-1 flex-wrap items-center gap-x-2 text-[15px]", past && "text-muted-foreground/70")}>
                  {range}
                  {isNow ? <span className="rounded-full bg-card px-2 py-px text-xs font-bold text-primary">এখন</span> : null}
                  {isNext ? (
                    <span className="rounded-full bg-gold-soft px-2 py-px text-xs font-bold text-gold-text-foreground">পরবর্তী</span>
                  ) : null}
                </span>
              </li>
            );
          })}
        </ol>
        <div className="grid grid-cols-4 gap-1 border-t border-border px-1 py-3 text-center">
          {(
            [
              ["সূর্যোদয়", clockOnly(times.sunrise)],
              ["ইশরাক", `${clockOnly(nafl.ishraq)} থেকে`],
              ["দুহা", `${clockOnly(nafl.duhaStart)}–${clockOnly(nafl.duhaEnd)}`],
              ["তাহাজ্জুদ", `${clockOnly(nafl.tahajjudStart)}–${clockOnly(nafl.tahajjudEnd - 1)}`],
            ] as const
          ).map(([n, v]) => (
            <div key={n} className="min-w-0 px-1">
              <p className="text-[13px] text-muted-foreground">{n}</p>
              <p className="truncate text-[13px] font-bold">{v}</p>
            </div>
          ))}
        </div>
        <div className="bg-alert-soft px-1.5 pb-3 pt-2.5 text-alert">
          <p className="flex items-center justify-center gap-1.5 pb-1.5 text-[13px] font-bold">
            <Ban className="size-4" aria-hidden /> নামাজ পড়া নিষেধ
          </p>
          <div className="grid grid-cols-3 gap-1 text-center">
            {windows.map((w) => (
              <div
                key={w.key}
                className={cn("rounded-lg py-1", s.forbiddenKey === w.key && "bg-alert/15")}
                aria-current={s.forbiddenKey === w.key ? "true" : undefined}
              >
                <p className={cn("text-[13px]", s.forbiddenKey === w.key && "font-bold")}>{FORBIDDEN_SHORT[w.key]}</p>
                <p className="truncate text-[13px] font-bold">
                  {clockOnly(w.from)}–{clockOnly(w.to)}
                </p>
              </div>
            ))}
          </div>
        </div>
      </div>
      <p className="text-center text-[11px] text-muted-foreground/80">{translate(lang, "home.offlineNote")}</p>
    </section>
  );
}
