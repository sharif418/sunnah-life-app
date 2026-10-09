"use client";

// CSV in and out for a content pack — many entries at once from a sheet
// (Excel "CSV UTF-8" or Google Sheets). The download is also the template:
// edit it and bring it back. Nothing goes live: the rows land in the draft,
// the editor sees the result and what is missing, then sends it for review.
// Packs with a nested list (adhkar, courses, quizzes) take one row per dhikr /
// lesson / question, with a column naming its set / course / quiz.

import * as React from "react";
import { AlertCircle, Download, FileUp } from "lucide-react";
import { toBn } from "@/lib/bn";
import { downloadCsvSafe, parseCsv } from "@/lib/csv";
import {
  fromForm,
  listOf,
  optionsFor,
  renumber,
  stableJson,
  toForm,
  type Doc,
  type Item,
  type PackConfig,
  type PackField,
} from "@/lib/content-packs";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";

type Mode = "merge" | "replace";

interface Plan {
  next: Doc;
  added: number;
  updated: number;
  unchanged: number;
  errors: string[];
  unknownColumns: string[];
  rows: number;
}

const cell = (f: PackField, raw: unknown) => (f.type === "lines" && Array.isArray(raw) ? raw.join(" | ") : toForm(f, raw));

/** Read one CSV row into fields; columns the sheet does not have stay as they were. */
function readRow(
  fields: PackField[],
  row: Record<string, string>,
  present: Set<string>,
  base: Item | null,
  rowNo: number,
  errors: string[]
): Item {
  const out: Item = { ...(base ?? {}) };
  for (const f of fields) {
    if (!present.has(f.key)) continue;
    const r = fromForm(f, row[f.key] ?? "");
    if (r.error) errors.push(`সারি ${toBn(rowNo)}: ${r.error}`);
    if (r.value === undefined) delete out[f.key];
    else out[f.key] = r.value;
  }
  return out;
}

function plan(cfg: PackConfig, doc: Doc, text: string, mode: Mode): Plan {
  const { headers, rows } = parseCsv(text);
  const present = new Set(headers);
  const errors: string[] = [];
  let added = 0;
  let updated = 0;
  let unchanged = 0;
  const same = (a: unknown, b: unknown) => stableJson(a) === stableJson(b);

  if (cfg.child) {
    const child = cfg.child;
    const known = new Set([child.parentColumn, ...child.fields.map((f) => f.key)]);
    const unknownColumns = headers.filter((h) => !known.has(h));
    if (!present.has(child.parentColumn)) errors.push(`"${child.parentColumn}" কলাম নেই — কোন ${cfg.labelBn}-এর অংশ, তা এই কলামে দিন`);
    if (!present.has("id")) errors.push(`"id" কলাম নেই`);
    const parents = listOf(doc, cfg.arrayKey).map((p) => ({ ...p, [child.key]: [...listOf(p, child.key)] }));
    const cleared = new Set<string>();
    rows.forEach((row, i) => {
      const rowNo = i + 2;
      const pid = row[child.parentColumn] ?? "";
      const parent = parents.find((p) => String(p[cfg.idKey ?? "id"]) === pid);
      if (!parent) {
        errors.push(`সারি ${toBn(rowNo)}: ${cfg.labelBn} "${pid}" পাওয়া যায়নি — আগে সেটি তৈরি করুন`);
        return;
      }
      let kids = parent[child.key] as Item[];
      if (mode === "replace" && !cleared.has(pid)) {
        cleared.add(pid);
        kids = [];
      }
      const id = row.id ?? "";
      const at = kids.findIndex((k) => String(k.id) === id);
      const base = at >= 0 ? kids[at] : null;
      const item = readRow(child.fields, row, present, base, rowNo, errors);
      if (at >= 0) {
        if (same(item, base)) unchanged++;
        else updated++;
        kids = kids.map((k, x) => (x === at ? item : k));
      } else {
        added++;
        kids = [...kids, item];
      }
      parent[child.key] = child.autoOrder ? renumber(kids) : kids;
    });
    return { next: { ...doc, [cfg.arrayKey]: parents }, added, updated, unchanged, errors, unknownColumns, rows: rows.length };
  }

  const known = new Set(cfg.fields.map((f) => f.key));
  const unknownColumns = headers.filter((h) => !known.has(h));
  if (cfg.idKey && mode === "merge" && !present.has(cfg.idKey)) errors.push(`"${cfg.idKey}" কলাম নেই — কোন এন্ট্রি বদলাবে তা আইডি দিয়ে মেলানো হয়`);
  let list = mode === "replace" ? [] : [...listOf(doc, cfg.arrayKey)];
  const before = listOf(doc, cfg.arrayKey);
  rows.forEach((row, i) => {
    const rowNo = i + 2;
    const id = cfg.idKey ? (row[cfg.idKey] ?? "") : "";
    const at = cfg.idKey && id ? list.findIndex((x) => String(x[cfg.idKey!]) === id) : -1;
    const base = at >= 0 ? list[at] : mode === "replace" && cfg.idKey ? (before.find((x) => String(x[cfg.idKey!]) === id) ?? null) : null;
    const item = readRow(cfg.fields, row, present, base, rowNo, errors);
    if (at >= 0) {
      if (same(item, list[at])) unchanged++;
      else updated++;
      list = list.map((x, k) => (k === at ? item : x));
    } else {
      if (base) {
        if (same(item, base)) unchanged++;
        else updated++;
      } else added++;
      list.push(item);
    }
  });
  return { next: { ...doc, [cfg.arrayKey]: list }, added, updated, unchanged, errors, unknownColumns, rows: rows.length };
}

export function CsvDialog({
  cfg,
  doc,
  onApply,
  onClose,
}: {
  cfg: PackConfig;
  doc: Doc;
  onApply: (next: Doc, summary: string) => void;
  onClose: () => void;
}) {
  const [mode, setMode] = React.useState<Mode>("merge");
  const [text, setText] = React.useState<string | null>(null);
  const [fileName, setFileName] = React.useState("");
  const result = React.useMemo(() => (text === null ? null : plan(cfg, doc, text, mode)), [cfg, doc, text, mode]);
  const columns: { key: string; label: string; note: string }[] = cfg.child
    ? [
        { key: cfg.child.parentColumn, label: `কোন ${cfg.labelBn}`, note: `${cfg.labelBn}-এর আইডি` },
        ...cfg.child.fields.map((f) => colInfo(f, doc)),
      ]
    : cfg.fields.map((f) => colInfo(f, doc));

  const exportCsv = () => {
    const name = `${cfg.key}-${new Date().toISOString().slice(0, 10)}.csv`;
    if (cfg.child) {
      const child = cfg.child;
      const rows: (string | number)[][] = [];
      for (const p of listOf(doc, cfg.arrayKey)) {
        for (const c of listOf(p, child.key)) {
          rows.push([String(p[cfg.idKey ?? "id"] ?? ""), ...child.fields.map((f) => cell(f, c[f.key]))]);
        }
      }
      downloadCsvSafe(name, [child.parentColumn, ...child.fields.map((f) => f.key)], rows);
    } else {
      downloadCsvSafe(
        name,
        cfg.fields.map((f) => f.key),
        listOf(doc, cfg.arrayKey).map((it) => cfg.fields.map((f) => cell(f, it[f.key])))
      );
    }
  };

  const onFile = async (file: File | undefined) => {
    if (!file) return;
    setFileName(file.name);
    setText(await file.text());
  };

  const blocked = !result || result.errors.length > 0 || result.rows === 0;
  const noun = cfg.child?.labelBn ?? "এন্ট্রি";

  return (
    <Dialog
      open
      wide
      onClose={onClose}
      title={`CSV দিয়ে ${cfg.labelBn}`}
      description="শিট থেকে একসাথে অনেক এন্ট্রি — খসড়ায় বসবে, আলেমের যাচাইয়ের আগে অ্যাপে যাবে না"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            disabled={blocked}
            onClick={() =>
              result &&
              onApply(
                result.next,
                `${toBn(result.added)}টি নতুন, ${toBn(result.updated)}টি হালনাগাদ ${noun} খসড়ায় বসেছে`
              )
            }
          >
            খসড়ায় বসান
          </Button>
        </>
      }
    >
      <div className="space-y-5 text-sm">
        <section className="space-y-2">
          <p className="font-semibold">১. বর্তমান তালিকা নামান — এটিই টেমপ্লেট</p>
          <p className="text-muted-foreground">
            এক্সেল বা গুগল শিটে খুলে বদলান বা নতুন সারি যোগ করুন, তারপর «CSV UTF-8» হিসেবে সংরক্ষণ করে নিচে দিন।
            {cfg.child ? ` প্রতি সারিতে একটি ${cfg.child.labelBn}।` : ""}
          </p>
          <Button variant="outline" size="sm" onClick={exportCsv}>
            <Download className="h-4 w-4" aria-hidden />
            CSV নামান
          </Button>
          <details className="rounded-lg border border-border p-3">
            <summary className="cursor-pointer text-xs font-semibold text-muted-foreground">কলামগুলোর অর্থ</summary>
            <table className="mt-2 w-full text-xs">
              <tbody>
                {columns.map((c) => (
                  <tr key={c.key} className="border-t border-border first:border-0">
                    <td className="py-1.5 pr-3 font-mono">{c.key}</td>
                    <td className="py-1.5 pr-3">{c.label}</td>
                    <td className="py-1.5 text-muted-foreground">{c.note}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </details>
        </section>

        <section className="space-y-2">
          <p className="font-semibold">২. কীভাবে বসবে</p>
          <div role="radiogroup" className="grid gap-2 sm:grid-cols-2">
            {(
              [
                ["merge", "হালনাগাদ ও যোগ", "আইডি মিললে সেই এন্ট্রি বদলাবে, নতুন আইডি হলে যোগ হবে; বাকিগুলো যেমন আছে"],
                [
                  "replace",
                  "পুরো তালিকা বদলে দিন",
                  cfg.child ? `যে ${cfg.labelBn}-এর সারি আছে, তার সব ${cfg.child.labelBn} এই শিট অনুযায়ী` : "শিটে যা আছে শুধু তা-ই থাকবে",
                ],
              ] as const
            ).map(([v, label, hint]) => (
              <label
                key={v}
                className={cn(
                  "flex cursor-pointer gap-2 rounded-lg border p-3",
                  mode === v ? "border-primary bg-primary-soft" : "border-border"
                )}
              >
                <input type="radio" name="csv-mode" className="mt-1 accent-[var(--primary)]" checked={mode === v} onChange={() => setMode(v)} />
                <span>
                  <span className="block font-semibold">{label}</span>
                  <span className="block text-xs text-muted-foreground">{hint}</span>
                </span>
              </label>
            ))}
          </div>
        </section>

        <section className="space-y-2">
          <p className="font-semibold">৩. ফাইল দিন</p>
          <label className="focus-within:ring-2 flex cursor-pointer items-center gap-3 rounded-lg border border-dashed border-border p-4 hover:bg-primary-soft">
            <FileUp className="h-5 w-5 text-primary" aria-hidden />
            <span>{fileName || "CSV ফাইল বেছে নিন"}</span>
            <input type="file" accept=".csv,text/csv" className="sr-only" onChange={(e) => onFile(e.target.files?.[0])} />
          </label>
          {result ? (
            <div className="space-y-2 rounded-lg bg-muted/60 p-3">
              <p>
                {toBn(result.rows)}টি সারি পড়া হয়েছে — <b>{toBn(result.added)}</b>টি নতুন, <b>{toBn(result.updated)}</b>টি হালনাগাদ,{" "}
                {toBn(result.unchanged)}টি অপরিবর্তিত
              </p>
              {result.unknownColumns.length ? (
                <p className="text-xs text-warning">এই কলামগুলো চেনা যায়নি, বাদ যাবে: {result.unknownColumns.join(", ")}</p>
              ) : null}
              {result.errors.length ? (
                <ul className="space-y-1 text-xs text-alert" role="alert">
                  {result.errors.slice(0, 12).map((e, i) => (
                    <li key={i} className="flex gap-1.5">
                      <AlertCircle className="mt-0.5 h-3.5 w-3.5 shrink-0" aria-hidden />
                      {e}
                    </li>
                  ))}
                  {result.errors.length > 12 ? <li>…আরও {toBn(result.errors.length - 12)}টি</li> : null}
                </ul>
              ) : null}
            </div>
          ) : null}
        </section>
      </div>
    </Dialog>
  );
}

function colInfo(f: PackField, doc: Doc): { key: string; label: string; note: string } {
  const opts = f.type === "select" ? optionsFor(f, doc) : [];
  const note =
    f.type === "select"
      ? opts.map((o) => `${o.value} = ${o.label}`).join(", ")
      : f.type === "lines"
        ? "একই ঘরে, | দিয়ে আলাদা"
        : f.type === "bool"
          ? "true / false"
          : f.type === "int" || f.type === "number"
            ? f.key === "answerIndex"
              ? "সংখ্যা, ১ থেকে"
              : "সংখ্যা"
            : "";
  return { key: f.key, label: f.label + (f.required ? " *" : ""), note };
}
