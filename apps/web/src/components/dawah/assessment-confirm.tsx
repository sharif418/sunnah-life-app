"use client";

// The assessee's acknowledgment (W4i, mobile parity): a submitted
// assessment stays "নিশ্চিতকরণের অপেক্ষায়" until the member confirms it with
// a code sent to their own phone — only then does the result count for the
// level. Or they decline with a reason (the invigilator is told).

import * as React from "react";
import { Loader2, ShieldCheck, ThumbsDown } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { toBn } from "@/lib/calendars";
import type { AssessmentDetail } from "@/types/domain";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";

type Step = "review" | "code" | "decline";

export function AssessmentConfirmDialog({
  assessment,
  onClose,
  onDone,
}: {
  assessment: AssessmentDetail | null;
  onClose: () => void;
  onDone: () => void;
}) {
  const [step, setStep] = React.useState<Step>("review");
  const [code, setCode] = React.useState("");
  const [devCode, setDevCode] = React.useState<string | null>(null);
  const [reason, setReason] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const [error, setError] = React.useState<string | null>(null);

  React.useEffect(() => {
    setStep("review");
    setCode("");
    setDevCode(null);
    setReason("");
    setError(null);
  }, [assessment?.id]);

  if (!assessment) return null;

  const run = async (fn: () => Promise<void>) => {
    setBusy(true);
    setError(null);
    try {
      await fn();
    } catch (e) {
      setError(e instanceof Error ? e.message : "কিছু একটা সমস্যা হয়েছে");
    } finally {
      setBusy(false);
    }
  };

  const sendCode = () =>
    run(async () => {
      const r = await api.assessmentConfirmRequest(assessment.id);
      setDevCode(r.devCode || null);
      setStep("code");
    });

  const confirm = () =>
    run(async () => {
      await api.assessmentConfirm(assessment.id, code.trim());
      toast.success("মূল্যায়ন নিশ্চিত হয়েছে — ফলাফল এখন চূড়ান্ত");
      onDone();
    });

  const decline = () =>
    run(async () => {
      await api.assessmentDecline(assessment.id, reason.trim() || undefined);
      toast.success("আপত্তি জানানো হয়েছে — পরিদর্শক জানবেন");
      onDone();
    });

  return (
    <Dialog open onOpenChange={(v) => (!v ? onClose() : null)}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>{assessment.template.titleBn}</DialogTitle>
          <DialogDescription>
            {[assessment.assessorName ? `মূল্যায়নকারী: ${assessment.assessorName}` : null, toBn(assessment.createdAt.slice(0, 10))]
              .filter(Boolean)
              .join(" · ")}
          </DialogDescription>
        </DialogHeader>

        <div className="flex items-center gap-3 rounded-xl bg-muted px-4 py-3">
          <span className="text-2xl font-bold text-primary">
            {assessment.scorePct != null ? `${toBn(assessment.scorePct)}%` : "—"}
          </span>
          <span className="text-sm font-semibold">
            {assessment.result === "passed" ? "উত্তীর্ণ" : "এখনো উত্তীর্ণ নয়"}
          </span>
        </div>
        {assessment.overallComment ? (
          <p className="rounded-lg bg-muted/60 px-3 py-2 text-sm leading-relaxed">“{assessment.overallComment}”</p>
        ) : null}

        {step === "review" ? (
          <div className="space-y-3">
            <p className="text-sm leading-relaxed text-muted-foreground">
              ফলাফলটি দেখে সঠিক মনে হলে নিশ্চিত করুন — আপনার ফোনে একটি কোড যাবে। নিশ্চিত করার পরই ফলাফল চূড়ান্ত হয় এবং স্তরের
              হিসাবে ধরা হয়।
            </p>
            <Button className="w-full" onClick={sendCode} disabled={busy}>
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : <ShieldCheck aria-hidden />}
              নিশ্চিত করুন
            </Button>
            <Button variant="ghost" className="w-full" onClick={() => setStep("decline")} disabled={busy}>
              <ThumbsDown aria-hidden /> আপত্তি জানান
            </Button>
          </div>
        ) : null}

        {step === "code" ? (
          <div className="space-y-3">
            <p className="text-sm text-muted-foreground">আপনার ফোনে পাঠানো ৬ সংখ্যার কোডটি লিখুন।</p>
            {devCode ? <p className="rounded-lg bg-muted px-3 py-2 text-sm">পরীক্ষামূলক সার্ভার — কোড: {devCode}</p> : null}
            <div className="space-y-1.5">
              <Label htmlFor="assess-code">কোড</Label>
              <Input
                id="assess-code"
                inputMode="numeric"
                autoComplete="one-time-code"
                maxLength={6}
                value={code}
                onChange={(e) => setCode(e.target.value)}
              />
            </div>
            <Button className="w-full" onClick={confirm} disabled={busy || code.trim().length < 4}>
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : <ShieldCheck aria-hidden />}
              নিশ্চিত করুন
            </Button>
          </div>
        ) : null}

        {step === "decline" ? (
          <div className="space-y-3">
            <div className="space-y-1.5">
              <Label htmlFor="assess-reason">কেন আপত্তি? (ঐচ্ছিক)</Label>
              <Textarea
                id="assess-reason"
                rows={3}
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                placeholder="যেমন: কিছু অংশ আমার সামনে মূল্যায়ন হয়নি…"
              />
            </div>
            <Button variant="destructive" className="w-full" onClick={decline} disabled={busy}>
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : <ThumbsDown aria-hidden />}
              আপত্তি জানান
            </Button>
            <Button variant="ghost" className="w-full" onClick={() => setStep("review")} disabled={busy}>
              ফিরে যান
            </Button>
          </div>
        ) : null}

        {error ? <p className="rounded-lg bg-destructive/10 px-3 py-2 text-sm text-destructive">{error}</p> : null}
      </DialogContent>
    </Dialog>
  );
}
