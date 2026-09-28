"use client";

// ─────────────────────────────────────────────────────────────────────────────
// Amal diary controls — the interactive paper-diary widgets (mirrors
// apps/mobile/lib/features/amal/amal_widgets.dart): tri-state জামাত/একা/কাযা
// chips, boolean check, count stepper with quick-set, quantity input, SVG
// completion ring, streak badge. 44px touch targets everywhere.
// ─────────────────────────────────────────────────────────────────────────────

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { Check, Flame, History, Minus, PersonStanding, Plus, Users } from "lucide-react";
import { Input } from "@/components/ui/input";
import { Button } from "@/components/ui/button";
import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";
import { toBn } from "@/lib/calendars";
import { bnNumber } from "./amal-logic";
import type { TriState } from "@/types/domain";

// ── জামাত / একা / কাযা ───────────────────────────────────────────────────────

const TRI_STATES: { key: TriState; label: string; icon: React.ElementType; activeClass: string }[] = [
  { key: "jamaat", label: "জামাত", icon: Users, activeClass: "border-transparent bg-primary text-primary-foreground shadow-card" },
  { key: "alone", label: "একা", icon: PersonStanding, activeClass: "border-transparent bg-secondary text-secondary-foreground" },
  { key: "qaza", label: "কাযা", icon: History, activeClass: "border-alert/60 bg-alert-soft text-alert" },
];

export function TriStateChips({
  value,
  disabled,
  onSelect,
}: {
  value: string;
  disabled?: boolean;
  onSelect: (v: TriState | "") => void;
}) {
  return (
    <div role="group" className="grid grid-cols-3 gap-2">
      {TRI_STATES.map(({ key, label, icon: Icon, activeClass }) => {
        const selected = value === key;
        return (
          <motion.button
            key={key}
            type="button"
            aria-pressed={selected}
            disabled={disabled}
            whileTap={disabled ? undefined : { scale: 0.96 }}
            transition={{ duration: 0.15 }}
            onClick={() => onSelect(selected ? "" : key)}
            className={cn(
              "tap-target flex h-11 items-center justify-center gap-1.5 rounded-lg border-2 px-1 transition-colors duration-150",
              selected
                ? activeClass
                : "border-border bg-muted/50 text-muted-foreground hover:bg-muted",
              disabled && "cursor-not-allowed opacity-60"
            )}
          >
            <Icon className="size-4 shrink-0" />
            <span className="truncate text-sm font-semibold">{label}</span>
          </motion.button>
        );
      })}
    </div>
  );
}

// ── Boolean check ────────────────────────────────────────────────────────────

export function BooleanCheck({
  value,
  disabled,
  onToggle,
}: {
  value: boolean;
  disabled?: boolean;
  onToggle: (v: boolean) => void;
}) {
  return (
    <motion.button
      type="button"
      role="checkbox"
      aria-checked={value}
      aria-label={value ? "সম্পন্ন — বাতিল করতে চাপুন" : "সম্পন্ন করুন"}
      disabled={disabled}
      whileTap={disabled ? undefined : { scale: 0.88 }}
      transition={{ duration: 0.15 }}
      onClick={() => onToggle(!value)}
      className={cn(
        "tap-target flex size-11 shrink-0 items-center justify-center rounded-full border-2 transition-colors duration-150",
        value ? "border-primary bg-primary text-primary-foreground shadow-card" : "border-border bg-card text-border",
        disabled && "cursor-not-allowed opacity-60"
      )}
    >
      <AnimatePresence initial={false}>
        {value && (
          <motion.span
            key="check"
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            exit={{ scale: 0 }}
            transition={{ duration: 0.15, ease: "easeOut" }}
            className="flex"
          >
            <Check className="size-5" strokeWidth={3} />
          </motion.span>
        )}
      </AnimatePresence>
    </motion.button>
  );
}

// ── Stepper round button ─────────────────────────────────────────────────────

function StepButton({
  icon: Icon,
  label,
  disabled,
  onClick,
}: {
  icon: React.ElementType;
  label: string;
  disabled?: boolean;
  onClick: () => void;
}) {
  return (
    <button
      type="button"
      aria-label={label}
      disabled={disabled}
      onClick={onClick}
      className={cn(
        "tap-target flex size-11 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary transition-transform duration-150 hover:bg-primary/15 active:scale-90",
        disabled && "cursor-not-allowed opacity-40 active:scale-100"
      )}
    >
      <Icon className="size-5" />
    </button>
  );
}

// ── Count stepper (দরুদ / ইস্তিগফার / মিসওয়াক…) ────────────────────────────

export function CountControl({
  value,
  target,
  unit,
  disabled,
  onChange,
}: {
  value: number;
  target: number | null;
  unit: string;
  disabled?: boolean;
  onChange: (v: number) => void;
}) {
  const quick = target != null ? (target >= 100 ? 100 : target) : 100;
  const reached = target != null && value >= target;
  const pct = target ? Math.min(100, Math.round((100 * value) / target)) : 0;
  return (
    <div className="space-y-2.5">
      <div className="flex items-center gap-2">
        <StepButton icon={Minus} label="এক কমান" disabled={disabled || value <= 0} onClick={() => onChange(Math.max(0, value - 1))} />
        <div className="min-w-0 flex-1 text-center">
          <p className={cn("text-2xl font-extrabold leading-none", reached ? "text-primary" : "text-foreground")}>
            {toBn(value)}
          </p>
          <p className="mt-1 truncate text-[11px] text-muted-foreground">
            {target != null ? `লক্ষ্য: ${toBn(target)} ${unit}` : unit || "বার"}
          </p>
        </div>
        <StepButton icon={Plus} label="এক বাড়ান" disabled={disabled} onClick={() => onChange(value + 1)} />
        <Button
          type="button"
          variant="outline"
          disabled={disabled}
          onClick={() => onChange(quick)}
          className="h-11 shrink-0 gap-1 rounded-full px-3"
          aria-label={`সরাসরি ${quick} সেট করুন`}
        >
          <Check className="size-4" />
          {toBn(quick)}
        </Button>
      </div>
      {target != null && <Progress value={pct} className="h-1.5" aria-label={`${pct}% সম্পন্ন`} />}
    </div>
  );
}

// ── Quantity input (তিলাওয়াত পৃষ্ঠা/পারা…) ────────────────────────────────

const BN_TO_EN: Record<string, string> = { "০": "0", "১": "1", "২": "2", "৩": "3", "৪": "4", "৫": "5", "৬": "6", "৭": "7", "৮": "8", "৯": "9" };

function parseDigits(raw: string): number {
  const en = raw.replace(/[০-৯]/g, (d) => BN_TO_EN[d] ?? d).replace(/[^\d.]/g, "");
  const n = parseFloat(en);
  return isNaN(n) ? 0 : n;
}

export function QuantityControl({
  value,
  target,
  unit,
  disabled,
  onChange,
}: {
  value: number;
  target: number | null;
  unit: string;
  disabled?: boolean;
  onChange: (v: number) => void;
}) {
  const [text, setText] = React.useState(() => (value > 0 ? bnNumber(value) : ""));

  // Keep the local field in sync when the stored value changes elsewhere
  // (server hydration / month-grid edits / store rehydrate).
  React.useEffect(() => {
    setText((prev) => (parseDigits(prev) === value ? prev : value > 0 ? bnNumber(value) : ""));
  }, [value]);

  const commit = () => {
    const n = Math.max(0, Math.min(999, parseDigits(text)));
    onChange(n);
    setText(n > 0 ? bnNumber(n) : "");
  };

  const step = (delta: number) => {
    const n = Math.max(0, Math.min(999, Math.round((value + delta) * 100) / 100));
    onChange(n);
  };

  const reached = target != null && value >= target;
  const pct = target ? Math.min(100, Math.round((100 * value) / target)) : 0;

  return (
    <div className="space-y-2.5">
      <div className="flex items-center justify-center gap-2">
        <StepButton icon={Minus} label="আধা কমান" disabled={disabled || value <= 0} onClick={() => step(-0.5)} />
        <div className="relative w-28 shrink-0">
          <Input
            value={text}
            onChange={(e) => setText(e.target.value)}
            onBlur={commit}
            onKeyDown={(e) => {
              if (e.key === "Enter") {
                e.preventDefault();
                commit();
              }
            }}
            inputMode="decimal"
            disabled={disabled}
            aria-label={`${unit} সংখ্যা`}
            className="h-11 pe-14 text-center text-lg font-bold"
          />
          <span className="pointer-events-none absolute end-2.5 top-1/2 w-10 -translate-y-1/2 truncate text-end text-[10px] leading-tight text-muted-foreground">
            {unit}
          </span>
        </div>
        <StepButton icon={Plus} label="আধা বাড়ান" disabled={disabled} onClick={() => step(0.5)} />
        {reached && (
          <span title="লক্ষ্য পূরণ" className="flex size-5 shrink-0 items-center justify-center">
            <Check className="size-5 text-success" strokeWidth={3} />
          </span>
        )}
      </div>
      {target != null && (
        <p className="text-center text-[11px] text-muted-foreground">
          লক্ষ্য: {bnNumber(target)} {unit}
        </p>
      )}
      {target != null && <Progress value={pct} className="h-1.5" aria-label={`${pct}% সম্পন্ন`} />}
    </div>
  );
}

// ── Completion ring (SVG, animated) ─────────────────────────────────────────

export function CompletionRing({ pct, size = 72 }: { pct: number; size?: number }) {
  const stroke = size >= 64 ? 7 : 5;
  const r = (size - stroke) / 2 - 1;
  const c = 2 * Math.PI * r;
  return (
    <div className="relative shrink-0" style={{ width: size, height: size }} role="img" aria-label={`${toBn(pct)}% সম্পন্ন`}>
      <svg width={size} height={size} className="-rotate-90">
        <circle cx={size / 2} cy={size / 2} r={r} fill="none" strokeWidth={stroke} className="stroke-muted" />
        <motion.circle
          cx={size / 2}
          cy={size / 2}
          r={r}
          fill="none"
          strokeWidth={stroke}
          strokeLinecap="round"
          className="stroke-primary"
          strokeDasharray={c}
          initial={false}
          animate={{ strokeDashoffset: c * (1 - pct / 100) }}
          transition={{ duration: 0.4, ease: "easeOut" }}
        />
      </svg>
      <div className="absolute inset-0 flex items-center justify-center">
        <span className={cn("font-extrabold leading-none", size >= 64 ? "text-base" : "text-[11px]")}>{toBn(pct)}%</span>
      </div>
    </div>
  );
}

// ── Streak badge ────────────────────────────────────────────────────────────

export function StreakBadge({ days }: { days: number }) {
  if (days <= 0) return null;
  return (
    <span className="inline-flex h-8 items-center gap-1.5 rounded-full border border-gold/30 bg-gold-soft px-3 text-xs font-bold text-gold-text-foreground">
      <Flame className="size-4 text-gold-text-text" />
      {toBn(days)} দিন ধারাবাহিক
    </span>
  );
}
