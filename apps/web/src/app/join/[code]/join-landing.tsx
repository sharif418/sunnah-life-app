"use client";

import * as React from "react";
import { LogoMark } from "@/components/app/logo";

// TODO(owner): replace the fallback with the Play Store listing URL once
// published (env override: NEXT_PUBLIC_APP_DOWNLOAD_URL — e.g.
// https://play.google.com/store/apps/details?id=bd.asunnah.sunnah_life).
const APP_DOWNLOAD_URL = process.env.NEXT_PUBLIC_APP_DOWNLOAD_URL ?? "#download";

/** Stable key the (future) web sign-up consumes — matches the PLAN's /join capture. */
const JOIN_CODE_STORAGE_KEY = "sl_join_code";

/** Same shape as the API's member codes (apps/api nextMemberCode: DS-XXXXXX). */
const MEMBER_CODE_RE = /^ds-\d{6,}$/i;

export function JoinLanding({ code }: { code: string }) {
  const [copied, setCopied] = React.useState(false);

  // Persist for a later web sign-up (mobile installs read the code through
  // the deep link itself — this storage is the web-only side of the story).
  React.useEffect(() => {
    if (!MEMBER_CODE_RE.test(code)) return;
    try {
      window.localStorage.setItem(JOIN_CODE_STORAGE_KEY, code.toUpperCase());
    } catch {
      // private mode / storage disabled — the page still works
    }
  }, [code]);

  const copyCode = async () => {
    try {
      await navigator.clipboard.writeText(code.toUpperCase());
    } catch {
      // clipboard API unavailable (http, older browsers) — try the legacy path
      try {
        const ta = document.createElement("textarea");
        ta.value = code.toUpperCase();
        document.body.appendChild(ta);
        ta.select();
        document.execCommand("copy");
        ta.remove();
      } catch {
        // still not copyable — the code is displayed prominently anyway
        return;
      }
    }
    setCopied(true);
    window.setTimeout(() => setCopied(false), 2000);
  };

  return (
    <main className="min-h-screen bg-primary text-primary-foreground flex items-center justify-center p-6">
      <div className="w-full max-w-md">
        <div className="flex flex-col items-center gap-3 mb-8">
          <LogoMark size={64} />
          <div className="text-center">
            <h1 className="text-2xl font-bold tracking-tight">সুন্নাহ লাইফ-এ যোগ দিন</h1>
            <p className="text-primary-foreground/70 text-sm mt-1">
              নামাজের সময়সূচি, আমলনামা, কুরআন ও তারবিয়াত — সব এক অ্যাপে।
            </p>
          </div>
        </div>

        {/* The referral code — prominent */}
        <div className="bg-card text-card-foreground rounded-2xl shadow-card p-6 flex flex-col items-center gap-3">
          <p className="text-xs text-muted-foreground">রেফারেল কোড</p>
          <p className="text-3xl font-bold tracking-[0.2em] text-primary" data-testid="join-code">
            {code.toUpperCase()}
          </p>
          <button
            type="button"
            onClick={copyCode}
            className="text-sm text-muted-foreground hover:text-foreground underline underline-offset-4 transition-colors"
          >
            {copied ? "কপি হয়েছে ✓" : "কোড কপি করুন"}
          </button>
        </div>

        {/* Open in the installed app (custom scheme; does nothing on desktop
            browsers — the download link below is the alternative). */}
        <a
          href={`sunnahlife://join/${code}`}
          className="mt-6 block w-full bg-gold text-[#1F4D3D] font-bold text-center py-4 rounded-xl hover:opacity-90 transition-opacity"
        >
          অ্যাপে খুলুন
        </a>

        <a
          href={APP_DOWNLOAD_URL}
          className="mt-3 block w-full text-center py-3 rounded-xl border border-primary-foreground/30 text-primary-foreground/90 hover:bg-primary-foreground/10 transition-colors"
        >
          অ্যাপ ডাউনলোড করুন
        </a>

        <p className="mt-6 text-center text-xs text-primary-foreground/50">
          অ্যাপ ইনস্টল থাকলে “অ্যাপে খুলুন” সরাসরি খুলবে — সাইন ইন করার সময় কোডটি
          স্বয়ংক্রিয়ভাবে যুক্ত হবে ইনশাআল্লাহ।
        </p>

        <p className="mt-8 text-center">
          <a href="/" className="text-primary-foreground/70 hover:text-primary-foreground underline underline-offset-4 text-sm">
            sunnahlife.app-এ ব্রাউজ করুন
          </a>
        </p>
      </div>
    </main>
  );
}
