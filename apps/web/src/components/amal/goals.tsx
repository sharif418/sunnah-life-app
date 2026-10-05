"use client";

// Personal goals (W4c, mobile parity): a member proposes a goal tied to one
// diary amal; the usrah head approves or rejects it. The member sees every
// goal with its status and can remove an open one. Heads get the approval
// queue (GoalQueueSection) on the Dawah → Usrah tab.

import * as React from "react";
import { ArrowLeft, Check, Flag, Loader2, Plus, Trash2, X } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { toBn } from "@/lib/calendars";
import { cn } from "@/lib/utils";
import type { AmalDefinition, GoalQueueItem, GoalStatus, PersonalGoal } from "@/types/domain";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { EmptyState, ErrorState, SkeletonRows, useAsync } from "@/components/dawah/parts";

const STATUS: Record<GoalStatus, { label: string; cls: string }> = {
  proposed: { label: "অনুমোদনের অপেক্ষায়", cls: "bg-gold-soft text-gold-text-foreground" },
  approved: { label: "অনুমোদিত", cls: "bg-primary-soft text-primary" },
  rejected: { label: "বাতিল", cls: "bg-alert-soft text-alert" },
  completed: { label: "সম্পন্ন", cls: "bg-primary-soft text-primary" },
  withdrawn: { label: "প্রত্যাহৃত", cls: "bg-muted text-muted-foreground" },
};
const TERMINAL: GoalStatus[] = ["rejected", "completed", "withdrawn"];

function today(): string {
  const d = new Date();
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}

export function GoalsView({ defs, onBack }: { defs: AmalDefinition[]; onBack: () => void }) {
  const goals = useAsync(() => api.goals());
  const [proposing, setProposing] = React.useState(false);
  const titleOf = React.useMemo(() => new Map(defs.map((d) => [d.key, d.titleBn])), [defs]);

  const remove = async (g: PersonalGoal) => {
    try {
      await api.deleteGoal(g.id);
      toast.success("লক্ষ্যটি সরানো হয়েছে");
      goals.reload();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "সরানো যায়নি");
    }
  };

  const list = goals.data?.goals ?? [];
  return (
    <div className="space-y-4">
      <div className="flex items-center gap-2">
        <Button variant="ghost" size="sm" className="h-9 rounded-full" onClick={onBack}>
          <ArrowLeft className="size-4 rtl:rotate-180" /> ফিরে যান
        </Button>
        <h2 className="flex-1 text-lg font-bold">আমার লক্ষ্য</h2>
        <Button size="sm" className="h-9 rounded-full" onClick={() => setProposing(true)}>
          <Plus className="size-4" /> নতুন লক্ষ্য
        </Button>
      </div>
      <p className="text-sm leading-relaxed text-muted-foreground">
        ডায়েরির কোনো একটি আমলে নিজের জন্য লক্ষ্য ঠিক করুন। উসরা প্রধান অনুমোদন দিলে লক্ষ্যটি চালু হবে।
      </p>

      {goals.loading ? (
        <SkeletonRows count={3} />
      ) : goals.error ? (
        <ErrorState message={goals.error} onRetry={goals.reload} />
      ) : list.length === 0 ? (
        <EmptyState
          icon={Flag}
          title="এখনো কোনো লক্ষ্য নেই"
          hint="প্রথম লক্ষ্যটি ঠিক করুন — যেমন সপ্তাহে তিন দিন তাহাজ্জুদ।"
          action={
            <Button className="rounded-full" onClick={() => setProposing(true)}>
              <Plus className="size-4" /> নতুন লক্ষ্য
            </Button>
          }
        />
      ) : (
        <div className="space-y-2">
          {list.map((g) => (
            <Card key={g.id} className="gap-1 rounded-xl p-3.5 shadow-card">
              <div className="flex items-start gap-2">
                <div className="min-w-0 flex-1">
                  <p className="font-semibold">{g.title}</p>
                  <p className="text-xs text-muted-foreground">
                    {[titleOf.get(g.amalKey) ?? g.amalKey, g.target || null, toBn(g.startDate)].filter(Boolean).join(" · ")}
                  </p>
                </div>
                <span className={cn("shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold", STATUS[g.status]?.cls)}>
                  {STATUS[g.status]?.label ?? g.status}
                </span>
              </div>
              {g.note ? <p className="text-sm leading-relaxed">{g.note}</p> : null}
              {g.status === "rejected" && g.reason ? (
                <p className="rounded-lg bg-alert-soft px-3 py-1.5 text-xs text-alert">কারণ: {g.reason}</p>
              ) : null}
              {!TERMINAL.includes(g.status) ? (
                <div className="flex justify-end">
                  <Button variant="ghost" size="sm" className="h-8 text-muted-foreground" onClick={() => remove(g)}>
                    <Trash2 className="size-3.5" /> সরান
                  </Button>
                </div>
              ) : null}
            </Card>
          ))}
        </div>
      )}

      <ProposeDialog
        open={proposing}
        defs={defs}
        onClose={() => setProposing(false)}
        onDone={() => {
          setProposing(false);
          goals.reload();
        }}
      />
    </div>
  );
}

function ProposeDialog({
  open,
  defs,
  onClose,
  onDone,
}: {
  open: boolean;
  defs: AmalDefinition[];
  onClose: () => void;
  onDone: () => void;
}) {
  const [amalKey, setAmalKey] = React.useState("");
  const [title, setTitle] = React.useState("");
  const [target, setTarget] = React.useState("");
  const [note, setNote] = React.useState("");
  const [busy, setBusy] = React.useState(false);

  React.useEffect(() => {
    if (open) {
      setAmalKey("");
      setTitle("");
      setTarget("");
      setNote("");
    }
  }, [open]);

  const submit = async () => {
    setBusy(true);
    try {
      await api.proposeGoal({ amalKey, title: title.trim(), startDate: today(), target: target.trim() || undefined, note: note.trim() || undefined });
      toast.success("লক্ষ্য প্রস্তাবিত — উসরা প্রধানের অনুমোদনের অপেক্ষায়");
      onDone();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "প্রস্তাব পাঠানো যায়নি");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Dialog open={open} onOpenChange={(v) => (!v ? onClose() : null)}>
      <DialogContent className="sm:max-w-md">
        <DialogHeader>
          <DialogTitle>নতুন লক্ষ্য</DialogTitle>
        </DialogHeader>
        <div className="space-y-3">
          <div className="space-y-1.5">
            <Label htmlFor="goal-amal">আমল</Label>
            <select
              id="goal-amal"
              value={amalKey}
              onChange={(e) => {
                setAmalKey(e.target.value);
                if (!title.trim()) setTitle(defs.find((d) => d.key === e.target.value)?.titleBn ?? "");
              }}
              className="h-10 w-full rounded-md border border-input bg-background px-3 text-sm"
            >
              <option value="">— আমল বেছে নিন —</option>
              {defs.map((d) => (
                <option key={d.key} value={d.key}>
                  {d.titleBn}
                </option>
              ))}
            </select>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="goal-title">লক্ষ্যের নাম</Label>
            <Input id="goal-title" maxLength={200} value={title} onChange={(e) => setTitle(e.target.value)} />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="goal-target">লক্ষ্য মাত্রা (ঐচ্ছিক)</Label>
            <Input
              id="goal-target"
              placeholder="যেমন: সপ্তাহে ৩ দিন"
              value={target}
              onChange={(e) => setTarget(e.target.value)}
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="goal-note">নোট (ঐচ্ছিক)</Label>
            <Textarea id="goal-note" rows={2} value={note} onChange={(e) => setNote(e.target.value)} />
          </div>
          <Button className="w-full" onClick={submit} disabled={busy || !amalKey || !title.trim()}>
            {busy ? <Loader2 className="animate-spin" aria-hidden /> : null}
            প্রস্তাব করুন
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

/** The usrah head's approval queue (GET /api/usrah/goals). Hidden when empty. */
export function GoalQueueSection() {
  const queue = useAsync(() => api.usrahGoals());
  const [rejecting, setRejecting] = React.useState<GoalQueueItem | null>(null);
  const [reason, setReason] = React.useState("");
  const [busyId, setBusyId] = React.useState<string | null>(null);

  const decide = async (item: GoalQueueItem, approve: boolean, why?: string) => {
    setBusyId(item.id);
    try {
      if (approve) await api.approveGoal(item.id);
      else await api.rejectGoal(item.id, why);
      toast.success(approve ? "অনুমোদিত হয়েছে" : "বাতিল হয়েছে");
      setRejecting(null);
      setReason("");
      queue.reload();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "করা যায়নি");
    } finally {
      setBusyId(null);
    }
  };

  const items = queue.data?.queue ?? [];
  if (queue.loading || queue.error || items.length === 0) return null;
  return (
    <section aria-label="লক্ষ্য অনুমোদনের অপেক্ষায়" className="space-y-2">
      <h3 className="text-sm font-bold">লক্ষ্য অনুমোদনের অপেক্ষায় ({toBn(items.length)})</h3>
      {items.map((it) => (
        <Card key={it.id} className="gap-1 rounded-xl p-3.5 shadow-card">
          <p className="text-xs font-semibold text-muted-foreground">{it.userName}</p>
          <p className="font-semibold">{it.title}</p>
          {it.target || it.note ? (
            <p className="text-sm text-muted-foreground">{[it.target, it.note].filter(Boolean).join(" · ")}</p>
          ) : null}
          <div className="mt-1 flex justify-end gap-2">
            <Button variant="outline" size="sm" className="h-8" onClick={() => setRejecting(it)} disabled={busyId === it.id}>
              <X className="size-3.5" /> বাতিল
            </Button>
            <Button size="sm" className="h-8" onClick={() => decide(it, true)} disabled={busyId === it.id}>
              <Check className="size-3.5" /> অনুমোদন
            </Button>
          </div>
        </Card>
      ))}
      <Dialog open={!!rejecting} onOpenChange={(v) => (!v ? setRejecting(null) : null)}>
        <DialogContent className="sm:max-w-md">
          <DialogHeader>
            <DialogTitle>লক্ষ্য বাতিল</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            <p className="text-sm">{rejecting?.title}</p>
            <div className="space-y-1.5">
              <Label htmlFor="goal-reject-reason">বাতিলের কারণ (ঐচ্ছিক)</Label>
              <Textarea id="goal-reject-reason" rows={2} value={reason} onChange={(e) => setReason(e.target.value)} />
            </div>
            <Button
              variant="destructive"
              className="w-full"
              disabled={!rejecting || busyId === rejecting?.id}
              onClick={() => rejecting && decide(rejecting, false, reason.trim() || undefined)}
            >
              বাতিল করুন
            </Button>
          </div>
        </DialogContent>
      </Dialog>
    </section>
  );
}
