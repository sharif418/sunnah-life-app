"use client";

// Account pieces of the profile (mobile parity): change the sign-in phone
// with a code sent to the NEW number (PROF-04), the sisters' privacy note,
// and deleting the account (Google Play's rule) — what goes, what stays,
// one deliberate tick.

import * as React from "react";
import { Loader2, Phone, ShieldCheck, Trash2 } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { SectionLabel } from "@/components/more/bits";

export function PhoneChangeCard() {
  const { user, setUser } = useApp();
  const [step, setStep] = React.useState<"idle" | "phone" | "code">("idle");
  const [phone, setPhone] = React.useState("");
  const [code, setCode] = React.useState("");
  const [devCode, setDevCode] = React.useState<string | null>(null);
  const [busy, setBusy] = React.useState(false);
  if (!user) return null;

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    try {
      await fn();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "করা যায়নি");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="rounded-xl shadow-card">
      <CardContent className="space-y-3 p-4 sm:p-5">
        <SectionLabel icon={<Phone className="size-4" />}>মোবাইল নম্বর</SectionLabel>
        {step === "idle" ? (
          <div className="flex items-center gap-3">
            <p className="min-w-0 flex-1 text-sm">{user.phone ?? <span className="text-muted-foreground">যোগ করা হয়নি</span>}</p>
            <Button variant="outline" size="sm" className="h-9 rounded-full" onClick={() => setStep("phone")}>
              {user.phone ? "বদলান" : "যোগ করুন"}
            </Button>
          </div>
        ) : null}
        {step === "phone" ? (
          <div className="space-y-2">
            <Label htmlFor="pc-phone">নতুন নম্বর</Label>
            <Input
              id="pc-phone"
              inputMode="tel"
              placeholder="01XXXXXXXXX"
              value={phone}
              onChange={(e) => setPhone(e.target.value)}
              className="h-11 rounded-xl"
            />
            <p className="text-xs text-muted-foreground">নতুন নম্বরে একটি কোড যাবে; নিশ্চিত করলেই এটি আপনার সাইন-ইনের নম্বর হবে।</p>
            <div className="flex gap-2">
              <Button variant="ghost" className="flex-1" onClick={() => setStep("idle")} disabled={busy}>
                বাতিল
              </Button>
              <Button
                className="flex-1"
                disabled={busy || phone.trim().length < 11}
                onClick={() =>
                  run(async () => {
                    const r = await api.requestPhoneChange(phone.trim());
                    setDevCode(r.devCode || null);
                    setStep("code");
                  })
                }
              >
                {busy ? <Loader2 className="animate-spin" aria-hidden /> : null}
                কোড পাঠান
              </Button>
            </div>
          </div>
        ) : null}
        {step === "code" ? (
          <div className="space-y-2">
            <Label htmlFor="pc-code">{phone} নম্বরে পাঠানো কোড</Label>
            {devCode ? <p className="rounded-lg bg-muted px-3 py-2 text-sm">পরীক্ষামূলক সার্ভার — কোড: {devCode}</p> : null}
            <Input
              id="pc-code"
              inputMode="numeric"
              autoComplete="one-time-code"
              maxLength={6}
              value={code}
              onChange={(e) => setCode(e.target.value)}
              className="h-11 rounded-xl"
            />
            <Button
              className="w-full"
              disabled={busy || code.trim().length < 4}
              onClick={() =>
                run(async () => {
                  const r = await api.verifyPhoneChange(phone.trim(), code.trim());
                  setUser(r.user);
                  setStep("idle");
                  setPhone("");
                  setCode("");
                  toast.success("মোবাইল নম্বর হালনাগাদ হয়েছে");
                })
              }
            >
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : <ShieldCheck aria-hidden />}
              নিশ্চিত করুন
            </Button>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

/** The sisters' privacy note (onboarding's promise, kept visible). */
export function FemalePrivacyNote() {
  const user = useApp((s) => s.user);
  if (user?.gender !== "F") return null;
  return (
    <div className="rounded-xl border border-primary/20 bg-primary-soft px-4 py-3 text-sm leading-relaxed">
      <p className="font-bold text-primary">বোনদের গোপনীয়তা</p>
      <p className="mt-0.5">আপনার ডায়েরি ও তথ্য শুধু নারী তত্ত্বাবধায়ক ও প্রধান অ্যাডমিনরা দেখতে পারেন।</p>
    </div>
  );
}

export function DeleteAccountButton() {
  const { user, setUser } = useApp();
  const [open, setOpen] = React.useState(false);
  const [understood, setUnderstood] = React.useState(false);
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);
  if (!user) return null;

  const remove = async () => {
    setBusy(true);
    setError(null);
    try {
      await api.deleteMe();
      await api.logout().catch(() => null);
      setUser(null);
      setOpen(false);
      toast.success("আপনার অ্যাকাউন্ট মুছে ফেলা হয়েছে");
    } catch (e) {
      setError(e instanceof Error ? e.message : "মুছতে পারা যায়নি");
    } finally {
      setBusy(false);
    }
  };

  return (
    <>
      <button
        type="button"
        onClick={() => {
          setUnderstood(false);
          setError(null);
          setOpen(true);
        }}
        className="mx-auto flex items-center gap-1.5 text-sm font-semibold text-alert hover:underline"
      >
        <Trash2 className="size-4" /> অ্যাকাউন্ট মুছে ফেলুন
      </button>
      <Dialog open={open} onOpenChange={setOpen}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>অ্যাকাউন্ট মুছে ফেলবেন?</DialogTitle>
            <DialogDescription>এটি ফেরানো যাবে না।</DialogDescription>
          </DialogHeader>
          <div className="space-y-1 text-sm leading-relaxed">
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
          </div>
          <label className="flex cursor-pointer items-start gap-3 text-sm">
            <input
              type="checkbox"
              className="mt-1 size-4 accent-[var(--destructive)]"
              checked={understood}
              onChange={(e) => setUnderstood(e.target.checked)}
            />
            <span>আমি বুঝেছি, আমার অ্যাকাউন্ট মুছে ফেলতে চাই</span>
          </label>
          {error ? <p className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">{error}</p> : null}
          <Button variant="destructive" className="w-full" onClick={remove} disabled={busy || !understood}>
            {busy ? <Loader2 className="animate-spin" aria-hidden /> : <Trash2 aria-hidden />}
            স্থায়ীভাবে মুছে ফেলুন
          </Button>
        </DialogContent>
      </Dialog>
    </>
  );
}
