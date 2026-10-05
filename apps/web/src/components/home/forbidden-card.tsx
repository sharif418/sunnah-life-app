"use client";

// Two things the app has and the web did not (mobile parity):
//   • নামাজ পড়া নিষেধ — today's three forbidden windows (sunrise, zawal,
//     sunset) as one compact card; the one in force now is marked.
//   • a browser alert when a waqt begins, for members who keep the site open
//     on an office laptop (Notification API; only while the tab is open —
//     the app's alarms work when it is closed).

import * as React from "react";
import { Ban, Bell, BellOff } from "lucide-react";
import { useNow, usePrayerDay } from "@/components/home/prayer-hooks";
import { forbiddenWindows } from "@/lib/prayer-times";
import { formatTimeBn } from "@/lib/calendars";
import { PRAYER_LABELS_BN } from "@/types/domain";
import { cn } from "@/lib/utils";

const SHORT: Record<string, string> = { sunrise: "সূর্যোদয়", zawal: "যাওয়াল", sunset: "সূর্যাস্ত" };

export function ForbiddenTimesCard() {
  const now = useNow(30_000);
  const { times } = usePrayerDay(now);
  const nowMin = now.getHours() * 60 + now.getMinutes();
  const windows = forbiddenWindows(times);
  return (
    <section
      aria-label="নামাজ পড়া নিষেধ"
      className="rounded-xl border border-alert/25 bg-alert-soft px-4 py-3 text-alert"
    >
      <h2 className="flex items-center gap-2 text-sm font-bold">
        <Ban className="size-4" aria-hidden /> নামাজ পড়া নিষেধ
      </h2>
      <ul className="mt-1.5 space-y-1 ps-6 text-sm">
        {windows.map((w) => {
          const active = nowMin >= w.from && nowMin <= w.to;
          return (
            <li key={w.key} className={cn("flex items-center gap-2", active && "font-bold")}>
              <span className="min-w-0 flex-1">
                {SHORT[w.key] ?? w.labelBn}
                {active ? <span className="ms-2 rounded-full bg-alert px-2 py-0.5 text-[11px] text-white">এখন</span> : null}
              </span>
              <span className="shrink-0 tabular-nums">
                {formatTimeBn(w.from)} — {formatTimeBn(w.to)}
              </span>
            </li>
          );
        })}
      </ul>
    </section>
  );
}

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
