"use client";

// অ্যাপ সম্পর্কে — ব্র্যান্ডিং, সংস্করণ, দানের লিংক, মতামত ফর্ম।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { SubShell, SectionLabel } from "@/components/more/bits";
import { LogoMark } from "@/components/app/logo";
import { api } from "@/lib/api";
import { toBn } from "@/lib/calendars";
import { useDonationUrl } from "@/hooks/use-donation-url";
import { Loader2, Send, HeartHandshake, CheckCircle2, Star, ShieldCheck } from "lucide-react";
import { toast } from "sonner";
import { version as appVersion } from "../../../package.json";

export function AboutView() {
  const donationUrl = useDonationUrl();
  const [feedback, setFeedback] = React.useState("");
  const [sending, setSending] = React.useState(false);
  const [sent, setSent] = React.useState(false);

  const send = async () => {
    const message = feedback.trim();
    if (!message) return;
    setSending(true);
    try {
      await api.feedback(message);
      setSent(true);
      setFeedback("");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "পাঠানো যায়নি");
    } finally {
      setSending(false);
    }
  };

  return (
    <SubShell title="অ্যাপ সম্পর্কে">
      <div className="space-y-4">
        {/* ব্র্যান্ডিং */}
        <Card className="rounded-xl shadow-card">
          <CardContent className="p-6 text-center">
            <div className="mx-auto w-fit">
              <LogoMark size={64} />
            </div>
            <h2 className="mt-3 text-xl font-extrabold">সুন্নাহ লাইফ</h2>
            <p className="mt-1 text-xs text-muted-foreground">আস-সুন্নাহ ফাউন্ডেশন — দাওয়াতুস সুন্নাহ</p>
            <p className="mt-3 text-sm leading-relaxed">
              নামাজ, আমল, ইলম আর তারবিয়াত — সব এক অ্যাপে। বাংলাভাষী মুসলিমের দৈনন্দিন সঙ্গী।
            </p>
            <div className="mt-3 inline-flex items-center gap-1.5 rounded-full bg-primary-soft px-3 py-1 text-xs font-semibold text-primary">
              <Star className="size-3.5" />
              সংস্করণ {toBn(appVersion)}
            </div>
          </CardContent>
        </Card>

        {/* দান */}
        <Card className="rounded-xl border-gold/40 bg-gold-soft/60 shadow-card">
          <CardContent className="p-4 flex items-center gap-3.5">
            <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-gold/20 text-warning">
              <HeartHandshake className="size-5" />
            </span>
            <div className="flex-1 min-w-0">
              <p className="text-sm font-bold">দাওয়াতের কাজে অংশ নিন</p>
              <p className="text-xs text-muted-foreground leading-relaxed">
                এই প্ল্যাটফর্ম পরিচালনায় আপনার সহযোগিতা কাম্য।
              </p>
            </div>
            <Button
              className="h-11 rounded-xl shrink-0"
              onClick={() => window.open(donationUrl, "_blank", "noopener,noreferrer")}
            >
              দান করুন
            </Button>
          </CardContent>
        </Card>

        {/* গোপনীয়তা */}
        <div className="flex items-start gap-2.5 rounded-xl bg-muted/60 p-3.5">
          <ShieldCheck className="size-4 text-primary shrink-0 mt-0.5" />
          <p className="text-xs text-muted-foreground leading-relaxed">
            নামাজের সব হিসাব আপনার ডিভাইসেই হয় — অবস্থান কারো কাছে পাঠানো হয় না। নারীদের আমল ও
            তথ্য শুধুমাত্র নারী সুপারভাইজর দেখতে পারেন।
          </p>
        </div>

        {/* মতামত */}
        <div className="space-y-3">
          <SectionLabel>মতামত দিন</SectionLabel>
          {sent ? (
            <Card className="rounded-xl shadow-card">
              <CardContent className="p-4 flex items-center gap-3">
                <CheckCircle2 className="size-5 text-success shrink-0" />
                <p className="text-sm">ধন্যবাদ! মতামত পাঠানো হয়েছে।</p>
              </CardContent>
            </Card>
          ) : (
            <Card className="rounded-xl shadow-card">
              <CardContent className="p-4 space-y-3">
                <Label htmlFor="fb-text" className="sr-only">
                  আপনার মতামত লিখুন
                </Label>
                <Textarea
                  id="fb-text"
                  value={feedback}
                  onChange={(e) => setFeedback(e.target.value)}
                  rows={4}
                  placeholder="আপনার মতামত লিখুন… কী ভালো লেগেছে, কী আরও চান?"
                  className="rounded-xl text-base"
                />
                <div className="flex justify-end">
                  <Button onClick={send} disabled={sending || feedback.trim().length === 0} className="h-11 rounded-xl">
                    {sending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
                    {sending ? "পাঠানো হচ্ছে…" : "পাঠান"}
                  </Button>
                </div>
              </CardContent>
            </Card>
          )}
        </div>

        <p className="pt-2 text-center text-[11px] text-muted-foreground">
          © আস-সুন্নাহ ফাউন্ডেশন · সর্বস্বত্ব সংরক্ষিত
        </p>
      </div>
    </SubShell>
  );
}
