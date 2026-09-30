"use client";

import * as React from "react";
import Link from "next/link";
import { useRouter } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Megaphone, Pin, Plus, TrendingDown, UserCheck, UserMinus, UserPlus, UserRound, UserRoundX, UsersRound } from "lucide-react";
import type { ColumnDef } from "@tanstack/react-table";
import { api, type Gender, type UsrahJoinRequestItem, type User, type UsrahMember } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { JOIN_STATUS_LABELS_BN, ROLE_LABELS_BN } from "@/lib/labels";
import { BothGendersBadge, CategoryBadge, FScopeBadge, GenderBadge, LevelBadge, RoleBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Field, Input, Select } from "@/components/ui/input";
import { EmptyState, ErrorState } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
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

// ── W4d: full_admin join-request queue — approve (assign an usrah) / reject ─

function JoinRequestSection() {
  const { toast } = useToast();
  const qc = useQueryClient();
  const queue = useQuery({ queryKey: ["join-requests"], queryFn: () => api.joinRequests() });
  const overview = useQuery({ queryKey: ["admin-overview"], queryFn: () => api.overview() });

  const [usrahPick, setUsrahPick] = React.useState<Record<string, string>>({}); // per request
  const [rejecting, setRejecting] = React.useState<UsrahJoinRequestItem | null>(null);
  const [reason, setReason] = React.useState("");

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["join-requests"] });
    qc.invalidateQueries({ queryKey: ["admin-overview"] });
    qc.invalidateQueries({ queryKey: ["admin-users", ""] });
  };

  const approve = useMutation({
    mutationFn: (r: UsrahJoinRequestItem) => api.approveJoinRequest(r.id, usrahPick[r.id] ?? ""),
    onSuccess: (_res, r) => {
      toast(`${r.userName} — অনুরোধ অনুমোদিত, উসরায় যুক্ত হয়েছেন (অডিট লগড)`, "success");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const reject = useMutation({
    mutationFn: (r: UsrahJoinRequestItem) => api.rejectJoinRequest(r.id, reason.trim() || undefined),
    onSuccess: () => {
      toast("অনুরোধ বাতিল করা হয়েছে (অডিট লগড)", "success");
      setRejecting(null);
      setReason("");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  if (queue.isLoading) return <TableSkeleton rows={2} cols={3} />;
  if (queue.isError) return <ErrorState error={queue.error} onRetry={() => queue.refetch()} />;

  const usrahs = overview.data?.usrahs ?? [];
  const pending = (queue.data?.requests ?? []).filter((r) => r.status === "pending");
  const decided = (queue.data?.requests ?? []).filter((r) => r.status !== "pending").slice(0, 6);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <UserCheck className="h-[18px] w-[18px] text-primary" aria-hidden />
          উসরা যোগানোর অনুরোধ
        </CardTitle>
        <CardDescription>
          উসরাহীন সদস্যদের অনুরোধ — উপযুক্ত উসরা নির্বাচন করে অনুমোদন দিন (লিঙ্গ মিলতে হবে) বা কারণসহ বাতিল করুন। প্রতিটি সিদ্ধান্ত অডিট লগে সংরক্ষিত।
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {pending.length === 0 ? (
          <EmptyState title="কোনো অপেক্ষমাণ অনুরোধ নেই ✓" hint="উসরাহীন কোনো সদস্য এই মুহূর্তে যোগ হতে অনুরোধ করেননি।" />
        ) : (
          <div className="space-y-2">
            {pending.map((r) => {
              const sameGenderUsrahs = usrahs.filter((u) => u.gender === r.userGender);
              const pick = usrahPick[r.id] ?? "";
              return (
                <div key={r.id} className="rounded-md border border-border p-3">
                  <div className="flex flex-wrap items-start justify-between gap-2">
                    <div className="min-w-0">
                      <p className="flex items-center gap-2 text-sm font-semibold">
                        <UserRound className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden />
                        {r.userName}
                        <GenderBadge gender={r.userGender} />
                      </p>
                      {r.message ? (
                        <p className="mt-1 max-w-xl text-sm text-muted-foreground">{r.message}</p>
                      ) : null}
                      <p className="mt-1 text-xs text-muted-foreground">{relativeBn(r.createdAt)} অনুরোধ করেছেন</p>
                    </div>
                    <Badge variant="warning">{JOIN_STATUS_LABELS_BN[r.status]}</Badge>
                  </div>

                  {rejecting?.id === r.id ? (
                    <div className="mt-3 space-y-2 rounded-md border border-border/70 bg-muted/40 p-3">
                      <Field label="বাতিলের কারণ (ঐচ্ছিক — সদস্য দেখতে পাবেন)" htmlFor={`join-reason-${r.id}`}>
                        <Input
                          id={`join-reason-${r.id}`}
                          value={reason}
                          onChange={(e) => setReason(e.target.value)}
                          placeholder="যেমন: আপনার এলাকায় এখনো উসরা চালু হয়নি — ইনশাআল্লাহ শিগগির।"
                          aria-label="বাতিলের কারণ"
                        />
                      </Field>
                      <div className="flex items-center gap-2">
                        <Button size="sm" variant="destructive" loading={reject.isPending} onClick={() => reject.mutate(r)}>
                          <UserRoundX className="h-4 w-4" aria-hidden /> বাতিল নিশ্চিত করুন
                        </Button>
                        <Button size="sm" variant="ghost" onClick={() => { setRejecting(null); setReason(""); }}>
                          ফিরে যান
                        </Button>
                      </div>
                    </div>
                  ) : (
                    <div className="mt-3 flex flex-wrap items-end gap-2">
                      <div className="min-w-56 flex-1">
                        <Field label="যে উসরায় যুক্ত হবেন" htmlFor={`join-usrah-${r.id}`}>
                          <Select
                            id={`join-usrah-${r.id}`}
                            value={pick}
                            onChange={(e) => setUsrahPick((m) => ({ ...m, [r.id]: e.target.value }))}
                          >
                            <option value="">উসরা নির্বাচন করুন…</option>
                            {sameGenderUsrahs.map((u) => (
                              <option key={u.id} value={u.id}>
                                {u.name} {u.district ? `· ${u.district}` : ""}
                              </option>
                            ))}
                          </Select>
                        </Field>
                      </div>
                      <Button
                        size="sm"
                        disabled={!pick}
                        loading={approve.isPending && approve.variables?.id === r.id}
                        onClick={() => approve.mutate(r)}
                      >
                        <UserCheck className="h-4 w-4" aria-hidden /> অনুমোদন
                      </Button>
                      <Button size="sm" variant="outline" onClick={() => { setRejecting(r); setReason(""); }}>
                        <UserRoundX className="h-4 w-4" aria-hidden /> বাতিল
                      </Button>
                    </div>
                  )}
                </div>
              );
            })}
          </div>
        )}

        {decided.length > 0 ? (
          <div className="border-t border-border pt-3">
            <p className="mb-2 text-sm font-semibold">সাম্প্রতিক সিদ্ধান্ত</p>
            <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
              {decided.map((r) => (
                <li
                  key={r.id}
                  className="flex min-h-11 items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm"
                >
                  <span className="min-w-0 truncate">
                    {r.userName}
                    {r.usrahName ? <span className="text-muted-foreground"> → {r.usrahName}</span> : null}
                  </span>
                  <Badge variant={r.status === "approved" ? "success" : "outline"}>
                    {JOIN_STATUS_LABELS_BN[r.status] ?? r.status}
                  </Badge>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </CardContent>
    </Card>
  );
}

// ── B6: full_admin usrah management — create, assign head/invigilator, move members ─

function UsrahManageSection() {
  const { toast } = useToast();
  const qc = useQueryClient();
  const overview = useQuery({ queryKey: ["admin-overview"], queryFn: () => api.overview() });
  const usersQuery = useQuery({ queryKey: ["admin-users", ""], queryFn: () => api.users("") });

  const [name, setName] = React.useState("");
  const [gender, setGender] = React.useState<Gender>("M");
  const [district, setDistrict] = React.useState("");
  const [creating, setCreating] = React.useState(false);

  const [managing, setManaging] = React.useState<string | null>(null);
  const [headId, setHeadId] = React.useState("");
  const [invigilatorId, setInvigilatorId] = React.useState("");
  const [memberId, setMemberId] = React.useState("");

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["admin-overview"] });
    qc.invalidateQueries({ queryKey: ["admin-users", ""] });
    qc.invalidateQueries({ queryKey: ["my-usrah"] });
  };

  const create = useMutation({
    mutationFn: () => api.createUsrah({ name: name.trim(), gender, district: district.trim() || undefined }),
    onSuccess: () => {
      toast("উসরা তৈরি হয়েছে (অডিট লগড)", "success");
      setName("");
      setDistrict("");
      setCreating(false);
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const assign = useMutation({
    mutationFn: (dto: { headUserId?: string | null; invigilatorUserId?: string | null }) =>
      api.patchUsrah(managing!, dto),
    onSuccess: () => {
      toast("দায়িত্ব নির্ধারিত হয়েছে (অডিট লগড)", "success");
      setHeadId("");
      setInvigilatorId("");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const addMember = useMutation({
    mutationFn: () => api.addUsrahMember(managing!, memberId),
    onSuccess: () => {
      toast("সদস্য যুক্ত/স্থানান্তরিত হয়েছে (অডিট লগড)", "success");
      setMemberId("");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const removeMember = useMutation({
    mutationFn: (userId: string) => api.removeUsrahMember(managing!, userId),
    onSuccess: () => {
      toast("সদস্য উসরা থেকে সরানো হয়েছে (অডিট লগড)", "success");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const usrahs = overview.data?.usrahs ?? [];
  const users = usersQuery.data?.users ?? [];
  const managed = usrahs.find((u) => u.id === managing) ?? null;
  const managedMembers = managed ? users.filter((u) => u.usrahId === managed.id) : [];
  // candidates: same gender, not already in THIS usrah (moving between usrahs is allowed)
  const candidates = managed ? users.filter((u) => u.gender === managed.gender && u.usrahId !== managed.id) : [];

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <UsersRound className="h-[18px] w-[18px] text-primary" aria-hidden />
          উসরা ব্যবস্থাপনা
        </CardTitle>
        <CardDescription>
          নতুন উসরা তৈরি, প্রধান ও পরিদর্শক নির্ধারণ, সদস্য যুক্ত/সরানো — প্রতিটি পরিবর্তন লিঙ্গ-যাচাইসহ অডিট লগে সংরক্ষিত
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        {creating ? (
          <div className="grid gap-3 rounded-md border border-border p-3 sm:grid-cols-[1.5fr_1fr_1fr_auto]">
            <Field label="উসরার নাম" htmlFor="new-usrah-name">
              <Input
                id="new-usrah-name"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="যেমন: উসরা আল-হুদা"
                aria-label="উসরার নাম"
              />
            </Field>
            <Field label="লিঙ্গ" htmlFor="new-usrah-gender">
              <Select id="new-usrah-gender" value={gender} onChange={(e) => setGender(e.target.value as Gender)}>
                <option value="M">পুরুষ</option>
                <option value="F">নারী</option>
              </Select>
            </Field>
            <Field label="জেলা" htmlFor="new-usrah-district">
              <Input
                id="new-usrah-district"
                value={district}
                onChange={(e) => setDistrict(e.target.value)}
                placeholder="dhaka"
                aria-label="জেলা"
              />
            </Field>
            <div className="flex items-end gap-2">
              <Button onClick={() => create.mutate()} loading={create.isPending} disabled={!name.trim()}>
                <Plus className="h-4 w-4" aria-hidden /> তৈরি করুন
              </Button>
              <Button variant="ghost" onClick={() => setCreating(false)}>
                বাতিল
              </Button>
            </div>
          </div>
        ) : (
          <Button variant="outline" onClick={() => setCreating(true)}>
            <Plus className="h-4 w-4" aria-hidden /> নতুন উসরা
          </Button>
        )}

        {usrahs.length === 0 ? (
          <EmptyState title="কোনো উসরা নেই" hint="উপরে নতুন উসরা তৈরি করুন।" />
        ) : (
          <div className="space-y-2">
            {usrahs.map((u) => {
              const members = users.filter((m) => m.usrahId === u.id);
              const open = managing === u.id;
              return (
                <div key={u.id} className="rounded-md border border-border">
                  <div className="flex flex-wrap items-center justify-between gap-2 p-3">
                    <div className="min-w-0">
                      <p className="truncate text-sm font-semibold">{u.name}</p>
                      <p className="mt-0.5 flex items-center gap-2 text-xs text-muted-foreground">
                        <GenderBadge gender={u.gender} /> · {toBn(members.length)} সদস্য
                        {u.district ? ` · ${u.district}` : ""}
                      </p>
                    </div>
                    <Button
                      variant={open ? "secondary" : "outline"}
                      size="sm"
                      onClick={() => {
                        setManaging(open ? null : u.id);
                        setHeadId("");
                        setInvigilatorId("");
                        setMemberId("");
                      }}
                      aria-expanded={open}
                    >
                      {open ? "বন্ধ করুন" : "ব্যবস্থাপনা"}
                    </Button>
                  </div>
                  {open ? (
                    <div className="space-y-4 border-t border-border p-3">
                      <div className="grid gap-3 sm:grid-cols-2">
                        <Field
                          label="উসরা প্রধান"
                          htmlFor="usrah-head"
                          hint="একই লিঙ্গের সদস্যই প্রধান হতে পারেন; একজন প্রধান একটিই উসরা চালান"
                        >
                          <Select id="usrah-head" value={headId} onChange={(e) => setHeadId(e.target.value)}>
                            <option value="">— অপরিবর্তিত —</option>
                            {members.map((m) => (
                              <option key={m.id} value={m.id}>
                                {m.name} {m.memberCode ? `(${m.memberCode})` : ""}
                              </option>
                            ))}
                          </Select>
                        </Field>
                        <Field label="পরিদর্শক" htmlFor="usrah-invigilator" hint="একই লিঙ্গের পরিদর্শক নির্বাচন করুন">
                          <Select
                            id="usrah-invigilator"
                            value={invigilatorId}
                            onChange={(e) => setInvigilatorId(e.target.value)}
                          >
                            <option value="">— অপরিবর্তিত —</option>
                            {users
                              .filter((m) => m.gender === u.gender)
                              .map((m) => (
                                <option key={m.id} value={m.id}>
                                  {m.name} · {ROLE_LABELS_BN[m.role]}
                                </option>
                              ))}
                          </Select>
                        </Field>
                      </div>
                      {(headId || invigilatorId) && (
                        <Button
                          size="sm"
                          loading={assign.isPending}
                          onClick={() =>
                            assign.mutate({
                              ...(headId ? { headUserId: headId } : {}),
                              ...(invigilatorId ? { invigilatorUserId: invigilatorId } : {}),
                            })
                          }
                        >
                          দায়িত্ব সংরক্ষণ করুন
                        </Button>
                      )}

                      <div>
                        <p className="mb-2 text-sm font-semibold">সদস্যবৃন্দ</p>
                        {managedMembers.length ? (
                          <ul className="grid grid-cols-1 gap-1.5 sm:grid-cols-2">
                            {managedMembers.map((m) => (
                              <li
                                key={m.id}
                                className="flex items-center justify-between gap-2 rounded-md border border-border/70 px-3 py-2 text-sm"
                              >
                                <span className="min-w-0 truncate">{m.name}</span>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  aria-label={`${m.name} উসরা থেকে সরান`}
                                  disabled={removeMember.isPending}
                                  onClick={() => removeMember.mutate(m.id)}
                                >
                                  <UserMinus className="h-4 w-4 text-alert" aria-hidden />
                                </Button>
                              </li>
                            ))}
                          </ul>
                        ) : (
                          <p className="text-sm text-muted-foreground">এখনো কোনো সদস্য নেই।</p>
                        )}
                        <div className="mt-3 flex flex-wrap items-end gap-2">
                          <div className="min-w-56 flex-1">
                            <Field
                              label="সদস্য যুক্ত / স্থানান্তর"
                              htmlFor="usrah-add-member"
                              hint="একই লিঙ্গের সদস্য — অন্য উসরার সদস্য হলে স্থানান্তর হবে"
                            >
                              <Select
                                id="usrah-add-member"
                                value={memberId}
                                onChange={(e) => setMemberId(e.target.value)}
                              >
                                <option value="">নির্বাচন করুন…</option>
                                {candidates.map((m) => (
                                  <option key={m.id} value={m.id}>
                                    {m.name} {m.usrahName ? `(${m.usrahName} থেকে)` : "(উসরাহীন)"}
                                  </option>
                                ))}
                              </Select>
                            </Field>
                          </div>
                          <Button
                            size="sm"
                            variant="outline"
                            disabled={!memberId}
                            loading={addMember.isPending}
                            onClick={() => addMember.mutate()}
                          >
                            <UserPlus className="h-4 w-4" aria-hidden /> যুক্ত করুন
                          </Button>
                        </div>
                      </div>
                    </div>
                  ) : null}
                </div>
              );
            })}
          </div>
        )}
      </CardContent>
    </Card>
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
  const { user, fullAdmin } = useSession();
  // Heads (and any supervisor inside a usrah) get the own-usrah member view;
  // invigilators get the cross-usrah health dashboard. full_admin additionally
  // gets the join-request queue (W4d) + the management section (B6) on top.
  if (user?.usrahId && !fullAdmin) return <OwnUsrahView />;
  return (
    <div className="space-y-6">
      {fullAdmin ? <JoinRequestSection /> : null}
      {fullAdmin ? <UsrahManageSection /> : null}
      <InvigilatorView />
    </div>
  );
}
