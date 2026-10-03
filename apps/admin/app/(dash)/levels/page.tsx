"use client";

import * as React from "react";
import { useQuery } from "@tanstack/react-query";
import { ArrowUpRight, Check, Clock, GraduationCap, History, Users } from "lucide-react";
import { api } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import { LEVEL_LABELS_BN, LEVEL_ORDER, isFullAdmin } from "@/lib/labels";
import { GenderBadge, LevelBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { ErrorState } from "@/components/ui/states";
import { TableSkeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

const LEVEL_DETAILS: Record<string, { title: string; desc: string }> = {
  none: {
    title: "শুরুর পর্যায়",
    desc: "তারবিয়াত কার্যক্রমে যুক্ত হওয়ার প্রাথমিক অবস্থা — মুহাসাবা ডায়েরি চালু করা, উসরায় যুক্ত হওয়া ও নিয়মিত আমলের চর্চা।",
  },
  muhibbus_sunnah: {
    title: "মুহিব্বুস সুন্নাহ",
    desc: "সুন্নাহর প্রতি ভালোবাসা ও অনুসরণের দ্বিতীয় স্তর — নির্দিষ্ট শর্ত পূরণের পর প্রধান অ্যাডমিন উন্নয়ন করেন (অডিট-লগড)।",
  },
  farze_ain_1: {
    title: "ফরযে আইন — ক্যাটাগরি ১",
    desc: "শুরুর পর্যায়ের পাঠ্যক্রম (দৈনিক ৪৫–৬০ মিনিট প্রস্তুতি) — ফরযে আইন মূল্যায়নে উত্তীর্ণ হয়ে অগ্রসরমান তারবিয়াত।",
  },
  farze_ain_2: {
    title: "ফরযে আইন — ক্যাটাগরি ২",
    desc: "অগ্রসর পাঠ্যক্রম (দৈনিক ৬০–৯০ মিনিট প্রস্তুতি) — গভীর ইলমি ও আমলি তারবিয়াতের সর্বোচ্চ স্তর।",
  },
};

const REQUIREMENT_LABELS: { key: string; label: string; detail: string }[] = [
  {
    key: "min_months",
    label: "স্তরে ন্যূনতম সময়",
    detail: "বর্তমান স্তরে অন্তত ৪ মাস অতিবাহিত করা (মাস গণনা levelStartedAt থেকে)।",
  },
  {
    key: "assessment_passed",
    label: "ফরযে আইন মূল্যায়নে উত্তীর্ণ",
    detail: "যেকোনো টেমপ্লেটের মূল্যায়নে উত্তীর্ণ হওয়া (প্রতি অংশে অর্ধেকের বেশি নির্ণায়কে ≥১ স্কোর)।",
  },
  {
    key: "min_referrals",
    label: "মাদউ উন্নয়ন",
    detail: "অন্তত ৫ জন মাদউ (রেফার করা) মুহিব্বুস সুন্নাহ স্তরে উন্নীত হওয়া।",
  },
  {
    key: "checklists",
    label: "তারবিয়াত চেকলিস্ট",
    detail: "ঈমান · ইলম · ইবাদত · আখলাক · সিফাত · ত্যাগ — প্রতিটি বিভাগের চেকলিস্ট পরিদর্শক কর্তৃক পূরণ।",
  },
];

function TransitionHistory() {
  const transitions = useQuery({
    queryKey: ["level-transitions"],
    queryFn: () => api.levelTransitions(),
  });

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <History className="h-[18px] w-[18px] text-primary" aria-hidden />
          উন্নয়নের ইতিহাস (LevelTransition)
        </CardTitle>
        <CardDescription>
          প্রতিটি স্তর-উন্নয়নের রেকর্ড — কে, কখন, কোন স্তর থেকে কোন স্তরে, কারণসহ · রাত ১২:৩০-এর
          স্বয়ংক্রিয় মূল্যায়নও এখানেই লেখা হয় (স্বয়ংক্রিয়)
        </CardDescription>
      </CardHeader>
      <CardContent>
        {transitions.isLoading ? (
          <TableSkeleton rows={4} cols={4} />
        ) : transitions.isError ? (
          <ErrorState error={transitions.error} onRetry={() => transitions.refetch()} />
        ) : (transitions.data?.transitions ?? []).length === 0 ? (
          <p className="rounded-md border border-dashed border-border p-4 text-center text-sm text-muted-foreground">
            এখনো কোনো উন্নয়ন রেকর্ড হয়নি
          </p>
        ) : (
          <ul className="scroll-thin max-h-[28rem] divide-y divide-border overflow-y-auto">
            {transitions.data!.transitions.map((t) => (
              <li key={t.id} className="flex flex-wrap items-center gap-x-3 gap-y-1.5 py-2.5">
                <span className="min-w-0 flex-1">
                  <span className="block truncate text-sm font-semibold">{t.userName}</span>
                  <span className="block text-[11px] text-muted-foreground">
                    {t.memberCode ?? "—"} · {relativeBn(t.at)}
                  </span>
                </span>
                <GenderBadge gender={t.gender} />
                <span className="flex items-center gap-1.5 text-xs">
                  <LevelBadge level={t.fromLevel} />
                  <ArrowUpRight className="h-3.5 w-3.5 text-muted-foreground" aria-hidden />
                  <LevelBadge level={t.toLevel} />
                </span>
                <Badge variant={t.method === "auto" ? "solid" : "outline"}>
                  {t.method === "auto" ? "স্বয়ংক্রিয়" : "অ্যাডমিন"}
                </Badge>
                {t.reason ? (
                  <span className="w-full text-xs leading-relaxed text-muted-foreground">কারণ: {t.reason}</span>
                ) : null}
              </li>
            ))}
          </ul>
        )}
      </CardContent>
    </Card>
  );
}

export default function LevelsPage() {
  const { user, fullAdmin } = useSession();

  const users = useQuery({
    queryKey: ["admin-users", ""],
    queryFn: () => api.users(""),
    enabled: fullAdmin,
  });

  const levelCounts = React.useMemo(() => {
    const counts = new Map<string, number>();
    for (const u of users.data?.users ?? []) counts.set(u.level, (counts.get(u.level) ?? 0) + 1);
    return counts;
  }, [users.data]);

  return (
    <div className="space-y-6">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <GraduationCap className="h-[18px] w-[18px] text-primary" aria-hidden />
            স্তর-সিঁড়ি (তারবিয়াত ল্যাডার)
          </CardTitle>
          <CardDescription>
            দাওয়াতুস সুন্নাহ তারবিয়াত কার্যক্রমের চার স্তর — উন্নয়ন শুধুমাত্র প্রধান অ্যাডমিন,
            প্রতিটি উন্নয়ন LevelTransition ও অডিট লগে সংরক্ষিত
          </CardDescription>
        </CardHeader>
        <CardContent>
          <ol className="grid grid-cols-1 gap-3 md:grid-cols-2 xl:grid-cols-4">
            {LEVEL_ORDER.map((lvl, i) => (
              <li
                key={lvl}
                className={cn(
                  "relative rounded-lg border p-4",
                  user?.level === lvl ? "border-primary/50 bg-primary-soft/50" : "border-border bg-card"
                )}
              >
                <span className="absolute right-3 top-3 text-2xl font-black text-primary/10" aria-hidden>
                  {toBn(i + 1)}
                </span>
                <p className="flex items-center gap-1.5 text-sm font-bold">
                  {LEVEL_LABELS_BN[lvl]}
                  {user?.level === lvl ? <Badge variant="solid">আপনার স্তর</Badge> : null}
                </p>
                <p className="mt-1.5 text-xs leading-relaxed text-muted-foreground">
                  {LEVEL_DETAILS[lvl].desc}
                </p>
                {fullAdmin && users.data ? (
                  <p className="mt-2 flex items-center gap-1 text-xs font-semibold text-primary">
                    <Users className="h-3 w-3" aria-hidden />
                    {toBn(levelCounts.get(lvl) ?? 0)} জন এই স্তরে
                  </p>
                ) : null}
              </li>
            ))}
          </ol>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Check className="h-[18px] w-[18px] text-success" aria-hidden />
              মুহিব্বুস সুন্নাহ উন্নয়নের শর্তাবলি
            </CardTitle>
            <CardDescription>
              চারটি শর্তের সবগুলো পূরণ হলে প্রধান অ্যাডমিন সদস্যকে উন্নীত করতে পারেন — অপূর্ণ
              থাকলে সার্ভার ৪২২-এ বাকি শর্তগুলো জানিয়ে দেয়
            </CardDescription>
          </CardHeader>
          <CardContent>
            <ul className="space-y-2.5">
              {REQUIREMENT_LABELS.map((r) => (
                <li key={r.key} className="flex items-start gap-3 rounded-md border border-border p-3">
                  <span className="mt-0.5 flex h-6 w-6 shrink-0 items-center justify-center rounded-full bg-primary-soft text-primary">
                    <Check className="h-3.5 w-3.5" aria-hidden />
                  </span>
                  <span>
                    <span className="block text-sm font-semibold">{r.label}</span>
                    <span className="block text-xs leading-relaxed text-muted-foreground">{r.detail}</span>
                  </span>
                </li>
              ))}
            </ul>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle className="flex items-center gap-2">
              <Clock className="h-[18px] w-[18px] text-gold" aria-hidden />
              নিয়ম ও স্বয়ংক্রিয়তা
            </CardTitle>
            <CardDescription>স্তর ব্যবস্থার সাথে সংশ্লিষ্ট স্বয়ংক্রিয় নিয়মকানুন</CardDescription>
          </CardHeader>
          <CardContent>
            <ul className="list-inside space-y-2 text-sm leading-relaxed text-foreground/90">
              <li className="flex gap-2">
                <ArrowUpRight className="mt-1 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden />
                প্রতি শনিবার (সপ্তাহ শুরু) প্রতিটি দায়ীর জন্য সাপ্তাহিক রিভিউ স্বয়ংক্রিয়ভাবে তৈরি হয় — ৭ দিন পরও সম্পূর্ণ না হলে বিলম্বিত গণ্য হয়।
              </li>
              <li className="flex gap-2">
                <ArrowUpRight className="mt-1 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden />
                আমলের দিন পরদিন ইশরাকের পর লক হয় — উসরা প্রধান বা তদের ঊর্ধ্বতন কারণ উল্লেখ করে আনলক করতে পারেন (অডিট-লগড)।
              </li>
              <li className="flex gap-2">
                <ArrowUpRight className="mt-1 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden />
                মূল্যায়নের ফলাফল সংখ্যা-নিয়মে স্বয়ংক্রিয়: মোট নির্ণায়কের অধিকাংশ ‘সম্পূর্ণ’ পেলে উত্তীর্ণ (আংশিক গণ্য হয় না)।
              </li>
              <li className="flex gap-2">
                <ArrowUpRight className="mt-1 h-3.5 w-3.5 shrink-0 text-primary" aria-hidden />
                উন্নয়নের সময় LevelTransition রেকর্ড হয় (প্রমাণ: শর্তের অবস্থা, মাস, মাদউ সংখ্যা) ও সদস্য রিমাইন্ডার পান।
              </li>
            </ul>
            {fullAdmin ? (
              <p className="mt-4 rounded-md border border-primary/30 bg-primary-soft/60 p-3 text-xs leading-relaxed">
                প্রধান অ্যাডমিন হিসেবে সদস্য উন্নয়ন করতে <strong>ব্যবহারকারী</strong> পাতায় গিয়ে
                সদস্যের সারিতে «স্তর উন্নয়ন» বাটন ব্যবহার করুন।
              </p>
            ) : null}
          </CardContent>
        </Card>
      </div>

      {fullAdmin && users.isLoading ? (
        <TableSkeleton rows={3} cols={3} />
      ) : null}
      {users.isError ? <ErrorState error={users.error} onRetry={() => users.refetch()} /> : null}

      <TransitionHistory />
    </div>
  );
}
