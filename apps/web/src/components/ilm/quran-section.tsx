"use client";

// কুরআন পাঠক — সূরা তালিকা (সার্চ + স্ক্রল) → উসমানি আরবি পাঠক (বড়, ডান-সারিবদ্ধ,
// ফন্ট-quran) + প্রতি আয়াতের নিচে বাংলা অনুবাদ। শেষ-পাঠ মনে রাখা হয় (localStorage),
// পড়া শেষে তিলাওয়াতের পৃষ্ঠা আমলনামায় যুক্ত হয় (amalKey: tilawat)।

import * as React from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import {
  ArrowLeft,
  ArrowRight,
  Bookmark,
  Check,
  Languages,
  BookOpenCheck,
  Minus,
  Plus,
  Search,
} from "lucide-react";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { dateKey, toBn } from "@/lib/calendars";
import type { AmalEntry, AmalValue } from "@/types/domain";
import { EmptyState, ErrorState, SkeletonRows, useAsync } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { cn } from "@/lib/utils";

const LASTREAD_KEY = "sunnahlife-web-lastread";
const CHUNK = 50;

interface LastRead {
  surah: number;
  ayah: number;
  nameBn: string;
}

function readLastRead(): LastRead | null {
  try {
    const raw = localStorage.getItem(LASTREAD_KEY);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as LastRead;
    if (typeof parsed?.surah === "number" && typeof parsed?.ayah === "number") return parsed;
  } catch {
    // ignore corrupt entries
  }
  return null;
}

function saveLastRead(pos: LastRead) {
  try {
    localStorage.setItem(LASTREAD_KEY, JSON.stringify(pos));
  } catch {
    // storage full/blocked — best effort only
  }
}

// ── সূরা তালিকা ─────────────────────────────────────────────────────────────

type SurahMeta = Awaited<ReturnType<typeof api.quranSurahs>>["surahs"][number];

export function QuranSection({ surah }: { surah: number | null }) {
  return surah ? <SurahReader number={surah} /> : <SurahList />;
}

function SurahList() {
  const { nav } = useApp();
  const { data, loading, error, reload } = useAsync(() => api.quranSurahs());
  const [query, setQuery] = React.useState("");
  const [lastRead, setLastRead] = React.useState<LastRead | null>(null);

  React.useEffect(() => {
    setLastRead(readLastRead());
  }, []);

  if (loading) return <SkeletonRows count={7} className="h-14" />;
  if (error) return <ErrorState message={error} onRetry={reload} />;
  const surahs = data?.surahs ?? [];
  if (surahs.length === 0) return <EmptyState icon={BookOpenCheck} title="কুরআনের সূরা পাওয়া যায়নি" />;

  const q = query.trim();
  const filtered = q
    ? surahs.filter(
        (s) =>
          s.nameBn.toLowerCase().includes(q.toLowerCase()) ||
          s.englishName.toLowerCase().includes(q.toLowerCase()) ||
          s.name.includes(q) ||
          String(s.number) === q
      )
    : surahs;

  return (
    <div>
      <div className="relative">
        <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="সূরা খুঁজুন — নাম বা নম্বর"
          className="h-11 rounded-xl ps-9"
          aria-label="সূরা খুঁজুন"
        />
      </div>

      {lastRead ? (
        <button
          onClick={() => nav("ilm", "quran", { surah: lastRead.surah })}
          className="mt-3 flex w-full items-center gap-2.5 rounded-xl bg-primary-soft px-4 py-3 text-start transition-colors hover:bg-primary-soft/70"
        >
          <Bookmark className="size-4 shrink-0 text-primary" />
          <span className="min-w-0 flex-1">
            <span className="block text-sm font-semibold text-primary">শেষ পাঠ চালিয়ে যান</span>
            <span className="block truncate text-xs text-muted-foreground">
              {lastRead.nameBn} — আয়াত {toBn(lastRead.ayah)}
            </span>
          </span>
          <ArrowRight className="size-4 shrink-0 text-primary" />
        </button>
      ) : null}

      <Card className="mt-3 max-h-[62vh] overflow-y-auto rounded-xl p-2 scroll-thin">
        {filtered.length === 0 ? (
          <p className="py-6 text-center text-sm text-muted-foreground">কোনো সূরা মেলেনি</p>
        ) : (
          <ul>
            {filtered.map((s) => (
              <li key={s.number}>
                <button
                  onClick={() => nav("ilm", "quran", { surah: s.number })}
                  className="tap-target flex w-full items-center gap-3 rounded-lg px-2.5 py-2 text-start transition-colors hover:bg-muted"
                >
                  <span className="flex size-9 shrink-0 items-center justify-center rounded-lg bg-primary-soft text-sm font-bold text-primary">
                    {toBn(s.number)}
                  </span>
                  <span className="min-w-0 flex-1">
                    <span className="block truncate text-sm font-semibold">{s.nameBn}</span>
                    <span className="block truncate text-xs text-muted-foreground">
                      {s.englishName} · {toBn(s.ayahCount)} আয়াত · {s.revelationType === "Meccan" ? "মাক্কী" : "মাদানী"}
                    </span>
                  </span>
                  <span dir="rtl" className="shrink-0 font-arabic text-base text-primary">
                    {s.name}
                  </span>
                </button>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}

// ── পাঠক ────────────────────────────────────────────────────────────────────

type Surah = NonNullable<Awaited<ReturnType<typeof api.quranSurah>>["surah"]>;

function SurahReader({ number: surahNumber }: { number: number }) {
  const { nav } = useApp();
  const { data, loading, error, reload } = useAsync(() => api.quranSurah(surahNumber), surahNumber);
  const [showTranslation, setShowTranslation] = React.useState(true);
  const [lastReadAyah, setLastReadAyah] = React.useState<number | null>(null);
  const [limit, setLimit] = React.useState(CHUNK);
  const [tilawatOpen, setTilawatOpen] = React.useState(false);
  const [tilawatMinutes, setTilawatMinutes] = React.useState(0);
  const sessionStart = React.useRef(Date.now());
  const sessionLogged = React.useRef(false);

  React.useEffect(() => {
    sessionStart.current = Date.now();
    sessionLogged.current = false;
    const saved = readLastRead();
    if (saved && saved.surah === surahNumber) {
      setLastReadAyah(saved.ayah);
      setLimit(Math.max(CHUNK, Math.ceil(saved.ayah / CHUNK) * CHUNK));
    } else {
      setLastReadAyah(null);
      setLimit(CHUNK);
    }
    window.scrollTo({ top: 0 });
  }, [surahNumber]);

  if (loading) return <SkeletonRows count={5} className="h-24" />;
  if (error || !data?.surah) return <ErrorState message={error ?? "সূরা লোড করা যায়নি"} onRetry={reload} />;
  const surah = data.surah;
  const ayahs = surah.ayahs.slice(0, limit);
  const hasMore = limit < surah.ayahs.length;

  const markAyah = (ayah: number) => {
    setLastReadAyah(ayah);
    saveLastRead({ surah: surahNumber, ayah, nameBn: surah.nameBn });
  };

  const maybePromptTilawat = () => {
    // refs read at EVENT time (react-hooks/refs) — the minutes snapshot is
    // captured when the dialog opens, never during render
    const minutes = Math.max(0, Math.floor((Date.now() - sessionStart.current) / 60000));
    if (!sessionLogged.current && minutes >= 1) {
      setTilawatMinutes(minutes);
      setTilawatOpen(true);
    }
  };

  return (
    <div>
      {/* toolbar */}
      <div className="sticky top-16 z-20 -mx-4 mb-4 border-b border-border bg-card/90 px-4 py-2.5 backdrop-blur supports-[backdrop-filter]:bg-card/80">
        <div className="flex items-center gap-2">
          <Button
            variant="ghost"
            size="icon"
            className="size-11 rounded-full"
            aria-label="সূরা তালিকায় ফিরুন"
            onClick={() => {
              maybePromptTilawat();
              nav("ilm", "quran");
            }}
          >
            <ArrowLeft className="size-5" />
          </Button>
          <div className="min-w-0 flex-1">
            <p className="truncate text-sm font-bold">
              {toBn(surah.number)}. {surah.nameBn}
            </p>
            <p className="truncate text-xs text-muted-foreground">
              {toBn(surah.ayahs.length)} আয়াত · {surah.revelationType === "Meccan" ? "মাক্কী" : "মাদানী"}
            </p>
          </div>
          <Button
            variant={showTranslation ? "secondary" : "ghost"}
            size="icon"
            className="size-11 rounded-full"
            aria-label="বাংলা অনুবাদ দেখান/লুকান"
            onClick={() => setShowTranslation((v) => !v)}
          >
            <Languages className="size-5" />
          </Button>
        </div>
      </div>

      {surah.bismillahPre ? (
        <p dir="rtl" className="mb-5 text-center font-quran text-2xl leading-loose">
          بِسْمِ ٱللَّهِ ٱلرَّحْمَٰنِ ٱلرَّحِيمِ
        </p>
      ) : null}

      <div className="space-y-5">
        {ayahs.map((ayah) => {
          const marked = lastReadAyah === ayah.numberInSurah;
          return (
            <motion.article
              key={ayah.numberInSurah}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.15 }}
              className="rounded-xl border border-border bg-card p-4 shadow-card"
              onClick={() => markAyah(ayah.numberInSurah)}
            >
              <div className="mb-2 flex items-center gap-2">
                <span className="rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-bold text-primary">
                  আয়াত {toBn(ayah.numberInSurah)}
                </span>
                <span className="text-xs text-muted-foreground">জুয {toBn(ayah.juz)}</span>
                <span className="ms-auto flex items-center gap-1 text-xs text-muted-foreground">
                  {ayah.page ? <span>পৃষ্ঠা {toBn(ayah.page)}</span> : null}
                  <Bookmark
                    className={cn("size-4", marked ? "fill-primary text-primary" : "text-muted-foreground/40")}
                    aria-label={marked ? "শেষ পাঠ এখানে" : "শেষ পাথ হিসেবে চিহ্নিত করুন"}
                  />
                </span>
              </div>
              <p dir="rtl" className="text-right font-quran text-2xl leading-loose sm:text-[28px]">
                {ayah.text}
              </p>
              {showTranslation && ayah.translationBn ? (
                <p className="mt-2.5 text-sm leading-relaxed text-muted-foreground">{ayah.translationBn}</p>
              ) : null}
            </motion.article>
          );
        })}
      </div>

      {hasMore ? (
        <Button variant="outline" className="mt-4 h-11 w-full rounded-xl" onClick={() => setLimit((l) => l + CHUNK)}>
          <Plus className="size-4" /> পরবর্তী {toBn(Math.min(CHUNK, surah.ayahs.length - limit))} আয়াত
        </Button>
      ) : (
        <div className="mt-6 rounded-xl bg-primary-soft p-5 text-center">
          <p className="text-sm font-bold text-primary">সাদাকাল্লাহুল আযীম — সূরা সমাপ্ত</p>
          <p className="mt-1 text-xs text-muted-foreground">
            তিলাওয়াত শেষ করলে পড়া পৃষ্ঠা আমলনামায় যুক্ত করে নিন।
          </p>
          <div className="mt-3 flex flex-wrap items-center justify-center gap-2">
            <Button size="sm" className="h-11 rounded-xl" onClick={() => setTilawatOpen(true)}>
              <Check className="size-4" /> তিলাওয়াত শেষ
            </Button>
            {surahNumber < 114 ? (
              <Button variant="outline" size="sm" className="h-11 rounded-xl" onClick={() => nav("ilm", "quran", { surah: surahNumber + 1 })}>
                পরবর্তী সূরা <ArrowRight className="size-4" />
              </Button>
            ) : null}
          </div>
        </div>
      )}

      <TilawatDialog
        open={tilawatOpen}
        onOpenChange={(open) => {
          if (!open) sessionLogged.current = true;
          setTilawatOpen(open);
        }}
        minutes={tilawatMinutes}
        surahLabel={surah.nameBn}
        onLogged={() => {
          sessionStart.current = Date.now();
        }}
      />
    </div>
  );
}

// ── তিলাওয়াত সেশন (আমলনামায় পৃষ্ঠা যুক্ত) ────────────────────────────────────

function TilawatDialog({
  open,
  onOpenChange,
  minutes,
  surahLabel,
  onLogged,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  minutes: number;
  surahLabel: string;
  onLogged: () => void;
}) {
  const suggested = Math.min(999, Math.max(1, Math.ceil(minutes / 3) + (minutes >= 1 ? 0 : 1)));
  const [pages, setPages] = React.useState(suggested);
  const [saved, setSaved] = React.useState(false);
  React.useEffect(() => {
    if (open) {
      setPages(suggested);
      setSaved(false);
    }
  }, [open, suggested]);

  const save = () => {
    if (pages <= 0) return;
    const entry: AmalEntry = {
      amalKey: "tilawat",
      date: dateKey(),
      value: pages as AmalValue,
      source: "auto:quran:tilawat",
      clientUpdatedAt: new Date().toISOString(),
    };
    useApp.getState().writeEntry(entry);
    setSaved(true);
    onLogged();
    toast.success(`আলহামদুলিল্লাহ — তিলাওয়াত লেখা হয়েছে (${toBn(pages)} পৃষ্ঠা)`);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-w-sm rounded-2xl">
        <DialogHeader>
          <DialogTitle className="text-start">তিলাওয়াত সেশন শেষ</DialogTitle>
        </DialogHeader>
        <p className="text-sm text-muted-foreground">
          {surahLabel} — পড়েছেন প্রায় {toBn(minutes)} মিনিট। কত পৃষ্ঠা আমলনামায় যুক্ত করবেন?
        </p>
        <div className="flex items-center justify-center gap-4 py-2">
          <Button variant="outline" size="icon" className="size-11 rounded-full" aria-label="কমান" onClick={() => setPages((p) => Math.max(0.5, p - 0.5))}>
            <Minus className="size-5" />
          </Button>
          <span className="min-w-16 text-center text-3xl font-extrabold text-primary">{toBn(pages)}</span>
          <Button variant="outline" size="icon" className="size-11 rounded-full" aria-label="বাড়ান" onClick={() => setPages((p) => Math.min(999, p + 0.5))}>
            <Plus className="size-5" />
          </Button>
        </div>
        <p className="text-center text-xs text-muted-foreground">পৃষ্ঠা (আধা পৃষ্ঠাও লেখা যায়)</p>
        <DialogFooter className="flex-col gap-2">
          <Button className="h-11 w-full rounded-xl" onClick={save} disabled={saved || pages <= 0}>
            <BookOpenCheck className="size-4" /> আমলনামায় সংরক্ষণ করুন
          </Button>
          <Button variant="ghost" className="h-11 w-full rounded-xl text-muted-foreground" onClick={() => onOpenChange(false)}>
            এখন নয়
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
