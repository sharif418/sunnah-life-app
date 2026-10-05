"use client";

// দাওয়াত ইঞ্জিন — দায়ী সদস্যদের তারবিয়াত কোর: সদস্য পরিচয় + রেফারেল,
// মাদউ ট্রি ও পরিসংখ্যান, স্তর-শর্ত, উসরা সার্কেল, সাপ্তাহিক রিভিউ ও মূল্যায়ন।
// শুধু role >= daee দেখতে পারেন (shell gate করে; এখানেও ডিফেন্সিভ চেক আছে)।
//
// সাব-ভিউ (store view): "overview" | "madu" | "level" → ওভারভিউ,
// "usrah" → উসরা, "reviews" → রিভিউ। params: {member} দিলে রিভিউ ডায়ালগ খোলে।

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { toast } from "sonner";
import {
  CheckCircle2,
  ClipboardCheck,
  Copy,
  FileCheck,
  ListChecks,
  Megaphone,
  Network,
  Share2,
  Sparkles,
  Star,
  UserCheck,
  UserPlus,
  Users,
} from "lucide-react";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { toBn } from "@/lib/calendars";
import type {
  Announcement,
  AssessmentDetail,
  AssessmentTemplate,
  DawahOverview,
  DawahRequirements,
  Level,
  User,
  Usrah,
  UsrahMember,
  WeeklyReview,
} from "@/types/domain";
import { LEVEL_LABELS_BN, ROLE_RANK } from "@/types/domain";
import {
  EmptyState,
  ErrorState,
  InitialsAvatar,
  LevelBadge,
  ReviewStatusPill,
  RoleBadge,
  SectionHeader,
  SkeletonRows,
  copyText,
  levelLabel,
  relTimeBn,
  useAsync,
} from "./parts";
import { ReviewDialog, type QueueItem } from "./review-dialog";
import { AssessmentDialog, type AssessmentMember } from "./assessment-dialog";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";
import { AssessmentConfirmDialog } from "@/components/dawah/assessment-confirm";
import { GoalQueueSection } from "@/components/amal/goals";
import { UsrahJoinCard } from "@/components/dawah/usrah-join";

type DawahKey = "overview" | "usrah" | "reviews";

function mapDawahView(view: string): DawahKey {
  if (view === "usrah") return "usrah";
  if (view === "reviews") return "reviews";
  return "overview"; // default | overview | madu | level
}

export function DawahView() {
  const { user, view, params, nav, setAuthModal } = useApp();
  const supervisor = user ? ROLE_RANK[user.role] >= ROLE_RANK.usrah_head : false;

  // শেয়ার্ড ডেটা — হুক অবশ্যই গেটের আগে কল হয় (শর্তসাপেক্ষ return নয়)।
  const usrahAsync = useAsync(() => (user ? api.usrah() : Promise.resolve(null)), user ? "auth" : "anon");
  const queueAsync = useAsync(
    () => (supervisor ? api.reviewsQueue() : Promise.resolve({ queue: [] as QueueItem[] })),
    supervisor ? "sup" : "plain"
  );
  const templatesAsync = useAsync(
    () => (supervisor ? api.assessmentTemplates() : Promise.resolve({ templates: [] as AssessmentTemplate[] })),
    supervisor ? "sup" : "plain"
  );

  // মূল্যায়ন ডায়ালগ (কন্টেইনার লেভেল — উসরা ট্যাব ও রিভিউ ট্যাব দুই জায়গা থেকেই খোলে)
  const [assessmentOpen, setAssessmentOpen] = React.useState(false);
  const [assessmentMemberId, setAssessmentMemberId] = React.useState<string | undefined>(undefined);
  const [reviewItem, setReviewItem] = React.useState<QueueItem | null>(null);

  // সুপারভাইজারের মূল্যায়নযোগ্য সদস্য তালিকা = উসরা সদস্য ∪ রিভিউ-কিউ ব্যবহারকারী
  const assessmentMembers: AssessmentMember[] = React.useMemo(() => {
    const map = new Map<string, AssessmentMember>();
    for (const m of usrahAsync.data?.usrah?.members ?? []) {
      map.set(m.id, { id: m.id, name: m.name, memberCode: m.memberCode, level: m.level });
    }
    for (const q of queueAsync.data?.queue ?? []) {
      if (!map.has(q.user.id)) {
        map.set(q.user.id, { id: q.user.id, name: q.user.name, memberCode: q.user.memberCode, level: q.user.level });
      }
    }
    return [...map.values()];
  }, [usrahAsync.data, queueAsync.data]);

  const template = templatesAsync.data?.templates[0] ?? null;
  const key = mapDawahView(view);

  // ডিফেন্সিভ গেট — সাধারণত shell আগেই আটকায়
  if (!user) {
    return (
      <EmptyState
        icon={UserCheck}
        title="দাওয়াত ইঞ্জিন দেখতে সাইন ইন করুন"
        hint="আপনার দাওয়াতি পরিসংখ্যান, উসরা ও সাপ্তাহিক রিভিউ দেখতে অ্যাকাউন্টে প্রবেশ করুন।"
        action={
          <Button className="h-11 rounded-xl" onClick={() => setAuthModal(true)}>
            সাইন ইন করুন
          </Button>
        }
      />
    );
  }
  if (ROLE_RANK[user.role] < ROLE_RANK.daee) {
    return (
      <EmptyState
        icon={UserCheck}
        title="দাওয়াত ইঞ্জিন শুধু দায়ী সদস্যদের জন্য"
        hint="দাওয়াতি কাজে যুক্ত হতে চাইলে আপনার এলাকার আস-সুন্নাহ ফাউন্ডেশনের দায়ীর সাথে যোগাযোগ করুন।"
      />
    );
  }

  const TABS: { key: DawahKey; label: string }[] = [
    { key: "overview", label: "দাওয়াত" },
    { key: "usrah", label: "উসরা" },
    { key: "reviews", label: "রিভিউ" },
  ];

  return (
    <div>
      <header className="mb-4">
        <h1 className="text-xl font-bold">দাওয়াত ইঞ্জিন</h1>
        <p className="mt-0.5 text-sm text-muted-foreground">তারবিয়াত, মাদউ ও স্তর-অগ্রগতির কেন্দ্র</p>
      </header>

      <div className="no-scrollbar mb-5 flex gap-1.5 overflow-x-auto border-b border-border pb-2" role="tablist">
        {TABS.map((t) => (
          <button
            key={t.key}
            role="tab"
            aria-selected={key === t.key}
            onClick={() => nav("dawah", t.key)}
            className={cn(
              "tap-target flex-1 shrink-0 rounded-full text-sm font-medium transition-colors",
              key === t.key ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground hover:text-foreground"
            )}
          >
            {t.label}
          </button>
        ))}
      </div>

      <AnimatePresence mode="wait">
        <motion.div
          key={key}
          initial={{ opacity: 0, y: 8 }}
          animate={{ opacity: 1, y: 0 }}
          exit={{ opacity: 0, y: -6 }}
          transition={{ duration: 0.12, ease: "easeOut" }}
        >
          {key === "overview" && <OverviewTab user={user} />}
          {key === "usrah" && (
            <UsrahTab
              asyncBundle={usrahAsync}
              supervisor={supervisor}
              onAssess={(memberId) => {
                setAssessmentMemberId(memberId);
                setAssessmentOpen(true);
              }}
            />
          )}
          {key === "reviews" && (
            <ReviewsTab
              user={user}
              supervisor={supervisor}
              queue={queueAsync.data?.queue ?? []}
              queueLoading={queueAsync.loading}
              queueError={queueAsync.error}
              reloadQueue={queueAsync.reload}
              openReviewItem={reviewItem}
              setOpenReviewItem={setReviewItem}
              onAssess={(memberId) => {
                setAssessmentMemberId(memberId);
                setAssessmentOpen(true);
              }}
              params={params}
            />
          )}
        </motion.div>
      </AnimatePresence>

      <ReviewDialog
        item={reviewItem}
        onOpenChange={(open) => {
          if (!open) setReviewItem(null);
        }}
        onDone={() => queueAsync.reload()}
      />
      <AssessmentDialog
        open={assessmentOpen}
        onOpenChange={(open) => {
          setAssessmentOpen(open);
          if (!open) setAssessmentMemberId(undefined);
        }}
        members={assessmentMembers}
        template={template}
        preselectedMemberId={assessmentMemberId}
        onDone={() => {
          queueAsync.reload();
          usrahAsync.reload();
        }}
      />
    </div>
  );
}

// ── Tab 1: দাওয়াত ওভারভিউ ───────────────────────────────────────────────────

function OverviewTab({ user }: { user: User }) {
  const overviewAsync = useAsync(() => api.dawahOverview());
  // own results, every status — a pending one waits for the member's OTP
  const assessmentsAsync = useAsync(() => api.myAssessments());
  const requirementsAsync = useAsync(() => api.dawahRequirements());

  if (overviewAsync.loading) return <SkeletonRows count={5} />;
  if (overviewAsync.error || !overviewAsync.data)
    return <ErrorState message={overviewAsync.error ?? "ডেটা লোড করা যায়নি"} onRetry={overviewAsync.reload} />;
  const overview: DawahOverview = overviewAsync.data;

  const origin = typeof window !== "undefined" ? window.location.origin : "https://sunnahlife.app";
  const memberCode = overview.memberCode || user.memberCode || "";
  const referralLink = memberCode ? `${origin}/?join=${memberCode}` : "";

  const now = Date.now();
  const activeCount = overview.downline.filter((n) => now - new Date(n.lastActiveAt).getTime() < 7 * 86400000).length;
  const weekNew = overview.downline.filter(
    (n) => n.joinedAt && now - new Date(n.joinedAt).getTime() < 7 * 86400000
  ).length;

  const copyReferral = async () => {
    const ok = await copyText(referralLink);
    if (ok) toast.success("রেফারেল লিংক কপি হয়েছে");
    else toast.error("কপি করা যায়নি");
  };
  const shareReferral = async () => {
    const text = `আসসালামু আলাইকুম। সুন্নাহ লাইফ অ্যাপে আমার সাথে যুক্ত হোন — দৈনন্দিন আমলের হিসাব, নামাজের সময় ও তারবিয়াত এক জায়গায়: ${referralLink}`;
    if (typeof navigator !== "undefined" && "share" in navigator) {
      try {
        await navigator.share({ title: "সুন্নাহ লাইফ", text });
        return;
      } catch {
        // ব্যবহারকারী বাতিল করলে কপিতে ফলব্যাক
      }
    }
    const ok = await copyText(text);
    if (ok) toast.success("শেয়ার টেক্সট কপি হয়েছে");
  };

  return (
    <div>
      {/* ১. সদস্য পরিচয় কার্ড */}
      <Card className="rounded-xl p-4 shadow-card">
        <div className="flex items-center gap-3">
          <InitialsAvatar name={user.name} className="size-12 text-base" />
          <div className="min-w-0 flex-1">
            <p className="truncate text-base font-bold leading-tight">{user.name}</p>
            <div className="mt-1.5 flex flex-wrap gap-1.5">
              <LevelBadge level={user.level} />
              <RoleBadge role={user.role} />
            </div>
          </div>
        </div>
        <div className="mt-4 grid grid-cols-2 gap-2 text-center">
          <div className="rounded-xl bg-muted p-3">
            <p className="text-xs text-muted-foreground">সদস্য কোড</p>
            <p dir="ltr" className="mt-0.5 text-lg font-extrabold tracking-wide text-primary">
              {memberCode || "—"}
            </p>
          </div>
          <div className="rounded-xl bg-muted p-3">
            <p className="text-xs text-muted-foreground">এই স্তরে সময়</p>
            <p className="mt-0.5 text-lg font-extrabold text-primary">{toBn(overview.monthsInLevel)} মাস</p>
          </div>
        </div>
      </Card>

      {/* ২. রেফারেল শেয়ার কার্ড */}
      {referralLink ? (
        <Card className="mt-3 rounded-xl border-primary/20 bg-primary-soft/40 p-4 shadow-card">
          <SectionHeader icon={UserPlus} title="দাওয়াতি রেফারেল লিংক" className="mt-0" />
          <button
            onClick={copyReferral}
            className="w-full truncate rounded-xl border border-border bg-card px-3 py-2.5 text-start text-sm font-medium text-primary underline decoration-primary/40 underline-offset-4"
            title="কপি করতে চাপুন"
          >
            <span dir="ltr">{referralLink}</span>
          </button>
          <div className="mt-2.5 grid grid-cols-2 gap-2">
            <Button variant="outline" className="h-11 rounded-xl" onClick={copyReferral}>
              <Copy className="size-4" /> কপি
            </Button>
            <Button className="h-11 rounded-xl" onClick={shareReferral}>
              <Share2 className="size-4" /> শেয়ার
            </Button>
          </div>
          <p className="mt-3 text-xs leading-relaxed text-muted-foreground">
            «যে ব্যক্তি কল্যাণের দিকে আহ্বান করে, তার জন্য কর্তার সমান প্রতিদান» (মুসলিম ১৮৯৩)। আপনার মাধ্যমে যতজন
            হেদায়েতের পথে ফিরবে, তাদের প্রতিটি নেক আমলের অনুরূপ সওয়াব আপনিও পাবেন — তাদের আমল কমবে না।
          </p>
        </Card>
      ) : null}

      {/* ৩. পরিসংখ্যান */}
      <SectionHeader icon={Network} title="দাওয়াতি পরিসংখ্যান" />
      <div className="grid grid-cols-2 gap-2 sm:grid-cols-4">
        <StatCell label="সরাসরি রেফার" value={toBn(overview.invitedCount)} />
        <StatCell label="মোট মাদউ ট্রি" value={toBn(overview.downline.length)} />
        <StatCell label="সক্রিয় (৭ দিন)" value={toBn(activeCount)} />
        <StatCell label="এই সপ্তাহে নতুন" value={toBn(weekNew)} />
      </div>

      {/* ৪. স্তরের প্রয়োজনীয়তা (লাইভ চেকলিস্ট — B6) */}
      <SectionHeader icon={ListChecks} title="স্তরের প্রয়োজনীয়তা" />
      <LevelRequirementsCard
        asyncData={requirementsAsync}
        fallbackRows={overview.requirements}
        nextLevel={overview.nextLevel}
      />

      {/* ৫. মাদউ ট্রি */}
      <SectionHeader icon={Users} title="আমার মাদউ" />
      {overview.downline.length === 0 ? (
        <EmptyState
          icon={UserPlus}
          title="এখনো কোনো মাদউ যুক্ত হয়নি"
          hint="উপরের রেফারেল লিংক শেয়ার করে দাওয়াত শুরু করুন — যারা যুক্ত হবে, তারা এখানে দেখা যাবে।"
        />
      ) : (
        <Card className="rounded-xl p-2 shadow-card">
          <ul>
            {overview.downline.map((n) => (
              <li
                key={n.id}
                className="flex items-center gap-2.5 rounded-lg px-2.5 py-2 transition-colors hover:bg-muted"
                style={{ paddingInlineStart: `${(Math.max(1, n.depth) - 1) * 20 + 10}px` }}
              >
                {n.depth === 1 ? (
                  <UserCheck className="size-4 shrink-0 text-primary" />
                ) : (
                  <span className="ms-2 shrink-0 text-muted-foreground/60">↳</span>
                )}
                <div className="min-w-0 flex-1">
                  <p className="truncate text-sm font-semibold">{n.name}</p>
                  <p className="truncate text-xs text-muted-foreground">
                    {n.memberCode ? `${n.memberCode} · ` : ""}
                    {levelLabel(n.level)} · {relTimeBn(n.lastActiveAt)}
                  </p>
                </div>
                <span className="shrink-0 text-[10px] font-semibold text-muted-foreground">
                  স্তর {toBn(n.depth)}
                </span>
              </li>
            ))}
          </ul>
        </Card>
      )}

      {/* ৬. মূল্যায়নের ইতিহাস */}
      <SectionHeader icon={FileCheck} title="আমার মূল্যায়ন" />
      <AssessmentHistory asyncState={assessmentsAsync} />
    </div>
  );
}

function StatCell({ label, value }: { label: string; value: string }) {
  return (
    <div className="rounded-xl bg-muted p-3">
      <p className="text-xs text-muted-foreground">{label}</p>
      <p className="mt-0.5 text-xl font-extrabold text-primary">{value}</p>
    </div>
  );
}

// ── স্তরের প্রয়োজনীয়তা — লাইভ চেকলিস্ট (B6: GET /api/dawah/requirements) ───────

function LevelRequirementsCard({
  asyncData,
  fallbackRows,
  nextLevel,
}: {
  asyncData: { data: DawahRequirements | null; loading: boolean; error: string | null };
  fallbackRows: DawahOverview["requirements"];
  nextLevel: Level;
}) {
  const live = asyncData.data;

  // লাইভ চেকলিস্ট আসার আগে স্কেলিটন
  if (!live && asyncData.loading) {
    return (
      <Card className="rounded-xl p-4 shadow-card">
        <div className="space-y-3" aria-busy="true" aria-label="স্তরের প্রয়োজনীয়তা লোড হচ্ছে">
          <SkeletonRows count={3} />
        </div>
      </Card>
    );
  }

  // নতুন এন্ডপয়েন্ট অনুপলব্ধ হলে ওভারভিউয়ের রেসপন্সই চেকলিস্ট (একই ইঞ্জিন)
  if (!live) {
    return (
      <Card className="rounded-xl p-4 shadow-card">
        {asyncData.error ? (
          <p className="mb-3 text-xs text-muted-foreground">লাইভ চেকলিস্ট আনা যায়নি — সর্বশেষ তথ্য দেখানো হচ্ছে</p>
        ) : null}
        <ul className="space-y-2.5">
          {fallbackRows.map((r) => (
            <li key={r.key} className="flex items-start gap-2.5">
              {r.done ? (
                <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-primary" />
              ) : (
                <span className="mt-1 size-3.5 shrink-0 rounded-full border-2 border-muted-foreground/40" />
              )}
              <div className="min-w-0">
                <p className={cn("text-sm leading-snug", r.done ? "font-semibold" : "font-medium")}>{r.label}</p>
                <p className="mt-0.5 text-xs text-muted-foreground">{r.detail}</p>
              </div>
            </li>
          ))}
        </ul>
        <p className="mt-3 border-t border-border pt-3 text-sm">
          <span className="text-muted-foreground">পরবর্তী স্তর: </span>
          <span className="font-bold text-primary">{LEVEL_LABELS_BN[nextLevel] ?? nextLevel}</span>
        </p>
      </Card>
    );
  }

  const machine = live.requirements.filter((r) => r.autoChecked);
  const manual = live.requirements.filter((r) => !r.autoChecked);
  const doneCount = machine.filter((r) => r.met).length;

  return (
    <Card className="rounded-xl p-4 shadow-card">
      {live.rulesApply ? (
        <div className="mb-3 flex items-center justify-between gap-2">
          <div className="flex gap-1">
            {machine.map((r) => (
              <span
                key={r.key}
                title={r.labelBn}
                className={cn(
                  "size-2.5 rounded-full",
                  r.met ? "bg-primary" : "bg-muted-foreground/25"
                )}
              />
            ))}
          </div>
          <span className="text-xs font-semibold text-primary">
            {toBn(doneCount)}/{toBn(machine.length)} পূরণ
          </span>
        </div>
      ) : null}

      <ul className="space-y-2.5">
        {live.requirements.map((r) => (
          <li key={r.key} className="flex items-start gap-2.5">
            {r.met ? (
              <CheckCircle2 className="mt-0.5 size-4 shrink-0 text-primary" />
            ) : (
              <span className="mt-1 size-3.5 shrink-0 rounded-full border-2 border-muted-foreground/40" />
            )}
            <div className="min-w-0 flex-1">
              <div className="flex flex-wrap items-center gap-1.5">
                <p className={cn("text-sm leading-snug", r.met ? "font-semibold" : "font-medium")}>{r.labelBn}</p>
                {r.autoChecked ? null : (
                  <span className="rounded-full bg-gold/15 px-1.5 py-0.5 text-[10px] font-bold text-gold-text-text">
                    পরিদর্শক যাচাই
                  </span>
                )}
              </div>
              <div className="mt-1 flex flex-wrap items-center gap-2">
                {r.current !== null && r.target !== null && r.target > 1 ? (
                  <span
                    className={cn(
                      "inline-flex items-center gap-1 rounded-full px-2 py-0.5 text-[11px] font-bold tabular-nums",
                      r.met ? "bg-primary-soft text-primary" : "bg-muted text-muted-foreground"
                    )}
                  >
                    {toBn(Math.min(r.current, r.target))}/{toBn(r.target)}
                  </span>
                ) : null}
                <span className="text-xs text-muted-foreground">{r.detailBn}</span>
              </div>
            </div>
          </li>
        ))}
      </ul>

      {live.rulesApply ? (
        <p className="mt-3 rounded-xl bg-primary-soft/60 p-2.5 text-xs leading-relaxed text-foreground/80">
          {live.autoEligible ? (
            <>
              <Sparkles className="me-1 inline size-3.5 text-primary" aria-hidden />
              সবগুলো শর্ত পূরণ হয়েছে — পরবর্তী রাত ১২:৩০-এ <strong>স্বয়ংক্রিয় উন্নতি</strong> হবে ইনশাআল্লাহ।
            </>
          ) : (
            <>
              বাকি শর্তগুলো পূরণ হলে প্রতি রাতে স্বয়ংক্রিয়ভাবে স্তর উন্নয়ন হয়{" "}
              {manual.length ? "— সবুজ ব্যাজের শর্তগুলো পরিদর্শক যাচাই করেন" : ""}।
            </>
          )}
        </p>
      ) : null}

      <p className="mt-3 border-t border-border pt-3 text-sm">
        <span className="text-muted-foreground">পরবর্তী স্তর: </span>
        <span className="font-bold text-primary">{LEVEL_LABELS_BN[live.nextLevel] ?? live.nextLevel}</span>
      </p>
    </Card>
  );
}

function AssessmentHistory({
  asyncState,
}: {
  asyncState: { data: { assessments: AssessmentDetail[] } | null; loading: boolean; error: string | null; reload: () => void };
}) {
  const [confirming, setConfirming] = React.useState<AssessmentDetail | null>(null);
  if (asyncState.loading) return <SkeletonRows count={2} />;
  if (asyncState.error) return <ErrorState message={asyncState.error} onRetry={asyncState.reload} />;
  const list = asyncState.data?.assessments ?? [];
  if (list.length === 0)
    return (
      <EmptyState
        icon={FileCheck}
        title="এখনো কোনো মূল্যায়ন হয়নি"
        hint="উসরা প্রধান নিয়মিত মূল্যায়ন নেওয়ার পর এখানে ফলাফল দেখা যাবে।"
      />
    );
  return (
    <div className="space-y-2">
      {list.map((a) => (
        <Card key={a.id} className="rounded-xl p-3.5 shadow-card">
          <div className="flex items-center gap-2">
            <p className="min-w-0 flex-1 truncate text-sm font-bold">{a.template.titleBn}</p>
            {a.status === "declined" ? (
              <span className="shrink-0 rounded-full bg-muted px-2.5 py-0.5 text-xs font-semibold text-muted-foreground">
                আপত্তি জানানো হয়েছে
              </span>
            ) : (
              <span
                className={cn(
                  "shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold",
                  a.result === "passed" ? "bg-primary-soft text-primary" : "bg-gold-soft text-warning"
                )}
              >
                {a.result === "passed" ? "উত্তীর্ণ" : "এখনো নয়"}
              </span>
            )}
          </div>
          <div className="mt-1 flex flex-wrap items-center gap-x-3 gap-y-0.5 text-xs text-muted-foreground">
            <span>{toBn(a.createdAt.slice(0, 10))}</span>
            {a.assessorName ? <span>মূল্যায়নকারী: {a.assessorName}</span> : null}
            {a.scorePct != null ? (
              <span className="font-bold text-primary">
                স্কোর {toBn(a.scorePct)}%
              </span>
            ) : null}
          </div>
          {a.overallComment ? (
            <p className="mt-2 rounded-lg bg-muted px-3 py-2 text-xs leading-relaxed">“{a.overallComment}”</p>
          ) : null}
          {a.status === "pending_confirmation" ? (
            <div className="mt-2.5 flex flex-wrap items-center gap-2 rounded-lg border border-gold/50 bg-gold-soft px-3 py-2">
              <p className="min-w-0 flex-1 text-xs leading-relaxed">
                ফলাফলটি আপনার নিশ্চিত করার অপেক্ষায় — নিশ্চিত হলে তবেই চূড়ান্ত হবে।
              </p>
              <Button size="sm" onClick={() => setConfirming(a)}>
                দেখে নিশ্চিত করুন
              </Button>
            </div>
          ) : null}
        </Card>
      ))}
      <AssessmentConfirmDialog
        assessment={confirming}
        onClose={() => setConfirming(null)}
        onDone={() => {
          setConfirming(null);
          asyncState.reload();
        }}
      />
    </div>
  );
}

// ── Tab 2: উসরা ─────────────────────────────────────────────────────────────

interface UsrahBundle {
  usrah: (Usrah & { members: UsrahMember[] }) | null;
  announcements: Announcement[];
}

function UsrahTab({
  asyncBundle,
  supervisor,
  onAssess,
}: {
  asyncBundle: { data: UsrahBundle | null; loading: boolean; error: string | null; reload: () => void };
  supervisor: boolean;
  onAssess: (memberId: string) => void;
}) {
  const { nav } = useApp();

  if (asyncBundle.loading) return <SkeletonRows count={4} />;
  if (asyncBundle.error || !asyncBundle.data)
    return <ErrorState message={asyncBundle.error ?? "উসরার তথ্য লোড করা যায়নি"} onRetry={asyncBundle.reload} />;

  const { usrah, announcements } = asyncBundle.data;

  // not in an usrah yet: ask the tarbiyah office to place me (the old
  // "যোগাযোগ করুন" button pointed at a view that does not exist)
  if (!usrah) return <UsrahJoinCard onJoined={asyncBundle.reload} />;

  return (
    <div className="space-y-4">
      {/* the head's approval queue first: it is the work waiting */}
      {supervisor ? <GoalQueueSection /> : null}
      <Card className="rounded-xl p-4 shadow-card">
        <div className="flex items-center gap-2">
          <Users className="size-5 shrink-0 text-primary" />
          <div className="min-w-0 flex-1">
            <h2 className="truncate text-base font-bold">{usrah.name}</h2>
            {usrah.headName ? <p className="text-xs text-muted-foreground">উসরা প্রধান: {usrah.headName}</p> : null}
          </div>
          <span className="shrink-0 rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-semibold text-primary">
            {toBn(usrah.members.length)} সদস্য
          </span>
        </div>

        <div className="mt-4 space-y-1">
          {usrah.members.map((m) => (
            <div key={m.id} className="flex items-center gap-3 rounded-xl p-2 transition-colors hover:bg-muted/60">
              <InitialsAvatar name={m.name} />
              <div className="min-w-0 flex-1">
                <p className="truncate text-sm font-semibold">{m.name}</p>
                <p dir="ltr" className="truncate text-xs text-muted-foreground">
                  {m.memberCode ? `${m.memberCode} · ` : ""}
                  {levelLabel(m.level)} · {relTimeBn(m.lastActiveAt)}
                </p>
              </div>
              <div className="flex shrink-0 items-center gap-2">
                <span
                  className={cn(
                    "rounded-full px-2.5 py-0.5 text-xs font-bold",
                    (m.completion7d ?? 0) >= 70
                      ? "bg-primary-soft text-primary"
                      : (m.completion7d ?? 0) >= 40
                        ? "bg-gold-soft text-gold-text-foreground"
                        : "bg-alert-soft text-alert"
                  )}
                  title="৭ দিনের আমল সম্পন্নতা"
                >
                  {toBn(m.completion7d ?? 0)}%
                </span>
                {supervisor ? (
                  <Button
                    variant="ghost"
                    size="icon"
                    className="size-9 rounded-full"
                    aria-label={`${m.name}-এর জন্য নতুন মূল্যায়ন`}
                    title="নতুন মূল্যায়ন"
                    onClick={() => onAssess(m.id)}
                  >
                    <ClipboardCheck className="size-4 text-primary" />
                  </Button>
                ) : null}
              </div>
            </div>
          ))}
        </div>
      </Card>

      <SectionHeader icon={Megaphone} title="ঘোষণা" />
      {announcements.length === 0 ? (
        <EmptyState icon={Megaphone} title="কোনো ঘোষণা নেই" />
      ) : (
        <div className="space-y-2">
          {announcements.map((a) => (
            <Card key={a.id} className="rounded-xl p-3.5 shadow-card">
              <div className="flex items-center gap-2">
                {a.pinned ? <Star className="size-3.5 shrink-0 fill-gold text-gold-text-text" /> : null}
                <p className="min-w-0 flex-1 truncate text-xs font-semibold">{a.authorName ?? "উসরা"}</p>
                <p className="shrink-0 text-xs text-muted-foreground">{toBn(a.createdAt.slice(0, 10))}</p>
              </div>
              <p className="mt-1.5 text-sm leading-relaxed">{a.body}</p>
            </Card>
          ))}
        </div>
      )}
    </div>
  );
}

// ── Tab 3: রিভিউ ────────────────────────────────────────────────────────────

function ReviewsTab({
  user,
  supervisor,
  queue,
  queueLoading,
  queueError,
  reloadQueue,
  openReviewItem,
  setOpenReviewItem,
  onAssess,
  params,
}: {
  user: User;
  supervisor: boolean;
  queue: QueueItem[];
  queueLoading: boolean;
  queueError: string | null;
  reloadQueue: () => void;
  openReviewItem: QueueItem | null;
  setOpenReviewItem: (item: QueueItem | null) => void;
  onAssess: (memberId: string) => void;
  params: Record<string, string | number>;
}) {
  const reviewsAsync = useAsync(() => api.reviews());
  const autoOpenedRef = React.useRef("");

  // deep-link: ?member=… দিলে ওই সদস্যের রিভিউ ডায়ালগ খোলে (একবারই)
  React.useEffect(() => {
    const memberId = params.member != null ? String(params.member) : "";
    if (!memberId || queueLoading || autoOpenedRef.current === memberId) return;
    const item = queue.find((q) => q.userId === memberId);
    if (item) {
      autoOpenedRef.current = memberId;
      setOpenReviewItem(item);
    }
  }, [params.member, queue, queueLoading, setOpenReviewItem]);

  const myReviews = reviewsAsync.data?.reviews ?? [];
  const pending = myReviews.filter((r) => r.status !== "done");
  const history = myReviews.filter((r) => r.status === "done");
  const pendingQueue = queue.filter((q) => q.status !== "done");
  const doneQueue = queue.filter((q) => q.status === "done");

  return (
    <div>
      {/* আমার অপেক্ষমাণ রিভিউ + আত্মমূল্যায়ন */}
      {reviewsAsync.loading ? (
        <SkeletonRows count={2} />
      ) : reviewsAsync.error ? (
        <ErrorState message={reviewsAsync.error} onRetry={reviewsAsync.reload} />
      ) : pending.length > 0 ? (
        <div className="space-y-3">
          {pending.map((r) => (
            <ReflectionCard key={r.id} review={r} onDone={() => reviewsAsync.reload()} note={supervisor ? undefined : "চূড়ান্ত রিভিউ উসরা প্রধান সম্পন্ন করবেন।"} />
          ))}
        </div>
      ) : (
        <EmptyState icon={ClipboardCheck} title="এই মুহূর্তে কোনো অপেক্ষমাণ রিভিউ নেই" />
      )}

      {/* সুপারভাইজার: রিভিউ-কিউ */}
      {supervisor ? (
        <>
          <SectionHeader
            icon={UserCheck}
            title="রিভিউ-কিউ"
            hint="আপনার অধীন সদস্যদের সাপ্তাহিক রিভিউ সম্পন্ন করুন"
            action={
              <Button size="sm" className="h-9 rounded-full" onClick={() => onAssess("")}>
                <FileCheck className="size-4" /> নতুন মূল্যায়ন
              </Button>
            }
          />
          {queueLoading ? (
            <SkeletonRows count={3} className="h-14" />
          ) : queueError ? (
            <ErrorState message={queueError} onRetry={reloadQueue} />
          ) : queue.length === 0 ? (
            <EmptyState icon={UserCheck} title="কিউ খালি — সব রিভিউ সম্পন্ন, আলহামদুলিল্লাহ" />
          ) : (
            <div className="space-y-2">
              {pendingQueue.map((q) => (
                <QueueRow key={q.id} item={q} onReview={() => setOpenReviewItem(q)} />
              ))}
              {doneQueue.map((q) => (
                <QueueRow key={q.id} item={q} onReview={() => setOpenReviewItem(q)} done />
              ))}
            </div>
          )}
        </>
      ) : null}

      {/* আমার রিভিউর ইতিহাস */}
      <SectionHeader icon={ListChecks} title="রিভিউর ইতিহাস" />
      {history.length === 0 ? (
        <EmptyState icon={ClipboardCheck} title="এখনো কোনো সাপ্তাহিক রিভিউ সম্পন্ন হয়নি" />
      ) : (
        <div className="space-y-2">
          {history.map((r) => (
            <ReviewCard key={r.id} review={r} />
          ))}
        </div>
      )}
    </div>
  );
}

/** সদস্যের নিজের আত্মমূল্যায়ন (সাপ্তাহের মূল্যায়ন লিখুন)। */
function ReflectionCard({
  review,
  onDone,
  note,
}: {
  review: WeeklyReview;
  onDone: () => void;
  note?: string;
}) {
  const [comment, setComment] = React.useState("");
  const [rating, setRating] = React.useState(4);
  const [nextGoals, setNextGoals] = React.useState("");
  const [saving, setSaving] = React.useState(false);
  const { user } = useApp();

  const submit = async () => {
    if (!user) return;
    setSaving(true);
    try {
      await api.submitReview({ userId: user.id, weekStart: review.weekStart, comment, rating, nextGoals });
      toast.success("আপনার লেখা জমা হয়েছে — জাযাকাল্লাহু খাইরান");
      onDone();
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "জমা দেওয়া যায়নি");
    } finally {
      setSaving(false);
    }
  };

  return (
    <Card className="rounded-xl border-primary/25 p-4 shadow-card">
      <div className="flex items-center gap-2">
        <p className="flex-1 text-sm font-bold">সপ্তাহের মূল্যায়ন লিখুন</p>
        <ReviewStatusPill status={review.status} />
      </div>
      <p className="mt-0.5 text-xs text-muted-foreground">সপ্তাহ: {toBn(review.weekStart)}</p>

      <div className="mt-3 space-y-3">
        <div className="space-y-1.5">
          <Label htmlFor={`refl-c-${review.id}`}>এই সপ্তাহের আত্মসমালোচনা</Label>
          <Textarea
            id={`refl-c-${review.id}`}
            value={comment}
            onChange={(e) => setComment(e.target.value)}
            placeholder="আমল, উপকার, ত্রুটি — নিজের হিসাব লিখুন…"
            className="min-h-20 rounded-xl"
          />
        </div>
        <div className="flex items-center gap-1">
          {[1, 2, 3, 4, 5].map((s) => (
            <button
              key={s}
              type="button"
              onClick={() => setRating(s)}
              aria-label={`${toBn(s)} তারা`}
              className="tap-target flex size-10 items-center justify-center rounded-lg hover:bg-muted"
            >
              <Star className={cn("size-5", s <= rating ? "fill-gold text-gold-text-text" : "text-muted-foreground/50")} />
            </button>
          ))}
        </div>
        <div className="space-y-1.5">
          <Label htmlFor={`refl-g-${review.id}`}>পরবর্তী সপ্তাহের লক্ষ্য</Label>
          <Textarea
            id={`refl-g-${review.id}`}
            value={nextGoals}
            onChange={(e) => setNextGoals(e.target.value)}
            placeholder="যেমন: ফজরের জামাত, দৈনিক তিলাওয়াত…"
            className="min-h-16 rounded-xl"
          />
        </div>
        {note ? <p className="text-xs text-muted-foreground">{note}</p> : null}
        <Button className="h-11 w-full rounded-xl" onClick={submit} disabled={saving}>
          {saving ? "জমা হচ্ছে…" : "জমা দিন"}
        </Button>
      </div>
    </Card>
  );
}

function QueueRow({ item, onReview, done }: { item: QueueItem; onReview: () => void; done?: boolean }) {
  return (
    <Card className={cn("rounded-xl p-3 shadow-card", done && "opacity-75")}>
      <div className="flex items-center gap-3">
        <InitialsAvatar name={item.user.name} className="size-9 text-xs" />
        <div className="min-w-0 flex-1">
          <p className="truncate text-sm font-semibold">{item.user.name}</p>
          <p className="truncate text-xs text-muted-foreground">
            সপ্তাহ {toBn(item.weekStart)} · সম্পন্নতা {toBn(item.user.completion7d ?? 0)}%
          </p>
        </div>
        {!done ? <ReviewStatusPill status={item.status} /> : null}
        <Button variant={done ? "ghost" : "outline"} size="sm" className="h-9 shrink-0 rounded-full" onClick={onReview}>
          {done ? "দেখুন" : "রিভিউ দিন"}
        </Button>
      </div>
    </Card>
  );
}

function ReviewCard({ review }: { review: WeeklyReview }) {
  return (
    <Card className="rounded-xl p-3.5 shadow-card">
      <div className="flex items-center gap-2">
        <p className="flex-1 text-sm font-bold">সপ্তাহ: {toBn(review.weekStart)}</p>
        <ReviewStatusPill status={review.status} />
      </div>
      {review.reviewerName ? <p className="mt-0.5 text-xs text-muted-foreground">উসরা প্রধান: {review.reviewerName}</p> : null}
      {review.summary?.overallPct != null ? (
        <p className="mt-1 text-sm font-semibold text-primary">আমল সম্পন্নতা: {toBn(review.summary.overallPct)}%</p>
      ) : null}
      {review.comment ? <p className="mt-1.5 text-sm leading-relaxed">“{review.comment}”</p> : null}
      {review.nextGoals ? (
        <p className="mt-1.5 rounded-lg bg-muted px-3 py-2 text-xs leading-relaxed">
          <span className="font-semibold">পরবর্তী লক্ষ্য: </span>
          {review.nextGoals}
        </p>
      ) : null}
      {review.rating ? (
        <div className="mt-1.5 flex gap-0.5">
          {[1, 2, 3, 4, 5].map((s) => (
            <Star key={s} className={cn("size-3.5", s <= (review.rating ?? 0) ? "fill-gold text-gold-text-text" : "text-muted-foreground/40")} />
          ))}
        </div>
      ) : null}
    </Card>
  );
}
