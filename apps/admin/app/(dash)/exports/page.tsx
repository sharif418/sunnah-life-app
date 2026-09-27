"use client";

// রিপোর্ট ও এক্সপোর্ট — CSV download hub (users, usrah health, month grids, audit)
// plus the monthly Muhasaba PDF worker status note.

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { CalendarDays, Download, FileSpreadsheet } from "lucide-react";
import { api } from "@/lib/api";
import { useSession } from "@/lib/session";
import { monthLabel, toBn } from "@/lib/bn";
import { GENDER_LABELS_BN, LEVEL_LABELS_BN, ROLE_LABELS_BN, auditActionLabel, isFullAdmin, isSupervisor } from "@/lib/labels";
import { downloadCsvSafe } from "@/lib/csv";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { PageHeading, RoleGate } from "@/components/ui/states";

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
            <CardTitle>মাসিক PDF রিপোর্ট</CardTitle>
            <CardDescription>
              ওয়ার্কার প্রতি মাসের ১ তারিখে স্বয়ংক্রিয়ভাবে প্রতিটি সদস্যের PDF (কাগজের ফর্মের বিন্যাসে) তৈরি করে
              স্টোরেজে রাখে। যেকোনো সদস্যের প্রোফাইল থেকে সরাসরি নামানো যাবে — এই পৃথিবীর সব রিপোর্ট সেখানেই।
            </CardDescription>
          </CardHeader>
        </Card>
      </div>
    </RoleGate>
  );
}
