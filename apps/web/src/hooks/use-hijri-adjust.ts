"use client";

// Effective Hijri day correction (mobile parity, calendars.dart
// `effectiveHijriAdjust`): the member's own correction (−2..2, prayer
// settings) plus the admin's (−2..2, GET /api/config), summed and clamped
// to −4..4. Every Hijri date and the ayyam-e-beez check read this one value.

import * as React from "react";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";

let adminAdjust: Promise<number> | null = null;

function loadAdminAdjust(): Promise<number> {
  adminAdjust ??= api
    .config()
    .then((c) => c.hijriAdjust || 0)
    .catch(() => {
      adminAdjust = null; // try again next time
      return 0;
    });
  return adminAdjust;
}

export function effectiveHijriAdjust(user: number, admin: number): number {
  return Math.max(-4, Math.min(4, user + admin));
}

export function useHijriAdjust(): number {
  const user = useApp((s) => s.profile.hijriAdjust ?? 0);
  const [admin, setAdmin] = React.useState(0);
  React.useEffect(() => {
    let alive = true;
    void loadAdminAdjust().then((n) => alive && setAdmin(n));
    return () => {
      alive = false;
    };
  }, []);
  return effectiveHijriAdjust(user, admin);
}
