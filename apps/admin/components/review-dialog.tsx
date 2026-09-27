"use client";

import * as React from "react";
import { useMutation, useQueryClient } from "@tanstack/react-query";
import { api, type UsrahMember, type WeeklyReview } from "@/lib/api";
import { toBn, weekStartOf } from "@/lib/bn";
import { useSession } from "@/lib/session";
import { useToast } from "@/components/ui/toast";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Field, Textarea } from "@/components/ui/input";
import { RatingInput } from "@/components/rating";
import { Badge } from "@/components/ui/badge";

/** Complete-review flow: comment editor, 1–5 rating, next-goals setter. */
export function ReviewDialog({
  member,
  review,
  open,
  onClose,
}: {
  member: Pick<UsrahMember, "id" | "name" | "level" | "completion7d">;
  review?: (Partial<WeeklyReview> & { weekStart: string; id?: string }) | null;
  open: boolean;
  onClose: () => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const { user } = useSession();

  const weekStart = review?.weekStart ?? weekStartOf();
  const [comment, setComment] = React.useState("");
  const [rating, setRating] = React.useState(3);
  const [nextGoals, setNextGoals] = React.useState("");

  // Reset fields when the dialog opens or switches review — render-phase
  // adjustment (the React-blessed replacement for setState-in-effect).
  const [resetKey, setResetKey] = React.useState("");
  const openKey = `${open}:${review?.id ?? ""}`;
  if (openKey !== resetKey) {
    setResetKey(openKey);
    setComment(review?.comment ?? "");
    setRating(review?.rating ?? 3);
    setNextGoals(review?.nextGoals ?? "");
  }

  const submit = useMutation({
    mutationFn: () =>
      api.submitReview({
        userId: member.id,
        weekStart,
        comment,
        rating,
        nextGoals,
      }),
    onSuccess: (res) => {
      const pct = res.review.summary?.overallPct;
      toast(
        `রিভিউ সম্পন্ন হয়েছে${pct !== undefined && pct !== null ? ` — সাপ্তাহিক সম্পূর্ণতা ${toBn(pct)}%` : ""}`,
        "success"
      );
      qc.invalidateQueries({ queryKey: ["review-queue"] });
      qc.invalidateQueries({ queryKey: ["admin-overview"] });
      onClose();
    },
    onError: (err: Error) => toast(err.message, "error"),
  });

  const existingSummary = review?.summary ?? null;

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={`সাপ্তাহিক রিভিউ — ${member.name}`}
      description={`সপ্তাহ শুরু: ${toBn(weekStart)} · রিভিউকারী: ${user?.name ?? ""}`}
      wide
      footer={
        <>
          <Button variant="outline" onClick={onClose} disabled={submit.isPending}>
            বাতিল
          </Button>
          <Button onClick={() => submit.mutate()} loading={submit.isPending}>
            রিভিউ জমা দিন
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <div className="flex flex-wrap items-center gap-2 rounded-md border border-border bg-muted/50 p-3 text-sm">
          <Badge variant="default">৭ দিনের সম্পূর্ণতা: {member.completion7d != null ? `${toBn(member.completion7d)}%` : "—"}</Badge>
          {existingSummary?.streak !== undefined && existingSummary?.streak !== null ? (
            <Badge variant="gold">স্ট্রিক: {toBn(existingSummary.streak)} দিন</Badge>
          ) : null}
          {existingSummary?.missedDays !== undefined && existingSummary?.missedDays !== null ? (
            <Badge variant={existingSummary.missedDays > 2 ? "alert" : "muted"}>
              মিসড দিন: {toBn(existingSummary.missedDays)}
            </Badge>
          ) : null}
          {existingSummary?.overallPct != null ? (
            <Badge variant="success">আগের সারসংক্ষেপ: {toBn(existingSummary.overallPct)}%</Badge>
          ) : (
            <Badge variant="muted">স্বয়ংক্রিয় সারসংক্ষেপ জমা দেওয়ার পর হিসাব হবে</Badge>
          )}
        </div>

        {existingSummary?.byCategory && Object.keys(existingSummary.byCategory).length ? (
          <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
            {Object.entries(existingSummary.byCategory).map(([cat, pct]) => (
              <div key={cat} className="rounded-md border border-border p-2 text-center">
                <p className="text-[10px] font-semibold text-muted-foreground">{cat}</p>
                <p className="text-sm font-bold">{toBn(pct)}%</p>
              </div>
            ))}
          </div>
        ) : null}

        <Field label="রিভিউ মন্তব্য" htmlFor="review-comment" hint="সদস্যের এই সপ্তাহের অবস্থা নিয়ে মূল্যায়ন লিখুন (ঐচ্ছিক)">
          <Textarea
            id="review-comment"
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder="আলহামদুলিল্লাহ, এই সপ্তাহে…"
            maxLength={4000}
          />
        </Field>

        <Field label="রেটিং" hint="এই সপ্তাহের সামগ্রিক মূল্যায়ন (১–৫)">
          <RatingInput value={rating} onChange={setRating} disabled={submit.isPending} />
        </Field>

        <Field
          label="পরবর্তী লক্ষ্যসমূহ"
          htmlFor="review-goals"
          hint="সদস্যের জন্য আগামী সপ্তাহের ব্যক্তিগত লক্ষ্য ও পরামর্শ — সদস্য রিমাইন্ডার পাবেন"
        >
          <Textarea
            id="review-goals"
            value={nextGoals}
            onChange={(e) => setNextGoals(e.target.value)}
            placeholder="যেমন: তাহাজ্জুদে অন্তত ৩ দিন জাগা, প্রতিদিন ১ পৃষ্ঠা তিলাওয়াত…"
            maxLength={2000}
          />
        </Field>
      </div>
    </Dialog>
  );
}
