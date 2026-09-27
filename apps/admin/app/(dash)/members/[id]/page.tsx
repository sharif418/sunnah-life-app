"use client";

import * as React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import {
  ArrowLeft,
  CalendarDays,
  ChevronLeft,
  ChevronRight,
  ClipboardCheck,
  FileCheck2,
  Lock,
  MapPin,
  Phone,
  ShieldCheck,
} from "lucide-react";
import { api } from "@/lib/api";
import { useSession } from "@/lib/session";
import {
  addDays,
  bdMonth,
  bdToday,
  completionPct,
  dateLabelBn,
  monthLabel,
  relativeBn,
  toBn,
} from "@/lib/bn";
import {
  ASSESSMENT_RESULT_LABELS_BN,
  CATEGORY_LABELS_BN,
  LEVEL_LABELS_BN,
  REVIEW_STATUS_LABELS_BN,
  auditActionLabel,
  isSupervisor,
} from "@/lib/labels";
import { CategoryBadge, GenderBadge, LevelBadge, RoleBadge } from "@/components/badges";
import { MonthGridHeatmap } from "@/components/month-grid";
import { ReviewDialog } from "@/components/review-dialog";
import { Badge } from "@/components/ui/badge";
import { useToast } from "@/components/ui/toast";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Field, Textarea } from "@/components/ui/input";
import { Skeleton, TableSkeleton } from "@/components/ui/skeleton";
import { EmptyState, ErrorState } from "@/components/ui/states";
import { cn } from "@/lib/utils";

function monthShift(month: string, delta: number): string {
  const [y, m] = month.split("-").map(Number);
  const d = new Date(Date.UTC(y, m - 1 + delta, 1));
  return d.toISOString().slice(0, 7);
}

function UnlockDialog({
  userId,
  userName,
  date,
  onClose,
}: {
  userId: string;
  userName: string;
  date: string | null;
  onClose: () => void;
}) {
  const [reason, setReason] = React.useState("");
  const { toast } = useToast();
  const qc = useQueryClient();

  // Clear the reason whenever the target date changes — render-phase adjustment.
  const [prevDate, setPrevDate] = React.useState<string | null>(date);
  if (date !== prevDate) {
    setPrevDate(date);
    setReason("");
  }

  const unlock = useMutation({
    mutationFn: (d: string) => api.unlockDay(userId, d, reason),
    onSuccess: () => {
      toast(`${dateLabelBn(date ?? "")} দিনটি আনলক করা হয়েছে — ${userName} এখন এন্ট্রি দিতে পারবেন`, "success");
      qc.invalidateQueries({ queryKey: ["audit-log"] });
      qc.invalidateQueries({ queryKey: ["admin-overview"] });
      onClose();
    },
    onError: (err: Error) => toast(err.message, "error"),
  });

  return (
    <Dialog
      open={date !== null}
      onClose={onClose}
      title="লকড দিন আনলক করুন"
      description={date ? `${userName} — ${dateLabelBn(date)}` : undefined}
      footer={
        <>
          <Button variant="outline" onClick={onClose} disabled={unlock.isPending}>
            বাতিল
          </Button>
          <Button onClick={() => date && unlock.mutate(date)} loading={unlock.isPending}>
            <Lock className="h-4 w-4" aria-hidden />
            আনলক করুন
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        <p className="rounded-md border border-gold/40 bg-gold-soft/70 p-3 text-sm leading-relaxed">
          কাগজের মুহাসাবা ডায়েরির নিয়ম: পরদিন ইশরাকের পর দিনটি লক হয়ে যায়। বৈধ কারণ ছাড়া আনলক
          করা নিরুৎসাহিত — প্রতিটি আনলক অডিট লগে সংরক্ষিত হয়।
        </p>
        <Field label="কারণ" htmlFor="unlock-reason" hint="যেমন: অসুস্থতা, ভ্রমণ, জরুরি প্রয়োজন">
          <Textarea
            id="unlock-reason"
            value={reason}
            onChange={(e) => setReason(e.target.value)}
            placeholder="আনলকের কারণ লিখুন…"
            maxLength={500}
          />
        </Field>
      </div>
    </Dialog>
  );
}

export default function MemberPage() {
  const params = useParams<{ id: string }>();
  const userId = params?.id;
  const { user, fullAdmin } = useSession();

  const [month, setMonth] = React.useState(bdMonth());
  const [unlockDate, setUnlockDate] = React.useState<string | null>(null);
  const [reviewOpen, setReviewOpen] = React.useState(false);

  const today = bdToday();
  const from7 = addDays(today, -6);

  const usersQuery = useQuery({
    queryKey: ["admin-users", ""],
    queryFn: () => api.users(""),
    enabled: !!userId,
  });
  const member = React.useMemo(
    () => usersQuery.data?.users.find((u) => u.id === userId) ?? null,
    [usersQuery.data, userId]
  );

  const gridQuery = useQuery({
    queryKey: ["month-grid", userId, month],
    queryFn: () => api.monthGrid(userId!, month),
    enabled: !!userId && !!member,
  });

  const entries7 = useQuery({
    queryKey: ["amal-entries-7d", userId],
    queryFn: () => api.amalEntries(from7, today, userId),
    enabled: !!userId && !!member,
  });

  const defsQuery = useQuery({
    queryKey: ["amal-definitions"],
    queryFn: () => api.definitions(),
  });

  const auditQuery = useQuery({
    queryKey: ["audit-log"],
    queryFn: () => api.audit(),
    enabled: fullAdmin,
    refetchOnWindowFocus: false,
  });
  const overviewAudit = useQuery({
    queryKey: ["admin-overview"],
    queryFn: () => api.overview(),
    enabled: !fullAdmin,
  });

  const assessmentsQuery = useQuery({
    queryKey: ["assessments", userId],
    queryFn: () => api.assessments(userId),
    enabled: !!userId && !!member,
  });

  const queueQuery = useQuery({
    queryKey: ["review-queue"],
    queryFn: () => api.reviewQueue(),
    enabled: !!userId && !!member,
  });

  const memberReviews = React.useMemo(
    () => (queueQuery.data?.queue ?? []).filter((r) => r.userId === userId),
    [queueQuery.data, userId]
  );
  const activeReview = memberReviews[0] ?? null;

  const unlockedDays = React.useMemo(() => {
    const set = new Set<string>();
    const entries = fullAdmin ? auditQuery.data?.entries : overviewAudit.data?.recentAudit;
    for (const e of entries ?? []) {
      if (e.action !== "unlock_day") continue;
      const meta = e.meta as { userId?: string; date?: string } | null;
      if (meta?.userId === userId && meta?.date) set.add(meta.date);
      // legacy seeded rows: targetId = "userId:date"
      if (e.targetId?.startsWith(`${userId}:`)) set.add(e.targetId.slice(userId.length + 1));
    }
    return set;
  }, [auditQuery.data, overviewAudit.data, fullAdmin, userId]);

  const completion7 = React.useMemo(() => {
    if (!entries7.data || !defsQuery.data || !member) return null;
    const dailyDefs = defsQuery.data.definitions
      .filter((d) => d.cadence === "daily")
      .map((d) => ({ key: d.key, inputType: d.inputType, target: d.target }));
    const days = Array.from({ length: 7 }, (_, i) => addDays(from7, i));
    return completionPct(entries7.data.entries, dailyDefs, member.category, days);
  }, [entries7.data, defsQuery.data, member, from7]);

  if (usersQuery.isLoading) {
    return (
      <div className="space-y-4" aria-label="লোড হচ্ছে" role="status">
        <div className="skeleton h-24" />
        <div className="skeleton h-96" />
      </div>
    );
  }

  if (usersQuery.isError) {
    return <ErrorState error={usersQuery.error} onRetry={() => usersQuery.refetch()} />;
  }

  if (!member) {
    return (
      <EmptyState
        title="সদস্য পাওয়া যায়নি"
        hint="এই আইডির কোনো সদস্য আপনার পরিসরে নেই — হয়তো লিঙ্কটি পুরোনো, অথবা লিঙ্গ-সুরক্ষা নিয়মে প্রবেশাধিকার নেই।"
        action={
          <Link href="/usrah" className="focus-ring rounded">
            <Button variant="outline">
              <ArrowLeft className="h-4 w-4" aria-hidden />
              উসরায় ফিরে যান
            </Button>
          </Link>
        }
      />
    );
  }

  return (
    <div className="space-y-6">
      <Link
        href="/usrah"
        className="focus-ring inline-flex min-h-9 items-center gap-1.5 rounded text-sm font-medium text-muted-foreground transition-colors hover:text-primary"
      >
        <ArrowLeft className="h-4 w-4" aria-hidden />
        উসরার তালিকায় ফিরুন
      </Link>

      {/* profile header */}
      <Card>
        <CardContent className="flex flex-col gap-4 pt-5 lg:flex-row lg:items-start lg:justify-between">
          <div className="flex items-start gap-4">
            <div
              className="flex h-14 w-14 shrink-0 items-center justify-center rounded-full bg-primary text-lg font-bold text-primary-foreground"
              aria-hidden
            >
              {member.name.slice(0, 2)}
            </div>
            <div>
              <h2 className="text-lg font-bold leading-snug">{member.name}</h2>
              <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                <GenderBadge gender={member.gender} />
                <RoleBadge role={member.role} />
                <LevelBadge level={member.level} />
                <CategoryBadge category={member.category} />
              </div>
              <p className="mt-2 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
                {member.memberCode ? <span className="font-mono">{member.memberCode}</span> : null}
                {member.phone ? (
                  <span className="flex items-center gap-1" dir="ltr">
                    <Phone className="h-3 w-3" aria-hidden />
                    {toBn(member.phone)}
                  </span>
                ) : null}
                {member.city ? (
                  <span className="flex items-center gap-1">
                    <MapPin className="h-3 w-3" aria-hidden />
                    {member.city}
                  </span>
                ) : null}
                <span className="flex items-center gap-1">
                  <CalendarDays className="h-3 w-3" aria-hidden />
                  যোগদান: {dateLabelBn(member.createdAt.slice(0, 10))}
                </span>
              </p>
              <p className="mt-1 text-xs text-muted-foreground">
                সর্বশেষ সক্রিয়: {relativeBn(member.lastActiveAt)} · উসরা:{" "}
                {member.usrahName ?? "নেই"}
              </p>
            </div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <div className="flex flex-col items-center rounded-md border border-border bg-muted/50 px-4 py-2">
              <span className="text-[11px] font-medium text-muted-foreground">৭ দিনের সম্পূর্ণতা</span>
              <span className="text-xl font-bold text-primary">
                {entries7.isLoading || defsQuery.isLoading ? "…" : completion7 !== null ? `${toBn(completion7)}%` : "—"}
              </span>
            </div>
            {isSupervisor(user?.role) ? (
              <Button onClick={() => setReviewOpen(true)}>
                <ClipboardCheck className="h-4 w-4" aria-hidden />
                রিভিউ দিন
              </Button>
            ) : null}
            <Link href={`/assessments?member=${member.id}`} className="focus-ring rounded">
              <Button variant="secondary">
                <FileCheck2 className="h-4 w-4" aria-hidden />
                নতুন মূল্যায়ন
              </Button>
            </Link>
          </div>
        </CardContent>
      </Card>

      <UnlockDialog userId={member.id} userName={member.name} date={unlockDate} onClose={() => setUnlockDate(null)} />
      <ReviewDialog
        member={{
          id: member.id,
          name: member.name,
          level: member.level,
          completion7d: completion7 ?? activeReview?.user?.completion7d ?? null,
        }}
        review={activeReview ?? undefined}
        open={reviewOpen}
        onClose={() => setReviewOpen(false)}
      />

      {/* month grid */}
      <Card>
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-3">
          <div>
            <CardTitle>মুহাসাবা ডায়েরি — {monthLabel(month)}</CardTitle>
            <CardDescription>
              {toBn(gridQuery.data?.grid.days.length ?? 0)} দিনের গ্রিড · সবুজ=জামাত · হালকা সবুজ=একা ·
              সোনালি=কাযা/আংশিক · লাল=বাদ পড়েছে
            </CardDescription>
          </div>
          <div className="no-print flex items-center gap-1">
            <Button
              variant="outline"
              size="icon"
              aria-label="আগের মাস"
              onClick={() => setMonth((m) => monthShift(m, -1))}
            >
              <ChevronLeft className="h-4 w-4" aria-hidden />
            </Button>
            <span className="min-w-28 text-center text-sm font-semibold">{monthLabel(month)}</span>
            <Button
              variant="outline"
              size="icon"
              aria-label="পরের মাস"
              disabled={month >= bdMonth()}
              onClick={() => setMonth((m) => monthShift(m, 1))}
            >
              <ChevronRight className="h-4 w-4" aria-hidden />
            </Button>
          </div>
        </CardHeader>
        <CardContent>
          {gridQuery.isLoading ? (
            <div className="space-y-2" role="status" aria-label="গ্রিড লোড হচ্ছে">
              <div className="skeleton h-8" />
              {Array.from({ length: 8 }).map((_, i) => (
                <Skeleton key={i} className="h-7" />
              ))}
            </div>
          ) : gridQuery.isError ? (
            <ErrorState
              error={gridQuery.error}
              onRetry={() => gridQuery.refetch()}
              title="গ্রিড আনা যায়নি"
            />
          ) : gridQuery.data ? (
            <MonthGridHeatmap
              grid={gridQuery.data.grid}
              user={member}
              month={month}
              unlockedDays={unlockedDays}
              canUnlock={isSupervisor(user?.role)}
              onUnlockDay={(d) => setUnlockDate(d)}
            />
          ) : null}
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-2">
        {/* reviews */}
        <Card>
          <CardHeader>
            <CardTitle>রিভিউয়ের অবস্থা</CardTitle>
            <CardDescription>এই সপ্তাহ ও বিলম্বিত রিভিউ</CardDescription>
          </CardHeader>
          <CardContent>
            {queueQuery.isLoading ? (
              <TableSkeleton rows={2} cols={3} />
            ) : queueQuery.isError ? (
              <ErrorState error={queueQuery.error} onRetry={() => queueQuery.refetch()} />
            ) : memberReviews.length === 0 ? (
              <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
                এই সপ্তাহে কোনো রিভিউ বাকি নেই ✓
              </p>
            ) : (
              <ul className="space-y-2">
                {memberReviews.map((r) => (
                  <li
                    key={r.id}
                    className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-border p-3 text-sm"
                  >
                    <span className="flex flex-col">
                      <span className="font-medium">সপ্তাহ: {toBn(r.weekStart)}</span>
                      {r.summary?.overallPct != null ? (
                        <span className="text-xs text-muted-foreground">
                          সম্পূর্ণতা {toBn(r.summary.overallPct)}%
                          {r.summary.streak != null ? ` · স্ট্রিক ${toBn(r.summary.streak)} দিন` : ""}
                        </span>
                      ) : null}
                    </span>
                    <Badge variant={r.status === "overdue" ? "alert" : r.status === "done" ? "success" : "warning"}>
                      {REVIEW_STATUS_LABELS_BN[r.status] ?? r.status}
                    </Badge>
                  </li>
                ))}
              </ul>
            )}
            {activeReview && activeReview.status !== "done" ? (
              <Button variant="secondary" size="sm" className="mt-3" onClick={() => setReviewOpen(true)}>
                এই সপ্তাহের রিভিউ সম্পূর্ণ করুন
              </Button>
            ) : null}
          </CardContent>
        </Card>

        {/* assessments */}
        <Card>
          <CardHeader>
            <CardTitle>মূল্যায়নের ইতিহাস</CardTitle>
            <CardDescription>ফরযে আইন মূল্যায়ন — দ্বৈত স্বাক্ষরসহ</CardDescription>
          </CardHeader>
          <CardContent>
            {assessmentsQuery.isLoading ? (
              <TableSkeleton rows={2} cols={3} />
            ) : assessmentsQuery.isError ? (
              <ErrorState error={assessmentsQuery.error} onRetry={() => assessmentsQuery.refetch()} />
            ) : (assessmentsQuery.data?.assessments ?? []).length === 0 ? (
              <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
                এখনো কোনো মূল্যায়ন হয়নি —{" "}
                <Link
                  href={`/assessments?member=${member.id}`}
                  className="font-medium text-primary hover:underline"
                >
                  প্রথম মূল্যায়ন শুরু করুন
                </Link>
              </p>
            ) : (
              <ul className="space-y-2">
                {(assessmentsQuery.data?.assessments ?? []).map((a) => (
                  <li key={a.id} className="rounded-md border border-border">
                    <details className="group">
                      <summary className="flex cursor-pointer list-none flex-wrap items-center justify-between gap-2 p-3 text-sm">
                        <span className="flex items-center gap-2">
                          <Badge variant={a.result === "passed" ? "success" : "warning"}>
                            {ASSESSMENT_RESULT_LABELS_BN[a.result]}
                          </Badge>
                          <span className="text-xs text-muted-foreground">{relativeBn(a.createdAt)}</span>
                        </span>
                        <span className="flex items-center gap-2 text-xs text-muted-foreground">
                          {a.scorePct != null ? (
                            <span className="font-bold text-foreground">{toBn(a.scorePct)}%</span>
                          ) : null}
                          <span className="flex items-center gap-1" title="মূল্যায়নকারীর স্বাক্ষর">
                            <ShieldCheck
                              className={cn("h-3.5 w-3.5", a.assessorSignedAt ? "text-success" : "text-muted-foreground/40")}
                              aria-hidden
                            />
                          </span>
                          <span
                            className="flex items-center gap-1"
                            title="মূল্যায়নার্থীর স্বাক্ষর (ওটিপি-নিশ্চিত)"
                          >
                            <ShieldCheck
                              className={cn("h-3.5 w-3.5", a.assesseeSignedAt ? "text-success" : "text-muted-foreground/40")}
                              aria-hidden
                            />
                          </span>
                        </span>
                      </summary>
                      <div className="border-t border-border p-3 text-sm">
                        <p className="mb-2 text-xs text-muted-foreground">
                          {a.template.titleBn} · ক্যাটাগরি {toBn(a.participantCategory)} · মূল্যায়নকারী:{" "}
                          {a.assessorName ?? "—"} · {dateLabelBn(a.createdAt.slice(0, 10))}
                        </p>
                        <div className="scroll-thin max-h-64 space-y-1 overflow-y-auto">
                          {a.template.sections.map((s) => (
                            <div key={s.key} className="mb-1">
                              <p className="text-xs font-bold text-foreground">{s.titleBn}</p>
                              <ul className="mt-0.5 space-y-0.5">
                                {s.criteria.map((c) => {
                                  const sc = a.scores[c.key];
                                  return (
                                    <li key={c.key} className="flex items-start justify-between gap-2 text-xs">
                                      <span className="min-w-0 flex-1 text-muted-foreground">{c.titleBn}</span>
                                      <Badge
                                        variant={!sc || sc.score === 0 ? "alert" : sc.score === 1 ? "warning" : "success"}
                                        className="shrink-0"
                                      >
                                        {toBn(sc?.score ?? 0)}
                                      </Badge>
                                    </li>
                                  );
                                })}
                              </ul>
                            </div>
                          ))}
                        </div>
                        {a.overallComment ? (
                          <p className="mt-2 rounded-md bg-muted/60 p-2 text-xs leading-relaxed">
                            <strong>সামগ্রিক মন্তব্য: </strong>
                            {a.overallComment}
                          </p>
                        ) : null}
                      </div>
                    </details>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      </div>

      {/* goals note */}
      <Card>
        <CardHeader>
          <CardTitle>লক্ষ্য ও পরামর্শ</CardTitle>
          <CardDescription>
            সাপ্তাহিক রিভিউর সময় «পরবর্তী লক্ষ্যসমূহ» ঘরে সদস্যের জন্য ব্যক্তিগত লক্ষ্য (সর্বোচ্চ ১৪টি
            আমল) নির্ধারণ করা হয় — সদস্য রিমাইন্ডার পান এবং নিজের অ্যাপে লক্ষ্যগুলো দেখতে পান।
          </CardDescription>
        </CardHeader>
        <CardContent>
          <div className="flex flex-wrap items-center gap-2">
            <Button size="sm" onClick={() => setReviewOpen(true)}>
              <ClipboardCheck className="h-4 w-4" aria-hidden />
              লক্ষ্যসহ রিভিউ দিন
            </Button>
            <span className="text-xs text-muted-foreground">
              স্তর: {LEVEL_LABELS_BN[member.level]} · ক্যাটাগরি: {CATEGORY_LABELS_BN[member.category]}
            </span>
          </div>
        </CardContent>
      </Card>
    </div>
  );
}
