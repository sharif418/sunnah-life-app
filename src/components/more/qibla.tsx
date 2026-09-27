"use client";

// কিবলা কম্পাস — সেন্সর-চালিত লাইভ কম্পাস (DeviceOrientation + iOS অনুমতি),
// সেন্সর না থাকলে ম্যানুয়াল ডায়াল + নির্দেশনা। কিবলার দিক ঠিক হলে
// সোনালি রিং + নিশ্চিতকরণ বার্তা।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Slider } from "@/components/ui/slider";
import { SubShell } from "@/components/more/bits";
import { cityLabel } from "@/components/more/city-picker";
import { useApp } from "@/lib/store";
import { KAABA, qiblaBearing, distanceKm, compassLabelBn } from "@/lib/qibla";
import { toBn } from "@/lib/calendars";
import { Navigation, RotateCw } from "lucide-react";
import { cn } from "@/lib/utils";

type SensorState = "idle" | "live" | "unavailable" | "denied";

interface OrientationEventish {
  alpha: number | null;
  absolute: boolean;
  webkitCompassHeading?: number;
}

export function QiblaView() {
  const profile = useApp((s) => s.profile);
  const bearing = qiblaBearing(profile.lat, profile.lng);
  const distance = distanceKm(profile.lat, profile.lng, KAABA.lat, KAABA.lng);

  const [heading, setHeading] = React.useState<number | null>(null);
  const [sensor, setSensor] = React.useState<SensorState>("idle");
  const [manual, setManual] = React.useState(0); // ডিগ্রি — ম্যানুয়াল ডায়াল

  const handlerRef = React.useRef<((e: Event) => void) | null>(null);
  const timeoutRef = React.useRef<ReturnType<typeof setTimeout> | null>(null);

  const stopSensor = React.useCallback(() => {
    const h = handlerRef.current;
    if (h) {
      window.removeEventListener("deviceorientationabsolute", h, true);
      window.removeEventListener("deviceorientation", h, true);
      handlerRef.current = null;
    }
    if (timeoutRef.current) {
      clearTimeout(timeoutRef.current);
      timeoutRef.current = null;
    }
    setHeading(null);
  }, []);

  React.useEffect(() => stopSensor, [stopSensor]);

  const startSensor = async () => {
    const DOE = (window as unknown as { DeviceOrientationEvent?: unknown }).DeviceOrientationEvent;
    if (!DOE) {
      setSensor("unavailable");
      return;
    }
    // iOS 13+: ব্যবহারকারীর ট্যাপ থেকেই অনুমতি চাইতে হয়।
    const req = (DOE as { requestPermission?: () => Promise<string> }).requestPermission;
    if (typeof req === "function") {
      try {
        const res = await req.call(DOE);
        if (res !== "granted") {
          setSensor("denied");
          return;
        }
      } catch {
        setSensor("denied");
        return;
      }
    }

    const handler = (ev: Event) => {
      const e = ev as unknown as OrientationEventish;
      let h: number | null = null;
      const wkh = e.webkitCompassHeading;
      if (typeof wkh === "number" && isFinite(wkh)) {
        h = wkh; // iOS: সত্যিকারের উত্তর থেকে ঘড়ির কাঁটায়
      } else if (typeof e.alpha === "number" && (e as { absolute?: boolean }).absolute) {
        h = (360 - e.alpha) % 360; // Android absolute
      }
      if (h != null && isFinite(h)) {
        if (timeoutRef.current) {
          clearTimeout(timeoutRef.current);
          timeoutRef.current = null;
        }
        setHeading(h);
        setSensor("live");
      }
    };
    handlerRef.current = handler;
    window.addEventListener("deviceorientationabsolute", handler, true);
    window.addEventListener("deviceorientation", handler, true);

    // ২.৫ সেকেন্ডে কোনো absolute রিডিং না এলে → ম্যানুয়াল মোড।
    timeoutRef.current = setTimeout(() => {
      setSensor((s) => (s === "live" ? s : "unavailable"));
    }, 2500);
  };

  const activeHeading = heading;
  const rotation = activeHeading != null ? -activeHeading : -manual;
  const arrowAngle = bearing + rotation;
  // কিবলা কতটা "সামনে" (স্ক্রিনের উপরের দিকে)?
  const diff = ((arrowAngle % 360) + 540) % 360 - 180;
  const aligned = Math.abs(diff) <= 4;

  return (
    <SubShell title="কিবলা কম্পাস">
      <div className="space-y-4">
        <p className="text-sm text-muted-foreground leading-relaxed text-center px-2">
          ফোন সমতলে ধরে উত্তর দিক ঠিক করে নিন, তারপর তীরের দিকে মুখ করুন।
        </p>

        <div className="flex justify-center">
          <div
            className={cn(
              "relative rounded-full p-2 transition-all motion-slow",
              aligned ? "ring-4 ring-gold" : "ring-0"
            )}
            role="img"
            aria-label={`কিবলা ${Math.round(bearing)} ডিগ্রি`}
          >
            <CompassDial bearing={bearing} rotation={rotation} size={272} />
            {sensor === "live" && (
              <span className="absolute top-2 start-1/2 -translate-x-1/2 inline-flex items-center gap-1.5 rounded-full bg-card border border-border px-2.5 py-1 text-[10.5px] font-bold text-primary shadow-card">
                <span className="size-1.5 rounded-full bg-success animate-pulse" />
                লাইভ
              </span>
            )}
          </div>
        </div>

        {/* বিয়ারিং ও দূরত্ব */}
        <div className="grid grid-cols-2 gap-3">
          <Card className="rounded-xl shadow-card">
            <CardContent className="p-3.5 text-center">
              <p className="text-[11px] text-muted-foreground">কিবলার দিক</p>
              <p className="mt-0.5 text-lg font-extrabold tabular-nums text-primary">
                {toBn(bearing.toFixed(1))}°
              </p>
              <p className="text-xs text-muted-foreground">{compassLabelBn(bearing)}</p>
            </CardContent>
          </Card>
          <Card className="rounded-xl shadow-card">
            <CardContent className="p-3.5 text-center">
              <p className="text-[11px] text-muted-foreground">কাবা থেকে দূরত্ব</p>
              <p className="mt-0.5 text-lg font-extrabold tabular-nums">
                {toBn(Math.round(distance).toLocaleString("en-IN"))}
              </p>
              <p className="text-xs text-muted-foreground">কিলোমিটার · {cityLabel(profile.city)}</p>
            </CardContent>
          </Card>
        </div>

        {/* অবস্থা অনুযায়ী নিয়ন্ত্রণ */}
        {sensor === "live" ? (
          <div
            className={cn(
              "rounded-xl p-4 text-center text-sm font-semibold border transition-colors",
              aligned
                ? "bg-gold-soft border-gold/50 text-warning"
                : "bg-primary-soft border-primary/20 text-primary"
            )}
            aria-live="polite"
          >
            {aligned
              ? "আলহামদুলিল্লাহ — এই দিকেই কিবলা"
              : `ডিভাইস ঘোরান — তীর উপরে এলেই কিবলা`}
            <Button
              variant="outline"
              size="sm"
              className="mt-2 h-11 rounded-xl block mx-auto bg-card"
              onClick={() => {
                stopSensor();
                setSensor("idle");
              }}
            >
              সেন্সর বন্ধ করুন
            </Button>
          </div>
        ) : sensor === "idle" ? (
          <Button className="w-full h-12 rounded-xl text-base" onClick={startSensor}>
            <Navigation className="size-4" /> সেন্সর চালু করুন (লাইভ কম্পাস)
          </Button>
        ) : (
          <Card className="rounded-xl border-gold/40 bg-gold-soft/50 shadow-card">
            <CardContent className="p-4 space-y-3">
              <p className="text-sm leading-relaxed">
                {sensor === "denied"
                  ? "কম্পাস সেন্সরের অনুমতি পাওয়া যায়নি — নিচের ম্যানুয়াল ডায়াল ব্যবহার করুন।"
                  : "এই ডিভাইসে কম্পাস সেন্সর নেই — ম্যানুয়াল ডায়াল ব্যবহার করুন।"}
              </p>
              <div className="flex items-center gap-2.5">
                <RotateCw className="size-4 text-warning shrink-0" />
                <Slider
                  value={[manual]}
                  min={-180}
                  max={180}
                  step={1}
                  onValueChange={(v) => setManual(v[0] ?? 0)}
                  aria-label="ডায়াল ঘোরান"
                />
                <span className="w-14 text-end text-xs font-semibold text-muted-foreground tabular-nums shrink-0">
                  {toBn(Math.round(Math.abs(manual)))}°
                </span>
              </div>
              <p className="text-[11.5px] text-muted-foreground leading-relaxed">
                আসল উত্তর যেদিকে জানেন (রোদ বা অন্য কম্পাস থেকে) সেটা ধরে ডায়াল ঘোরান — "উত্তর" লেবেল
                যেন ঠিক উপরে আসে। তখন তীরই কিবলার দিক দেখাবে।
              </p>
            </CardContent>
          </Card>
        )}

        <p className="text-center text-[11px] text-muted-foreground leading-relaxed px-2">
          হিসাব আপনার ডিভাইসেই হয় (অফলাইন) · বিয়ারিং সত্যিকারের উত্তর থেকে, চুম্বকীয় নয়।
        </p>
      </div>
    </SubShell>
  );
}

/** SVG কম্পাস ডায়াল — রোজ + কার্ডিনাল লেবেল ঘোরে, তীর কিবলায়, উপরের চিহ্ন স্থির। */
function CompassDial({ bearing, rotation, size }: { bearing: number; rotation: number; size: number }) {
  const arrowAngle = bearing + rotation;
  return (
    <svg viewBox="0 0 200 200" style={{ width: size, height: size }} aria-hidden="true">
      {/* বাইরের রিং */}
      <circle cx="100" cy="100" r="96" className="fill-card stroke-border" strokeWidth="2" />
      <circle cx="100" cy="100" r="84" className="fill-none stroke-border" strokeWidth="0.75" />

      <g transform={`rotate(${rotation} 100 100)`} style={{ transition: "transform 150ms ease-out" }}>
        {/* টিক মার্ক */}
        {Array.from({ length: 24 }, (_, i) => i * 15).map((a) => {
          const major = a % 90 === 0;
          return (
            <line
              key={a}
              x1="100"
              y1={major ? 12 : 17}
              x2="100"
              y2="24"
              className={major ? "stroke-foreground" : "stroke-muted-foreground/50"}
              strokeWidth={major ? 2.5 : 1.2}
              transform={`rotate(${a} 100 100)`}
            />
          );
        })}
        {/* কার্ডিনাল লেবেল (বাংলা) */}
        <text x="100" y="40" textAnchor="middle" fontSize="12" fontWeight="800" className="fill-gold">
          উত্তর
        </text>
        <text x="160" y="104" textAnchor="middle" fontSize="10" fontWeight="700" className="fill-muted-foreground">
          পূর্ব
        </text>
        <text x="100" y="172" textAnchor="middle" fontSize="10" fontWeight="700" className="fill-muted-foreground">
          দক্ষিণ
        </text>
        <text x="40" y="104" textAnchor="middle" fontSize="10" fontWeight="700" className="fill-muted-foreground">
          পশ্চিম
        </text>
      </g>

      {/* কিবলা তীর — কার্ড-ফ্রেমে, দিক bearing + rotation */}
      <g transform={`rotate(${arrowAngle} 100 100)`} style={{ transition: "transform 150ms ease-out" }}>
        <line x1="100" y1="132" x2="100" y2="36" className="stroke-primary" strokeWidth="5.5" strokeLinecap="round" />
        <path d="M100 26 L109 44 L100 39 L91 44 Z" className="fill-primary" />
        {/* কাবা মার্কার */}
        <rect x="93" y="22" width="14" height="14" transform="rotate(45 100 29)" className="fill-foreground" />
        <line x1="93" y1="27" x2="107" y2="27" className="stroke-gold" strokeWidth="2" />
      </g>

      {/* কেন্দ্র */}
      <circle cx="100" cy="100" r="6" className="fill-primary" />
      <circle cx="100" cy="100" r="2.5" className="fill-card" />

      {/* স্থির উপরের চিহ্ন */}
      <path d="M100 1 L106 11 L94 11 Z" className="fill-gold" />
    </svg>
  );
}
