"use client";

import * as React from "react";
import { useRouter } from "next/navigation";
import { KeyRound, Phone, ShieldCheck, Sparkles, X } from "lucide-react";
import { useSession } from "@/lib/session";
import { api } from "@/lib/api";
import { toBn } from "@/lib/bn";
import { DEMO_ACCOUNTS, ROLE_GROUP_LABELS, ROLE_ORDER } from "@/lib/demo-accounts";
import { GenderBadge, RoleBadge } from "@/components/badges";
import { Button } from "@/components/ui/button";
import { Field, Input } from "@/components/ui/input";
import { Card, CardContent } from "@/components/ui/card";
import { useToast } from "@/components/ui/toast";

export default function LoginPage() {
  const { status, login } = useSession();
  const router = useRouter();
  const { toast } = useToast();

  const [phone, setPhone] = React.useState("");
  const [code, setCode] = React.useState("");
  const [devCode, setDevCode] = React.useState<string | null>(null);
  const [showHint, setShowHint] = React.useState(true);
  const [step, setStep] = React.useState<"phone" | "code">("phone");
  const [busy, setBusy] = React.useState(false);
  const [quickBusy, setQuickBusy] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (status === "authenticated") router.replace("/");
  }, [status, router]);

  const requestCode = React.useCallback(
    async (p: string): Promise<string | null> => {
      const clean = p.replace(/[^\d]/g, "");
      if (clean.length !== 11) {
        toast("১১ সংখ্যার বৈধ মোবাইল নম্বর দিন", "error");
        return null;
      }
      setBusy(true);
      try {
        const res = await api.requestOtp(clean);
        setDevCode(res.devCode);
        setShowHint(true);
        setStep("code");
        toast("কোড পাঠানো হয়েছে", "success");
        return res.devCode;
      } catch (err) {
        toast(err instanceof Error ? err.message : "কোড পাঠানো যায়নি", "error");
        return null;
      } finally {
        setBusy(false);
      }
    },
    [toast]
  );

  const verify = React.useCallback(
    async (p: string, c: string) => {
      if (!/^\d{6}$/.test(c)) {
        toast("৬ সংখ্যার কোড দিন", "error");
        return;
      }
      setBusy(true);
      try {
        await login(p, c);
        toast("স্বাগতম! সফলভাবে লগইন হয়েছে", "success");
        router.replace("/");
      } catch (err) {
        toast(err instanceof Error ? err.message : "লগইন সম্ভব হয়নি", "error");
      } finally {
        setBusy(false);
      }
    },
    [login, router, toast]
  );

  const quickLogin = React.useCallback(
    async (p: string) => {
      setQuickBusy(p);
      try {
        const dev = await api.requestOtp(p);
        await login(p, dev.devCode);
        toast("স্বাগতম! সফলভাবে লগইন হয়েছে", "success");
        router.replace("/");
      } catch (err) {
        toast(err instanceof Error ? err.message : "দ্রুত লগইন সম্ভব হয়নি", "error");
      } finally {
        setQuickBusy(null);
      }
    },
    [login, router, toast]
  );

  const grouped = React.useMemo(() => {
    return ROLE_ORDER.map((role) => ({
      role,
      accounts: DEMO_ACCOUNTS.filter((a) => a.role === role),
    })).filter((g) => g.accounts.length > 0);
  }, []);

  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-6 bg-background p-4 sm:p-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <svg viewBox="0 0 48 48" aria-hidden className="h-14 w-14">
          <circle cx="24" cy="24" r="22" fill="var(--primary)" />
          <path d="M31 13a11.5 11.5 0 1 0 3.2 15.9A9.6 9.6 0 0 1 31 13z" fill="var(--gold)" />
          <path d="M34.5 18.2l1.05 2.6 2.65.3-2 1.85.55 2.62-2.25-1.45-2.25 1.45.55-2.62-2-1.85 2.65-.3z" fill="var(--gold)" />
        </svg>
        <h1 className="text-xl font-bold text-foreground sm:text-2xl">সুন্নাহ লাইফ অ্যাডমিন</h1>
        <p className="max-w-md text-sm text-muted-foreground">
          দাওয়াতুস সুন্নাহ তারবিয়াত ইঞ্জিন — উসরা প্রধান · পরিদর্শক · প্রধান অ্যাডমিন প্যানেল
        </p>
      </div>

      <Card className="w-full max-w-md shadow-lifted">
        <CardContent className="p-5 pt-5 sm:p-6 sm:pt-6">
          <form
            className="space-y-4"
            onSubmit={(e) => {
              e.preventDefault();
              if (step === "phone") requestCode(phone);
              else verify(phone, code);
            }}
          >
            <Field label="মোবাইল নম্বর" htmlFor="login-phone" hint="আস-সুন্নাহ ফাউন্ডেশনের নিবন্ধিত নম্বর দিয়ে লগইন করুন">
              <div className="relative">
                <Phone className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
                <Input
                  id="login-phone"
                  inputMode="numeric"
                  autoComplete="tel"
                  placeholder="01XXXXXXXXX"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  className="pl-9 tracking-wider"
                  dir="ltr"
                  required
                />
              </div>
            </Field>

            {step === "code" ? (
              <>
                {devCode && showHint ? (
                  <div className="flex items-start justify-between gap-2 rounded-md border border-gold/50 bg-gold-soft/80 p-3 text-sm">
                    <div className="flex items-start gap-2">
                      <Sparkles className="mt-0.5 h-4 w-4 shrink-0 text-gold" aria-hidden />
                      <p className="text-foreground dark:text-gold">
                        ডেমো SMS গেটওয়ে — কোড: <strong className="font-bold">{toBn(devCode)}</strong>{" "}
                        <button
                          type="button"
                          className="ml-1 font-semibold text-primary underline underline-offset-2"
                          onClick={() => setCode(devCode)}
                        >
                          কোড বসান
                        </button>
                      </p>
                    </div>
                    <button
                      type="button"
                      aria-label="বন্ধ করুন"
                      onClick={() => setShowHint(false)}
                      className="focus-ring rounded p-0.5 text-muted-foreground hover:text-foreground"
                    >
                      <X className="h-4 w-4" aria-hidden />
                    </button>
                  </div>
                ) : null}
                <Field label="ওটিপি কোড" htmlFor="login-code" hint="মোবাইলে পাঠানো ৬ সংখ্যার কোড">
                  <div className="relative">
                    <KeyRound className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
                    <Input
                      id="login-code"
                      inputMode="numeric"
                      placeholder="______"
                      value={code}
                      onChange={(e) => setCode(e.target.value)}
                      className="pl-9 tracking-[0.3em]"
                      dir="ltr"
                      autoFocus
                      required
                    />
                  </div>
                </Field>
              </>
            ) : null}

            <div className="flex items-center gap-2">
              {step === "code" ? (
                <Button
                  type="button"
                  variant="outline"
                  onClick={() => {
                    setStep("phone");
                    setCode("");
                    setDevCode(null);
                  }}
                >
                  ফিরে যান
                </Button>
              ) : null}
              <Button type="submit" className="flex-1" loading={busy}>
                {step === "phone" ? "কোড পাঠান" : "প্রবেশ করুন"}
              </Button>
            </div>
          </form>

          <p className="mt-4 flex items-center gap-1.5 text-xs text-muted-foreground">
            <ShieldCheck className="h-3.5 w-3.5 text-success" aria-hidden />
            নারীদের তথ্য শুধু নারী তত্ত্বাবধায়কদের কাছে দৃশ্যমান — ডেটাবেজ স্তরে সুরক্ষিত
          </p>
        </CardContent>
      </Card>

      {/* Demo quick-login renders ONLY when the deployment was explicitly
          built with NEXT_PUBLIC_DEMO=true (Phase C/W2b — a production admin
          build must never show a one-click-login grid). */}
      {process.env.NEXT_PUBLIC_DEMO === "true" && (
      <Card className="w-full max-w-3xl">
        <CardContent className="p-4 sm:p-5">
          <p className="mb-3 text-sm font-bold text-foreground">ডেমো অ্যাকাউন্ট — এক ক্লিকে লগইন</p>
          <div className="scroll-thin max-h-[38vh] space-y-4 overflow-y-auto pr-1">
            {grouped.map((g) => (
              <div key={g.role}>
                <div className="mb-1.5 flex items-center gap-2">
                  <RoleBadge role={g.role} />
                  <span className="text-xs text-muted-foreground">
                    {toBn(g.accounts.length)} টি অ্যাকাউন্ট
                  </span>
                </div>
                <div className="grid grid-cols-1 gap-2 sm:grid-cols-2 lg:grid-cols-3">
                  {g.accounts.map((a) => (
                    <button
                      key={a.phone}
                      type="button"
                      disabled={quickBusy !== null}
                      onClick={() => quickLogin(a.phone)}
                      className="focus-ring group flex min-h-11 flex-col items-start gap-1 rounded-md border border-border bg-card p-2.5 text-left transition-colors duration-200 hover:border-primary/40 hover:bg-primary-soft/50 disabled:opacity-60"
                      aria-label={`দ্রুত লগইন: ${a.name}`}
                    >
                      <span className="flex w-full items-center gap-1.5">
                        <span className="truncate text-sm font-semibold text-foreground">{a.name}</span>
                        <GenderBadge gender={a.gender} className="ml-auto shrink-0" />
                      </span>
                      <span className="flex w-full items-center gap-2">
                        <span dir="ltr" className="text-xs tabular-nums text-muted-foreground">
                          {a.phone}
                        </span>
                        {a.note ? (
                          <span className="truncate text-[10px] text-gold-foreground dark:text-gold" title={a.note}>
                            {a.note}
                          </span>
                        ) : null}
                        {quickBusy === a.phone ? (
                          <span className="ml-auto text-[11px] font-medium text-primary">লগইন হচ্ছে…</span>
                        ) : (
                          <span className="ml-auto text-[11px] font-medium text-primary opacity-0 transition-opacity group-hover:opacity-100">
                            {ROLE_GROUP_LABELS[a.role] ? "লগইন →" : ""}
                          </span>
                        )}
                      </span>
                    </button>
                  ))}
                </div>
              </div>
            ))}
          </div>
          <p className="mt-3 text-xs text-muted-foreground">
            ওটিপি রেট লিমিট: প্রতি ১০ মিনিটে প্রতি নম্বরে ৩টি কোড। মক SMS প্রোভাইডার কোডটি সরাসরি
            রেসপন্সে ফেরত দেয়।
          </p>
        </CardContent>
      </Card>
      )}
    </div>
  );
}
