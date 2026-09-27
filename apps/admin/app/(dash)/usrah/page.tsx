"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useQuery } from "@tanstack/react-query";
import { Megaphone, Pin, TrendingDown, UserRound } from "lucide-react";
import type { ColumnDef } from "@tanstack/react-table";
import { api, type UsrahMember } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { ROLE_LABELS_BN } from "@/lib/labels";
import { BothGendersBadge, CategoryBadge, FScopeBadge, GenderBadge, LevelBadge, RoleBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { EmptyState, ErrorState } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

function CompletionBar({ pct }: { pct: number }) {
  const color = pct >= 70 ? "bg-success" : pct >= 40 ? "bg-gold" : "bg-alert";
  return (
    <div className="flex items-center gap-2">
      <div className="h-1.5 w-16 overflow-hidden rounded-full bg-muted" role="presentation">
        <div className={cn("h-full rounded-full", color)} style={{ width: `${Math.min(pct, 100)}%` }} />
      </div>
      <span className="text-xs font-bold tabular-nums">{toBn(pct)}%</span>
    </div>
  );
}

function useMemberColumns(): ColumnDef<UsrahMember, unknown>[] {
  return React.useMemo(
    () => [
      {
        accessorKey: "name",
        header: "সদস্য",
        cell: ({ row }) => (
          <div className="flex items-center gap-2">
            <div
              className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full bg-primary-soft text-xs font-bold text-primary"
              aria-hidden
            >
              {row.original.name.slice(0, 2)}
            </div>
            <span className="min-w-0">
              <span className="block truncate font-semibold">{row.original.name}</span>
              {row.original.memberCode ? (
                <span className="block font-mono text-[11px] text-muted-foreground">{row.original.memberCode}</span>
              ) : null}
            </span>
          </div>
        ),
      },
      {
        accessorKey: "category",
        header: "ক্যাটাগরি",
        cell: ({ row }) => <CategoryBadge category={row.original.category} />,
      },
      {
        accessorKey: "level",
        header: "স্তর",
        cell: ({ row }) => <LevelBadge level={row.original.level} />,
      },
      {
        accessorKey: "completion7d",
        header: "৭ দিনের সম্পূর্ণতা",
        cell: ({ row }) => (
          <div className="min-w-24">
            <CompletionBar pct={row.original.completion7d ?? 0} />
          </div>
        ),
      },
      {
        accessorKey: "lastActiveAt",
        header: "সর্বশেষ সক্রিয়",
        cell: ({ row }) => (
          <span
            className={cn(
              "text-xs",
              Date.now() - new Date(row.original.lastActiveAt).getTime() > 3 * 86_400_000
                ? "font-semibold text-alert"
                : "text-muted-foreground"
            )}
          >
            {relativeBn(row.original.lastActiveAt)}
          </span>
        ),
      },
    ],
    []
  );
}

function OwnUsrahView() {
  const { user } = useSession();
  const router = useRouter();
  const usrahQuery = useQuery({ queryKey: ["my-usrah"], queryFn: () => api.myUsrah() });
  const queueQuery = useQuery({ queryKey: ["review-queue"], queryFn: () => api.reviewQueue() });
  const columns = useMemberColumns();

  const reviewStatusByUser = React.useMemo(() => {
    const m = new Map<string, { status: string; streak: number | null }>();
    for (const r of queueQuery.data?.queue ?? []) {
      const prev = m.get(r.userId);
      if (r.status !== "done" || !prev) {
        m.set(r.userId, { status: r.status, streak: r.summary?.streak ?? null });
      }
    }
    return m;
  }, [queueQuery.data]);

  const usrah = usrahQuery.data?.usrah;

  if (usrahQuery.isLoading) return <TableSkeleton rows={6} cols={5} />;
  if (usrahQuery.isError)
    return <ErrorState error={usrahQuery.error} onRetry={() => usrahQuery.refetch()} />;
  if (!usrah)
    return (
      <EmptyState
        icon={<UserRound className="h-6 w-6" aria-hidden />}
        title="আপনি কোনো উসরার সদস্য নন"
        hint="উসরা ব্যবস্থাপনার জন্য অ্যাডমিন আপনাকে একটি উসরায় যুক্ত করবেন। প্রধান অ্যাডমিনের কাছে অনুরোধ করুন।"
      />
    );

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="flex-row items-center justify-between flex-wrap gap-3">
          <div>
            <CardTitle className="text-lg">{usrah.name}</CardTitle>
            <CardDescription>
              প্রধান: {usrah.headName ?? "—"} · জেলা: {usrah.district ?? "—"} · সদস্য {toBn(usrah.memberCount ?? usrah.members.length)} জন
            </CardDescription>
          </div>
          <GenderBadge gender={usrah.gender} />
        </CardHeader>
        <CardContent>
          <DataTable
            columns={columns}
            data={usrah.members}
            onRowClick={(m) => router.push(`/members/${m.id}`)}
            rowAriaLabel={(m) => `${m.name} — প্রোফাইল দেখুন`}
            emptyTitle="উসরায় কোনো সদস্য নেই"
            csvFilename={`usrah-members-${usrah.name}.csv`}
            csvHeaders={["নাম", "সদস্য কোড", "লিঙ্গ", "স্তর", "ক্যাটাগরি", "৭ দিনের সম্পূর্ণতা (%)", "সর্বশেষ সক্রিয়"]}
            csvRow={(m) => [
              m.name,
              m.memberCode ?? "",
              m.gender === "M" ? "পুরুষ" : "নারী",
              m.level,
              m.category,
              m.completion7d ?? 0,
              m.lastActiveAt,
            ]}
          />
          {queueQuery.data && queueQuery.data.queue.length > 0 ? (
            <div className="mt-4 space-y-2">
              <p className="text-sm font-semibold">এই সপ্তাহের রিভিউ অবস্থা</p>
              <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
                {usrah.members.map((m) => {
                  const st = reviewStatusByUser.get(m.id);
                  return (
                    <li
                      key={m.id}
                      className="flex items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm"
                    >
                      <Link
                        href={`/members/${m.id}`}
                        className="focus-ring min-w-0 truncate rounded font-medium hover:text-primary"
                      >
                        {m.name}
                      </Link>
                      {st ? (
                        <Badge variant={st.status === "overdue" ? "alert" : st.status === "done" ? "success" : "warning"}>
                          {st.status === "overdue" ? "বিলম্বিত" : st.status === "done" ? "সম্পন্ন" : "অপেক্ষমাণ"}
                        </Badge>
                      ) : (
                        <Badge variant="muted">এই সপ্তাহে নেই</Badge>
                      )}
                    </li>
                  );
                })}
              </ul>
            </div>
          ) : null}
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Megaphone className="h-[18px] w-[18px] text-primary" aria-hidden />
            উসরার ঘোষণাসমূহ
          </CardTitle>
          <CardDescription>উসরা প্রধান ও পরিদর্শকদের পাঠানো ঘোষণা</CardDescription>
        </CardHeader>
        <CardContent>
          {(usrahQuery.data?.announcements ?? []).length === 0 ? (
            <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
              এখনো কোনো ঘোষণা নেই
            </p>
          ) : (
            <ul className="scroll-thin max-h-96 space-y-2 overflow-y-auto">
              {usrahQuery.data!.announcements.map((a) => (
                <li key={a.id} className="rounded-md border border-border p-3">
                  <p className="flex items-center gap-1.5 text-xs text-muted-foreground">
                    {a.pinned ? <Pin className="h-3 w-3 text-gold" aria-hidden /> : null}
                    {a.authorName ?? "অ্যাডমিন"} · {relativeBn(a.createdAt)}
                  </p>
                  <p className="mt-1 text-sm leading-relaxed">{a.body}</p>
                </li>
              ))}
            </ul>
          )}
          <Link href="/broadcast" className="focus-ring mt-3 inline-block rounded text-sm font-medium text-primary hover:underline">
            নতুন ঘোষণা পাঠান →
          </Link>
        </CardContent>
      </Card>
    </div>
  );
}

function InvigilatorView() {
  const { user, fullAdmin } = useSession();
  const overview = useQuery({ queryKey: ["admin-overview"], queryFn: () => api.overview() });
  const usersQuery = useQuery({ queryKey: ["admin-users", ""], queryFn: () => api.users("") });
  const [expanded, setExpanded] = React.useState<string | null>(null);

  if (overview.isLoading) return <TableSkeleton rows={4} cols={4} />;
  if (overview.isError)
    return <ErrorState error={overview.error} onRetry={() => overview.refetch()} />;

  const usrahs = overview.data?.usrahs ?? [];

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-center gap-2">
        {fullAdmin ? <BothGendersBadge /> : user?.gender === "F" ? <FScopeBadge /> : <Badge variant="outline">পুরুষদের উসরা</Badge>}
        <span className="text-sm text-muted-foreground">
          {toBn(usrahs.length)} টি উসরা · পরিসরভুক্ত সদস্য {toBn(overview.data?.totals.users ?? 0)} জন
        </span>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>উসরা স্বাস্থ্য ড্যাশবোর্ড</CardTitle>
          <CardDescription>
            রিভিউ সম্পূর্নতা = গত ৪ সপ্তাহের সম্পন্ন রিভিউ হার · আমল = সদস্যদের গড় ৭ দিনের সম্পূর্ণতা ·
            নিষ্ক্রিয় = ৩+ দিন সক্রিয় নয়
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-2">
          {usrahs.length === 0 ? (
            <EmptyState title="আপনার পরিসরে কোনো উসরা নেই" hint="প্রধান অ্যাডমিন উসরা তৈরি করলে এখানে দেখা যাবে।" />
          ) : (
            usrahs.map((u) => {
              const members = (usersQuery.data?.users ?? []).filter((m) => m.usrahId === u.id);
              const open = expanded === u.id;
              const health = Math.round((u.reviewPct + u.avgCompletion) / 2);
              return (
                <div key={u.id} className="rounded-md border border-border">
                  <div className="grid grid-cols-1 items-center gap-3 p-4 sm:grid-cols-[1.2fr_1fr_1fr_auto]">
                    <div className="min-w-0">
                      <button
                        className="focus-ring flex items-center gap-2 rounded text-left font-semibold hover:text-primary"
                        onClick={() => setExpanded(open ? null : u.id)}
                        aria-expanded={open}
                      >
                        <TrendingDown
                          className={cn("h-4 w-4 text-muted-foreground transition-transform", open && "rotate-180")}
                          aria-hidden
                        />
                        {u.name}
                      </button>
                      <div className="mt-1 flex items-center gap-2">
                        <GenderBadge gender={u.gender} />
                        <span className="text-xs text-muted-foreground">{toBn(u.members)} সদস্য</span>
                      </div>
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground">রিভিউ সম্পূর্ণতা</p>
                      <CompletionBar pct={u.reviewPct} />
                    </div>
                    <div>
                      <p className="text-xs text-muted-foreground">গড় আমল সম্পূর্ণতা</p>
                      <CompletionBar pct={u.avgCompletion} />
                    </div>
                    <div className="flex items-center gap-2">
                      <Badge variant={health >= 70 ? "success" : health >= 45 ? "warning" : "alert"}>
                        স্বাস্থ্য {toBn(health)}
                      </Badge>
                      {u.inactiveCount > 0 ? (
                        <Badge variant="alert">{toBn(u.inactiveCount)} নিষ্ক্রিয়</Badge>
                      ) : null}
                    </div>
                  </div>
                  {open ? (
                    <div className="border-t border-border p-4">
                      {usersQuery.isLoading ? (
                        <TableSkeleton rows={3} cols={3} />
                      ) : members.length === 0 ? (
                        <p className="text-sm text-muted-foreground">সদস্য তালিকা পাওয়া যায়নি।</p>
                      ) : (
                        <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2 lg:grid-cols-3">
                          {members.map((m) => (
                            <li key={m.id}>
                              <Link
                                href={`/members/${m.id}`}
                                className="focus-ring flex min-h-11 items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm transition-colors duration-200 hover:border-primary/40 hover:bg-primary-soft/50"
                              >
                                <span className="min-w-0 truncate font-medium">{m.name}</span>
                                <span className="flex shrink-0 items-center gap-1.5">
                                  <RoleBadge role={m.role} />
                                  {Date.now() - new Date(m.lastActiveAt).getTime() > 3 * 86_400_000 ? (
                                    <Badge variant="alert">নিষ্ক্রিয়</Badge>
                                  ) : null}
                                </span>
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
    </div>
  );
}

export default function UsrahPage() {
  const { user } = useSession();
  // Heads (and any supervisor inside a usrah) get the own-usrah member view;
  // invigilators and full admins get the cross-usrah health dashboard.
  return user?.usrahId ? <OwnUsrahView /> : <InvigilatorView />;
}
