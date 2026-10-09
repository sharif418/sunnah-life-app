"use client";

// One entry of a content pack in a form — a dua, a dhikr set (with its
// dhikr inside), a course (with its lessons). What is missing is said under
// the field while typing (the same rules the API checks before review), so
// the editor never meets a wall of errors at the end. An existing entry's id
// is locked: members' favourites and progress are tied to it.

import * as React from "react";
import { AlertCircle, ArrowDown, ArrowUp, Lock, Pencil, Plus, Trash2 } from "lucide-react";
import { toBn } from "@/lib/bn";
import {
  applyFields,
  fromForm,
  ID_LOCK_HINT,
  listOf,
  nextId,
  optionsFor,
  renumber,
  toForm,
  type ChildConfig,
  type Doc,
  type Item,
  type PackField,
} from "@/lib/content-packs";
import { cn } from "@/lib/utils";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";

/** field → message for one candidate entry; each child's the same, by index */
export interface EntryIssues {
  fields: Map<string, string>;
  children: Map<number, Map<string, string>>;
}

export interface EntryDialogProps {
  title: string;
  fields: PackField[];
  /** null = a new entry */
  initial: Item | null;
  /** the other entries of the list (duplicate ids, the next number) */
  siblings: Item[];
  idKey?: string;
  idGen?: { numericId?: boolean; idPrefix?: string };
  child?: ChildConfig;
  doc: Doc | null;
  readOnly?: boolean;
  /** the live check for this entry as it stands in the form */
  check: (candidate: Item) => EntryIssues;
  onClose: () => void;
  onSubmit: (item: Item) => void;
}

function initialValues(fields: PackField[], initial: Item | null, idKey: string | undefined, freshId: string | number | null) {
  const v: Record<string, string> = {};
  for (const f of fields) v[f.key] = toForm(f, initial?.[f.key]);
  if (!initial && idKey && freshId !== null) v[idKey] = String(freshId);
  return v;
}

export function EntryDialog({
  title,
  fields,
  initial,
  siblings,
  idKey,
  idGen,
  child,
  doc,
  readOnly,
  check,
  onClose,
  onSubmit,
}: EntryDialogProps) {
  const { toast } = useToast();
  const isNew = initial === null;
  const [values, setValues] = React.useState<Record<string, string>>(() =>
    initialValues(fields, initial, idKey, isNew && idKey && idGen ? nextId(idGen, siblings, idKey) : null)
  );
  const [children, setChildren] = React.useState<Item[]>(() => (child ? listOf(initial, child.key) : []));
  const [editingChild, setEditingChild] = React.useState<{ index: number | null } | null>(null);

  // the entry as the form holds it now (unconvertible text is left out here;
  // the submit says so)
  const candidate = React.useMemo(() => {
    const out: Item = {};
    for (const f of fields) {
      const r = fromForm(f, values[f.key] ?? "");
      if (r.value !== undefined) out[f.key] = r.value;
    }
    const item = applyFields(initial, fields, out);
    if (child) item[child.key] = child.autoOrder ? renumber(children) : children;
    return item;
  }, [values, children, fields, initial, child]);

  const issues = React.useMemo(() => check(candidate), [check, candidate]);

  const duplicateId = React.useMemo(() => {
    if (!idKey || !isNew) return null;
    const id = String(candidate[idKey] ?? "");
    return id && siblings.some((s) => String(s[idKey] ?? "") === id) ? `আইডি "${id}" আগে থেকেই আছে — অন্যটি দিন` : null;
  }, [candidate, idKey, isNew, siblings]);

  const submit = () => {
    for (const f of fields) {
      const r = fromForm(f, values[f.key] ?? "");
      if (r.error) {
        toast(r.error, "error");
        return;
      }
    }
    if (duplicateId) {
      toast(duplicateId, "error");
      return;
    }
    onSubmit(candidate);
  };

  const set = (key: string, v: string) => setValues((s) => ({ ...s, [key]: v }));
  const remaining = issues.fields.size + [...issues.children.values()].reduce((n, m) => n + m.size, 0);

  return (
    <Dialog
      open
      onClose={onClose}
      wide
      title={title}
      description={
        readOnly
          ? "শুধু দেখার জন্য — যাচাইয়ের অপেক্ষায় থাকা অবস্থায় বদলানো যায় না"
          : "পরিবর্তন খসড়ায় যায় (নিজে থেকেই সংরক্ষিত হয়) — আলেমের যাচাইয়ের পরেই অ্যাপে পৌঁছাবে"
      }
      footer={
        readOnly ? (
          <Button variant="outline" onClick={onClose}>
            বন্ধ করুন
          </Button>
        ) : (
          <>
            {remaining ? (
              <span className="mr-auto flex items-center gap-1.5 text-xs text-warning">
                <AlertCircle className="h-4 w-4" aria-hidden />
                যাচাইয়ে পাঠানোর আগে {toBn(remaining)}টি জিনিস বাকি — এখনো রাখতে পারেন
              </span>
            ) : null}
            <Button variant="outline" onClick={onClose}>
              বাতিল
            </Button>
            <Button onClick={submit}>{isNew ? "যোগ করুন" : "পরিবর্তন রাখুন"}</Button>
          </>
        )
      }
    >
      <div className="space-y-4">
        {fields.map((f) => {
          const id = `en-${f.key}`;
          const locked = !isNew && f.key === idKey;
          const msg = (f.key === idKey && duplicateId) || issues.fields.get(f.key);
          const value = values[f.key] ?? "";
          const control =
            f.type === "bool" ? (
              <label className="flex min-h-11 cursor-pointer items-center gap-3 text-sm">
                <input
                  id={id}
                  type="checkbox"
                  className="h-5 w-5 accent-[var(--primary)]"
                  disabled={readOnly}
                  checked={value === "true"}
                  onChange={(e) => set(f.key, e.target.checked ? "true" : "false")}
                />
                হ্যাঁ
              </label>
            ) : f.type === "select" ? (
              <Select id={id} value={value} disabled={readOnly} onChange={(e) => set(f.key, e.target.value)}>
                <option value="">— বেছে নিন —</option>
                {optionsFor(f, doc).map((o) => (
                  <option key={o.value} value={o.value}>
                    {o.label}
                  </option>
                ))}
                {value && !optionsFor(f, doc).some((o) => o.value === value) ? <option value={value}>{value}</option> : null}
              </Select>
            ) : f.type === "textarea" || f.type === "lines" ? (
              <Textarea
                id={id}
                dir={f.rtl ? "rtl" : undefined}
                lang={f.rtl ? "ar" : undefined}
                readOnly={readOnly}
                value={value}
                onChange={(e) => set(f.key, e.target.value)}
                className={cn(f.long && "min-h-[280px]", f.rtl && "min-h-[110px] font-arabic text-xl leading-loose")}
              />
            ) : (
              <div className="relative">
                <Input
                  id={id}
                  inputMode={f.type === "number" ? "decimal" : f.type === "int" ? "numeric" : undefined}
                  dir={f.rtl ? "rtl" : undefined}
                  lang={f.rtl ? "ar" : undefined}
                  readOnly={readOnly || locked}
                  value={value}
                  onChange={(e) => set(f.key, e.target.value)}
                  className={cn(locked && "pr-10 text-muted-foreground", f.rtl && "font-arabic text-lg")}
                />
                {locked ? (
                  <Lock className="absolute right-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
                ) : null}
              </div>
            );
          return (
            <Field
              key={f.key}
              label={f.label + (f.required ? " *" : "")}
              htmlFor={id}
              hint={locked ? ID_LOCK_HINT : f.hint}
            >
              {control}
              {msg ? (
                <p className="flex items-center gap-1 text-xs font-medium text-alert" role="alert">
                  <AlertCircle className="h-3.5 w-3.5" aria-hidden />
                  {msg}
                </p>
              ) : null}
            </Field>
          );
        })}

        {child ? (
          <div className={cn("rounded-lg border p-3", issues.fields.get(child.key) ? "border-alert/50" : "border-border")}>
            <div className="mb-2 flex flex-wrap items-center justify-between gap-2">
              <p className="flex items-center gap-2 text-sm font-semibold">
                {child.labelBn} <Badge variant="muted">{toBn(children.length)}টি</Badge>
              </p>
              {!readOnly ? (
                <Button variant="outline" size="sm" onClick={() => setEditingChild({ index: null })}>
                  <Plus className="h-4 w-4" aria-hidden />
                  নতুন {child.labelBn}
                </Button>
              ) : null}
            </div>
            {issues.fields.get(child.key) ? (
              <p className="mb-2 text-xs font-medium text-alert">{issues.fields.get(child.key)}</p>
            ) : null}
            <ul className="divide-y divide-border">
              {children.map((c, i) => {
                const childIssues = [...(issues.children.get(i)?.values() ?? [])];
                return (
                  <li key={i} className="flex items-center gap-2 py-2 text-sm">
                    <span className="w-6 shrink-0 text-center text-xs font-bold text-primary">{toBn(i + 1)}</span>
                    <button
                      type="button"
                      className="focus-ring min-w-0 flex-1 rounded text-left"
                      onClick={() => setEditingChild({ index: i })}
                    >
                      <span className="block truncate">{String(c[child.titleKey] ?? "") || "(শিরোনাম নেই)"}</span>
                      {childIssues.length ? (
                        <span className="block truncate text-xs text-alert">{childIssues.join(" · ")}</span>
                      ) : child.subtitleKey && c[child.subtitleKey] ? (
                        <span className="block truncate text-xs text-muted-foreground">{String(c[child.subtitleKey])}</span>
                      ) : null}
                    </button>
                    {!readOnly ? (
                      <span className="flex shrink-0 items-center">
                        <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === 0} aria-label="উপরে সরান" onClick={() => {
                          const n = [...children];
                          [n[i - 1], n[i]] = [n[i], n[i - 1]];
                          setChildren(n);
                        }}>
                          <ArrowUp className="h-4 w-4" aria-hidden />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === children.length - 1} aria-label="নিচে সরান" onClick={() => {
                          const n = [...children];
                          [n[i], n[i + 1]] = [n[i + 1], n[i]];
                          setChildren(n);
                        }}>
                          <ArrowDown className="h-4 w-4" aria-hidden />
                        </Button>
                        <Button variant="ghost" size="icon" className="h-9 w-9" aria-label="সম্পাদনা" onClick={() => setEditingChild({ index: i })}>
                          <Pencil className="h-4 w-4" aria-hidden />
                        </Button>
                        <Button
                          variant="ghost"
                          size="icon"
                          className="h-9 w-9 text-alert hover:bg-alert-soft hover:text-alert"
                          aria-label="মুছে ফেলুন"
                          onClick={() => setChildren(children.filter((_, x) => x !== i))}
                        >
                          <Trash2 className="h-4 w-4" aria-hidden />
                        </Button>
                      </span>
                    ) : null}
                  </li>
                );
              })}
            </ul>
          </div>
        ) : null}
      </div>

      {child && editingChild ? (
        <EntryDialog
          title={editingChild.index === null ? `নতুন ${child.labelBn}` : `${child.labelBn} ${toBn(editingChild.index + 1)}`}
          fields={child.fields}
          initial={editingChild.index === null ? null : children[editingChild.index]}
          siblings={editingChild.index === null ? children : children.filter((_, x) => x !== editingChild.index)}
          idKey="id"
          idGen={{ idPrefix: String(candidate.id ?? child.key) }}
          doc={doc}
          readOnly={readOnly}
          check={(c) => {
            // the child checked in its place inside this entry
            const at = editingChild.index ?? children.length;
            const next = [...children];
            next[at] = c;
            const res = check({ ...candidate, [child.key]: next });
            return { fields: res.children.get(at) ?? new Map(), children: new Map() };
          }}
          onClose={() => setEditingChild(null)}
          onSubmit={(v) => {
            setChildren(
              editingChild.index === null ? [...children, v] : children.map((c, x) => (x === editingChild.index ? v : c))
            );
            setEditingChild(null);
          }}
        />
      ) : null}
    </Dialog>
  );
}
