"use client";

// অডিট লগ (full_admin) — every unlock, role/gender change, promotion, broadcast.
// The immutable trail behind the trust model.

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { ScrollText } from "lucide-react";
import { api, type AuditEntry } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateLabelBn, dateTimeBn, toBn } from "@/lib/bn";
import { AUDIT_TARGET_LABELS_BN, auditActionLabel, auditValueBn, isFullAdmin } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { PageHeading, RoleGate } from "@/components/ui/states";

/** The record's details in words — no internal ids, codes in Bengali. */
function metaSummary(e: AuditEntry): string {
  if (!e.meta) return "—";
  const parts: string[] = [];
  const m = e.meta as Record<string, unknown>;
  if (typeof m.from === "string" && typeof m.to === "string") {
    parts.push(`${auditValueBn(m.from)} → ${auditValueBn(m.to)}`);
  } else if (typeof m.to === "string") {
    parts.push(`→ ${auditValueBn(m.to)}`);
  }
  if (typeof m.date === "string") parts.push(`তারিখ ${dateLabelBn(m.date)}`);
  if (typeof m.reason === "string" && m.reason.trim()) parts.push(`কারণ: ${m.reason}`);
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
        accessorKey: "actorName",
        header: "কে করেছেন",
        cell: (c) => (
          <span className="font-medium">{c.row.original.actorName ?? (c.row.original.actorId ? "—" : "সিস্টেম")}</span>
        ),
      },
      {
        accessorKey: "targetType",
        header: "কার / কিসের ওপর",
        cell: (c) => (
          <div className="flex flex-col">
            {c.row.original.targetName ? <span className="font-medium">{c.row.original.targetName}</span> : null}
            <span className="text-xs text-muted-foreground">
              {AUDIT_TARGET_LABELS_BN[String(c.getValue())] ?? String(c.getValue())}
            </span>
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
          title="কার্যক্রমের রেকর্ড"
          description="কে কখন কী পরিবর্তন করেছেন — দিন আনলক, ভূমিকা বা স্তর পরিবর্তন, ঘোষণা ইত্যাদি। এই রেকর্ড মোছা যায় না।"
        />
        <Card>
          <CardHeader>
            <CardTitle>সাম্প্রতিক কার্যক্রম</CardTitle>
            <CardDescription>সর্বশেষ {toBn(audit.data?.entries.length ?? 0)}টি, নতুনগুলো আগে</CardDescription>
          </CardHeader>
          <CardContent>
            <DataTable
              columns={columns}
              data={audit.data?.entries}
              loading={audit.isLoading}
              error={audit.error}
              onRetry={() => audit.refetch()}
              emptyTitle="এখনো কোনো রেকর্ড নেই"
              emptyHint="কোনো পরিবর্তন হলে এখানে দেখা যাবে।"
              csvFilename="audit-log.csv"
              csvHeaders={["সময়", "ঘটনা", "কর্তা", "লক্ষ্য", "বিবরণ"]}
              csvRow={(e) => [
                e.createdAt,
                auditActionLabel(e.action),
                e.actorName ?? (e.actorId ? "" : "সিস্টেম"),
                [e.targetName, AUDIT_TARGET_LABELS_BN[e.targetType] ?? e.targetType].filter(Boolean).join(" — "),
                metaSummary(e),
              ]}
            />
          </CardContent>
        </Card>
      </div>
    </RoleGate>
  );
}
