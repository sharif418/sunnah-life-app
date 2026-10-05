"use client";

// ─────────────────────────────────────────────────────────────────────────────
// আমল (Muhasaba diary) — the daily practice engine. Mirrors
// apps/mobile/lib/features/amal/today_screen.dart: cadence-aware rows grouped
// by category, tri-state prayers, counters with targets, auto-source badges,
// completion hero + streak, week strip with swipe navigation, day locking
// (Ishraq of D+1) and the month heatmap sub-view.
// Offline-first: guests write to the Zustand amal cache/outbox (persisted);
// logged-in users get server hydration + debounced batch upsert via the store.
// ─────────────────────────────────────────────────────────────────────────────

import * as React from "react";
import { api } from "@/lib/api";
import { toast } from "sonner";
import { useApp } from "@/lib/store";
import {
  addDays,
  dateKey,
  formatDayHeaderBn,
  hijriDate,
  parseKey,
  toBn,
  WEEKDAYS_SHORT_BN,
} from "@/lib/calendars";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Tooltip, TooltipContent, TooltipTrigger } from "@/components/ui/tooltip";
import {
  BookOpen,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  CircleCheck,
  Flag,
  Lock,
  RefreshCw,
  Zap,
  Info,
  ChevronDown,
  Flame,
} from "lucide-react";
import type {
  AmalDefinition,
  AmalEntry,
  AmalValue,
  UserCategory,
} from "@/types/domain";
import {
  bnNumber,
  cadenceLabelBn,
  currentStreak,
  dayCompletion,
  displayTarget,
  isAmalDay,
  isDateLockedClient,
  shortUnit,
  type AmalGeoCfg,
  amalPoints,
} from "./amal-logic";
import {
  BooleanCheck,
  CompletionRing,
  CountControl,
  QuantityControl,
  StreakBadge,
  TriStateChips,
} from "./amal-controls";
import { AmalMonthView } from "./amal-month";
import { GoalsView } from "./goals";
import { HabitView } from "./habit";
import { useHijriAdjust } from "@/hooks/use-hijri-adjust";
import { LatestReviewCard } from "./latest-review";
import { DIARY_COVER, DIARY_INSTRUCTIONS, PAPER_KEYS, PAPER_LAYOUT } from "@/lib/diary-layout";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";

// Session-level definition cache: re-entering the tab renders instantly and
// guests keep a working diary after the first successful fetch.
let defsSessionCache: AmalDefinition[] | null = null;

function useAmalDefinitions() {
  const [state, setState] = React.useState<{ defs: AmalDefinition[] | null; error: string | null; loading: boolean }>(
    () => ({ defs: defsSessionCache, error: null, loading: !defsSessionCache })
  );
  const load = React.useCallback(async () => {
    setState((s) => ({ ...s, loading: true, error: null }));
    try {
      const r = await api.amalDefinitions();
      defsSessionCache = r.definitions;
      setState({ defs: r.definitions, error: null, loading: false });
    } catch (e) {
      setState({ defs: defsSessionCache, error: (e as Error).message, loading: false });
    }
  }, []);
  React.useEffect(() => {
    if (!defsSessionCache) void load();
  }, [load]);
  return { ...state, reload: load };
}

export function AmalView() {
  const user = useApp((s) => s.user);
  const profile = useApp((s) => s.profile);
  const view = useApp((s) => s.view);
  const back = useApp((s) => s.back);
  const nav = useApp((s) => s.nav);
  const amalCache = useApp((s) => s.amalCache);
  const writeEntry = useApp((s) => s.writeEntry);
  const hydrateFromServer = useApp((s) => s.hydrateFromServer);
  const hijriAdjust = useHijriAdjust();

  const today = dateKey(new Date());
  const [selectedDate, setSelectedDate] = React.useState(today);
  const [weekEnd, setWeekEnd] = React.useState(today);
  const [monthAnchor, setMonthAnchor] = React.useState(() => today.slice(0, 8) + "01");
  const [entriesLoading, setEntriesLoading] = React.useState(false);
  const { defs, loading: defsLoading, reload } = useAmalDefinitions();

  const category: UserCategory = user?.category ?? "general";
  const monthView = view === "month";

  // Server hydration of the diary window (logged-in users only; guests run
  // fully from the persisted local cache).
  const from = React.useMemo(() => {
    const base = addDays(today, -119); // streak lookback window
    return monthView && monthAnchor < base ? monthAnchor : base;
  }, [monthView, monthAnchor, today]);

  React.useEffect(() => {
    if (!user) return;
    let cancelled = false;
    setEntriesLoading(true);
    api
      .amalEntries(from, today)
      .then((r) => {
        if (!cancelled) hydrateFromServer(r.entries);
      })
      .catch(() => undefined)
      .finally(() => {
        if (!cancelled) setEntriesLoading(false);
      });
    return () => {
      cancelled = true;
    };
  }, [user, from, today, hydrateFromServer]);

  const allEntries = React.useMemo(() => Object.values(amalCache), [amalCache]);
  const dayEntries = React.useMemo(() => allEntries.filter((e) => e.date === selectedDate), [allEntries, selectedDate]);

  const geo: AmalGeoCfg = React.useMemo(
    () => ({ lat: profile.lat, lng: profile.lng, method: profile.method, madhhab: profile.madhhab }),
    [profile.lat, profile.lng, profile.method, profile.madhhab]
  );
  const lockedFn = React.useCallback((day: string) => isDateLockedClient(day, geo, today), [geo, today]);
  const locked = lockedFn(selectedDate);

  const dueDefs = React.useMemo(
    () => (defs ?? []).filter((d) => isAmalDay(d, selectedDate, hijriAdjust)),
    [defs, selectedDate, hijriAdjust]
  );
  // The paper diary's groups, in the paper's order (mobile parity): every
  // due catalog amal a row names renders under that group; the rest are the
  // app's extras, kept apart in a collapsed card.
  const paperGroups = React.useMemo(() => {
    const byKey = new Map(dueDefs.map((d) => [d.key, d] as const));
    return PAPER_LAYOUT.map((g) => ({
      ...g,
      defs: g.rows.flatMap((r) => r.amalKeys.map((k) => byKey.get(k)).filter((d): d is AmalDefinition => !!d)),
    })).filter((g) => g.defs.length > 0);
  }, [dueDefs]);
  const paperDefs = React.useMemo(() => dueDefs.filter((d) => PAPER_KEYS.has(d.key)), [dueDefs]);
  const extraDefs = React.useMemo(() => dueDefs.filter((d) => !PAPER_KEYS.has(d.key)), [dueDefs]);
  const [extrasOpen, setExtrasOpen] = React.useState(false);
  const [instructionsOpen, setInstructionsOpen] = React.useState(false);
  // the day's count is the paper's (as on the printed form and in the app)
  const completion = React.useMemo(() => dayCompletion(dayEntries, paperDefs, category), [dayEntries, paperDefs, category]);
  const extrasDone = React.useMemo(
    () => extraDefs.filter((d) => amalPoints(dayEntries.find((e) => e.amalKey === d.key)?.value, d, category) >= 1).length,
    [extraDefs, dayEntries, category]
  );
  const streak = React.useMemo(() => currentStreak(allEntries, defs ?? [], category, today), [allEntries, defs, category, today]);

  const write = React.useCallback(
    (def: AmalDefinition, value: AmalValue) => {
      if (locked || selectedDate > today) return; // locked/future days are read-only
      writeEntry({ amalKey: def.key, date: selectedDate, value, clientUpdatedAt: new Date().toISOString(), source: "manual" });
    },
    [locked, selectedDate, today, writeEntry]
  );

  const selectDay = (day: string) => {
    if (day > today) return;
    setSelectedDate(day);
  };

  const weekDays = React.useMemo(
    () => Array.from({ length: 7 }, (_, i) => addDays(weekEnd, -(6 - i))),
    [weekEnd]
  );

  const shiftWeek = (delta: number) => {
    setWeekEnd((we) => {
      const next = addDays(we, delta);
      return next > today ? today : next;
    });
  };

  const shiftDay = (delta: number) => {
    const next = addDays(selectedDate, delta);
    if (next > today || next < addDays(today, -365)) return;
    setSelectedDate(next);
    setWeekEnd((we) => {
      if (next > we) return next < today ? next : today;
      if (next < addDays(we, -6)) {
        const end = addDays(next, 6);
        return end < today ? end : today;
      }
      return we;
    });
  };

  // Swipe left/right on the diary body → previous/next day.
  const touchStart = React.useRef<{ x: number; y: number } | null>(null);
  const onTouchStart = (e: React.TouchEvent) => {
    const t = e.touches[0];
    touchStart.current = { x: t.clientX, y: t.clientY };
  };
  const onTouchEnd = (e: React.TouchEvent) => {
    const s = touchStart.current;
    touchStart.current = null;
    if (!s) return;
    const t = e.changedTouches[0];
    const dx = t.clientX - s.x;
    const dy = t.clientY - s.y;
    if (Math.abs(dx) > 64 && Math.abs(dx) > Math.abs(dy) * 1.5) {
      shiftDay(dx > 0 ? -1 : 1);
    }
  };

  const entryOf = (key: string): AmalEntry | undefined => amalCache[`${selectedDate}#${key}`];

  // ── habit challenge sub-view ───────────────────────────────────────────────
  if (view === "habit" && defs && defs.length > 0) {
    return <HabitView defs={defs} entries={allEntries} category={category} today={today} onBack={back} />;
  }

  // ── goals sub-view (signed-in members) ─────────────────────────────────────
  if (view === "goals" && user && defs && defs.length > 0) {
    return <GoalsView defs={defs} onBack={back} />;
  }

  // ── month sub-view ─────────────────────────────────────────────────────────
  if (monthView && defs && defs.length > 0) {
    return (
      <AmalMonthView
        defs={defs}
        entries={allEntries}
        today={today}
        category={category}
        geo={geo}
        anchor={monthAnchor}
        onAnchorChange={setMonthAnchor}
        onOpenDay={(day) => {
          setSelectedDate(day);
          back();
        }}
        onBack={back}
      />
    );
  }

  // ── loading / error / empty ────────────────────────────────────────────────
  if (defsLoading && !defs) return <AmalSkeleton />;
  if (!defs) return <DefsError onRetry={reload} />;
  if (defs.length === 0) return <DefsEmpty />;

  // ── day view ───────────────────────────────────────────────────────────────
  return (
    <div className="space-y-4" onTouchStart={onTouchStart} onTouchEnd={onTouchEnd}>
      {/* header */}
      <div className="flex items-start justify-between gap-3">
        <div className="flex min-w-0 items-start gap-1">
          <button
            type="button"
            onClick={() => shiftDay(-1)}
            aria-label="আগের দিন"
            className="tap-target mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <ChevronLeft className="size-4 rtl:rotate-180" />
          </button>
          <div className="min-w-0">
            <h1 className="text-xl font-extrabold leading-tight">
              {selectedDate === today ? "আজকের আমল" : "আমল ডায়েরি"}
            </h1>
            <p className="mt-0.5 truncate text-xs text-muted-foreground">
              {formatDayHeaderBn(parseKey(selectedDate))} · {hijriDate(parseKey(selectedDate), hijriAdjust).formatted}
            </p>
          </div>
          <button
            type="button"
            onClick={() => shiftDay(1)}
            disabled={selectedDate >= today}
            aria-label="পরের দিন"
            className="tap-target mt-0.5 flex size-8 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-30"
          >
            <ChevronRight className="size-4 rtl:rotate-180" />
          </button>
        </div>
        <Button
          variant="outline"
          size="sm"
          className="h-9 shrink-0 gap-1.5 rounded-full"
          onClick={() => nav("amal", "month")}
        >
          <CalendarDays className="size-4" />
          <span className="hidden min-[380px]:inline">মাসিক ছক</span>
        </Button>
        <Button variant="outline" size="sm" className="h-9 shrink-0 gap-1.5 rounded-full" onClick={() => nav("amal", "habit")}>
          <Flame className="size-4" />
          <span className="hidden min-[380px]:inline">অভ্যাস</span>
        </Button>
        {user ? (
          <Button variant="outline" size="sm" className="h-9 shrink-0 gap-1.5 rounded-full" onClick={() => nav("amal", "goals")}>
            <Flag className="size-4" />
            <span className="hidden min-[380px]:inline">আমার লক্ষ্য</span>
          </Button>
        ) : null}
      </div>

      {/* week strip */}
      <Card className="gap-0 py-0 p-2">
        <div className="flex items-center gap-1">
          <button
            type="button"
            onClick={() => shiftWeek(-7)}
            aria-label="আগের সপ্তাহ"
            className="tap-target flex size-9 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <ChevronLeft className="size-5 rtl:rotate-180" />
          </button>
          <div className="grid flex-1 grid-cols-7 gap-1">
            {weekDays.map((day) => (
              <DayPill
                key={day}
                day={day}
                selected={day === selectedDate}
                isToday={day === today}
                locked={lockedFn(day)}
                onSelect={() => selectDay(day)}
              />
            ))}
          </div>
          <button
            type="button"
            onClick={() => shiftWeek(7)}
            disabled={weekEnd >= today}
            aria-label="পরের সপ্তাহ"
            className="tap-target flex size-9 shrink-0 items-center justify-center rounded-full text-muted-foreground transition-colors hover:bg-muted hover:text-foreground disabled:opacity-30"
          >
            <ChevronRight className="size-5 rtl:rotate-180" />
          </button>
        </div>
      </Card>

      {/* completion hero */}
      <Card className="py-0">
        <CardContent className="p-4 sm:p-6">
          <div className="flex items-center gap-4">
            <CompletionRing pct={completion.pct} size={76} />
            <div className="min-w-0 flex-1">
              <p className="text-xs text-muted-foreground">
                {selectedDate === today ? "আজকের সম্পন্নতা" : "এই দিনের সম্পন্নতা"}
              </p>
              <p className="mt-1 text-lg font-extrabold leading-tight">
                {toBn(completion.done)} / {toBn(completion.total)} সম্পন্ন
              </p>
              <div className="mt-2 flex flex-wrap items-center gap-2">
                <StreakBadge days={streak} />
                {entriesLoading && (
                  <span className="text-[11px] text-muted-foreground">সার্ভার থেকে লোড হচ্ছে…</span>
                )}
                {!user && (
                  <span className="text-[11px] text-muted-foreground">
                    অতিথি — আমল এই ডিভাইসে সংরক্ষিত, সাইন আপ করলে সিঙ্ক হবে
                  </span>
                )}
              </div>
            </div>
          </div>
          <button
            type="button"
            onClick={() => setInstructionsOpen(true)}
            className="mt-3 inline-flex items-center gap-1.5 text-xs font-semibold text-primary hover:underline"
          >
            <Info className="size-3.5" /> ডায়েরির নির্দেশনাবলী
          </button>
        </CardContent>
      </Card>

      {/* the head's latest comment to me (signed in) */}
      {user ? <LatestReviewCard /> : null}

      {/* locked-day banner */}
      {locked && (
        <Card className="border-alert/30 bg-alert-soft py-0">
          <CardContent className="flex items-center gap-3 p-4 text-alert">
            <Lock className="size-5 shrink-0" />
            <div className="min-w-0">
              <p className="text-sm font-bold">এই দিনের আমল লক হয়ে গেছে</p>
              <p className="mt-0.5 text-xs leading-relaxed text-alert/80">
                পরের দিন ইশরাকের পর দিন বন্ধ হয় — সম্পাদনার জন্য উসরা প্রধানের অনুমতি দরকার।
              </p>
            </div>
            {user?.usrahId ? (
              <Button
                size="sm"
                variant="outline"
                className="ms-auto h-9 shrink-0 rounded-full border-alert/40 bg-card text-alert hover:bg-alert-soft"
                onClick={async () => {
                  try {
                    await api.amalUnlockRequest(selectedDate);
                    toast.success("উসরা প্রধানকে অনুরোধ পাঠানো হয়েছে");
                  } catch (e) {
                    toast.error(e instanceof Error ? e.message : "পাঠানো যায়নি");
                  }
                }}
              >
                আনলক চাই
              </Button>
            ) : null}
          </CardContent>
        </Card>
      )}

      {/* the paper diary, group by group */}
      {paperGroups.map((g) => {
        const done = g.defs.filter((d) => amalPoints(entryOf(d.key)?.value, d, category) >= 1).length;
        return (
          <section key={g.groupBn} className="space-y-2.5">
            <div className="flex items-baseline gap-2 px-1">
              <h2 className="text-sm font-bold text-primary">{g.groupBn}</h2>
              <Badge variant="secondary" className="ms-auto shrink-0 font-semibold">
                {toBn(done)}/{toBn(g.defs.length)}
              </Badge>
            </div>
            {g.noteBn ? <p className="px-1 text-[11.5px] leading-relaxed text-muted-foreground">{g.noteBn}</p> : null}
            <div className="space-y-2.5">
              {g.defs.map((def) => (
                <AmalRow key={def.key} def={def} entry={entryOf(def.key)} disabled={locked} category={category} onWrite={write} />
              ))}
            </div>
          </section>
        );
      })}

      {/* the app's extras (not on the paper): collapsed, opt-in */}
      {extraDefs.length > 0 ? (
        <section className="space-y-2.5">
          <button
            type="button"
            onClick={() => setExtrasOpen((v) => !v)}
            aria-expanded={extrasOpen}
            className="flex w-full items-center gap-2 rounded-xl border border-border bg-card px-4 py-3 text-start shadow-card"
          >
            <span className="min-w-0 flex-1">
              <span className="block text-sm font-bold">অতিরিক্ত আমল</span>
              <span className="block text-[11.5px] text-muted-foreground">
                কাগজের ডায়েরির বাইরে · {toBn(extrasDone)}/{toBn(extraDefs.length)}
              </span>
            </span>
            <ChevronDown className={cn("size-4 shrink-0 text-muted-foreground transition-transform", extrasOpen && "rotate-180")} />
          </button>
          {extrasOpen ? (
            <div className="space-y-2.5">
              {extraDefs.map((def) => (
                <AmalRow key={def.key} def={def} entry={entryOf(def.key)} disabled={locked} category={category} onWrite={write} />
              ))}
            </div>
          ) : null}
        </section>
      ) : null}

      <Dialog open={instructionsOpen} onOpenChange={setInstructionsOpen}>
        <DialogContent className="max-h-[85vh] overflow-y-auto sm:max-w-lg">
          <DialogHeader>
            <DialogTitle>নির্দেশনাবলী</DialogTitle>
          </DialogHeader>
          {DIARY_COVER.ar ? (
            <div className="rounded-xl bg-primary-soft px-4 py-3 text-center">
              <p dir="rtl" lang="ar" className="font-arabic text-lg leading-loose">{DIARY_COVER.ar}</p>
              <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{DIARY_COVER.bn}</p>
            </div>
          ) : null}
          <ol className="space-y-2 ps-5 text-sm leading-relaxed [list-style:bengali]">
            {DIARY_INSTRUCTIONS.map((t, i) => (
              <li key={i}>{t}</li>
            ))}
          </ol>
        </DialogContent>
      </Dialog>

      <p className="pt-1 text-center text-[11px] leading-relaxed text-muted-foreground">
        প্রতিদিনের আমল পরের দিনের ইশরাকের পর লক হয়ে যায় — তাই প্রতিদিন সকালে হিসাব লিখুন।
      </p>
    </div>
  );
}

// ── One amal row ────────────────────────────────────────────────────────────

function AmalRow({
  def,
  entry,
  disabled,
  category,
  onWrite,
}: {
  def: AmalDefinition;
  entry: AmalEntry | undefined;
  disabled: boolean;
  category: UserCategory;
  onWrite: (def: AmalDefinition, value: AmalValue) => void;
}) {
  const value = entry?.value;
  const target = displayTarget(def, category);
  const isCounter = def.inputType === "count" || def.inputType === "quantity";
  const cadence = cadenceLabelBn(def.cadence);
  const subtitle =
    cadence ||
    (target != null && isCounter ? `লক্ষ্য: ${bnNumber(target)} ${shortUnit(def.unit)}` : null);
  const reached = target != null && typeof value === "number" && value >= target;
  const autoValued = entry?.source?.startsWith("auto:") ?? false;
  const isBoolean = def.inputType === "boolean";
  const unit = shortUnit(def.unit);

  return (
    <Card className="gap-0 py-0">
      <CardContent className={cn("flex gap-3 p-4", isBoolean ? "items-center" : "items-start")}>
        <div className="min-w-0 flex-1">
          <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
            <h3 className="text-[15px] font-semibold leading-snug">{def.titleBn}</h3>
            {def.autoSource && <AutoBadge active={autoValued} />}
          </div>
          {subtitle && <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{subtitle}</p>}
        </div>
        {reached && <CircleCheck className="mt-0.5 size-5 shrink-0 text-success" aria-label="লক্ষ্য পূরণ" />}
        {isBoolean && (
          <BooleanCheck value={value === true} disabled={disabled} onToggle={(v) => onWrite(def, v)} />
        )}
      </CardContent>

      {!isBoolean && (
        <CardContent className="px-4 pb-4">
          <div className="mt-1">
            {def.inputType === "tristate" && (
              <TriStateChips
                value={typeof value === "string" && value !== "" ? value : ""}
                disabled={disabled}
                onSelect={(v) => onWrite(def, v)}
              />
            )}
            {def.inputType === "count" && (
              <CountControl
                value={typeof value === "number" ? Math.round(value) : 0}
                target={target}
                unit={unit || "বার"}
                disabled={disabled}
                onChange={(v) => onWrite(def, v)}
              />
            )}
            {def.inputType === "quantity" && (
              <QuantityControl
                value={typeof value === "number" ? value : 0}
                target={target}
                unit={unit || "পৃষ্ঠা"}
                disabled={disabled}
                onChange={(v) => onWrite(def, v)}
              />
            )}
          </div>
        </CardContent>
      )}
    </Card>
  );
}

// ── Auto-source badge ────────────────────────────────────────────────────────

function AutoBadge({ active }: { active: boolean }) {
  return (
    <Tooltip>
      <TooltipTrigger asChild>
        <span tabIndex={0} className="inline-flex cursor-help outline-none">
          <Badge
            variant={active ? "default" : "outline"}
            className="gap-0.5 px-1.5 py-0 text-[10px] leading-4"
          >
            <Zap className="size-2.5" />
            অটো
          </Badge>
        </span>
      </TooltipTrigger>
      <TooltipContent side="top">
        {active
          ? "স্বয়ংক্রিয়ভাবে লেখা হয়েছে — প্রয়োজনে সংশোধন করা যাবে"
          : "অন্য ফিচার (নামাজ লগ, তিলাওয়াত, আযকার) থেকে স্বয়ংক্রিয়ভাবে সিঙ্ক হয়"}
      </TooltipContent>
    </Tooltip>
  );
}

// ── Week strip pill ─────────────────────────────────────────────────────────

function DayPill({
  day,
  selected,
  isToday,
  locked,
  onSelect,
}: {
  day: string;
  selected: boolean;
  isToday: boolean;
  locked: boolean;
  onSelect: () => void;
}) {
  const d = parseKey(day);
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-current={selected ? "date" : undefined}
      className={cn(
        "tap-target relative flex h-14 min-w-0 flex-col items-center justify-center gap-1 rounded-xl border transition-colors duration-150",
        selected
          ? "border-primary bg-primary text-primary-foreground shadow-card"
          : isToday
            ? "border-primary/50 bg-card text-primary"
            : "border-border bg-card text-muted-foreground hover:bg-muted/60",
        locked && !selected && "opacity-70"
      )}
    >
      <span className="text-[10px] font-medium leading-none">{WEEKDAYS_SHORT_BN[d.getDay()]}</span>
      <span className="text-sm font-bold leading-none">{toBn(d.getDate())}</span>
      {locked && <Lock className="absolute end-1 top-1 size-2.5 opacity-70" />}
    </button>
  );
}

// ── Loading / error / empty states ──────────────────────────────────────────

function AmalSkeleton() {
  return (
    <div className="space-y-4">
      <Skeleton className="h-7 w-44 rounded-lg" />
      <Skeleton className="h-[74px] w-full rounded-xl" />
      <Skeleton className="h-36 w-full rounded-xl" />
      {Array.from({ length: 6 }).map((_, i) => (
        <Skeleton key={i} className="h-28 w-full rounded-xl" />
      ))}
    </div>
  );
}

function DefsError({ onRetry }: { onRetry: () => void }) {
  return (
    <Card className="gap-0 border-alert/30 bg-alert-soft py-0">
      <CardContent className="flex flex-col items-center gap-3 p-8 text-center">
        <div className="flex size-14 items-center justify-center rounded-full bg-alert/10">
          <RefreshCw className="size-6 text-alert" />
        </div>
        <div>
          <p className="font-bold text-alert">আমলের তালিকা আনা যায়নি</p>
          <p className="mt-1 text-sm leading-relaxed text-alert/80">
            ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন।
          </p>
        </div>
        <Button
          variant="outline"
          className="h-11 gap-2 rounded-full border-alert/40 text-alert hover:bg-alert/10 hover:text-alert"
          onClick={onRetry}
        >
          <RefreshCw className="size-4" /> আবার চেষ্টা করুন
        </Button>
      </CardContent>
    </Card>
  );
}

function DefsEmpty() {
  return (
    <Card className="gap-0 py-0">
      <CardContent className="flex flex-col items-center gap-2 p-10 text-center">
        <div className="flex size-14 items-center justify-center rounded-full bg-primary-soft">
          <BookOpen className="size-6 text-primary" />
        </div>
        <p className="font-semibold">আমলের তালিকা খালি</p>
        <p className="text-sm leading-relaxed text-muted-foreground">
          ক্যাটালগ সার্ভার থেকে আসে — কিছুক্ষণ পর আবার খুলে দেখুন।
        </p>
      </CardContent>
    </Card>
  );
}
