"use client";

// আরও — মেনু গ্রিড: প্রোফাইল কার্ড + ফিচার টাইলসমূহ।

import * as React from "react";
import { motion } from "framer-motion";
import { Card, CardContent } from "@/components/ui/card";
import { Badge } from "@/components/ui/badge";
import { useApp } from "@/lib/store";
import { translate } from "@/lib/i18n";
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

const ITEMS: { view: string; icon: LucideIcon; titleKey: string; descKey: string; highlight?: boolean }[] = [
  { view: "settings", icon: AlarmClock, titleKey: "more.prayerSettings", descKey: "more.desc.settings" },
  { view: "qibla", icon: Compass, titleKey: "more.qibla", descKey: "more.desc.qibla" },
  { view: "zakat", icon: Calculator, titleKey: "more.zakat", descKey: "more.desc.zakat", highlight: true },
  { view: "mosques", icon: Landmark, titleKey: "more.mosques", descKey: "more.desc.mosques" },
  { view: "masala", icon: MessageCircleQuestion, titleKey: "more.masala", descKey: "more.desc.masala" },
  { view: "contacts", icon: LinkIcon, titleKey: "more.contacts", descKey: "more.desc.contacts" },
  { view: "about", icon: Info, titleKey: "more.about", descKey: "more.desc.about" },
];

export function MoreMenu() {
  const { user, profile, nav } = useApp();
  const t = (k: string) => translate(profile.language, k);
  const name = user?.name || profile.name || "অতিথি";
  const initials = name.trim().slice(0, 2);

  return (
    <motion.div
      initial={{ opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.15, ease: "easeOut" }}
    >
      <h1 className="text-xl font-bold mb-4">{t("nav.more")}</h1>

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
                t("more.guestHint")
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
        {ITEMS.map(({ view, icon: Icon, titleKey, descKey, highlight }) => (
          <button
            key={view}
            onClick={() => nav("more", view)}
            className={
              "tap-target rounded-xl border bg-card p-4 shadow-card text-start transition-all motion-base hover:shadow-lifted active:scale-[0.98] " +
              (highlight
                ? "border-gold/40 bg-gold-soft/60"
                : "border-border hover:border-primary/30")
            }
            aria-label={t(titleKey)}
          >
            <span
              className={
                "flex size-11 items-center justify-center rounded-full " +
                (highlight ? "bg-gold/20 text-warning" : "bg-primary-soft text-primary")
              }
            >
              <Icon className="size-5" />
            </span>
            <span className="mt-2.5 block text-sm font-semibold leading-snug">{t(titleKey)}</span>
            <span className="mt-0.5 block text-[11.5px] text-muted-foreground leading-snug">{t(descKey)}</span>
          </button>
        ))}
      </div>

      <p className="mt-6 text-center text-xs text-muted-foreground">{t("app.tagline")}</p>
    </motion.div>
  );
}
