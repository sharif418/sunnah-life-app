"use client";

// A browser alert when a waqt begins, for members who keep the site open on
// an office laptop (Notification API; only while the tab is open — the app's
// alarms work when it is closed). The forbidden times moved into the home
// schedule card (prayer-card.tsx) in the 2026-10-07 redesign.

import * as React from "react";
import { Bell, BellOff } from "lucide-react";
import { useNow, usePrayerDay } from "@/components/home/prayer-hooks";
import { PRAYER_LABELS_BN } from "@/types/domain";
import { cn } from "@/lib/utils";

const PREF_KEY = "sl-waqt-alerts";

function readPref(): boolean {
  try {
    return localStorage.getItem(PREF_KEY) === "on";
  } catch {
    return false;
  }
}

export function WaqtAlertsToggle() {
  const now = useNow(60_000);
  const { next } = usePrayerDay(now);
  const [supported, setSupported] = React.useState(false);
  const [on, setOn] = React.useState(false);
  const [denied, setDenied] = React.useState(false);

  React.useEffect(() => {
    const ok = typeof window !== "undefined" && "Notification" in window;
    setSupported(ok);
    if (ok) {
      setDenied(Notification.permission === "denied");
      setOn(readPref() && Notification.permission === "granted");
    }
  }, []);

  // one timer to the next waqt; re-armed as `next` moves on
  React.useEffect(() => {
    if (!on) return;
    const ms = next.at.getTime() - Date.now();
    if (ms <= 0 || ms > 24 * 3600_000) return;
    const id = window.setTimeout(() => {
      try {
        new Notification(`এখন ${PRAYER_LABELS_BN[next.key]}-এর সময়`, {
          body: "সুন্নাহ লাইফ — নামাজের প্রস্তুতি নিন",
          icon: "/icon-192.png",
          tag: `waqt-${next.key}`,
        });
      } catch {
        // some browsers only allow notifications from a service worker
      }
    }, ms);
    return () => window.clearTimeout(id);
  }, [on, next.at, next.key]);

  if (!supported) return null;

  const toggle = async () => {
    if (on) {
      setOn(false);
      try {
        localStorage.setItem(PREF_KEY, "off");
      } catch {}
      return;
    }
    const perm = Notification.permission === "default" ? await Notification.requestPermission() : Notification.permission;
    if (perm !== "granted") {
      setDenied(perm === "denied");
      return;
    }
    setOn(true);
    try {
      localStorage.setItem(PREF_KEY, "on");
    } catch {}
  };

  return (
    <div className="flex items-center gap-3 rounded-xl border border-border bg-card px-4 py-3 shadow-card">
      {on ? <Bell className="size-5 shrink-0 text-primary" aria-hidden /> : <BellOff className="size-5 shrink-0 text-muted-foreground" aria-hidden />}
      <div className="min-w-0 flex-1">
        <p className="text-sm font-semibold">ওয়াক্ত শুরু হলে ব্রাউজারে জানান</p>
        <p className="text-xs leading-relaxed text-muted-foreground">
          {denied
            ? "ব্রাউজারে নোটিফিকেশন বন্ধ করা আছে — ঠিকানাবারের তালার চিহ্ন থেকে চালু করুন।"
            : "এই পাতা খোলা থাকলে কাজ করে। ফোনে অ্যাপ ঘণ্টা বাজায় বন্ধ থাকলেও।"}
        </p>
      </div>
      <button
        type="button"
        role="switch"
        aria-checked={on}
        aria-label="ওয়াক্ত শুরু হলে ব্রাউজারে জানান"
        onClick={toggle}
        disabled={denied && !on}
        className={cn(
          "relative h-6 w-11 shrink-0 rounded-full transition-colors disabled:opacity-50",
          on ? "bg-primary" : "bg-muted"
        )}
      >
        <span className={cn("absolute top-0.5 size-5 rounded-full bg-white shadow transition-all", on ? "start-[22px]" : "start-0.5")} />
      </button>
    </div>
  );
}
