import type { ReactNode } from "react";
import { Eye, EyeOff } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { cn } from "@/lib/utils";
import type { Gender, Level, Role, UserCategory } from "@/lib/api";
import {
  CATEGORY_LABELS_BN,
  GENDER_LABELS_BN,
  LEVEL_LABELS_BN,
  ROLE_LABELS_BN,
} from "@/lib/labels";

/** Tiny venus/mars glyphs (lucide has no gender icons). */
export function GenderGlyph({ gender, className }: { gender: Gender; className?: string }) {
  return (
    <svg
      viewBox="0 0 16 16"
      aria-hidden
      className={cn("h-3.5 w-3.5", className)}
      fill="currentColor"
    >
      {gender === "M" ? (
        <path d="M14 2h-4.2v2h2.78L8.5 8.08A4.7 4.7 0 1 0 7.08 9.5L11.1 5.48V8h2V4h.9V2zM5.2 9.6a3 3 0 1 1 0-6 3 3 0 0 1 0 6z" />
      ) : (
        <path d="M9 6.2a3.8 3.8 0 1 0-1.9 3.3v1.4H5.5v1.9h1.6V15h1.9v-2.2h1.6v-1.9H9V9.5A3.8 3.8 0 0 0 9 6.2zM7.2 9a2.3 2.3 0 1 1 0-4.6 2.3 2.3 0 0 1 0 4.6z" />
      )}
    </svg>
  );
}

export function GenderBadge({ gender, className }: { gender: Gender; className?: string }) {
  return (
    <Badge
      variant={gender === "F" ? "gold" : "default"}
      className={className}
      aria-label={`লিঙ্গ: ${GENDER_LABELS_BN[gender]}`}
    >
      <GenderGlyph gender={gender} />
      {GENDER_LABELS_BN[gender]}
    </Badge>
  );
}

export function RoleBadge({ role }: { role: Role }) {
  const variant =
    role === "full_admin" ? "solid" : role === "invigilator" ? "gold" : "default";
  return (
    <Badge variant={variant} aria-label={`ভূমিকা: ${ROLE_LABELS_BN[role]}`}>
      {ROLE_LABELS_BN[role]}
    </Badge>
  );
}

export function LevelBadge({ level }: { level: Level }) {
  if (level === "none") return <Badge variant="outline">শুরুর পর্যায়</Badge>;
  return (
    <Badge variant={level.startsWith("farze") ? "gold" : "default"} aria-label={`স্তর: ${LEVEL_LABELS_BN[level]}`}>
      {LEVEL_LABELS_BN[level]}
    </Badge>
  );
}

export function CategoryBadge({ category }: { category: UserCategory }) {
  if (category === "general") return <Badge variant="outline">সাধারণ</Badge>;
  return <Badge variant="muted">{CATEGORY_LABELS_BN[category]}</Badge>;
}

/** Female-data trust badge — shown on gender-scoped views. */
export function FScopeBadge() {
  return (
    <Badge variant="gold" aria-label="নারী পরিদর্শকের জন্য দৃশ্যমান">
      <Eye className="h-3 w-3" aria-hidden />
      নারী পরিদর্শকের জন্য দৃশ্যমান
    </Badge>
  );
}

/** Both-genders indicator for full admins. */
export function BothGendersBadge() {
  return (
    <Badge variant="success" aria-label="উভয় লিঙ্গের তথ্য দৃশ্যমান">
      <Eye className="h-3 w-3" aria-hidden />
      উভয় লিঙ্গ দৃশ্যমান
    </Badge>
  );
}

/** Subtle "gender-restricted data" marker on member rows. */
export function GenderScopeNote({ gender }: { gender: Gender }) {
  return (
    <span className="inline-flex items-center gap-1 text-xs text-muted-foreground">
      {gender === "F" ? (
        <EyeOff className="h-3 w-3 text-gold" aria-hidden />
      ) : null}
      {gender === "F" ? "সুরক্ষিত তথ্য" : "সাধারণ দৃশ্যমানতা"}
    </span>
  );
}

export function TrustNote({ children }: { children: ReactNode }) {
  return (
    <div className="flex items-start gap-2 rounded-md border border-gold/40 bg-gold-soft/70 p-3 text-xs leading-relaxed text-foreground dark:text-gold">
      {children}
    </div>
  );
}
