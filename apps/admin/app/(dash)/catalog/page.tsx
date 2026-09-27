"use client";

// আমল ক্যাটালগ এডিটর (full_admin) — DB-configurable AmalDefinition editor.
// The catalog drives the Muhasaba diary on every client; edits are audit-safe:
// upsert by key via /api/admin/amal-catalog, partial PATCH by key, and
// reorder (up/down) via PATCH /api/admin/amal-catalog {keys}.

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { ArrowDown, ArrowUp, ListChecks, Pencil, Plus, Power } from "lucide-react";
import { api, type AmalCadence, type AmalCategory, type AmalDefinition, type AmalInputType, type Level } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn } from "@/lib/bn";
import {
  AMAL_CATEGORY_LABELS_BN,
  CADENCE_LABELS_BN,
  INPUT_TYPE_LABELS_BN,
  LEVEL_LABELS_BN,
} from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Select } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";
import { PageHeading, RoleGate } from "@/components/ui/states";

const CADENCE_OPTIONS: AmalCadence[] = [
  "daily",
  "weekly:fri",
  "weekly:mon_thu",
  "monthly:ayyam_beez",
];
const INPUT_TYPE_OPTIONS: AmalInputType[] = ["tristate", "boolean", "count", "quantity", "text"];
const CATEGORY_OPTIONS: AmalCategory[] = [
  "salah",
  "quran",
  "dhikr",
  "akhlaq",
  "dawat",
  "lifestyle",
  "sunnah",
  "personal",
];
const LEVEL_OPTIONS: Level[] = ["none", "muhibbus_sunnah", "farze_ain_1", "farze_ain_2"];

interface CatalogForm {
  key: string;
  titleBn: string;
  titleEn: string;
  category: AmalCategory;
  inputType: AmalInputType;
  cadence: AmalCadence;
  sortOrder: number;
  unit: string;
  minLevel: Level;
  targetGeneral: string;
  targetHafez: string;
  targetAlim: string;
  autoSource: string;
  active: boolean;
}

function definitionToForm(d: AmalDefinition): CatalogForm {
  return {
    key: d.key,
    titleBn: d.titleBn,
    titleEn: d.titleEn,
    category: d.category,
    inputType: d.inputType,
    cadence: d.cadence,
    sortOrder: d.sortOrder,
    unit: d.unit ?? "",
    minLevel: d.minLevel,
    targetGeneral: d.target ? String(d.target.general ?? "") : "",
    targetHafez: d.target ? String(d.target.hafez ?? "") : "",
    targetAlim: d.target ? String(d.target.alim ?? "") : "",
    autoSource: d.autoSource ?? "",
    active: d.active !== false,
  };
}

function CatalogDialog({
  initial,
  onClose,
}: {
  initial: AmalDefinition | null; // null = create new
  onClose: () => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [form, setForm] = React.useState<CatalogForm>(() =>
    initial
      ? definitionToForm(initial)
      : {
          key: "",
          titleBn: "",
          titleEn: "",
          category: "salah",
          inputType: "boolean",
          cadence: "daily",
          sortOrder: 100,
          unit: "",
          minLevel: "none",
          targetGeneral: "",
          targetHafez: "",
          targetAlim: "",
          autoSource: "",
          active: true,
        },
  );
  const [confirmKey, setConfirmKey] = React.useState("");

  const set = <K extends keyof CatalogForm>(k: K, v: CatalogForm[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  const needsTarget = form.inputType === "count" || form.inputType === "quantity";

  const save = useMutation({
    mutationFn: async () => {
      const target: Record<string, number> = {};
      if (form.targetGeneral !== "") target.general = Number(form.targetGeneral);
      if (form.targetHafez !== "") target.hafez = Number(form.targetHafez);
      if (form.targetAlim !== "") target.alim = Number(form.targetAlim);
      return api.upsertCatalog({
        key: form.key,
        titleBn: form.titleBn,
        titleEn: form.titleEn,
        category: form.category,
        inputType: form.inputType,
        cadence: form.cadence,
        sortOrder: form.sortOrder,
        unit: form.unit || null,
        minLevel: form.minLevel,
        target: needsTarget && Object.keys(target).length ? target : null,
        autoSource: form.autoSource || null,
        active: form.active,
      });
    },
    onSuccess: () => {
      toast("ক্যাটালগ সংরক্ষণ করা হয়েছে", "success");
      qc.invalidateQueries({ queryKey: ["admin-catalog"] });
      qc.invalidateQueries({ queryKey: ["definitions"] });
      onClose();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const keyMismatch = !!initial ? confirmKey !== initial.key : false;

  return (
    <Dialog
      open
      onClose={onClose}
      title={initial ? "আমল সম্পাদনা" : "নতুন আমল যোগ করুন"}
      description="ক্যাটালগ পরিবর্তন সব ব্যবহারকারীর ডায়েরিতে সাথে সাথেই প্রভাবিত করে।"
      wide
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            onClick={() => save.mutate()}
            disabled={
              save.isPending ||
              !form.key.trim() ||
              !form.titleBn.trim() ||
              (needsTarget && !form.targetGeneral)
            }
          >
            {save.isPending ? "সংরক্ষণ হচ্ছে…" : "সংরক্ষণ করুন"}
          </Button>
        </>
      }
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="কী (key)" hint="ইংরেজি, ছোট হাতের অক্ষর ও আন্ডারস্কোর — যেমন salat_fajr">
          <Input
            value={form.key}
            onChange={(e) => set("key", e.target.value)}
            disabled={!!initial}
            placeholder="salat_fajr"
            aria-label="আমল কী"
          />
        </Field>
        <Field label="ক্রম (sort)" hint="আজকের পাতায় যে ক্রমে দেখাবে">
          <Input
            type="number"
            value={form.sortOrder}
            onChange={(e) => set("sortOrder", Number(e.target.value))}
            aria-label="ক্রম"
          />
        </Field>
        <Field label="শিরোনাম (বাংলা)">
          <Input value={form.titleBn} onChange={(e) => set("titleBn", e.target.value)} aria-label="শিরোনাম বাংলা" />
        </Field>
        <Field label="শিরোনাম (ইংরেজি)">
          <Input value={form.titleEn} onChange={(e) => set("titleEn", e.target.value)} aria-label="শিরোনাম ইংরেজি" />
        </Field>
        <Field label="বিভাগ">
          <Select value={form.category} onChange={(e) => set("category", e.target.value as AmalCategory)} aria-label="বিভাগ">
            {CATEGORY_OPTIONS.map((c) => (
              <option key={c} value={c}>
                {AMAL_CATEGORY_LABELS_BN[c]}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="ইনপুট ধরন">
          <Select value={form.inputType} onChange={(e) => set("inputType", e.target.value as AmalInputType)} aria-label="ইনপুট ধরন">
            {INPUT_TYPE_OPTIONS.map((t) => (
              <option key={t} value={t}>
                {INPUT_TYPE_LABELS_BN[t]}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="নিয়মিতা (cadence)">
          <Select value={form.cadence} onChange={(e) => set("cadence", e.target.value as AmalCadence)} aria-label="নিয়মিতা">
            {CADENCE_OPTIONS.map((c) => (
              <option key={c} value={c}>
                {CADENCE_LABELS_BN[c] ?? c}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="সর্বনিম্ন স্তর" hint="এই স্তরের নিচে থাকলে ডায়েরিতে দেখাবে না">
          <Select value={form.minLevel} onChange={(e) => set("minLevel", e.target.value as Level)} aria-label="সর্বনিম্ন স্তর">
            {LEVEL_OPTIONS.map((l) => (
              <option key={l} value={l}>
                {LEVEL_LABELS_BN[l]}
              </option>
            ))}
          </Select>
        </Field>
        {needsTarget ? (
          <>
            <Field label="লক্ষ্য — সাধারণ" hint={form.unit ? `একক: ${form.unit}` : "সংখ্যা"}>
              <Input
                type="number"
                value={form.targetGeneral}
                onChange={(e) => set("targetGeneral", e.target.value)}
                aria-label="সাধারণ লক্ষ্য"
              />
            </Field>
            <Field label="লক্ষ্য — হাফেজ">
              <Input
                type="number"
                value={form.targetHafez}
                onChange={(e) => set("targetHafez", e.target.value)}
                aria-label="হাফেজ লক্ষ্য"
              />
            </Field>
            <Field label="লক্ষ্য — আলেম">
              <Input
                type="number"
                value={form.targetAlim}
                onChange={(e) => set("targetAlim", e.target.value)}
                aria-label="আলেম লক্ষ্য"
              />
            </Field>
            <Field label="একক" hint="যেমন: পারা, পৃষ্ঠা, মিনিট, বার">
              <Input value={form.unit} onChange={(e) => set("unit", e.target.value)} aria-label="একক" />
            </Field>
          </>
        ) : null}
        <Field label="অটো-উৎস (auto_source)" hint="কোন অ্যাপ ফিচার শেষ হলে স্বয়ংক্রিয়ভাবে টিক হবে — যেমন adhkar:morning">
          <Input value={form.autoSource} onChange={(e) => set("autoSource", e.target.value)} aria-label="অটো উৎস" />
        </Field>
        <Field label="সচল">
          <Select value={form.active ? "1" : "0"} onChange={(e) => set("active", e.target.value === "1")} aria-label="সচল">
            <option value="1">সচল (ডায়েরিতে দেখাবে)</option>
            <option value="0">নিষ্ক্রিয়</option>
          </Select>
        </Field>
      </div>
      {initial ? (
        <Field
          label={`নিশ্চিত করতে কী-টি লিখুন: ${initial.key}`}
          hint="বিদ্যমান আমলের শিরোনাম/লক্ষ্য বদলালে ইতিহাস একই থাকে, কী অপরিবর্তিত থাকে।"
        >
          <Input value={confirmKey} onChange={(e) => setConfirmKey(e.target.value)} aria-label="নিশ্চিতকরণ কী" />
        </Field>
      ) : null}
      {initial && keyMismatch ? (
        <p className="text-sm text-alert" role="alert">
          কী মিলছে না — হুবহু <code>{initial.key}</code> লিখুন।
        </p>
      ) : null}
    </Dialog>
  );
}

export default function CatalogPage() {
  const { user, fullAdmin } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  // B6: the ADMIN catalog — every definition incl. inactive, current sortOrder.
  const defs = useQuery({
    queryKey: ["admin-catalog"],
    queryFn: () => api.adminCatalog(),
    enabled: !!user && fullAdmin,
  });
  const [editing, setEditing] = React.useState<AmalDefinition | null>(null);
  const [creating, setCreating] = React.useState(false);

  const rows = defs.data?.definitions ?? [];

  const reorder = useMutation({
    mutationFn: (keys: string[]) => api.reorderCatalog(keys),
    onSuccess: () => {
      qc.invalidateQueries({ queryKey: ["admin-catalog"] });
      qc.invalidateQueries({ queryKey: ["definitions"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const move = (index: number, delta: -1 | 1) => {
    const target = index + delta;
    if (target < 0 || target >= rows.length) return;
    const keys = rows.map((r) => r.key);
    [keys[index], keys[target]] = [keys[target], keys[index]];
    reorder.mutate(keys);
  };

  const toggleActive = useMutation({
    mutationFn: ({ key, active }: { key: string; active: boolean }) =>
      api.patchCatalog(key, { active }),
    onSuccess: () => {
      toast("অবস্থা পরিবর্তিত হয়েছে (অডিট লগড)", "success");
      qc.invalidateQueries({ queryKey: ["admin-catalog"] });
      qc.invalidateQueries({ queryKey: ["definitions"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const columns = React.useMemo<ColumnDef<AmalDefinition, unknown>[]>(
    () => [
      {
        accessorKey: "sortOrder",
        header: "ক্রম",
        cell: (c) => <span className="tabular-nums">{toBn(c.getValue<number>())}</span>,
      },
      {
        accessorKey: "key",
        header: "কী",
        cell: (c) => (
          <span className="font-mono text-xs text-muted-foreground">{String(c.getValue())}</span>
        ),
      },
      {
        accessorKey: "titleBn",
        header: "আমল",
        cell: (c) => (
          <div className="flex flex-col">
            <span className="font-semibold">{String(c.getValue())}</span>
            <span className="text-xs text-muted-foreground">
              {c.row.original.titleEn}
              {c.row.original.autoSource ? (
                <span className="ml-2 rounded bg-gold/15 px-1.5 py-0.5 text-[10px] font-bold text-gold">
                  অটো
                </span>
              ) : null}
            </span>
          </div>
        ),
      },
      {
        accessorKey: "category",
        header: "বিভাগ",
        cell: (c) => AMAL_CATEGORY_LABELS_BN[c.getValue<AmalCategory>()],
      },
      {
        accessorKey: "inputType",
        header: "ইনপুট",
        cell: (c) => INPUT_TYPE_LABELS_BN[c.getValue<AmalInputType>()],
      },
      {
        accessorKey: "cadence",
        header: "নিয়মিতা",
        cell: (c) => CADENCE_LABELS_BN[c.getValue<AmalCadence>()] ?? String(c.getValue()),
      },
      {
        accessorKey: "target",
        header: "লক্ষ্য",
        cell: (c) => {
          const t = c.getValue<Record<string, number> | null>();
          if (!t) return <span className="text-muted-foreground">—</span>;
          return (
            <span className="text-xs">
              {(["general", "hafez", "alim"] as const)
                .filter((k) => t[k] !== undefined)
                .map((k) => `${k === "general" ? "সাধারণ" : k === "hafez" ? "হাফেজ" : "আলেম"} ${toBn(t[k])}`)
                .join(" · ")}
            </span>
          );
        },
      },
      {
        id: "reorder",
        header: "",
        cell: (c) => {
          const i = c.row.index;
          return (
            <span className="flex items-center gap-0.5">
              <Button
                variant="ghost"
                size="sm"
                aria-label={`${c.row.original.titleBn} উপরে সরান`}
                disabled={reorder.isPending || i === 0}
                onClick={(e) => {
                  e.stopPropagation();
                  move(i, -1);
                }}
              >
                <ArrowUp className="h-4 w-4" aria-hidden />
              </Button>
              <Button
                variant="ghost"
                size="sm"
                aria-label={`${c.row.original.titleBn} নিচে সরান`}
                disabled={reorder.isPending || i === rows.length - 1}
                onClick={(e) => {
                  e.stopPropagation();
                  move(i, 1);
                }}
              >
                <ArrowDown className="h-4 w-4" aria-hidden />
              </Button>
            </span>
          );
        },
      },
      {
        accessorKey: "active",
        header: "অবস্থা",
        cell: (c) =>
          c.row.original.active !== false ? (
            <Badge variant="success">সচল</Badge>
          ) : (
            <Badge variant="muted">নিষ্ক্রিয়</Badge>
          ),
      },
      {
        id: "actions",
        header: "",
        cell: (c) => (
          <span className="flex items-center gap-0.5">
            <Button
              variant="ghost"
              size="sm"
              aria-label={`${c.row.original.titleBn} ${c.row.original.active !== false ? "নিষ্ক্রিয়" : "সচল"} করুন`}
              disabled={toggleActive.isPending}
              onClick={(e) => {
                e.stopPropagation();
                toggleActive.mutate({
                  key: c.row.original.key,
                  active: c.row.original.active === false,
                });
              }}
            >
              <Power className="h-4 w-4" aria-hidden />
            </Button>
            <Button
              variant="ghost"
              size="sm"
              aria-label={`${c.row.original.titleBn} সম্পাদনা`}
              onClick={(e) => {
                e.stopPropagation();
                setEditing(c.row.original);
              }}
            >
              <Pencil className="h-4 w-4" aria-hidden />
            </Button>
          </span>
        ),
      },
    ],
    [rows.length, reorder.isPending, toggleActive.isPending],
  );

  return (
    <RoleGate allow={(r) => r === "full_admin"} role={user?.role}>
      <div className="space-y-6">
      <PageHeading
        icon={<ListChecks className="h-6 w-6" aria-hidden />}
        title="আমল ক্যাটালগ"
        description="মুহাসাবা ডায়েরির সব আমল — ক্রম, লক্ষ্য ও নিয়মিতা এখান থেকে নিয়ন্ত্রিত হয়।"
        action={
          <Button onClick={() => setCreating(true)}>
            <Plus className="h-4 w-4" aria-hidden />
            নতুন আমল
          </Button>
        }
      />
      <Card>
        <CardHeader>
          <CardTitle>ক্যাটালগ ({toBn(defs.data?.definitions.length ?? 0)} টি)</CardTitle>
          <CardDescription>
            লক্ষ্য বিভাগভিত্তিক (সাধারণ / হাফেজ / আলেম)। অটো-চিহ্নিত আমল অ্যাপের সংশ্লিষ্ট ফিচার শেষ করলে নিজে থেকেই টিক হয়।
          </CardDescription>
        </CardHeader>
        <CardContent>
          <DataTable
            columns={columns}
            data={rows}
            loading={defs.isLoading}
            error={defs.error}
            onRetry={() => defs.refetch()}
            emptyTitle="কোনো আমল সংজ্ঞা নেই"
            emptyHint="ক্যাটালগ খালি — নতুন আমল যোগ করুন (খালি থাকলে কনটেন্ট প্যাক থেকে স্বয়ংক্রিয়ভাবে আসবে)।"
            csvFilename="amal-catalog.csv"
            csvHeaders={["কী", "শিরোনাম (বাংলা)", "শিরোনাম (ইংরেজি)", "বিভাগ", "ইনপুট", "নিয়মিতা", "ক্রম", "সচল"]}
            csvRow={(d) => [d.key, d.titleBn, d.titleEn, d.category, d.inputType, d.cadence, d.sortOrder, d.active === false ? "না" : "হ্যাঁ"]}
          />
          <p className="mt-2 text-xs text-muted-foreground">
            উপরে/নিচে তীর চিহ্নে ক্রম বদলান — পরিবর্তন অডিট লগে সংরক্ষিত হয় এবং সব ব্যবহারকারীর ডায়েরিতে প্রযোজ্য।
          </p>
        </CardContent>
      </Card>
      {editing ? <CatalogDialog initial={editing} onClose={() => setEditing(null)} /> : null}
      {creating ? <CatalogDialog initial={null} onClose={() => setCreating(false)} /> : null}
      </div>
    </RoleGate>
  );
}
