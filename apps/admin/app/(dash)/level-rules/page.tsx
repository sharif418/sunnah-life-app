"use client";

// লেভেল রুলস এডিটর (full_admin) — W4h। স্তরের উন্নয়নের নিয়ম সম্পাদনা: ইঞ্জিন
// packages/content/level-rules.json (প্যাক সিড) থেকে পড়ে, আর এখানকার সম্পাদনা
// AppConfigRow (key "level_rules")-এ DB ওভাররাইড হিসেবে জমা হয় (merge semantics —
// যে ফিল্ড পাঠানো হয়নি সেটি আগের মানই থাকে)। DELETE = এক স্তরের ওভাররাইড ফেলে
// প্যাক ডিফল্টে ফেরা। প্রতিটি পরিবর্তন অডিট লগ হয় (level_rules_update)।

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowDown, ArrowUp, ListPlus, RotateCcw, Save, SlidersHorizontal, Trash2 } from "lucide-react";
import { api, type LevelRulesDoc } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn } from "@/lib/bn";
import { LEVEL_LABELS_BN, isFullAdmin } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { BoolToggle } from "@/components/ui/bool-toggle";
import { Field, Input, Textarea } from "@/components/ui/input";
import { ErrorState, PageHeading, RoleGate } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";
import { cn } from "@/lib/utils";

const LEVEL_KEYS = ["muhibbus_sunnah", "farze_ain_1", "farze_ain_2"] as const;
type LevelKey = (typeof LEVEL_KEYS)[number];

const SOURCE_LABELS: Record<string, { label: string; variant: "gold" | "outline" | "muted" }> = {
  db: { label: "কাস্টম ওভাররাইড (ডেটাবেস)", variant: "gold" },
  pack: { label: "প্যাক ডিফল্ট", variant: "outline" },
  default: { label: "ইঞ্জিন ডিফল্ট", variant: "muted" },
};

/** checklistBn আইটেম — {key?, categoryBn?, label} (API validator-এর ঠিক আকার)। */
interface ChecklistForm {
  key: string;
  categoryBn: string;
  label: string;
}

interface RulesForm {
  titleBn: string;
  minMonths: string;
  minMonthsLabelBn: string;
  minReferralsAtLevel: string;
  minReferralsLabelBn: string;
  outlineReviewLabelBn: string;
  assessmentKey: string;
  assessmentCategory: string;
  assessmentRuleBn: string;
  categoryDescriptionBn: string;
  requireAssessmentPassed: boolean;
  outlineReviewRequired: boolean;
  autoPromote: boolean;
  checklist: ChecklistForm[];
}

function nodeToForm(node: Record<string, unknown>): RulesForm {
  const str = (k: string) => (typeof node[k] === "string" ? (node[k] as string) : "");
  const num = (k: string) => (typeof node[k] === "number" ? String(node[k]) : "");
  const rawChecklist = Array.isArray(node.checklistBn) ? node.checklistBn : [];
  return {
    titleBn: str("titleBn"),
    minMonths: num("minMonths"),
    minMonthsLabelBn: str("minMonthsLabelBn"),
    minReferralsAtLevel: num("minReferralsAtLevel"),
    minReferralsLabelBn: str("minReferralsLabelBn"),
    outlineReviewLabelBn: str("outlineReviewLabelBn"),
    assessmentKey: str("assessmentKey"),
    assessmentCategory: num("assessmentCategory"),
    assessmentRuleBn: str("assessmentRuleBn"),
    categoryDescriptionBn: str("categoryDescriptionBn"),
    requireAssessmentPassed: node.requireAssessmentPassed === true,
    outlineReviewRequired: node.outlineReviewRequired === true,
    autoPromote: node.autoPromote === true,
    checklist: rawChecklist.map((raw) => {
      const o = (raw ?? {}) as Record<string, unknown>;
      return {
        key: typeof o.key === "string" ? o.key : "",
        categoryBn: typeof o.categoryBn === "string" ? o.categoryBn : "",
        label: typeof o.label === "string" ? o.label : "",
      };
    }),
  };
}

/** ফর্ম → PUT প্যাচ। খালি optional স্ট্রিং/সংখ্যা বাদ — API-র validator অনুযায়ী
 *  শুধু বোধগম্য ফিল্ডই যায়, তাই ভুলে কোনো নিয়ম মুছে যায় না। */
function formToPatch(form: RulesForm, hasChecklist: boolean): Record<string, unknown> {
  const patch: Record<string, unknown> = {
    titleBn: form.titleBn.trim(),
    requireAssessmentPassed: form.requireAssessmentPassed,
    outlineReviewRequired: form.outlineReviewRequired,
    autoPromote: form.autoPromote,
  };
  const int = (v: string) => {
    const n = Number(v);
    return v !== "" && Number.isInteger(n) ? n : null;
  };
  const minMonths = int(form.minMonths);
  if (minMonths !== null) patch.minMonths = minMonths;
  const minReferrals = int(form.minReferralsAtLevel);
  if (minReferrals !== null) patch.minReferralsAtLevel = minReferrals;
  const category = int(form.assessmentCategory);
  if (category !== null) patch.assessmentCategory = category;
  for (const key of [
    "minMonthsLabelBn",
    "minReferralsLabelBn",
    "outlineReviewLabelBn",
    "assessmentKey",
    "assessmentRuleBn",
    "categoryDescriptionBn",
  ] as const) {
    const v = form[key].trim();
    if (v) patch[key] = v;
  }
  if (hasChecklist || form.checklist.length > 0) {
    patch.checklistBn = form.checklist
      .filter((c) => c.label.trim())
      .map((c) => ({
        ...(c.key.trim() ? { key: c.key.trim().slice(0, 60) } : {}),
        ...(c.categoryBn.trim() ? { categoryBn: c.categoryBn.trim().slice(0, 60) } : {}),
        label: c.label.trim(),
      }));
  }
  return patch;
}

function ChecklistEditor({
  items,
  onChange,
}: {
  items: ChecklistForm[];
  onChange: (items: ChecklistForm[]) => void;
}) {
  const set = (i: number, patch: Partial<ChecklistForm>) =>
    onChange(items.map((it, idx) => (idx === i ? { ...it, ...patch } : it)));
  const move = (i: number, dir: -1 | 1) => {
    const j = i + dir;
    if (j < 0 || j >= items.length) return;
    const next = [...items];
    [next[i], next[j]] = [next[j], next[i]];
    onChange(next);
  };

  return (
    <div className="space-y-2.5">
      {items.length === 0 ? (
        <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
          এই স্তরে কোনো চেকলিস্ট আইটেম নেই
        </p>
      ) : (
        <ul className="space-y-2">
          {items.map((item, i) => (
            <li key={i} className="rounded-md border border-border bg-card p-3">
              <div className="flex flex-wrap items-center gap-2">
                <Input
                  value={item.categoryBn}
                  onChange={(e) => set(i, { categoryBn: e.target.value })}
                  placeholder="বিভাগ (যেমন: ঈমান)"
                  className="h-9 w-44 flex-1"
                  aria-label={`${toBn(i + 1)} নং আইটেমের বিভাগ`}
                />
                <Input
                  value={item.key}
                  onChange={(e) => set(i, { key: e.target.value })}
                  placeholder="কী (ঐচ্ছিক)"
                  className="h-9 w-36 font-mono text-xs"
                  aria-label={`${toBn(i + 1)} নং আইটেমের কী`}
                />
                <span className="ml-auto flex items-center gap-1">
                  <Button variant="ghost" size="icon" className="h-9 w-9" onClick={() => move(i, -1)} disabled={i === 0} aria-label="উপরে সরান">
                    <ArrowUp className="h-4 w-4" aria-hidden />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-9 w-9" onClick={() => move(i, 1)} disabled={i === items.length - 1} aria-label="নিচে সরান">
                    <ArrowDown className="h-4 w-4" aria-hidden />
                  </Button>
                  <Button
                    variant="ghost"
                    size="icon"
                    className="h-9 w-9 text-alert hover:bg-alert-soft hover:text-alert"
                    onClick={() => onChange(items.filter((_, idx) => idx !== i))}
                    aria-label="আইটেম মুছুন"
                  >
                    <Trash2 className="h-4 w-4" aria-hidden />
                  </Button>
                </span>
              </div>
              <Textarea
                value={item.label}
                onChange={(e) => set(i, { label: e.target.value })}
                placeholder="চেকলিস্টের বিবরণ"
                className="mt-2 min-h-[64px]"
                aria-label={`${toBn(i + 1)} নং আইটেমের বিবরণ`}
              />
            </li>
          ))}
        </ul>
      )}
      <Button
        variant="outline"
        size="sm"
        onClick={() => onChange([...items, { key: "", categoryBn: "", label: "" }])}
      >
        <ListPlus className="h-4 w-4" aria-hidden />
        চেকলিস্ট আইটেম যোগ
      </Button>
    </div>
  );
}

function LevelEditor({
  level,
  info,
}: {
  level: LevelKey;
  info: { node: Record<string, unknown>; source: string };
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const hasChecklist = Array.isArray(info.node.checklistBn);
  const [form, setForm] = React.useState<RulesForm>(() => nodeToForm(info.node));
  const [confirmReset, setConfirmReset] = React.useState(false);

  const set = <K extends keyof RulesForm>(k: K, v: RulesForm[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  const save = useMutation({
    mutationFn: () => api.updateLevelRules(level, formToPatch(form, hasChecklist)),
    onSuccess: (res) => {
      // PUT মার্জ করা নোড ফেরত দেয় — ফর্ম সেটাতেই সিঙ্ক থাকে।
      setForm(nodeToForm(res.node));
      toast(`সংরক্ষিত — ${toBn(res.changed.length)}টি ফিল্ড পরিবর্তিত`, "success");
      qc.invalidateQueries({ queryKey: ["level-rules"] });
    },
    onError: (err: Error) => toast(err.message || "সংরক্ষণ করা যায়নি", "error"),
  });

  const reset = useMutation({
    mutationFn: () => api.resetLevelRules(level),
    onSuccess: async (res) => {
      toast(res.reset ? "প্যাক ডিফল্টে ফিরিয়ে আনা হয়েছে" : "এই স্তরে কোনো ওভাররাইড ছিল না", "success");
      // refetch শেষ হওয়ার পর ফ্রেশ প্যাক-নোড দিয়ে ফর্ম রিসেট।
      await qc.invalidateQueries({ queryKey: ["level-rules"] });
      const fresh = qc.getQueryData<LevelRulesDoc>(["level-rules"]);
      const node = fresh?.levels[level]?.node;
      if (node) setForm(nodeToForm(node));
    },
    onError: (err: Error) => toast(err.message || "রিসেট করা যায়নি", "error"),
  });

  const source = SOURCE_LABELS[info.source] ?? SOURCE_LABELS.default;

  return (
    <Card>
      <CardHeader className="flex-row flex-wrap items-center justify-between gap-2">
        <div>
          <CardTitle className="flex flex-wrap items-center gap-2">
            {LEVEL_LABELS_BN[level]}
            <Badge variant={source.variant}>{source.label}</Badge>
          </CardTitle>
          <CardDescription>
            ইঞ্জিন এই নিয়মই ব্যবহার করে (দাওয়াত শর্ত, উন্নয়ন যাচাই, রাতের স্বয়ংক্রিয় কাজ) · সম্পাদনা
            ডেটাবেস ওভাররাইড হিসেবে জমা হয়
          </CardDescription>
        </div>
        <div className="flex items-center gap-2">
          {info.source === "db" ? (
            <Button variant="outline" size="sm" onClick={() => setConfirmReset(true)}>
              <RotateCcw className="h-4 w-4" aria-hidden />
              প্যাক ডিফল্টে ফেরান
            </Button>
          ) : null}
          <Button size="sm" onClick={() => save.mutate()} disabled={save.isPending}>
            <Save className="h-4 w-4" aria-hidden />
            {save.isPending ? "সংরক্ষণ হচ্ছে…" : "সংরক্ষণ করুন"}
          </Button>
        </div>
      </CardHeader>
      <CardContent className="space-y-5">
        <div className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Field label="স্তরের নাম (বাংলা)" htmlFor={`lr-title-${level}`}>
            <Input
              id={`lr-title-${level}`}
              value={form.titleBn}
              onChange={(e) => set("titleBn", e.target.value)}
              placeholder="যেমন: মুহিব্বুস সুন্নাহ"
            />
          </Field>
          <Field
            label="সময়সীমা (পূর্ণসংখ্যা, মাস)"
            htmlFor={`lr-months-${level}`}
            hint="বর্তমান স্তরে অতিবাহিত হতে হবে এমন ন্যূনতম মাস"
          >
            <Input
              id={`lr-months-${level}`}
              type="number"
              min={0}
              value={form.minMonths}
              onChange={(e) => set("minMonths", e.target.value)}
              placeholder="যেমন: 4"
            />
          </Field>
          <Field label="সময়সীমার প্রদর্শন-লেখা" htmlFor={`lr-months-label-${level}`}>
            <Input
              id={`lr-months-label-${level}`}
              value={form.minMonthsLabelBn}
              onChange={(e) => set("minMonthsLabelBn", e.target.value)}
              placeholder="সময়সীমাঃ সর্বনিম্ন ৪ মাস"
            />
          </Field>
          <Field
            label="ন্যূনতম মাদউ (পূর্ণসংখ্যা)"
            htmlFor={`lr-refs-${level}`}
            hint="এই স্তরে উন্নীন হতে হবে এমন ন্যূনতম রেফার-সদস্য"
          >
            <Input
              id={`lr-refs-${level}`}
              type="number"
              min={0}
              value={form.minReferralsAtLevel}
              onChange={(e) => set("minReferralsAtLevel", e.target.value)}
              placeholder="যেমন: 5"
            />
          </Field>
          <Field label="মাদউ শর্তের প্রদর্শন-লেখা" htmlFor={`lr-refs-label-${level}`}>
            <Input
              id={`lr-refs-label-${level}`}
              value={form.minReferralsLabelBn}
              onChange={(e) => set("minReferralsLabelBn", e.target.value)}
              placeholder="৫ জনকে মুহিব্বুস সুন্নাহ স্তরে আনা"
            />
          </Field>
          <Field
            label="স্বয়ংক্রিয় উন্নয়ন"
            hint="মানব-সাক্ষ্য নির্ভর স্তরে বন্ধই রাখুন — রাতের কাজ সব শর্ত পূরণ পেলে নিজেই উন্নয়ন করে"
          >
            <BoolToggle
              value={form.autoPromote}
              onChange={(v) => set("autoPromote", v)}
              labels={["চালু", "বন্ধ"]}
            />
          </Field>
        </div>

        <fieldset className="space-y-4 rounded-lg border border-border p-4">
          <legend className="px-1.5 text-sm font-bold text-foreground">আউটলাইন রিভিউ (মুহিব্বুস সুন্নাহ মডেল)</legend>
          <Field label="উসরা প্রধানের আউটলাইন রিভিউ দরকার?">
            <BoolToggle
              value={form.outlineReviewRequired}
              onChange={(v) => set("outlineReviewRequired", v)}
              labels={["দরকার", "দরকার নেই"]}
            />
          </Field>
          <Field label="আউটলাইন রিভিউয়ের বর্ণনা" htmlFor={`lr-outline-${level}`}>
            <Textarea
              id={`lr-outline-${level}`}
              value={form.outlineReviewLabelBn}
              onChange={(e) => set("outlineReviewLabelBn", e.target.value)}
              placeholder="উসরা প্রধানের আউটলাইন পর্যালোচনা — প্রতিটি লক্ষ্য আইটেম ধরে ধরে যাচাই"
            />
          </Field>
        </fieldset>

        <fieldset className="space-y-4 rounded-lg border border-border p-4">
          <legend className="px-1.5 text-sm font-bold text-foreground">ফরযে আইন মূল্যায়ন</legend>
          <div className="grid grid-cols-1 gap-4 md:grid-cols-3">
            <Field label="মূল্যায়নে উত্তীর্ণ দরকার?">
              <BoolToggle
                value={form.requireAssessmentPassed}
               onChange={(v) => set("requireAssessmentPassed", v)}
                labels={["দরকার", "দরকার নেই"]}
              />
            </Field>
            <Field label="মূল্যায়ন টেমপ্লেট কী" htmlFor={`lr-akey-${level}`} hint="যেমন: farze_ain_v1.1">
              <Input
                id={`lr-akey-${level}`}
                value={form.assessmentKey}
                onChange={(e) => set("assessmentKey", e.target.value)}
                placeholder="farze_ain_v1.1"
                className="font-mono text-xs"
              />
            </Field>
            <Field label="ক্যাটাগরি (১/২)" htmlFor={`lr-acat-${level}`}>
              <Input
                id={`lr-acat-${level}`}
                type="number"
                min={1}
                max={2}
                value={form.assessmentCategory}
                onChange={(e) => set("assessmentCategory", e.target.value)}
                placeholder="1 বা 2"
              />
            </Field>
          </div>
          <Field label="মূল্যায়নের নিয়ম-বর্ণনা" htmlFor={`lr-arule-${level}`}>
            <Textarea
              id={`lr-arule-${level}`}
              value={form.assessmentRuleBn}
              onChange={(e) => set("assessmentRuleBn", e.target.value)}
              placeholder="একটি ক্যাটাগরির অধিকাংশ ক্রাইটেরিয়া 'সম্পূর্ণ' পর্যায়ে পৌঁছালে…"
            />
          </Field>
          <Field label="ক্যাটাগরির বিবরণ" htmlFor={`lr-adesc-${level}`}>
            <Textarea
              id={`lr-adesc-${level}`}
              value={form.categoryDescriptionBn}
              onChange={(e) => set("categoryDescriptionBn", e.target.value)}
              placeholder="এই ক্যাটাগরি কাদের জন্য…"
            />
          </Field>
        </fieldset>

        <div>
          <h3 className="mb-1 text-sm font-bold text-foreground">
            তারবিয়াত চেকলিস্ট{" "}
            <span className="font-normal text-muted-foreground">({toBn(form.checklist.length)}টি আইটেম)</span>
          </h3>
          <p className="mb-3 text-xs leading-relaxed text-muted-foreground">
            মূলত মুহিব্বুস সুন্নাহ স্তরের আউটলাইন লক্ষ্যগুলো — বিভাগ + বিবরণ ধরে ধরে সাজানো।
          </p>
          <ChecklistEditor items={form.checklist} onChange={(items) => set("checklist", items)} />
        </div>
      </CardContent>

      <Dialog
        open={confirmReset}
        onClose={() => setConfirmReset(false)}
        title="প্যাক ডিফল্টে ফেরান?"
        description={`${LEVEL_LABELS_BN[level]} স্তরের ডেটাবেস ওভাররাইড মুছে যাবে — নিয়ম আবার প্যাক ফাইল অনুযায়ী চলবে।`}
        footer={
          <>
            <Button variant="outline" onClick={() => setConfirmReset(false)}>
              বাতিল
            </Button>
            <Button
              variant="destructive"
              loading={reset.isPending}
              onClick={() => reset.mutate(undefined, { onSettled: () => setConfirmReset(false) })}
            >
              <RotateCcw className="h-4 w-4" aria-hidden />
              হ্যাঁ, রিসেট করুন
            </Button>
          </>
        }
      >
        <p className="text-sm leading-relaxed text-muted-foreground">
          এই কাজটি অডিট লগে সংরক্ষিত হয়। ভুল হলে আবার সম্পাদনা করে নতুন ওভাররাইড বসাতে পারবেন।
        </p>
      </Dialog>
    </Card>
  );
}

export default function LevelRulesPage() {
  const { user } = useSession();
  const fullAdmin = isFullAdmin(user?.role);
  const [active, setActive] = React.useState<LevelKey>("muhibbus_sunnah");

  const rules = useQuery<LevelRulesDoc>({
    queryKey: ["level-rules"],
    queryFn: () => api.levelRules(),
    enabled: fullAdmin,
  });

  return (
    <RoleGate allow={isFullAdmin} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<SlidersHorizontal className="h-6 w-6" aria-hidden />}
          title="লেভেল রুলস"
          description="স্তর উন্নয়নের নিয়মকানুন সম্পাদনা — প্যাক সিডের ওপরে ডেটাবেস ওভাররাইড, প্রতিটি পরিবর্তন অডিট-লগড।"
        />

        {rules.isLoading ? (
          <div className="space-y-3">
            <div className="skeleton h-10 w-64" />
            <div className="skeleton h-96" />
          </div>
        ) : rules.isError ? (
          <ErrorState error={rules.error} onRetry={() => rules.refetch()} />
        ) : (
          <div className="space-y-4">
            {rules.data?.packNote ? (
              <div className="rounded-lg border border-gold/40 bg-gold-soft/60 p-3.5 text-xs leading-relaxed text-foreground dark:text-gold">
                {rules.data.packNote}
              </div>
            ) : null}

            <div role="tablist" aria-label="স্তর নির্বাচন" className="flex flex-wrap gap-2">
              {LEVEL_KEYS.map((key) => {
                const info = rules.data?.levels[key];
                const isActive = active === key;
                return (
                  <button
                    key={key}
                    type="button"
                    role="tab"
                    aria-selected={isActive}
                    onClick={() => setActive(key)}
                    className={cn(
                      "focus-ring min-h-11 rounded-md border px-4 py-2 text-sm font-semibold transition-colors duration-200",
                      isActive
                        ? "border-primary bg-primary text-primary-foreground shadow-card"
                        : "border-border bg-card text-muted-foreground hover:bg-primary-soft hover:text-primary"
                    )}
                  >
                    {LEVEL_LABELS_BN[key]}
                    {info?.source === "db" ? <span className="ms-1.5" aria-hidden>●</span> : null}
                  </button>
                );
              })}
            </div>

            {rules.data?.levels[active] ? (
              <LevelEditor key={active} level={active} info={rules.data.levels[active]} />
            ) : (
              <p className="rounded-md border border-dashed border-border p-6 text-center text-sm text-muted-foreground">
                এই স্তরের নিয়ম পাওয়া যায়নি।
              </p>
            )}
          </div>
        )}
      </div>
    </RoleGate>
  );
}
