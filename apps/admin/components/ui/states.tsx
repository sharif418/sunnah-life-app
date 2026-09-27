"use client";

import * as React from "react";
import { AlertTriangle, Inbox, RefreshCw } from "lucide-react";
import { Button } from "./button";
import { cn } from "@/lib/utils";

export function EmptyState({
  icon,
  title,
  hint,
  action,
  className,
}: {
  icon?: React.ReactNode;
  title: string;
  hint?: string;
  action?: React.ReactNode;
  className?: string;
}) {
  return (
    <div
      className={cn(
        "flex flex-col items-center justify-center gap-2 rounded-lg border border-dashed border-border bg-card/50 px-6 py-10 text-center",
        className
      )}
    >
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-primary-soft text-primary">
        {icon ?? <Inbox className="h-6 w-6" aria-hidden />}
      </div>
      <p className="text-sm font-semibold text-foreground">{title}</p>
      {hint ? <p className="max-w-md text-sm text-muted-foreground">{hint}</p> : null}
      {action ? <div className="mt-2">{action}</div> : null}
    </div>
  );
}

export function ErrorState({
  error,
  onRetry,
  title = "তথ্য আনা যায়নি",
  className,
}: {
  error?: unknown;
  onRetry?: () => void;
  title?: string;
  className?: string;
}) {
  const message =
    error instanceof Error && error.message ? error.message : "নেটওয়ার্ক সমস্যা হয়েছে — আবার চেষ্টা করুন";
  return (
    <div
      role="alert"
      className={cn(
        "flex flex-col items-center justify-center gap-2 rounded-lg border border-alert/30 bg-alert-soft/60 px-6 py-10 text-center",
        className
      )}
    >
      <div className="flex h-12 w-12 items-center justify-center rounded-full bg-alert-soft text-alert">
        <AlertTriangle className="h-6 w-6" aria-hidden />
      </div>
      <p className="text-sm font-semibold text-foreground">{title}</p>
      <p className="max-w-md text-sm text-alert">{message}</p>
      {onRetry ? (
        <Button variant="outline" size="sm" className="mt-2" onClick={onRetry}>
          <RefreshCw className="h-4 w-4" aria-hidden />
          আবার চেষ্টা করুন
        </Button>
      ) : null}
    </div>
  );
}

/** Page-level role gate — the app-shell hides nav links, but a direct URL
 *  must not leak data either (the API enforces too; this is UX defense). */
export function RoleGate({
  allow,
  role,
  children,
}: {
  allow: (r: string) => boolean;
  role: string | null | undefined;
  children: React.ReactNode;
}) {
  if (role && allow(role)) return <>{children}</>;
  return (
    <EmptyState
      title="এই অংশটি আপনার জন্য নয়"
      hint="এই পৃষ্ঠাটি শুধুমাত্র অনুমোদিত তত্ত্বাবধায়কদের জন্য। প্রয়োজন হলে প্রধান অ্যাডমিনের সাথে যোগাযোগ করুন।"
      className="my-10"
    />
  );
}

/** Consistent page heading with icon, title, description and optional action. */
export function PageHeading({
  icon,
  title,
  description,
  action,
}: {
  icon?: React.ReactNode;
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-wrap items-start justify-between gap-3">
      <div className="flex items-start gap-3">
        {icon ? (
          <div className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary-soft text-primary">
            {icon}
          </div>
        ) : null}
        <div>
          <h1 className="text-xl font-bold tracking-tight text-foreground md:text-2xl">{title}</h1>
          {description ? (
            <p className="mt-0.5 max-w-2xl text-sm leading-relaxed text-muted-foreground">{description}</p>
          ) : null}
        </div>
      </div>
      {action ? <div className="flex items-center gap-2">{action}</div> : null}
    </div>
  );
}
