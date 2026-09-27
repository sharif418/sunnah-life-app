"use client";

// দোয়া ও আযকার — দোয়া ভাণ্ডার (ক্যাটাগরি + সার্চ, আরবি + বাংলা অর্থ + দলিল)
// এবং মাসনূন আযকার (সকাল/সন্ধ্যা/নামাজ-পরে) সহ বৈশিষ্ট্যসংখ্যা কাউন্টার।
// সেট সম্পূর্ণ হলে আমলনামায় স্বয়ংক্রিয়ভাবে টিক লাগে (auto:adhkar:…)।

import * as React from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Check, Copy, HandHeart, Quote, RotateCcw, Search, Sparkles } from "lucide-react";
import { dateKey, toBn } from "@/lib/calendars";
import { getPack } from "@/lib/content";
import type { AdhkarPack, DuaPack } from "@/lib/content";
import type { DhikrSet, DuaItem } from "@/types/domain";
import { useApp } from "@/lib/store";
import type { AmalEntry } from "@/types/domain";
import { EmptyState, SkeletonRows, StatusPill, copyText, useAsync } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Progress } from "@/components/ui/progress";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";

export type DuasMode = "duas" | "adhkar";

export function DuasSection({ mode, highlightId }: { mode: DuasMode; highlightId?: string }) {
  const { nav } = useApp();
  return (
    <div>
      <Tabs value={mode} onValueChange={(v) => nav("ilm", v as DuasMode)}>
        <TabsList className="h-11 w-full rounded-xl p-1">
          <TabsTrigger value="duas" className="h-9 flex-1 rounded-lg text-sm">
            দোয়া ভাণ্ডার
          </TabsTrigger>
          <TabsTrigger value="adhkar" className="h-9 flex-1 rounded-lg text-sm">
            আযকার
          </TabsTrigger>
        </TabsList>
      </Tabs>
      <div className="mt-4">
        {mode === "duas" ? <DuasLibrary highlightId={highlightId} /> : <AdhkarLibrary />}
      </div>
    </div>
  );
}

// ── দোয়া ভাণ্ডার ─────────────────────────────────────────────────────────────

function DuasLibrary({ highlightId }: { highlightId?: string }) {
  const { data, loading, error } = useAsync<DuaPack>(() => getPack("duas") as Promise<DuaPack>);
  const [query, setQuery] = React.useState("");
  const [category, setCategory] = React.useState<string | null>(null);

  if (loading) return <SkeletonRows count={5} className="h-28" />;
  if (error) return <EmptyState icon={HandHeart} title="দোয়া লোড করা যায়নি" hint={error} />;
  const pack = data;
  const items = pack?.items ?? [];
  const categories = pack?.categories ?? [];
  if (items.length === 0) return <EmptyState icon={HandHeart} title="এখনো কোনো দোয়া নেই" />;

  const q = query.trim();
  const visible = items.filter((d) => {
    if (category && d.category !== category) return false;
    if (!q) return true;
    return (
      d.titleBn.includes(q) ||
      d.translationBn.includes(q) ||
      (d.translitBn ?? "").includes(q)
    );
  });

  return (
    <div>
      <div className="relative">
        <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="দোয়া খুঁজুন…"
          className="h-11 rounded-xl ps-9"
          aria-label="দোয়া খুঁজুন"
        />
      </div>

      <div className="no-scrollbar mt-3 flex gap-1.5 overflow-x-auto pb-0.5">
        <CategoryChip label="সব দেখুন" active={category === null} onClick={() => setCategory(null)} />
        {categories.map((c) => (
          <CategoryChip key={c.key} label={c.labelBn} active={category === c.key} onClick={() => setCategory(c.key)} />
        ))}
      </div>

      <div className="mt-4 space-y-3">
        {visible.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">কোনো দোয়া মেলেনি</p>
        ) : (
          visible.map((d) => <DuaCard key={d.id} dua={d} highlighted={highlightId === d.id} />)
        )}
      </div>
    </div>
  );
}

function CategoryChip({ label, active, onClick }: { label: string; active: boolean; onClick: () => void }) {
  return (
    <button
      onClick={onClick}
      className={cn(
        "tap-target shrink-0 rounded-full px-3.5 text-xs font-semibold transition-colors",
        active ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
      )}
      aria-pressed={active}
    >
      {label}
    </button>
  );
}

function DuaCard({ dua, highlighted }: { dua: DuaItem; highlighted: boolean }) {
  const [copied, setCopied] = React.useState(false);
  const copy = async () => {
    const ok = await copyText(`${dua.titleBn}\n\n${dua.arabic}\n\n${dua.translationBn}\n— ${dua.reference}`);
    if (ok) {
      setCopied(true);
      toast.success("দোয়াটি কপি হয়েছে");
      window.setTimeout(() => setCopied(false), 2000);
    } else {
      toast.error("কপি করা যায়নি");
    }
  };

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.15 }}>
      <Card className={cn("rounded-xl p-4 shadow-card", highlighted && "ring-2 ring-primary")}>
        <div className="flex items-start gap-2">
          <h3 className="flex-1 text-[15px] font-bold leading-snug">{dua.titleBn}</h3>
          <Button variant="ghost" size="icon" className="size-9 rounded-full" aria-label="দোয়া কপি করুন" onClick={copy}>
            {copied ? <Check className="size-4 text-primary" /> : <Copy className="size-4 text-muted-foreground" />}
          </Button>
        </div>
        <p dir="rtl" className="mt-3 text-right font-arabic text-xl leading-loose sm:text-[22px]">
          {dua.arabic}
        </p>
        {dua.translitBn ? <p className="mt-2 text-xs italic text-muted-foreground">{dua.translitBn}</p> : null}
        <p className="mt-2 text-sm leading-relaxed">{dua.translationBn}</p>
        <p className="mt-2 flex items-center gap-1 text-xs font-medium text-primary">
          <Quote className="size-3 shrink-0" />
          {dua.reference}
        </p>
        {dua.virtue ? (
          <p className="mt-2 rounded-lg bg-gold-soft px-3 py-2 text-xs leading-relaxed text-gold-text-foreground">
            <Sparkles className="me-1 inline size-3" />
            {dua.virtue}
          </p>
        ) : null}
      </Card>
    </motion.div>
  );
}

// ── আযকার ───────────────────────────────────────────────────────────────────

const SET_META: Record<string, { amalKey: string; source: string }> = {
  morning: { amalKey: "adhkar_morning", source: "auto:adhkar:morning" },
  evening: { amalKey: "adhkar_evening", source: "auto:adhkar:evening" },
  post_salat: { amalKey: "post_salat_tasbih", source: "auto:adhkar:post_salat" },
};

const SET_TITLES: Record<string, string> = {
  morning: "সকালের মাসনূন আযকার",
  evening: "সন্ধ্যার মাসনূন আযকার",
  post_salat: "নামাজের পরের আযকার ও দোয়া কার্ড",
};

function AdhkarLibrary() {
  const { data, loading, error } = useAsync<AdhkarPack>(() => getPack("adhkar") as Promise<AdhkarPack>);
  if (loading) return <SkeletonRows count={3} className="h-32" />;
  if (error) return <EmptyState icon={Sparkles} title="আযকার লোড করা যায়নি" hint={error} />;
  const sets: DhikrSet[] = data?.sets ?? [];
  if (sets.length === 0) return <EmptyState icon={Sparkles} title="এখনো কোনো আযকার নেই" />;

  return (
    <div className="space-y-5">
      {sets.map((set) => (
        <DhikrSetCard key={set.id} set={set} />
      ))}
      <p className="pb-2 text-center text-xs text-muted-foreground">
        সেট সম্পূর্ণ করলে আজকের আমলনামায় স্বয়ংক্রিয়ভাবে টিক লেগে যাবে।
      </p>
    </div>
  );
}

function DhikrSetCard({ set }: { set: DhikrSet }) {
  const meta = SET_META[set.period] ?? { amalKey: "", source: "auto:adhkar:other" };
  const [counts, setCounts] = React.useState<Record<string, number>>({});
  const [ticked, setTicked] = React.useState(false);

  const doneCount = set.items.filter((i) => (counts[`${set.id}:${i.id}`] ?? 0) >= i.count).length;
  const allDone = doneCount === set.items.length;

  const tick = (itemId: string) => {
    const next = { ...counts, [`${set.id}:${itemId}`]: (counts[`${set.id}:${itemId}`] ?? 0) + 1 };
    setCounts(next);
    // set completed with this tap?
    const willComplete = set.items.every((it) => (next[`${set.id}:${it.id}`] ?? 0) >= it.count);
    if (willComplete && !ticked && meta.amalKey) {
      setTicked(true);
      const entry: AmalEntry = {
        amalKey: meta.amalKey,
        date: dateKey(),
        value: true,
        source: meta.source,
        clientUpdatedAt: new Date().toISOString(),
      };
      useApp.getState().writeEntry(entry);
      toast.success(
        `আলহামদুলিল্লাহ! ${SET_TITLES[set.period] ?? set.titleBn} সম্পূর্ণ — আজকের আমলনামায় যুক্ত হয়েছে`
      );
    }
  };

  const reset = () => setCounts({});

  return (
    <Card className="rounded-xl p-4 shadow-card">
      <div className="flex items-center gap-2">
        <h3 className="text-[15px] font-bold">{set.titleBn}</h3>
        {set.totalMin ? <StatusPill tone="muted">≈ {toBn(set.totalMin)} মিনিট</StatusPill> : null}
        {allDone ? (
          <span className="ms-auto inline-flex items-center gap-1 text-xs font-bold text-primary">
            <Check className="size-4" /> সম্পন্ন
          </span>
        ) : (
          <button
            onClick={reset}
            className="ms-auto inline-flex items-center gap-1 text-xs text-muted-foreground hover:text-foreground"
            aria-label="গুনতি রিসেট করুন"
          >
            <RotateCcw className="size-3.5" /> রিসেট
          </button>
        )}
      </div>
      <Progress value={(100 * doneCount) / set.items.length} className="mt-3 h-1.5" />

      <div className="mt-4 space-y-4">
        {set.items.map((item) => {
          const count = counts[`${set.id}:${item.id}`] ?? 0;
          const remaining = Math.max(0, item.count - count);
          const done = remaining === 0;
          return (
            <div key={item.id} className={cn("rounded-lg border border-border p-3", done && "bg-primary-soft/50")}>
              <div className="flex items-start gap-3">
                <div className="min-w-0 flex-1">
                  <p dir="rtl" className="text-right font-arabic text-lg leading-loose">
                    {item.arabic}
                  </p>
                  {item.translitBn ? <p className="mt-1 text-xs italic text-muted-foreground">{item.translitBn}</p> : null}
                  <p className="mt-1.5 text-sm leading-relaxed">{item.translationBn}</p>
                  <p className="mt-1 text-xs text-primary">{item.reference}</p>
                  {item.virtue ? <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{item.virtue}</p> : null}
                </div>
                <motion.button
                  whileTap={{ scale: 0.92 }}
                  onClick={() => !done && tick(item.id)}
                  disabled={done}
                  aria-label={`${item.translitBn} — ${toBn(item.count)} বার`}
                  className={cn(
                    "tap-target flex size-12 shrink-0 flex-col items-center justify-center rounded-full text-sm font-extrabold transition-colors",
                    done ? "bg-primary text-primary-foreground" : "bg-primary text-primary-foreground shadow-lifted"
                  )}
                >
                  {done ? <Check className="size-5" /> : <>{toBn(remaining === 0 ? item.count : remaining)}</>}
                </motion.button>
              </div>
            </div>
          );
        })}
      </div>
    </Card>
  );
}
