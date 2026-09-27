import * as React from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const badgeVariants = cva(
  "inline-flex items-center gap-1 rounded-full px-2.5 py-0.5 text-xs font-semibold leading-5 whitespace-nowrap",
  {
    variants: {
      variant: {
        default: "bg-primary-soft text-primary",
        solid: "bg-primary text-primary-foreground",
        outline: "border border-border text-muted-foreground bg-card",
        gold: "bg-gold-soft text-gold-foreground dark:text-gold",
        success: "bg-primary-soft text-success",
        warning: "bg-gold-soft text-warning",
        alert: "bg-alert-soft text-alert",
        muted: "bg-muted text-muted-foreground",
      },
    },
    defaultVariants: { variant: "default" },
  }
);

export interface BadgeProps
  extends React.HTMLAttributes<HTMLSpanElement>,
    VariantProps<typeof badgeVariants> {}

export function Badge({ className, variant, ...props }: BadgeProps) {
  return <span className={cn(badgeVariants({ variant }), className)} {...props} />;
}
