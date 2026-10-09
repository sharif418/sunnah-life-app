"use client";

import * as React from "react";
import { usePathname, useRouter } from "next/navigation";
import { useSession } from "@/lib/session";
import { homeRoute, routeAllowed } from "@/lib/routes";
import { AppShell } from "@/components/app-shell";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ShieldAlert } from "lucide-react";

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const { status, user } = useSession();
  const pathname = usePathname();
  const router = useRouter();

  React.useEffect(() => {
    if (status === "anonymous") router.replace("/login");
  }, [status, router]);

  // W4h — URL-level role gate: a role opening a page outside its map is
  // redirected to their dashboard (not a 403 wall). The nav filters links;
  // this catches direct URLs / stale bookmarks. The API re-checks everything.
  const allowed = routeAllowed(pathname, user);
  React.useEffect(() => {
    if (status === "authenticated" && user && !routeAllowed(pathname, user)) {
      router.replace(homeRoute(user));
    }
  }, [status, user, pathname, router]);

  if (status === "loading") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-6">
        <div className="w-full max-w-5xl space-y-4" aria-label="লোড হচ্ছে" role="status">
          <div className="skeleton h-12 w-64" />
          <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {Array.from({ length: 4 }).map((_, i) => (
              <div key={i} className="skeleton h-28" />
            ))}
          </div>
          <div className="skeleton h-64" />
        </div>
      </div>
    );
  }

  if (status === "forbidden") {
    return (
      <div className="flex min-h-screen items-center justify-center bg-background p-6">
        <Card className="max-w-md">
          <CardContent className="flex flex-col items-center gap-3 pt-5 text-center">
            <div className="flex h-14 w-14 items-center justify-center rounded-full bg-alert-soft text-alert">
              <ShieldAlert className="h-7 w-7" aria-hidden />
            </div>
            <h2 className="text-lg font-bold">এই প্যানেলটি তত্ত্বাবধায়কদের জন্য</h2>
            <p className="text-sm leading-relaxed text-muted-foreground">
              স্বাগতম {user?.name}! আপনার ভূমিকা অনুযায়ী অ্যাডমিন প্যানেল ব্যবহারের অনুমতি নেই।
              উসরা প্রধান, পরিদর্শক, প্রধান অ্যাডমিন বা কনটেন্ট দলের অ্যাকাউন্ট দিয়ে লগইন করুন।
            </p>
            <Button variant="destructive" className="mt-2" onClick={() => router.push("/login")}>
              লগআউট করুন
            </Button>
          </CardContent>
        </Card>
      </div>
    );
  }

  if (status !== "authenticated") return null;

  // redirecting to the dashboard — render nothing (no forbidden flash)
  if (!allowed && user) return null;

  return <AppShell>{children}</AppShell>;
}
