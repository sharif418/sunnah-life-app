"use client";

// কনটেন্ট ও যাচাই — every pack the apps show except the Qur'an. Editors draft,
// a reviewing scholar approves, only then it reaches the apps. This page is
// the map: what waits for me, every pack's state, and (full_admin) who is on
// the content team.

import * as React from "react";
import Link from "next/link";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowRight, BookOpen, CheckCircle2, ChevronRight, PenLine, ShieldCheck, Smartphone, Trash2, UserPlus, Users } from "lucide-react";
import { api, type CmsPackSummary, type ContentRole, type User } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { CONTENT_ROLE_LABELS_BN, GENDER_LABELS_BN } from "@/lib/labels";
import { PACK_CONFIGS, PACK_GROUPS } from "@/lib/content-packs";
import { cn } from "@/lib/utils";
import { WorkingBadge } from "@/components/content/status";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Input, Select } from "@/components/ui/input";
import { ErrorState, PageHeading } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

function Steps() {
  const steps = [
    { icon: PenLine, title: "সম্পাদক খসড়া করেন", hint: "নিজে থেকে সংরক্ষিত হয়; কী বাকি তা পাশে লেখা থাকে" },
    { icon: ShieldCheck, title: "আলেম যাচাই করেন", hint: "ঠিক কী বদলেছে দেখে অনুমোদন দেন বা মন্তব্যসহ ফেরত দেন" },
    { icon: Smartphone, title: "অ্যাপে পৌঁছায়", hint: "অনুমোদনের পরেই — প্রতিটি সংস্করণ থাকে, আগেরটিতে ফেরানো যায়" },
  ];
  return (
    <ol className="grid gap-2 sm:grid-cols-3">
      {steps.map((s, i) => (
        <li key={s.title} className="flex items-start gap-3 rounded-lg border border-border bg-card p-3">
          <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary">
            <s.icon className="h-4 w-4" aria-hidden />
          </span>
          <span className="min-w-0">
            <span className="block text-sm font-semibold">
              {toBn(i + 1)}. {s.title}
            </span>
            <span className="block text-xs leading-relaxed text-muted-foreground">{s.hint}</span>
          </span>
        </li>
      ))}
    </ol>
  );
}

function PackCard({ p }: { p: CmsPackSummary }) {
  const cfg = PACK_CONFIGS[p.pack];
  const w = p.working;
  return (
    <Link
      href={`/content/${p.pack}`}
      className="focus-ring group flex flex-col gap-2 rounded-lg border border-border bg-card p-4 shadow-card transition-colors duration-200 hover:border-primary/40 hover:bg-primary-soft/40"
    >
      <span className="flex items-start justify-between gap-2">
        <span className="text-base font-bold text-foreground">{cfg.labelBn}</span>
        <WorkingBadge status={w?.status} />
      </span>
      <span className="text-xs leading-relaxed text-muted-foreground">{cfg.descBn}</span>
      <span className="mt-auto flex items-center justify-between gap-2 pt-1 text-xs text-muted-foreground">
        <span>
          {w
            ? `সংস্করণ ${toBn(w.version)} · ${w.authorName ?? "—"} · ${relativeBn(w.updatedAt)}`
            : `অ্যাপে ${toBn(p.liveItemCount)}টি ${cfg.entryBn}${p.liveVersion ? ` · সংস্করণ ${toBn(p.liveVersion)}` : ""}`}
        </span>
        <ChevronRight className="h-4 w-4 shrink-0 transition-transform group-hover:translate-x-0.5" aria-hidden />
      </span>
    </Link>
  );
}

/** What waits for this person: drafts to review, or their drafts sent back. */
function Waiting({ packs, reviewer, me }: { packs: CmsPackSummary[]; reviewer: boolean; me: string | undefined }) {
  const toReview = reviewer ? packs.filter((p) => p.working?.status === "in_review" && p.working.authorId !== me) : [];
  const sentBack = packs.filter((p) => p.working?.status === "rejected");
  if (!toReview.length && !sentBack.length) return null;
  const row = (p: CmsPackSummary, action: string, line: string) => (
    <li key={p.pack}>
      <Link
        href={`/content/${p.pack}`}
        className="focus-ring flex min-h-14 items-center gap-3 rounded-md px-3 py-2 hover:bg-primary-soft"
      >
        <span className="min-w-0 flex-1">
          <span className="block text-sm font-semibold">{PACK_CONFIGS[p.pack].labelBn}</span>
          <span className="block truncate text-xs text-muted-foreground">{line}</span>
        </span>
        <span className="flex shrink-0 items-center gap-1 text-sm font-semibold text-primary">
          {action}
          <ArrowRight className="h-4 w-4" aria-hidden />
        </span>
      </Link>
    </li>
  );
  return (
    <Card className="border-gold/50">
      <CardHeader>
        <CardTitle className="text-base">আপনার জন্য অপেক্ষায়</CardTitle>
      </CardHeader>
      <CardContent>
        <ul className="divide-y divide-border">
          {toReview.map((p) =>
            row(
              p,
              "যাচাই করুন",
              `${p.working!.authorName ?? "—"} পাঠিয়েছেন ${relativeBn(p.working!.submittedAt ?? p.working!.updatedAt)}${p.working!.note ? ` — ${p.working!.note}` : ""}`
            )
          )}
          {sentBack.map((p) => row(p, "ঠিক করুন", `আলেমের মন্তব্য: ${p.working!.reviewNote ?? "—"}`))}
        </ul>
      </CardContent>
    </Card>
  );
}

/** full_admin: who edits and who reviews. */
function ContentTeam() {
  const { toast } = useToast();
  const qc = useQueryClient();
  const team = useQuery({ queryKey: ["cms-team"], queryFn: () => api.contentTeam() });
  const [q, setQ] = React.useState("");
  const [debounced, setDebounced] = React.useState("");
  React.useEffect(() => {
    const t = setTimeout(() => setDebounced(q.trim()), 350);
    return () => clearTimeout(t);
  }, [q]);
  const search = useQuery({
    queryKey: ["cms-team-search", debounced],
    queryFn: () => api.users(debounced),
    enabled: debounced.length >= 2,
  });
  const setRole = useMutation({
    mutationFn: ({ id, role }: { id: string; role: ContentRole | null }) => api.setContentRole(id, role),
    onSuccess: (res) => {
      toast(
        res.contentRole ? `${res.name} — ${CONTENT_ROLE_LABELS_BN[res.contentRole]}` : `${res.name} কনটেন্ট দল থেকে বাদ`,
        "success"
      );
      qc.invalidateQueries({ queryKey: ["cms-team"] });
      setQ("");
    },
    onError: (e: Error) => toast(e.message, "error"),
  });
  const members = team.data?.editors ?? [];
  const inTeam = new Set(members.map((m) => m.id));
  const found = (search.data?.users ?? []).filter((u: User) => !inTeam.has(u.id)).slice(0, 6);

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          <Users className="h-5 w-5 text-primary" aria-hidden />
          কনটেন্ট দল
        </CardTitle>
        <CardDescription>
          সম্পাদক খসড়া করেন ও যাচাইয়ে পাঠান; যাচাইকারী আলেম অনুমোদন, ফেরত ও আগের সংস্করণে ফেরাতে পারেন। কেউ নিজের লেখা
          নিজে অনুমোদন করতে পারেন না — প্রতিটি পরিবর্তনে দুজন। তাঁরা সাধারণ সদস্য হলেও অ্যাডমিনে শুধু কনটেন্ট অংশটি দেখবেন।
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {team.isError ? <ErrorState error={team.error} onRetry={() => team.refetch()} /> : null}
        {members.length ? (
          <ul className="divide-y divide-border rounded-lg border border-border">
            {members.map((m) => (
              <li key={m.id} className="flex flex-wrap items-center gap-3 px-3 py-2">
                <span className="min-w-0 flex-1">
                  <span className="block text-sm font-semibold">{m.name}</span>
                  <span className="block text-xs text-muted-foreground">
                    {m.phone ? toBn(m.phone) : "—"} · {GENDER_LABELS_BN[m.gender]}
                  </span>
                </span>
                <Select
                  aria-label={`${m.name}-এর ভূমিকা`}
                  className="h-10 w-48"
                  value={m.contentRole}
                  disabled={setRole.isPending}
                  onChange={(e) => setRole.mutate({ id: m.id, role: e.target.value as ContentRole })}
                >
                  <option value="editor">{CONTENT_ROLE_LABELS_BN.editor}</option>
                  <option value="reviewer">{CONTENT_ROLE_LABELS_BN.reviewer}</option>
                </Select>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-10 w-10 text-alert hover:bg-alert-soft hover:text-alert"
                  aria-label={`${m.name}-কে দল থেকে বাদ দিন`}
                  disabled={setRole.isPending}
                  onClick={() => setRole.mutate({ id: m.id, role: null })}
                >
                  <Trash2 className="h-4 w-4" aria-hidden />
                </Button>
              </li>
            ))}
          </ul>
        ) : team.isLoading ? (
          <div className="skeleton h-16" />
        ) : (
          <p className="rounded-lg border border-dashed border-border p-4 text-sm text-muted-foreground">
            এখনো কেউ নেই — নিচে নাম বা ফোন নম্বর দিয়ে খুঁজে যোগ করুন। অন্তত একজন যাচাইকারী আলেম লাগবে।
          </p>
        )}
        <div className="space-y-2">
          <label htmlFor="team-search" className="flex items-center gap-2 text-sm font-medium">
            <UserPlus className="h-4 w-4 text-primary" aria-hidden />
            দলে যোগ করুন
          </label>
          <Input id="team-search" placeholder="নাম বা ফোন নম্বর…" value={q} onChange={(e) => setQ(e.target.value)} />
          {debounced.length >= 2 ? (
            search.isLoading ? (
              <div className="skeleton h-12" />
            ) : found.length ? (
              <ul className="divide-y divide-border rounded-lg border border-border">
                {found.map((u) => (
                  <li key={u.id} className="flex flex-wrap items-center gap-2 px-3 py-2">
                    <span className="min-w-0 flex-1 text-sm">
                      <span className="font-semibold">{u.name}</span>{" "}
                      <span className="text-xs text-muted-foreground">{u.phone ? toBn(u.phone) : ""}</span>
                    </span>
                    <Button size="sm" variant="outline" disabled={setRole.isPending} onClick={() => setRole.mutate({ id: u.id, role: "editor" })}>
                      সম্পাদক
                    </Button>
                    <Button size="sm" variant="outline" disabled={setRole.isPending} onClick={() => setRole.mutate({ id: u.id, role: "reviewer" })}>
                      যাচাইকারী আলেম
                    </Button>
                  </li>
                ))}
              </ul>
            ) : (
              <p className="text-xs text-muted-foreground">কাউকে পাওয়া যায়নি</p>
            )
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}

export default function ContentOverviewPage() {
  const { user, fullAdmin, contentReviewer } = useSession();
  const overview = useQuery({ queryKey: ["cms-overview"], queryFn: () => api.cmsOverview() });
  const byKey = new Map((overview.data?.packs ?? []).map((p) => [p.pack, p]));

  return (
    <div className="space-y-6">
      <PageHeading
        icon={<BookOpen className="h-6 w-6" aria-hidden />}
        title="কনটেন্ট ও যাচাই"
        description="আযকার, দোয়া, সুন্নাহ থেকে কোর্স ও কুইজ — কুরআন ছাড়া অ্যাপের সব কনটেন্ট। আলেমের যাচাইয়ের পরেই অ্যাপে যায়।"
      />
      <Steps />

      {overview.isError ? (
        <ErrorState error={overview.error} onRetry={() => overview.refetch()} />
      ) : overview.isLoading ? (
        <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
          {Array.from({ length: 6 }).map((_, i) => (
            <div key={i} className="skeleton h-32" />
          ))}
        </div>
      ) : (
        <>
          <Waiting packs={overview.data!.packs} reviewer={contentReviewer} me={user?.id} />
          {!overview.data!.packs.some((p) => p.working) ? (
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
              <CheckCircle2 className="h-4 w-4 text-primary" aria-hidden />
              কোনো খসড়া নেই — অ্যাপে যা আছে সব প্রকাশিত ও যাচাই করা
            </p>
          ) : null}
          {PACK_GROUPS.map((g) => (
            <section key={g.labelBn} className="space-y-2">
              <h2 className="text-sm font-semibold text-muted-foreground">{g.labelBn}</h2>
              <div className={cn("grid gap-3 sm:grid-cols-2 xl:grid-cols-3")}>
                {g.packs.map((k) => {
                  const p = byKey.get(k);
                  return p ? <PackCard key={k} p={p} /> : null;
                })}
              </div>
            </section>
          ))}
          {!contentReviewer ? (
            <p className="text-xs text-muted-foreground">
              আপনি সম্পাদক — খসড়া করে যাচাইয়ে পাঠাতে পারবেন; অনুমোদন দেবেন যাচাইকারী আলেম।
            </p>
          ) : null}
        </>
      )}

      {fullAdmin ? <ContentTeam /> : null}
    </div>
  );
}
