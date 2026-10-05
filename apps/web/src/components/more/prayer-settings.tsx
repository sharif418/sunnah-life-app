"use client";

// নামাজের সেটিংস — হিসাব পদ্ধতি, মাযহাব (আসর), শহর।
// PrayerSettingsControls প্রোফাইল পেজেও ব্যবহৃত হয়; সাইন-ইন থাকলে
// পরিবর্তনগুলো debounced-ভাবে /api/me-তে সংরক্ষিত হয়।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SubShell, SectionLabel } from "@/components/more/bits";
import { CityPicker } from "@/components/more/city-picker";
import { useNow, usePrayerDay, SCHEDULE_ROWS } from "@/components/home/prayer-hooks";
import { CALC_METHODS } from "@/lib/prayer-times";
import { formatTimeBn, hijriDate, toBn } from "@/lib/calendars";
import { useHijriAdjust } from "@/hooks/use-hijri-adjust";
import { useApp } from "@/lib/store";
import { api } from "@/lib/api";
import { PRAYER_LABELS_BN } from "@/types/domain";
import type { CalcMethodKey, Madhhab } from "@/types/domain";
import { toast } from "sonner";
import { AlarmClock, CalendarDays, MapPin, Clock3, Minus, Plus } from "lucide-react";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";

export function PrayerSettingsView() {
  return (
    <SubShell title="নামাজের সেটিংস">
      <PrayerSettingsControls withPreview />
    </SubShell>
  );
}

export function PrayerSettingsControls({ withPreview = false }: { withPreview?: boolean }) {
  const { user, profile, updateProfile } = useApp();

  // লাইভ প্রিভিউ — প্রোফাইল বদলালেই নতুন সময় দেখায়।
  const now = useNow(60_000);
  const { times } = usePrayerDay(now);

  // সাইন-ইন থাকলে debounced সার্ভার সিঙ্ক (শুধু নামাজ-সংক্রান্ত ফিল্ড)।
  const lastSynced = React.useRef<string | null>(null);
  React.useEffect(() => {
    const sig = JSON.stringify([profile.method, profile.madhhab, profile.city, profile.lat, profile.lng]);
    if (!user) {
      lastSynced.current = sig;
      return;
    }
    if (lastSynced.current === null) {
      lastSynced.current = sig;
      return;
    }
    if (lastSynced.current === sig) return;
    const id = setTimeout(() => {
      api
        .updateMe({
          calcMethod: profile.method,
          madhhab: profile.madhhab,
          city: profile.city,
          lat: profile.lat,
          lng: profile.lng,
        })
        .then(() => {
          lastSynced.current = sig;
        })
        .catch((e: unknown) => {
          toast.error(e instanceof Error ? e.message : "সার্ভারে সংরক্ষণ করা যায়নি");
        });
    }, 800);
    return () => clearTimeout(id);
  }, [user, profile.method, profile.madhhab, profile.city, profile.lat, profile.lng]);

  return (
    <div className="space-y-4">
      <Card className="rounded-xl shadow-card">
        <CardContent className="p-4 sm:p-5 space-y-5">
          {/* শহর */}
          <div className="space-y-1.5">
            <SectionLabel icon={<MapPin className="size-4" />}>শহর</SectionLabel>
            <CityPicker
              value={profile.city}
              onChange={(cityEn, lat, lng) => updateProfile({ city: cityEn, lat, lng })}
            />
            <p className="text-xs text-muted-foreground leading-relaxed">
              বাংলাদেশের ৬৪ জেলা + আন্তর্জাতিক শহর, অথবা GPS দিয়ে স্বয়ংক্রিয় শনাক্তকরণ।
            </p>
          </div>

          {/* হিসাব পদ্ধতি */}
          <div className="space-y-1.5">
            <SectionLabel icon={<Clock3 className="size-4" />}>হিসাব পদ্ধতি</SectionLabel>
            <Select
              value={profile.method}
              onValueChange={(v) => updateProfile({ method: v as CalcMethodKey })}
            >
              <SelectTrigger className="h-12 rounded-xl w-full" aria-label="হিসাব পদ্ধতি নির্বাচন করুন">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                {(Object.keys(CALC_METHODS) as CalcMethodKey[]).map((k) => (
                  <SelectItem key={k} value={k} className="py-2.5">
                    {CALC_METHODS[k].labelBn}
                  </SelectItem>
                ))}
              </SelectContent>
            </Select>
            <p className="text-xs text-muted-foreground leading-relaxed">
              বাংলাদেশের জন্য প্রচলিত: করাচি পদ্ধতি (ফজর ও ইশা ১৮°)।
            </p>
          </div>

          {/* মাযহাব */}
          <div className="space-y-1.5">
            <SectionLabel icon={<AlarmClock className="size-4" />}>মাযহাব (আসরের হিসাব)</SectionLabel>
            <div className="grid grid-cols-2 gap-2">
              {(
                [
                  { key: "hanafi", label: "হানাফি", hint: "ছায়া দ্বিগুণ হলে আসর" },
                  { key: "shafii", label: "শাফেয়ি", hint: "ছায়া সমান হলে আসর" },
                ] as const
              ).map((m) => (
                <button
                  key={m.key}
                  type="button"
                  onClick={() => updateProfile({ madhhab: m.key as Madhhab })}
                  aria-pressed={profile.madhhab === m.key}
                  className={cn(
                    "tap-target rounded-xl border-2 bg-card px-3 py-3 text-start transition-all motion-base",
                    profile.madhhab === m.key ? "border-primary bg-primary-soft" : "border-border"
                  )}
                >
                  <span className={cn("block text-sm font-semibold", profile.madhhab === m.key && "text-primary")}>
                    {m.label}
                  </span>
                  <span className="mt-0.5 block text-[11px] text-muted-foreground">{m.hint}</span>
                </button>
              ))}
            </div>
          </div>

          <HijriAdjustRow />
        </CardContent>
      </Card>

      {/* লাইভ প্রিভিউ */}
      {withPreview && (
        <Card className="rounded-xl shadow-card">
          <CardContent className="p-4 sm:p-5">
            <SectionLabel icon={<Clock3 className="size-4" />}>আজকের সময়সূচি — লাইভ প্রিভিউ</SectionLabel>
            <ul className="mt-3 divide-y divide-border">
              {SCHEDULE_ROWS.map((key) => (
                <li key={key} className="flex items-center justify-between gap-2 py-2">
                  <span
                    className={cn(
                      "text-sm",
                      key === "sunrise" ? "text-muted-foreground" : "font-medium"
                    )}
                  >
                    {PRAYER_LABELS_BN[key]}
                  </span>
                  <span className="text-sm font-semibold tabular-nums">{formatTimeBn(times[key])}</span>
                </li>
              ))}
            </ul>
            <p className="mt-2 text-[11px] text-muted-foreground text-center">
              সেটিংস বদলালে সাথে সাথেই সময়গুলো বদলে যায় — সব হিসাব আপনার ডিভাইসেই হয়।
            </p>
          </CardContent>
        </Card>
      )}
    </div>
  );
}

/**
 * The member's own Hijri correction (−2..2 days, mobile parity): the moon
 * is sighted locally, so the calculated date can be a day off. Today's
 * Hijri date is shown so the change is easy to judge.
 */
function HijriAdjustRow() {
  const own = useApp((s) => s.profile.hijriAdjust ?? 0);
  const updateProfile = useApp((s) => s.updateProfile);
  const effective = useHijriAdjust();
  const set = (n: number) => updateProfile({ hijriAdjust: Math.max(-2, Math.min(2, n)) });
  const sign = own > 0 ? "+" : own < 0 ? "−" : "";
  return (
    <div className="space-y-1.5">
      <SectionLabel icon={<CalendarDays className="size-4" />}>হিজরি তারিখ সমন্বয়</SectionLabel>
      <div className="flex items-center gap-3 rounded-xl border border-border px-3 py-2.5">
        <div className="min-w-0 flex-1">
          <p className="text-sm font-semibold">আজ {hijriDate(new Date(), effective).formatted}</p>
          <p className="text-xs text-muted-foreground">
            {own === 0 ? "কোনো সমন্বয় নেই" : `${sign}${toBn(Math.abs(own))} দিন`}
          </p>
        </div>
        <Button
          variant="outline"
          size="icon"
          className="size-10 rounded-full"
          aria-label="এক দিন কমান"
          disabled={own <= -2}
          onClick={() => set(own - 1)}
        >
          <Minus className="size-4" />
        </Button>
        <Button
          variant="outline"
          size="icon"
          className="size-10 rounded-full"
          aria-label="এক দিন বাড়ান"
          disabled={own >= 2}
          onClick={() => set(own + 1)}
        >
          <Plus className="size-4" />
        </Button>
      </div>
      <p className="text-xs leading-relaxed text-muted-foreground">
        চাঁদ দেখার ভিত্তিতে তারিখ এক-দুই দিন আগে-পিছে হলে এখানে ঠিক করুন। আইয়ামে বীযের রোযার দিনও এ অনুযায়ী হিসাব হয়।
      </p>
    </div>
  );
}
