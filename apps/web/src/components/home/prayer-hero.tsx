"use client";

// হোম হিরো — তারিখ-ঘড়ি হেডার + পরবর্তী ওয়াক্ত কাউন্টডাউন + আজকের সময়সূচি।

import * as React from "react";
import { Button } from "@/components/ui/button";
import { LocationSheet, cityLabelBn } from "@/components/home/city-sheet";
import { useNow, usePrayerDay, formatCountdownBn, SCHEDULE_ROWS } from "@/components/home/prayer-hooks";
import { useApp } from "@/lib/store";
import { useHijriAdjust } from "@/hooks/use-hijri-adjust";
import { banglaDate, gregorianBn, hijriDate, timePeriodBnFromMinutes, toBn, formatTimeBn, dateKey } from "@/lib/calendars";
import { PRAYER_LABELS_BN } from "@/types/domain";
import type { PrayerKey } from "@/types/domain";
import { MapPin, ChevronDown, Sun, MoonStar } from "lucide-react";
import { cn } from "@/lib/utils";
import { translate } from "@/lib/i18n";

export function PrayerHero() {
  const now = useNow(1000);
  const { times, next } = usePrayerDay(now);
  const city = useApp((s) => s.profile.city);
  const lang = useApp((s) => s.profile.language);
  const t = (k: string) => translate(lang, k);
  const [sheetOpen, setSheetOpen] = React.useState(false);
  // হিজরি তারিখ: অ্যাডমিন + সদস্যের নিজের ±দিন সংশোধন
  const hijriAdjust = useHijriAdjust();

  const bnDate = banglaDate(now);
  const hijri = hijriDate(now, hijriAdjust);
  const nextLabel = PRAYER_LABELS_BN[next.key];
  const countdown = formatCountdownBn(next.at.getTime() - now.getTime());

  const clock = React.useMemo(() => {
    const h24 = now.getHours();
    const h12 = h24 % 12 === 0 ? 12 : h24 % 12;
    const p2 = (n: number) => String(n).padStart(2, "0");
    return `${timePeriodBnFromMinutes(h24 * 60 + now.getMinutes())} ${toBn(h12)}:${toBn(p2(now.getMinutes()))}:${toBn(p2(now.getSeconds()))}`;
  }, [now]);

  return (
    <section
      aria-labelledby="prayer-hero-title"
      className="rounded-2xl overflow-hidden bg-primary text-primary-foreground shadow-lifted"
    >
      {/* ── হেডার: শহর + ঘড়ি + তারিখ ── */}
      <div className="bg-pattern-islamic px-4 pt-4 sm:px-6 sm:pt-5">
        <div className="flex items-center justify-between gap-3">
          <h1 id="prayer-hero-title" className="sr-only">
            {t("home.todaySchedule")}
          </h1>
          <Button
            variant="ghost"
            onClick={() => setSheetOpen(true)}
            className="tap-target h-11 rounded-full bg-primary-foreground/10 hover:bg-primary-foreground/20 hover:text-primary-foreground px-4 gap-1.5"
            aria-label={t("home.changeCity")}
          >
            <MapPin className="size-4" />
            <span className="text-sm font-semibold">{cityLabelBn(city)}</span>
            <ChevronDown className="size-3.5 opacity-70" />
          </Button>
          <div className="text-end leading-tight" aria-live="off">
            <p className="text-base sm:text-lg font-bold tabular-nums tracking-wide">{clock}</p>
            <p className="sr-only">{t("home.currentTime")}</p>
          </div>
        </div>
        <p className="mt-1.5 text-[12.5px] leading-relaxed text-primary-foreground/75">
          {gregorianBn(now)} · {bnDate.formatted} বঙ্গাব্দ · {hijri.formatted} হিজরি
        </p>
      </div>

      {/* ── কাউন্টডাউন ── */}
      <div className="bg-pattern-islamic px-4 pb-5 sm:px-6 sm:pb-6 pt-4">
        <div className="flex items-center justify-between gap-2">
          <span className="inline-flex items-center gap-1.5 rounded-full bg-gold px-3 py-1 text-xs font-bold text-gold-text-foreground">
            {t("home.ongoing")}: {PRAYER_LABELS_BN[next.current]}
          </span>
          {next.key === "fajr" ? <MoonStar className="size-4 text-primary-foreground/70" /> : <Sun className="size-4 text-primary-foreground/70" />}
        </div>
        <p className="mt-3 text-sm text-primary-foreground/85">
          {t("home.nextWaqt")} — <strong className="text-primary-foreground">{nextLabel}</strong>
        </p>
        <p
          className="mt-1 text-5xl sm:text-6xl font-extrabold text-gold-text tabular-nums leading-tight"
          aria-live="polite"
          aria-label={`${t("home.nextWaqt")} ${nextLabel} — ${countdown}`}
        >
          {countdown}
        </p>
        <p className="mt-1 text-sm text-primary-foreground/85">
          {nextLabel} — {formatTimeBn(times[next.key])}
        </p>
      </div>

      {/* ── আজকের সময়সূচি ── */}
      <div className="bg-card text-foreground p-2.5 sm:p-3">
        <ol className="grid gap-0.5" aria-label={t("home.todaySchedule")}>
          {SCHEDULE_ROWS.map((key) => (
            <ScheduleRow
              key={key}
              waqt={key}
              minutes={times[key]}
              isCurrent={next.current === key}
              isNext={next.key === key}
            />
          ))}
        </ol>
        <p className="mt-2 px-3 pb-1 text-[11.5px] text-muted-foreground text-center leading-relaxed">
          ইশরাক {formatTimeBn(times.ishraq)} · দুহা {formatTimeBn(times.duha)} · তাহাজ্জুদ{" "}
          {formatTimeBn(times.tahajjud)}
        </p>
        <p className="px-3 pb-1 pt-0.5 text-[11px] text-muted-foreground/70 text-center">
          {t("home.offlineNote")} · {dateKey(now)}
        </p>
      </div>

      <LocationSheet open={sheetOpen} onOpenChange={setSheetOpen} />
    </section>
  );
}

function ScheduleRow({
  waqt,
  minutes,
  isCurrent,
  isNext,
}: {
  waqt: PrayerKey;
  minutes: number;
  isCurrent: boolean;
  isNext: boolean;
}) {
  const lang = useApp((s) => s.profile.language);
  const t = (k: string) => translate(lang, k);
  const label = PRAYER_LABELS_BN[waqt];
  const isSunrise = waqt === "sunrise";
  return (
    <li
      className={cn(
        "flex items-center gap-3 rounded-xl px-3 py-2 transition-colors",
        isCurrent && "bg-primary-soft"
      )}
      aria-current={isCurrent ? "true" : undefined}
    >
      <span
        className={cn(
          "size-2 rounded-full shrink-0",
          isCurrent ? "bg-primary" : isSunrise ? "border border-border" : "bg-border"
        )}
        aria-hidden="true"
      />
      <span
        className={cn(
          "flex-1 text-sm",
          isCurrent ? "font-bold text-primary" : isSunrise ? "text-muted-foreground" : "font-medium"
        )}
      >
        {label}
      </span>
      {isNext && (
        <span className="rounded-full border border-primary/30 px-2 py-0.5 text-[10.5px] font-semibold text-primary">
          {t("home.next")}
        </span>
      )}
      {isCurrent && (
        <span className="rounded-full bg-primary px-2 py-0.5 text-[10.5px] font-semibold text-primary-foreground">
          {t("home.ongoing")}
        </span>
      )}
      <span
        className={cn(
          "text-sm tabular-nums",
          isCurrent ? "font-bold text-primary" : "font-semibold text-foreground/90"
        )}
      >
        {formatTimeBn(minutes)}
      </span>
    </li>
  );
}
