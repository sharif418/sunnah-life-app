"use client";

import * as React from "react";
import { Check, Circle, Clock3, Lock, LockOpen, Printer, RotateCcw } from "lucide-react";
import type { AmalDefinition, AmalValue, MonthGrid, MonthGridCell, User } from "@/lib/api";
import { bdToday, cadenceApplies, toBn, monthLabel, weekdayLetter } from "@/lib/bn";
import { AMAL_CATEGORY_LABELS_BN, LEVEL_ORDER } from "@/lib/labels";
import { cn } from "@/lib/utils";
import { Button } from "@/components/ui/button";
import { useToast } from "@/components/ui/toast";

type CellKind = "jamaat" | "alone" | "qaza" | "done" | "partial" | "missed" | "future" | "na";

function classifyCell(
  def: AmalDefinition,
  cell: MonthGridCell | undefined,
  day: string,
  today: string,
  userCategory: string
): { kind: CellKind; label: string; display?: string } {
  if (!cell || !cadenceApplies(def.cadence, day)) {
    return { kind: "na", label: "প্রযোজ্য নয়" };
  }
  const v: AmalValue | null = cell.value;
  const isPast = day <= today;
  if (def.inputType === "tristate") {
    if (v === "jamaat") return { kind: "jamaat", label: "জামাতে আদায়" };
    if (v === "alone") return { kind: "alone", label: "একা আদায়" };
    if (v === "qaza") return { kind: "qaza", label: "কাযা হয়েছে" };
    return isPast
      ? { kind: "missed", label: "বাদ পড়েছে" }
      : { kind: "future", label: "এখনো হয়নি" };
  }
  if (def.inputType === "boolean") {
    if (v === true) return { kind: "done", label: "সম্পূর্ণ হয়েছে" };
    if (v === false) return isPast ? { kind: "missed", label: "বাদ পড়েছে" } : { kind: "future", label: "এখনো হয়নি" };
    return isPast ? { kind: "missed", label: "বাদ পড়েছে" } : { kind: "future", label: "এখনো হয়নি" };
  }
  if (def.inputType === "count" || def.inputType === "quantity") {
    const n = typeof v === "number" ? v : Number(v);
    if (isFinite(n) && n > 0) {
      const target = def.target?.[userCategory] ?? def.target?.["general"] ?? 1;
      return n >= target
        ? { kind: "done", label: `সম্পূর্ণ — ${toBn(n)}`, display: toBn(n) }
        : { kind: "partial", label: `আংশিক — ${toBn(n)} (লক্ষ্য ${toBn(target)})`, display: toBn(n) };
    }
    return isPast ? { kind: "missed", label: "বাদ পড়েছে" } : { kind: "future", label: "এখনো হয়নি" };
  }
  if (def.inputType === "text") {
    if (typeof v === "string" && v.trim()) return { kind: "done", label: "লেখা হয়েছে" };
    return isPast ? { kind: "missed", label: "বাদ পড়েছে" } : { kind: "future", label: "এখনো হয়নি" };
  }
  return { kind: "na", label: "প্রযোজ্য নয়" };
}

const KIND_CLASS: Record<CellKind, string> = {
  jamaat: "mg-jamaat",
  alone: "mg-alone",
  qaza: "mg-qaza",
  done: "mg-done",
  partial: "mg-partial",
  missed: "mg-missed",
  future: "mg-future",
  na: "mg-na",
};

const LEGEND: { kind: CellKind; label: string }[] = [
  { kind: "jamaat", label: "জামাত" },
  { kind: "alone", label: "একা" },
  { kind: "qaza", label: "কাযা" },
  { kind: "done", label: "সম্পূর্ণ" },
  { kind: "partial", label: "আংশিক" },
  { kind: "missed", label: "বাদ পড়েছে" },
  { kind: "future", label: "বাকি আছে" },
];

interface MonthGridHeatmapProps {
  grid: MonthGrid;
  user: Pick<User, "category" | "level" | "name">;
  month: string;
  unlockedDays: Set<string>;
  canUnlock: boolean;
  onUnlockDay: (date: string) => void;
}

/**
 * 31-column Muhasaba heatmap — mirrors the paper diary: amal rows × day
 * columns, color-coded cells, sticky amal-name column, weekday letters,
 * today highlighted, locked days with unlock affordance for supervisors.
 */
export function MonthGridHeatmap({
  grid,
  user,
  month,
  unlockedDays,
  canUnlock,
  onUnlockDay,
}: MonthGridHeatmapProps) {
  const today = bdToday();
  const { toast } = useToast();

  const defs = grid.definitions;

  const dayHeader = (day: string, index: number) => {
    const d = new Date(day + "T00:00:00");
    const isToday = day === today;
    const isFuture = day > today;
    const locked = day < today && !unlockedDays.has(day);
    const unlocked = unlockedDays.has(day);
    const label = `${toBn(index + 1)} ${weekdayLetter(d)}${locked ? " — লকড" : unlocked ? " — আনলক করা" : ""}`;
    return (
      <th
        key={day}
        scope="col"
        className={cn(
          "min-w-[34px] border-b border-border px-0.5 pb-1 pt-1.5 align-top",
          isToday && "rounded-t-md"
        )}
      >
        <button
          type="button"
          disabled={!canUnlock || !locked}
          onClick={() => onUnlockDay(day)}
          title={
            locked
              ? canUnlock
                ? "লকড দিন — ক্লিক করে আনলক করুন"
                : "লকড দিন (ইশরাকের পর স্বয়ংক্রিয়)"
              : unlocked
                ? "উসরা প্রধান আনলক করেছেন"
                : "চলতি দিন"
          }
          className={cn(
            "flex w-full flex-col items-center gap-0.5 rounded-md px-0.5 py-1",
            isToday && "mg-today shadow-card",
            locked && canUnlock && "cursor-pointer hover:opacity-80"
          )}
          aria-label={`${toBn(index + 1)} তারিখ — ${weekdayLetter(d)}${locked ? " (লকড)" : ""}`}
        >
          <span
            className={cn(
              "text-[9px] leading-none",
              isToday ? "opacity-80" : "text-muted-foreground/70"
            )}
          >
            {weekdayLetter(d)}
          </span>
          <span className="flex items-center gap-0.5">
            <span className={cn("text-[11px] font-bold leading-none", isFuture && !isToday && "text-muted-foreground")}>
              {toBn(index + 1)}
            </span>
            {unlocked ? (
              <LockOpen className="h-2.5 w-2.5 text-success" aria-label="আনলক করা" />
            ) : locked ? (
              <Lock className="h-2.5 w-2.5 text-gold" aria-label="লকড" />
            ) : null}
          </span>
        </button>
      </th>
    );
  };

  return (
    <div className="space-y-3">
      <div className="scroll-thin overflow-x-auto rounded-lg border border-border bg-card shadow-card">
        <table className="w-full border-collapse text-sm" aria-label={`${user.name} — ${monthLabel(month)} মাসের মুহাসাবা গ্রিড`}>
          <thead className="sticky top-0 z-20 bg-card">
            <tr>
              <th scope="col" className="sticky left-0 z-30 min-w-[190px] border-b border-r border-border bg-card px-3 pb-1 pt-2 text-left text-xs font-bold text-muted-foreground">
                আমল
                <span className="ml-2 font-normal text-muted-foreground/70">({monthLabel(month)})</span>
              </th>
              {grid.days.map(dayHeader)}
            </tr>
          </thead>
          <tbody>
            {defs.map((def) => {
              const cells = grid.rows[def.key] ?? [];
              const levelIdx = (l: string) => Math.max(0, LEVEL_ORDER.indexOf(l as never));
              const dimmed = levelIdx(def.minLevel) > levelIdx(user.level);
              return (
                <tr key={def.key} className="group">
                  <th
                    scope="row"
                    className={cn(
                      "sticky left-0 z-10 border-b border-r border-border bg-card px-3 py-1.5 text-left font-normal",
                      dimmed && "opacity-50"
                    )}
                  >
                    <span className="flex flex-col">
                      <span className="truncate text-xs font-semibold text-foreground" title={def.titleBn}>
                        {def.titleBn}
                      </span>
                      <span className="text-[10px] text-muted-foreground">
                        {AMAL_CATEGORY_LABELS_BN[def.category]}
                        {dimmed ? " · উচ্চ স্তরের আমল" : ""}
                      </span>
                    </span>
                  </th>
                  {grid.days.map((day, i) => {
                    const c = classifyCell(def, cells[i], day, today, user.category);
                    const locked = day < today && !unlockedDays.has(day);
                    const sourceNote =
                      c.kind !== "na" && cells[i]?.source && cells[i]?.source !== "manual"
                        ? ` · স্বয়ংক্রিয় (${cells[i].source})`
                        : "";
                    return (
                      <td key={day} className="border-b border-border/40 px-0.5 py-0.5 text-center">
                        <span
                          className={cn("mg-cell", KIND_CLASS[c.kind], locked && c.kind !== "na" && "mg-lockedcol")}
                          title={`${def.titleBn} · ${toBn(i + 1)} তারিখ — ${c.label}${sourceNote}`}
                          role="presentation"
                        >
                          {c.kind === "jamaat" ? (
                            <Check className="h-3 w-3" strokeWidth={3} aria-hidden />
                          ) : c.kind === "alone" ? (
                            <Circle className="h-2.5 w-2.5" aria-hidden />
                          ) : c.kind === "qaza" ? (
                            <RotateCcw className="h-3 w-3" aria-hidden />
                          ) : c.kind === "done" && def.inputType !== "count" && def.inputType !== "quantity" ? (
                            <Check className="h-3 w-3" strokeWidth={3} aria-hidden />
                          ) : (
                            (c.display ?? "")
                          )}
                        </span>
                      </td>
                    );
                  })}
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>

      <div className="flex flex-wrap items-center gap-x-4 gap-y-2">
        {LEGEND.map((l) => (
          <span key={l.kind} className="flex items-center gap-1.5 text-xs text-muted-foreground">
            <span className={cn("mg-cell !h-4 !w-4 !text-[8px]", KIND_CLASS[l.kind])} aria-hidden />
            {l.label}
          </span>
        ))}
        <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <Lock className="h-3 w-3 text-gold" aria-hidden />
          লকড দিন (ইশরাকের পর স্বয়ংক্রিয়)
        </span>
        <span className="flex items-center gap-1.5 text-xs text-muted-foreground">
          <Clock3 className="h-3 w-3" aria-hidden />
          আজকের কলাম সোনালি
        </span>
        {canUnlock ? (
          <span className="ml-auto hidden text-xs text-muted-foreground lg:block">
            লকড দিনের শিরোনামে ক্লিক করলে আনলক করা যাবে
          </span>
        ) : null}
      </div>

      <Button
        variant="outline"
        size="sm"
        className="no-print"
        onClick={() => {
          toast("ব্রাউজারের প্রিন্ট ডায়ালগ খুলছে — \"Save as PDF\" নির্বাচন করুন", "info");
          window.setTimeout(() => window.print(), 350);
        }}
      >
        <Printer className="h-4 w-4" aria-hidden />
        মাসিক রিপোর্ট প্রিন্ট / PDF
      </Button>
    </div>
  );
}
