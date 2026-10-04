"use client";

// মাসআলা জিজ্ঞাসা (full_admin) — questions members and guests send from the
// app. New first. Answering one delivers it to a signed-in asker's inbox and
// as a push; a guest is reached through the phone they left.

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BookOpenCheck, Phone, Send } from "lucide-react";
import { api, type MasalaQuestionItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/input";
import { EmptyState, PageHeading, RoleGate } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

type Filter = "new" | "answered" | "all";

function QuestionCard({ q }: { q: MasalaQuestionItem }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [draft, setDraft] = React.useState("");
  const answer = useMutation({
    mutationFn: () => api.answerMasala(q.id, draft.trim()),
    onSuccess: () => {
      toast(q.member ? "উত্তর পাঠানো হয়েছে — সদস্যের ইনবক্সে পৌঁছেছে" : "উত্তর সংরক্ষিত — অতিথিকে ফোনে জানান", "success");
      setDraft("");
      qc.invalidateQueries({ queryKey: ["admin-masala"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  return (
    <Card className={q.status === "new" ? "border-gold/60" : undefined}>
      <CardContent className="space-y-3 p-4">
        <div className="flex flex-wrap items-center gap-2 text-sm">
          <span className="font-semibold">{q.name}</span>
          {q.member?.gender ? <GenderBadge gender={q.member.gender} /> : <Badge variant="muted">অতিথি</Badge>}
          {q.member?.memberCode ? <Badge variant="outline">{q.member.memberCode}</Badge> : null}
          {q.phone ? (
            <a href={`tel:${q.phone}`} className="inline-flex items-center gap-1 tabular-nums text-primary" dir="ltr">
              <Phone className="h-3.5 w-3.5" aria-hidden />
              {q.phone}
            </a>
          ) : null}
          <span className="ml-auto text-xs text-muted-foreground" title={dateTimeBn(q.createdAt)}>
            {relativeBn(q.createdAt)}
          </span>
        </div>
        <p className="whitespace-pre-wrap text-sm font-medium leading-relaxed">{q.question}</p>
        {q.status === "answered" && q.answer ? (
          <div className="rounded-md border-l-4 border-primary bg-primary-soft p-3 text-sm leading-relaxed">
            <p className="whitespace-pre-wrap">{q.answer}</p>
            {q.answeredAt ? <p className="mt-1 text-xs text-muted-foreground">উত্তর: {dateTimeBn(q.answeredAt)}</p> : null}
          </div>
        ) : (
          <div className="space-y-2">
            <Textarea
              value={draft}
              onChange={(e) => setDraft(e.target.value)}
              placeholder="দলিলসহ উত্তর লিখুন…"
              rows={4}
              maxLength={8000}
              aria-label="উত্তর"
            />
            <div className="flex justify-end">
              <Button onClick={() => answer.mutate()} loading={answer.isPending} disabled={draft.trim().length < 2}>
                <Send className="h-4 w-4" aria-hidden />
                উত্তর পাঠান
              </Button>
            </div>
          </div>
        )}
      </CardContent>
    </Card>
  );
}

export default function MasalaPage() {
  const { user } = useSession();
  const [filter, setFilter] = React.useState<Filter>("new");
  const list = useQuery({
    queryKey: ["admin-masala", filter],
    queryFn: () => api.masalaInbox(filter === "all" ? undefined : filter),
    enabled: !!user,
  });
  if (!user) return <TableSkeleton rows={4} cols={3} />;
  const items = list.data?.questions ?? [];

  return (
    <RoleGate allow={(r) => r === "full_admin"} role={user.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<BookOpenCheck className="h-6 w-6" aria-hidden />}
          title="মাসআলা জিজ্ঞাসা"
          description="অ্যাপ থেকে আসা দ্বীনি প্রশ্ন। উত্তর দিলে সদস্য অ্যাপের নোটিফিকেশনে ও 'আমার প্রশ্ন ও উত্তর'-এ পাবেন; অতিথিকে তাঁর দেওয়া ফোনে জানাতে হবে।"
        />
        <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="ফিল্টার">
          {(
            [
              ["new", `উত্তর বাকি${list.data ? ` (${toBn(list.data.newCount)})` : ""}`],
              ["answered", "উত্তর দেওয়া"],
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
          <EmptyState title={filter === "new" ? "উত্তর বাকি এমন কোনো প্রশ্ন নেই" : "কিছু নেই"} />
        ) : (
          <div className="space-y-3">
            {items.map((q) => (
              <QuestionCard key={q.id} q={q} />
            ))}
          </div>
        )}
      </div>
    </RoleGate>
  );
}
