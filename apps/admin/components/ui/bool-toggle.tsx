"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

/** সত্য/মিথ্যা টগল — দুই-বাটন সেগমেন্টেড কন্ট্রোল (labels = [সত্য-লেবেল, মিথ্যা-লেবেল])। */
export function BoolToggle({
  value,
  onChange,
  labels,
  ariaLabel,
}: {
  value: boolean;
  onChange: (v: boolean) => void;
  labels: [string, string];
  ariaLabel?: string;
}) {
  return (
    <div role="group" aria-label={ariaLabel ?? labels[0]} className="inline-flex overflow-hidden rounded-md border border-border">
      {[true, false].map((v) => (
        <button
          key={String(v)}
          type="button"
          aria-pressed={value === v}
          onClick={() => onChange(v)}
          className={cn(
            "focus-ring min-h-9 px-3.5 py-1.5 text-sm font-medium transition-colors duration-200",
            value === v
              ? "bg-primary text-primary-foreground"
              : "bg-card text-muted-foreground hover:bg-primary-soft hover:text-primary"
          )}
        >
          {v ? labels[0] : labels[1]}
        </button>
      ))}
    </div>
  );
}
