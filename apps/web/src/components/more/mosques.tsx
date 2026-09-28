"use client";

// আমার মসজিদ — content/mosques.json প্যাক থেকে তালিকা, অবস্থান থেকে দূরত্ব অনুসারে সাজানো।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";
import { Button } from "@/components/ui/button";
import { SubShell, ErrorRetry, EmptyState } from "@/components/more/bits";
import { getPack } from "@/lib/content";
import type { MosquesPack } from "@/lib/content";
import { useApp } from "@/lib/store";
import { distanceKm } from "@/lib/qibla";
import { toBn } from "@/lib/calendars";
import type { MosqueInfo } from "@/types/domain";
import { Landmark, ExternalLink, MapPin } from "lucide-react";

export function MosquesView() {
  const profile = useApp((s) => s.profile);
  const [mosques, setMosques] = React.useState<MosqueInfo[] | null>(null);
  const [error, setError] = React.useState(false);
  const [reload, setReload] = React.useState(0);

  React.useEffect(() => {
    let alive = true;
    setMosques(null);
    setError(false);
    getPack("mosques")
      // content.ts-এর getPack রিটার্ন-টাইপ জেনেরিক ইনফারেন্সে ভেঙে থাকায় কাস্ট (lib ফাইল আমার নয়)।
      .then((p) => {
        const pack = p as unknown as MosquesPack;
        if (alive) setMosques(Array.isArray(pack.mosques) ? pack.mosques : []);
      })
      .catch(() => alive && setError(true));
    return () => {
      alive = false;
    };
  }, [reload]);

  const sorted = React.useMemo(() => {
    if (!mosques) return null;
    return [...mosques].sort(
      (a, b) =>
        distanceKm(profile.lat, profile.lng, a.lat, a.lng) -
        distanceKm(profile.lat, profile.lng, b.lat, b.lng)
    );
  }, [mosques, profile.lat, profile.lng]);

  return (
    <SubShell title="আমার মসজিদ">
      {error ? (
        <ErrorRetry message="মসজিদের তালিকা আনা যায়নি।" onRetry={() => setReload((r) => r + 1)} />
      ) : sorted === null ? (
        <div className="space-y-3">
          {[0, 1, 2, 3, 4].map((i) => (
            <Skeleton key={i} className="h-[76px] rounded-xl" />
          ))}
        </div>
      ) : sorted.length === 0 ? (
        <Card className="rounded-xl">
          <CardContent className="p-2">
            <EmptyState
              icon={<Landmark className="size-9" />}
              message="এখনো কোনো মসজিদ যোগ করা হয়নি"
              hint="অদ্যাবধি কনটেন্ট প্যাকটি খালি — শিগগিরই যোগ হবে ইনশাআল্লাহ।"
            />
          </CardContent>
        </Card>
      ) : (
        <ul className="space-y-3" aria-label="নিকটবর্তী মসজিদসমূহ">
          {sorted.map((m) => {
            const km = distanceKm(profile.lat, profile.lng, m.lat, m.lng);
            return (
              <li key={m.id}>
                <Card className="rounded-xl shadow-card">
                  <CardContent className="p-3.5 flex items-center gap-3">
                    <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary">
                      <Landmark className="size-5" />
                    </span>
                    <span className="flex-1 min-w-0">
                      <span className="block text-sm font-semibold leading-snug">{m.nameBn}</span>
                      <span className="mt-0.5 flex items-center gap-1 text-xs text-muted-foreground leading-snug">
                        <MapPin className="size-3 shrink-0" />
                        <span className="truncate">{m.addressBn}</span>
                      </span>
                    </span>
                    <span className="text-end shrink-0">
                      <span className="block text-base font-extrabold tabular-nums leading-none">
                        {toBn(km >= 100 ? Math.round(km) : km.toFixed(1))}
                      </span>
                      <span className="block text-[10.5px] text-muted-foreground">কিমি</span>
                    </span>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="size-11 rounded-full shrink-0"
                      aria-label={`${m.nameBn} — ম্যাপে দেখুন`}
                      onClick={() =>
                        window.open(
                          `https://www.google.com/maps/search/?api=1&query=${m.lat},${m.lng}`,
                          "_blank",
                          "noopener,noreferrer"
                        )
                      }
                    >
                      <ExternalLink className="size-4" />
                    </Button>
                  </CardContent>
                </Card>
              </li>
            );
          })}
        </ul>
      )}
    </SubShell>
  );
}
