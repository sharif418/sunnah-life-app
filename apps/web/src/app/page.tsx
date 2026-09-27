"use client";

import * as React from "react";
import { useApp } from "@/lib/store";
import { api } from "@/lib/api";
import { AppShell } from "@/components/app/shell";
import { Onboarding } from "@/components/app/onboarding";
import { LogoMark } from "@/components/app/logo";

export default function Page() {
  const { hydrated, profile, setUser, setAuthChecked, setReferralCode } = useApp();

  React.useEffect(() => {
    if (!hydrated) return;
    // Referral landing: /?join=DS-000123 (the mandated /join/DS-1234 route,
    // expressed on the single route available in this workspace).
    const join = new URLSearchParams(window.location.search).get("join");
    if (join && /^ds-\d+$/i.test(join.trim())) {
      setReferralCode(join.trim().toUpperCase());
    }
    api
      .me()
      .then((r) => setUser(r.user))
      .catch(() => {
        setAuthChecked(true);
        useApp.setState({ user: null, authChecked: true });
      });
  }, [hydrated, setUser, setAuthChecked, setReferralCode]);

  if (!hydrated) {
    return (
      <div className="min-h-screen bg-primary flex items-center justify-center">
        <div className="flex flex-col items-center gap-4">
          <LogoMark size={72} />
          <p className="text-primary-foreground/80 text-sm tracking-wide">সুন্নাহ লাইফ লোড হচ্ছে…</p>
        </div>
      </div>
    );
  }

  if (!profile.onboardingDone) return <Onboarding />;
  return <AppShell />;
}
