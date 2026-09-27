"use client";

import * as React from "react";
import { Star } from "lucide-react";
import { cn } from "@/lib/utils";
import { toBn } from "@/lib/bn";

/** 1–5 star rating input (large, keyboard accessible). */
export function RatingInput({
  value,
  onChange,
  disabled,
}: {
  value: number;
  onChange: (v: number) => void;
  disabled?: boolean;
}) {
  return (
    <div className="flex items-center gap-1" role="radiogroup" aria-label="রেটিং (১–৫)">
      {[1, 2, 3, 4, 5].map((n) => (
        <button
          key={n}
          type="button"
          role="radio"
          aria-checked={value === n}
          aria-label={`${toBn(n)} তারা`}
          disabled={disabled}
          onClick={() => onChange(n)}
          className={cn(
            "focus-ring flex h-11 w-11 items-center justify-center rounded-md transition-colors duration-150",
            disabled && "cursor-default"
          )}
        >
          <Star
            className={cn(
              "h-6 w-6 transition-colors duration-150",
              n <= value ? "fill-gold text-gold" : "text-muted-foreground/40 hover:text-gold"
            )}
            aria-hidden
          />
        </button>
      ))}
    </div>
  );
}

export function RatingView({ value }: { value: number | null }) {
  if (!value) return <span className="text-sm text-muted-foreground">—</span>;
  return (
    <span className="flex items-center gap-0.5" aria-label={`রেটিং: ${toBn(value)} / ${toBn(5)}`}>
      {[1, 2, 3, 4, 5].map((n) => (
        <Star
          key={n}
          className={cn("h-3.5 w-3.5", n <= (value ?? 0) ? "fill-gold text-gold" : "text-muted-foreground/30")}
          aria-hidden
        />
      ))}
    </span>
  );
}
