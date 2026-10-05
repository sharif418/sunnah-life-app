"use client";

// The usrah head's latest weekly comment to ME, on the diary (mobile parity):
// on the web a plain member could not see their head's feedback anywhere —
// the Dawah tab is hidden for them.

import * as React from "react";
import { MessageCircle } from "lucide-react";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import type { WeeklyReview } from "@/types/domain";
import { Card, CardContent } from "@/components/ui/card";

function dateBn(key: string): string {
  const d = new Date(`${key}T00:00:00`);
  if (Number.isNaN(d.getTime())) return key;
  return new Intl.DateTimeFormat("bn-BD", { day: "numeric", month: "long" }).format(d);
}

/** "এই সপ্তাহ" / "গত সপ্তাহ" for a recent review week. */
function weekTag(weekStart: string): string | null {
  const ws = new Date(`${weekStart}T00:00:00`).getTime();
  if (Number.isNaN(ws)) return null;
  const days = Math.floor((Date.now() - ws) / 86_400_000);
  if (days >= 0 && days < 7) return "এই সপ্তাহ";
  if (days >= 7 && days < 14) return "গত সপ্তাহ";
  return null;
}

export function LatestReviewCard() {
  const user = useApp((s) => s.user);
  const [review, setReview] = React.useState<WeeklyReview | null>(null);

  React.useEffect(() => {
    if (!user) return;
    api
      .reviews()
      .then((r) => {
        const mine = r.reviews
          .filter((x) => x.userId === user.id && (x.comment ?? "").trim())
          .sort((a, b) => b.weekStart.localeCompare(a.weekStart));
        setReview(mine[0] ?? null);
      })
      .catch(() => setReview(null));
  }, [user]);

  if (!review) return null;
  const tag = weekTag(review.weekStart);
  return (
    <Card className="py-0">
      <CardContent className="space-y-2 p-4">
        <div className="flex items-center gap-2">
          <MessageCircle className="size-4 shrink-0 text-primary" aria-hidden />
          <p className="flex-1 text-sm font-bold">উসরা প্রধানের সাপ্তাহিক মন্তব্য</p>
          {tag ? <span className="text-xs text-muted-foreground">{tag}</span> : null}
        </div>
        <p className="whitespace-pre-line text-sm leading-relaxed">{review.comment}</p>
        {review.nextGoals ? (
          <p className="text-sm leading-relaxed text-muted-foreground">
            <span className="font-semibold text-foreground">আগামী সপ্তাহের লক্ষ্য:</span> {review.nextGoals}
          </p>
        ) : null}
        <p className="text-xs text-muted-foreground">
          {[review.reviewerName, dateBn(review.weekStart)].filter(Boolean).join(" · ")}
        </p>
      </CardContent>
    </Card>
  );
}
