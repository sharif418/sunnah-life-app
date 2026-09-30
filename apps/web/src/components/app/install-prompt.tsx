"use client";

// PWA — "অ্যাপ ইনস্টল করুন" banner. Captures the browser's
// beforeinstallprompt, offers install/later, and PERSISTS dismissal
// (localStorage) so the banner never nags again after "এখন নয়".

import * as React from "react";
import { useApp } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { Button } from "@/components/ui/button";
import { LogoMark } from "@/components/app/logo";
import { Download, X } from "lucide-react";

const DISMISS_KEY = "sl-install-dismissed";

interface BeforeInstallPromptEvent extends Event {
  prompt: () => Promise<void>;
  userChoice: Promise<{ outcome: "accepted" | "dismissed" }>;
}

export function InstallPrompt() {
  const lang = useApp((s) => s.profile.language);
  const t = (k: string) => translate(lang, k);
  const [deferred, setDeferred] = React.useState<BeforeInstallPromptEvent | null>(null);
  const [dismissed, setDismissed] = React.useState(true); // client-only reveal

  React.useEffect(() => {
    try {
      if (localStorage.getItem(DISMISS_KEY) === "1") return;
    } catch {
      /* private mode etc. — show the banner */
    }
    setDismissed(false);

    const onPrompt = (e: Event) => {
      e.preventDefault(); // keep the browser's own mini-infobar out of the way
      setDeferred(e as BeforeInstallPromptEvent);
    };
    const onInstalled = () => {
      setDeferred(null);
      setDismissed(true);
      try {
        localStorage.setItem(DISMISS_KEY, "1");
      } catch {
        /* best effort */
      }
    };
    window.addEventListener("beforeinstallprompt", onPrompt);
    window.addEventListener("appinstalled", onInstalled);
    return () => {
      window.removeEventListener("beforeinstallprompt", onPrompt);
      window.removeEventListener("appinstalled", onInstalled);
    };
  }, []);

  if (dismissed || !deferred) return null;

  const install = async () => {
    try {
      await deferred.prompt();
      await deferred.userChoice; // accepted | dismissed — both end the banner
    } finally {
      setDeferred(null);
    }
  };
  const later = () => {
    setDeferred(null);
    setDismissed(true);
    try {
      localStorage.setItem(DISMISS_KEY, "1");
    } catch {
      /* best effort */
    }
  };

  return (
    <div
      role="dialog"
      aria-label={t("install.title")}
      className="fixed bottom-20 xl:bottom-4 inset-x-4 z-30 mx-auto max-w-sm rounded-2xl border border-border bg-card p-3.5 shadow-lifted flex items-center gap-3"
    >
      <LogoMark size={40} className="shrink-0" />
      <div className="flex-1 min-w-0">
        <p className="text-sm font-bold leading-snug">{t("install.title")}</p>
        <p className="mt-0.5 text-xs text-muted-foreground leading-relaxed">{t("install.body")}</p>
      </div>
      <div className="flex flex-col items-stretch gap-1.5 shrink-0">
        <Button size="sm" className="h-9 rounded-full px-4" onClick={install}>
          <Download className="size-4" /> {t("install.cta")}
        </Button>
        <button
          onClick={later}
          className="text-[11px] text-muted-foreground hover:text-foreground transition-colors leading-none flex items-center justify-center gap-1"
        >
          <X className="size-3" /> {t("install.later")}
        </button>
      </div>
    </div>
  );
}
