"use client";

// সাপোর্ট ইনবক্স (full_admin) — W4d: সদস্য ↔ অ্যাডমিন লাইভ আলাপনা।
// Thread list with status filter + click-through dialog with the full message
// history, reply box and close button. Everything runs through
// /api/admin/support (full_admin-only server-side; RoleGate is UX defense).

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { CheckCheck, Inbox, Send, UserRound } from "lucide-react";
import { api, type SupportThreadItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { SUPPORT_STATUS_LABELS_BN } from "@/lib/labels";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Dialog } from "@/components/ui/dialog";
import { Textarea } from "@/components/ui/input";
import { PageHeading, RoleGate } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

function StatusBadge({ status }: { status: string }) {
  const variant = status === "open" ? "warning" : status === "answered" ? "success" : "outline";
  return <Badge variant={variant}>{SUPPORT_STATUS_LABELS_BN[status] ?? status}</Badge>;
}

/** Thread view: full history + reply box + close. */
function ThreadDialog({
  thread,
  open,
  onClose,
}: {
  thread: SupportThreadItem | null;
  open: boolean;
  onClose: () => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [reply, setReply] = React.useState("");

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["support-inbox"] });
    if (thread) qc.invalidateQueries({ queryKey: ["support-thread", thread.id] });
  };

  const detail = useQuery({
    queryKey: ["support-thread", thread?.id],
    queryFn: () => api.supportThread(thread!.id),
    enabled: !!thread && open,
  });

  const send = useMutation({
    mutationFn: () => api.supportReply(thread!.id, reply.trim()),
    onSuccess: () => {
      toast("উত্তর পাঠানো হয়েছে (অডিট লগড)", "success");
      setReply("");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const close = useMutation({
    mutationFn: () => api.supportClose(thread!.id),
    onSuccess: () => {
      toast("আলাপনা বন্ধ করা হয়েছে (অডিট লগড)", "success");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const closed = detail.data?.thread.status === "closed";

  return (
    <Dialog
      open={open}
      onClose={onClose}
      title={thread ? thread.subject : ""}
      description={
        thread
          ? `${thread.userName}${thread.userMemberCode ? ` (${thread.userMemberCode})` : ""} · খোলা হয়েছে ${dateTimeBn(thread.createdAt)}`
          : undefined
      }
      wide
      footer={
        <>
          {!closed ? (
            <Button
              variant="outline"
              disabled={close.isPending || (detail.data?.messages.length ?? 0) === 0}
              onClick={() => close.mutate()}
            >
              <CheckCheck className="h-4 w-4" aria-hidden /> আলাপনা বন্ধ করুন
            </Button>
          ) : null}
          <Button variant="ghost" onClick={onClose}>
            বন্ধ করুন
          </Button>
        </>
      }
    >
      {detail.isLoading ? (
        <TableSkeleton rows={4} cols={1} />
      ) : detail.isError ? (
        <p className="text-sm text-alert">আলাপনাটি আনা যায়নি — আবার চেষ্টা করুন।</p>
      ) : (
        <div className="space-y-4">
          <ol className="space-y-3">
            {(detail.data?.messages ?? []).map((m) => (
              <li
                key={m.id}
                className={cn(
                  "max-w-[85%] rounded-lg border p-3 text-sm leading-relaxed",
                  m.isAdmin ? "ml-auto border-primary/25 bg-primary-soft/60" : "border-border bg-card"
                )}
              >
                <p className="mb-1 flex items-center gap-2 text-xs font-semibold text-muted-foreground">
                  {m.isAdmin ? "সাপোর্ট দল" : (m.authorName ?? "সদস্য")} · {dateTimeBn(m.createdAt)}
                </p>
                <p className="whitespace-pre-wrap">{m.body}</p>
              </li>
            ))}
          </ol>

          {closed ? (
            <p className="rounded-md border border-border bg-muted/50 p-3 text-sm text-muted-foreground">
              এই আলাপনা বন্ধ করা হয়েছে — নতুন বার্তা যুক্ত করা যাবে না।
            </p>
          ) : (
            <div className="space-y-2 border-t border-border pt-3">
              <Textarea
                id="support-reply"
                value={reply}
                onChange={(e) => setReply(e.target.value)}
                placeholder="সদস্যকে সালামসহ উত্তর লিখুন…"
                aria-label="উত্তর"
                className="min-h-[88px]"
              />
              <div className="flex items-center justify-between gap-2">
                <span className="text-xs text-muted-foreground">{toBn(reply.trim().length)} / ২০০০</span>
                <Button
                  size="sm"
                  disabled={!reply.trim() || reply.trim().length < 3 || send.isPending}
                  loading={send.isPending}
                  onClick={() => send.mutate()}
                >
                  <Send className="h-4 w-4" aria-hidden /> উত্তর পাঠান
                </Button>
              </div>
            </div>
          )}
        </div>
      )}
    </Dialog>
  );
}

export default function SupportPage() {
  const { user } = useSession();
  const [filter, setFilter] = React.useState<string>(""); // "" = সব
  const [active, setActive] = React.useState<SupportThreadItem | null>(null);
  const [dialogOpen, setDialogOpen] = React.useState(false);

  const inbox = useQuery({
    queryKey: ["support-inbox", filter],
    queryFn: () => api.supportInbox(filter || undefined),
  });

  const rows = inbox.data?.threads ?? [];
  const counts = React.useMemo(() => {
    const all = inbox.data?.threads ?? [];
    return {
      open: all.filter((t) => t.status === "open").length,
      answered: all.filter((t) => t.status === "answered").length,
      closed: all.filter((t) => t.status === "closed").length,
    };
  }, [inbox.data]);

  const columns = React.useMemo<ColumnDef<SupportThreadItem, unknown>[]>(
    () => [
      {
        accessorKey: "userName",
        header: "সদস্য",
        cell: ({ row }) => (
          <div className="min-w-0">
            <span className="flex items-center gap-1.5 truncate font-semibold">
              <UserRound className="h-3.5 w-3.5 shrink-0 text-muted-foreground" aria-hidden />
              {row.original.userName}
            </span>
            {row.original.userMemberCode ? (
              <span className="block font-mono text-[11px] text-muted-foreground">
                {row.original.userMemberCode}
              </span>
            ) : null}
          </div>
        ),
      },
      {
        accessorKey: "userGender",
        header: "লিঙ্গ",
        cell: ({ row }) => <GenderBadge gender={row.original.userGender} />,
        enableSorting: false,
      },
      {
        accessorKey: "subject",
        header: "বিষয়",
        cell: ({ row }) => (
          <div className="max-w-72">
            <span className="block truncate font-medium">{row.original.subject}</span>
            {row.original.lastPreview ? (
              <span className="block truncate text-xs text-muted-foreground">{row.original.lastPreview}</span>
            ) : null}
          </div>
        ),
      },
      {
        accessorKey: "messageCount",
        header: "বার্তা",
        cell: ({ row }) => <span className="font-bold tabular-nums">{toBn(row.original.messageCount)}</span>,
      },
      {
        accessorKey: "status",
        header: "অবস্থা",
        cell: ({ row }) => <StatusBadge status={row.original.status} />,
      },
      {
        accessorKey: "lastMessageAt",
        header: "সর্বশেষ",
        cell: ({ row }) => (
          <span className="text-xs text-muted-foreground">
            {row.original.lastMessageAt ? relativeBn(row.original.lastMessageAt) : "—"}
          </span>
        ),
      },
    ],
    []
  );

  if (!user) return <TableSkeleton rows={4} cols={4} />;

  return (
    <RoleGate allow={(r) => r === "full_admin"} role={user.role}>
    <div className="space-y-6">
      <PageHeading
        icon={<Inbox className="h-6 w-6" aria-hidden />}
        title="সাপোর্ট ইনবক্স"
        description="সদস্যদের সরাসরি জিজ্ঞাসা — উত্তর দিন বা সমাধান হলে আলাপনা বন্ধ করুন। প্রতিটি উত্তর ও বন্ধকরণ অডিট লগে সংরক্ষিত হয়।"
      />

      <Card>
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-3">
          <div>
            <CardTitle>আলাপনা তালিকা</CardTitle>
            <CardDescription>উত্তর-বাকি আগে, তারপর উত্তরিত, শেষে বন্ধ — প্রতিটি গ্রুপে সর্বশেষ কার্যক্রম অনুসারে</CardDescription>
          </div>
          <div className="flex items-center gap-1.5" role="group" aria-label="অবস্থা ফিল্টার">
            {(
              [
                ["", `সব ${toBn(rows.length)}`],
                ["open", `উত্তর বাকি ${toBn(counts.open)}`],
                ["answered", `উত্তরিত ${toBn(counts.answered)}`],
                ["closed", `বন্ধ ${toBn(counts.closed)}`],
              ] as const
            ).map(([key, label]) => (
              <Button
                key={key || "all"}
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
            loading={inbox.isLoading}
            error={inbox.isError ? inbox.error : undefined}
            onRetry={() => inbox.refetch()}
            onRowClick={(t) => {
              setActive(t);
              setDialogOpen(true);
            }}
            rowAriaLabel={(t) => `${t.userName} — ${t.subject} — আলাপনা খুলুন`}
            emptyTitle="কোনো আলাপনা নেই ✓"
            emptyHint="এই মুহূর্তে কোনো সদস্য সাপোর্টে যোগাযোগ করেননি।"
            csvFilename="support-inbox.csv"
            csvHeaders={["সদস্য", "সদস্য কোড", "বিষয়", "অবস্থা", "বার্তা সংখ্যা", "সর্বশেষ কার্যক্রম"]}
            csvRow={(t) => [
              t.userName,
              t.userMemberCode ?? "",
              t.subject,
              SUPPORT_STATUS_LABELS_BN[t.status] ?? t.status,
              t.messageCount,
              t.lastMessageAt ?? "",
            ]}
          />
        </CardContent>
      </Card>

      {active ? <ThreadDialog thread={active} open={dialogOpen} onClose={() => setDialogOpen(false)} /> : null}
    </div>
    </RoleGate>
  );
}
