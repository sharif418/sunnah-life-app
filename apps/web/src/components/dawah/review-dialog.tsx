"use client";

// সাপ্তাহিক রিভিউ ডায়ালগ — উসরা প্রধান কোনো সদস্যের রিভিউ সম্পন্ন করেন:
// মন্তব্য + রেটিং (১-৫) + পরবর্তী লক্ষ্য → api.submitReview (সার্ভার সারসংক্ষেপ
// নিজেই হিসাব করে, সদস্যকে রিমাইন্ডার যায়)।

import * as React from "react";
import { toast } from "sonner";
import { Star } from "lucide-react";
import { api } from "@/lib/api";
import type { WeeklyReview, UsrahMember } from "@/types/domain";
import { toBn } from "@/lib/calendars";
import { InitialsAvatar, levelLabel } from "./parts";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

export type QueueItem = WeeklyReview & { user: UsrahMember };

export function ReviewDialog({
  item,
  onOpenChange,
  onDone,
}: {
  item: QueueItem | null;
  onOpenChange: (open: boolean) => void;
  onDone: () => void;
}) {
  const [comment, setComment] = React.useState("");
  const [rating, setRating] = React.useState(4);
  const [nextGoals, setNextGoals] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  React.useEffect(() => {
    if (item) {
      setComment(item.comment ?? "");
      setRating(item.rating ?? 4);
      setNextGoals(item.nextGoals ?? "");
      setSaving(false);
    }
  }, [item]);

  const save = async () => {
    if (!item) return;
    setSaving(true);
    try {
      await api.submitReview({ userId: item.userId, weekStart: item.weekStart, comment, rating, nextGoals });
      toast.success("রিভিউ সম্পন্ন হয়েছে — সদস্যকে জানানো হয়েছে");
      onOpenChange(false);
      onDone();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "রিভিউ সংরক্ষণ করা যায়নি");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={item !== null} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[85vh] overflow-y-auto rounded-2xl scroll-thin">
        <DialogHeader>
          <DialogTitle className="text-start">সাপ্তাহিক রিভিউ সম্পন্ন করুন</DialogTitle>
        </DialogHeader>

        {item ? (
          <div className="flex items-center gap-3 rounded-xl bg-muted p-3">
            <InitialsAvatar name={item.user.name} />
            <div className="min-w-0 flex-1">
              <p className="truncate text-sm font-bold">{item.user.name}</p>
              <p className="truncate text-xs text-muted-foreground">
                {item.user.memberCode ? `${item.user.memberCode} · ` : ""}
                {levelLabel(item.user.level)}
              </p>
            </div>
            <div className="text-end">
              <p className="text-xs text-muted-foreground">৭ দিনে সম্পন্নতা</p>
              <p className="text-sm font-bold text-primary">{toBn(item.user.completion7d ?? 0)}%</p>
            </div>
          </div>
        ) : null}

        <div className="space-y-4">
          <div>
            <p className="text-xs text-muted-foreground">সপ্তাহ: {item ? toBn(item.weekStart) : ""}</p>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="review-comment">মন্তব্য (সাপ্তাহের মূল্যায়ন)</Label>
            <Textarea
              id="review-comment"
              value={comment}
              onChange={(e) => setComment(e.target.value)}
              placeholder="এই সপ্তাহের আমল, অগ্রগতি ও উন্নতির ক্ষেত্র নিয়ে লিখুন…"
              className="min-h-24 rounded-xl"
            />
          </div>

          <div className="space-y-1.5">
            <Label>রেটিং</Label>
            <div className="flex gap-1">
              {[1, 2, 3, 4, 5].map((s) => (
                <button
                  key={s}
                  type="button"
                  onClick={() => setRating(s)}
                  aria-label={`${toBn(s)} তারা`}
                  className="tap-target flex size-11 items-center justify-center rounded-lg hover:bg-muted"
                >
                  <Star className={cn("size-6", s <= rating ? "fill-gold text-gold-text-text" : "text-muted-foreground/50")} />
                </button>
              ))}
            </div>
          </div>

          <div className="space-y-1.5">
            <Label htmlFor="review-goals">পরবর্তী সপ্তাহের লক্ষ্য</Label>
            <Textarea
              id="review-goals"
              value={nextGoals}
              onChange={(e) => setNextGoals(e.target.value)}
              placeholder="যেমন: ফজরের জামাত, প্রতিদিন ১ পৃষ্ঠা তিলাওয়াত…"
              className="min-h-20 rounded-xl"
            />
          </div>
        </div>

        <DialogFooter className="flex-col gap-2">
          <Button className="h-11 w-full rounded-xl" onClick={save} disabled={saving}>
            {saving ? "সংরক্ষণ হচ্ছে…" : "রিভিউ জমা দিন"}
          </Button>
          <Button variant="ghost" className="h-11 w-full rounded-xl text-muted-foreground" onClick={() => onOpenChange(false)}>
            বাতিল
          </Button>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
