"use client";

import { motion } from "framer-motion";
import { X } from "lucide-react";
import { useApp } from "@/lib/store";
import { Button } from "@/components/ui/button";
import { AppTitle, LogoMark } from "@/components/app/logo";

export function AdminConsole() {
  const { setAdminOpen } = useApp();
  return (
    <motion.div
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
      exit={{ opacity: 0 }}
      transition={{ duration: 0.2 }}
      className="fixed inset-0 z-50 bg-background overflow-y-auto"
      role="dialog"
      aria-label="অ্যাডমিন প্যানেল"
    >
      <div className="sticky top-0 z-10 border-b border-border bg-primary text-primary-foreground">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-3">
          <LogoMark size={34} />
          <div>
            <h1 className="font-bold leading-tight">অ্যাডমিন কনসোল</h1>
            <p className="text-[10px] text-primary-foreground/70">দাওয়াতুস সুন্নাহ তারবিয়াত ইঞ্জিন</p>
          </div>
          <Button
            variant="secondary"
            size="sm"
            className="ms-auto h-9 rounded-full"
            onClick={() => setAdminOpen(false)}
          >
            <X className="size-4 me-1" /> বন্ধ
          </Button>
        </div>
      </div>
      <div className="max-w-7xl mx-auto px-4 sm:px-6 py-6">
        <p className="text-sm text-muted-foreground">অ্যাডমিন প্যানেল তৈরি হচ্ছে…</p>
      </div>
    </motion.div>
  );
}
