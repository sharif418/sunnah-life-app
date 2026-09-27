"use client";

// রেফারেল ট্রি — full_admin: the whole referral forest (built client-side from
// /api/admin/users, which carries referredById on every user). Supervisors
// (usrah_head / invigilator / daee) see their OWN downline via /api/dawah
// (RLS-scoped to their gender + tree). Expandable nodes with level + last-active.

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { ChevronDown, ChevronRight, Link2, Network, Users2 } from "lucide-react";
import { api, type DownlineNode, type User } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { LEVEL_LABELS_BN, isFullAdmin, isSupervisor } from "@/lib/labels";
import { GenderBadge, LevelBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PageHeading, RoleGate, EmptyState } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

interface TreeNode {
  user: User;
  children: TreeNode[];
  depth: number;
}

function buildForest(users: User[]): TreeNode[] {
  const byId = new Map<string, TreeNode>();
  for (const u of users) byId.set(u.id, { user: u, children: [], depth: 0 });
  const roots: TreeNode[] = [];
  for (const node of byId.values()) {
    const parent = node.user.referredById ? byId.get(node.user.referredById) : undefined;
    if (parent) {
      node.depth = parent.depth + 1;
      parent.children.push(node);
    } else {
      roots.push(node);
    }
  }
  const sortTree = (nodes: TreeNode[]) => {
    nodes.sort((a, b) => a.user.name.localeCompare(b.user.name, "bn"));
    for (const n of nodes) sortTree(n.children);
  };
  sortTree(roots);
  return roots;
}

function countTree(nodes: TreeNode[]): { total: number; maxDepth: number } {
  let total = 0;
  let maxDepth = 0;
  const walk = (list: TreeNode[]) => {
    for (const n of list) {
      total += 1;
      maxDepth = Math.max(maxDepth, n.depth + 1);
      walk(n.children);
    }
  };
  walk(nodes);
  return { total, maxDepth };
}

function TreeRow({ node, initialOpen }: { node: TreeNode; initialOpen: number }) {
  const [open, setOpen] = React.useState(node.depth < initialOpen);
  const hasChildren = node.children.length > 0;
  const inactiveDays = (() => {
    const last = new Date(node.user.lastActiveAt).getTime();
    return Math.floor((Date.now() - last) / 86_400_000);
  })();
  return (
    <li className="min-w-0">
      <div className="flex items-center gap-2 rounded-lg px-2 py-1.5 hover:bg-primary-soft/40">
        {hasChildren ? (
          <button
            type="button"
            onClick={() => setOpen((o) => !o)}
            aria-expanded={open}
            aria-label={`${node.user.name}-এর মাদউ দেখুন`}
            className="flex h-8 w-8 shrink-0 items-center justify-center rounded-md text-muted-foreground transition-colors hover:bg-card hover:text-foreground"
          >
            {open ? <ChevronDown className="h-4 w-4" aria-hidden /> : <ChevronRight className="h-4 w-4" aria-hidden />}
          </button>
        ) : (
          <span className="inline-block h-8 w-8 shrink-0" aria-hidden />
        )}
        <span className="flex min-w-0 flex-wrap items-center gap-2">
          <span className="font-semibold text-foreground">{node.user.name}</span>
          {node.user.memberCode ? (
            <span className="font-mono text-xs text-muted-foreground">{node.user.memberCode}</span>
          ) : null}
          <GenderBadge gender={node.user.gender} />
          <LevelBadge level={node.user.level} />
          {node.user.role !== "user" ? <Badge variant="outline">{node.user.role}</Badge> : null}
          <span className="text-xs text-muted-foreground">
            {inactiveDays > 7 ? (
              <span className="text-alert" title="৭ দিনের বেশি নিষ্ক্রিয়">
                ⚠ {relativeBn(node.user.lastActiveAt)}
              </span>
            ) : (
              relativeBn(node.user.lastActiveAt)
            )}
          </span>
        </span>
      </div>
      {hasChildren && open ? (
        <ul className="ml-[18px] border-l border-border pl-2" role="group" aria-label={`${node.user.name}-এর মাদউ`}>
          {node.children.map((c) => (
            <TreeRow key={c.user.id} node={c} initialOpen={initialOpen} />
          ))}
        </ul>
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

  // Full admin: the whole forest from the scoped users list.
  const users = useQuery({
    queryKey: ["admin-users", ""],
    queryFn: () => api.users(""),
    enabled: fullAdmin,
  });
  // Everyone else (daee+): own downline via the dawah dashboard.
  const dawah = useQuery({
    queryKey: ["dawah"],
    queryFn: () => api.dawah(),
    enabled: !fullAdmin && supervisor,
  });

  const forest = React.useMemo(() => (users.data ? buildForest(users.data.users) : []), [users.data]);
  const stats = React.useMemo(() => countTree(forest), [forest]);

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
              ? "পুরো দাওয়াত নেটওয়ার্ক — যে কে কাকে এনেছে, কার কোন স্তরে আছে, কে নিষ্ক্রিয় হয়ে পড়েছে।"
              : "আপনার মাদউ (রেফার করা মানুষজন) — স্তর ও সক্রিয়তা সহ।"
          }
        />

        {fullAdmin ? (
          <Card>
            <CardHeader>
              <CardTitle className="flex items-center gap-2">
                <Users2 className="h-[18px] w-[18px] text-primary" aria-hidden />
                মোট {toBn(stats.total)} জন · সর্বোচ্চ {toBn(stats.maxDepth)} ধাপ গভীর
              </CardTitle>
              <CardDescription>নামের পাশের তীর চেপে প্রতিটি শাখা খুলে দেখুন। ⚠ চিহ্ন = ৭ দিনের বেশি নিষ্ক্রিয়।</CardDescription>
            </CardHeader>
            <CardContent>
              {users.isLoading ? (
                <p className="py-8 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
              ) : users.error ? (
                <p className="py-8 text-center text-sm text-alert" role="alert">
                  তথ্য আনা যায়নি — আবার চেষ্টা করুন
                </p>
              ) : forest.length === 0 ? (
                <EmptyState title="কোনো রেফারেল নেই" hint="এখনও কেউ কাউকে রেফার করেনি।" />
              ) : (
                <ul className="space-y-0.5">
                  {forest.map((root) => (
                    <TreeRow key={root.user.id} node={root} initialOpen={1} />
                  ))}
                </ul>
              )}
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
