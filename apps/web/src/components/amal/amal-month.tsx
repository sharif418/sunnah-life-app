"use client";

// ─────────────────────────────────────────────────────────────────────────────
// মাসিক ছক — the paper-diary month heatmap (mirrors month_screen.dart):
// rows = amal definitions, columns = days. Month navigation, per-category
// month-average rings, streak, locking rule (🔒 in the day header), tap a
// column to open that day in the diary view.
// ─────────────────────────────────────────────────────────────────────────────

import * as React from "react";
import { ChevronLeft, ChevronRight, Lock } from "lucide-react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { dateKey, GREG_MONTHS_BN, toBn } from "@/lib/calendars";
import { cn } from "@/lib/utils";
import { AMAL_CATEGORY_LABELS_BN } from "@/types/domain";
import type { AmalCategory, AmalDefinition, AmalEntry, UserCategory } from "@/types/domain";
import { amalPoints, currentStreak, isAmalDay, isDateLockedClient, valueLabelBn, type AmalGeoCfg } from "./amal-logic";
import { CompletionRing, StreakBadge } from "./amal-controls";

const CELL = 24; // px stride per day column (20px cell + 2px margins)

export function AmalMonthView({
  defs,
  entries,
  today,
  category,
  geo,
  anchor,
  onAnchorChange,
  onOpenDay,
  onBack,
}: {
  defs: AmalDefinition[];
  entries: AmalEntry[];
  today: string;
  category: UserCategory;
  geo: AmalGeoCfg;
  /** day-key of the 1st of the displayed month */
  anchor: string;
  onAnchorChange: (a: string) => void;
  onOpenDay: (day: string) => void;
  onBack: () => void;
}) {
  const [y, m] = React.useMemo(() => anchor.split("-").map(Number) as [number, number], [anchor]);

  const days = React.useMemo(() => {
    const dim = new Date(y, m, 0).getDate();
    return Array.from({ length: dim }, (_, i) => dateKey(new Date(y, m - 1, i + 1)));
  }, [y, m]);

  const byDate = React.useMemo(() => {
    const mm = new Map<string, Map<string, AmalEntry>>();
    const prefix = anchor.slice(0, 7);
    for (const e of entries) {
      if (!e.date.startsWith(prefix)) continue;
      let day = mm.get(e.date);
      if (!day) {
        day = new Map();
        mm.set(e.date, day);
      }
      day.set(e.amalKey, e);
    }
    return mm;
  }, [entries, anchor]);

  const lockedFn = React.useCallback((day: string) => day < today && isDateLockedClient(day, geo, today), [geo, today]);

  const streak = React.useMemo(() => currentStreak(entries, defs, category, today), [entries, defs, category, today]);

  /** Per-category month-average completion over the days elapsed so far. */
  const monthCatPct = React.useMemo(() => {
    const res = new Map<AmalCategory, { points: number; due: number }>();
    for (const def of defs) {
      let due = 0;
      let points = 0;
      for (const day of days) {
        if (day > today) break;
        if (!isAmalDay(def, day)) continue;
        due++;
        const e = byDate.get(day)?.get(def.key);
        points += e ? amalPoints(e.value, def, category) : 0;
      }
      if (due <= 0) continue;
      const c = res.get(def.category);
      if (c) {
        c.points += points;
        c.due += due;
      } else {
        res.set(def.category, { points, due });
      }
    }
    return res;
  }, [defs, days, today, byDate, category]);

  const thisMonthStart = today.slice(0, 8) + "01";
  const canNext = anchor < thisMonthStart;

  const shiftMonth = (delta: number) => {
    onAnchorChange(dateKey(new Date(y, m - 1 + delta, 1)));
  };

  return (
    <div className="space-y-4">
      {/* view header */}
      <div className="flex items-center gap-2">
        <Button
          variant="ghost"
          size="icon"
          className="tap-target size-11 shrink-0 rounded-full"
          onClick={onBack}
          aria-label="আজকের আমলে ফিরে যান"
        >
          <ChevronLeft className="size-5 rtl:rotate-180" />
        </Button>
        <div className="min-w-0">
          <h1 className="text-xl font-extrabold">মাসিক ছক</h1>
          <p className="text-xs text-muted-foreground">দিন × আমল — মাসের হিসাবের সারসংক্ষেপ</p>
        </div>
      </div>

      {/* month navigation */}
      <div className="flex items-center gap-2">
        <Button
          variant="outline"
          size="icon"
          className="tap-target size-11 shrink-0 rounded-full"
          onClick={() => shiftMonth(-1)}
          aria-label="আগের মাস"
        >
          <ChevronLeft className="size-5 rtl:rotate-180" />
        </Button>
        <p className="flex-1 text-center text-lg font-extrabold">
          {GREG_MONTHS_BN[m - 1]} {toBn(y)}
        </p>
        <Button
          variant="outline"
          size="icon"
          className="tap-target size-11 shrink-0 rounded-full"
          onClick={() => shiftMonth(1)}
          disabled={!canNext}
          aria-label="পরের মাস"
        >
          <ChevronRight className="size-5 rtl:rotate-180" />
        </Button>
      </div>

      {/* streak + month-average category rings */}
      <div className="flex items-center gap-4 overflow-x-auto px-1 pb-1 no-scrollbar">
        <StreakBadge days={streak} />
        {[...monthCatPct.entries()].map(([cat, c]) => (
          <div key={cat} className="flex w-14 shrink-0 flex-col items-center gap-1">
            <CompletionRing pct={c.due ? Math.round((100 * c.points) / c.due) : 0} size={44} />
            <span className="w-full truncate text-center text-[10px] text-muted-foreground">
              {AMAL_CATEGORY_LABELS_BN[cat]}
            </span>
          </div>
        ))}
      </div>

      {/* heatmap grid */}
      <Card className="gap-0 py-0">
        <CardContent className="p-3 sm:p-4">
          <div className="flex">
            {/* fixed label column */}
            <div className="w-28 shrink-0 border-e border-border pe-2 sm:w-36">
              <div className="h-6" />
              {defs.map((def, i) => (
                <div
                  key={def.key}
                  className={cn("flex h-6 items-center", i > 0 && def.category !== defs[i - 1].category && "mt-2")}
                  title={def.titleBn}
                >
                  <span className="truncate text-[10px] leading-tight text-foreground/80">{def.titleBn}</span>
                </div>
              ))}
            </div>
            {/* scrollable day columns */}
            <div className="flex-1 overflow-x-auto scroll-thin">
              <div className="flex">
                {days.map((day) => {
                  const isToday = day === today;
                  const future = day > today;
                  const locked = lockedFn(day);
                  return (
                    <div key={day} className="shrink-0" style={{ width: CELL }}>
                      <button
                        type="button"
                        onClick={() => !future && onOpenDay(day)}
                        disabled={future}
                        aria-label={`${day} দিনের আমল দেখুন`}
                        className={cn(
                          "flex h-6 w-6 items-center justify-center text-[9px] font-semibold",
                          isToday ? "text-primary" : "text-muted-foreground",
                          !future && "rounded hover:bg-primary-soft hover:text-primary"
                        )}
                      >
                        {locked ? <Lock className="size-2.5" /> : toBn(Number(day.slice(8)))}
                      </button>
                      {defs.map((def, i) => {
                        const e = byDate.get(day)?.get(def.key);
                        const p = e ? amalPoints(e.value, def, category) : 0;
                        const due = !future && isAmalDay(def, day);
                        return (
                          <button
                            key={def.key}
                            type="button"
                            disabled={future}
                            onClick={() => onOpenDay(day)}
                            aria-label={`${day} — ${def.titleBn}: ${valueLabelBn(e?.value, def)}`}
                            className={cn(
                              "m-0.5 block size-5 rounded-sm transition-transform duration-150",
                              !due
                                ? "border border-dashed border-border/70 bg-transparent"
                                : p >= 1
                                  ? "bg-primary"
                                  : p > 0
                                    ? "bg-gold"
                                    : "bg-muted",
                              !future && "hover:scale-110",
                              i > 0 && def.category !== defs[i - 1].category && "mt-2"
                            )}
                          />
                        );
                      })}
                    </div>
                  );
                })}
              </div>
            </div>
          </div>

          {/* legend */}
          <div className="mt-3 flex flex-wrap items-center justify-center gap-x-4 gap-y-1.5 border-t border-border pt-3 text-[11px] text-muted-foreground">
            <span className="inline-flex items-center gap-1.5">
              <span className="size-3 rounded-sm bg-primary" /> সম্পূর্ণ
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="size-3 rounded-sm bg-gold" /> আংশিক
            </span>
            <span className="inline-flex items-center gap-1.5">
              <span className="size-3 rounded-sm bg-muted" /> হয়নি
            </span>
            <span className="inline-flex items-center gap-1.5">
              <Lock className="size-3" /> লকড দিন
            </span>
          </div>
        </CardContent>
      </Card>

      <p className="text-center text-[11px] leading-relaxed text-muted-foreground">
        যেকোনো দিনে চাপ দিলে সেই দিনের আমল খোলে — লকড দিন শুধু পড়ার জন্য।
      </p>
    </div>
  );
}
