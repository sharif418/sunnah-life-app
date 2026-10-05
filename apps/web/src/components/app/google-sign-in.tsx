"use client";

// "গুগল দিয়ে চালিয়ে যান" on the web (mobile parity): Google Identity
// Services renders its own button; the id_token goes to POST
// /api/auth/social, which verifies it and sets the session cookies. The
// client id comes from GET /api/auth/providers (a public value), so no
// build-time setting is needed. The site's origin must be listed under the
// web OAuth client's "Authorized JavaScript origins" in Google Cloud.

import * as React from "react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import type { User } from "@/types/domain";

type GoogleId = {
  accounts: {
    id: {
      initialize: (o: { client_id: string; callback: (r: { credential: string }) => void; ux_mode?: string }) => void;
      renderButton: (el: HTMLElement, o: Record<string, unknown>) => void;
    };
  };
};

const SCRIPT = "https://accounts.google.com/gsi/client";

function loadScript(): Promise<GoogleId> {
  const w = window as unknown as { google?: GoogleId };
  if (w.google?.accounts?.id) return Promise.resolve(w.google);
  return new Promise((resolve, reject) => {
    const existing = document.querySelector<HTMLScriptElement>(`script[src="${SCRIPT}"]`);
    const s = existing ?? document.createElement("script");
    s.addEventListener("load", () => (w.google ? resolve(w.google) : reject(new Error("google unavailable"))));
    s.addEventListener("error", () => reject(new Error("google unavailable")));
    if (!existing) {
      s.src = SCRIPT;
      s.async = true;
      s.defer = true;
      document.head.appendChild(s);
    }
  });
}

export function GoogleSignInButton({
  name,
  gender,
  onSignedIn,
  onError,
}: {
  name?: string;
  gender?: "M" | "F" | null;
  onSignedIn: (user: User) => void;
  onError: (message: string) => void;
}) {
  const slot = React.useRef<HTMLDivElement>(null);
  const [ready, setReady] = React.useState(false);
  const latest = React.useRef({ name, gender, onSignedIn, onError });
  React.useEffect(() => {
    latest.current = { name, gender, onSignedIn, onError };
  }, [name, gender, onSignedIn, onError]);

  React.useEffect(() => {
    let alive = true;
    (async () => {
      try {
        const p = await api.authProviders();
        if (!p.google || !p.googleClientId || !alive) return;
        const g = await loadScript();
        if (!alive || !slot.current) return;
        g.accounts.id.initialize({
          client_id: p.googleClientId,
          callback: async ({ credential }) => {
            try {
              const { name: n, gender: gd } = latest.current;
              const res = await api.socialSignIn({
                provider: "google",
                idToken: credential,
                name: n || undefined,
                gender: gd ?? undefined,
              });
              latest.current.onSignedIn(res.user);
            } catch (e) {
              latest.current.onError(e instanceof Error ? e.message : "গুগল দিয়ে সাইন ইন করা যায়নি");
            }
          },
        });
        g.accounts.id.renderButton(slot.current, {
          theme: "outline",
          size: "large",
          shape: "pill",
          text: "continue_with",
          locale: "bn",
          width: Math.min(320, slot.current.offsetWidth || 320),
        });
        setReady(true);
      } catch {
        // Google unreachable or not configured — the phone sign-in remains
      }
    })();
    return () => {
      alive = false;
    };
  }, []);

  return (
    <div className={ready ? "space-y-3" : "hidden"}>
      <div ref={slot} className="flex justify-center" />
      <div className="flex items-center gap-3 text-xs text-muted-foreground">
        <span className="h-px flex-1 bg-border" />
        অথবা মোবাইল নম্বর দিয়ে
        <span className="h-px flex-1 bg-border" />
      </div>
    </div>
  );
}

/**
 * A Google-created account starts without a gender ("unspecified") when the
 * member signed in before choosing one. Gender keeps brothers' and sisters'
 * data apart, so it is asked once, here — the API locks it afterwards.
 */
export function GenderCompletionDialog() {
  const user = useApp((s) => s.user);
  const setUser = useApp((s) => s.setUser);
  const [busy, setBusy] = React.useState(false);
  const missing = !!user && user.gender !== "M" && user.gender !== "F";
  if (!missing) return null;

  const choose = async (gender: "M" | "F") => {
    setBusy(true);
    try {
      const r = await api.updateMe({ gender });
      setUser(r.user);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "সংরক্ষণ করা যায়নি");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open>
      <DialogContent className="max-w-sm rounded-2xl" onInteractOutside={(e) => e.preventDefault()}>
        <DialogHeader>
          <DialogTitle>আপনি কি ভাই, না বোন?</DialogTitle>
          <DialogDescription>
            ভাই ও বোনদের তথ্য সম্পূর্ণ আলাদা রাখা হয়। এটি একবারই বেছে নিতে হয়, পরে বদলানো যায় না।
          </DialogDescription>
        </DialogHeader>
        <div className="grid grid-cols-2 gap-3">
          <Button className="h-12 rounded-xl" disabled={busy} onClick={() => choose("M")}>
            ভাই
          </Button>
          <Button className="h-12 rounded-xl" disabled={busy} onClick={() => choose("F")}>
            বোন
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
