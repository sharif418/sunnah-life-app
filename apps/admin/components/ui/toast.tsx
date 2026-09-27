"use client";

import * as React from "react";
import { CheckCircle2, XCircle, Info } from "lucide-react";
import { cn } from "@/lib/utils";

export interface Toast {
  id: number;
  kind: "success" | "error" | "info";
  message: string;
}

interface ToastContextValue {
  toast: (message: string, kind?: Toast["kind"]) => void;
}

const ToastCtx = React.createContext<ToastContextValue | null>(null);

export function useToast(): ToastContextValue {
  const ctx = React.useContext(ToastCtx);
  if (!ctx) throw new Error("useToast must be used inside <ToastProvider>");
  return ctx;
}

let nextId = 1;

export function ToastProvider({ children }: { children: React.ReactNode }) {
  const [toasts, setToasts] = React.useState<Toast[]>([]);

  const toast = React.useCallback((message: string, kind: Toast["kind"] = "info") => {
    const id = nextId++;
    setToasts((prev) => [...prev.slice(-3), { id, kind, message }]);
    window.setTimeout(() => {
      setToasts((prev) => prev.filter((t) => t.id !== id));
    }, kind === "error" ? 6_000 : 4_000);
  }, []);

  const value = React.useMemo(() => ({ toast }), [toast]);

  return (
    <ToastCtx.Provider value={value}>
      {children}
      <div
        aria-live="polite"
        aria-label="বিজ্ঞপ্তি"
        className="no-print pointer-events-none fixed bottom-4 right-4 z-[70] flex w-[min(92vw,380px)] flex-col gap-2"
      >
        {toasts.map((t) => (
          <div
            key={t.id}
            role="status"
            className={cn(
              "pointer-events-auto flex items-start gap-2.5 rounded-lg border p-3.5 text-sm shadow-lifted bg-card",
              t.kind === "success" && "border-success/40",
              t.kind === "error" && "border-alert/40",
              t.kind === "info" && "border-border"
            )}
          >
            {t.kind === "success" ? (
              <CheckCircle2 className="mt-0.5 h-4 w-4 shrink-0 text-success" aria-hidden />
            ) : t.kind === "error" ? (
              <XCircle className="mt-0.5 h-4 w-4 shrink-0 text-alert" aria-hidden />
            ) : (
              <Info className="mt-0.5 h-4 w-4 shrink-0 text-primary" aria-hidden />
            )}
            <p className="leading-relaxed text-foreground">{t.message}</p>
          </div>
        ))}
      </div>
    </ToastCtx.Provider>
  );
}
