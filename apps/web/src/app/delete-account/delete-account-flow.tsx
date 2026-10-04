"use client";

// Delete a Sunnah Life account from the web: prove the phone (the same
// one-time code as sign-in), read what goes and what stays, tick, delete.
// The sign-in sets the session cookie; DELETE /api/me does the rest
// (apps/api/src/me/account-deletion.ts).

import * as React from "react";
import Link from "next/link";
import { Loader2, ShieldCheck, Trash2 } from "lucide-react";
import { LogoMark } from "@/components/app/logo";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { api } from "@/lib/api";

type Stage = "phone" | "code" | "confirm" | "done";

export function DeleteAccountFlow() {
  const [stage, setStage] = React.useState<Stage>("phone");
  const [phone, setPhone] = React.useState("");
  const [code, setCode] = React.useState("");
  const [devCode, setDevCode] = React.useState<string | null>(null);
  const [name, setName] = React.useState("");
  const [understood, setUnderstood] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : "কিছু একটা সমস্যা হয়েছে — আবার চেষ্টা করুন");
    } finally {
      setBusy(false);
    }
  };

  const sendCode = () =>
    run(async () => {
      const res = await api.requestOtp(phone.trim());
      // staging has no SMS gateway yet: the server hands the code back
      setDevCode(res.devCode || null);
      setStage("code");
    });

  const verify = () =>
    run(async () => {
      const res = await api.verifyOtp({ phone: phone.trim(), code: code.trim() });
      setName(res.user.name);
      setStage("confirm");
    });

  const remove = () =>
    run(async () => {
      await api.deleteMe();
      setStage("done");
    });

  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-lg px-4 py-10 sm:px-6">
        <header className="mb-6 flex items-center gap-3">
          <LogoMark size={44} />
          <div>
            <p className="text-sm text-muted-foreground">সুন্নাহ লাইফ</p>
            <h1 className="text-2xl font-bold tracking-tight">অ্যাকাউন্ট মুছে ফেলুন</h1>
          </div>
        </header>

        <div className="space-y-5 rounded-2xl border border-border bg-card p-5 shadow-sm">
          {stage === "phone" ? (
            <>
              <p className="text-[15px] leading-7">
                যে মোবাইল নম্বর দিয়ে অ্যাপে সাইন-ইন করেন, সেটি লিখুন। একটি কোড পাঠানো হবে, তা দিয়ে নিশ্চিত হওয়া যাবে
                অ্যাকাউন্টটি আপনার।
              </p>
              <div className="space-y-2">
                <Label htmlFor="del-phone">মোবাইল নম্বর</Label>
                <Input
                  id="del-phone"
                  inputMode="tel"
                  autoComplete="tel"
                  placeholder="01XXXXXXXXX"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                />
              </div>
              <Button className="w-full" onClick={sendCode} disabled={busy || phone.trim().length < 11}>
                {busy ? <Loader2 className="animate-spin" aria-hidden /> : null}
                কোড পাঠান
              </Button>
              <p className="text-sm leading-6 text-muted-foreground">
                শুধু গুগল দিয়ে সাইন-ইন করেন? অ্যাপের <b>আরও → প্রোফাইল → অ্যাকাউন্ট মুছে ফেলুন</b> থেকে মুছুন, অথবা প্রোফাইলে
                মোবাইল নম্বর যোগ করে এই পাতা ব্যবহার করুন।
              </p>
            </>
          ) : null}

          {stage === "code" ? (
            <>
              <p className="text-[15px] leading-7">{phone} নম্বরে পাঠানো ৬ সংখ্যার কোডটি লিখুন।</p>
              {devCode ? (
                <p className="rounded-lg bg-muted px-3 py-2 text-sm">পরীক্ষামূলক সার্ভার — কোড: {devCode}</p>
              ) : null}
              <div className="space-y-2">
                <Label htmlFor="del-code">কোড</Label>
                <Input
                  id="del-code"
                  inputMode="numeric"
                  autoComplete="one-time-code"
                  maxLength={6}
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                />
              </div>
              <Button className="w-full" onClick={verify} disabled={busy || code.trim().length < 4}>
                {busy ? <Loader2 className="animate-spin" aria-hidden /> : <ShieldCheck aria-hidden />}
                নিশ্চিত করুন
              </Button>
              <Button variant="ghost" className="w-full" onClick={() => setStage("phone")} disabled={busy}>
                নম্বর বদলান
              </Button>
            </>
          ) : null}

          {stage === "confirm" ? (
            <>
              <p className="text-[15px] font-semibold">{name}, আপনার অ্যাকাউন্ট মুছে ফেলবেন?</p>
              <div className="space-y-1 text-[15px] leading-7">
                <p className="font-semibold">যা মুছে যাবে:</p>
                <ul className="list-disc ps-5">
                  <li>মুহাসাবা ডায়েরি, লক্ষ্য, রিভিউ ও মূল্যায়ন</li>
                  <li>প্রশ্ন, মতামত ও সাপোর্ট বার্তা</li>
                  <li>নাম, ফোন নম্বর, ইমেইল, সদস্য কোড ও গুগল সংযোগ</li>
                </ul>
                <p className="pt-2 font-semibold">যা থাকবে (আপনার নাম ছাড়া):</p>
                <ul className="list-disc ps-5">
                  <li>অন্যদের জন্য আপনি যা লিখেছিলেন, যেমন রিভিউ বা ঘোষণা — সেখানে লেখা থাকবে “মুছে ফেলা অ্যাকাউন্ট”</li>
                </ul>
                <p className="pt-2 font-semibold text-destructive">এটি ফেরানো যাবে না।</p>
              </div>
              <label className="flex cursor-pointer items-start gap-3 text-[15px]">
                <input
                  type="checkbox"
                  className="mt-1 size-4 accent-[var(--destructive)]"
                  checked={understood}
                  onChange={(e) => setUnderstood(e.target.checked)}
                />
                <span>আমি বুঝেছি, আমার অ্যাকাউন্ট মুছে ফেলতে চাই</span>
              </label>
              <Button variant="destructive" className="w-full" onClick={remove} disabled={busy || !understood}>
                {busy ? <Loader2 className="animate-spin" aria-hidden /> : <Trash2 aria-hidden />}
                স্থায়ীভাবে মুছে ফেলুন
              </Button>
            </>
          ) : null}

          {stage === "done" ? (
            <div className="space-y-2 text-[15px] leading-7">
              <p className="font-semibold">আপনার অ্যাকাউন্ট মুছে ফেলা হয়েছে।</p>
              <p className="text-muted-foreground">
                ফোনের অ্যাপ পরের বার খুললে সেখান থেকেও আপনাকে বের করে দেওয়া হবে। আবার কখনো এই নম্বর দিয়ে সাইন-ইন করলে নতুন
                অ্যাকাউন্ট তৈরি হবে।
              </p>
            </div>
          ) : null}

          {error ? <p className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">{error}</p> : null}
        </div>

        <p className="mt-6 text-sm text-muted-foreground">
          কোন তথ্য রাখা হয় জানতে দেখুন{" "}
          <Link href="/privacy" className="font-semibold text-primary underline">
            গোপনীয়তা নীতি
          </Link>
          ।
        </p>
      </div>
    </main>
  );
}
