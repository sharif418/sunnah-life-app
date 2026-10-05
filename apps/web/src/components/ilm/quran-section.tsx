"use client";

// কুরআন পাঠক — সূরা তালিকা (সার্চ + স্ক্রল) → উসমানি আরবি পাঠক (বড়, ডান-সারিবদ্ধ,
// ফন্ট-quran) + প্রতি আয়াতের নিচে বাংলা অনুবাদ। শেষ-পাঠ ও বুকমার্ক মনে রাখা হয়
// (localStorage), আয়াতে যাওয়া ও প্রতি আয়াতের তিলাওয়াত শোনা যায় (অ্যাপের মতো),
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
  Hash,
  Headphones,
  Minus,
  Pause,
  Play,
  Plus,
  Search,
  Square,
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
import {
  RECITERS,
  ayahAudioUrl,
  parseAyahInput,
  readBookmarks,
  readReciter,
  saveReciter,
  toggleBookmark,
  type AyahBookmark,
  type Reciter,
} from "./quran-audio";

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
  const ayahParam = useApp((s) => s.params.ayah);
  const ayah = ayahParam != null && Number(ayahParam) >= 1 ? Number(ayahParam) : null;
  return surah ? <SurahReader number={surah} initialAyah={ayah} /> : <SurahList />;
}

function SurahList() {
  const { nav } = useApp();
  const { data, loading, error, reload } = useAsync(() => api.quranSurahs());
  const [query, setQuery] = React.useState("");
  const [lastRead, setLastRead] = React.useState<LastRead | null>(null);
  const [bookmarks, setBookmarks] = React.useState<AyahBookmark[]>([]);

  React.useEffect(() => {
    setLastRead(readLastRead());
    setBookmarks(readBookmarks());
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
          onClick={() => nav("ilm", "quran", { surah: lastRead.surah, ayah: lastRead.ayah })}
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

      {bookmarks.length > 0 ? (
        <div className="mt-3">
          <p className="mb-1.5 text-xs font-semibold text-muted-foreground">বুকমার্ক</p>
          <div className="scroll-thin flex gap-2 overflow-x-auto pb-1">
            {bookmarks.map((b) => (
              <button
                key={`${b.surah}:${b.ayah}`}
                onClick={() => nav("ilm", "quran", { surah: b.surah, ayah: b.ayah })}
                className="flex h-9 shrink-0 items-center gap-1.5 rounded-full border border-border bg-card px-3 text-xs font-semibold transition-colors hover:bg-muted"
              >
                <Bookmark className="size-3.5 fill-primary text-primary" aria-hidden />
                {b.nameBn} : {toBn(b.ayah)}
              </button>
            ))}
          </div>
        </div>
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

function SurahReader({ number: surahNumber, initialAyah }: { number: number; initialAyah: number | null }) {
  const { nav } = useApp();
  const { data, loading, error, reload } = useAsync(() => api.quranSurah(surahNumber), surahNumber);
  const [showTranslation, setShowTranslation] = React.useState(true);
  const [lastReadAyah, setLastReadAyah] = React.useState<number | null>(null);
  const [limit, setLimit] = React.useState(CHUNK);
  const [tilawatOpen, setTilawatOpen] = React.useState(false);
  const [tilawatMinutes, setTilawatMinutes] = React.useState(0);
  const sessionStart = React.useRef(Date.now());
  const sessionLogged = React.useRef(false);
  // bookmarks, go-to-ayah and per-ayah recitation (mobile parity)
  const [bookmarks, setBookmarks] = React.useState<AyahBookmark[]>([]);
  const [audioOn, setAudioOn] = React.useState(false);
  const [reciter, setReciter] = React.useState<Reciter>(RECITERS[0]);
  const [reciterOpen, setReciterOpen] = React.useState(false);
  const [gotoOpen, setGotoOpen] = React.useState(false);
  const [playing, setPlaying] = React.useState<number | null>(null);
  const [pendingJump, setPendingJump] = React.useState<{ ayah: number; block: ScrollLogicalPosition } | null>(null);
  const audio = React.useRef<HTMLAudioElement | null>(null);

  React.useEffect(() => {
    audio.current = new Audio();
    setBookmarks(readBookmarks());
    setReciter(readReciter());
    let alive = true;
    // audioBase is the admin's on/off switch for recitation, as in the app
    api
      .config()
      .then((c) => alive && setAudioOn(!!c.audioBase))
      .catch(() => alive && setAudioOn(true));
    const player = audio;
    return () => {
      alive = false;
      player.current?.pause();
      player.current = null;
    };
  }, []);

  React.useEffect(() => {
    sessionStart.current = Date.now();
    sessionLogged.current = false;
    const saved = readLastRead();
    const target = initialAyah ?? (saved && saved.surah === surahNumber ? saved.ayah : null);
    setLastReadAyah(saved && saved.surah === surahNumber ? saved.ayah : null);
    setLimit(target ? Math.max(CHUNK, Math.ceil(target / CHUNK) * CHUNK) : CHUNK);
    setPendingJump(initialAyah ? { ayah: initialAyah, block: "start" } : null);
    window.scrollTo({ top: 0 });
    // leaving the surah stops its recitation
    const player = audio;
    return () => {
      player.current?.pause();
      setPlaying(null);
    };
  }, [surahNumber, initialAyah]);

  // scroll once the target ayah is on the page (after load / "show more")
  React.useEffect(() => {
    if (!pendingJump) return;
    const el = document.getElementById(`ayah-${pendingJump.ayah}`);
    if (!el) return;
    el.scrollIntoView({ behavior: "smooth", block: pendingJump.block });
    setPendingJump(null);
  }, [pendingJump, limit, data]);

  if (loading) return <SkeletonRows count={5} className="h-24" />;
  if (error || !data?.surah) return <ErrorState message={error ?? "সূরা লোড করা যায়নি"} onRetry={reload} />;
  const surah = data.surah;
  const total = surah.ayahs.length;
  const ayahs = surah.ayahs.slice(0, limit);
  const hasMore = limit < total;

  const markAyah = (ayah: number) => {
    setLastReadAyah(ayah);
    saveLastRead({ surah: surahNumber, ayah, nameBn: surah.nameBn });
  };

  const reveal = (ayah: number, block: ScrollLogicalPosition = "start") => {
    setLimit((l) => Math.max(l, Math.ceil(ayah / CHUNK) * CHUNK));
    setPendingJump({ ayah, block });
  };

  const stop = () => {
    audio.current?.pause();
    setPlaying(null);
  };

  const audioFailed = () => {
    setPlaying(null);
    toast.error("তিলাওয়াত চালানো যায়নি — ইন্টারনেট সংযোগ দেখে আবার চেষ্টা করুন");
  };

  // one <audio> for the reader; when an ayah ends the next one plays until
  // the surah ends, and the page follows it
  const play = (ayah: number, who: Reciter = reciter) => {
    const el = audio.current;
    if (!el) return;
    el.onended = () => {
      if (ayah < total) {
        play(ayah + 1, who);
        reveal(ayah + 1, "nearest");
      } else {
        setPlaying(null);
      }
    };
    el.onerror = audioFailed;
    el.src = ayahAudioUrl(who, surahNumber, ayah);
    setPlaying(ayah);
    el.play().catch((e: unknown) => {
      // a newer play() interrupting this one is not a failure
      if (!(e instanceof DOMException && e.name === "AbortError")) audioFailed();
    });
  };

  const isBookmarked = (ayah: number) => bookmarks.some((b) => b.surah === surahNumber && b.ayah === ayah);

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
        <div className="flex items-center gap-1">
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
              {toBn(total)} আয়াত · {surah.revelationType === "Meccan" ? "মাক্কী" : "মাদানী"}
            </p>
          </div>
          <Button variant="ghost" size="icon" className="size-11 rounded-full" aria-label="আয়াতে যান" onClick={() => setGotoOpen(true)}>
            <Hash className="size-5" />
          </Button>
          {audioOn ? (
            <Button variant="ghost" size="icon" className="size-11 rounded-full" aria-label="ক্বারী বেছে নিন" onClick={() => setReciterOpen(true)}>
              <Headphones className="size-5" />
            </Button>
          ) : null}
          <Button
            variant={showTranslation ? "secondary" : "ghost"}
            size="icon"
            className="size-11 rounded-full"
            aria-label="বাংলা অনুবাদ দেখান/লুকান"
            aria-pressed={showTranslation}
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
          const n = ayah.numberInSurah;
          const lastRead = lastReadAyah === n;
          const marked = isBookmarked(n);
          const isPlaying = playing === n;
          return (
            <motion.article
              key={n}
              id={`ayah-${n}`}
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              transition={{ duration: 0.15 }}
              className={cn(
                "scroll-mt-36 rounded-xl border border-border bg-card p-4 shadow-card transition-shadow",
                isPlaying && "border-primary/40 ring-2 ring-primary/30"
              )}
              onClick={() => markAyah(n)}
            >
              <div className="mb-2 flex items-center gap-2">
                <span className="rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-bold text-primary">
                  আয়াত {toBn(n)}
                </span>
                <span className="text-xs text-muted-foreground">
                  জুয {toBn(ayah.juz)}
                  {ayah.page ? ` · পৃষ্ঠা ${toBn(ayah.page)}` : ""}
                </span>
                {lastRead ? (
                  <span className="rounded-full bg-gold-soft px-2 py-0.5 text-[11px] font-semibold text-gold-text-foreground">শেষ পাঠ</span>
                ) : null}
                <span className="ms-auto flex items-center">
                  {audioOn ? (
                    <Button
                      variant="ghost"
                      size="icon"
                      className={cn("size-10 rounded-full", isPlaying && "text-primary")}
                      aria-label={isPlaying ? `আয়াত ${toBn(n)} থামান` : `আয়াত ${toBn(n)} শুনুন`}
                      onClick={(e) => {
                        e.stopPropagation();
                        if (isPlaying) stop();
                        else play(n);
                      }}
                    >
                      {isPlaying ? <Pause className="size-5" /> : <Play className="size-5" />}
                    </Button>
                  ) : null}
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-10 rounded-full"
                    aria-label={marked ? "বুকমার্ক সরান" : "বুকমার্ক করুন"}
                    aria-pressed={marked}
                    onClick={(e) => {
                      e.stopPropagation();
                      setBookmarks(toggleBookmark({ surah: surahNumber, ayah: n, nameBn: surah.nameBn }));
                    }}
                  >
                    <Bookmark className={cn("size-5", marked ? "fill-primary text-primary" : "text-muted-foreground")} />
                  </Button>
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
          <Plus className="size-4" /> পরবর্তী {toBn(Math.min(CHUNK, total - limit))} আয়াত
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

      {/* now playing — stays in reach while the page scrolls */}
      {playing != null ? (
        <div className="fixed inset-x-0 bottom-24 z-30 flex justify-center px-4 md:bottom-6">
          <div className="flex items-center gap-3 rounded-full border border-border bg-card py-1.5 pe-1.5 ps-4 shadow-lg">
            <span className="size-2 animate-pulse rounded-full bg-primary" aria-hidden />
            <span className="text-sm font-semibold">
              আয়াত {toBn(playing)} <span className="font-normal text-muted-foreground">· {reciter.nameBn}</span>
            </span>
            <Button size="sm" variant="secondary" className="h-9 rounded-full" onClick={stop}>
              <Square className="size-3.5 fill-current" /> থামান
            </Button>
          </div>
        </div>
      ) : null}

      <Dialog open={gotoOpen} onOpenChange={setGotoOpen}>
        <DialogContent className="max-w-xs rounded-2xl">
          <DialogHeader>
            <DialogTitle className="text-start">আয়াতে যান</DialogTitle>
          </DialogHeader>
          <form
            className="space-y-3"
            onSubmit={(e) => {
              e.preventDefault();
              const n = parseAyahInput(String(new FormData(e.currentTarget).get("ayah") ?? ""));
              if (n == null || n < 1 || n > total) {
                toast.error(`১ থেকে ${toBn(total)} এর মধ্যে আয়াত নম্বর দিন`);
                return;
              }
              setGotoOpen(false);
              reveal(n);
            }}
          >
            <Input name="ayah" inputMode="numeric" autoFocus placeholder={`আয়াত নম্বর (১–${toBn(total)})`} className="h-11 rounded-xl" aria-label="আয়াত নম্বর" />
            <Button type="submit" className="h-11 w-full rounded-xl">
              যান
            </Button>
          </form>
        </DialogContent>
      </Dialog>

      <Dialog open={reciterOpen} onOpenChange={setReciterOpen}>
        <DialogContent className="max-w-sm rounded-2xl">
          <DialogHeader>
            <DialogTitle className="text-start">ক্বারী</DialogTitle>
          </DialogHeader>
          <ul className="space-y-1" role="radiogroup" aria-label="ক্বারী">
            {RECITERS.map((r) => (
              <li key={r.id}>
                <button
                  type="button"
                  role="radio"
                  aria-checked={reciter.id === r.id}
                  onClick={() => {
                    setReciter(r);
                    saveReciter(r);
                    setReciterOpen(false);
                    if (playing != null) play(playing, r);
                  }}
                  className={cn(
                    "flex w-full items-center gap-3 rounded-xl px-3 py-3 text-start text-sm transition-colors hover:bg-muted",
                    reciter.id === r.id && "bg-primary-soft font-semibold text-primary"
                  )}
                >
                  <span className="flex-1">{r.nameBn}</span>
                  {reciter.id === r.id ? <Check className="size-4" /> : null}
                </button>
              </li>
            ))}
          </ul>
          <p className="text-xs text-muted-foreground">প্রতিটি আয়াত আলাদা করে শোনা যায়; একটি শেষ হলে পরেরটি নিজে থেকেই শুরু হয়।</p>
        </DialogContent>
      </Dialog>

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
