"use client";

import type { RevisionStatus } from "@/lib/api";
import { Badge } from "@/components/ui/badge";

/** The working copy's state, as the editor and the scholar see it. */
export const WORKING_LABEL_BN: Record<"draft" | "in_review" | "rejected", string> = {
  draft: "খসড়া",
  in_review: "যাচাইয়ের অপেক্ষায়",
  rejected: "ফেরত এসেছে",
};

/** A version in the history. */
export const HISTORY_LABEL_BN: Record<RevisionStatus, string> = {
  draft: "খসড়া",
  in_review: "যাচাইয়ের অপেক্ষায়",
  rejected: "ফেরত",
  published: "এখন অ্যাপে",
  archived: "আগের সংস্করণ",
};

export function WorkingBadge({ status }: { status: RevisionStatus | null | undefined }) {
  if (status === "in_review") return <Badge variant="gold">{WORKING_LABEL_BN.in_review}</Badge>;
  if (status === "rejected") return <Badge variant="alert">{WORKING_LABEL_BN.rejected}</Badge>;
  if (status === "draft") return <Badge variant="warning">{WORKING_LABEL_BN.draft}</Badge>;
  return <Badge variant="success">প্রকাশিত</Badge>;
}

export function HistoryBadge({ status }: { status: RevisionStatus }) {
  const variant = status === "published" ? "success" : status === "rejected" ? "alert" : "muted";
  return <Badge variant={variant}>{HISTORY_LABEL_BN[status]}</Badge>;
}
