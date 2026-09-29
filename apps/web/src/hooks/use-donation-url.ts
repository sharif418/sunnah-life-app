"use client";

// Donation URL — from /api/config with the as-sunnah.org fallback bundled,
// so the header's Donate button works even before the config round-trip
// (or when the API is unreachable). Mirrors the codebase's direct
// api.config() idiom (prayer-hero, about, contacts).

import * as React from "react";
import { api } from "@/lib/api";

export const FALLBACK_DONATION_URL = "https://as-sunnah.org/donation";

export function useDonationUrl(): string {
  const [url, setUrl] = React.useState(FALLBACK_DONATION_URL);
  React.useEffect(() => {
    let alive = true;
    api
      .config()
      .then((c) => {
        if (alive && c.donationUrl) setUrl(c.donationUrl);
      })
      .catch(() => null);
    return () => {
      alive = false;
    };
  }, []);
  return url;
}
