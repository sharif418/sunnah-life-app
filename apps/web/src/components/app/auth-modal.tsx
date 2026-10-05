"use client";

import * as React from "react";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { InputOTP, InputOTPGroup, InputOTPSlot } from "@/components/ui/input-otp";
import { Label } from "@/components/ui/label";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { toast } from "sonner";
import { Loader2, Phone, ShieldCheck, Sparkles } from "lucide-react";
import { cn } from "@/lib/utils";
import { GenderCompletionDialog, GoogleSignInButton } from "@/components/app/google-sign-in";
import type { User } from "@/types/domain";

const DEMO_ACCOUNTS: { phone: string; label: string; desc: string }[] = [
  { phone: "01000000001", label: "প্রধান অ্যাডমিন", desc: "সবকিছু দেখা যায়" },
  { phone: "01000000003", label: "উসরা প্রধান (পুরুষ)", desc: "আল-ফুরকান উসরা" },
  { phone: "01000000005", label: "উসরা প্রধান (নারী)", desc: "আয়েশা সিদ্দিকা উসরা" },
  { phone: "01000000004", label: "দায়ী", desc: "রাফিউল ইসলাম DS-000004" },
  { phone: "01000000007", label: "সাধারণ ব্যবহারকারী", desc: "শুধু নিজের ডেটা" },
];

/** The one-tap demo accounts exist only in the seeded demo database: show
 * them on staging / local builds, never on the production site (there the
 * numbers would be real people's phones). */
function showDemoAccounts(): boolean {
  if (process.env.NEXT_PUBLIC_DEMO_ACCOUNTS === "1") return true;
  if (typeof window === "undefined") return false;
  return /(^|\.)(staging|localhost)|^localhost$|^127\.0\.0\.1$/.test(window.location.hostname) ||
    window.location.hostname.includes("staging");
}

export function AuthModal() {
  const { authModal, setAuthModal, setUser, profile, referralCode, outbox } = useApp();
  const [stage, setStage] = React.useState<"phone" | "code">("phone");
  const [phone, setPhone] = React.useState("");
  const [code, setCode] = React.useState("");
  const [loading, setLoading] = React.useState(false);

  const requestOtp = async (p: string) => {
    setLoading(true);
    try {
      const res = await api.requestOtp(p);
      setStage("code");
      setCode(res.devCode);
      toast.success(`ডেমো SMS গেটওয়ে — কোড: ${res.devCode}`, { duration: 8000 });
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "কোড পাঠানো যায়নি");
    } finally {
      setLoading(false);
    }
  };

  const verify = async (p: string, c: string) => {
    setLoading(true);
    try {
      const res = await api.verifyOtp({
        phone: p,
        code: c,
        name: profile.name || undefined,
        gender: profile.gender ?? undefined,
        referredByCode: referralCode ?? undefined,
        guestEntries: Object.values(outbox),
      });
      setUser(res.user);
      useApp.setState({ outbox: {} });
      toast.success(`স্বাগতম, ${res.user.name}!`);
      setAuthModal(false);
      reset();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "ভুল কোড");
    } finally {
      setLoading(false);
    }
  };

  const reset = () => {
    setStage("phone");
    setPhone("");
    setCode("");
    setLoading(false);
  };

  return (
    <>
    <GenderCompletionDialog />
    <Dialog
      open={authModal}
      onOpenChange={(o) => {
        setAuthModal(o);
        if (!o) reset();
      }}
    >
      <DialogContent className="rounded-2xl max-w-sm" dir="ltr">
        <DialogHeader className="text-center sm:text-center">
          <div className="mx-auto mb-1 flex size-14 items-center justify-center rounded-2xl bg-primary-soft">
            <ShieldCheck className="size-7 text-primary" />
          </div>
          <DialogTitle className="text-xl">সুন্নাহ লাইফে সাইন ইন</DialogTitle>
          <DialogDescription className="text-sm leading-relaxed">
            গুগল বা মোবাইল নম্বর দিয়ে। অতিথি হিসেবে থাকলেও সব ফিচার ব্যবহার করা যায় —
            সাইন ইন করলে আপনার আমলের ডায়েরি অ্যাকাউন্টে সংরক্ষিত হবে।
          </DialogDescription>
        </DialogHeader>

        {stage === "phone" ? (
          <GoogleSignInButton
            name={profile.name || undefined}
            gender={profile.gender}
            onSignedIn={(u) => {
              setUser(u);
              toast.success(`স্বাগতম, ${u.name}!`);
              setAuthModal(false);
              reset();
            }}
            onError={(m) => toast.error(m)}
          />
        ) : null}

        {stage === "phone" ? (
          <form
            className="space-y-3 pt-1"
            onSubmit={(e) => {
              e.preventDefault();
              if (phone.trim()) requestOtp(phone.trim());
            }}
          >
            <div className="space-y-1.5">
              <Label htmlFor="auth-phone">মোবাইল নম্বর</Label>
              <div className="relative">
                <Phone className="absolute left-3 top-1/2 -translate-y-1/2 size-4 text-muted-foreground" />
                <Input
                  id="auth-phone"
                  inputMode="tel"
                  autoComplete="tel"
                  placeholder="01XXXXXXXXX"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="h-12 rounded-xl pl-10 text-base tracking-wide"
                />
              </div>
            </div>
            <Button type="submit" disabled={loading || !phone.trim()} className="h-12 w-full rounded-xl text-base font-semibold">
              {loading ? <Loader2 className="size-5 animate-spin" /> : "কোড পাঠান"}
            </Button>
          </form>
        ) : (
          <form
            className="space-y-4 pt-1"
            onSubmit={(e) => {
              e.preventDefault();
              if (code.length === 6) verify(phone.trim(), code);
            }}
          >
            <div className="space-y-1.5">
              <Label>৬ সংখ্যার কোড</Label>
              <InputOTP maxLength={6} value={code} onChange={setCode} className="gap-1.5">
                <InputOTPGroup>
                  {[0, 1, 2, 3, 4, 5].map((i) => (
                    <InputOTPSlot key={i} index={i} className="size-11 rounded-xl text-lg" />
                  ))}
                </InputOTPGroup>
              </InputOTP>
            </div>
            <Button type="submit" disabled={loading || code.length < 6} className="h-12 w-full rounded-xl text-base font-semibold">
              {loading ? <Loader2 className="size-5 animate-spin" /> : "যাচাই করুন"}
            </Button>
            <button type="button" className="w-full text-sm text-muted-foreground underline-offset-4 hover:underline" onClick={() => setStage("phone")}>
              নম্বর পরিবর্তন করুন
            </button>
          </form>
        )}

        {showDemoAccounts() ? (
        <div className="rounded-xl bg-muted/60 p-3">
          <div className="flex items-center gap-1.5 text-xs font-semibold text-muted-foreground mb-2">
            <Sparkles className="size-3.5 text-gold-text-text" /> ডেমো অ্যাকাউন্ট (এক ট্যাপে সাইন ইন)
          </div>
          <div className="grid gap-1.5">
            {DEMO_ACCOUNTS.map((acc) => (
              <button
                key={acc.phone}
                disabled={loading}
                onClick={() => demoLogin(acc.phone, acc.label)}
                className={cn(
                  "tap-target flex items-center justify-between rounded-lg bg-card border border-border px-3 py-2.5 text-start hover:border-primary/40 transition-colors"
                )}
              >
                <span>
                  <span className="block text-sm font-semibold">{acc.label}</span>
                  <span className="block text-[11px] text-muted-foreground">{acc.desc}</span>
                </span>
                <span className="text-[10px] font-mono text-muted-foreground/70">{acc.phone}</span>
              </button>
            ))}
          </div>
        </div>
        ) : null}
      </DialogContent>
    </Dialog>
    </>
  );

  async function demoLogin(phone: string, label: string) {
    setLoading(true);
    try {
      const res = await api.requestOtp(phone);
      await verifyWith(res.devCode, phone);
    } catch (e) {
      toast.error(e instanceof Error ? `${label}: ${e.message}` : "সাইন ইন ব্যর্থ");
      setLoading(false);
    }
  }

  async function verifyWith(c: string, phoneToUse: string) {
    try {
      const res = await api.verifyOtp({
        phone: phoneToUse,
        code: c,
        guestEntries: Object.values(useApp.getState().outbox),
      });
      const u: User = res.user;
      useApp.setState({ outbox: {} });
      setUser(u);
      toast.success(`স্বাগতম, ${u.name}!`);
      setAuthModal(false);
      reset();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "সাইন ইন ব্যর্থ");
    } finally {
      setLoading(false);
    }
  }
}
