"use client";

import * as React from "react";
import { useRouter, useSearchParams } from "next/navigation";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { FileCheck2, Plus, ShieldCheck, Users2 } from "lucide-react";
import { api, type AssessmentDetail } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateLabelBn, relativeBn, toBn } from "@/lib/bn";
import { ASSESSMENT_RESULT_LABELS_BN } from "@/lib/labels";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { Skeleton, TableSkeleton } from "@/components/ui/skeleton";
import { ErrorState } from "@/components/ui/states";
import { Tabs, TabsList, TabsPanel, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

type ScoreState = Record<string, { score: 0 | 1 | 2; comment?: string }>;

function ScoreSegment({
  value,
  onChange,
  disabled,
}: {
  value: 0 | 1 | 2 | undefined;
  onChange: (v: 0 | 1 | 2) => void;
  disabled?: boolean;
}) {
  const opts: { v: 0 | 1 | 2; label: string }[] = [
    { v: 0, label: "০ · হয়নি" },
    { v: 1, label: "১ · আংশিক" },
    { v: 2, label: "২ · সম্পূর্ণ" },
  ];
  return (
    <div className="inline-flex overflow-hidden rounded-md border border-border" role="radiogroup" aria-label="স্কোর">
      {opts.map((o) => (
        <button
          key={o.v}
          type="button"
          role="radio"
          aria-checked={value === o.v}
          disabled={disabled}
          onClick={() => onChange(o.v)}
          className={cn(
            "focus-ring min-h-9 border-r border-border px-2.5 text-xs font-semibold transition-colors duration-150 last:border-r-0",
            value === o.v
              ? o.v === 2
                ? "bg-success text-success-foreground"
                : o.v === 1
                  ? "bg-gold text-gold-foreground"
                  : "bg-alert text-destructive-foreground"
              : "bg-card text-muted-foreground hover:bg-primary-soft"
          )}
        >
          {o.label}
        </button>
      ))}
    </div>
  );
}

function NewAssessmentForm() {
  const { user } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const router = useRouter();
  const searchParams = useSearchParams();
  const preselect = searchParams.get("member");

  const templates = useQuery({ queryKey: ["assessment-templates"], queryFn: () => api.assessmentTemplates() });
  const myUsrah = useQuery({ queryKey: ["my-usrah"], queryFn: () => api.myUsrah(), enabled: !!user?.usrahId });
  const allUsers = useQuery({
    queryKey: ["admin-users", ""],
    queryFn: () => api.users(""),
    enabled: !user?.usrahId,
  });

  const [memberId, setMemberId] = React.useState<string>(preselect ?? "");
  const [templateKey, setTemplateKey] = React.useState<string>("");
  const [participantCategory, setParticipantCategory] = React.useState<1 | 2>(1);
  const [scores, setScores] = React.useState<ScoreState>({});
  const [overallComment, setOverallComment] = React.useState("");

  const template = React.useMemo(
    () => templates.data?.templates.find((t) => t.key === templateKey) ?? templates.data?.templates[0] ?? null,
    [templates.data, templateKey]
  );

  const candidates = React.useMemo(() => {
    const fromUsrah = myUsrah.data?.usrah?.members ?? [];
    if (fromUsrah.length) {
      return fromUsrah
        .filter((m) => m.id !== user?.id)
        .map((m) => ({ id: m.id, name: m.name, gender: m.gender, memberCode: m.memberCode }));
    }
    return (allUsers.data?.users ?? [])
      .filter((m) => m.id !== user?.id)
      .map((m) => ({ id: m.id, name: m.name, gender: m.gender, memberCode: m.memberCode }));
  }, [myUsrah.data, allUsers.data, user?.id]);

  // Validate the preselected member once candidates load — render-phase
  // adjustment (kept outside effects per react-hooks lint).
  const [candidatesKey, setCandidatesKey] = React.useState("");
  const ckey = `${preselect ?? ""}:${candidates.length}`;
  if (ckey !== candidatesKey) {
    setCandidatesKey(ckey);
    if (!memberId && candidates.length) {
      setMemberId(preselect && candidates.some((c) => c.id === preselect) ? preselect : "");
    }
  }

  const totalCriteria = template?.sections.reduce((s, sec) => s + sec.criteria.length, 0) ?? 0;
  const scoredCount = template
    ? template.sections.reduce((s, sec) => s + sec.criteria.filter((c) => scores[c.key]).length, 0)
    : 0;
  const previewPct =
    scoredCount > 0
      ? Math.round(
          (100 * Object.values(scores).reduce((s, v) => s + v.score, 0)) / (2 * Math.max(scoredCount, 1))
        )
      : null;
  const previewPassed =
    template && scoredCount === totalCriteria && totalCriteria > 0
      ? template.sections.every((sec) => {
          const good = sec.criteria.filter((c) => (scores[c.key]?.score ?? 0) >= 1).length;
          return good * 2 > sec.criteria.length;
        })
      : null;

  const submit = useMutation({
    mutationFn: () => {
      if (!memberId || !template) throw new Error("সদস্য ও টেমপ্লেট নির্বাচন করুন");
      if (scoredCount < totalCriteria) throw new Error("সবগুলো নির্ণায়কে স্কোর দিন");
      return api.submitAssessment({
        assesseeId: memberId,
        templateKey: template.key,
        participantCategory,
        scores,
        overallComment,
      });
    },
    onSuccess: (res) => {
      toast(
        `মূল্যায়ন সম্পন্ন — ফলাফল: ${ASSESSMENT_RESULT_LABELS_BN[res.assessment.result]}${
          res.assessment.scorePct != null ? ` (${toBn(res.assessment.scorePct)}%)` : ""
        }`,
        "success"
      );
      setScores({});
      setOverallComment("");
      qc.invalidateQueries({ queryKey: ["assessments"] });
      qc.invalidateQueries({ queryKey: ["admin-overview"] });
      router.replace("/assessments");
    },
    onError: (err: Error) => toast(err.message, "error"),
  });

  if (templates.isLoading) return <TableSkeleton rows={5} cols={3} />;
  if (templates.isError) return <ErrorState error={templates.error} onRetry={() => templates.refetch()} />;

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <FileCheck2 className="h-[18px] w-[18px] text-primary" aria-hidden />
          নতুন মূল্যায়ন — ফরযে আইন
        </CardTitle>
        <CardDescription>
          ২৩টি নির্ণায়ক (ঈমান ৫ · ইলম ৫ · ইবাদত ৬ · আখলাক ৭) · প্রতিটিতে ০/১/২ স্কোর + মন্তব্য ·
          উত্তরণের নিয়ম: প্রতি অংশের অর্ধেকের বেশি নির্ণায়কে ≥১ স্কোর
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="grid grid-cols-1 gap-4 sm:grid-cols-2">
          <Field label="মূল্যায়নার্থী" htmlFor="assess-member">
            <Select
              id="assess-member"
              value={memberId}
              onChange={(e) => setMemberId(e.target.value)}
            >
              <option value="">— নির্বাচন করুন —</option>
              {candidates.map((c) => (
                <option key={c.id} value={c.id}>
                  {c.name}
                  {c.memberCode ? ` (${c.memberCode})` : ""}
                </option>
              ))}
            </Select>
          </Field>
          <Field label="টেমপ্লেট" htmlFor="assess-template">
            <Select
              id="assess-template"
              value={template?.key ?? ""}
              onChange={(e) => {
                setTemplateKey(e.target.value);
                setScores({});
              }}
            >
              {templates.data?.templates.map((t) => (
                <option key={t.key} value={t.key}>
                  {t.titleBn} (v{toBn(t.version)})
                </option>
              ))}
            </Select>
          </Field>
        </div>

        <Field label="অংশগ্রহণকারীর ক্যাটাগরি" hint="সময়-ব্যবস্থাপনার ধাপ অনুযায়ী">
          <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="ক্যাটাগরি">
            {(
              [
                [1, "ক্যাটাগরি ১ — প্রাথমিক দ্বীন শিক্ষা ও দাওয়াত (দৈনিক ৪৫ মিনিট–১ ঘণ্টা)"],
                [2, "ক্যাটাগরি ২ — অগ্রগামী ইলম ও পূর্ণাঙ্গ দাঈ (দৈনিক ১–১.৫ ঘণ্টা)"],
              ] as const
            ).map(([v, label]) => (
              <button
                key={v}
                type="button"
                role="radio"
                aria-checked={participantCategory === v}
                onClick={() => setParticipantCategory(v)}
                className={cn(
                  "focus-ring flex min-h-11 items-center rounded-md border px-3.5 text-sm font-medium transition-colors duration-200",
                  participantCategory === v
                    ? "border-primary bg-primary-soft text-primary"
                    : "border-border bg-card text-muted-foreground hover:text-foreground"
                )}
              >
                {label}
              </button>
            ))}
          </div>
        </Field>

        {template ? (
          <div className="space-y-5">
            {template.sections.map((sec, si) => (
              <fieldset key={sec.key} className="rounded-lg border border-border">
                <legend className="px-2 text-sm font-bold text-foreground">
                  {toBn(si + 1)}. {sec.titleBn}{" "}
                  <span className="font-normal text-muted-foreground">
                    ({toBn(sec.criteria.length)} নির্ণায়ক)
                  </span>
                </legend>
                <div className="space-y-1 p-2.5">
                  {sec.criteria.map((c) => {
                    const sc = scores[c.key];
                    return (
                      <div
                        key={c.key}
                        className="flex flex-col gap-2 rounded-md border border-border/60 p-2.5 lg:flex-row lg:items-center"
                      >
                        <div className="min-w-0 flex-1">
                          <p className="text-sm font-medium leading-snug">{c.titleBn}</p>
                          {c.hintBn ? (
                            <p className="text-xs leading-relaxed text-muted-foreground">{c.hintBn}</p>
                          ) : null}
                        </div>
                        <div className="flex flex-wrap items-center gap-2 lg:justify-end">
                          <ScoreSegment
                            value={sc?.score}
                            onChange={(v) =>
                              setScores((prev) => ({
                                ...prev,
                                [c.key]: { ...prev[c.key], score: v },
                              }))
                            }
                            disabled={submit.isPending}
                          />
                          <Input
                            aria-label={`${c.titleBn} — মন্তব্য`}
                            placeholder="মন্তব্য (ঐচ্ছিক)"
                            value={sc?.comment ?? ""}
                            onChange={(e) =>
                              setScores((prev) => ({
                                ...prev,
                                [c.key]: { score: prev[c.key]?.score ?? 0, comment: e.target.value },
                              }))
                            }
                            className="h-9 w-full text-xs sm:w-56"
                            maxLength={500}
                          />
                        </div>
                      </div>
                    );
                  })}
                </div>
              </fieldset>
            ))}

            <div className="flex flex-wrap items-center gap-4 rounded-lg border border-border bg-muted/40 p-4">
              <div className="flex items-center gap-2">
                <span className="text-sm font-semibold">অগ্রগতি:</span>
                <Badge variant={scoredCount === totalCriteria ? "success" : "warning"}>
                  {toBn(scoredCount)} / {toBn(totalCriteria)}
                </Badge>
              </div>
              {previewPct !== null ? (
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold">প্রাথমিক স্কোর:</span>
                  <span className="text-lg font-bold text-primary">{toBn(previewPct)}%</span>
                </div>
              ) : null}
              {previewPassed !== null ? (
                <Badge variant={previewPassed ? "success" : "warning"}>
                  প্রত্যাশিত ফলাফল: {ASSESSMENT_RESULT_LABELS_BN[previewPassed ? "passed" : "not_yet"]}
                </Badge>
              ) : null}
            </div>

            <Field
              label="সামগ্রিক মন্তব্য"
              htmlFor="assess-overall"
              hint="জমা দিলে মূল্যায়নকারীর ডিজিটাল স্বাক্ষর যুক্ত হবে; মূল্যায়নার্থীর স্বাক্ষর ওটিপি-নিশ্চিতকরণের পর যুক্ত হবে"
            >
              <Textarea
                id="assess-overall"
                value={overallComment}
                onChange={(e) => setOverallComment(e.target.value)}
                placeholder="সামগ্রিক পর্যবেক্ষণ…"
                maxLength={4000}
              />
            </Field>

            <div className="flex flex-wrap items-center justify-end gap-2">
              <Button
                variant="outline"
                onClick={() => {
                  setScores({});
                  setOverallComment("");
                }}
                disabled={submit.isPending}
              >
                ফর্ম রিসেট
              </Button>
              <Button onClick={() => submit.mutate()} loading={submit.isPending} disabled={!memberId}>
                <ShieldCheck className="h-4 w-4" aria-hidden />
                স্বাক্ষরসহ জমা দিন
              </Button>
            </div>
          </div>
        ) : (
          <EmptyTemplates />
        )}
      </CardContent>
    </Card>
  );
}

function EmptyTemplates() {
  return (
    <p className="rounded-md border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
      কোনো মূল্যায়ন টেমপ্লেট পাওয়া যায়নি।
    </p>
  );
}

function AssessmentHistory() {
  const history = useQuery({ queryKey: ["assessments", "mine"], queryFn: () => api.assessments() });

  const columns = React.useMemo<ColumnDef<AssessmentDetail, unknown>[]>(
    () => [
      {
        accessorKey: "assesseeName",
        header: "মূল্যায়নার্থী",
        cell: ({ row }) => <span className="font-semibold">{row.original.assesseeName ?? "—"}</span>,
      },
      {
        accessorKey: "assessorName",
        header: "মূল্যায়নকারী",
        cell: ({ row }) => <span>{row.original.assessorName ?? "—"}</span>,
      },
      {
        accessorKey: "createdAt",
        header: "তারিখ",
        cell: ({ row }) => <span className="text-sm">{dateLabelBn(row.original.createdAt.slice(0, 10))}</span>,
      },
      {
        accessorKey: "scorePct",
        header: "স্কোর",
        cell: ({ row }) => (
          <span className="font-bold tabular-nums">
            {row.original.scorePct != null ? `${toBn(row.original.scorePct)}%` : "—"}
          </span>
        ),
      },
      {
        accessorKey: "result",
        header: "ফলাফল",
        cell: ({ row }) => (
          <Badge variant={row.original.result === "passed" ? "success" : "warning"}>
            {ASSESSMENT_RESULT_LABELS_BN[row.original.result]}
          </Badge>
        ),
      },
      {
        // W4i: the member's OTP-confirmed acknowledgment lifecycle —
        // read-only here; the confirm is the ASSESSEE's own action.
        accessorKey: "status",
        header: "নিশ্চয়ন",
        cell: ({ row }) => {
          const st = (row.original as { status?: string }).status ?? "pending_confirmation";
          const map: Record<string, { label: string; variant: "success" | "warning" | "alert" }> = {
            confirmed: { label: "নিশ্চিত", variant: "success" },
            declined: { label: "বাতিল", variant: "alert" },
            pending_confirmation: { label: "নিশ্চয়ন বাকি", variant: "warning" },
          };
          const cfg = map[st] ?? map.pending_confirmation;
          return <Badge variant={cfg.variant}>{cfg.label}</Badge>;
        },
        enableSorting: false,
      },
      {
        accessorKey: "signatures",
        header: "স্বাক্ষর",
        cell: ({ row }) => (
          <span className="flex items-center gap-1.5" aria-label="দ্বৈত স্বাক্ষরের অবস্থা">
            <Badge variant={row.original.assessorSignedAt ? "success" : "muted"}>মূল্যায়নকারী</Badge>
            <Badge variant={row.original.assesseeSignedAt ? "success" : "muted"}>মূল্যায়নার্থী</Badge>
          </span>
        ),
        enableSorting: false,
      },
    ],
    []
  );

  return (
    <DataTable
      columns={columns}
      data={history.data?.assessments}
      loading={history.isLoading}
      error={history.error}
      onRetry={() => history.refetch()}
      emptyTitle="এখনো কোনো মূল্যায়ন রেকর্ড হয়নি"
      emptyHint="নতুন মূল্যায়ন ট্যাব থেকে প্রথম মূল্যায়ন শুরু করুন।"
      csvFilename="assessments.csv"
      csvHeaders={["মূল্যায়নার্থী", "মূল্যায়নকারী", "তারিখ", "স্কোর (%)", "ফলাফল", "নিশ্চয়ন", "টেমপ্লেট"]}
      csvRow={(a) => [
        a.assesseeName ?? "",
        a.assessorName ?? "",
        a.createdAt.slice(0, 10),
        a.scorePct ?? "",
        ASSESSMENT_RESULT_LABELS_BN[a.result],
        (a as { status?: string }).status === "confirmed"
          ? "নিশ্চিত"
          : (a as { status?: string }).status === "declined"
            ? "বাতিল"
            : "নিশ্চয়ন বাকি",
        a.template.titleBn,
      ]}
    />
  );
}

function TemplateViewer() {
  const templates = useQuery({ queryKey: ["assessment-templates"], queryFn: () => api.assessmentTemplates() });
  const [key, setKey] = React.useState<string>("");
  if (templates.isLoading) return <TableSkeleton rows={4} cols={2} />;
  if (templates.isError) return <ErrorState error={templates.error} onRetry={() => templates.refetch()} />;

  const list = templates.data?.templates ?? [];
  const active = list.find((t) => t.key === key) ?? list[0];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center gap-2">
        {list.map((t) => (
          <Button
            key={t.key}
            size="sm"
            variant={active?.key === t.key ? "default" : "outline"}
            aria-pressed={active?.key === t.key}
            onClick={() => setKey(t.key)}
          >
            {t.titleBn}
          </Button>
        ))}
      </div>
      {active ? (
        <Card>
          <CardHeader>
            <CardTitle>
              {active.titleBn}{" "}
              <span className="text-sm font-normal text-muted-foreground">
                (সংস্করণ {toBn(active.version)} · {active.titleEn})
              </span>
            </CardTitle>
            <CardDescription>
              সর্বমোট {toBn(active.sections.reduce((s, x) => s + x.criteria.length, 0))} নির্ণায়ক —{" "}
              {active.sections.map((s) => `${s.titleBn} ${toBn(s.criteria.length)}`).join(" · ")}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            {active.sections.map((sec) => (
              <div key={sec.key}>
                <p className="mb-1.5 flex items-center gap-2 text-sm font-bold">
                  {sec.titleBn}
                  <Badge variant="muted">{toBn(sec.criteria.length)} নির্ণায়ক</Badge>
                </p>
                <ol className="space-y-1.5">
                  {sec.criteria.map((c, i) => (
                    <li key={c.key} className="rounded-md border border-border/70 p-2.5">
                      <p className="text-sm">
                        <span className="mr-1.5 font-semibold text-muted-foreground">{toBn(i + 1)}.</span>
                        {c.titleBn}
                      </p>
                      {c.hintBn ? (
                        <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{c.hintBn}</p>
                      ) : null}
                    </li>
                  ))}
                </ol>
              </div>
            ))}
            <p className="rounded-md border border-border bg-muted/50 p-3 text-xs leading-relaxed text-muted-foreground">
              টেমপ্লেটটি সংস্করণযুক্ত — নতুন সংস্করণ প্রকাশের সময় আগের সংস্করণের মূল্যায়নগুলো অপরিবর্তিত
              থাকে। মূল্যায়ন পাশের স্কোর-নিয়ম: প্রতি অংশের অর্ধেকের বেশি নির্ণায়কে ≥১ (আংশিক বা
              সম্পূর্ণ) পেলে সেই অংশ উত্তীর্ণ।
            </p>
          </CardContent>
        </Card>
      ) : (
        <EmptyTemplates />
      )}
    </div>
  );
}

// ── B6: versioned template management (full_admin) ─────────────────────

function TemplateVersions() {
  const { fullAdmin } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const all = useQuery({
    queryKey: ["admin-templates"],
    queryFn: () => api.adminTemplates(),
    enabled: fullAdmin,
  });

  const [key, setKey] = React.useState("");
  const [titleBn, setTitleBn] = React.useState("");
  const [sectionsJson, setSectionsJson] = React.useState("");
  const [creating, setCreating] = React.useState(false);

  const invalidate = () => {
    qc.invalidateQueries({ queryKey: ["admin-templates"] });
    qc.invalidateQueries({ queryKey: ["assessment-templates"] });
  };

  const activate = useMutation({
    mutationFn: ({ id, active }: { id: string; active: boolean }) => api.patchTemplate(id, { active }),
    onSuccess: () => {
      toast("সংস্করণের অবস্থা পরিবর্তিত হয়েছে (অডিট লগড)", "success");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const create = useMutation({
    mutationFn: async () => {
      let sections: unknown;
      try {
        sections = JSON.parse(sectionsJson);
      } catch {
        throw new Error("বিভাগসমূহ (sections) সঠিক JSON নয়");
      }
      return api.createTemplateVersion({ key: key.trim(), titleBn: titleBn.trim(), sections: sections as never });
    },
    onSuccess: () => {
      toast("নতুন সংস্করণ তৈরি হয়েছে — পর্যালোচনা শেষে সক্রিয় করুন", "success");
      setCreating(false);
      setKey("");
      setTitleBn("");
      setSectionsJson("");
      invalidate();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  if (!fullAdmin) {
    return (
      <Card>
        <CardContent className="pt-6 text-center text-sm text-muted-foreground">
          সংস্করণ ব্যবস্থাপনা শুধুমাত্র প্রধান অ্যাডমিনের জন্য।
        </CardContent>
      </Card>
    );
  }

  const templates = all.data?.templates ?? [];

  return (
    <div className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-2">
        <p className="text-sm text-muted-foreground">
          প্রতি কী-তে ঠিক একটি সক্রিয় সংস্করণ — সদস্যরা সেটিই দেখেন; সক্রিয় সংস্করণ সম্পাদনাযোগ্য নয়, নতুন সংস্করণ তৈরি করুন।
        </p>
        <Button size="sm" onClick={() => setCreating((c) => !c)}>
          <Plus className="h-4 w-4" aria-hidden />
          {creating ? "বাতিল" : "নতুন সংস্করণ"}
        </Button>
      </div>

      {creating ? (
        <Card>
          <CardHeader>
            <CardTitle className="text-base">নতুন সংস্করণ তৈরি</CardTitle>
            <CardDescription>
              একই কী দিলে পরবর্তী সংস্করণ নম্বর স্বয়ংক্রিয়ভাবে বসে এবং সংস্করণটি নিষ্ক্রিয় অবস্থায় শুরু হয়।
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="grid gap-3 sm:grid-cols-2">
              <Field label="কী (key)" htmlFor="tmpl-key" hint="যেমন farze_ain_v1 — একই কী = নতুন সংস্করণ">
                <Input id="tmpl-key" dir="ltr" value={key} onChange={(e) => setKey(e.target.value)} aria-label="টেমপ্লেট কী" />
              </Field>
              <Field label="বাংলা শিরোনাম" htmlFor="tmpl-title">
                <Input id="tmpl-title" value={titleBn} onChange={(e) => setTitleBn(e.target.value)} aria-label="বাংলা শিরোনাম" />
              </Field>
            </div>
            <Field
              label="বিভাগসমূহ (JSON)"
              htmlFor="tmpl-sections"
              hint='[{"key":"iman","titleBn":"ঈমান","criteria":[{"key":"i1","titleBn":"…"}]}]'
            >
              <Textarea
                id="tmpl-sections"
                dir="ltr"
                rows={8}
                className="font-mono text-xs"
                value={sectionsJson}
                onChange={(e) => setSectionsJson(e.target.value)}
                aria-label="বিভাগসমূহ JSON"
              />
            </Field>
            <Button
              onClick={() => create.mutate()}
              loading={create.isPending}
              disabled={!key.trim() || !titleBn.trim() || !sectionsJson.trim()}
            >
              তৈরি করুন
            </Button>
          </CardContent>
        </Card>
      ) : null}

      {all.isLoading ? (
        <TableSkeleton rows={3} cols={4} />
      ) : all.isError ? (
        <ErrorState error={all.error} onRetry={() => all.refetch()} />
      ) : templates.length === 0 ? (
        <Card>
          <CardContent className="pt-6 text-center text-sm text-muted-foreground">
            কোনো টেমপ্লেট নেই — নতুন সংস্করণ তৈরি করুন।
          </CardContent>
        </Card>
      ) : (
        <ul className="space-y-2">
          {templates.map((t) => (
            <li
              key={t.id}
              className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-border p-3"
            >
              <div className="min-w-0">
                <p className="truncate text-sm font-semibold">
                  {t.titleBn}{" "}
                  <span className="font-mono text-xs font-normal text-muted-foreground" dir="ltr">
                    {t.key} · v{toBn(t.version)}
                  </span>
                </p>
                <p className="text-xs text-muted-foreground">
                  {toBn(t.sections.reduce((s, x) => s + x.criteria.length, 0))} নির্ণায়ক · {dateLabelBn(t.createdAt)}
                </p>
              </div>
              <span className="flex items-center gap-2">
                {t.active ? (
                  <Badge variant="success">সক্রিয়</Badge>
                ) : (
                  <Badge variant="muted">নিষ্ক্রিয়</Badge>
                )}
                <Button
                  size="sm"
                  variant={t.active ? "outline" : "default"}
                  disabled={activate.isPending}
                  onClick={() => activate.mutate({ id: t.id, active: !t.active })}
                >
                  {t.active ? "নিষ্ক্রিয় করুন" : "সক্রিয় করুন"}
                </Button>
              </span>
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export default function AssessmentsPage() {
  return (
    <Tabs defaultValue="new" aria-label="মূল্যায়ন বিভাগ">
      <TabsList>
        <TabsTrigger value="new">নতুন মূল্যায়ন</TabsTrigger>
        <TabsTrigger value="history">ইতিহাস</TabsTrigger>
        <TabsTrigger value="template">টেমপ্লেট দেখুন</TabsTrigger>
        <TabsTrigger value="versions">সংস্করণ ব্যবস্থাপনা</TabsTrigger>
      </TabsList>
      <TabsPanel value="new">
        <React.Suspense fallback={<Skeleton className="h-96" />}>
          <NewAssessmentForm />
        </React.Suspense>
      </TabsPanel>
      <TabsPanel value="history">
        <AssessmentHistory />
      </TabsPanel>
      <TabsPanel value="template">
        <TemplateViewer />
      </TabsPanel>
      <TabsPanel value="versions">
        <TemplateVersions />
      </TabsPanel>
    </Tabs>
  );
}
