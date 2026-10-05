"use client";

// HOME-10 on the web (mobile parity): when a Foundation program is live, the
// home page says so first; otherwise the next one within a day. Public data
// (GET /api/live), hidden when there is nothing to show.

import * as React from "react";
import { Play, Radio } from "lucide-react";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { formatTime } from "@/lib/calendars";
import type { LiveProgramItem } from "@/types/domain";
import { Button } from "@/components/ui/button";

function at(iso: string): string {
  const d = new Date(iso);
  const today = new Date();
  const sameDay = d.toDateString() === today.toDateString();
  const time = formatTime(d.getHours() * 60 + d.getMinutes(), "bn");
  return sameDay ? `আজ ${time}` : `আগামীকাল ${time}`;
}

export function HomeLiveCard() {
  const nav = useApp((s) => s.nav);
  const [programs, setPrograms] = React.useState<LiveProgramItem[] | null>(null);

  React.useEffect(() => {
    const load = () =>
      api
        .live()
        .then((r) => setPrograms(r.programs))
        .catch(() => setPrograms([]));
    void load();
    const id = window.setInterval(load, 5 * 60_000);
    return () => window.clearInterval(id);
  }, []);

  if (!programs) return null;
  const live = programs.find((p) => p.status === "live");
  const soon = programs
    .filter((p) => p.status === "upcoming" && new Date(p.startsAt).getTime() - Date.now() < 24 * 3600_000)
    .sort((a, b) => a.startsAt.localeCompare(b.startsAt))[0];
  const p = live ?? soon;
  if (!p) return null;

  return (
    <section
      aria-label={live ? "এখন লাইভ" : "আসছে"}
      className="flex items-center gap-3 rounded-xl border border-border bg-card p-4 shadow-card"
    >
      <span
        className={
          live
            ? "flex size-11 shrink-0 items-center justify-center rounded-full bg-alert text-white"
            : "flex size-11 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary"
        }
      >
        <Radio className="size-5" aria-hidden />
      </span>
      <div className="min-w-0 flex-1">
        <p className={live ? "text-xs font-bold text-alert" : "text-xs font-semibold text-muted-foreground"}>
          {live ? "এখন লাইভ" : `আসছে · ${at(p.startsAt)}`}
        </p>
        <p className="truncate font-semibold">{p.titleBn}</p>
        {p.hostName ? <p className="truncate text-xs text-muted-foreground">{p.hostName}</p> : null}
      </div>
      {live && p.youtubeId ? (
        <Button asChild size="sm" className="h-10 shrink-0 rounded-full">
          <a href={`https://www.youtube.com/watch?v=${encodeURIComponent(p.youtubeId)}`} target="_blank" rel="noopener noreferrer">
            <Play className="size-4" /> দেখুন
          </a>
        </Button>
      ) : (
        <Button variant="outline" size="sm" className="h-10 shrink-0 rounded-full" onClick={() => nav("ilm", "live")}>
          বিস্তারিত
        </Button>
      )}
    </section>
  );
}
