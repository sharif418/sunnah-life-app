"use client";

// অভ্যাস গড়ার চ্যালেঞ্জ (mobile parity): pick one diary amal and a span
// (৭ / ২১ / ৪০ দিন); the last N days show which were kept, the streak and
// how far the challenge has come. Read from the same diary entries.

import * as React from "react";
import { ArrowLeft, Check, Flame } from "lucide-react";
import { addDays, toBn } from "@/lib/calendars";
import { cn } from "@/lib/utils";
import type { AmalDefinition, AmalEntry, UserCategory } from "@/types/domain";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { useHijriAdjust } from "@/hooks/use-hijri-adjust";
import { amalPoints, isAmalDay } from "./amal-logic";

const SPANS = [7, 21, 40] as const;
const PREF = "sl-habit";

function readPref(): { key?: string; days?: number } {
  try {
    return JSON.parse(localStorage.getItem(PREF) ?? "{}") as { key?: string; days?: number };
  } catch {
    return {};
  }
}

export function HabitView({
  defs,
  entries,
  category,
  today,
  onBack,
}: {
  defs: AmalDefinition[];
  entries: AmalEntry[];
  category: UserCategory;
  today: string;
  onBack: () => void;
}) {
  const hijriAdjust = useHijriAdjust();
  const daily = React.useMemo(() => defs.filter((d) => d.cadence === "daily"), [defs]);
  const [key, setKey] = React.useState<string>(() => daily[0]?.key ?? "");
  const [days, setDays] = React.useState<number>(7);
  React.useEffect(() => {
    const p = readPref();
    if (p.key && daily.some((d) => d.key === p.key)) setKey(p.key);
    if (p.days && (SPANS as readonly number[]).includes(p.days)) setDays(p.days);
  }, [daily]);
  React.useEffect(() => {
    try {
      localStorage.setItem(PREF, JSON.stringify({ key, days }));
    } catch {}
  }, [key, days]);

  const def = daily.find((d) => d.key === key) ?? daily[0];
  const valueOn = React.useMemo(() => {
    const m = new Map<string, AmalEntry["value"]>();
    for (const e of entries) if (e.amalKey === def?.key) m.set(e.date, e.value);
    return m;
  }, [entries, def?.key]);

  if (!def) return null;
  const kept = (day: string) => isAmalDay(def, day, hijriAdjust) && amalPoints(valueOn.get(day), def, category) >= 1;
  const span = Array.from({ length: days }, (_, i) => addDays(today, -(days - 1 - i)));
  const keptCount = span.filter(kept).length;
  let streak = 0;
  for (let d = kept(today) ? today : addDays(today, -1); kept(d); d = addDays(d, -1)) streak++;

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" className="h-9 rounded-full" onClick={onBack}>
          <ArrowLeft className="size-4 rtl:rotate-180" /> ফিরে যান
        </Button>
        <h2 className="flex-1 text-lg font-bold">অভ্যাস গড়ার চ্যালেঞ্জ</h2>
      </div>

      <Card className="py-0">
        <CardContent className="space-y-3 p-4">
          <label className="block space-y-1.5">
            <span className="text-sm font-semibold">কোন আমলটি অভ্যাসে আনবেন?</span>
            <select
              value={def.key}
              onChange={(e) => setKey(e.target.value)}
              className="h-11 w-full rounded-xl border border-input bg-background px-3 text-sm"
            >
              {daily.map((d) => (
                <option key={d.key} value={d.key}>
                  {d.titleBn}
                </option>
              ))}
            </select>
          </label>
          <div className="grid grid-cols-3 gap-2" role="radiogroup" aria-label="কত দিনের চ্যালেঞ্জ">
            {SPANS.map((n) => (
              <button
                key={n}
                type="button"
                role="radio"
                aria-checked={days === n}
                onClick={() => setDays(n)}
                className={cn(
                  "h-10 rounded-xl border text-sm font-semibold",
                  days === n ? "border-primary bg-primary text-primary-foreground" : "border-border bg-card hover:bg-muted"
                )}
              >
                {toBn(n)} দিন
              </button>
            ))}
          </div>
        </CardContent>
      </Card>

      <Card className="py-0">
        <CardContent className="space-y-3 p-4">
          <div className="flex items-center gap-2">
            <p className="flex-1 font-bold">{def.titleBn}</p>
            {streak > 0 ? (
              <span className="inline-flex items-center gap-1 rounded-full bg-gold-soft px-2.5 py-0.5 text-xs font-semibold text-gold-text-foreground">
                <Flame className="size-3.5" /> {toBn(streak)} দিন ধারাবাহিক
              </span>
            ) : null}
          </div>
          <Progress value={(100 * keptCount) / days} className="h-2" />
          <p className="text-sm text-muted-foreground">
            {toBn(keptCount)} / {toBn(days)} দিন
          </p>
          <div className={cn("grid gap-1.5", days <= 7 ? "grid-cols-7" : "grid-cols-7 sm:grid-cols-10")}>
            {span.map((d) => {
              const ok = kept(d);
              return (
                <div
                  key={d}
                  title={d}
                  className={cn(
                    "flex aspect-square items-center justify-center rounded-lg text-[11px] font-semibold",
                    ok ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground",
                    d === today && "ring-2 ring-gold"
                  )}
                >
                  {ok ? <Check className="size-3.5" aria-label="রাখা হয়েছে" /> : toBn(Number(d.slice(8)))}
                </div>
              );
            })}
          </div>
          <p className="text-xs leading-relaxed text-muted-foreground">
            আজকের আমল ডায়েরিতে লিখলেই এখানে গণনা হয়। একদিন ছুটে গেলে হতাশ না হয়ে আবার শুরু করুন।
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
