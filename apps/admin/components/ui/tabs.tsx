"use client";

import * as React from "react";
import { cn } from "@/lib/utils";

interface TabsContextValue {
  value: string;
  setValue: (v: string) => void;
}
const TabsCtx = React.createContext<TabsContextValue | null>(null);

export function Tabs({
  defaultValue,
  value: controlled,
  onValueChange,
  className,
  children,
  "aria-label": ariaLabel,
}: {
  defaultValue: string;
  value?: string;
  onValueChange?: (v: string) => void;
  className?: string;
  children: React.ReactNode;
  "aria-label"?: string;
}) {
  const [internal, setInternal] = React.useState(defaultValue);
  const value = controlled ?? internal;
  const setValue = (v: string) => {
    setInternal(v);
    onValueChange?.(v);
  };
  return (
    <TabsCtx.Provider value={{ value, setValue }}>
      <div className={cn("flex flex-col gap-4", className)} aria-label={ariaLabel}>
        {children}
      </div>
    </TabsCtx.Provider>
  );
}

export function TabsList({ className, children }: { className?: string; children: React.ReactNode }) {
  return (
    <div
      role="tablist"
      className={cn(
        "inline-flex w-fit max-w-full items-center gap-1 overflow-x-auto scroll-thin rounded-lg border border-border bg-muted p-1",
        className
      )}
    >
      {children}
    </div>
  );
}

export function TabsTrigger({ value, children }: { value: string; children: React.ReactNode }) {
  const ctx = React.useContext(TabsCtx)!;
  const active = ctx.value === value;
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      tabIndex={active ? 0 : -1}
      onClick={() => ctx.setValue(value)}
      className={cn(
        "focus-ring whitespace-nowrap rounded-md px-3.5 py-1.5 text-sm font-medium transition-colors duration-200",
        active
          ? "bg-card text-primary shadow-card"
          : "text-muted-foreground hover:text-foreground"
      )}
    >
      {children}
    </button>
  );
}

export function TabsPanel({ value, children }: { value: string; children: React.ReactNode }) {
  const ctx = React.useContext(TabsCtx)!;
  if (ctx.value !== value) return null;
  return (
    <div role="tabpanel" className="focus-ring rounded-md">
      {children}
    </div>
  );
}
