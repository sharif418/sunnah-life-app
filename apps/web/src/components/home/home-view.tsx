"use client";

// হোম (বাড়ি) — নামাজ ড্যাশবোর্ড: তারিখ-ঘড়ি হিরো, পরবর্তী ওয়াক্ত কাউন্টডাউন,
// সময়সূচি, কিবলা, আজকের আমল সারসংক্ষেপ, দ্রুত শর্টকাট।
// সবকিছু গেস্ট-বান্ধব — সাইন-ইন ছাড়াই কাজ করে।

import * as React from "react";
import { useApp } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { Button } from "@/components/ui/button";
import { PrayerHero } from "@/components/home/prayer-hero";
import { QiblaCard } from "@/components/home/qibla-card";
import { AmalSummaryCard } from "@/components/home/amal-summary-card";
import { QuickLinks } from "@/components/home/quick-links";
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

  return (
    <div className="space-y-4 sm:space-y-6">
      {!hasLocation && <LocationPrompt />}
      <PrayerHero />
      <QiblaCard />
      <AmalSummaryCard />
      <QuickLinks />
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
