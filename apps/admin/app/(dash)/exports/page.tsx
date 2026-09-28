"use client";

// রিপোর্ট ও এক্সপোর্ট — CSV download hub (users, usrah health, month grids, audit)
// plus the monthly Muhasaba PDF report list (worker-generated + manual render).

import * as React from "react";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import { CalendarDays, Download, FileSpreadsheet, FileText, RefreshCw } from "lucide-react";
import { api, downloadReportPdf, type MonthlyReportItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, monthLabel, toBn } from "@/lib/bn";
import { GENDER_LABELS_BN, LEVEL_LABELS_BN, ROLE_LABELS_BN, auditActionLabel, isFullAdmin, isSupervisor } from "@/lib/labels";
import { downloadCsvSafe } from "@/lib/csv";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PageHeading, RoleGate } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

function ExportCard({
  icon,
  title,
  description,
  onDownload,
  loading,
  disabled,
  disabledHint,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
  onDownload: () => void;
  loading?: boolean;
  disabled?: boolean;
  disabledHint?: string;
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2 text-base">
          {icon}
          {title}
        </CardTitle>
        <CardDescription>{description}</CardDescription>
      </CardHeader>
      <CardContent>
        <Button onClick={onDownload} disabled={disabled || loading} loading={loading}>
          <Download className="h-4 w-4" aria-hidden />
          CSV ডাউনলোড
        </Button>
        {disabled && disabledHint ? <p className="mt-2 text-xs text-alert">{disabledHint}</p> : null}
      </CardContent>
    </Card>
  );
}

export default function ExportsPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const queryClient = useQueryClient();
  const fullAdmin = isFullAdmin(user?.role);
  const supervisor = isSupervisor(user?.role);

  const overview = useQuery({ queryKey: ["admin-overview"], queryFn: () => api.overview(), enabled: supervisor });
  const users = useQuery({ queryKey: ["admin-users", ""], queryFn: () => api.users(""), enabled: fullAdmin });
  const audit = useQuery({ queryKey: ["audit"], queryFn: () => api.audit(), enabled: fullAdmin });

  const monthOptions = React.useMemo(() => {
    const now = new Date();
    const out: string[] = [];
    for (let i = 0; i < 6; i += 1) {
      const d = new Date(now.getFullYear(), now.getMonth() - i, 1);
      out.push(`${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`);
    }
    return out;
  }, []);
  const [gridMonth, setGridMonth] = React.useState(monthOptions[0]);
  const [gridUser, setGridUser] = React.useState("");
  const [gridBusy, setGridBusy] = React.useState(false);

  // Monthly PDF reports (B3): worker-generated + manual render.
  const [reportMonth, setReportMonth] = React.useState(monthOptions[0]);
  const [reportUser, setReportUser] = React.useState("");
  const [reportBusy, setReportBusy] = React.useState(false);
  const [downloadingId, setDownloadingId] = React.useState<string | null>(null);

  const reports = useQuery({
    queryKey: ["monthly-reports", reportMonth, reportUser],
    queryFn: () => api.monthlyReports(reportMonth, reportUser || undefined),
    enabled: supervisor,
  });

  const reportRows = reports.data?.reports ?? [];

  const generateReport = async () => {
    if (!reportUser) return;
    setReportBusy(true);
    try {
      const created = await api.generateReport(reportUser, reportMonth);
      toast(`${monthLabel(reportMonth)} মাসের রিপোর্ট তৈরি হয়েছে`, "success");
      await queryClient.invalidateQueries({ queryKey: ["monthly-reports"] });
      void created;
    } catch (e) {
      toast(e instanceof Error ? e.message : "রিপোর্ট তৈরি ব্যর্থ", "error");
    } finally {
      setReportBusy(false);
    }
  };

  const downloadReport = async (report: MonthlyReportItem) => {
    setDownloadingId(report.id);
    try {
      await downloadReportPdf(report);
    } catch (e) {
      toast(e instanceof Error ? e.message : "ডাউনলোড ব্যর্থ", "error");
    } finally {
      setDownloadingId(null);
    }
  };

  const exportUsers = () => {
    const rows = (users.data?.users ?? []).map((u) => [
      u.name,
      u.phone,
      GENDER_LABELS_BN[u.gender],
      ROLE_LABELS_BN[u.role],
      u.memberCode,
      LEVEL_LABELS_BN[u.level],
      u.district,
      u.lastActiveAt,
    ]);
    downloadCsvSafe("sunnahlife-users.csv", ["নাম", "ফোন", "লিঙ্গ", "ভূমিকা", "সদস্য কোড", "স্তর", "জেলা", "সর্বশেষ সক্রিয়"], rows);
  };

  const exportUsrahHealth = () => {
    const rows = (overview.data?.usrahs ?? []).map((h) => [
      h.name,
      GENDER_LABELS_BN[h.gender],
      h.members,
      h.reviewPct,
      h.avgCompletion,
      h.inactiveCount,
    ]);
    downloadCsvSafe(
      "sunnahlife-usrah-health.csv",
      ["উসরা", "লিঙ্গ", "সদস্য", "রিভিউ %", "গড় আমল %", "নিষ্ক্রিয়"],
      rows,
    );
  };

  const exportAudit = () => {
    const rows = (audit.data?.entries ?? []).map((e) => [
      e.createdAt,
      auditActionLabel(e.action),
      e.actorId ?? "system",
      e.targetType,
      e.targetId,
    ]);
    downloadCsvSafe("sunnahlife-audit.csv", ["সময়", "ঘটনা", "কর্তা", "লক্ষ্য ধরন", "লক্ষ্য আইডি"], rows);
  };

  const exportMonthGrid = async () => {
    if (!gridUser) return;
    setGridBusy(true);
    try {
      const res = await api.monthGrid(gridUser, gridMonth);
      const grid = res.grid;
      const header = ["আমল", ...grid.days];
      const rows = Object.entries(grid.rows).map(([amalKey, cells]) => {
        const def = grid.definitions.find((d) => d.key === amalKey);
        const label = def?.titleBn ?? amalKey;
        return [
          label,
          ...cells.map((c) => {
            if (!c) return "";
            const v = c.value;
            if (v === "jamaat") return "জামাত";
            if (v === "alone") return "একা";
            if (v === "qaza") return "কাযা";
            if (typeof v === "boolean") return v ? "✓" : "✗";
            return String(v ?? "");
          }),
        ];
      });
      const userName = users.data?.users.find((u) => u.id === gridUser)?.name ?? gridUser;
      downloadCsvSafe(`muhasaba-${userName}-${gridMonth}.csv`, header, rows);
    } finally {
      setGridBusy(false);
    }
  };

  return (
    <RoleGate allow={(r) => isSupervisor(r)} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<FileSpreadsheet className="h-6 w-6" aria-hidden />}
          title="রিপোর্ট ও এক্সপোর্ট"
          description="CSV এক্সপোর্ট (Excel-উপযোগী, বাংলা টেক্সটসহ) ও মাসিক মুহাসাবা রিপোর্টের অবস্থা।"
        />

        <div className="grid gap-4 md:grid-cols-2 xl:grid-cols-3">
          <ExportCard
            icon={<FileSpreadsheet className="h-[18px] w-[18px] text-primary" aria-hidden />}
            title="ব্যবহারকারী তালিকা"
            description={fullAdmin ? "সব ব্যবহারকারী — ভূমিকা, স্তর, সদস্য কোডসহ।" : "শুধুমাত্র প্রধান অ্যাডমিনের জন্য।"}
            onDownload={exportUsers}
            loading={users.isLoading}
            disabled={!fullAdmin || (users.data?.users.length ?? 0) === 0}
            disabledHint={!fullAdmin ? "প্রধান অ্যাডমিন নন।" : "কোনো ব্যবহারকারী নেই।"}
          />
          <ExportCard
            icon={<FileSpreadsheet className="h-[18px] w-[18px] text-primary" aria-hidden />}
            title="উসরা স্বাস্থ্য"
            description="রিভিউ সম্পন্নতা, গড় আমল, নিষ্ক্রিয় সদস্য — আপনার পরিধির উসরাগুলো।"
            onDownload={exportUsrahHealth}
            loading={overview.isLoading}
            disabled={(overview.data?.usrahs.length ?? 0) === 0}
            disabledHint="কোনো উসরা নেই।"
          />
          {fullAdmin ? (
            <ExportCard
              icon={<FileSpreadsheet className="h-[18px] w-[18px] text-primary" aria-hidden />}
              title="অডিট লগ"
              description="সংবেদনশীল ঘটনাগুলোর সম্পূর্ণ তালিকা।"
              onDownload={exportAudit}
              loading={audit.isLoading}
              disabled={(audit.data?.entries.length ?? 0) === 0}
              disabledHint="কোনো এন্ট্রি নেই।"
            />
          ) : null}
        </div>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <CalendarDays className="h-[18px] w-[18px] text-primary" aria-hidden />
              মাসিক মুহাসাবা গ্রিড (CSV)
            </CardTitle>
            <CardDescription>
              কাগজের ডায়েরির মতোই ৩১ কলামের গ্রিড — যেকোনো সদস্যের যেকোনো মাস।
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-wrap items-end gap-3">
              <label className="flex flex-col gap-1 text-sm font-semibold">
                মাস
                <select
                  value={gridMonth}
                  onChange={(e) => setGridMonth(e.target.value)}
                  className="min-h-11 rounded-lg border border-border bg-card px-3 text-sm"
                  aria-label="মাস নির্বাচন"
                >
                  {monthOptions.map((m) => (
                    <option key={m} value={m}>
                      {monthLabel(m)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-semibold">
                সদস্য
                <select
                  value={gridUser}
                  onChange={(e) => setGridUser(e.target.value)}
                  className="min-h-11 min-w-52 rounded-lg border border-border bg-card px-3 text-sm"
                  aria-label="সদস্য নির্বাচন"
                >
                  <option value="">— নির্বাচন করুন —</option>
                  {(users.data?.users ?? []).map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.name}
                      {u.memberCode ? ` (${u.memberCode})` : ""}
                    </option>
                  ))}
                </select>
              </label>
              <Button onClick={exportMonthGrid} disabled={!gridUser || gridBusy} loading={gridBusy}>
                <Download className="h-4 w-4" aria-hidden />
                গ্রিড ডাউনলোড
              </Button>
            </div>
            {!fullAdmin ? (
              <p className="text-xs text-muted-foreground">
                সদস্য তালিকা আপনার এখতিয়ার অনুযায়ী সীমিত — আপনার উসরার সদস্যদের গ্রিড নামাতে উসরা পাতা থেকে সদস্য পছন্দ করুন।
              </p>
            ) : null}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <FileText className="h-[18px] w-[18px] text-primary" aria-hidden />
              মাসিক মুহাসাবা PDF রিপোর্ট
            </CardTitle>
            <CardDescription>
              কাগজের ফর্মের বিন্যাসে ৩১ কলামের PDF — ওয়ার্কার প্রতি মাসের ১ তারিখে স্বয়ংক্রিয়ভাবে তৈরি করে।
              {fullAdmin ? " প্রয়োজনে এখান থেকে সরাসরি তৈরি করুন।" : ""}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="flex flex-wrap items-end gap-3">
              <label className="flex flex-col gap-1 text-sm font-semibold">
                মাস
                <select
                  value={reportMonth}
                  onChange={(e) => setReportMonth(e.target.value)}
                  className="min-h-11 rounded-lg border border-border bg-card px-3 text-sm"
                  aria-label="রিপোর্টের মাস"
                >
                  {monthOptions.map((m) => (
                    <option key={m} value={m}>
                      {monthLabel(m)}
                    </option>
                  ))}
                </select>
              </label>
              <label className="flex flex-col gap-1 text-sm font-semibold">
                সদস্য
                <select
                  value={reportUser}
                  onChange={(e) => setReportUser(e.target.value)}
                  className="min-h-11 min-w-52 rounded-lg border border-border bg-card px-3 text-sm"
                  aria-label="রিপোর্টের সদস্য"
                >
                  <option value="">— সব সদস্য —</option>
                  {(users.data?.users ?? []).map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.name}
                      {u.memberCode ? ` (${u.memberCode})` : ""}
                    </option>
                  ))}
                </select>
              </label>
              {fullAdmin ? (
                <Button onClick={generateReport} disabled={!reportUser || reportBusy} loading={reportBusy}>
                  <RefreshCw className="h-4 w-4" aria-hidden />
                  রিপোর্ট তৈরি করুন
                </Button>
              ) : null}
              <Button
                variant="outline"
                onClick={() => reports.refetch()}
                disabled={reports.isFetching}
                loading={reports.isFetching}
              >
                <RefreshCw className="h-4 w-4" aria-hidden />
                তালিকা রিফ্রেশ
              </Button>
            </div>
            {!fullAdmin ? (
              <p className="text-xs text-muted-foreground">
                তালিকা আপনার এখতিয়ার অনুযায়ী সীমিত — আপনার উসরার সদস্যদের রিপোর্টই দেখা যাবে।
              </p>
            ) : null}

            {reports.isLoading ? (
              <p className="text-sm text-muted-foreground">লোড হচ্ছে…</p>
            ) : reportRows.length === 0 ? (
              <p className="text-sm text-muted-foreground">
                {reportMonth ? `${monthLabel(reportMonth)} মাসে` : "এই পরিসরে"} কোনো রিপোর্ট নেই।
              </p>
            ) : (
              <div className="overflow-x-auto rounded-lg border border-border">
                <table className="w-full text-sm">
                  <thead className="bg-primary-soft text-left text-xs">
                    <tr>
                      <th className="px-3 py-2 font-semibold">সদস্য</th>
                      <th className="px-3 py-2 font-semibold">মাস</th>
                      <th className="px-3 py-2 font-semibold">অবস্থা</th>
                      <th className="px-3 py-2 font-semibold">আকার</th>
                      <th className="px-3 py-2 font-semibold">তৈরি</th>
                      <th className="px-3 py-2 font-semibold text-right">ডাউনলোড</th>
                    </tr>
                  </thead>
                  <tbody>
                    {reportRows.map((r) => (
                      <tr key={r.id} className="border-t border-border">
                        <td className="px-3 py-2">
                          <span className="font-medium">{r.userName ?? r.userId.slice(0, 8)}</span>
                          {r.memberCode ? (
                            <span className="ml-1 text-xs text-muted-foreground">{r.memberCode}</span>
                          ) : null}
                        </td>
                        <td className="px-3 py-2">{monthLabel(r.month)}</td>
                        <td className="px-3 py-2">
                          {r.status === "ready" ? (
                            <span className="rounded-full bg-green-100 px-2 py-0.5 text-xs font-semibold text-green-800">
                              প্রস্তুত
                            </span>
                          ) : (
                            <span className="rounded-full bg-red-100 px-2 py-0.5 text-xs font-semibold text-red-800">
                              ব্যর্থ{r.errorBn ? ` — ${r.errorBn.slice(0, 40)}` : ""}
                            </span>
                          )}
                        </td>
                        <td className="px-3 py-2 text-muted-foreground">{toBn(Math.round(r.byteSize / 1024))} কিবি</td>
                        <td className="px-3 py-2 text-muted-foreground">{dateTimeBn(r.generatedAt)}</td>
                        <td className="px-3 py-2 text-right">
                          <Button
                            size="sm"
                            variant="outline"
                            disabled={r.status !== "ready" || downloadingId === r.id}
                            loading={downloadingId === r.id}
                            onClick={() => downloadReport(r)}
                          >
                            <Download className="h-4 w-4" aria-hidden />
                            PDF
                          </Button>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              </div>
            )}
          </CardContent>
        </Card>
      </div>
    </RoleGate>
  );
}
