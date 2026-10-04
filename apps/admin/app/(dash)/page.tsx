"use client";

import * as React from "react";
import Link from "next/link";
import { useQuery } from "@tanstack/react-query";
import {
  Activity,
  BookOpenCheck,
  ChevronRight,
  Headset,
  MessageSquareText,
  ClipboardCheck,
  FileCheck2,
  ListTodo,
  Radio,
  TrendingUp,
  UserRound,
  Users,
  UserRoundCheck,
} from "lucide-react";
import { api, type InvigilatorHealthRow, type UsrahHealth } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn, relativeBn, todayLineBn, bdToday, dateLabelBn } from "@/lib/bn";
import { auditActionLabel, pctBn, ROLE_LABELS_BN } from "@/lib/labels";
import { BothGendersBadge, FScopeBadge, GenderBadge, RoleBadge } from "@/components/badges";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { CardSkeleton, TableSkeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/ui/states";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";

function StatCard({
  label,
  value,
  icon: Icon,
  hint,
  href,
}: {
  label: string;
  value: number | null;
  icon: React.ComponentType<{ className?: string }>;
  hint?: string;
  href?: string;
}) {
  const body = (
    <Card className="h-full transition-shadow duration-200 hover:shadow-lifted">
      <CardContent className="flex items-center gap-4 pt-5">
        <div className="flex h-12 w-12 shrink-0 items-center justify-center rounded-md bg-primary-soft text-primary">
          <Icon className="h-6 w-6" aria-hidden />
        </div>
        <div className="min-w-0">
          <p className="text-xs font-medium text-muted-foreground">{label}</p>
          <p className="text-2xl font-bold leading-tight text-foreground">
            {value === null ? "…" : toBn(value)}
          </p>
          {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
        </div>
      </CardContent>
    </Card>
  );
  return href ? (
    <Link href={href} className="focus-ring block rounded-lg" aria-label={`${label} দেখুন`}>
      {body}
    </Link>
  ) : (
    body
  );
}

function HealthBar({ pct, label }: { pct: number; label: string }) {
  const color = pct >= 70 ? "bg-success" : pct >= 40 ? "bg-gold" : "bg-alert";
  return (
    <div className="flex min-w-28 flex-col gap-1" aria-label={`${label}: ${pctBn(pct)}`}>
      <div className="flex items-baseline justify-between text-xs">
        <span className="text-muted-foreground">{label}</span>
        <span className="font-bold tabular-nums text-foreground">{pctBn(pct)}</span>
      </div>
      <div className="h-1.5 overflow-hidden rounded-full bg-muted" role="presentation">
        <div className={cn("h-full rounded-full", color)} style={{ width: `${Math.min(pct, 100)}%` }} />
      </div>
    </div>
  );
}

function UsrahHealthCard({ usrahs, fullAdmin }: { usrahs: UsrahHealth[] | undefined; fullAdmin: boolean }) {
  const { data: usersData, isLoading: usersLoading } = useQuery({
    queryKey: ["admin-users", ""],
    queryFn: () => api.users(""),
    enabled: usrahs !== undefined,
  });

  const [expanded, setExpanded] = React.useState<string | null>(null);

  if (usrahs === undefined) return <TableSkeleton rows={3} cols={4} />;

  return (
    <Card>
      <CardHeader className="flex-row items-center justify-between">
        <div>
          <CardTitle>উসরার স্বাস্থ্য তালিকা</CardTitle>
          <CardDescription>
            রিভিউ সম্পূর্ণতা · গড় আমল সম্পূর্ণতা · নিষ্ক্রিয় সদস্য — সারিতে ক্লিক করে সদস্য দেখুন
          </CardDescription>
        </div>
        {fullAdmin ? <BothGendersBadge /> : null}
      </CardHeader>
      <CardContent className="space-y-2">
        {usrahs.length === 0 ? (
          <p className="rounded-md border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
            আপনার পরিসরে কোনো উসরা নেই।
          </p>
        ) : (
          usrahs.map((u) => {
            const members = (usersData?.users ?? []).filter((m) => m.usrahId === u.id);
            const open = expanded === u.id;
            return (
              <div key={u.id} className="rounded-md border border-border bg-card">
                <button
                  className="focus-ring grid w-full grid-cols-1 items-center gap-3 rounded-md p-3.5 text-left transition-colors duration-200 hover:bg-primary-soft/40 sm:grid-cols-[1fr_auto_auto_auto]"
                  onClick={() => setExpanded(open ? null : u.id)}
                  aria-expanded={open}
                >
                  <span className="flex items-center gap-2">
                    <ChevronRight
                      className={cn("h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-200", open && "rotate-90")}
                      aria-hidden
                    />
                    <span className="min-w-0">
                      <span className="block truncate font-semibold text-foreground">{u.name}</span>
                      <span className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
                        <GenderBadge gender={u.gender} />
                        <span>{toBn(u.members)} সদস্য</span>
                      </span>
                    </span>
                  </span>
                  <HealthBar pct={u.reviewPct} label="রিভিউ" />
                  <HealthBar pct={u.avgCompletion} label="আমল" />
                  <span className="flex items-center gap-2 justify-self-start sm:justify-self-end">
                    {u.inactiveCount > 0 ? (
                      <Badge variant="alert" aria-label={`${toBn(u.inactiveCount)} জন নিষ্ক্রিয়`}>
                        {toBn(u.inactiveCount)} নিষ্ক্রিয়
                      </Badge>
                    ) : (
                      <Badge variant="success">সব সক্রিয়</Badge>
                    )}
                  </span>
                </button>
                {open ? (
                  <div className="border-t border-border p-3.5">
                    {usersLoading ? (
                      <TableSkeleton rows={3} cols={3} />
                    ) : members.length === 0 ? (
                      <p className="text-sm text-muted-foreground">এই উসরার সদস্য তালিকা লোড করা যায়নি।</p>
                    ) : (
                      <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2 lg:grid-cols-3">
                        {members.map((m) => (
                          <li key={m.id}>
                            <Link
                              href={`/members/${m.id}`}
                              className="focus-ring flex min-h-11 items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm transition-colors duration-200 hover:border-primary/40 hover:bg-primary-soft/50"
                            >
                              <span className="min-w-0 truncate font-medium">{m.name}</span>
                              <RoleBadge role={m.role} />
                            </Link>
                          </li>
                        ))}
                      </ul>
                    )}
                  </div>
                ) : null}
              </div>
            );
          })
        )}
      </CardContent>
    </Card>
  );
}

/** W4h — পরিদর্শকের তত্ত্বাবধান স্বাস্থ্য: score = 0.35·রিভিউ + 0.35·আমল +
 *  0.20·সক্রিয়তা + 0.10·সময়মতো (বিলম্বিত রিভিউ লাল পতাকা)। full_admin সব
 *  পরিদর্শকের তালিকা পান; পরিদর্শক শুধু নিজের স্কোর। */
function ScoreBadge({ score }: { score: number | null }) {
  if (score === null) return <Badge variant="muted">পরিসর খালি</Badge>;
  if (score >= 70) return <Badge variant="success">স্কোর {toBn(score)}</Badge>;
  if (score >= 40) return <Badge variant="warning">স্কোর {toBn(score)}</Badge>;
  return <Badge variant="alert">স্কোর {toBn(score)}</Badge>;
}

function HealthComponents({ h }: { h: InvigilatorHealthRow }) {
  return (
    <div className="grid grid-cols-2 gap-x-6 gap-y-3 sm:grid-cols-4">
      <HealthBar pct={h.reviewPct ?? 0} label="সাপ্তাহিক রিভিউ (৩৫%)" />
      <HealthBar pct={h.amalPct ?? 0} label="আমল সম্পূর্ণতা (৩৫%)" />
      <HealthBar pct={h.activePct ?? 0} label="সক্রিয় সদস্য (২০%)" />
      <div className="flex min-w-28 flex-col gap-1" aria-label={`বিলম্বিত রিভিউ: ${toBn(h.overdueCount)}`}>
        <span className="text-xs text-muted-foreground">বিলম্বিত রিভিউ (১০%)</span>
        <span
          className={cn(
            "text-sm font-bold tabular-nums",
            h.overdueCount > 0 ? "text-alert" : "text-success"
          )}
        >
          {h.overdueCount > 0 ? `${toBn(h.overdueCount)}টি` : "নেই ✓"}
        </span>
      </div>
    </div>
  );
}

function InvigilatorHealthSection({ role }: { role: string }) {
  const health = useQuery({
    queryKey: ["invigilator-health"],
    queryFn: () => api.invigilatorHealth(),
    enabled: role === "invigilator" || role === "full_admin",
  });

  if (!health.data) return null;
  const rows = health.data.invigilators;
  if (rows.length === 0) return null;

  // পরিদর্শক নিজে — একটাই কার্ড, নিজের স্কোর।
  if (role === "invigilator") {
    const self = rows[0];
    return (
      <Card>
        <CardHeader>
          <CardTitle className="flex flex-wrap items-center gap-2">
            <Activity className="h-[18px] w-[18px] text-primary" aria-hidden />
            আমার তত্ত্বাবধান স্বাস্থ্য
            <ScoreBadge score={self.score} />
          </CardTitle>
          <CardDescription>
            রিভিউ, আমল, সক্রিয়তা ও সময়মতো কাজের ভিত্তিতে — আপনার পরিসরের {toBn(self.memberCount)} সদস্য
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          {self.score === null ? (
            <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
              আপনার পরিসরে এখনো কোনো উসরা নেই।
            </p>
          ) : (
            <>
              <HealthComponents h={self} />
              <p className="text-xs leading-relaxed text-muted-foreground">
                গত ৩০ দিনে মূল্যায়ন {toBn(self.assessments30d)}টি
                {self.unsignedAssessments > 0 ? ` · অস্বাক্ষরিত ${toBn(self.unsignedAssessments)}টি` : " · সব স্বাক্ষরিত"}
                {self.usrahNames.length > 0 ? ` · উসরা: ${self.usrahNames.join(" · ")}` : ""}
              </p>
            </>
          )}
        </CardContent>
      </Card>
    );
  }

  // full_admin — প্রতি পরিদর্শকের সারি, খুললে উপাদানগুলো।
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Activity className="h-[18px] w-[18px] text-primary" aria-hidden />
          পরিদর্শকদের তত্ত্বাবধান স্বাস্থ্য ({toBn(rows.length)} জন)
        </CardTitle>
        <CardDescription>রিভিউ, আমল, সক্রিয়তা ও সময়মতো কাজের ভিত্তিতে — বিস্তারিত দেখতে সারিতে চাপুন</CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        {rows.map((h) => (
          <InvigilatorHealthRowView key={h.id} h={h} />
        ))}
      </CardContent>
    </Card>
  );
}

function InvigilatorHealthRowView({ h }: { h: InvigilatorHealthRow }) {
  const [open, setOpen] = React.useState(false);
  return (
    <div className="rounded-md border border-border bg-card">
      <button
        className="focus-ring grid w-full grid-cols-1 items-center gap-3 rounded-md p-3.5 text-left transition-colors duration-200 hover:bg-primary-soft/40 sm:grid-cols-[1fr_auto_auto]"
        onClick={() => setOpen((o) => !o)}
        aria-expanded={open}
      >
        <span className="flex min-w-0 items-center gap-2">
          <ChevronRight
            className={cn("h-4 w-4 shrink-0 text-muted-foreground transition-transform duration-200", open && "rotate-90")}
            aria-hidden
          />
          <span className="min-w-0">
            <span className="block truncate font-semibold text-foreground">{h.name}</span>
            <span className="mt-0.5 flex flex-wrap items-center gap-1.5 text-xs text-muted-foreground">
              <GenderBadge gender={h.gender} />
              <span>{toBn(h.memberCount)} সদস্য</span>
              {h.usrahNames.length > 0 ? <span>· {toBn(h.usrahNames.length)} উসরা</span> : null}
            </span>
          </span>
        </span>
        {h.unsignedAssessments > 0 ? (
          <Badge variant="alert">অস্বাক্ষরিত {toBn(h.unsignedAssessments)}</Badge>
        ) : null}
        <ScoreBadge score={h.score} />
      </button>
      {open ? (
        <div className="space-y-3 border-t border-border p-3.5">
          {h.score === null ? (
            <p className="text-sm text-muted-foreground">এই পরিদর্শকের পরিসরে কোনো উসরা নেই।</p>
          ) : (
            <HealthComponents h={h} />
          )}
          <p className="text-xs leading-relaxed text-muted-foreground">
            গত ৩০ দিনে মূল্যায়ন {toBn(h.assessments30d)}টি · অস্বাক্ষরিত {toBn(h.unsignedAssessments)}টি
            {h.usrahNames.length > 0 ? ` · উসরা: ${h.usrahNames.join(" · ")}` : ""}
          </p>
        </div>
      ) : null}
    </div>
  );
}

interface Queue {
  n: number | null | undefined;
  label: string;
  done: string;
  href: string;
  icon: React.ComponentType<{ className?: string }>;
}

/** One waiting queue: the count, what it is, where to go. */
function TodoTile({ q }: { q: Queue }) {
  const Icon = q.icon;
  return (
    <Link
      href={q.href}
      className="focus-ring flex min-h-20 items-center gap-3 rounded-lg border border-gold/60 bg-gold-soft p-4 transition-shadow duration-200 hover:shadow-lifted"
    >
      <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-md bg-gold text-gold-foreground">
        <Icon className="h-5 w-5" aria-hidden />
      </div>
      <div className="min-w-0 flex-1">
        <p className="text-2xl font-bold leading-tight tabular-nums">{toBn(q.n ?? 0)}</p>
        <p className="text-sm font-medium">{q.label}</p>
      </div>
      <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
    </Link>
  );
}

/** "আজকের কাজ": what is waiting comes first as cards; queues with nothing
 * waiting collapse into one quiet line of ticks instead of five empty boxes. */
function TodaysWork({ fullAdmin }: { fullAdmin: boolean }) {
  const q = useQuery({ queryKey: ["admin-queues"], queryFn: () => api.queues(), refetchInterval: 60_000 });
  const d = q.data;
  const queues: Queue[] = [
    { n: d?.reviews, label: "সাপ্তাহিক রিভিউ বাকি", done: "রিভিউ", href: "/reviews", icon: ClipboardCheck },
    ...(fullAdmin
      ? [
          { n: d?.joinRequests, label: "উসরায় যোগ দেওয়ার অনুরোধ", done: "উসরার অনুরোধ", href: "/usrah", icon: Users },
          { n: d?.support, label: "সাপোর্ট বার্তার উত্তর বাকি", done: "সাপোর্ট", href: "/support", icon: Headset },
          { n: d?.masala, label: "মাসআলার উত্তর বাকি", done: "মাসআলা", href: "/masala", icon: BookOpenCheck },
          { n: d?.feedback, label: "নতুন মতামত", done: "মতামত", href: "/feedback", icon: MessageSquareText },
        ]
      : []),
  ];
  const waiting = queues.filter((x) => (x.n ?? 0) > 0);
  const clear = queues.filter((x) => !((x.n ?? 0) > 0));
  return (
    <section aria-label="আজকের কাজ" className="space-y-3">
      <h3 className="text-base font-bold">আজকের কাজ</h3>
      {q.isLoading ? (
        <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
          <div className="skeleton h-20" />
          <div className="skeleton h-20" />
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 gap-3 sm:grid-cols-2 xl:grid-cols-3">
            {waiting.map((x) => (
              <TodoTile key={x.href} q={x} />
            ))}
            <Link
              href="/assessments"
              className="focus-ring flex min-h-20 items-center gap-3 rounded-lg border border-dashed border-border bg-card p-4 transition-shadow duration-200 hover:shadow-lifted"
            >
              <div className="flex h-11 w-11 shrink-0 items-center justify-center rounded-md bg-primary-soft text-primary">
                <FileCheck2 className="h-5 w-5" aria-hidden />
              </div>
              <div className="min-w-0 flex-1">
                <p className="text-sm font-semibold">নতুন মূল্যায়ন নিন</p>
                <p className="text-xs text-muted-foreground">ফরযে আইন মূল্যায়ন ফর্ম</p>
              </div>
              <ChevronRight className="h-4 w-4 shrink-0 text-muted-foreground" aria-hidden />
            </Link>
          </div>
          {clear.length ? (
            <p className="flex flex-wrap items-center gap-x-3 gap-y-1 text-sm text-muted-foreground">
              <span className="font-semibold text-success">✓ কিছু বাকি নেই:</span>
              {clear.map((x) => (
                <Link key={x.href} href={x.href} className="focus-ring rounded hover:text-primary hover:underline">
                  {x.done}
                </Link>
              ))}
            </p>
          ) : null}
        </>
      )}
    </section>
  );
}

export default function OverviewPage() {
  const { user, fullAdmin } = useSession();

  const overview = useQuery({
    queryKey: ["admin-overview"],
    queryFn: () => api.overview(),
    enabled: !!user,
  });
  const queue = useQuery({
    queryKey: ["review-queue"],
    queryFn: () => api.reviewQueue(),
    enabled: !!user,
  });

  const pending = (queue.data?.queue ?? []).filter((r) => r.status === "pending").length;
  const overdue = (queue.data?.queue ?? []).filter((r) => r.status === "overdue").length;
  const wsToday = bdToday();

  return (
    <div className="space-y-6">
      <section className="flex flex-col gap-1" aria-label="শুভেচ্ছা">
        <h2 className="text-xl font-bold sm:text-2xl">আসসালামু আলাইকুম, {user?.name}</h2>
        <p className="text-sm text-muted-foreground">
          {todayLineBn()} · {user ? ROLE_LABELS_BN[user.role] : ""} প্যানেল
          {user?.role === "invigilator" && user.gender === "F" ? " — " : ""}
        </p>
        <div className="mt-1 flex flex-wrap items-center gap-2">
          {fullAdmin ? (
            <BothGendersBadge />
          ) : user?.gender === "F" ? (
            <FScopeBadge />
          ) : (
            <Badge variant="outline">পুরুষ পরিসরের তথ্য</Badge>
          )}
        </div>
      </section>

      <TodaysWork fullAdmin={!!fullAdmin} />

      {overview.isError ? (
        <ErrorState error={overview.error} onRetry={() => overview.refetch()} />
      ) : (
        <section className="grid grid-cols-1 gap-4 sm:grid-cols-3" aria-label="সারসংক্ষেপ">
          <StatCard
            label="পরিসরের সদস্য"
            value={overview.data?.totals.users ?? null}
            icon={UserRound}
            hint="আপনার তত্ত্বাবধানের পরিসরে"
          />
          <StatCard label="দায়ী" value={overview.data?.totals.daees ?? null} icon={UserRoundCheck} hint="সক্রিয় দাওয়াত কর্মী" />
          <StatCard label="উসরা" value={overview.data?.totals.usrahs ?? null} icon={Users} hint="তত্ত্বাবধানের উসরা" />
        </section>
      )}

      {/* W4h — পরিদর্শক স্ব-স্কোর / প্রধান অ্যাডমিনের পরিদর্শক তালিকা */}
      {user && (user.role === "invigilator" || user.role === "full_admin") ? (
        <InvigilatorHealthSection role={user.role} />
      ) : null}

      <div className="grid grid-cols-1 gap-6 xl:grid-cols-[1.6fr_1fr]">
        {overview.isError ? (
          <ErrorState error={overview.error} onRetry={() => overview.refetch()} />
        ) : overview.isLoading ? (
          <div className="space-y-3">
            <div className="skeleton h-10 w-72" />
            <div className="skeleton h-40" />
          </div>
        ) : (
          <UsrahHealthCard usrahs={overview.data?.usrahs} fullAdmin={!!fullAdmin} />
        )}

        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <ClipboardCheck className="h-[18px] w-[18px] text-primary" aria-hidden />
                এই সপ্তাহের রিভিউ
              </CardTitle>
              <CardDescription>সপ্তাহ শুরু {dateLabelBn(wsToday)}</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              {queue.isLoading ? (
                <div className="space-y-2">
                  <div className="skeleton h-9" />
                  <div className="skeleton h-9" />
                </div>
              ) : queue.isError ? (
                <ErrorState error={queue.error} onRetry={() => queue.refetch()} className="py-4" />
              ) : queue.data && queue.data.queue.length > 0 ? (
                <>
                  <div className="flex items-center gap-3">
                    <Badge variant={pending > 0 ? "warning" : "success"}>
                      অপেক্ষমাণ {toBn(pending)}
                    </Badge>
                    <Badge variant={overdue > 0 ? "alert" : "muted"}>বিলম্বিত {toBn(overdue)}</Badge>
                  </div>
                  <ul className="space-y-1.5">
                    {queue.data.queue.slice(0, 5).map((r) => (
                      <li key={r.id} className="flex items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm">
                        <Link href={`/members/${r.userId}`} className="focus-ring min-w-0 truncate rounded font-medium hover:text-primary">
                          {r.user?.name ?? r.userName ?? "সদস্য"}
                        </Link>
                        <Badge variant={r.status === "overdue" ? "alert" : r.status === "done" ? "success" : "warning"}>
                          {r.status === "overdue" ? "বিলম্বিত" : r.status === "done" ? "সম্পন্ন" : "অপেক্ষমাণ"}
                        </Badge>
                      </li>
                    ))}
                  </ul>
                  {queue.data.queue.length > 5 ? (
                    <Link href="/reviews" className="focus-ring inline-block rounded text-sm font-medium text-primary hover:underline">
                      সব {toBn(queue.data.queue.length)}টি রিভিউ দেখুন →
                    </Link>
                  ) : null}
                </>
              ) : (
                <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
                  এই সপ্তাহে কোনো রিভিউ বাকি নেই ✓
                </p>
              )}
              <Link
                href="/reviews"
                className="focus-ring flex min-h-11 items-center justify-center gap-2 rounded-md bg-primary px-4 text-sm font-semibold text-primary-foreground transition-colors duration-200 hover:bg-primary-deep"
              >
                রিভিউ কিউতে যান
                <ChevronRight className="h-4 w-4" aria-hidden />
              </Link>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <TrendingUp className="h-[18px] w-[18px] text-primary" aria-hidden />
                সাম্প্রতিক কার্যক্রম
              </CardTitle>
              <CardDescription>
                {fullAdmin ? "সব অডিট এন্ট্রি" : "আপনার সকল কার্যক্রমের অডিট রেকর্ড"}
              </CardDescription>
            </CardHeader>
            <CardContent>
              {overview.isLoading ? (
                <div className="space-y-2">
                  <div className="skeleton h-4 w-full" />
                  <div className="skeleton h-4 w-4/5" />
                  <div className="skeleton h-4 w-3/5" />
                </div>
              ) : overview.data && overview.data.recentAudit.length > 0 ? (
                <ul className="space-y-2.5">
                  {overview.data.recentAudit.slice(0, 6).map((a) => (
                    <li key={a.id} className="flex items-start gap-2 text-sm">
                      <Badge variant="muted" className="shrink-0">
                        {auditActionLabel(a.action)}
                      </Badge>
                      <span className="min-w-0 flex-1">
                        <span className="block truncate text-xs text-muted-foreground">
                          {a.actorName ?? "সিস্টেম"} · {relativeBn(a.createdAt)}
                        </span>
                      </span>
                    </li>
                  ))}
                </ul>
              ) : (
                <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
                  এখনো কোনো কার্যক্রম রেকর্ড হয়নি
                </p>
              )}
              {fullAdmin ? (
                <Link href="/audit" className="focus-ring mt-3 inline-block rounded text-sm font-medium text-primary hover:underline">
                  সম্পূর্ণ অডিট লগ →
                </Link>
              ) : null}
            </CardContent>
          </Card>

        </div>
      </div>
    </div>
  );
}
