"use client";

// মতামত (full_admin) — what members and testers send from the app's
// "মতামত" tile (POST /api/feedback). New first; each message shows who sent
// it (or অতিথি), when, and the app version + phone OS the app attached.
// "সমাধান হয়েছে" moves it out of the new list (and back, if needed).

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { CheckCheck, MessageSquareText, RotateCcw, Smartphone } from "lucide-react";
import { api, type FeedbackItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { ROLE_LABELS_BN } from "@/lib/labels";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { EmptyState, PageHeading, RoleGate } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

type Filter = "new" | "done" | "all";

export default function FeedbackPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const [filter, setFilter] = React.useState<Filter>("new");
  const list = useQuery({
    queryKey: ["admin-feedback", filter],
    queryFn: () => api.feedbackInbox(filter === "all" ? undefined : filter),
    enabled: !!user,
  });
  const setStatus = useMutation({
    mutationFn: ({ id, status }: { id: string; status: "new" | "done" }) => api.setFeedbackStatus(id, status),
    onSuccess: (_, v) => {
      toast(v.status === "done" ? "সমাধান হয়েছে হিসেবে চিহ্নিত" : "আবার নতুন তালিকায়", "success");
      qc.invalidateQueries({ queryKey: ["admin-feedback"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  if (!user) return <TableSkeleton rows={4} cols={3} />;

  const items = list.data?.feedback ?? [];
  return (
    <RoleGate allow={(r) => r === "full_admin"} role={user.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<MessageSquareText className="h-6 w-6" aria-hidden />}
          title="মতামত"
          description="অ্যাপের 'মতামত' থেকে পাঠানো লেখা — সদস্য ও পরীক্ষকদের সমস্যা-প্রস্তাব। প্রতিটির সাথে অ্যাপ-সংস্করণ ও ফোনের তথ্য থাকে।"
        />
        <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="ফিল্টার">
          {(
            [
              ["new", `নতুন${list.data ? ` (${toBn(list.data.newCount)})` : ""}`],
              ["done", "সমাধান হয়েছে"],
              ["all", "সব"],
            ] as const
          ).map(([v, label]) => (
            <button
              key={v}
              type="button"
              role="radio"
              aria-checked={filter === v}
              onClick={() => setFilter(v)}
              className={cn(
                "focus-ring min-h-10 rounded-full border px-4 text-sm font-semibold transition-colors",
                filter === v ? "border-primary bg-primary text-primary-foreground" : "border-border bg-card hover:bg-primary-soft"
              )}
            >
              {label}
            </button>
          ))}
        </div>

        {list.isLoading ? (
          <TableSkeleton rows={4} cols={3} />
        ) : items.length === 0 ? (
          <EmptyState title={filter === "new" ? "নতুন কোনো মতামত নেই" : "কিছু নেই"} />
        ) : (
          <div className="space-y-3">
            {items.map((f: FeedbackItem) => (
              <Card key={f.id} className={f.status === "new" ? "border-gold/60" : undefined}>
                <CardContent className="space-y-3 p-4">
                  <div className="flex flex-wrap items-center gap-2 text-sm">
                    <span className="font-semibold">{f.user?.name ?? "অতিথি (লগইন ছাড়া)"}</span>
                    {f.user?.gender ? <GenderBadge gender={f.user.gender} /> : null}
                    {f.user?.role ? <Badge variant="muted">{ROLE_LABELS_BN[f.user.role] ?? f.user.role}</Badge> : null}
                    {f.user?.phone ? (
                      <span className="tabular-nums text-muted-foreground" dir="ltr">
                        {f.user.phone}
                      </span>
                    ) : null}
                    <span className="ml-auto text-xs text-muted-foreground" title={dateTimeBn(f.createdAt)}>
                      {relativeBn(f.createdAt)}
                    </span>
                  </div>
                  <p className="whitespace-pre-wrap text-sm leading-relaxed">{f.message}</p>
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <span className="inline-flex items-center gap-1.5 text-xs text-muted-foreground">
                      <Smartphone className="h-3.5 w-3.5" aria-hidden />
                      {f.context ?? "ডিভাইসের তথ্য নেই (পুরনো সংস্করণ)"}
                    </span>
                    {f.status === "new" ? (
                      <Button
                        size="sm"
                        onClick={() => setStatus.mutate({ id: f.id, status: "done" })}
                        disabled={setStatus.isPending}
                      >
                        <CheckCheck className="h-4 w-4" aria-hidden />
                        সমাধান হয়েছে
                      </Button>
                    ) : (
                      <Button
                        size="sm"
                        variant="outline"
                        onClick={() => setStatus.mutate({ id: f.id, status: "new" })}
                        disabled={setStatus.isPending}
                      >
                        <RotateCcw className="h-4 w-4" aria-hidden />
                        আবার খুলুন
                      </Button>
                    )}
                  </div>
                </CardContent>
              </Card>
            ))}
          </div>
        )}
      </div>
    </RoleGate>
  );
}
