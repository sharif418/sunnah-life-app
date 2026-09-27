"use client";

// শেয়ার্ড ছোট অংশ — সাব-ভিউ হেডার, সেকশন লেবেল, এরর-রিট্রাই কার্ড।

import * as React from "react";
import { motion } from "framer-motion";
import { Button } from "@/components/ui/button";
import { useApp } from "@/lib/store";
import { ChevronLeft, RefreshCw } from "lucide-react";

/** সাব-ভিউ চেহারা — পেছানে বাটন + শিরোনাম + ফেড-ইন মোশন। */
export function SubShell({ title, children }: { title: string; children: React.ReactNode }) {
  const back = useApp((s) => s.back);
  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.15, ease: "easeOut" }}
    >
      <div className="flex items-center gap-1.5 mb-4">
        <Button
          variant="ghost"
          size="icon"
          className="size-11 rounded-full shrink-0"
          onClick={back}
          aria-label="পেছানে যান"
        >
          <ChevronLeft className="size-5 flip-rtl" />
        </Button>
        <h1 className="text-xl font-bold leading-tight">{title}</h1>
      </div>
      {children}
    </motion.div>
  );
}

/** সেকশনের ছোট লেবেল (uppercase-ধর্মী নয় — বাংলা)। */
export function SectionLabel({ icon, children }: { icon?: React.ReactNode; children: React.ReactNode }) {
  return (
    <h2 className="flex items-center gap-2 text-sm font-bold text-primary">
      {icon}
      {children}
    </h2>
  );
}

/** বন্ধুত্বপূর্ণ বাংলা এরর + আবার চেষ্টা। */
export function ErrorRetry({ message, onRetry }: { message?: string; onRetry: () => void }) {
  return (
    <div className="rounded-xl bg-alert-soft border border-alert/20 p-5 text-center">
      <p className="text-sm leading-relaxed">{message ?? "কিছু একটা ভুল হয়েছে — আবার চেষ্টা করুন।"}</p>
      <Button variant="outline" className="mt-3 h-11 rounded-xl" onClick={onRetry}>
        <RefreshCw className="size-4" /> আবার চেষ্টা করুন
      </Button>
    </div>
  );
}

/** ইলাস্ট্রেটেড খালি অবস্থা। */
export function EmptyState({
  icon,
  message,
  hint,
}: {
  icon: React.ReactNode;
  message: string;
  hint?: string;
}) {
  return (
    <div className="py-12 text-center">
      <div className="mx-auto size-20 rounded-full bg-primary-soft flex items-center justify-center text-primary/50">
        {icon}
      </div>
      <p className="mt-4 text-sm font-medium">{message}</p>
      {hint && <p className="mt-1 text-xs text-muted-foreground">{hint}</p>}
    </div>
  );
}
