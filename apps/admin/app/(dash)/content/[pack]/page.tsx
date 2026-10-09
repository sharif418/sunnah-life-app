"use client";

// One content pack: its entries, the draft, the review and the history.
//
//  • Editing makes a DRAFT that saves itself (a moment after each change);
//    what is still missing is listed beside each entry while typing.
//  • «যাচাইয়ে পাঠান» sends it to a reviewing scholar, with a line on what
//    changed. While it waits it is locked (the editor may take it back).
//  • The scholar sees exactly what will change — word by word — and approves
//    (→ the apps get it) or sends it back with a note. Never their own.
//  • Every published version stays; a scholar can bring an earlier one back.

import * as React from "react";
import Link from "next/link";
import { useParams } from "next/navigation";
import { useQuery, useQueryClient } from "@tanstack/react-query";
import {
  AlertCircle,
  ArrowDown,
  ArrowLeft,
  ArrowUp,
  CheckCircle2,
  Cloud,
  CloudOff,
  Eye,
  FileSpreadsheet,
  History,
  Loader2,
  Pencil,
  Plus,
  RotateCcw,
  Search,
  Send,
  ShieldCheck,
  Tags,
  Trash2,
  Undo2,
  XCircle,
} from "lucide-react";
import { api, ApiError, type CmsPackKey, type PackIssue, type RevisionMeta } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { validatePack } from "@/lib/content-validation";
import { diffIsEmpty, diffPack } from "@/lib/content-diff";
import {
  displayValue,
  issuesByEntry,
  listOf,
  parseIssuePath,
  PACK_CONFIGS,
  stableJson,
  type Doc,
  type EntryIssue,
  type Item,
  type PackConfig,
} from "@/lib/content-packs";
import { cn } from "@/lib/utils";
import { CsvDialog } from "@/components/content/csv-dialog";
import { DiffView } from "@/components/content/diff-view";
import { EntryDialog, type EntryIssues } from "@/components/content/entry-dialog";
import { HistoryBadge, WorkingBadge } from "@/components/content/status";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Textarea } from "@/components/ui/input";
import { Tabs, TabsList, TabsPanel, TabsTrigger } from "@/components/ui/tabs";
import { EmptyState, ErrorState, PageHeading } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

type SaveState = "idle" | "saving" | "saved" | "error";

const errText = (e: unknown, fallback: string) => (e instanceof Error && e.message ? e.message : fallback);

/** "যিকির ৩: সূত্র দিন" — an issue as the entry list says it. */
function issueLine(cfg: PackConfig, is: EntryIssue): string {
  return is.childIndex !== null && cfg.child ? `${cfg.child.labelBn} ${toBn(is.childIndex + 1)}: ${is.message}` : is.message;
}

// ── dialogs ──────────────────────────────────────────────────────────────────

function SubmitDialog({
  cfg,
  initialNote,
  issues,
  changed,
  onClose,
  onSend,
}: {
  cfg: PackConfig;
  initialNote: string;
  issues: PackIssue[];
  changed: boolean;
  onClose: () => void;
  onSend: (note: string) => Promise<void>;
}) {
  const [note, setNote] = React.useState(initialNote);
  const [busy, setBusy] = React.useState(false);
  const byEntry = issuesByEntry(cfg, issues);
  const blocked = issues.length > 0 || !changed;
  return (
    <Dialog
      open
      onClose={onClose}
      title="যাচাইয়ের জন্য পাঠান"
      description="একজন যাচাইকারী আলেম দেখে অনুমোদন দিলে তবেই অ্যাপে যাবে। অপেক্ষার সময় খসড়া বদলানো যাবে না — দরকারে ফেরত নিতে পারবেন।"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            disabled={blocked || busy}
            onClick={async () => {
              setBusy(true);
              try {
                await onSend(note);
              } finally {
                setBusy(false);
              }
            }}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : <Send className="h-4 w-4" aria-hidden />}
            পাঠান
          </Button>
        </>
      }
    >
      {!changed ? (
        <p className="text-sm text-muted-foreground">অ্যাপে এখন যা আছে তার সাথে কোনো পার্থক্য নেই — পাঠানোর মতো কিছু নেই।</p>
      ) : issues.length ? (
        <div className="space-y-2" role="alert">
          <p className="flex items-center gap-2 text-sm font-semibold text-alert">
            <AlertCircle className="h-4 w-4" aria-hidden />
            আগে {toBn(issues.length)}টি জিনিস ঠিক করুন
          </p>
          <ul className="max-h-64 space-y-1 overflow-y-auto text-sm">
            {[...byEntry].map(([i, list]) =>
              list.map((is, k) => (
                <li key={`${i}-${k}`} className="text-muted-foreground">
                  {i >= 0 ? `${cfg.entryBn} ${toBn(i + 1)} — ` : ""}
                  {issueLine(cfg, is)}
                </li>
              ))
            )}
          </ul>
        </div>
      ) : (
        <Field label="কী বদলালেন" htmlFor="submit-note" hint="আলেমের জন্য এক-দুই লাইন — যেমন: «সকালের আযকারে দুটি যিকির যোগ, একটির সূত্র ঠিক করা»">
          <Textarea id="submit-note" value={note} maxLength={500} onChange={(e) => setNote(e.target.value)} />
        </Field>
      )}
    </Dialog>
  );
}

function ReviewDialog({
  decision,
  onClose,
  onDecide,
}: {
  decision: "approve" | "reject";
  onClose: () => void;
  onDecide: (note: string) => Promise<void>;
}) {
  const [note, setNote] = React.useState("");
  const [busy, setBusy] = React.useState(false);
  const approve = decision === "approve";
  return (
    <Dialog
      open
      onClose={onClose}
      title={approve ? "অনুমোদন ও প্রকাশ" : "মন্তব্যসহ ফেরত দিন"}
      description={
        approve
          ? "অনুমোদন দিলে এই সংস্করণটি সবার অ্যাপে পৌঁছাবে (পরের বার খুললেই)। আগের সংস্করণ ইতিহাসে থাকবে।"
          : "সম্পাদক আপনার মন্তব্য দেখে ঠিক করে আবার পাঠাবেন। অ্যাপে কিছু বদলাবে না।"
      }
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            variant={approve ? "default" : "destructive"}
            disabled={busy || (!approve && !note.trim())}
            onClick={async () => {
              setBusy(true);
              try {
                await onDecide(note);
              } finally {
                setBusy(false);
              }
            }}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : approve ? <ShieldCheck className="h-4 w-4" aria-hidden /> : <XCircle className="h-4 w-4" aria-hidden />}
            {approve ? "অনুমোদন দিন" : "ফেরত দিন"}
          </Button>
        </>
      }
    >
      <Field
        label={approve ? "মন্তব্য (ইচ্ছা হলে)" : "কী ঠিক করতে হবে *"}
        htmlFor="review-note"
        hint={approve ? undefined : "যেমন: «দোয়া ৫-এর সূত্রে হাদিস নম্বর মেলেনি — সহীহ মুসলিম দেখে ঠিক করুন»"}
      >
        <Textarea id="review-note" value={note} maxLength={1000} onChange={(e) => setNote(e.target.value)} />
      </Field>
    </Dialog>
  );
}

function ConfirmDialog({
  title,
  body,
  confirm,
  destructive,
  onClose,
  onConfirm,
  children,
  wide,
}: {
  title: string;
  body: string;
  confirm: string;
  destructive?: boolean;
  onClose: () => void;
  onConfirm: () => Promise<void>;
  children?: React.ReactNode;
  wide?: boolean;
}) {
  const [busy, setBusy] = React.useState(false);
  return (
    <Dialog
      open
      wide={wide}
      onClose={onClose}
      title={title}
      description={body}
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            variant={destructive ? "destructive" : "default"}
            disabled={busy}
            onClick={async () => {
              setBusy(true);
              try {
                await onConfirm();
              } finally {
                setBusy(false);
              }
            }}
          >
            {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : null}
            {confirm}
          </Button>
        </>
      }
    >
      {children ?? <span className="sr-only">{body}</span>}
    </Dialog>
  );
}

/** A side list the pack keeps (duas → categories): key + name rows. */
function ExtraDialog({
  cfg,
  doc,
  onClose,
  onSave,
}: {
  cfg: PackConfig;
  doc: Doc;
  onClose: () => void;
  onSave: (rows: Item[]) => void;
}) {
  const extra = cfg.extra!;
  const [rows, setRows] = React.useState<Item[]>(() => listOf(doc, extra.key).map((r) => ({ ...r })));
  const used = (key: unknown) => listOf(doc, cfg.arrayKey).filter((it) => it.category === key).length;
  const [keyField, labelField] = extra.fields;
  const keys = rows.map((r) => String(r[keyField.key] ?? "").trim());
  const dup = keys.find((k, i) => k && keys.indexOf(k) !== i);
  const empty = rows.some((r) => !String(r[keyField.key] ?? "").trim() || !String(r[labelField.key] ?? "").trim());
  return (
    <Dialog
      open
      onClose={onClose}
      title={`${cfg.labelBn}-এর ${extra.labelBn}`}
      description="অ্যাপে এই ভাগে ভাগে দেখায়। যে বিভাগে এন্ট্রি আছে, সেটি বাদ দেওয়া যায় না।"
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বাতিল
          </Button>
          <Button disabled={!!dup || empty} onClick={() => onSave(rows.map((r) => ({ ...r, [keyField.key]: String(r[keyField.key]).trim(), [labelField.key]: String(r[labelField.key]).trim() })))}>
            রাখুন
          </Button>
        </>
      }
    >
      <div className="space-y-2">
        {rows.map((r, i) => {
          const n = used(r[keyField.key]);
          return (
            <div key={i} className="flex items-center gap-2">
              <Input
                aria-label={keyField.label}
                className="w-36 font-mono"
                value={String(r[keyField.key] ?? "")}
                readOnly={n > 0}
                onChange={(e) => setRows(rows.map((x, k) => (k === i ? { ...x, [keyField.key]: e.target.value } : x)))}
              />
              <Input
                aria-label={labelField.label}
                value={String(r[labelField.key] ?? "")}
                onChange={(e) => setRows(rows.map((x, k) => (k === i ? { ...x, [labelField.key]: e.target.value } : x)))}
              />
              <span className="w-14 shrink-0 text-center text-xs text-muted-foreground">{toBn(n)}টি</span>
              <Button
                variant="ghost"
                size="icon"
                className="h-10 w-10 shrink-0 text-alert hover:bg-alert-soft hover:text-alert"
                disabled={n > 0}
                aria-label="বিভাগ বাদ দিন"
                onClick={() => setRows(rows.filter((_, k) => k !== i))}
              >
                <Trash2 className="h-4 w-4" aria-hidden />
              </Button>
            </div>
          );
        })}
        {dup ? <p className="text-xs text-alert">কী "{dup}" দুবার আছে</p> : null}
        <Button variant="outline" size="sm" onClick={() => setRows([...rows, { [keyField.key]: "", [labelField.key]: "" }])}>
          <Plus className="h-4 w-4" aria-hidden />
          নতুন {extra.labelBn}
        </Button>
        <p className="text-xs text-muted-foreground">{keyField.hint}</p>
      </div>
    </Dialog>
  );
}

// ── the page ─────────────────────────────────────────────────────────────────

export default function ContentPackPage() {
  const params = useParams<{ pack: string }>();
  const key = params?.pack as CmsPackKey;
  const cfg = PACK_CONFIGS[key] as PackConfig | undefined;
  if (!cfg) {
    return (
      <EmptyState
        title="এই কনটেন্ট পাওয়া যায়নি"
        action={
          <Link href="/content" className="text-sm font-semibold text-primary">
            সব কনটেন্ট
          </Link>
        }
      />
    );
  }
  return <PackWorkspace key={key} cfg={cfg} />;
}

function PackWorkspace({ cfg }: { cfg: PackConfig }) {
  const pack = cfg.key;
  const { user, contentReviewer } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const query = useQuery({ queryKey: ["cms-pack", pack], queryFn: () => api.cmsPack(pack) });
  const data = query.data;
  const working = data?.working ?? null;
  const live = (data?.live ?? null) as Doc | null;

  // the server's copy: the draft if there is one, else what is live
  const base = (working?.data ?? live) as Doc | null;
  const [local, setLocal] = React.useState<Doc | null>(null);
  const current = local ?? base;
  // key order aside (the database keeps its own), is the local copy the saved one?
  const baseJson = React.useMemo(() => (base ? stableJson(base) : ""), [base]);
  const currentJson = React.useMemo(() => (current ? stableJson(current) : ""), [current]);
  const dirty = local !== null && currentJson !== baseJson;
  const readOnly = working?.status === "in_review";

  // ── autosave: a moment after the last change ──
  const [saveState, setSaveState] = React.useState<SaveState>("idle");
  const [saveError, setSaveError] = React.useState("");
  const currentRef = React.useRef<Doc | null>(null);
  React.useEffect(() => {
    currentRef.current = current;
  }, [current]);

  const saveNow = React.useCallback(
    async (note?: string) => {
      const doc = currentRef.current;
      if (!doc) return;
      setSaveState("saving");
      try {
        await api.cmsSaveDraft(pack, doc, note);
        await qc.invalidateQueries({ queryKey: ["cms-pack", pack] });
        qc.invalidateQueries({ queryKey: ["cms-overview"] });
        setSaveState("saved");
      } catch (e) {
        setSaveState("error");
        setSaveError(errText(e, "সংরক্ষণ করা যায়নি"));
        throw e;
      }
    },
    [pack, qc]
  );

  React.useEffect(() => {
    if (!dirty || readOnly || saveState === "saving") return;
    const t = setTimeout(() => {
      saveNow().catch(() => undefined);
    }, saveState === "error" ? 8000 : 1200);
    return () => clearTimeout(t);
  }, [currentJson, dirty, readOnly, saveState, saveNow]);

  // leaving with unsaved work asks first
  React.useEffect(() => {
    if (!dirty && saveState !== "saving") return;
    const onBeforeUnload = (e: BeforeUnloadEvent) => {
      e.preventDefault();
    };
    window.addEventListener("beforeunload", onBeforeUnload);
    return () => window.removeEventListener("beforeunload", onBeforeUnload);
  }, [dirty, saveState]);

  const issues = React.useMemo(() => (current ? validatePack(pack, current) : []), [pack, current]);
  const byEntry = React.useMemo(() => issuesByEntry(cfg, issues), [cfg, issues]);
  const changedVsLive = React.useMemo(() => !diffIsEmpty(diffPack(cfg, live, current)), [cfg, live, current]);
  const items = listOf(current, cfg.arrayKey);

  const edit = (next: Doc) => {
    if (readOnly) return;
    setLocal(next);
  };
  const setItems = (next: Item[]) => current && edit({ ...current, [cfg.arrayKey]: next });

  // ── list state ──
  const [q, setQ] = React.useState("");
  const [onlyIssues, setOnlyIssues] = React.useState(false);
  const [editing, setEditing] = React.useState<{ index: number | null } | null>(null);
  const [removed, setRemoved] = React.useState<{ item: Item; index: number } | null>(null);
  const [dialog, setDialog] = React.useState<
    | null
    | { kind: "submit" | "discard" | "withdraw" | "csv" | "extra" }
    | { kind: "review"; decision: "approve" | "reject" }
    | { kind: "version"; rev: RevisionMeta }
  >(null);
  const isAuthor = !!working && working.authorId === user?.id;
  const canDecide = contentReviewer && readOnly && !isAuthor;
  const [tab, setTab] = React.useState<string | null>(null);
  const hasChanges = !!working || dirty;
  // the scholar opens a waiting draft on what changes; everyone else on the list
  const activeTab = tab === "changes" && !hasChanges ? "entries" : (tab ?? (canDecide ? "changes" : "entries"));

  React.useEffect(() => {
    if (!removed) return;
    const t = setTimeout(() => setRemoved(null), 8000);
    return () => clearTimeout(t);
  }, [removed]);

  const shown = React.useMemo(() => {
    const needle = q.trim().toLowerCase();
    return items
      .map((item, index) => ({ item, index }))
      .filter(({ item, index }) => {
        if (onlyIssues && !byEntry.has(index)) return false;
        if (!needle) return true;
        return JSON.stringify(item).toLowerCase().includes(needle);
      });
  }, [items, q, onlyIssues, byEntry]);
  const filtering = !!q.trim() || onlyIssues;

  const checkEntry = React.useCallback(
    (index: number | null) =>
      (candidate: Item): EntryIssues => {
        const list = [...listOf(currentRef.current, cfg.arrayKey)];
        const at = index ?? list.length;
        list[at] = candidate;
        const res: EntryIssues = { fields: new Map(), children: new Map() };
        for (const is of validatePack(pack, { ...(currentRef.current ?? {}), [cfg.arrayKey]: list })) {
          const p = parseIssuePath(cfg.arrayKey, cfg.child?.key, is.path);
          if (!p || p.index !== at) continue;
          if (p.childIndex !== null) {
            const m = res.children.get(p.childIndex) ?? new Map<string, string>();
            m.set(p.field ?? "", is.message);
            res.children.set(p.childIndex, m);
          } else res.fields.set(p.field ?? "", is.message);
        }
        return res;
      },
    [cfg, pack]
  );

  // ── actions ──
  const refresh = async () => {
    setLocal(null);
    await qc.invalidateQueries({ queryKey: ["cms-pack", pack] });
    qc.invalidateQueries({ queryKey: ["cms-overview"] });
  };

  const submit = async (note: string) => {
    try {
      await saveNow(note);
      await api.cmsSubmit(pack);
      await refresh();
      setDialog(null);
      toast("যাচাইয়ের জন্য পাঠানো হয়েছে — আলেম দেখলে জানতে পারবেন", "success");
    } catch (e) {
      toast(errText(e, "পাঠানো যায়নি"), "error");
    }
  };

  const act = async (fn: () => Promise<unknown>, ok: string) => {
    try {
      await fn();
      await refresh();
      setDialog(null);
      toast(ok, "success");
    } catch (e) {
      toast(e instanceof ApiError || e instanceof Error ? e.message : "করা যায়নি", "error");
    }
  };

  if (query.isLoading) {
    return (
      <div className="space-y-3">
        <div className="skeleton h-10 w-72" />
        <div className="skeleton h-24" />
        <div className="skeleton h-64" />
      </div>
    );
  }
  if (query.isError || !data || !current) {
    return <ErrorState error={query.error} onRetry={() => query.refetch()} />;
  }

  const liveCount = listOf(live, cfg.arrayKey).length;
  const liveRev = data.history.find((h) => h.status === "published");
  const editingItem = editing && editing.index !== null ? items[editing.index] : null;

  return (
    <div className="space-y-5">
      <Link href="/content" className="focus-ring inline-flex items-center gap-1.5 rounded text-sm text-muted-foreground hover:text-primary">
        <ArrowLeft className="h-4 w-4" aria-hidden />
        সব কনটেন্ট
      </Link>
      <PageHeading
        title={cfg.labelBn}
        description={`অ্যাপে এখন ${toBn(liveCount)}টি ${cfg.entryBn}${liveRev ? ` · সংস্করণ ${toBn(liveRev.version)} · প্রকাশ ${relativeBn(liveRev.publishedAt ?? liveRev.updatedAt)}` : ""}`}
        action={<WorkingBadge status={working?.status ?? (dirty ? "draft" : null)} />}
      />

      {/* ── where this pack stands, and the next step ── */}
      <Card className={cn(working?.status === "rejected" && "border-alert/40", readOnly && "border-gold/50")}>
        <CardContent className="space-y-3 pt-5">
          {working?.reviewNote && working.status !== "in_review" ? (
            <div className="rounded-lg border border-alert/30 bg-alert-soft/60 p-3 text-sm" role="status">
              <p className="font-semibold text-alert">
                আলেমের মন্তব্য{working.reviewerName ? ` — ${working.reviewerName}` : ""}
              </p>
              <p className="mt-0.5 whitespace-pre-wrap">{working.reviewNote}</p>
            </div>
          ) : null}

          {readOnly ? (
            <>
              <p className="text-sm">
                <b>যাচাইয়ের অপেক্ষায়</b> — {working!.authorName ?? "—"} পাঠিয়েছেন {relativeBn(working!.submittedAt ?? working!.updatedAt)}।
                {working!.note ? <span className="mt-1 block text-muted-foreground">«{working!.note}»</span> : null}
              </p>
              <div className="flex flex-wrap items-center gap-2">
                {canDecide ? (
                  <>
                    <Button onClick={() => setDialog({ kind: "review", decision: "approve" })}>
                      <ShieldCheck className="h-4 w-4" aria-hidden />
                      অনুমোদন ও প্রকাশ
                    </Button>
                    <Button variant="outline" onClick={() => setDialog({ kind: "review", decision: "reject" })}>
                      <XCircle className="h-4 w-4" aria-hidden />
                      মন্তব্যসহ ফেরত দিন
                    </Button>
                  </>
                ) : contentReviewer && isAuthor ? (
                  <p className="text-xs text-muted-foreground">আপনার নিজের পাঠানো — অন্য একজন যাচাইকারী অনুমোদন দেবেন।</p>
                ) : (
                  <p className="text-xs text-muted-foreground">অপেক্ষার সময় বদলানো যায় না।</p>
                )}
                <Button variant="ghost" onClick={() => setDialog({ kind: "withdraw" })}>
                  <Undo2 className="h-4 w-4" aria-hidden />
                  ফেরত নিন
                </Button>
              </div>
            </>
          ) : working || dirty ? (
            <div className="flex flex-wrap items-center gap-3">
              <p className="mr-auto flex items-center gap-2 text-sm">
                <b>খসড়া{working ? ` — সংস্করণ ${toBn(working.version)}` : ""}</b>
                <SaveIndicator state={dirty && saveState !== "saving" && saveState !== "error" ? "pending" : saveState} error={saveError} updatedAt={working?.updatedAt} />
              </p>
              {issues.length ? (
                <button
                  type="button"
                  className="focus-ring flex items-center gap-1.5 rounded text-sm font-medium text-warning hover:underline"
                  onClick={() => {
                    setTab("entries");
                    setOnlyIssues(true);
                  }}
                >
                  <AlertCircle className="h-4 w-4" aria-hidden />
                  {toBn(issues.length)}টি জিনিস বাকি
                </button>
              ) : null}
              <Button variant="ghost" onClick={() => setDialog({ kind: "discard" })}>
                <Trash2 className="h-4 w-4" aria-hidden />
                খসড়া বাতিল
              </Button>
              <Button onClick={() => setDialog({ kind: "submit" })} disabled={saveState === "saving"}>
                <Send className="h-4 w-4" aria-hidden />
                যাচাইয়ে পাঠান
              </Button>
            </div>
          ) : (
            <p className="flex items-center gap-2 text-sm text-muted-foreground">
              <CheckCircle2 className="h-4 w-4 shrink-0 text-primary" aria-hidden />
              এটিই এখন অ্যাপে আছে। যেকোনো পরিবর্তন প্রথমে খসড়া হবে — আলেমের যাচাইয়ের আগে অ্যাপে যাবে না।
            </p>
          )}
        </CardContent>
      </Card>

      <Tabs defaultValue="entries" value={activeTab} onValueChange={setTab} aria-label={cfg.labelBn}>
        <TabsList>
          <TabsTrigger value="entries">
            {readOnly ? "খসড়ার তালিকা" : "তালিকা"} ({toBn(items.length)})
          </TabsTrigger>
          {hasChanges ? <TabsTrigger value="changes">কী বদলাচ্ছে</TabsTrigger> : null}
          <TabsTrigger value="history">ইতিহাস</TabsTrigger>
        </TabsList>

        {/* ── entries ── */}
        <TabsPanel value="entries">
          <Card>
            <CardContent className="space-y-3 pt-5">
              <div className="flex flex-wrap items-center gap-2">
                <div className="relative min-w-0 flex-1 basis-56">
                  <Search className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground" aria-hidden />
                  <Input
                    aria-label="খুঁজুন"
                    placeholder={`${cfg.entryBn} খুঁজুন…`}
                    className="pl-9"
                    value={q}
                    onChange={(e) => setQ(e.target.value)}
                  />
                </div>
                {issues.length ? (
                  <label className="flex min-h-10 cursor-pointer items-center gap-2 rounded-md border border-border px-3 text-sm">
                    <input type="checkbox" className="accent-[var(--primary)]" checked={onlyIssues} onChange={(e) => setOnlyIssues(e.target.checked)} />
                    শুধু বাকি থাকাগুলো ({toBn(byEntry.size - (byEntry.has(-1) ? 1 : 0))})
                  </label>
                ) : null}
                {!readOnly ? (
                  <>
                    {cfg.extra ? (
                      <Button variant="outline" size="sm" onClick={() => setDialog({ kind: "extra" })}>
                        <Tags className="h-4 w-4" aria-hidden />
                        {cfg.extra.labelBn}
                      </Button>
                    ) : null}
                    <Button variant="outline" size="sm" onClick={() => setDialog({ kind: "csv" })}>
                      <FileSpreadsheet className="h-4 w-4" aria-hidden />
                      CSV
                    </Button>
                    <Button size="sm" onClick={() => setEditing({ index: null })}>
                      <Plus className="h-4 w-4" aria-hidden />
                      নতুন {cfg.entryBn}
                    </Button>
                  </>
                ) : null}
              </div>

              {removed ? (
                <div className="flex items-center gap-3 rounded-lg bg-muted px-3 py-2 text-sm" role="status">
                  <span className="min-w-0 flex-1 truncate">
                    «{String(removed.item[cfg.titleKey] ?? cfg.entryBn)}» বাদ দেওয়া হয়েছে
                  </span>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => {
                      const next = [...items];
                      next.splice(Math.min(removed.index, next.length), 0, removed.item);
                      setItems(next);
                      setRemoved(null);
                    }}
                  >
                    <Undo2 className="h-4 w-4" aria-hidden />
                    ফিরিয়ে আনুন
                  </Button>
                </div>
              ) : null}

              {byEntry.get(-1)?.length ? (
                <p className="text-sm text-alert">{byEntry.get(-1)!.map((i) => i.message).join(" · ")}</p>
              ) : null}

              {shown.length ? (
                <ul className="divide-y divide-border">
                  {shown.map(({ item, index: i }) => {
                    const its = byEntry.get(i) ?? [];
                    const sub = cfg.subtitleKey ? displayValue(cfg.fields.find((f) => f.key === cfg.subtitleKey), item[cfg.subtitleKey], current) : "";
                    const kids = cfg.child ? listOf(item, cfg.child.key).length : 0;
                    return (
                      <li key={i} className="flex items-start gap-3 py-2.5">
                        <span
                          className={cn(
                            "mt-1 flex h-7 min-w-7 shrink-0 items-center justify-center rounded-full px-1 text-xs font-bold",
                            its.length ? "bg-alert-soft text-alert" : "bg-primary-soft text-primary"
                          )}
                        >
                          {toBn(cfg.numericId && item.id !== undefined ? String(item.id) : i + 1)}
                        </span>
                        <button
                          type="button"
                          className="focus-ring min-w-0 flex-1 rounded py-0.5 text-left"
                          onClick={() => setEditing({ index: i })}
                        >
                          <span className="block truncate text-sm font-semibold text-foreground">
                            {String(item[cfg.titleKey] ?? "") || "(শিরোনাম নেই)"}
                          </span>
                          {sub ? <span className="mt-0.5 line-clamp-1 block text-xs text-muted-foreground">{sub}</span> : null}
                          {cfg.child ? (
                            <span className="mt-0.5 block text-xs text-muted-foreground">
                              {toBn(kids)}টি {cfg.child.labelBn}
                            </span>
                          ) : null}
                          {its.length ? (
                            <span className="mt-1 block text-xs font-medium text-alert">
                              {its.slice(0, 3).map((x) => issueLine(cfg, x)).join(" · ")}
                              {its.length > 3 ? ` · আরও ${toBn(its.length - 3)}টি` : ""}
                            </span>
                          ) : null}
                        </button>
                        {!readOnly ? (
                          <span className="flex shrink-0 items-center">
                            {!filtering ? (
                              <>
                                <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === 0} aria-label="উপরে সরান" onClick={() => {
                                  const n = [...items];
                                  [n[i - 1], n[i]] = [n[i], n[i - 1]];
                                  setItems(n);
                                }}>
                                  <ArrowUp className="h-4 w-4" aria-hidden />
                                </Button>
                                <Button variant="ghost" size="icon" className="h-9 w-9" disabled={i === items.length - 1} aria-label="নিচে সরান" onClick={() => {
                                  const n = [...items];
                                  [n[i], n[i + 1]] = [n[i + 1], n[i]];
                                  setItems(n);
                                }}>
                                  <ArrowDown className="h-4 w-4" aria-hidden />
                                </Button>
                              </>
                            ) : null}
                            <Button variant="ghost" size="icon" className="h-9 w-9" aria-label="সম্পাদনা" onClick={() => setEditing({ index: i })}>
                              <Pencil className="h-4 w-4" aria-hidden />
                            </Button>
                            <Button
                              variant="ghost"
                              size="icon"
                              className="h-9 w-9 text-alert hover:bg-alert-soft hover:text-alert"
                              aria-label="বাদ দিন"
                              onClick={() => {
                                setRemoved({ item, index: i });
                                setItems(items.filter((_, x) => x !== i));
                              }}
                            >
                              <Trash2 className="h-4 w-4" aria-hidden />
                            </Button>
                          </span>
                        ) : (
                          <Button variant="ghost" size="icon" className="h-9 w-9 shrink-0" aria-label="দেখুন" onClick={() => setEditing({ index: i })}>
                            <Eye className="h-4 w-4" aria-hidden />
                          </Button>
                        )}
                      </li>
                    );
                  })}
                </ul>
              ) : (
                <EmptyState
                  title={filtering ? "কিছু মেলেনি" : `এখনো কোনো ${cfg.entryBn} নেই`}
                  hint={filtering ? "অন্য শব্দে খুঁজুন বা ফিল্টার সরান" : undefined}
                />
              )}
            </CardContent>
          </Card>
        </TabsPanel>

        {/* ── what changes vs the apps ── */}
        <TabsPanel value="changes">
          <Card>
            <CardContent className="pt-5">
              <p className="mb-4 text-xs text-muted-foreground">
                অ্যাপে এখন যা আছে তার তুলনায় খসড়ায় কী বদলাচ্ছে — <ins className="rounded bg-primary-soft px-0.5 text-primary no-underline">যোগ</ins>{" "}
                ও <del className="rounded bg-alert-soft px-0.5 text-alert">বাদ</del> শব্দে শব্দে দেখানো।
              </p>
              <DiffView cfg={cfg} before={live} after={current} />
            </CardContent>
          </Card>
        </TabsPanel>

        {/* ── versions ── */}
        <TabsPanel value="history">
          <Card>
            <CardContent className="pt-5">
              {data.history.filter((h) => h.id !== working?.id).length ? (
                <ul className="divide-y divide-border">
                  {data.history
                    .filter((h) => h.id !== working?.id)
                    .map((h) => (
                      <li key={h.id} className="flex flex-wrap items-start gap-3 py-3">
                        <span className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full bg-muted text-xs font-bold">
                          {toBn(h.version)}
                        </span>
                        <span className="min-w-0 flex-1 basis-64">
                          <span className="flex flex-wrap items-center gap-2 text-sm font-semibold">
                            সংস্করণ {toBn(h.version)} <HistoryBadge status={h.status} />
                          </span>
                          {h.note ? <span className="block text-sm">{h.note}</span> : null}
                          <span className="block text-xs text-muted-foreground">
                            {toBn(h.itemCount)}টি {cfg.entryBn} · লিখেছেন {h.authorName ?? "—"}
                            {h.reviewerName ? ` · অনুমোদন ${h.reviewerName}` : ""}
                            {h.publishedAt ? ` · ${dateTimeBn(h.publishedAt)}` : ""}
                          </span>
                          {h.reviewNote ? <span className="block text-xs text-muted-foreground">মন্তব্য: {h.reviewNote}</span> : null}
                        </span>
                        <span className="flex shrink-0 gap-2">
                          {h.status !== "published" ? (
                            <Button variant="outline" size="sm" onClick={() => setDialog({ kind: "version", rev: h })}>
                              {contentReviewer && h.status === "archived" ? (
                                <>
                                  <RotateCcw className="h-4 w-4" aria-hidden />
                                  দেখুন ও ফেরান
                                </>
                              ) : (
                                <>
                                  <Eye className="h-4 w-4" aria-hidden />
                                  দেখুন
                                </>
                              )}
                            </Button>
                          ) : null}
                        </span>
                      </li>
                    ))}
                </ul>
              ) : (
                <EmptyState
                  icon={<History className="h-6 w-6" aria-hidden />}
                  title="এখনো কোনো সংস্করণ নেই"
                  hint="প্রথম খসড়া করলেই অ্যাপের বর্তমান কনটেন্ট সংস্করণ ১ হিসেবে রাখা হবে — যেন সবসময় ফেরানো যায়।"
                />
              )}
            </CardContent>
          </Card>
        </TabsPanel>
      </Tabs>

      {/* ── dialogs ── */}
      {editing ? (
        <EntryDialog
          title={
            readOnly
              ? `${cfg.entryBn} ${toBn((editing.index ?? 0) + 1)}`
              : editing.index === null
                ? `নতুন ${cfg.entryBn}`
                : `${cfg.entryBn} সম্পাদনা`
          }
          fields={cfg.fields}
          initial={editingItem}
          siblings={editing.index === null ? items : items.filter((_, x) => x !== editing.index)}
          idKey={cfg.idKey}
          idGen={cfg.idKey ? { numericId: cfg.numericId, idPrefix: cfg.idPrefix } : undefined}
          child={cfg.child}
          doc={current}
          readOnly={readOnly}
          check={checkEntry(editing.index)}
          onClose={() => setEditing(null)}
          onSubmit={(item) => {
            setItems(editing.index === null ? [...items, item] : items.map((it, x) => (x === editing.index ? item : it)));
            setEditing(null);
          }}
        />
      ) : null}

      {dialog?.kind === "submit" ? (
        <SubmitDialog
          cfg={cfg}
          initialNote={working?.note ?? ""}
          issues={issues}
          changed={changedVsLive}
          onClose={() => setDialog(null)}
          onSend={submit}
        />
      ) : null}
      {dialog?.kind === "review" ? (
        <ReviewDialog
          decision={dialog.decision}
          onClose={() => setDialog(null)}
          onDecide={(note) =>
            act(
              () => api.cmsReview(pack, dialog.decision, note.trim() || undefined),
              dialog.decision === "approve" ? "প্রকাশিত — অ্যাপগুলো পরের বার খুললেই পাবে" : "মন্তব্যসহ সম্পাদকের কাছে ফেরত গেছে"
            )
          }
        />
      ) : null}
      {dialog?.kind === "discard" ? (
        <ConfirmDialog
          title="খসড়া বাতিল করবেন?"
          body="খসড়ার সব পরিবর্তন মুছে যাবে। অ্যাপে যা আছে তা-ই থাকবে।"
          confirm="বাতিল করুন"
          destructive
          onClose={() => setDialog(null)}
          onConfirm={() => act(() => (working ? api.cmsDiscardDraft(pack) : Promise.resolve()), "খসড়া বাতিল হয়েছে")}
        />
      ) : null}
      {dialog?.kind === "withdraw" ? (
        <ConfirmDialog
          title="যাচাই থেকে ফেরত নেবেন?"
          body="খসড়াটি আবার বদলানো যাবে; পরে আবার পাঠাতে হবে।"
          confirm="ফেরত নিন"
          onClose={() => setDialog(null)}
          onConfirm={() => act(() => api.cmsWithdraw(pack), "ফেরত নেওয়া হয়েছে — এখন বদলাতে পারবেন")}
        />
      ) : null}
      {dialog?.kind === "csv" ? (
        <CsvDialog
          cfg={cfg}
          doc={current}
          onClose={() => setDialog(null)}
          onApply={(next, summary) => {
            edit(next);
            setDialog(null);
            toast(summary, "success");
          }}
        />
      ) : null}
      {dialog?.kind === "extra" ? (
        <ExtraDialog
          cfg={cfg}
          doc={current}
          onClose={() => setDialog(null)}
          onSave={(rows) => {
            edit({ ...current, [cfg.extra!.key]: rows });
            setDialog(null);
          }}
        />
      ) : null}
      {dialog?.kind === "version" ? (
        <VersionDialog
          cfg={cfg}
          rev={dialog.rev}
          live={live}
          canRestore={contentReviewer && dialog.rev.status === "archived"}
          onClose={() => setDialog(null)}
          onRestore={() =>
            act(() => api.cmsRollback(pack, dialog.rev.id), `সংস্করণ ${toBn(dialog.rev.version)} আবার প্রকাশিত হয়েছে`)
          }
        />
      ) : null}
    </div>
  );
}

function SaveIndicator({
  state,
  error,
  updatedAt,
}: {
  state: SaveState | "pending";
  error: string;
  updatedAt?: string;
}) {
  if (state === "saving" || state === "pending") {
    return (
      <span className="flex items-center gap-1 text-xs text-muted-foreground" role="status">
        <Loader2 className="h-3.5 w-3.5 animate-spin" aria-hidden />
        সংরক্ষণ হচ্ছে…
      </span>
    );
  }
  if (state === "error") {
    return (
      <span className="flex items-center gap-1 text-xs text-alert" role="alert" title={error}>
        <CloudOff className="h-3.5 w-3.5" aria-hidden />
        সংরক্ষণ হয়নি — আবার চেষ্টা হচ্ছে
      </span>
    );
  }
  return (
    <span className="flex items-center gap-1 text-xs text-muted-foreground">
      <Cloud className="h-3.5 w-3.5" aria-hidden />
      সংরক্ষিত{updatedAt ? ` · ${relativeBn(updatedAt)}` : ""}
    </span>
  );
}

/** An earlier version: what restoring it would change, and (reviewer) restore. */
function VersionDialog({
  cfg,
  rev,
  live,
  canRestore,
  onClose,
  onRestore,
}: {
  cfg: PackConfig;
  rev: RevisionMeta;
  live: Doc | null;
  canRestore: boolean;
  onClose: () => void;
  onRestore: () => Promise<void>;
}) {
  const full = useQuery({ queryKey: ["cms-rev", cfg.key, rev.id], queryFn: () => api.cmsRevision(cfg.key, rev.id) });
  const [busy, setBusy] = React.useState(false);
  return (
    <Dialog
      open
      wide
      onClose={onClose}
      title={`সংস্করণ ${toBn(rev.version)}`}
      description={
        canRestore
          ? "এটি আবার প্রকাশ করলে অ্যাপে এখন যা আছে তার তুলনায় নিচের পরিবর্তনগুলো হবে। এখনকারটিও ইতিহাসে থাকবে।"
          : "অ্যাপে এখন যা আছে তার তুলনায় এই সংস্করণে কী আলাদা ছিল"
      }
      footer={
        <>
          <Button variant="outline" onClick={onClose}>
            বন্ধ করুন
          </Button>
          {canRestore ? (
            <Button
              disabled={busy || !full.data}
              onClick={async () => {
                setBusy(true);
                try {
                  await onRestore();
                } finally {
                  setBusy(false);
                }
              }}
            >
              {busy ? <Loader2 className="h-4 w-4 animate-spin" aria-hidden /> : <RotateCcw className="h-4 w-4" aria-hidden />}
              এই সংস্করণ আবার প্রকাশ করুন
            </Button>
          ) : null}
        </>
      }
    >
      {full.isLoading ? (
        <div className="skeleton h-40" />
      ) : full.isError ? (
        <ErrorState error={full.error} onRetry={() => full.refetch()} />
      ) : (
        <DiffView cfg={cfg} before={live} after={full.data!.data} />
      )}
    </Dialog>
  );
}
