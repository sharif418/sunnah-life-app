"use client";

// লাইভ — আসন্ন/চলমান/শেষ হয়ে যাওয়া প্রোগ্রাম। চলমান হলে pulsing LIVE ব্যাজ +
// YouTube এমবেড; আসন্ন প্রোগ্রামে "মনে করিয়ে দিন" রিমাইন্ডার।
// (বোনদের-একমাত্র সেশন সার্ভার-সাইডে ফিল্টার হয় — অতিথিরা নিরপেক্ষগুলোই দেখেন।)

import * as React from "react";
import { motion } from "framer-motion";
import { Bell, CalendarClock, Mic, Radio, User } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import type { LiveProgramItem } from "@/types/domain";
import { EmptyState, ErrorState, SectionHeader, SkeletonRows, StatusPill, fmtDateTimeBn, useAsync } from "./parts";
import { Card } from "@/components/ui/card";
import { Button } from "@/components/ui/button";

const STATUS_LABEL: Record<LiveProgramItem["status"], string> = {
  live: "লাইভ এখন",
  upcoming: "আসছে",
  past: "শেষ হয়ে গেছে",
};

export function LiveSection() {
  const { data, loading, error, reload } = useAsync(() => api.live());
  const programs = data?.programs ?? null;

  if (loading) return <SkeletonRows count={4} />;
  if (error) return <ErrorState message={error} onRetry={reload} />;
  if (!programs || programs.length === 0)
    return (
      <EmptyState
        icon={Radio}
        title="এখন কোনো লাইভ প্রোগ্রাম নেই"
        hint="আস-সুন্নাহ ফাউন্ডেশনের সরাসরি সেশন ঘোষণা দিলে এখানে দেখা যাবে, ইনশাআল্লাহ।"
      />
    );

  const groups: { key: LiveProgramItem["status"]; title: string }[] = [
    { key: "live", title: "এখন লাইভ" },
    { key: "upcoming", title: "আসন্ন প্রোগ্রাম" },
    { key: "past", title: "শেষ হয়ে গেছে" },
  ];

  return (
    <div>
      {groups.map((g) => {
        const items = programs.filter((p) => p.status === g.key);
        if (items.length === 0) return null;
        return (
          <React.Fragment key={g.key}>
            <SectionHeader icon={g.key === "live" ? Radio : g.key === "upcoming" ? CalendarClock : Mic} title={g.title} />
            <div className="space-y-3">
              {items.map((p) => (
                <LiveCard key={p.id} program={p} />
              ))}
            </div>
          </React.Fragment>
        );
      })}
    </div>
  );
}

function LiveCard({ program }: { program: LiveProgramItem }) {
  const { user, setAuthModal } = useApp();
  const [reminded, setReminded] = React.useState(false);
  const [reminding, setReminding] = React.useState(false);
  const isLive = program.status === "live";
  const isPast = program.status === "past";
  const hasVideo = Boolean(program.youtubeId) && !isPast;

  const notify = async () => {
    if (!user) {
      toast.info("রিমাইন্ডার নিতে অনুগ্রহ করে সাইন ইন করুন");
      setAuthModal(true);
      return;
    }
    setReminding(true);
    try {
      await api.notifyLive(program.id);
      setReminded(true);
      toast.success("মনে করিয়ে দেওয়া হবে — প্রোগ্রাম শুরুর সময় রিমাইন্ডার পাবেন");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "রিমাইন্ডার সেট করা যায়নি");
    } finally {
      setReminding(false);
    }
  };

  return (
    <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ duration: 0.18 }}>
      <Card className={isLive ? "rounded-xl border-alert/25 bg-card p-0 shadow-card" : "rounded-xl p-0 shadow-card"}>
        <div className="p-4">
          <div className="flex items-start gap-2">
            {isLive ? (
              <StatusPill tone="alert" pulse>
                {STATUS_LABEL.live}
              </StatusPill>
            ) : (
              <StatusPill tone={program.status === "upcoming" ? "primary" : "muted"}>
                {STATUS_LABEL[program.status]}
              </StatusPill>
            )}
            <div className="ms-auto flex items-center gap-1 text-xs text-muted-foreground">
              {program.hostName ? (
                <>
                  <User className="size-3.5" />
                  <span className="truncate">{program.hostName}</span>
                </>
              ) : null}
            </div>
          </div>
          <h3 className="mt-2 text-[15px] font-bold leading-snug">{program.titleBn}</h3>
          <p className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
            <CalendarClock className="size-3.5 shrink-0" />
            {fmtDateTimeBn(program.startsAt)}
          </p>
          {program.descBn ? <p className="mt-2 text-sm leading-relaxed text-muted-foreground">{program.descBn}</p> : null}
        </div>

        {hasVideo ? (
          <div className="mt-3 overflow-hidden rounded-b-xl">
            <iframe
              className="aspect-video w-full"
              src={`https://www.youtube-nocookie.com/embed/${program.youtubeId}${isLive ? "?autoplay=0" : ""}`}
              title={program.titleBn}
              allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
              referrerPolicy="strict-origin-when-cross-origin"
              allowFullScreen
              loading="lazy"
            />
          </div>
        ) : isPast && program.recordingUrl ? (
          <div className="px-4 pb-4 pt-2">
            <a
              href={program.recordingUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="tap-target inline-flex items-center gap-1.5 text-sm font-semibold text-primary hover:underline"
            >
              <Mic className="size-4" /> রেকর্ডিং দেখুন
            </a>
          </div>
        ) : null}

        {program.status === "upcoming" ? (
          <div className="p-4 pt-3">
            <Button
              variant={reminded ? "secondary" : "outline"}
              className="h-11 w-full rounded-xl"
              disabled={reminded || reminding}
              onClick={notify}
            >
              <Bell className="size-4" />
              {reminded ? "রিমাইন্ডার সেট হয়েছে" : reminding ? "সেট হচ্ছে…" : "মনে করিয়ে দিন"}
            </Button>
          </div>
        ) : isPast && !program.recordingUrl ? (
          <div className="px-4 pb-4 pt-2 text-xs text-muted-foreground">রেকর্ডিং যুক্ত হয়নি</div>
        ) : null}
      </Card>
    </motion.div>
  );
}
