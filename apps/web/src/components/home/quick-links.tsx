"use client";

// দ্রুত শর্টকাট — কুরআন, দোয়া, আজকের আমল, লাইভ।

import { useApp } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { BookOpen, HeartHandshake, ClipboardCheck, Radio } from "lucide-react";
import type { Tab } from "@/lib/store";

const LINKS: { icon: typeof BookOpen; titleKey: string; descKey: string; tab: Tab; view: string }[] = [
  { icon: BookOpen, titleKey: "quick.quran", descKey: "quick.desc.quran", tab: "ilm", view: "quran" },
  { icon: HeartHandshake, titleKey: "quick.duas", descKey: "quick.desc.duas", tab: "ilm", view: "duas" },
  { icon: ClipboardCheck, titleKey: "quick.amal", descKey: "quick.desc.amal", tab: "amal", view: "default" },
  { icon: Radio, titleKey: "quick.live", descKey: "quick.desc.live", tab: "ilm", view: "live" },
];

export function QuickLinks() {
  const lang = useApp((s) => s.profile.language);
  const nav = useApp((s) => s.nav);
  const t = (k: string) => translate(lang, k);
  return (
    <nav aria-label={t("quick.label")} className="grid grid-cols-2 min-[480px]:grid-cols-4 gap-3">
      {LINKS.map(({ icon: Icon, titleKey, descKey, tab, view }) => (
        <button
          key={titleKey}
          onClick={() => nav(tab, view)}
          className="tap-target rounded-xl border border-border bg-card p-3.5 shadow-card text-start transition-all motion-base hover:shadow-lifted hover:border-primary/30 active:scale-[0.98]"
        >
          <span className="flex size-11 items-center justify-center rounded-full bg-primary-soft text-primary">
            <Icon className="size-5" />
          </span>
          <span className="mt-2.5 block text-sm font-semibold leading-snug">{t(titleKey)}</span>
          <span className="mt-0.5 block text-[11.5px] text-muted-foreground leading-snug">{t(descKey)}</span>
        </button>
      ))}
    </nav>
  );
}
