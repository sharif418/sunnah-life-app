"use client";

// শহর নির্বাচন — bottom sheet with GPS auto-detect + searchable city list
// (64 BD districts + major international cities). Guest-friendly.

import * as React from "react";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { ScrollArea } from "@/components/ui/scroll-area";
import { CITIES } from "@/lib/cities";
import { useApp } from "@/lib/store";
import { toast } from "sonner";
import { Navigation, Search, MapPin, Check } from "lucide-react";
import { cn } from "@/lib/utils";

export function cityLabelBn(city: string): string {
  const c = CITIES.find((x) => x.nameEn === city);
  if (c) return c.nameBn;
  if (city === "GPS") return "GPS অবস্থান";
  return city;
}

export function LocationSheet({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { profile, updateProfile } = useApp();
  const [search, setSearch] = React.useState("");
  const [locating, setLocating] = React.useState(false);

  const pick = (cityEn: string, lat: number, lng: number, label: string) => {
    updateProfile({ city: cityEn, lat, lng });
    onOpenChange(false);
    setSearch("");
    toast.success(`অবস্থান সেট হয়েছে: ${label}`);
  };

  const useGps = () => {
    if (!navigator.geolocation) {
      toast.error("এই ব্রাউজারে GPS সমর্থিত নয় — তালিকা থেকে শহর বাছুন");
      return;
    }
    setLocating(true);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        setLocating(false);
        pick("GPS", pos.coords.latitude, pos.coords.longitude, "GPS অবস্থান");
      },
      () => {
        setLocating(false);
        toast.error("GPS পাওয়া যায়নি — তালিকা থেকে শহর বাছুন");
      },
      { timeout: 8000, maximumAge: 300000 }
    );
  };

  const filtered = search
    ? CITIES.filter(
        (c) => c.nameBn.includes(search) || c.nameEn.toLowerCase().includes(search.toLowerCase())
      )
    : CITIES;

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      <SheetContent side="bottom" className="h-[75vh] px-0 rounded-t-2xl">
        <SheetHeader className="px-5">
          <SheetTitle>শহর নির্বাচন করুন</SheetTitle>
        </SheetHeader>
        <div className="px-5 pb-2">
          <Button
            onClick={useGps}
            disabled={locating}
            variant="secondary"
            className="w-full h-12 rounded-xl"
          >
            <Navigation className={cn("size-4 me-1", locating && "animate-spin")} />
            {locating ? "খোঁজা হচ্ছে…" : "GPS দিয়ে স্বয়ংক্রিয় শনাক্ত"}
          </Button>
        </div>
        <div className="px-5 pb-3">
          <div className="relative">
            <Search className="absolute start-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
            <Input
              placeholder="শহরের নাম লিখুন…"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="h-11 rounded-xl ps-9"
              aria-label="শহর খুঁজুন"
            />
          </div>
        </div>
        <ScrollArea className="h-[46vh] px-3">
          <div className="grid gap-1 pb-4">
            {filtered.map((c) => {
              const active = profile.city === c.nameEn;
              return (
                <button
                  key={c.nameEn}
                  onClick={() => pick(c.nameEn, c.lat, c.lng, c.nameBn)}
                  className={cn(
                    "tap-target w-full flex items-center gap-2.5 rounded-xl px-4 py-3 text-start hover:bg-muted transition-colors",
                    active && "bg-primary-soft"
                  )}
                >
                  <MapPin className={cn("size-4 shrink-0", active ? "text-primary" : "text-muted-foreground")} />
                  <span className="flex-1 min-w-0">
                    <span className="block font-medium truncate">{c.nameBn}</span>
                    <span className="block text-xs text-muted-foreground truncate">
                      {c.nameEn} · {c.country === "BD" ? "বাংলাদেশ" : "আন্তর্জাতিক"}
                    </span>
                  </span>
                  {active && <Check className="size-4 text-primary shrink-0" />}
                </button>
              );
            })}
            {filtered.length === 0 && (
              <p className="py-8 text-center text-sm text-muted-foreground">কোনো শহর মেলেনি</p>
            )}
          </div>
        </ScrollArea>
      </SheetContent>
    </Sheet>
  );
}
