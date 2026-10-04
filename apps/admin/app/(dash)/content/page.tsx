"use client";

// কন্টেন্ট ম্যানেজমেন্ট (full_admin) — W4h। PUT /api/admin/content/:pack যেসব
// প্যাক লিখতে দেয় সেগুলোর CMS: faq / articles / mosques / duas-এর জন্য
// ফিল্ড-কনফিগার-চালিত তালিকা + সংযোজন/সম্পাদনা/মুছে ফেলা/স্থানান্তর এডিটর;
// courses / quizzes-এ প্রতিটি এন্ট্রির ভেতরে পাঠ / প্রশ্নের নেস্টেড তালিকা
// (একই সম্পাদক, এক ধাপ ভেতরে)। সংরক্ষণ = গোটা প্যাক ডকুমেন্ট অ্যাটমিকভাবে
// বদলানো (PUT), অন্যান্য টপ-লেভেল কী অক্ষত থাকে; প্রতিটি সংরক্ষণ অডিট লগ হয়।
// সংরক্ষণ API-র স্থায়ী স্টোরেজ ভলিউমে যায় — রিডেপ্লয়েও টিকে থাকে।

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { ArrowDown, ArrowUp, BookOpen, Info, Pencil, Plus, Save, Trash2 } from "lucide-react";
import { api } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn } from "@/lib/bn";
import { isFullAdmin } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Textarea } from "@/components/ui/input";
import { Tabs, TabsList, TabsPanel, TabsTrigger } from "@/components/ui/tabs";
import { ErrorState, PageHeading, RoleGate } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

/** PUT-এ অনুমোদিত প্যাকগুলো (apps/api CMS_PACKS)। */
type EditablePack = "faq" | "articles" | "mosques" | "duas" | "courses" | "quizzes";

interface PackField {
  key: string;
  label: string;
  /** bool = checkbox; lines = one array element per line (quiz options) */
  type: "text" | "textarea" | "number" | "bool" | "lines";
  required?: boolean;
  hint?: string;
  rtl?: boolean;
}

/** A nested list inside each entry (a course's lessons, a quiz's questions). */
interface ChildConfig {
  key: string;
  labelBn: string;
  titleKey: string;
  fields: PackField[];
  /** checks one child before it joins the list; returns an error or null */
  validate?: (v: Record<string, unknown>) => string | null;
}

interface PackConfig {
  labelBn: string;
  arrayKey: string;
  titleKey: string;
  subtitleKey: string;
  fields: PackField[];
  child?: ChildConfig;
}

const PACK_CONFIGS: Record<EditablePack, PackConfig> = {
  faq: {
    labelBn: "জিজ্ঞাসা (FAQ)",
    arrayKey: "items",
    titleKey: "q",
    subtitleKey: "a",
    fields: [
      { key: "q", label: "প্রশ্ন", type: "textarea", required: true },
      { key: "a", label: "উত্তর", type: "textarea", required: true },
    ],
  },
  articles: {
    labelBn: "আর্টিকেল",
    arrayKey: "items",
    titleKey: "titleBn",
    subtitleKey: "excerptBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true, hint: "যেমন: muhasaba-daily" },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "excerptBn", label: "সার-সংক্ষেপ", type: "textarea" },
      { key: "category", label: "বিভাগ", type: "text", hint: "যেমন: tarbiyah / dawah / sunnah" },
      { key: "readMinutes", label: "পড়ার সময় (মিনিট)", type: "number" },
      { key: "publishedAt", label: "প্রকাশের তারিখ", type: "text", hint: "YYYY-MM-DD" },
      { key: "bodyBn", label: "মূল লেখা", type: "textarea", hint: "অনুচ্ছেদ আলাদা করতে খালি লাইন দিন" },
    ],
  },
  mosques: {
    labelBn: "মসজিদ তালিকা",
    arrayKey: "mosques",
    titleKey: "nameBn",
    subtitleKey: "addressBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true, hint: "যেমন: msj-baitul-mukarram" },
      { key: "nameBn", label: "নাম (বাংলা)", type: "text", required: true },
      { key: "nameEn", label: "নাম (ইংরেজি)", type: "text" },
      { key: "addressBn", label: "ঠিকানা", type: "text" },
      { key: "area", label: "এলাকা", type: "text" },
      { key: "lat", label: "অক্ষাংশ (lat)", type: "number" },
      { key: "lng", label: "দ্রাঘিমাংশ (lng)", type: "number" },
    ],
  },
  duas: {
    labelBn: "দোয়া সংকলন",
    arrayKey: "items",
    titleKey: "titleBn",
    subtitleKey: "translationBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true },
      { key: "category", label: "বিভাগ কী", type: "text", required: true, hint: "প্যাকের categories-এর key" },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "arabic", label: "আরবি", type: "textarea", rtl: true },
      { key: "translitBn", label: "উচ্চারণ", type: "textarea" },
      { key: "translationBn", label: "বাংলা অনুবাদ", type: "textarea", required: true },
      { key: "reference", label: "দলিল", type: "text" },
      { key: "virtue", label: "ফজিলত", type: "text" },
    ],
  },
  courses: {
    labelBn: "কোর্স",
    arrayKey: "courses",
    titleKey: "titleBn",
    subtitleKey: "descBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true, hint: "যেমন: course-salah-basics (পরে বদলাবেন না — সদস্যদের অগ্রগতি এতে বাঁধা)" },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "descBn", label: "বিবরণ", type: "textarea", required: true },
      { key: "level", label: "স্তর", type: "text", hint: "যেমন: মুহিব্বুস সুন্নাহ" },
    ],
    child: {
      key: "lessons",
      labelBn: "পাঠ",
      titleKey: "titleBn",
      fields: [
        { key: "id", label: "পাঠের আইডি", type: "text", required: true, hint: "যেমন: salah-01-intro" },
        { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
        { key: "minutes", label: "সময় (মিনিট)", type: "number", required: true },
        { key: "order", label: "ক্রম", type: "number", hint: "খালি রাখলে তালিকার ক্রমই থাকবে" },
        { key: "bodyBn", label: "পাঠের লেখা", type: "textarea", required: true, hint: "অনুচ্ছেদ আলাদা করতে খালি লাইন দিন" },
      ],
    },
  },
  quizzes: {
    labelBn: "কুইজ",
    arrayKey: "quizzes",
    titleKey: "titleBn",
    subtitleKey: "descBn",
    fields: [
      { key: "id", label: "আইডি", type: "text", required: true, hint: "যেমন: quiz-salah (পরে বদলাবেন না — ফলাফল এতে বাঁধা)" },
      { key: "titleBn", label: "শিরোনাম", type: "text", required: true },
      { key: "descBn", label: "বিবরণ", type: "textarea" },
      { key: "category", label: "বিভাগ", type: "text", hint: "যেমন: salah / aqeedah / quran_sunnah" },
      { key: "minutes", label: "সময় (মিনিট)", type: "number" },
      { key: "live", label: "লাইভ কুইজে ব্যবহারযোগ্য", type: "bool" },
    ],
    child: {
      key: "questions",
      labelBn: "প্রশ্ন",
      titleKey: "questionBn",
      fields: [
        { key: "id", label: "প্রশ্নের আইডি", type: "text", required: true, hint: "যেমন: qs-11" },
        { key: "questionBn", label: "প্রশ্ন", type: "textarea", required: true },
        { key: "options", label: "অপশন (প্রতি লাইনে একটি)", type: "lines", required: true, hint: "২–৬টি অপশন, প্রতিটি আলাদা লাইনে" },
        { key: "answerIndex", label: "সঠিক উত্তর (অপশনের ক্রম, ১ থেকে)", type: "number", required: true },
        { key: "explanationBn", label: "ব্যাখ্যা", type: "textarea" },
        { key: "difficulty", label: "কাঠিন্য", type: "text", hint: "easy / medium / hard" },
      ],
      validate: (v) => {
        const opts = Array.isArray(v.options) ? v.options : [];
        if (opts.length < 2 || opts.length > 6) return "২ থেকে ৬টি অপশন দিন";
        const a = Number(v.answerIndex);
        if (!Number.isInteger(a) || a < 0 || a >= opts.length) return "সঠিক উত্তরের ক্রম অপশনের মধ্যে হতে হবে";
        return null;
      },
    },
  },
};

/** Stored → form: answerIndex is 0-based in the pack, 1-based in the form. */
function toForm(f: PackField, raw: unknown): string {
  if (raw === undefined || raw === null) return "";
  if (f.type === "lines" && Array.isArray(raw)) return raw.map(String).join("\n");
  if (f.key === "answerIndex" && typeof raw === "number") return String(raw + 1);
  return String(raw);
}

/** API-র ৯০ কিলোবাইট সীমার নিরাপদ মার্জিনে ক্লায়েন্ট-সাইড সতর্কতা। */
const SIZE_LIMIT = 90_000;

function truncate(s: unknown, n = 110): string {
  const str = typeof s === "string" ? s : "";
  return str.length > n ? `${str.slice(0, n)}…` : str;
}

function PackItemDialog({
  title,
  fields,
  initial,
  child,
  onClose,
  onSubmit,
}: {
  title: string;
  fields: PackField[];
  initial: Record<string, unknown> | null;
  child?: ChildConfig;
  onClose: () => void;
  onSubmit: (values: Record<string, unknown>) => void;
}) {
  const { toast } = useToast();
  const [values, setValues] = React.useState<Record<string, string>>(() => {
    const v: Record<string, string> = {};
    for (const f of fields) v[f.key] = toForm(f, initial?.[f.key]);
    return v;
  });
  const [children, setChildren] = React.useState<Record<string, unknown>[]>(() =>
    child && Array.isArray(initial?.[child.key]) ? (initial![child.key] as Record<string, unknown>[]) : []
  );
  const [editingChild, setEditingChild] = React.useState<{ index: number | null } | null>(null);

  const submit = () => {
    for (const f of fields) {
      if (f.required && f.type !== "bool" && !values[f.key].trim()) {
        toast(`${f.label} দরকার`, "error");
        return;
      }
    }
    const out: Record<string, unknown> = {};
    for (const f of fields) {
      const v = values[f.key].trim();
      if (f.type === "bool") {
        out[f.key] = v === "true";
        continue;
      }
      if (v === "") continue; // খালি ফিল্ড প্যাকে যায় না
      if (f.type === "lines") {
        out[f.key] = v.split("\n").map((x) => x.trim()).filter(Boolean);
      } else if (f.type === "number") {
        out[f.key] = f.key === "answerIndex" ? Number(v) - 1 : Number(v);
      } else {
        out[f.key] = v;
      }
    }
    // সংখ্যা ক্ষেত্র NaN হলে আটকাও
    for (const f of fields) {
      if (f.type === "number" && f.key in out && !Number.isFinite(out[f.key] as number)) {
        toast(`${f.label} সংখ্যা হতে হবে`, "error");
        return;
      }
    }
    if (child) {
      if (!children.length) {
        toast(`অন্তত একটি ${child.labelBn} দিন`, "error");
        return;
      }
      out[child.key] = children;
    }
    onSubmit(out);
  };

  return (
    <Dialog
      open
      onClose={onClose}
      wide
      title={title}
      description="সংরক্ষণ বাটন পুরো প্যাক ফাইলে লেখে — আগে তালিকায় যোগ হবে, তারপর উপরের «সংরক্ষণ করুন» চাপুন।"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button onClick={submit}>
            <Plus className="h-4 w-4" aria-hidden />
            তালিকায় যোগ করুন
          </Button>
        </>
      }
    >
      <div className="space-y-4">
        {fields.map((f) => (
          <Field key={f.key} label={f.label + (f.required ? " *" : "")} htmlFor={`pk-${f.key}`} hint={f.hint}>
            {f.type === "bool" ? (
              <input
                id={`pk-${f.key}`}
                type="checkbox"
                className="h-5 w-5 accent-[var(--primary)]"
                checked={values[f.key] === "true"}
                onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.checked ? "true" : "false" }))}
              />
            ) : f.type === "textarea" || f.type === "lines" ? (
              <Textarea
                id={`pk-${f.key}`}
                dir={f.rtl ? "rtl" : undefined}
                value={values[f.key]}
                onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
                className={f.key === "bodyBn" ? "min-h-[280px]" : f.rtl ? "min-h-[96px] text-lg leading-loose" : undefined}
              />
            ) : (
              <Input
                id={`pk-${f.key}`}
                type={f.type === "number" ? "number" : "text"}
                inputMode={f.type === "number" ? "decimal" : undefined}
                step={f.type === "number" ? "any" : undefined}
                dir={f.rtl ? "rtl" : undefined}
                value={values[f.key]}
                onChange={(e) => setValues((v) => ({ ...v, [f.key]: e.target.value }))}
              />
            )}
          </Field>
        ))}
        {child ? (
          <div className="rounded-lg border border-border p-3">
            <div className="mb-2 flex items-center justify-between">
              <p className="text-sm font-semibold">
                {child.labelBn} <Badge variant="muted">{toBn(children.length)}</Badge>
              </p>
              <Button variant="outline" size="sm" onClick={() => setEditingChild({ index: null })}>
                <Plus className="h-4 w-4" aria-hidden />
                নতুন {child.labelBn}
              </Button>
            </div>
            <ul className="divide-y divide-border">
              {children.map((c, i) => (
                <li key={i} className="flex items-center gap-2 py-2 text-sm">
                  <span className="w-6 shrink-0 text-center text-xs font-bold text-primary">{toBn(i + 1)}</span>
                  <span className="min-w-0 flex-1 truncate">{truncate(c[child.titleKey], 80) || "(শিরোনাম নেই)"}</span>
                  <Button variant="ghost" size="icon" className="h-8 w-8" disabled={i === 0} aria-label="উপরে" onClick={() => {
                    const n = [...children];
                    [n[i - 1], n[i]] = [n[i], n[i - 1]];
                    setChildren(n);
                  }}>
                    <ArrowUp className="h-4 w-4" aria-hidden />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-8 w-8" disabled={i === children.length - 1} aria-label="নিচে" onClick={() => {
                    const n = [...children];
                    [n[i], n[i + 1]] = [n[i + 1], n[i]];
                    setChildren(n);
                  }}>
                    <ArrowDown className="h-4 w-4" aria-hidden />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-8 w-8" aria-label="সম্পাদনা" onClick={() => setEditingChild({ index: i })}>
                    <Pencil className="h-4 w-4" aria-hidden />
                  </Button>
                  <Button variant="ghost" size="icon" className="h-8 w-8 text-alert" aria-label="মুছে ফেলুন" onClick={() => setChildren(children.filter((_, x) => x !== i))}>
                    <Trash2 className="h-4 w-4" aria-hidden />
                  </Button>
                </li>
              ))}
            </ul>
          </div>
        ) : null}
      </div>
      {child && editingChild ? (
        <PackItemDialog
          title={editingChild.index === null ? `নতুন ${child.labelBn}` : `${child.labelBn} সম্পাদনা`}
          fields={child.fields}
          initial={editingChild.index === null ? null : children[editingChild.index]}
          onClose={() => setEditingChild(null)}
          onSubmit={(v) => {
            const err = child.validate?.(v) ?? null;
            if (err) {
              toast(err, "error");
              return;
            }
            setChildren(
              editingChild.index === null
                ? [...children, v]
                : children.map((c, x) => (x === editingChild.index ? { ...c, ...v } : c))
            );
            setEditingChild(null);
          }}
        />
      ) : null}
    </Dialog>
  );
}

function PackEditor({
  pack,
  editedItems,
  onItemsChange,
}: {
  pack: EditablePack;
  /** প্যাক-ভেদে সম্পাদনা ক্যাশে — পেজ-লেভেলে থাকে, ট্যাব বদলালেও অসংরক্ষিত কাজ হারায় না (TabsPanel আনমাউন্ট করে)। */
  editedItems: Record<string, unknown>[] | null;
  onItemsChange: (items: Record<string, unknown>[] | null) => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const cfg = PACK_CONFIGS[pack];
  const [editing, setEditing] = React.useState<{ index: number | null } | null>(null);

  const query = useQuery({
    queryKey: ["content-pack", pack],
    queryFn: () => api.contentPack(pack),
  });

  const doc = (query.data?.data ?? null) as Record<string, unknown> | null;
  const serverItems = Array.isArray(doc?.[cfg.arrayKey])
    ? (doc![cfg.arrayKey] as Record<string, unknown>[])
    : [];
  const items = editedItems ?? serverItems;
  const dirty = editedItems !== null;

  const setItems = (next: Record<string, unknown>[]) => onItemsChange(next);

  const save = useMutation({
    mutationFn: async () => {
      if (!doc) throw new Error("প্যাক লোড হয়নি");
      const nextDoc = { ...doc, [cfg.arrayKey]: items };
      const serialized = JSON.stringify(nextDoc, null, 2);
      if (serialized.length > SIZE_LIMIT) {
        throw new Error("প্যাকটি খুব বড় হয়ে যাচ্ছে (৯০ কিলোবাইটের সীমা) — কিছু আইটেম ছোট করুন");
      }
      return api.updateContentPack(pack, nextDoc);
    },
    onSuccess: (res) => {
      // ক্যাশে সরাসরি বসিয়ে দিই — ফ্লিকার ছাড়াই ফ্রেশ সার্ভার-অবস্থা।
      qc.setQueryData(["content-pack", pack], {
        pack,
        data: { ...(doc ?? {}), [cfg.arrayKey]: items },
      });
      onItemsChange(null);
      toast(`সংরক্ষিত — ${toBn(res.itemCount)}টি আইটেম`, "success");
    },
    onError: (err: Error) => toast(err.message || "সংরক্ষণ করা যায়নি", "error"),
  });

  if (query.isLoading) {
    return (
      <div className="space-y-2">
        <div className="skeleton h-10 w-72" />
        <div className="skeleton h-40" />
      </div>
    );
  }
  if (query.isError) {
    return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  }

  const editingInitial =
    editing && editing.index !== null && items[editing.index] ? items[editing.index] : null;

  return (
    <Card>
      <CardHeader className="flex-row flex-wrap items-center justify-between gap-2">
        <div>
          <CardTitle className="flex flex-wrap items-center gap-2">
            {cfg.labelBn}
            <Badge variant="muted">{toBn(items.length)}টি আইটেম</Badge>
            {dirty ? <Badge variant="warning">অসংরক্ষিত পরিবর্তন</Badge> : null}
          </CardTitle>
          <CardDescription>
            সংরক্ষণ করলে সাথে সাথে অ্যাপ ও ওয়েবে পৌঁছায় · স্থায়ী স্টোরেজে থাকে, রিডেপ্লয়েও হারায় না
          </CardDescription>
        </div>
        <div className="flex items-center gap-2">
          <Button variant="outline" size="sm" onClick={() => setEditing({ index: null })}>
            <Plus className="h-4 w-4" aria-hidden />
            নতুন আইটেম
          </Button>
          <Button size="sm" onClick={() => save.mutate()} disabled={save.isPending || !dirty}>
            <Save className="h-4 w-4" aria-hidden />
            {save.isPending ? "সংরক্ষণ হচ্ছে…" : "সংরক্ষণ করুন"}
          </Button>
        </div>
      </CardHeader>
      <CardContent>
        <ul className="divide-y divide-border">
          {items.map((item, i) => (
            <li key={i} className="flex items-start gap-3 py-3">
              <span className="mt-0.5 flex h-7 w-7 shrink-0 items-center justify-center rounded-full bg-primary-soft text-xs font-bold text-primary">
                {toBn(i + 1)}
              </span>
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold text-foreground">
                  {truncate(item[cfg.titleKey], 90) || "(শিরোনাম নেই)"}
                </p>
                <p className="mt-0.5 line-clamp-2 text-xs leading-relaxed text-muted-foreground">
                  {truncate(item[cfg.subtitleKey]) || "—"}
                </p>
                {cfg.child && Array.isArray(item[cfg.child.key]) ? (
                  <Badge variant="muted" className="mt-1">
                    {toBn((item[cfg.child.key] as unknown[]).length)} {cfg.child.labelBn}
                  </Badge>
                ) : null}
              </div>
              <span className="flex shrink-0 items-center gap-0.5">
                <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === 0} onClick={() => {
                  const next = [...items];
                  [next[i - 1], next[i]] = [next[i], next[i - 1]];
                  setItems(next);
                }} aria-label="উপরে সরান">
                  <ArrowUp className="h-4 w-4" aria-hidden />
                </Button>
                <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === items.length - 1} onClick={() => {
                  const next = [...items];
                  [next[i], next[i + 1]] = [next[i + 1], next[i]];
                  setItems(next);
                }} aria-label="নিচে সরান">
                  <ArrowDown className="h-4 w-4" aria-hidden />
                </Button>
                <Button variant="ghost" size="icon" className="h-9 w-9" onClick={() => setEditing({ index: i })} aria-label="সম্পাদনা">
                  <Pencil className="h-4 w-4" aria-hidden />
                </Button>
                <Button
                  variant="ghost"
                  size="icon"
                  className="h-9 w-9 text-alert hover:bg-alert-soft hover:text-alert"
                  onClick={() => {
                    if (items.length <= 1) {
                      toast("প্যাকে অন্তত একটি আইটেম থাকতে হবে", "error");
                      return;
                    }
                    setItems(items.filter((_, idx) => idx !== i));
                  }}
                  aria-label="মুছে ফেলুন"
                >
                  <Trash2 className="h-4 w-4" aria-hidden />
                </Button>
              </span>
            </li>
          ))}
        </ul>
      </CardContent>

      {editing ? (
        <PackItemDialog
          title={editingInitial ? "আইটেম সম্পাদনা" : `নতুন ${cfg.labelBn} আইটেম`}
          fields={cfg.fields}
          child={cfg.child}
          initial={editingInitial}
          onClose={() => setEditing(null)}
          onSubmit={(values) => {
            setItems(
              editing.index === null
                ? [...items, values]
                : items.map((it, idx) => (idx === editing.index ? { ...it, ...values } : it))
            );
            setEditing(null);
            toast(editing.index === null ? "তালিকায় যোগ হয়েছে — এখন সংরক্ষণ করুন" : "পরিবর্তন হয়েছে — এখন সংরক্ষণ করুন", "info");
          }}
        />
      ) : null}
    </Card>
  );
}

export default function ContentPage() {
  const { user } = useSession();
  /** প্যাক-ভেদে অসংরক্ষিত সম্পাদনা — TabsPanel আনমাউন্ট করে, তাই পেজ-লেভেল স্টেট। */
  const [edits, setEdits] = React.useState<Record<string, Record<string, unknown>[] | null>>({});
  const setPackEdits = (pack: string) => (items: Record<string, unknown>[] | null) =>
    setEdits((e) => ({ ...e, [pack]: items }));

  return (
    <RoleGate allow={isFullAdmin} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<BookOpen className="h-6 w-6" aria-hidden />}
          title="কন্টেন্ট ম্যানেজমেন্ট"
          description="অ্যাপের কন্টেন্ট প্যাক সম্পাদনা — সংরক্ষণ তাৎক্ষণিকভাবে সব ব্যবহারকারীর কাছে যায়, প্রতিটি লেখা অডিট-লগড।"
        />

        <div className="rounded-lg border border-border bg-primary-soft p-3.5 text-xs leading-relaxed text-foreground">
          <Info className="mr-1 inline h-3.5 w-3.5" aria-hidden />
          সংরক্ষণ সার্ভারের স্থায়ী স্টোরেজে যায় — রিডেপ্লয়েও থাকে। কোর্স ও কুইজের আইডি একবার দিলে আর বদলাবেন না
          (সদস্যদের অগ্রগতি ও ফলাফল আইডিতে বাঁধা)। কুরআন ও রেফারেন্স প্যাক (adhkar, names99, sunnahs…) এখানে
          সম্পাদনাযোগ্য নয়।
        </div>

        <Tabs defaultValue="faq" aria-label="কন্টেন্ট প্যাক">
          <TabsList>
            <TabsTrigger value="faq">জিজ্ঞাসা (FAQ)</TabsTrigger>
            <TabsTrigger value="articles">আর্টিকেল</TabsTrigger>
            <TabsTrigger value="mosques">মসজিদ</TabsTrigger>
            <TabsTrigger value="duas">দোয়া</TabsTrigger>
            <TabsTrigger value="courses">কোর্স</TabsTrigger>
            <TabsTrigger value="quizzes">কুইজ</TabsTrigger>
          </TabsList>
          <TabsPanel value="faq">
            <PackEditor pack="faq" editedItems={edits.faq ?? null} onItemsChange={setPackEdits("faq")} />
          </TabsPanel>
          <TabsPanel value="articles">
            <PackEditor pack="articles" editedItems={edits.articles ?? null} onItemsChange={setPackEdits("articles")} />
          </TabsPanel>
          <TabsPanel value="mosques">
            <PackEditor pack="mosques" editedItems={edits.mosques ?? null} onItemsChange={setPackEdits("mosques")} />
          </TabsPanel>
          <TabsPanel value="duas">
            <PackEditor pack="duas" editedItems={edits.duas ?? null} onItemsChange={setPackEdits("duas")} />
          </TabsPanel>
          <TabsPanel value="courses">
            <PackEditor pack="courses" editedItems={edits.courses ?? null} onItemsChange={setPackEdits("courses")} />
          </TabsPanel>
          <TabsPanel value="quizzes">
            <PackEditor pack="quizzes" editedItems={edits.quizzes ?? null} onItemsChange={setPackEdits("quizzes")} />
          </TabsPanel>
        </Tabs>
      </div>
    </RoleGate>
  );
}
