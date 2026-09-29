"use client";

// রেফারেল ট্রি — full_admin: সার্ভার-পেজিনেটেড পুরো দাওয়াত ফরেস্ট
// (GET /api/admin/referral-tree, W4h)। এক রিকোয়েস্টে এক পাতা: মূল সদস্য
// (userId ছাড়া) বা এক পিতার সরাসরি মাদউ — নোড খুললে সন্তান আসে, প্রতি নোডে
// childCount ব্যাজ, আরও থাকলে "আরও" বাটন (কার্সর পেজিনেশন)। সুপারভাইজার/দায়ী
// আগের মতোই নিজের ডাউনলাইন দেখেন (/api/dawah, RLS-স্কোপড)।

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { AlertTriangle, ChevronDown, ChevronRight, Link2, Network, Users2 } from "lucide-react";
import { api, type DownlineNode, type ReferralTreeNode } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { LEVEL_LABELS_BN, ROLE_LABELS_BN, isFullAdmin, isSupervisor } from "@/lib/labels";
import { GenderBadge, LevelBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState, PageHeading, RoleGate } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

const PAGE_LIMIT = 50;

/** এক পিতার সন্তানদের এক পাতা + "আরও" — parentId null = মূল (রেফারেকারহীন) পাতা। */
function TreeChildren({ parentId }: { parentId: string | null }) {
  const [pages, setPages] = React.useState<ReferralTreeNode[]>([]);
  const [cursor, setCursor] = React.useState<string | null>(null);
  const [remaining, setRemaining] = React.useState(0);
  const [status, setStatus] = React.useState<"loading" | "ok" | "error">("loading");
  const [loadingMore, setLoadingMore] = React.useState(false);

  // মাউন্টেই প্রথম পাতা আনে (status ইতিমধ্যেই "loading" দিয়ে শুরু)।
  React.useEffect(() => {
    let alive = true;
    api
      .referralTree({ ...(parentId ? { userId: parentId } : {}), limit: PAGE_LIMIT })
      .then((page) => {
        if (!alive) return;
        setPages(page.nodes);
        setCursor(page.nextCursor);
        setRemaining(page.remaining);
        setStatus("ok");
      })
      .catch(() => {
        if (alive) setStatus("error");
      });
    return () => {
      alive = false;
    };
  }, [parentId]);

  const loadMore = async () => {
    if (!cursor || loadingMore) return;
    setLoadingMore(true);
    try {
      const page = await api.referralTree({
        ...(parentId ? { userId: parentId } : {}),
        cursor,
        limit: PAGE_LIMIT,
      });
      setPages((prev) => [...prev, ...page.nodes]);
      setCursor(page.nextCursor);
      setRemaining(page.remaining);
    } finally {
      setLoadingMore(false);
    }
  };

  if (status === "loading") {
    return <p className="py-3 text-sm text-muted-foreground">লোড হচ্ছে…</p>;
  }
  if (status === "error") {
    return (
      <p className="py-3 text-sm text-alert" role="alert">
        তথ্য আনা যায়নি — শাখা বন্ধ করে আবার খুলুন
      </p>
    );
  }
  if (pages.length === 0) {
    return <p className="py-2 text-sm text-muted-foreground">কোনো সরাসরি মাদউ নেই।</p>;
  }

  return (
    <>
      <ul
        className="space-y-0.5"
        role="group"
        aria-label={parentId ? "সরাসরি মাদউ" : "মূল সদস্য"}
      >
        {pages.map((node) => (
          <TreeNodeRow key={node.id} node={node} />
        ))}
      </ul>
      {cursor ? (
        <Button variant="ghost" size="sm" className="mt-1" onClick={loadMore} loading={loadingMore}>
          আরও দেখুন {remaining > 0 ? `(${toBn(remaining)} জন বাকি)` : ""}
        </Button>
      ) : null}
    </>
  );
}

function TreeNodeRow({ node }: { node: ReferralTreeNode }) {
  const [open, setOpen] = React.useState(false);
  const hasChildren = node.childCount > 0;
  const inactiveDays = Math.floor((Date.now() - new Date(node.lastActiveAt).getTime()) / 86_400_000);

  return (
    <li className="min-w-0">
      <div className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-primary-soft/40">
        {hasChildren ? (
          <button
            type="button"
            onClick={() => setOpen((o) => !o)}
            aria-expanded={open}
            aria-label={`${node.name}-এর মাদউ দেখুন`}
            className="focus-ring relative flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
          >
            {open ? <ChevronDown className="h-4 w-4" aria-hidden /> : <ChevronRight className="h-4 w-4" aria-hidden />}
            {node.childCount > 99 ? null : (
              <span
                className="absolute -right-0.5 -top-0.5 flex h-4 min-w-4 items-center justify-center rounded-full bg-primary px-1 text-[9px] font-bold leading-none text-primary-foreground"
                aria-hidden
              >
                {toBn(node.childCount)}
              </span>
            )}
          </button>
        ) : (
          <span className="inline-block h-8 w-8 shrink-0" aria-hidden />
        )}
        {/* লিঙ্গ-টিন্ট: পুরুষ = সবুজ, নারী = সোনালি */}
        <span
          className={cn(
            "flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold",
            node.gender === "F"
              ? "bg-gold-soft text-gold-foreground dark:text-gold"
              : "bg-primary-soft text-primary"
          )}
          aria-hidden
        >
          {node.name.slice(0, 1)}
        </span>
        <span className="flex min-w-0 flex-wrap items-center gap-2">
          <span className="font-semibold text-foreground">{node.name}</span>
          {node.memberCode ? (
            <span className="font-mono text-xs text-muted-foreground">{node.memberCode}</span>
          ) : null}
          <LevelBadge level={node.level} />
          <GenderBadge gender={node.gender} />
          {node.role !== "user" ? (
            <Badge variant="outline">{ROLE_LABELS_BN[node.role]}</Badge>
          ) : null}
          {node.childCount > 0 ? (
            <Badge variant="muted">{toBn(node.childCount)} মাদউ</Badge>
          ) : null}
          <span className="text-xs text-muted-foreground">
            {inactiveDays > 7 ? (
              <span className="text-alert" title="৭ দিনের বেশি নিষ্ক্রিয়">
                <AlertTriangle className="mr-0.5 inline h-3 w-3" aria-hidden />
                {relativeBn(node.lastActiveAt)}
              </span>
            ) : (
              relativeBn(node.lastActiveAt)
            )}
          </span>
        </span>
      </div>
      {hasChildren && open ? (
        <div className="ml-[18px] border-l border-border pl-2">
          <TreeChildren parentId={node.id} />
        </div>
      ) : null}
    </li>
  );
}

function DownlineList({ downline }: { downline: DownlineNode[] }) {
  const groups = React.useMemo(() => {
    const byDepth = new Map<number, DownlineNode[]>();
    for (const d of downline) {
      const list = byDepth.get(d.depth) ?? [];
      list.push(d);
      byDepth.set(d.depth, list);
    }
    return [...byDepth.entries()].sort((a, b) => a[0] - b[0]);
  }, [downline]);

  return (
    <div className="space-y-4">
      {groups.map(([depth, list]) => (
        <div key={depth}>
          <p className="mb-1.5 text-xs font-bold uppercase tracking-wide text-muted-foreground">
            {toBn(depth)} ধাপ দূরের মাদউ ({toBn(list.length)} জন)
          </p>
          <ul className="space-y-1">
            {list.map((d) => (
              <li
                key={d.id}
                className="flex flex-wrap items-center gap-2 rounded-lg border border-border bg-card px-3 py-2"
              >
                <span className="font-semibold">{d.name}</span>
                {d.memberCode ? (
                  <span className="font-mono text-xs text-muted-foreground">{d.memberCode}</span>
                ) : null}
                <GenderBadge gender={d.gender} />
                <LevelBadge level={d.level} />
                <span className="ml-auto text-xs text-muted-foreground">{relativeBn(d.lastActiveAt)}</span>
              </li>
            ))}
          </ul>
        </div>
      ))}
    </div>
  );
}

export default function ReferralsPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const fullAdmin = isFullAdmin(user?.role);
  const supervisor = isSupervisor(user?.role) || user?.role === "daee";

  // Everyone else (daee+): own downline via the dawah dashboard.
  const dawah = useQuery({
    queryKey: ["dawah"],
    queryFn: () => api.dawah(),
    enabled: !fullAdmin && supervisor,
  });

  const copyLink = async (link: string) => {
    try {
      await navigator.clipboard.writeText(link);
      toast("রেফারেল লিংক কপি হয়েছে", "success");
    } catch {
      toast("কপি করা যায়নি — ম্যানুয়ালি সিলেক্ট করুন", "error");
    }
  };

  return (
    <RoleGate allow={(r) => isSupervisor(r) || r === "daee"} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<Network className="h-6 w-6" aria-hidden />}
          title="রেফারেল ট্রি"
          description={
            fullAdmin
              ? "পুরো দাওয়াত নেটওয়ার্ক — শাখা খুললে সরাসরি মাদউ আসে (পাতায় পাতায়), ব্যাজে মোট মাদউ সংখ্যা।"
              : "আপনার মাদউ (রেফার করা মানুষজন) — স্তর ও সক্রিয়তা সহ।"
          }
        />

        {fullAdmin ? (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users2 className="h-[18px] w-[18px] text-primary" aria-hidden />
                মূল সদস্য থেকে পুরো ফরেস্ট
              </CardTitle>
              <CardDescription>
                নামের পাশের তীর চেপে প্রতিটি শাখা খুলে দেখুন · ⚠ চিহ্ন = ৭ দিনের বেশি নিষ্ক্রিয় ·
                প্রতি পাতায় {toBn(PAGE_LIMIT)} জন করে, বড় শাখায় «আরও দেখুন»।
              </CardDescription>
            </CardHeader>
            <CardContent>
              <TreeChildren parentId={null} />
            </CardContent>
          </Card>
        ) : (
          <Card>
            <CardHeader>
              <CardTitle className="flex flex-wrap items-center gap-2">
                <Users2 className="h-[18px] w-[18px] text-primary" aria-hidden />
                আমার মাদউ
                {dawah.data ? (
                  <Badge variant="gold">{toBn(dawah.data.invitedCount)} জন সরাসরি</Badge>
                ) : null}
              </CardTitle>
              <CardDescription>রেফারেল স্তর-উন্নয়নের শর্তেও গণনা হয় — ৫ জনকে মুহিব্বুস সুন্নাহ স্তরে আনা।</CardDescription>
            </CardHeader>
            <CardContent className="space-y-5">
              {dawah.data?.referralLink ? (
                <div className="flex flex-wrap items-center gap-2 rounded-lg border border-gold/40 bg-gold-soft/50 px-3.5 py-3">
                  <Link2 className="h-4 w-4 text-gold-foreground" aria-hidden />
                  <code className="min-w-0 flex-1 truncate text-sm">{dawah.data.referralLink}</code>
                  <Button variant="outline" size="sm" onClick={() => copyLink(dawah.data!.referralLink)}>
                    কপি
                  </Button>
                </div>
              ) : null}
              {dawah.isLoading ? (
                <p className="py-8 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
              ) : dawah.error ? (
                <p className="py-8 text-center text-sm text-alert" role="alert">
                  তথ্য আনা যায়নি
                </p>
              ) : (dawah.data?.downline.length ?? 0) === 0 ? (
                <EmptyState
                  title="এখনও কোনো মাদউ নেই"
                  hint="আপনার রেফারেল লিংক শেয়ার করে মানুষজনকে কার্যক্রমে আনুন।"
                />
              ) : (
                <DownlineList downline={dawah.data!.downline} />
              )}
            </CardContent>
          </Card>
        )}

        {dawah.data && !fullAdmin ? (
          <p className="text-xs text-muted-foreground">
            বর্তমান স্তর: {LEVEL_LABELS_BN[dawah.data.level]} · স্তরে {toBn(dawah.data.monthsInLevel)} মাস
          </p>
        ) : null}
      </div>
    </RoleGate>
  );
}
