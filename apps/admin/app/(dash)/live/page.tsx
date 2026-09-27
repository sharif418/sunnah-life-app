"use client";

// লাইভ প্রোগ্রাম — upcoming/live/past sessions (YouTube unlisted embeds).
// Female-only sessions are visually marked and NEVER carry a public link.

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BellRing, Radio, Video } from "lucide-react";
import { api, type LiveProgramItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { GENDER_LABELS_BN } from "@/lib/labels";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { EmptyState } from "@/components/ui/states";
import { Tabs, TabsList, TabsPanel, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/components/ui/toast";

function ProgramCard({ p }: { p: LiveProgramItem }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const femaleOnly = p.gender === "F";

  const notify = useMutation({
    mutationFn: () => api.notifyLive(p.id),
    onSuccess: () => {
      toast("শুরুর আগে বিজ্ঞপ্তি পাবেন", "success");
      qc.invalidateQueries({ queryKey: ["live"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const startsSoon = p.status === "upcoming";

  return (
    <Card className={p.status === "live" ? "border-alert/50 shadow-lifted" : undefined}>
      <CardHeader>
        <CardTitle className="flex flex-wrap items-center gap-2">
          {p.status === "live" ? (
            <span className="inline-flex items-center gap-1.5 rounded-full bg-alert px-2.5 py-0.5 text-xs font-bold text-white">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-white opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-white" />
              </span>
              এখন লাইভ
            </span>
          ) : null}
          <span className="text-base">{p.titleBn}</span>
        </CardTitle>
        <CardDescription className="flex flex-wrap items-center gap-2">
          {p.hostName ? <span>উপস্থাপক: {p.hostName}</span> : null}
          <span>· {dateTimeBn(p.startsAt)}</span>
          {p.endsAt ? <span>(শেষ: {relativeBn(p.endsAt)})</span> : null}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {p.descBn ? <p className="text-sm leading-relaxed text-muted-foreground">{p.descBn}</p> : null}
        <div className="flex flex-wrap items-center gap-2">
          <GenderBadge gender={p.gender} />
          {femaleOnly ? (
            <Badge variant="gold">শুধুমাত্র নারীদের সেশন — প্রকাশ্য লিংক নেই</Badge>
          ) : null}
          {p.youtubeId && !femaleOnly && p.status !== "upcoming" ? (
            <Badge variant="outline">YouTube (unlisted)</Badge>
          ) : null}
        </div>
        <div className="flex flex-wrap gap-2">
          {p.status === "live" && p.youtubeId && !femaleOnly ? (
            <Button size="sm" onClick={() => window.open(`https://youtube.com/watch?v=${p.youtubeId}`, "_blank", "noopener")}>
              <Video className="h-4 w-4" aria-hidden />
              দেখুন
            </Button>
          ) : null}
          {startsSoon ? (
            <Button size="sm" variant="outline" onClick={() => notify.mutate()} disabled={notify.isPending}>
              <BellRing className="h-4 w-4" aria-hidden />
              {notify.isPending ? "…" : "আমাকে জানান"}
            </Button>
          ) : null}
          {p.recordingUrl ? (
            <a
              href={p.recordingUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-9 items-center rounded-lg border border-border px-3 text-sm font-semibold hover:bg-primary-soft"
            >
              রেকর্ডিং
            </a>
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}

export default function LivePage() {
  const { user } = useSession();
  const live = useQuery({ queryKey: ["live"], queryFn: () => api.livePrograms(), enabled: !!user });

  const programs = live.data?.programs ?? [];
  const now = programs.filter((p) => p.status === "live");
  const upcoming = programs.filter((p) => p.status === "upcoming");
  const past = programs.filter((p) => p.status === "past");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <div className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary-soft text-primary">
            <Radio className="h-6 w-6" aria-hidden />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-foreground md:text-2xl">লাইভ প্রোগ্রাম</h1>
            <p className="mt-0.5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              সরাসরি দারস ও প্রশিক্ষণ — YouTube (unlisted) এমবেডে। নারীদের সেশন কখনো প্রকাশ্য নয়।
            </p>
          </div>
        </div>
      </div>

      {live.isLoading ? (
        <p className="py-10 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
      ) : live.error ? (
        <EmptyState title="প্রোগ্রাম তালিকা আনা যায়নি" hint="নেটওয়ার্ক চেক করে আবার চেষ্টা করুন।" />
      ) : programs.length === 0 ? (
        <EmptyState
          title="কোনো লাইভ প্রোগ্রাম নেই"
          hint="নতুন সেশন নির্ধারিত হলে এখানে দেখা যাবে।"
        />
      ) : (
        <Tabs defaultValue="now">
          <TabsList>
            <TabsTrigger value="now">
              এখন ({toBn(now.length)})
            </TabsTrigger>
            <TabsTrigger value="upcoming">
              আসন্ন ({toBn(upcoming.length)})
            </TabsTrigger>
            <TabsTrigger value="past">
              পূর্বের ({toBn(past.length)})
            </TabsTrigger>
          </TabsList>
          <TabsPanel value="now">
            {now.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {now.map((p) => (
                  <ProgramCard key={p.id} p={p} />
                ))}
              </div>
            ) : (
              <EmptyState title="এই মুহূর্তে কোনো সেশন লাইভ নেই" />
            )}
          </TabsPanel>
          <TabsPanel value="upcoming">
            {upcoming.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {upcoming.map((p) => (
                  <ProgramCard key={p.id} p={p} />
                ))}
              </div>
            ) : (
              <EmptyState title="কোনো আসন্ন সেশন নেই" />
            )}
          </TabsPanel>
          <TabsPanel value="past">
            {past.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {past.map((p) => (
                  <ProgramCard key={p.id} p={p} />
                ))}
              </div>
            ) : (
              <EmptyState title="কোনো রেকর্ডিং নেই" />
            )}
          </TabsPanel>
        </Tabs>
      )}
    </div>
  );
}
