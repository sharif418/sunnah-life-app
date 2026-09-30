"use client";

// ইলম — কুরআন পাঠক, দোয়া-আযকার, কোর্স, লাইভ প্রোগ্রাম ও আরও পড়ার জ্ঞান-কেন্দ্র।
// অতিথিদের জন্যও উন্মুক্ত (এনরোল/রিমাইন্ডারে সাইন-ইন প্রম্পট)।
// সাব-নেভিগেশন store-এর view/params দিয়ে: nav("ilm","quran",{surah:1}) ইত্যাদি।

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { BookOpen, GraduationCap, HandHeart, LayoutGrid, Radio, Search, X } from "lucide-react";
import { translate } from "@/lib/i18n";
import { useApp } from "@/lib/store";
import { Input } from "@/components/ui/input";
import { PillTabs } from "./parts";
import { LiveSection } from "./live-section";
import { QuranSection } from "./quran-section";
import { DuasSection, type DuasMode } from "./duas-section";
import { CoursesSection } from "./courses-section";
import { ExtrasSection, type ExtraKey } from "./extras-section";
import { SearchSection } from "./search-section";

type IlmTab = "live" | "quran" | "duas" | "courses" | "more";

const TABS: { key: IlmTab; label: string; icon: React.ElementType }[] = [
  { key: "live", label: "লাইভ", icon: Radio },
  { key: "quran", label: "কুরআন", icon: BookOpen },
  { key: "duas", label: "দোয়া ও আযকার", icon: HandHeart },
  { key: "courses", label: "কোর্স", icon: GraduationCap },
  { key: "more", label: "আরও", icon: LayoutGrid },
];

// Views that render inside the আরও tab. NOTE: "more" itself (the tab) has
// extra: null — the grid; the rest deep-link a specific extra card.
const EXTRAS: ExtraKey[] = [
  "quizzes",
  "live-quiz",
  "usrah-questions",
  "names99",
  "islamic-names",
  "articles",
  "sunnahs",
  "iman70",
];

interface IlmRoute {
  tab: IlmTab;
  surah: number | null;
  duasMode: DuasMode;
  duaId?: string;
  courseId?: string;
  lessonId?: string;
  extra: ExtraKey | null;
  extraId?: string;
}

function routeIlm(view: string, params: Record<string, string | number>): IlmRoute {
  const surahParam = params.surah ?? params.number;
  const surah = surahParam != null && Number(surahParam) >= 1 && Number(surahParam) <= 114 ? Number(surahParam) : null;
  const base: IlmRoute = {
    tab: "live",
    surah: null,
    duasMode: "duas",
    courseId: params.courseId != null ? String(params.courseId) : undefined,
    lessonId: params.lessonId != null ? String(params.lessonId) : undefined,
    extra: null,
  };
  switch (view) {
    case "quran":
      return { ...base, tab: "quran", surah };
    case "quran-surah":
      return { ...base, tab: "quran", surah: surah ?? 1 };
    case "duas":
      return { ...base, tab: "duas", duasMode: "duas" };
    case "dua":
      return { ...base, tab: "duas", duasMode: "duas", duaId: params.id != null ? String(params.id) : undefined };
    case "adhkar":
    case "adhkar-set":
    case "post-salat":
      return { ...base, tab: "duas", duasMode: "adhkar" };
    case "courses":
      return { ...base, tab: "courses" };
    case "course":
      return { ...base, tab: "courses", courseId: base.courseId ?? (params.id != null ? String(params.id) : undefined) };
    case "lesson":
      return { ...base, tab: "courses" };
    case "more":
      // the আরও tab itself — the extras grid (quizzes, live quiz, usrah
      // questions, 99 names, …). Without this case the tab fell through to
      // default (live) and the grid was unreachable.
      return { ...base, tab: "more" };
    case "quiz":
      // deep link: jump straight into playing one quiz
      return {
        ...base,
        tab: "more",
        extra: "quizzes",
        extraId: params.id != null ? String(params.id) : undefined,
      };
    default:
      if (EXTRAS.includes(view as ExtraKey)) {
        return { ...base, tab: "more", extra: view as ExtraKey };
      }
      return base; // "home" / "default" / অজানা → লাইভ
  }
}

export function IlmView() {
  const { view, params, nav } = useApp();
  const lang = useApp((s) => s.profile.language);
  const t = (k: string) => translate(lang, k);
  const route = routeIlm(view, params);

  // W4j — the unified search field. A trimmed query of ≥ 2 characters swaps
  // the tab area for the grouped results (PillTabs hide while searching);
  // clearing the field restores the tab the user left.
  const [query, setQuery] = React.useState("");
  const q = query.trim();
  const searching = q.length >= 2;

  return (
    <div>
      <header className="mb-4">
        <h1 className="text-xl font-bold">ইলম</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">কুরআন, দোয়া, আযকার ও জীবন্ত ইলমি পরিবেশ</p>
      </header>

      <div className="relative mb-4">
        <Search className="pointer-events-none absolute start-3 top-1/2 size-4 -translate-y-1/2 text-muted-foreground" />
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder={t("search.hint")}
          aria-label={t("search.title")}
          className="h-11 rounded-xl ps-9 pe-9"
        />
        {query ? (
          <button
            onClick={() => setQuery("")}
            aria-label={t("search.clear")}
            className="tap-target absolute end-2 top-1/2 -translate-y-1/2 rounded-full p-1 text-muted-foreground transition-colors hover:bg-muted hover:text-foreground"
          >
            <X className="size-4" />
          </button>
        ) : null}
      </div>

      {searching ? (
        <SearchSection query={q} onResultTap={() => setQuery("")} />
      ) : (
        <>
          <PillTabs
            items={TABS}
            value={route.tab}
            onChange={(key) => nav("ilm", key)}
            className="mb-5 border-b border-border pb-2"
          />

          <AnimatePresence mode="wait">
            <motion.div
              key={route.tab}
              initial={{ opacity: 0, y: 8 }}
              animate={{ opacity: 1, y: 0 }}
              exit={{ opacity: 0, y: -6 }}
              transition={{ duration: 0.12, ease: "easeOut" }}
            >
              {route.tab === "live" && <LiveSection />}
              {route.tab === "quran" && <QuranSection surah={route.surah} />}
              {route.tab === "duas" && <DuasSection mode={route.duasMode} highlightId={route.duaId} />}
              {route.tab === "courses" && <CoursesSection courseId={route.courseId} lessonId={route.lessonId} />}
              {route.tab === "more" && (
                <ExtrasSection
                  active={route.extra}
                  highlightId={
                    params.id != null && (view === "article" || route.extra === "articles") ? String(params.id) : undefined
                  }
                  startQuizId={route.extra === "quizzes" && route.extraId ? route.extraId : undefined}
                />
              )}
            </motion.div>
          </AnimatePresence>
        </>
      )}
    </div>
  );
}
