"use client";

// কিবলা কার্ড — বিয়ারিং + মক্কার দূরত্ব + পূর্ণ কম্পাসে যাওয়ার শর্টকাট।

import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { useApp } from "@/lib/store";
import { KAABA, qiblaBearing, distanceKm, compassLabelBn } from "@/lib/qibla";
import { toBn } from "@/lib/calendars";
import { Compass } from "lucide-react";

export function QiblaCard() {
  const { profile, nav } = useApp();
  const bearing = qiblaBearing(profile.lat, profile.lng);
  const distance = distanceKm(profile.lat, profile.lng, KAABA.lat, KAABA.lng);

  return (
    <Card className="rounded-xl shadow-card">
      <CardContent className="p-4 flex items-center gap-4">
        <MiniDial bearing={bearing} />
        <div className="flex-1 min-w-0">
          <p className="font-bold leading-snug">
            কিবলা {toBn(bearing.toFixed(1))}° — {compassLabelBn(bearing)} দিকে
          </p>
          <p className="mt-0.5 text-sm text-muted-foreground leading-snug">
            কাবা থেকে {toBn(Math.round(distance).toLocaleString("en-IN"))} কিমি দূরে
          </p>
        </div>
        <Button
          variant="outline"
          className="h-11 rounded-xl shrink-0"
          onClick={() => nav("more", "qibla")}
          aria-label="কিবলা কম্পাস খুলুন"
        >
          <Compass className="size-4" />
          <span className="hidden min-[380px]:inline">কম্পাস</span>
        </Button>
      </CardContent>
    </Card>
  );
}

/** ছোট স্ট্যাটিক ডায়াল — তীর সবসময় কিবলার দিকে নির্দেশ করে। */
function MiniDial({ bearing }: { bearing: number }) {
  return (
    <svg
      viewBox="0 0 80 80"
      className="size-[72px] shrink-0"
      role="img"
      aria-label={`কিবলা ${Math.round(bearing)} ডিগ্রি`}
    >
      <circle cx="40" cy="40" r="37" className="fill-primary-soft stroke-border" strokeWidth="1.5" />
      {/* প্রধান টিক */}
      {[0, 90, 180, 270].map((a) => (
        <line
          key={a}
          x1="40"
          y1="7"
          x2="40"
          y2="13"
          className="stroke-muted-foreground"
          strokeWidth="2"
          transform={`rotate(${a} 40 40)`}
        />
      ))}
      {/* উত্তর চিহ্ন */}
      <text x="40" y="21" textAnchor="middle" fontSize="8" fontWeight="700" className="fill-gold">
        উ
      </text>
      {/* কিবলা তীর */}
      <g transform={`rotate(${bearing} 40 40)`}>
        <line x1="40" y1="52" x2="40" y2="22" className="stroke-primary" strokeWidth="4" strokeLinecap="round" />
        <path d="M40 12 L47 26 L40 22 L33 26 Z" className="fill-primary" />
      </g>
      <circle cx="40" cy="40" r="3.5" className="fill-primary" />
    </svg>
  );
}
