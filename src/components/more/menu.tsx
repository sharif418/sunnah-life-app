"use client";

// আরও — মেনু গ্রিড: প্রোফাইল কার্ড + ফিচার টাইলসমূহ।

import * as React from "react";
import { motion } from "framer-motion";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useApp } from "@/lib/store";
import { ROLE_LABELS_BN, LEVEL_LABELS_BN } from "@/types/domain";
import {
  ChevronLeft,
  AlarmClock,
  Compass,
  Calculator,
  Landmark,
  MessageCircleQuestion,
  Link as LinkIcon,
  Info,
  UserRound,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

const ITEMS: { view: string; icon: LucideIcon; title: string; desc: string; highlight?: boolean }[] = [
  { view: "settings", icon: AlarmClock, title: "নামাজের সেটিংস", desc: "হিসাব পদ্ধতি, মাযহাব ও শহর" },
  { view: "qibla", icon: Compass, title: "কিবলা কম্পাস", desc: "কাবার দিক খুঁজুন" },
  { view: "zakat", icon: Calculator, title: "যাকাত ক্যালকুলেটর", desc: "নিসাব ও প্রদেয় হিসাব", highlight: true },
  { view: "mosques", icon: Landmark, title: "মসজিদ", desc: "নিকটবর্তী মসজিদের তালিকা" },
  { view: "masala", icon: MessageCircleQuestion, title: "মাসআলা জিজ্ঞাসা", desc: "মুফতির কাছে প্রশ্ন করুন" },
  { view: "contacts", icon: LinkIcon, title: "যোগাযোগ ও লিংক", desc: "প্রতিষ্ঠান ও গ্রুপসমূহ" },
  { view: "about", icon: Info, title: "অ্যাপ সম্পর্কে", desc: "সংস্করণ ও মতামত" },
];

export function MoreMenu() {
  const { user, profile, nav } = useApp();
  const name = user?.name || profile.name || "অতিথি";
  const initials = name.trim().slice(0, 2);

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.15, ease: "easeOut" }}
    >
      <h1 className="text-xl font-bold mb-4">আরও</h1>

      {/* প্রোফাইল কার্ড */}
      <Card
        className="rounded-xl shadow-card cursor-pointer transition-all motion-base hover:shadow-lifted"
        onClick={() => nav("more", "profile")}
        role="button"
        tabIndex={0}
        onKeyDown={(e: React.KeyboardEvent) => {
          if (e.key === "Enter" || e.key === " ") nav("more", "profile");
        }}
        aria-label="প্রোফাইল খুলুন"
      >
        <CardContent className="p-4 flex items-center gap-3.5">
          <span className="flex size-[52px] shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary text-lg font-bold">
            {user || profile.name ? initials : <UserRound className="size-6" />}
          </span>
          <span className="flex-1 min-w-0">
            <span className="block font-bold truncate">{name}</span>
            <span className="mt-0.5 block text-xs text-muted-foreground truncate">
              {user ? (
                <>
                  {ROLE_LABELS_BN[user.role]}
                  {user.memberCode ? ` · ${user.memberCode}` : ""}
                </>
              ) : (
                "অতিথি — সাইন ইন করে সব সুবিধা নিন"
              )}
            </span>
            {user && user.level !== "none" && (
              <Badge variant="secondary" className="mt-1.5 rounded-full text-[10px] font-semibold">
                {LEVEL_LABELS_BN[user.level]}
              </Badge>
            )}
          </span>
          <ChevronLeft className="size-5 text-muted-foreground shrink-0 flip-rtl" />
        </CardContent>
      </Card>

      {/* ফিচার গ্রিড */}
      <div className="mt-4 grid grid-cols-2 gap-3">
        {ITEMS.map(({ view, icon: Icon, title, desc, highlight }) => (
          <button
            key={view}
            onClick={() => nav("more", view)}
            className={
              "tap-target rounded-xl border bg-card p-4 shadow-card text-start transition-all motion-base hover:shadow-lifted active:scale-[0.98] " +
              (highlight
                ? "border-gold/40 bg-gold-soft/60"
                : "border-border hover:border-primary/30")
            }
            aria-label={title}
          >
            <span
              className={
                "flex size-11 items-center justify-center rounded-full " +
                (highlight ? "bg-gold/20 text-warning" : "bg-primary-soft text-primary")
              }
            >
              <Icon className="size-5" />
            </span>
            <span className="mt-2.5 block text-sm font-semibold leading-snug">{title}</span>
            <span className="mt-0.5 block text-[11.5px] text-muted-foreground leading-snug">{desc}</span>
          </button>
        ))}
      </div>

      <p className="mt-6 text-center text-xs text-muted-foreground">
        আস-সুন্নাহ ফাউন্ডেশন · দাওয়াতুস সুন্নাহ
      </p>
    </motion.div>
  );
}
