"use client";

// আজকের আমল সারসংক্ষেপ — ক্যাটাগরিভিত অগ্রগতি রিং + গণনা।
// গেস্ট: স্থানীয় (localStorage) এন্ট্রি থেকে; সাইন-ইন: সার্ভার + আনসিঙ্কড আউটবক্স।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { dateKey, isAyyamBeez, toBn, weekdayBn } from "@/lib/calendars";
import {
  AMAL_CATEGORY_LABELS_BN,
  type AmalCategory,
  type AmalDefinition,
  type AmalEntry,
  type AmalValue,
} from "@/types/domain";
import { ClipboardCheck, ChevronLeft, RefreshCw } from "lucide-react";
import { cn } from "@/lib/utils";

const CATEGORY_ORDER: AmalCategory[] = ["salah", "quran", "dhikr", "dawat", "lifestyle", "sunnah"];

interface CategoryStat {
  category: AmalCategory;
  done: number;
  total: number;
}

/** আজকের তালিকায় এই আমলটি আসবে কি? (weekly:any দিন-নির্দিষ্ট নয় — বাদ) */
function appliesToday(def: AmalDefinition, d: Date): boolean {
  const dow = d.getDay();
  switch (def.cadence) {
    case "daily":
      return true;
    case "weekly:fri":
      return dow === 5;
    case "weekly:mon_thu":
      return dow === 1 || dow === 4;
    case "weekly:any":
      return false;
    case "monthly:ayyam_beez":
      return isAyyamBeez(d);
    default:
      return false;
  }
}

/** সার্ভারের amalPoints-এর ক্লায়েন্ট কপি: ১=সম্পূর্ণ, ০.৫=আংশিক। */
function pointsFor(value: AmalValue | undefined, def: AmalDefinition, userCategory: string): number {
  if (value === undefined) return 0;
  if (def.inputType === "tristate") return value === "jamaat" || value === "alone" ? 1 : 0;
  if (def.inputType === "boolean") return value === true ? 1 : 0;
  if (def.inputType === "count" || def.inputType === "quantity") {
    const n = typeof value === "number" ? value : Number(value);
    if (!isFinite(n) || n <= 0) return 0;
    const target = def.target?.[userCategory] ?? def.target?.general ?? 1;
    return n >= target ? 1 : 0.5;
  }
  if (def.inputType === "text") return typeof value === "string" && value.trim().length > 0 ? 1 : 0;
  return 0;
}

export function AmalSummaryCard() {
  const { user, amalCache, outbox, nav } = useApp();
  const today = dateKey();
  const todayDate = React.useMemo(() => new Date(), []);

  const [defs, setDefs] = React.useState<AmalDefinition[] | null>(null);
  const [serverEntries, setServerEntries] = React.useState<AmalEntry[] | null>(null);
  const [error, setError] = React.useState(false);
  const [reload, setReload] = React.useState(0);

  React.useEffect(() => {
    let alive = true;
    setDefs(null);
    setServerEntries(null);
    setError(false);
    api
      .amalDefinitions()
      .then((r) => alive && setDefs(r.definitions))
      .catch(() => alive && setError(true));
    if (user) {
      api
        .amalEntries(today, today)
        .then((r) => alive && setServerEntries(r.entries))
        .catch(() => alive && setServerEntries([]));
    } else {
      setServerEntries([]);
    }
    return () => {
      alive = false;
    };
  }, [user, today, reload]);

  // আজকের মান: সার্ভার (সাইন-ইন হলে) → উপরে আনসিঙ্কড লোকাল এডিট; গেস্ট: শুধু লোকাল।
  const values = React.useMemo(() => {
    const m = new Map<string, AmalValue>();
    if (user) {
      for (const e of serverEntries ?? []) m.set(e.amalKey, e.value);
      for (const e of Object.values(outbox)) if (e.date === today) m.set(e.amalKey, e.value);
    } else {
      for (const e of Object.values(amalCache)) if (e.date === today) m.set(e.amalKey, e.value);
    }
    return m;
  }, [user, serverEntries, outbox, amalCache, today]);

  const { applicable, byCategory, doneCount, pct } = React.useMemo(() => {
    const applicable = (defs ?? []).filter((d) => appliesToday(d, todayDate));
    const userCategory = user?.category ?? "general";
    let points = 0;
    const stats = new Map<AmalCategory, CategoryStat>();
    for (const def of applicable) {
      const p = pointsFor(values.get(def.key), def, userCategory);
      points += p;
      const s = stats.get(def.category) ?? { category: def.category, done: 0, total: 0 };
      s.total += 1;
      s.done += p;
      stats.set(def.category, s);
    }
    return {
      applicable,
      byCategory: CATEGORY_ORDER.filter((c) => stats.has(c)).map((c) => stats.get(c)!),
      doneCount: Math.round(points),
      pct: applicable.length ? Math.round((100 * points) / applicable.length) : 0,
    };
  }, [defs, values, user, todayDate]);

  return (
    <Card className="rounded-xl shadow-card">
      <CardContent className="p-4 sm:p-5">
        <div className="flex items-center gap-4">
          <ProgressRing pct={pct} />
          <div className="flex-1 min-w-0">
            <div className="flex items-center justify-between gap-2">
              <h2 className="font-bold">আজকের আমল</h2>
              <span className="text-xs text-muted-foreground">{weekdayBn(todayDate)}</span>
            </div>
            <p className="mt-0.5 text-sm text-muted-foreground">
              {defs === null && !error ? (
                "লোড হচ্ছে…"
              ) : error ? (
                "আনা যায়নি"
              ) : (
                <>
                  {toBn(doneCount)}/{toBn(applicable.length)} সম্পন্ন ·{" "}
                  <strong className="text-primary">{toBn(pct)}%</strong>
                </>
              )}
            </p>
          </div>
        </div>

        {error ? (
          <div className="mt-4 rounded-xl bg-alert-soft border border-alert/20 p-4 text-center">
            <p className="text-sm">আমলের তালিকা আনা যায়নি।</p>
            <Button
              variant="outline"
              className="mt-2 h-11 rounded-xl"
              onClick={() => setReload((r) => r + 1)}
            >
              <RefreshCw className="size-4" /> আবার চেষ্টা করুন
            </Button>
          </div>
        ) : defs === null || (user && serverEntries === null) ? (
          <div className="mt-4 grid grid-cols-2 gap-2">
            {[0, 1, 2, 3].map((i) => (
              <Skeleton key={i} className="h-10 rounded-xl" />
            ))}
          </div>
        ) : byCategory.length === 0 ? (
          <p className="mt-4 rounded-xl bg-muted p-4 text-center text-sm text-muted-foreground">
            আজকের জন্য কোনো আমল নির্ধারিত নেই।
          </p>
        ) : (
          <div className="mt-4 grid grid-cols-2 gap-2">
            {byCategory.map((s) => {
              const cp = s.total ? Math.round((100 * s.done) / s.total) : 0;
              return (
                <div key={s.category} className="rounded-xl bg-muted/60 px-3 py-2.5" aria-label={`${AMAL_CATEGORY_LABELS_BN[s.category]} ${cp} শতাংশ`}>
                  <div className="flex items-center justify-between gap-1">
                    <span className="text-xs font-medium text-foreground/80 truncate">
                      {AMAL_CATEGORY_LABELS_BN[s.category]}
                    </span>
                    <span className="text-[11px] font-semibold text-muted-foreground tabular-nums shrink-0">
                      {toBn(Math.round(s.done))}/{toBn(s.total)}
                    </span>
                  </div>
                  <div className="mt-1.5 h-1.5 rounded-full bg-border overflow-hidden">
                    <div
                      className={cn("h-full rounded-full transition-all motion-base", cp >= 100 ? "bg-success" : "bg-primary")}
                      style={{ width: `${Math.min(100, cp)}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )}

        <Button className="mt-4 w-full h-11 rounded-xl" onClick={() => nav("amal")}>
          <ClipboardCheck className="size-4" />
          আজকের আমল পূরণ করুন
          <ChevronLeft className="size-4 flip-rtl" />
        </Button>
      </CardContent>
    </Card>
  );
}

function ProgressRing({ pct }: { pct: number }) {
  const r = 30;
  const c = 2 * Math.PI * r;
  const filled = Math.min(100, Math.max(0, pct));
  return (
    <div className="relative shrink-0" role="img" aria-label={`আজকের আমল সম্পন্নতা ${pct} শতাংশ`}>
      <svg viewBox="0 0 72 72" className="size-[72px]">
        <circle cx="36" cy="36" r={r} className="fill-none stroke-muted" strokeWidth="7" />
        <circle
          cx="36"
          cy="36"
          r={r}
          className={cn("fill-none transition-all motion-base", filled >= 100 ? "stroke-success" : "stroke-primary")}
          strokeWidth="7"
          strokeLinecap="round"
          strokeDasharray={c}
          strokeDashoffset={c - (c * filled) / 100}
          transform="rotate(-90 36 36)"
        />
      </svg>
      <span className="absolute inset-0 flex items-center justify-center text-sm font-extrabold tabular-nums">
        {toBn(filled)}%
      </span>
    </div>
  );
}
