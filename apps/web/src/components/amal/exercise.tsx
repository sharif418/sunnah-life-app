"use client";

// শরীরচর্চা — the exercise log (AMOL-14, mobile parity: exercise_screen.dart).
// A session's minutes ADD to the day's diary amal `exercise_minutes`, so
// they sync and count like any entry; the session detail (kind, time) stays
// in this browser for 14 days so a mistaken one can be taken back off.

import * as React from "react";
import {
  ArrowLeft,
  Bike,
  Dumbbell,
  Footprints,
  HeartPulse,
  Minus,
  MoreHorizontal,
  Plus,
  Trophy,
  Waves,
  X,
  Zap,
} from "lucide-react";
import { toast } from "sonner";
import { useApp } from "@/lib/store";
import { addDays, parseKey, toBn } from "@/lib/calendars";
import type { AmalEntry } from "@/types/domain";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";

const KEY = "exercise_minutes";
const DAILY = 20;
const WEEKLY = 150;
const PREF = "sl-exercise-sessions";

const TYPES = [
  { key: "walk", label: "হাঁটা", icon: Footprints },
  { key: "run", label: "দৌড়", icon: Zap },
  { key: "bike", label: "সাইকেল", icon: Bike },
  { key: "workout", label: "ব্যায়াম", icon: Dumbbell },
  { key: "sport", label: "খেলাধুলা", icon: Trophy },
  { key: "swim", label: "সাঁতার", icon: Waves },
  { key: "other", label: "অন্যান্য", icon: MoreHorizontal },
] as const;
type Kind = (typeof TYPES)[number]["key"];
const WEEKDAYS = ["রবি", "সোম", "মঙ্গল", "বুধ", "বৃহঃ", "শুক্র", "শনি"];

interface Session {
  t: Kind;
  m: number;
  at: string;
}

function readSessions(): Record<string, Session[]> {
  try {
    const raw = JSON.parse(localStorage.getItem(PREF) ?? "{}");
    return raw && typeof raw === "object" && !Array.isArray(raw) ? (raw as Record<string, Session[]>) : {};
  } catch {
    return {};
  }
}

function saveSessions(all: Record<string, Session[]>, today: string) {
  const from = addDays(today, -13);
  const kept = Object.fromEntries(Object.entries(all).filter(([d, l]) => d >= from && l.length));
  try {
    localStorage.setItem(PREF, JSON.stringify(kept));
  } catch {}
}

const minutesOf = (v: unknown) => (typeof v === "number" ? Math.round(v) : Math.round(Number(v) || 0));

export function ExerciseView({ entries, today, onBack }: { entries: AmalEntry[]; today: string; onBack: () => void }) {
  const writeEntry = useApp((s) => s.writeEntry);
  const [kind, setKind] = React.useState<Kind>("walk");
  const [minutes, setMinutes] = React.useState(20);
  const [sessions, setSessions] = React.useState<Record<string, Session[]>>({});
  React.useEffect(() => setSessions(readSessions()), []);

  const byDate = React.useMemo(() => {
    const m = new Map<string, number>();
    for (const e of entries) if (e.amalKey === KEY) m.set(e.date, minutesOf(e.value));
    return m;
  }, [entries]);
  const on = (d: string) => byDate.get(d) ?? 0;
  const todayMin = on(today);
  const week = Array.from({ length: 7 }, (_, i) => addDays(today, i - 6));
  const weekTotal = week.reduce((a, d) => a + on(d), 0);
  const weekMax = Math.max(DAILY, ...week.map(on));
  const todays = sessions[today] ?? [];

  const write = (value: number) =>
    writeEntry({
      amalKey: KEY,
      date: today,
      value: Math.max(0, Math.min(24 * 60, value)),
      source: "exercise",
      clientUpdatedAt: new Date().toISOString(),
    });

  const add = () => {
    write(todayMin + minutes);
    const next = { ...sessions, [today]: [...todays, { t: kind, m: minutes, at: new Date().toISOString() }] };
    setSessions(next);
    saveSessions(next, today);
    toast.success(`${TYPES.find((t) => t.key === kind)!.label} · ${toBn(minutes)} মিনিট — ডায়েরিতে যোগ হয়েছে`);
  };

  const undo = (i: number) => {
    const s = todays[i];
    if (!s) return;
    write(todayMin - s.m);
    const next = { ...sessions, [today]: todays.filter((_, j) => j !== i) };
    setSessions(next);
    saveSessions(next, today);
  };

  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" className="h-9 rounded-full" onClick={onBack}>
          <ArrowLeft className="size-4 rtl:rotate-180" /> ফিরে যান
        </Button>
        <h2 className="flex-1 text-lg font-bold">শরীরচর্চা</h2>
      </div>

      <Card className="py-0">
        <CardContent className="space-y-2 p-4">
          <p className="font-bold">আজকের শরীরচর্চা</p>
          <p className="flex items-baseline gap-2">
            <span className="text-4xl font-extrabold text-primary">{toBn(todayMin)}</span>
            <span className="text-muted-foreground">/ {toBn(DAILY)} মিনিট</span>
          </p>
          <Progress value={Math.min(100, (100 * todayMin) / DAILY)} className="h-2" />
          <p className={cn("text-sm", todayMin >= DAILY ? "font-semibold text-success" : "text-muted-foreground")}>
            {todayMin >= DAILY ? "আজকের লক্ষ্য পূরণ হয়েছে — আলহামদুলিল্লাহ" : `লক্ষ্য পূরণে আর ${toBn(DAILY - todayMin)} মিনিট`}
          </p>
        </CardContent>
      </Card>

      <Card className="py-0">
        <CardContent className="space-y-4 p-4">
          <p className="flex items-center gap-2 font-bold">
            <HeartPulse className="size-4 text-primary" aria-hidden /> সেশন যোগ করুন
          </p>
          <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="শরীরচর্চার ধরন">
            {TYPES.map(({ key, label, icon: Icon }) => (
              <button
                key={key}
                type="button"
                role="radio"
                aria-checked={kind === key}
                onClick={() => setKind(key)}
                className={cn(
                  "inline-flex h-10 items-center gap-1.5 rounded-full border px-3.5 text-sm font-semibold",
                  kind === key ? "border-primary bg-primary-soft text-primary" : "border-border bg-card hover:bg-muted"
                )}
              >
                <Icon className="size-4" aria-hidden /> {label}
              </button>
            ))}
          </div>
          <div className="flex items-center gap-3">
            <Button variant="outline" size="icon" className="size-11 rounded-full" aria-label="৫ মিনিট কমান" disabled={minutes <= 5} onClick={() => setMinutes((m) => m - 5)}>
              <Minus className="size-5" />
            </Button>
            <p className="flex-1 text-center text-2xl font-bold">{toBn(minutes)} মিনিট</p>
            <Button variant="outline" size="icon" className="size-11 rounded-full" aria-label="৫ মিনিট বাড়ান" disabled={minutes >= 240} onClick={() => setMinutes((m) => m + 5)}>
              <Plus className="size-5" />
            </Button>
          </div>
          <div className="flex flex-wrap justify-center gap-2">
            {[10, 15, 20, 30, 45, 60].map((m) => (
              <button
                key={m}
                type="button"
                onClick={() => setMinutes(m)}
                aria-pressed={minutes === m}
                className={cn(
                  "h-10 min-w-12 rounded-full border px-3 text-sm font-semibold",
                  minutes === m ? "border-primary bg-primary-soft text-primary" : "border-border bg-card hover:bg-muted"
                )}
              >
                {toBn(m)}
              </button>
            ))}
          </div>
          <Button className="h-11 w-full rounded-xl" onClick={add}>
            <Plus className="size-4" /> ডায়েরিতে যোগ করুন
          </Button>
        </CardContent>
      </Card>

      {todays.length ? (
        <Card className="py-0">
          <CardContent className="p-2">
            <p className="px-2 pt-2 text-sm font-bold">আজকের সেশন</p>
            <ul>
              {todays.map((s, i) => {
                const t = TYPES.find((x) => x.key === s.t) ?? TYPES[TYPES.length - 1];
                const time = new Date(s.at);
                return (
                  <li key={`${s.at}-${i}`} className="flex items-center gap-3 rounded-lg px-2 py-2">
                    <t.icon className="size-5 shrink-0 text-primary" aria-hidden />
                    <span className="min-w-0 flex-1 text-sm">
                      <span className="font-semibold">{t.label}</span>
                      <span className="text-muted-foreground">
                        {" "}
                        · {toBn(s.m)} মিনিট · {toBn(`${time.getHours() % 12 || 12}:${String(time.getMinutes()).padStart(2, "0")}`)}
                      </span>
                    </span>
                    <Button variant="ghost" size="icon" className="size-10 rounded-full" aria-label="সেশনটি বাদ দিন" onClick={() => undo(i)}>
                      <X className="size-4" />
                    </Button>
                  </li>
                );
              })}
            </ul>
          </CardContent>
        </Card>
      ) : null}

      <Card className="py-0">
        <CardContent className="space-y-3 p-4">
          <p className="font-bold">গত ৭ দিন</p>
          <div className="flex h-32 items-end gap-2" role="img" aria-label={`গত ৭ দিনে মোট ${toBn(weekTotal)} মিনিট`}>
            {week.map((d) => {
              const v = on(d);
              return (
                <div key={d} className="flex h-full flex-1 flex-col items-center justify-end gap-1">
                  <span className="text-[11px] font-semibold">{toBn(v)}</span>
                  <div
                    className={cn("w-full rounded-md", v >= DAILY ? "bg-primary" : v > 0 ? "bg-gold" : "bg-border")}
                    style={{ height: `${Math.max(4, (100 * v) / weekMax)}%` }}
                  />
                  <span className={cn("text-[11px]", d === today ? "font-bold text-primary" : "text-muted-foreground")}>
                    {WEEKDAYS[parseKey(d).getDay()]}
                  </span>
                </div>
              );
            })}
          </div>
          <p className="font-semibold">
            এই ৭ দিনে মোট: {toBn(weekTotal)} / {toBn(WEEKLY)} মিনিট
          </p>
          <p className="text-xs text-muted-foreground">বিশ্ব স্বাস্থ্য সংস্থার পরামর্শ: সপ্তাহে অন্তত ১৫০ মিনিট মাঝারি শরীরচর্চা।</p>
        </CardContent>
      </Card>

      <p className="text-center text-sm text-muted-foreground">
        “শক্তিশালী মুমিন আল্লাহর কাছে দুর্বল মুমিনের চেয়ে উত্তম ও প্রিয়।” — সহীহ মুসলিম ২৬৬৪
      </p>
    </div>
  );
}
