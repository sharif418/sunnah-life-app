"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { ClipboardCheck } from "lucide-react";
import { api, type WeeklyReview } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateLabelBn, relativeBn, toBn, weekStartOf } from "@/lib/bn";
import { REVIEW_STATUS_LABELS_BN } from "@/lib/labels";
import { GenderBadge, LevelBadge } from "@/components/badges";
import { RatingView } from "@/components/rating";
import { ReviewDialog } from "@/components/review-dialog";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { EmptyState } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

export default function ReviewsPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const queue = useQuery({ queryKey: ["review-queue"], queryFn: () => api.reviewQueue() });
  const [filter, setFilter] = React.useState<"due" | "overdue" | "all">("due");
  const [active, setActive] = React.useState<WeeklyReview | null>(null);
  const [dialogOpen, setDialogOpen] = React.useState(false);

  const currentWeek = weekStartOf();

  const rows = React.useMemo(() => {
    const all = queue.data?.queue ?? [];
    if (filter === "overdue") return all.filter((r) => r.status === "overdue");
    if (filter === "all") return all;
    return all.filter((r) => r.status !== "done");
  }, [queue.data, filter]);

  const counts = React.useMemo(() => {
    const all = queue.data?.queue ?? [];
    return {
      due: all.filter((r) => r.status === "pending").length,
      overdue: all.filter((r) => r.status === "overdue").length,
      all: all.length,
    };
  }, [queue.data]);

  const columns = React.useMemo<ColumnDef<WeeklyReview, unknown>[]>(
    () => [
      {
        accessorKey: "user.name",
        header: "সদস্য",
        cell: ({ row }) => (
          <div className="min-w-0">
            <span className="block truncate font-semibold">{row.original.user?.name ?? "—"}</span>
            {row.original.user?.memberCode ? (
              <span className="block font-mono text-[11px] text-muted-foreground">
                {row.original.user.memberCode}
              </span>
            ) : null}
          </div>
        ),
      },
      {
        accessorKey: "user.gender",
        header: "লিঙ্গ",
        cell: ({ row }) => <GenderBadge gender={row.original.user?.gender ?? "M"} />,
        enableSorting: false,
      },
      {
        accessorKey: "user.level",
        header: "স্তর",
        cell: ({ row }) => <LevelBadge level={row.original.user?.level ?? "none"} />,
      },
      {
        accessorKey: "user.completion7d",
        header: "৭ দিনের সম্পূর্ণতা",
        cell: ({ row }) => (
          <span className="font-bold tabular-nums">{toBn(row.original.user?.completion7d ?? 0)}%</span>
        ),
      },
      {
        accessorKey: "weekStart",
        header: "সপ্তাহ",
        cell: ({ row }) => (
          <span className="text-sm">{dateLabelBn(row.original.weekStart)}</span>
        ),
      },
      {
        accessorKey: "status",
        header: "অবস্থা",
        cell: ({ row }) => (
          <Badge
            variant={
              row.original.status === "overdue" ? "alert" : row.original.status === "done" ? "success" : "warning"
            }
          >
            {REVIEW_STATUS_LABELS_BN[row.original.status] ?? row.original.status}
          </Badge>
        ),
      },
      {
        accessorKey: "rating",
        header: "রেটিং",
        cell: ({ row }) => <RatingView value={row.original.rating} />,
        enableSorting: false,
      },
      {
        accessorKey: "completedAt",
        header: "সম্পন্ন",
        cell: ({ row }) => (
          <span className="text-xs text-muted-foreground">
            {row.original.completedAt ? relativeBn(row.original.completedAt) : "—"}
          </span>
        ),
      },
    ],
    []
  );

  const openReview = (r: WeeklyReview) => {
    if (r.status === "done") {
      toast("এই রিভিউ ইতিমধ্যেই সম্পন্ন হয়েছে", "info");
      return;
    }
    setActive(r);
    setDialogOpen(true);
  };

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-3">
          <div>
            <CardTitle>রিভিউ কিউ — এই সপ্তাহে প্রত্যাশিত</CardTitle>
            <CardDescription>
              সপ্তাহ শুরু (শনিবার): {dateLabelBn(currentWeek)} · প্রতি দায়ীর জন্য সাপ্তাহিক রিভিউ
              বাধ্যতামূলক
            </CardDescription>
          </div>
          <div className="flex items-center gap-1.5" role="group" aria-label="ফিল্টার">
            {(
              [
                ["due", `বাকি ${toBn(counts.due)}`],
                ["overdue", `বিলম্বিত ${toBn(counts.overdue)}`],
                ["all", `সব ${toBn(counts.all)}`],
              ] as const
            ).map(([key, label]) => (
              <Button
                key={key}
                size="sm"
                variant={filter === key ? "default" : "outline"}
                aria-pressed={filter === key}
                onClick={() => setFilter(key)}
              >
                {label}
              </Button>
            ))}
          </div>
        </CardHeader>
        <CardContent>
          <DataTable
            columns={columns}
            data={rows}
            loading={queue.isLoading}
            error={queue.error}
            onRetry={() => queue.refetch()}
            onRowClick={openReview}
            rowAriaLabel={(r) =>
              `${r.user?.name ?? ""} — ${REVIEW_STATUS_LABELS_BN[r.status]} — রিভিউ দিন`
            }
            emptyTitle="এই সপ্তাহে কোনো রিভিউ বাকি নেই ✓"
            emptyHint="আলহামদুলিল্লাহ! পরিসরের সব সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে। পরের শনিবার নতুন রিভিউ তৈরি হবে।"
            csvFilename="review-queue.csv"
            csvHeaders={["সদস্য", "সদস্য কোড", "সপ্তাহ শুরু", "অবস্থা", "৭ দিনের সম্পূর্ণতা (%)", "রেটিং", "সম্পন্নের সময়"]}
            csvRow={(r) => [
              r.user?.name ?? "",
              r.user?.memberCode ?? "",
              r.weekStart,
              REVIEW_STATUS_LABELS_BN[r.status] ?? r.status,
              r.user?.completion7d ?? 0,
              r.rating ?? "",
              r.completedAt ?? "",
            ]}
          />
        </CardContent>
      </Card>

      {queue.data && queue.data.queue.length === 0 && !queue.isLoading ? (
        <EmptyState
          icon={<ClipboardCheck className="h-6 w-6" aria-hidden />}
          title="এই সপ্তাহে কোনো রিভিউ বাকি নেই ✓"
          hint="আপনার পরিসরে এই মুহূর্তে কোনো অপেক্ষমাণ বা বিলম্বিত সাপ্তাহিক রিভিউ নেই।"
        />
      ) : null}

      {active ? (
        <ReviewDialog
          member={{
            id: active.userId,
            name: active.user?.name ?? active.userName ?? "সদস্য",
            level: active.user?.level ?? "none",
            completion7d: active.user?.completion7d ?? null,
          }}
          review={active}
          open={dialogOpen}
          onClose={() => setDialogOpen(false)}
        />
      ) : null}
    </div>
  );
}
