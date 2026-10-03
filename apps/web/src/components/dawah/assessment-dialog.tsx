"use client";

// নতুন মূল্যায়ন ডায়ালগ — উসরা প্রধান+ কোনো সদস্যের ফরযে আইন মূল্যায়ন (v১)
// গঠন করেন: প্রতিটি মানদণ্ডে ০/১/২ স্কোর + সার্বিক মন্তব্য →
// api.createAssessment। ফলাফল সার্ভার নির্ধারণ করে (কাগজের নিয়ম: মোট
// মানদণ্ডের অধিকাংশ "সম্পূর্ণ" (২) হলে "উত্তীর্ণ")।

import * as React from "react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import type { AssessmentTemplate, Level } from "@/types/domain";
import { toBn } from "@/lib/calendars";
import { levelLabel } from "./parts";
import { Button } from "@/components/ui/button";
import { Dialog, DialogContent, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select";
import { cn } from "@/lib/utils";

export interface AssessmentMember {
  id: string;
  name: string;
  memberCode: string | null;
  level: Level;
}

const SCORE_OPTIONS: { value: 0 | 1 | 2; label: string; title: string }[] = [
  { value: 0, label: "০", title: "হয়নি" },
  { value: 1, label: "১", title: "আংশিক / চর্চা চলছে" },
  { value: 2, label: "২", title: "দক্ষ / নিয়মিত" },
];

export function AssessmentDialog({
  open,
  onOpenChange,
  members,
  template,
  preselectedMemberId,
  onDone,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  members: AssessmentMember[];
  template: AssessmentTemplate | null;
  preselectedMemberId?: string;
  onDone: () => void;
}) {
  const [memberId, setMemberId] = React.useState<string>("");
  const [category, setCategory] = React.useState<"1" | "2">("1");
  const [scores, setScores] = React.useState<Record<string, 0 | 1 | 2>>({});
  const [overallComment, setOverallComment] = React.useState("");
  const [saving, setSaving] = React.useState(false);

  const totalCriteria = template?.sections.reduce((s, sec) => s + sec.criteria.length, 0) ?? 0;
  const scoredCount = Object.keys(scores).length;

  React.useEffect(() => {
    if (open) {
      setMemberId(preselectedMemberId ?? "");
      setCategory("1");
      setScores({});
      setOverallComment("");
      setSaving(false);
    }
  }, [open, preselectedMemberId]);

  const save = async () => {
    if (!template || !memberId) return;
    setSaving(true);
    try {
      await api.createAssessment({
        assesseeId: memberId,
        templateKey: template.key,
        participantCategory: Number(category),
        scores: Object.fromEntries(Object.entries(scores).map(([k, v]) => [k, { score: v }])),
        overallComment,
      });
      toast.success("মূল্যায়ন সংরক্ষিত হয়েছে");
      onOpenChange(false);
      onDone();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "মূল্যায়ন সংরক্ষণ করা যায়নি");
    } finally {
      setSaving(false);
    }
  };

  const canSubmit = Boolean(template && memberId && totalCriteria > 0 && scoredCount === totalCriteria);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[88vh] overflow-y-auto rounded-2xl scroll-thin sm:max-w-lg">
        <DialogHeader>
          <DialogTitle className="text-start">নতুন মূল্যায়ন</DialogTitle>
        </DialogHeader>

        {!template ? (
          <p className="py-6 text-center text-sm text-muted-foreground">মূল্যায়ন টেমপ্লেট পাওয়া যায়নি।</p>
        ) : (
          <>
            <p className="text-sm font-semibold text-primary">{template.titleBn}</p>

            <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
              <div className="space-y-1.5">
                <Label>সদস্য</Label>
                <Select value={memberId || undefined} onValueChange={(v) => setMemberId(v)}>
                  <SelectTrigger className="h-11 w-full rounded-xl">
                    <SelectValue placeholder="নির্বাচন করুন" />
                  </SelectTrigger>
                  <SelectContent>
                    {members.map((m) => (
                      <SelectItem key={m.id} value={m.id}>
                        {m.name}
                        {m.memberCode ? ` (${m.memberCode})` : ""}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
              <div className="space-y-1.5">
                <Label>শ্রেণি</Label>
                <Select value={category} onValueChange={(v) => setCategory(v === "2" ? "2" : "1")}>
                  <SelectTrigger className="h-11 w-full rounded-xl">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="1">১ — প্রাথমিক দ্বীন শিক্ষা ও দাওয়াত</SelectItem>
                    <SelectItem value="2">২ — অগ্রগামী ইলম ও পূর্ণাঙ্গ দাঈ</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            </div>
            {memberId && members.length > 0 ? (
              <p className="text-xs text-muted-foreground">
                {(() => {
                  const m = members.find((x) => x.id === memberId);
                  return m ? `স্তর: ${levelLabel(m.level)}` : "";
                })()}
              </p>
            ) : null}

            <div className="space-y-5">
              {template.sections.map((section) => (
                <div key={section.key}>
                  <h4 className="mb-2 text-sm font-bold text-primary">{section.titleBn}</h4>
                  <div className="space-y-2">
                    {section.criteria.map((c) => {
                      const value = scores[c.key];
                      return (
                        <div key={c.key} className="rounded-xl border border-border p-3">
                          <div className="flex items-start justify-between gap-2">
                            <div className="min-w-0">
                              <p className="text-sm font-semibold leading-snug">{c.titleBn}</p>
                              {c.hintBn ? <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{c.hintBn}</p> : null}
                            </div>
                          </div>
                          <div className="mt-2.5 flex gap-1.5">
                            {SCORE_OPTIONS.map((opt) => (
                              <button
                                key={opt.value}
                                type="button"
                                title={opt.title}
                                aria-label={`${c.titleBn}: ${opt.title}`}
                                aria-pressed={value === opt.value}
                                onClick={() => setScores((s) => ({ ...s, [c.key]: opt.value }))}
                                className={cn(
                                  "tap-target flex-1 rounded-lg border text-sm font-bold transition-colors",
                                  value === opt.value
                                    ? "border-primary bg-primary text-primary-foreground"
                                    : "border-border bg-card text-muted-foreground hover:bg-muted"
                                )}
                              >
                                {opt.label}
                              </button>
                            ))}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                </div>
              ))}
            </div>

            <div className="space-y-1.5">
              <Label htmlFor="assessment-comment">সার্বিক মন্তব্য</Label>
              <Textarea
                id="assessment-comment"
                value={overallComment}
                onChange={(e) => setOverallComment(e.target.value)}
                placeholder="সদস্যের সার্বিক অবস্থা, শক্তি ও উন্নতির ক্ষেত্র…"
                className="min-h-20 rounded-xl"
              />
            </div>

            <p className="text-xs text-muted-foreground">
              স্কোর দেওয়া হয়েছে {toBn(scoredCount)}/{toBn(totalCriteria)} মানদণ্ডে। প্রতিটি সেকশনের সংখ্যাগরিষ্ঠ
              মানদণ্ডে স্কোর ≥১ হলে "উত্তীর্ণ" ধরা হবে।
            </p>

            <DialogFooter className="flex-col gap-2">
              <Button className="h-11 w-full rounded-xl" onClick={save} disabled={!canSubmit || saving}>
                {saving ? "সংরক্ষণ হচ্ছে…" : "মূল্যায়ন জমা দিন"}
              </Button>
              <Button variant="ghost" className="h-11 w-full rounded-xl text-muted-foreground" onClick={() => onOpenChange(false)}>
                বাতিল
              </Button>
            </DialogFooter>
          </>
        )}
      </DialogContent>
    </Dialog>
  );
}
