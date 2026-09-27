"use client";

// দাওয়াত views-এর শেয়ার্ড প্রিমিটিভ: async loader hook, স্তর/ভূমিকা ব্যাজ,
// খালা/ভুল/স্কেলেটন স্টেট, বাংলা সময় হেল্পার।

import * as React from "react";
import { RefreshCw, AlertTriangle } from "lucide-react";
import { Button } from "@/components/ui/button";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";
import { toBn } from "@/lib/calendars";
import { LEVEL_LABELS_BN } from "@/types/domain";
import type { Level, Role } from "@/types/domain";
import { ROLE_LABELS_BN } from "@/types/domain";

// ── async data ──────────────────────────────────────────────────────────────

/** Promise-state hook with manual reload; a `key` change re-runs the fetch. */
export function useAsync<T>(fn: () => Promise<T>, key: string | number | null = null) {
  const [data, setData] = React.useState<T | null>(null);
  const [loading, setLoading] = React.useState(true);
  const [error, setError] = React.useState<string | null>(null);
  const [nonce, setNonce] = React.useState(0);
  const fnRef = React.useRef(fn);
  const reload = React.useCallback(() => setNonce((n) => n + 1), []);

  // keep the latest fn without re-running the fetch (latest-ref pattern)
  React.useEffect(() => {
    fnRef.current = fn;
  });

  React.useEffect(() => {
    let alive = true;
    setLoading(true);
    setError(null);
    fnRef.current().then(
      (d) => {
        if (!alive) return;
        setData(d);
        setLoading(false);
      },
      (e: unknown) => {
        if (!alive) return;
        setError(e instanceof Error ? e.message : "দুঃখিত, কিছু একটা সমস্যা হয়েছে");
        setLoading(false);
      }
    );
    return () => {
      alive = false;
    };
  }, [key, nonce]);

  return { data, loading, error, reload };
}

// ── হেল্পার ────────────────────────────────────────────────────────────────

/** clipboard copy — resolves false when blocked. */
export async function copyText(text: string): Promise<boolean> {
  if (typeof navigator === "undefined" || !navigator.clipboard) return false;
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    return false;
  }
}

/** আপেক্ষিক সময়: "এইমাত্র", "৩ ঘণ্টা আগে", "৫ দিন আগে" */
export function relTimeBn(iso: string | null | undefined): string {
  if (!iso) return "";
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return "";
  const min = Math.floor((Date.now() - t) / 60000);
  if (min < 1) return "এইমাত্র";
  if (min < 60) return `${toBn(min)} মিনিট আগে`;
  const h = Math.floor(min / 60);
  if (h < 24) return `${toBn(h)} ঘণ্টা আগে`;
  const d = Math.floor(h / 24);
  if (d < 30) return `${toBn(d)} দিন আগে`;
  return toBn(iso.slice(0, 10));
}

export function levelLabel(level: Level): string {
  return LEVEL_LABELS_BN[level] ?? level;
}

// ── ছোট UI atoms ────────────────────────────────────────────────────────────

export function SectionHeader({
  icon: Icon,
  title,
  hint,
  action,
  className,
}: {
  icon?: React.ElementType;
  title: string;
  hint?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("mb-3 mt-6 flex items-center gap-2 first:mt-0", className)}>
      {Icon ? <Icon className="size-4 shrink-0 text-primary" /> : null}
      <div className="min-w-0">
        <h2 className="text-base font-bold leading-tight">{title}</h2>
        {hint ? <p className="text-xs text-muted-foreground">{hint}</p> : null}
      </div>
      {action ? <div className="ms-auto shrink-0">{action}</div> : null}
    </div>
  );
}

export function LevelBadge({ level, className }: { level: Level; className?: string }) {
  return (
    <span className={cn("inline-flex rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary", className)}>
      {levelLabel(level)}
    </span>
  );
}

export function RoleBadge({ role }: { role: Role }) {
  return (
    <span className="inline-flex rounded-full bg-gold-soft px-2.5 py-0.5 text-xs font-semibold text-gold-foreground">
      {ROLE_LABELS_BN[role] ?? role}
    </span>
  );
}

export function EmptyState({
  icon: Icon,
  title,
  hint,
  action,
}: {
  icon?: React.ElementType;
  title: string;
  hint?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="py-10 text-center">
      <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-primary-soft">
        {Icon ? <Icon className="size-7 text-primary/60" /> : null}
      </div>
      <p className="mt-3 text-sm font-semibold">{title}</p>
      {hint ? <p className="mx-auto mt-1 max-w-sm px-4 text-xs leading-relaxed text-muted-foreground">{hint}</p> : null}
      {action ? <div className="mt-4 flex justify-center">{action}</div> : null}
    </div>
  );
}

export function ErrorState({ message, onRetry }: { message: string; onRetry?: () => void }) {
  return (
    <div className="rounded-xl border border-alert/20 bg-alert-soft px-4 py-5 text-center">
      <AlertTriangle className="mx-auto size-6 text-alert" />
      <p className="mt-2 text-sm font-semibold text-alert">{message}</p>
      {onRetry ? (
        <Button variant="outline" size="sm" className="mt-3 h-9 rounded-full" onClick={onRetry}>
          <RefreshCw className="size-3.5" /> আবার চেষ্টা করুন
        </Button>
      ) : null}
    </div>
  );
}

export function SkeletonRows({ count = 4, className }: { count?: number; className?: string }) {
  return (
    <div className="space-y-3" aria-hidden>
      {Array.from({ length: count }, (_, i) => (
        <Skeleton key={i} className={cn("h-16 w-full rounded-xl", className)} />
      ))}
    </div>
  );
}

/** Initials avatar (name → 2 chars)। */
export function InitialsAvatar({ name, className }: { name: string; className?: string }) {
  const initials = name.trim().slice(0, 2) || "?";
  return (
    <span
      className={cn("flex size-10 shrink-0 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-foreground", className)}
      aria-hidden
    >
      {initials}
    </span>
  );
}

/** সাপ্তাহিক রিভিউ অবস্থার পিল। */
export function ReviewStatusPill({ status }: { status: "pending" | "done" | "overdue" }) {
  const map = {
    done: { label: "সম্পন্ন", cls: "bg-primary-soft text-primary" },
    pending: { label: "অপেক্ষমাণ", cls: "bg-gold-soft text-gold-foreground" },
    overdue: { label: "বিলম্বিত", cls: "bg-alert-soft text-alert" },
  } as const;
  const s = map[status];
  return <span className={cn("inline-flex rounded-full px-2.5 py-0.5 text-xs font-semibold", s.cls)}>{s.label}</span>;
}
