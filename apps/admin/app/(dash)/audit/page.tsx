"use client";

// অডিট লগ (full_admin) — every unlock, role/gender change, promotion, broadcast.
// The immutable trail behind the trust model.

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { ScrollText } from "lucide-react";
import { api, type AuditEntry } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, toBn } from "@/lib/bn";
import { auditActionLabel, isFullAdmin } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { PageHeading, RoleGate } from "@/components/ui/states";

function metaSummary(e: AuditEntry): string {
  if (!e.meta) return "—";
  const parts: string[] = [];
  const m = e.meta as Record<string, unknown>;
  if (typeof m.userId === "string") parts.push(`user ${m.userId.slice(0, 8)}…`);
  if (typeof m.date === "string") parts.push(`date ${m.date}`);
  if (typeof m.reason === "string") parts.push(`কারণ: ${m.reason}`);
  if (typeof m.to === "string") parts.push(`→ ${m.to}`);
  if (typeof m.from === "string") parts.push(`← ${m.from}`);
  if (typeof m.usrahId === "string") parts.push(`usrah ${m.usrahId.slice(0, 8)}…`);
  if (typeof m.scope === "string") parts.push(String(m.scope));
  return parts.length ? parts.join(" · ") : "—";
}

export default function AuditPage() {
  const { user } = useSession();
  const audit = useQuery({ queryKey: ["audit"], queryFn: () => api.audit(), enabled: isFullAdmin(user?.role) });

  const columns = React.useMemo<ColumnDef<AuditEntry, unknown>[]>(
    () => [
      {
        accessorKey: "createdAt",
        header: "সময়",
        cell: (c) => (
          <span className="whitespace-nowrap text-muted-foreground">{dateTimeBn(String(c.getValue()))}</span>
        ),
      },
      {
        accessorKey: "action",
        header: "ঘটনা",
        cell: (c) => {
          const a = String(c.getValue());
          const tone =
            a.includes("unlock")
              ? "warning"
              : a.includes("change_gender")
                ? "alert"
                : a.includes("promote") || a.includes("sign") || a.includes("passed")
                  ? "success"
                  : "default";
          return <Badge variant={tone as never}>{auditActionLabel(a)}</Badge>;
        },
      },
      {
        accessorKey: "actorId",
        header: "কে করেছে",
        cell: (c) => {
          const id = c.getValue<string>();
          return id ? (
            <span className="font-mono text-xs text-muted-foreground">{id.slice(0, 10)}…</span>
          ) : (
            <span className="text-muted-foreground">সিস্টেম</span>
          );
        },
      },
      {
        accessorKey: "targetType",
        header: "লক্ষ্য",
        cell: (c) => (
          <div className="flex flex-col">
            <span className="text-xs font-semibold">{String(c.getValue())}</span>
            {c.row.original.targetId ? (
              <span className="font-mono text-[10px] text-muted-foreground">{c.row.original.targetId.slice(0, 10)}…</span>
            ) : null}
          </div>
        ),
      },
      {
        accessorKey: "meta",
        header: "বিবরণ",
        cell: (c) => <span className="text-xs text-muted-foreground">{metaSummary(c.row.original)}</span>,
      },
    ],
    [],
  );

  return (
    <RoleGate allow={(r) => r === "full_admin"} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<ScrollText className="h-6 w-6" aria-hidden />}
          title="অডিট লগ"
          description="প্রতিটি সংবেদনশীল কাজের অমোচনযোগ্য ইতিহাস — দিন আনলক, ভূমিকা/লিঙ্গ পরিবর্তন, স্তর উন্নয়ন, ঘোষণা।"
        />
        <Card>
          <CardHeader>
            <CardTitle>সাম্প্রতিক ঘটনা ({toBn(audit.data?.entries.length ?? 0)})</CardTitle>
            <CardDescription>সর্বশেষ {toBn(100)} টি এন্ট্রি — কালানুক্রমিক।</CardDescription>
          </CardHeader>
          <CardContent>
            <DataTable
              columns={columns}
              data={audit.data?.entries}
              loading={audit.isLoading}
              error={audit.error}
              onRetry={() => audit.refetch()}
              emptyTitle="কোনো অডিট এন্ট্রি নেই"
              emptyHint="এখনও কোনো সংবেদনশীল কাজ হয়নি — ভালো খবর।"
              csvFilename="audit-log.csv"
              csvHeaders={["সময়", "ঘটনা", "কর্তা", "লক্ষ্য", "বিবরণ"]}
              csvRow={(e) => [
                e.createdAt,
                auditActionLabel(e.action),
                e.actorId ?? "system",
                `${e.targetType}${e.targetId ? ` (${e.targetId})` : ""}`,
                metaSummary(e),
              ]}
            />
          </CardContent>
        </Card>
      </div>
    </RoleGate>
  );
}
