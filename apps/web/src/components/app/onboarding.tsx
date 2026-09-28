"use client";

import * as React from "react";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { ScrollArea } from "@/components/ui/scroll-area";
import { Sheet, SheetContent, SheetHeader, SheetTitle, SheetTrigger } from "@/components/ui/sheet";
import { LogoMark } from "@/components/app/logo";
import { CITIES } from "@/lib/cities";
import { useApp } from "@/lib/store";
import { CALC_METHODS } from "@/lib/prayer-times";
import { translate } from "@/lib/i18n";
import { MapPin, Navigation, Languages, UserRound, Moon, Check, Search } from "lucide-react";
import type { CalcMethodKey, Gender, Lang } from "@/types/domain";
import { cn } from "@/lib/utils";

const LANGS: { key: Lang; label: string; native: string }[] = [
  { key: "bn", label: "বাংলা", native: "বাংলাদেশের প্রধান ভাষা" },
  { key: "en", label: "English", native: "For international users" },
  { key: "ar", label: "العربية", native: "بالدعم الكامل للاتجاه من اليمين إلى اليسار" },
];

export function Onboarding() {
  const { profile, updateProfile } = useApp();
  const t = (k: string) => translate(profile.language, k);
  const [step, setStep] = React.useState(0);
  const [name, setName] = React.useState(profile.name);
  const [gender, setGender] = React.useState<Gender | null>(profile.gender);
  const [citySearch, setCitySearch] = React.useState("");

  const setCity = (cityEn: string) => {
    const c = CITIES.find((x) => x.nameEn === cityEn);
    if (!c) return;
    updateProfile({ city: c.nameEn, lat: c.lat, lng: c.lng });
  };

  const useGps = () => {
    if (!navigator.geolocation) return;
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        updateProfile({
          city: "GPS",
          lat: pos.coords.latitude,
          lng: pos.coords.longitude,
        });
      },
      () => null,
      { timeout: 8000 }
    );
  };

  const filteredCities = citySearch
    ? CITIES.filter(
        (c) =>
          c.nameBn.includes(citySearch) ||
          c.nameEn.toLowerCase().includes(citySearch.toLowerCase())
      )
    : CITIES;

  const canNext = step === 0 ? true : step === 1 ? name.trim().length > 0 && !!gender : true;

  return (
    <div className="min-h-screen bg-primary text-primary-foreground flex flex-col" dir="ltr">
      {/* Hero */}
      <div className="bg-pattern-islamic relative px-6 pt-14 pb-10">
        <div className="flex items-center gap-3">
          <LogoMark size={52} />
          <div>
            <h1 className="text-2xl font-bold leading-tight">সুন্নাহ লাইফ</h1>
            <p className="text-sm text-primary-foreground/70">আস-সুন্নাহ ফাউন্ডেশন — দাওয়াতুস সুন্নাহ</p>
          </div>
        </div>
        <div className="mt-8 h-1.5 w-24 rounded-full bg-primary-foreground/15 overflow-hidden">
          <motion.div
            className="h-full bg-gold"
            animate={{ width: `${((step + 1) / 3) * 100}%` }}
            transition={{ duration: 0.32 }}
          />
        </div>
        <p className="mt-3 text-xs text-primary-foreground/60">{step + 1} / ৩ — সেটআপ</p>
      </div>

      {/* Steps */}
      <div className="flex-1 bg-background text-foreground rounded-t-[28px] -mt-6 relative z-10 px-5 pt-8 pb-8 flex flex-col">
        <div className="flex-1">
          {step === 0 && (
            <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
              <SectionTitle icon={<Languages className="size-5" />} title={t("onb.language")} />
              <div className="grid gap-3 mt-5">
                {LANGS.map((l) => (
                  <button
                    key={l.key}
                    onClick={() => updateProfile({ language: l.key })}
                    className={cn(
                      "tap-target flex items-center justify-between rounded-xl border-2 bg-card px-5 py-4 text-start transition-all motion-base",
                      profile.language === l.key
                        ? "border-primary bg-primary-soft"
                        : "border-border hover:border-primary/40"
                    )}
                  >
                    <span>
                      <span className="block font-semibold text-lg">{l.label}</span>
                      <span className="block text-xs text-muted-foreground mt-0.5">{l.native}</span>
                    </span>
                    {profile.language === l.key && <Check className="size-5 text-primary" />}
                  </button>
                ))}
              </div>
            </motion.div>
          )}

          {step === 1 && (
            <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
              <SectionTitle icon={<UserRound className="size-5" />} title="আপনার পরিচয়" />
              <div className="mt-5 space-y-4">
                <div className="space-y-1.5">
                  <Label htmlFor="ob-name">নাম</Label>
                  <Input
                    id="ob-name"
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="যেমন: আব্দুল্লাহ"
                    className="h-12 rounded-xl text-base"
                  />
                </div>
                <div className="space-y-1.5">
                  <Label>লিঙ্গ</Label>
                  <div className="grid grid-cols-2 gap-3">
                    {(
                      [
                        { g: "M" as Gender, label: "পুরুষ", emoji: "👨" },
                        { g: "F" as Gender, label: "নারী", emoji: "👩" },
                      ]
                    ).map((x) => (
                      <button
                        key={x.g}
                        onClick={() => setGender(x.g)}
                        className={cn(
                          "tap-target rounded-xl border-2 bg-card px-4 py-4 transition-all motion-base",
                          gender === x.g ? "border-primary bg-primary-soft" : "border-border"
                        )}
                      >
                        <span className="text-2xl">{x.emoji}</span>
                        <span className="block font-semibold mt-1">{x.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
                {gender === "F" && (
                  <div className="rounded-xl bg-gold-soft border border-gold/30 px-4 py-3 text-sm leading-relaxed">
                    🌸 <b>নিশ্চিত থাকুন:</b> নারীদের আমল ও তথ্য শুধুমাত্র নারী সুপারভাইজর
                    (উসরা প্রধান ও পরিদর্শক) দেখতে পারবেন — পুরুষ কেউ নয়।
                  </div>
                )}
              </div>
            </motion.div>
          )}

          {step === 2 && (
            <motion.div initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.2 }}>
              <SectionTitle icon={<MapPin className="size-5" />} title="অবস্থান ও নামাজের হিসাব" />
              <div className="mt-5 space-y-4">
                <Sheet>
                  <SheetTrigger asChild>
                    <button className="tap-target w-full flex items-center justify-between rounded-xl border-2 border-border bg-card px-4 py-3.5">
                      <span className="flex items-center gap-2.5">
                        <MapPin className="size-5 text-primary" />
                        <span className="text-start">
                          <span className="block font-semibold">{cityLabel(profile.city)}</span>
                          <span className="block text-xs text-muted-foreground">শহর পরিবর্তন করুন</span>
                        </span>
                      </span>
                      <Search className="size-4 text-muted-foreground" />
                    </button>
                  </SheetTrigger>
                  <SheetContent side="bottom" className="h-[75vh] px-0">
                    <SheetHeader className="px-5">
                      <SheetTitle>শহর নির্বাচন করুন</SheetTitle>
                    </SheetHeader>
                    <div className="px-5 pb-2">
                      <Button onClick={useGps} variant="secondary" className="w-full h-12 rounded-xl">
                        <Navigation className="size-4 me-2" /> GPS দিয়ে স্বয়ংক্রিয় শনাক্ত
                      </Button>
                    </div>
                    <div className="px-5 pb-3">
                      <Input
                        placeholder="শহরের নাম লিখুন…"
                        value={citySearch}
                        onChange={(e) => setCitySearch(e.target.value)}
                        className="h-11 rounded-xl"
                      />
                    </div>
                    <ScrollArea className="h-[46vh] px-3">
                      <div className="grid gap-1">
                        {filteredCities.map((c) => (
                          <button
                            key={c.nameEn}
                            onClick={() => {
                              setCity(c.nameEn);
                              setCitySearch("");
                            }}
                            className={cn(
                              "w-full flex items-center justify-between rounded-xl px-4 py-3 text-start hover:bg-muted transition-colors",
                              profile.city === c.nameEn && "bg-primary-soft"
                            )}
                          >
                            <span className="font-medium">{c.nameBn}</span>
                            <span className="text-xs text-muted-foreground">{c.nameEn}</span>
                          </button>
                        ))}
                      </div>
                    </ScrollArea>
                  </SheetContent>
                </Sheet>

                <div className="grid grid-cols-2 gap-3">
                  <div className="space-y-1.5">
                    <Label>মাযহাব (আসর)</Label>
                    <div className="grid grid-cols-2 gap-1.5 rounded-xl bg-muted p-1.5">
                      {(["hanafi", "shafii"] as const).map((m) => (
                        <button
                          key={m}
                          onClick={() => updateProfile({ madhhab: m })}
                          className={cn(
                            "h-9 rounded-lg text-sm font-medium transition-all",
                            profile.madhhab === m ? "bg-card shadow-sm text-primary" : "text-muted-foreground"
                          )}
                        >
                          {m === "hanafi" ? "হানাফি" : "শাফেয়ি"}
                        </button>
                      ))}
                    </div>
                  </div>
                  <div className="space-y-1.5">
                    <Label>হিসাব পদ্ধতি</Label>
                    <select
                      value={profile.method}
                      onChange={(e) => updateProfile({ method: e.target.value as CalcMethodKey })}
                      className="h-11 w-full rounded-xl border border-input bg-card px-3 text-sm"
                    >
                      {(Object.keys(CALC_METHODS) as CalcMethodKey[]).map((k) => (
                        <option key={k} value={k}>
                          {CALC_METHODS[k].labelBn}
                        </option>
                      ))}
                    </select>
                  </div>
                </div>
                <p className="text-xs text-muted-foreground leading-relaxed">
                  বাংলাদেশের জন্য ডিফল্ট: করাচি পদ্ধতি ও হানাফি আসর। সব হিসাব আপনার ফোনেই হয় —
                  ইন্টারনেট ছাড়াও কাজ করবে।
                </p>
              </div>
            </motion.div>
          )}
        </div>

        <div className="flex gap-3 pt-6">
          {step > 0 && (
            <Button variant="outline" className="h-12 rounded-xl px-6" onClick={() => setStep((s) => s - 1)}>
              পেছানে
            </Button>
          )}
          <Button
            disabled={!canNext}
            className="h-12 flex-1 rounded-xl text-base font-semibold"
            onClick={() => {
              if (step < 2) {
                setStep((s) => s + 1);
              } else {
                updateProfile({ name: name.trim() || "ব্যবহারকারী", gender: gender ?? "M", onboardingDone: true });
              }
            }}
          >
            {step < 2 ? "পরবর্তী" : "বিসমিল্লাহ — শুরু করুন"}
          </Button>
        </div>
      </div>
    </div>
  );
}

function cityLabel(city: string): string {
  const c = CITIES.find((x) => x.nameEn === city);
  if (c) return `${c.nameBn} (${c.country === "BD" ? "বাংলাদেশ" : "বিদেশ"})`;
  if (city === "GPS") return "GPS অবস্থান";
  return city;
}

function SectionTitle({ icon, title }: { icon: React.ReactNode; title: string }) {
  return (
    <div className="flex items-center gap-2.5 text-primary">
      {icon}
      <h2 className="text-xl font-bold">{title}</h2>
    </div>
  );
}
