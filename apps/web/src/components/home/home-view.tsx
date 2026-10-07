"use client";

// হোম (বাড়ি) — the app's order since the 2026-10-07 redesign: the date row,
// the prayer card (sun arc), today's muhasaba, quick links, the one-card
// schedule (+ the browser alert switch), qibla, most-used amal, ilm.
// সবকিছু গেস্ট-বান্ধব — সাইন-ইন ছাড়াই কাজ করে।

import * as React from "react";
import { useApp } from "@/lib/store";
import { useMediaQuery } from "@/hooks/use-media-query";
import { translate } from "@/lib/i18n";
import { Button } from "@/components/ui/button";
import { HomeDateRow, ScheduleCard, SunArcCard } from "@/components/home/prayer-card";
import { QiblaCard } from "@/components/home/qibla-card";
import { HomeLiveCard } from "@/components/home/live-card";
import { WaqtAlertsToggle } from "@/components/home/forbidden-card";
import { AmalSummaryCard } from "@/components/home/amal-summary-card";
import { QuickLinks } from "@/components/home/quick-links";
import { IlmPreview, MostUsedSection } from "@/components/home/home-extras";
import { LocationSheet } from "@/components/home/city-sheet";
import { MapPin, Navigation } from "lucide-react";

export function HomeView() {
  const hasLocation = useApp(
    (s) =>
      typeof s.profile.lat === "number" &&
      isFinite(s.profile.lat) &&
      s.profile.lat !== 0 &&
      typeof s.profile.lng === "number" &&
      isFinite(s.profile.lng) &&
      s.profile.lng !== 0
  );

  // one column on phones (the app's order); two on a wide screen, the
  // prayer column on the left — the sun's arc would flatten across a full
  // desktop width
  const wide = useMediaQuery("(min-width: 1024px)");

  if (wide) {
    return (
      <div className="space-y-6">
        {!hasLocation && <LocationPrompt />}
        <div className="grid grid-cols-2 items-start gap-6">
          <div className="space-y-6">
            <HomeDateRow />
            <HomeLiveCard />
            <SunArcCard />
            <ScheduleCard />
            <WaqtAlertsToggle />
          </div>
          <div className="space-y-6">
            <AmalSummaryCard />
            <QuickLinks />
            <QiblaCard />
            <MostUsedSection />
            <IlmPreview />
          </div>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-4 sm:space-y-6">
      {!hasLocation && <LocationPrompt />}
      <HomeDateRow />
      <HomeLiveCard />
      <SunArcCard />
      <AmalSummaryCard />
      <QuickLinks />
      <ScheduleCard />
      <WaqtAlertsToggle />
      <QiblaCard />
      <MostUsedSection />
      <IlmPreview />
    </div>
  );
}

/** অবস্থান নেই — শহর বাছাই বা GPS; ব্যর্থ হলে ঢাকা ডিফল্টই থাকে। */
function LocationPrompt() {
  const [open, setOpen] = React.useState(false);
  const lang = useApp((s) => s.profile.language);
  const t = (k: string) => translate(lang, k);
  return (
    <>
      <div className="rounded-xl border border-gold/40 bg-gold-soft p-4 flex items-center gap-3">
        <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-gold/20 text-warning">
          <MapPin className="size-5" />
        </span>
        <div className="flex-1 min-w-0">
          <p className="text-sm font-semibold">{t("home.chooseLocation")}</p>
          <p className="text-xs text-muted-foreground leading-relaxed">{t("home.locationHint")}</p>
        </div>
        <Button size="sm" className="h-11 rounded-xl shrink-0" onClick={() => setOpen(true)}>
          <Navigation className="size-4" /> {t("home.city")}
        </Button>
      </div>
      <LocationSheet open={open} onOpenChange={setOpen} />
    </>
  );
}
