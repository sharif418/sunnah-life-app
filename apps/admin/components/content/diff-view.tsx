"use client";

// What will change in the apps — new, removed and changed entries, changed
// text word by word. The reviewing scholar approves exactly this.

import * as React from "react";
import { ArrowUpDown, CheckCircle2, Minus, Pencil, Plus } from "lucide-react";
import { toBn } from "@/lib/bn";
import { diffIsEmpty, diffPack, wordDiff, type EntryChange, type ListDiff } from "@/lib/content-diff";
import { displayValue, listOf, type Doc, type Item, type PackConfig, type PackField } from "@/lib/content-packs";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";

function titleOf(item: Item, titleKey: string, key: string): string {
  const t = item[titleKey];
  return (typeof t === "string" && t.trim()) || key;
}

function TextChange({ field, before, after, doc }: { field: PackField; before: unknown; after: unknown; doc: Doc | null }) {
  const b = displayValue(field, before, doc);
  const a = displayValue(field, after, doc);
  const segs = React.useMemo(() => wordDiff(b, a), [a, b]);
  return (
    <div className="grid gap-1 sm:grid-cols-[9rem_1fr] sm:gap-3">
      <p className="text-xs font-semibold text-muted-foreground">{field.label}</p>
      <p
        dir={field.rtl ? "rtl" : undefined}
        lang={field.rtl ? "ar" : undefined}
        className={cn("whitespace-pre-wrap break-words text-sm leading-relaxed", field.rtl && "font-arabic text-lg")}
      >
        {!b ? (
          <ins className="rounded bg-primary-soft px-0.5 text-primary no-underline">{a}</ins>
        ) : !a ? (
          <del className="rounded bg-alert-soft px-0.5 text-alert">{b}</del>
        ) : (
          segs.map((s, i) =>
            s.kind === "same" ? (
              <span key={i}>{s.text}</span>
            ) : s.kind === "add" ? (
              <ins key={i} className="rounded bg-primary-soft px-0.5 font-medium text-primary no-underline" aria-label={`যোগ: ${s.text}`}>
                {s.text}
              </ins>
            ) : (
              <del key={i} className="rounded bg-alert-soft px-0.5 text-alert" aria-label={`বাদ: ${s.text}`}>
                {s.text}
              </del>
            )
          )
        )}
      </p>
    </div>
  );
}

function EntryFields({ fields, item, doc, muted }: { fields: PackField[]; item: Item; doc: Doc | null; muted?: boolean }) {
  return (
    <dl className="space-y-1.5">
      {fields.map((f) => {
        const v = displayValue(f, item[f.key], doc);
        if (!v) return null;
        return (
          <div key={f.key} className="grid gap-0.5 sm:grid-cols-[9rem_1fr] sm:gap-3">
            <dt className="text-xs font-semibold text-muted-foreground">{f.label}</dt>
            <dd
              dir={f.rtl ? "rtl" : undefined}
              lang={f.rtl ? "ar" : undefined}
              className={cn(
                "whitespace-pre-wrap break-words text-sm leading-relaxed",
                f.rtl && "font-arabic text-lg",
                muted && "text-muted-foreground line-through"
              )}
            >
              {f.long && v.length > 600 ? `${v.slice(0, 600)}…` : v}
            </dd>
          </div>
        );
      })}
    </dl>
  );
}

function Section({
  tone,
  icon,
  label,
  count,
  children,
}: {
  tone: "add" | "del" | "edit";
  icon: React.ReactNode;
  label: string;
  count: number;
  children: React.ReactNode;
}) {
  if (!count) return null;
  return (
    <section className="space-y-2">
      <h3
        className={cn(
          "flex items-center gap-2 text-sm font-bold",
          tone === "add" ? "text-primary" : tone === "del" ? "text-alert" : "text-foreground"
        )}
      >
        {icon}
        {label} <Badge variant={tone === "add" ? "default" : tone === "del" ? "alert" : "muted"}>{toBn(count)}</Badge>
      </h3>
      <div className="space-y-2">{children}</div>
    </section>
  );
}

function ListDiffView({
  diff,
  fields,
  titleKey,
  noun,
  doc,
  child,
}: {
  diff: ListDiff;
  fields: PackField[];
  titleKey: string;
  noun: string;
  doc: Doc | null;
  child?: { key: string; labelBn: string; titleKey: string; fields: PackField[] };
}) {
  const card = "rounded-lg border p-3";
  return (
    <div className="space-y-4">
      {diff.reordered ? (
        <p className="flex items-center gap-2 text-sm text-muted-foreground">
          <ArrowUpDown className="h-4 w-4" aria-hidden />
          {noun}-এর ক্রম বদলেছে
        </p>
      ) : null}
      <Section tone="add" icon={<Plus className="h-4 w-4" aria-hidden />} label={`নতুন ${noun}`} count={diff.added.length}>
        {diff.added.map(({ key, item }) => (
          <div key={key} className={cn(card, "border-primary/30 bg-primary-soft/40")}>
            <p className="mb-2 text-sm font-semibold">{titleOf(item, titleKey, key)}</p>
            <EntryFields fields={fields} item={item} doc={doc} />
            {child && listOf(item, child.key).length ? (
              <p className="mt-2 text-xs text-muted-foreground">
                {toBn(listOf(item, child.key).length)}টি {child.labelBn}
              </p>
            ) : null}
          </div>
        ))}
      </Section>
      <Section tone="del" icon={<Minus className="h-4 w-4" aria-hidden />} label={`বাদ পড়ছে`} count={diff.removed.length}>
        {diff.removed.map(({ key, item }) => (
          <details key={key} className={cn(card, "border-alert/30 bg-alert-soft/40")}>
            <summary className="cursor-pointer text-sm font-semibold text-alert line-through">{titleOf(item, titleKey, key)}</summary>
            <div className="mt-2">
              <EntryFields fields={fields} item={item} doc={doc} muted />
            </div>
          </details>
        ))}
      </Section>
      <Section tone="edit" icon={<Pencil className="h-4 w-4" aria-hidden />} label="পরিবর্তিত" count={diff.changed.length}>
        {diff.changed.map((c: EntryChange) => (
          <div key={c.key} className={cn(card, "border-border bg-card")}>
            <p className="mb-2 text-sm font-semibold">{titleOf(c.after, titleKey, c.key)}</p>
            <div className="space-y-2">
              {c.fields.map((fc) => (
                <TextChange key={fc.field.key} field={fc.field} before={fc.before} after={fc.after} doc={doc} />
              ))}
            </div>
            {child && c.children ? (
              <div className="mt-3 border-l-2 border-border pl-3">
                <ListDiffView diff={c.children} fields={child.fields} titleKey={child.titleKey} noun={child.labelBn} doc={doc} />
              </div>
            ) : null}
          </div>
        ))}
      </Section>
    </div>
  );
}

export function DiffView({ cfg, before, after }: { cfg: PackConfig; before: Doc | null; after: Doc | null }) {
  const diff = React.useMemo(() => diffPack(cfg, before, after), [cfg, before, after]);
  if (diffIsEmpty(diff)) {
    return (
      <div className="flex items-center gap-2 rounded-lg border border-dashed border-border p-6 text-sm text-muted-foreground">
        <CheckCircle2 className="h-5 w-5 text-primary" aria-hidden />
        অ্যাপে এখন যা আছে তার সাথে কোনো পার্থক্য নেই
      </div>
    );
  }
  return (
    <div className="space-y-5">
      <p className="flex flex-wrap gap-2 text-xs">
        {diff.added.length ? <Badge>+{toBn(diff.added.length)} নতুন</Badge> : null}
        {diff.removed.length ? <Badge variant="alert">−{toBn(diff.removed.length)} বাদ</Badge> : null}
        {diff.changed.length ? <Badge variant="muted">{toBn(diff.changed.length)}টি পরিবর্তিত</Badge> : null}
      </p>
      <ListDiffView
        diff={diff}
        fields={cfg.fields}
        titleKey={cfg.titleKey}
        noun={cfg.child ? "অংশ" : "এন্ট্রি"}
        doc={after}
        child={cfg.child}
      />
      {cfg.extra && diff.extraChanged ? (
        <div className="rounded-lg border border-border p-3 text-sm">
          <p className="mb-1 font-semibold">{cfg.extra.labelBn}-এর তালিকা বদলেছে</p>
          <p className="text-muted-foreground">
            আগে: {listOf(before, cfg.extra.key).map((x) => String(x[cfg.extra!.titleKey] ?? "")).join(", ") || "—"}
          </p>
          <p>
            এখন: {listOf(after, cfg.extra.key).map((x) => String(x[cfg.extra!.titleKey] ?? "")).join(", ") || "—"}
          </p>
        </div>
      ) : null}
      {diff.otherKeys.length ? (
        <p className="text-xs text-muted-foreground">অন্যান্য অংশও বদলেছে: {diff.otherKeys.join(", ")}</p>
      ) : null}
    </div>
  );
}
