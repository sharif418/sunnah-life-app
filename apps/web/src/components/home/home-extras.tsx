"use client";

// Two home sections the app has (mobile parity, home_screen.dart):
//   • সর্বাধিক ব্যবহৃত — the three amals kept on the most distinct days in
//     the last 30 (full points only), with a one-tap "আজ লিখুন". Hidden until
//     there is something to rank.
//   • ইলম — courses and quizzes, with how many there are.

import * as React from "react";
import { Check, ChevronLeft, Flame, GraduationCap, ListChecks } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { getPack } from "@/lib/content";
import { useApp } from "@/lib/store";
import { addDays, dateKey, toBn } from "@/lib/calendars";
import type { AmalDefinition, AmalEntry, AmalValue, UserCategory } from "@/types/domain";
import { amalPoints } from "@/components/amal/amal-logic";
import { Button } from "@/components/ui/button";
import { cn } from "@/lib/utils";

const WINDOW = 30;

export interface MostUsed {
  def: AmalDefinition;
  daysUsed: number;
}

/** Same rule as the app's mostUsedAmals: distinct full-point days, ≥ 2, top N. */
export function mostUsedAmals(
  entries: AmalEntry[],
  defs: AmalDefinition[],
  today: string,
  category: UserCategory,
  limit = 3
): MostUsed[] {
  const from = addDays(today, -(WINDOW - 1));
  const byKey = new Map(defs.map((d) => [d.key, d]));
  const days = new Map<string, Set<string>>();
  for (const e of entries) {
    if (e.date < from || e.date > today) continue;
    const def = byKey.get(e.amalKey);
    if (!def || amalPoints(e.value, def, category) < 1) continue;
    const set = days.get(e.amalKey) ?? new Set<string>();
    set.add(e.date);
    days.set(e.amalKey, set);
  }
  return [...days.entries()]
    .filter(([, d]) => d.size >= 2)
    .sort(
      ([a, da], [b, db]) =>
        db.size - da.size || (byKey.get(a)!.sortOrder ?? 0) - (byKey.get(b)!.sortOrder ?? 0) || a.localeCompare(b)
    )
    .slice(0, limit)
    .map(([k, d]) => ({ def: byKey.get(k)!, daysUsed: d.size }));
}

/** The one-tap value for today (null: free text has no quick affordance). */
function quickValue(def: AmalDefinition, current: AmalValue | undefined): AmalValue | null {
  switch (def.inputType) {
    case "boolean":
      return true;
    case "count":
    case "quantity":
      return (typeof current === "number" ? current : 0) + 1;
    case "tristate":
      return "jamaat";
    default:
      return null;
  }
}

export function MostUsedSection() {
  const user = useApp((s) => s.user);
  const amalCache = useApp((s) => s.amalCache);
  const outbox = useApp((s) => s.outbox);
  const writeEntry = useApp((s) => s.writeEntry);
  const category: UserCategory = user?.category ?? "general";
  const today = dateKey();
  const [defs, setDefs] = React.useState<AmalDefinition[]>([]);
  const [server, setServer] = React.useState<AmalEntry[]>([]);

  React.useEffect(() => {
    let alive = true;
    api
      .amalDefinitions()
      .then((r) => alive && setDefs(r.definitions))
      .catch(() => null);
    if (user) {
      api
        .amalEntries(addDays(today, -(WINDOW - 1)), today)
        .then((r) => alive && setServer(r.entries))
        .catch(() => null);
    } else {
      setServer([]);
    }
    return () => {
      alive = false;
    };
  }, [user, today]);

  // server history, then this device's entries on top (unsynced edits win)
  const entries = React.useMemo(() => {
    const m = new Map<string, AmalEntry>();
    for (const e of server) m.set(`${e.date}#${e.amalKey}`, e);
    for (const e of Object.values(amalCache)) m.set(`${e.date}#${e.amalKey}`, e);
    for (const e of Object.values(outbox)) m.set(`${e.date}#${e.amalKey}`, e);
    return [...m.values()];
  }, [server, amalCache, outbox]);

  const ranked = React.useMemo(() => mostUsedAmals(entries, defs, today, category), [entries, defs, today, category]);
  if (ranked.length === 0) return null;
  const todayValue = (key: string) => entries.find((e) => e.date === today && e.amalKey === key)?.value;

  return (
    <section aria-labelledby="most-used-h" className="space-y-2">
      <h2 id="most-used-h" className="flex items-center gap-2 text-base font-bold">
        <Flame className="size-4 text-gold" aria-hidden /> সর্বাধিক ব্যবহৃত
      </h2>
      <div
        className={cn(
          "grid grid-cols-1 gap-2",
          ranked.length === 3 ? "min-[480px]:grid-cols-3" : ranked.length === 2 ? "min-[480px]:grid-cols-2" : ""
        )}
      >
        {ranked.map(({ def, daysUsed }) => {
          const current = todayValue(def.key);
          const done = amalPoints(current, def, category) >= 1;
          const next = quickValue(def, current);
          const counted = def.inputType === "count" || def.inputType === "quantity";
          return (
            <div key={def.key} className="flex items-center gap-3 rounded-xl border border-border bg-card p-3 shadow-card min-[480px]:flex-col min-[480px]:items-stretch">
              <div className="min-w-0 flex-1">
                <p className="line-clamp-2 text-sm font-bold">{def.titleBn}</p>
                <span className="mt-1 inline-flex items-center gap-1 rounded-full bg-gold-soft px-2 py-0.5 text-[11px] font-semibold text-gold-text-foreground">
                  <Flame className="size-3" aria-hidden /> ৩০ দিনে {toBn(daysUsed)} দিন
                </span>
              </div>
              {done && !counted ? (
                <span className="inline-flex h-10 shrink-0 items-center justify-center gap-1 rounded-full bg-success/10 px-3 text-sm font-semibold text-success">
                  <Check className="size-4" /> আজ লেখা হয়েছে
                </span>
              ) : next != null ? (
                <Button
                  variant="secondary"
                  className="h-10 shrink-0 rounded-full"
                  onClick={() => {
                    writeEntry({
                      amalKey: def.key,
                      date: today,
                      value: next,
                      source: "quick:home",
                      clientUpdatedAt: new Date().toISOString(),
                    });
                    toast.success(counted ? `${def.titleBn}: আজ ${toBn(Number(next))}` : `${def.titleBn} — লেখা হয়েছে`);
                  }}
                >
                  {counted && typeof current === "number" && current > 0 ? `আরও ১ (এখন ${toBn(current)})` : "আজ লিখুন"}
                </Button>
              ) : null}
            </div>
          );
        })}
      </div>
    </section>
  );
}

export function IlmPreview() {
  const nav = useApp((s) => s.nav);
  const [counts, setCounts] = React.useState<{ courses: number | null; quizzes: number | null }>({
    courses: null,
    quizzes: null,
  });
  React.useEffect(() => {
    let alive = true;
    getPack("courses")
      .then((p) => alive && setCounts((c) => ({ ...c, courses: p.courses.length })))
      .catch(() => null);
    getPack("quizzes")
      .then((p) => alive && setCounts((c) => ({ ...c, quizzes: p.quizzes.length })))
      .catch(() => null);
    return () => {
      alive = false;
    };
  }, []);

  const cards = [
    {
      icon: GraduationCap,
      title: "কোর্স",
      desc: "ধাপে ধাপে দ্বীন শেখা — পাঠ, ভিডিও ও অগ্রগতি",
      count: counts.courses,
      go: () => nav("ilm", "courses"),
    },
    {
      icon: ListChecks,
      title: "কুইজ",
      desc: "যা শিখলেন যাচাই করুন, স্কোর রাখুন",
      count: counts.quizzes,
      go: () => nav("ilm", "quizzes"),
    },
  ];

  return (
    <section aria-labelledby="ilm-preview-h" className="space-y-2">
      <div className="flex items-center justify-between">
        <h2 id="ilm-preview-h" className="flex items-center gap-2 text-base font-bold">
          <GraduationCap className="size-4 text-primary" aria-hidden /> ইলম
        </h2>
        <button
          type="button"
          onClick={() => nav("ilm")}
          className="flex h-9 items-center gap-0.5 rounded-full px-2 text-sm font-semibold text-primary hover:bg-primary-soft"
        >
          সব দেখুন <ChevronLeft className="size-4 flip-rtl" />
        </button>
      </div>
      <div className="grid grid-cols-2 gap-2">
        {cards.map(({ icon: Icon, title, desc, count, go }) => (
          <button
            key={title}
            type="button"
            onClick={go}
            className="rounded-xl border border-border bg-card p-4 text-start shadow-card transition-colors hover:bg-muted/50"
          >
            <span className="flex size-11 items-center justify-center rounded-full bg-primary-soft text-primary">
              <Icon className="size-5" aria-hidden />
            </span>
            <span className="mt-2 block font-bold">{title}</span>
            <span className="mt-0.5 line-clamp-2 block text-xs text-muted-foreground">{desc}</span>
            {count ? (
              <span className="mt-1 block text-xs font-semibold text-primary">
                {toBn(count)}টি {title}
              </span>
            ) : null}
          </button>
        ))}
      </div>
    </section>
  );
}
