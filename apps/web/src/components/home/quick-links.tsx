"use client";

// দ্রুত শর্টকাট — কুরআন, দোয়া, আজকের আমল, লাইভ।

import { useApp } from "@/lib/store";
import { BookOpen, HeartHandshake, ClipboardCheck, Radio } from "lucide-react";
import type { Tab } from "@/lib/store";

const LINKS: { icon: typeof BookOpen; title: string; desc: string; tab: Tab; view: string }[] = [
  { icon: BookOpen, title: "কুরআন পাঠ", desc: "সূরা ও অনুবাদ", tab: "ilm", view: "quran" },
  { icon: HeartHandshake, title: "দোয়া সংগ্রহ", desc: "দৈনন্দিন দোয়া", tab: "ilm", view: "duas" },
  { icon: ClipboardCheck, title: "আজকের আমল", desc: "মুহাসাবা ডায়েরি", tab: "amal", view: "default" },
  { icon: Radio, title: "লাইভ", desc: "সরাসরি অনুষ্ঠান", tab: "ilm", view: "live" },
];

export function QuickLinks() {
  const nav = useApp((s) => s.nav);
  return (
    <nav aria-label="দ্রুত শর্টকাট" className="grid grid-cols-2 min-[480px]:grid-cols-4 gap-3">
      {LINKS.map(({ icon: Icon, title, desc, tab, view }) => (
        <button
          key={title}
          onClick={() => nav(tab, view)}
          className="tap-target rounded-xl border border-border bg-card p-3.5 shadow-card text-start transition-all motion-base hover:shadow-lifted hover:border-primary/30 active:scale-[0.98]"
        >
          <span className="flex size-11 items-center justify-center rounded-full bg-primary-soft text-primary">
            <Icon className="size-5" />
          </span>
          <span className="mt-2.5 block text-sm font-semibold leading-snug">{title}</span>
          <span className="mt-0.5 block text-[11.5px] text-muted-foreground leading-snug">{desc}</span>
        </button>
      ))}
    </nav>
  );
}
