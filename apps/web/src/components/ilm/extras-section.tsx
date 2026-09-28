"use client";

// আরও পড়ুন — আল্লাহর ৯৯ নাম, ইসলামিক নাম (শিশুদের), প্রবন্ধ, সুন্নাহ সমূহ,
// ঈমানের ৭০ শাখা + লাইভ কুইজ ও উসরার প্রশ্নোত্তর বোর্ড।
// মেনু → সাব-ভিউ (store view দিয়ে ডিপ-লিংকযোগ্য)।

import * as React from "react";
import { motion } from "framer-motion";
import { ArrowRight, BookHeart, Baby, Brain, Heart, MessageCircleQuestion, Newspaper, Radio, Sparkles, Sun } from "lucide-react";
import { getPack } from "@/lib/content";
import type { ArticlesPack, ImanBranchesPack, IslamicNamesPack, Names99Pack, SunnahsPack } from "@/lib/content";
import { toBn } from "@/lib/calendars";
import { useApp } from "@/lib/store";
import type { ArticleItem, ImanBranch, IslamicName, NameOfAllah, SunnahItem } from "@/types/domain";
import { EmptyState, SkeletonRows, useAsync } from "./parts";
import { LiveQuizSection } from "./live-quiz-section";
import { UsrahQuestionsView } from "./usrah-questions";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Dialog, DialogContent, DialogHeader, DialogTitle } from "@/components/ui/dialog";
import { QuizzesSection } from "./quizzes-section";
import { cn } from "@/lib/utils";

export type ExtraKey =
  | "quizzes"
  | "names99"
  | "islamic-names"
  | "articles"
  | "sunnahs"
  | "iman70"
  | "live-quiz"
  | "usrah-questions";

export function ExtrasSection({
  active,
  highlightId,
  startQuizId,
}: {
  active: ExtraKey | null;
  highlightId?: string;
  startQuizId?: string;
}) {
  const { nav } = useApp();

  if (active === "quizzes") return <QuizzesSection startQuizId={startQuizId} />;
  if (active === "names99") return <Names99View onBack={() => nav("ilm", "more")} />;
  if (active === "islamic-names") return <IslamicNamesView onBack={() => nav("ilm", "more")} />;
  if (active === "articles") return <ArticlesView onBack={() => nav("ilm", "more")} openId={highlightId} />;
  if (active === "sunnahs") return <SunnahsView onBack={() => nav("ilm", "more")} />;
  if (active === "iman70") return <ImanBranchesView onBack={() => nav("ilm", "more")} />;
  if (active === "live-quiz") return <LiveQuizSection />;
  if (active === "usrah-questions") return <UsrahQuestionsView />;

  const entries: { key: ExtraKey; icon: React.ElementType; title: string; desc: string; count: string }[] = [
    { key: "quizzes", icon: Brain, title: "কুইজ", desc: "নিজে নিজে খেলুন — স্কোর সংরক্ষিত হয়, সেরা ফলাফল দেখুন", count: "৩টি" },
    { key: "live-quiz", icon: Radio, title: "লাইভ কুইজ", desc: "উসরার সবার সাথে একসাথে কুইজ — লাইভ লিডারবোর্ডসহ", count: "উসরা" },
    { key: "usrah-questions", icon: MessageCircleQuestion, title: "উসরার প্রশ্নোত্তর", desc: "উসরার ভেতরে প্রশ্ন করুন, প্রধানের উত্তর দেখুন", count: "উসরা" },
    { key: "names99", icon: Sparkles, title: "আল্লাহর ৯৯ নাম", desc: "আরবি, উচ্চারণ ও বাংলা অর্থসহ আসমাউল হুসনা", count: "৯৯টি" },
    { key: "islamic-names", icon: Baby, title: "ইসলামিক নাম", desc: "ছেলে-মেয়েদের অর্থসহ সুন্দর নামের তালিকা", count: "৭০টি" },
    { key: "articles", icon: Newspaper, title: "প্রবন্ধ", desc: "আমল, মুহাসাবা ও জীবনাচরণের ওপর সংক্ষিপ্ত লেখা", count: "৪টি" },
    { key: "sunnahs", icon: Sun, title: "সুন্নাহ সমূহ", desc: "দৈনন্দিন, বিস্মৃত ও নামাজের সুন্নাহ", count: "৩০টি" },
    { key: "iman70", icon: Heart, title: "ঈমানের ৭০ শাখা", desc: "অন্তর, মুখ ও দেহের শাখাগুলোর বিবরণ", count: "৭০টি" },
  ];

  return (
    <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
      {entries.map((e) => (
        <motion.button
          key={e.key}
          initial={{ opacity: 0, y: 6 }}
          animate={{ opacity: 1, y: 0 }}
          whileTap={{ scale: 0.98 }}
          onClick={() => nav("ilm", e.key)}
          className="tap-target flex items-center gap-3 rounded-xl border border-border bg-card p-4 text-start shadow-card transition-colors hover:bg-muted/50"
        >
          <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary-soft">
            <e.icon className="size-5 text-primary" />
          </span>
          <span className="min-w-0 flex-1">
            <span className="block text-sm font-bold">{e.title}</span>
            <span className="mt-0.5 block line-clamp-2 text-xs leading-relaxed text-muted-foreground">{e.desc}</span>
          </span>
          <ArrowRight className="size-4 shrink-0 text-muted-foreground" />
        </motion.button>
      ))}
    </div>
  );
}

function BackBar({ label, onBack }: { label: string; onBack: () => void }) {
  return (
    <Button variant="ghost" className="mb-3 h-11 rounded-xl px-2 text-muted-foreground" onClick={onBack}>
      {label}
    </Button>
  );
}

// ── আল্লাহর ৯৯ নাম ─────────────────────────────────────────────────────────

function Names99View({ onBack }: { onBack: () => void }) {
  const { data, loading, error } = useAsync<Names99Pack>(() => getPack("names99") as Promise<Names99Pack>);
  const [query, setQuery] = React.useState("");

  if (loading) return <SkeletonRows count={6} className="h-16" />;
  if (error) return <EmptyState icon={Sparkles} title="লোড করা যায়নি" hint={error} />;
  const names: NameOfAllah[] = data?.names ?? [];
  if (names.length === 0) return <EmptyState icon={Sparkles} title="তালিকা খালি" />;

  const q = query.trim();
  const visible = q
    ? names.filter((n) => n.translitBn.includes(q) || n.meaningBn.includes(q) || n.arabic.includes(q))
    : names;

  return (
    <div>
      <BackBar label="আরও-তে ফিরুন" onBack={onBack} />
      <h2 className="text-lg font-bold">আল্লাহর ৯৯ নাম — আসমাউল হুসনা</h2>
      <p className="mt-0.5 text-xs text-muted-foreground">
        «যে ব্যক্তি আল্লাহর ৯৯ নাম হিফয করবে, সে জান্নাতে প্রবেশ করবে» (বুখারী ২৭৩৬)
      </p>
      <div className="relative mt-3">
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="নাম খুঁজুন…"
          className="h-11 rounded-xl"
          aria-label="আল্লাহর নাম খুঁজুন"
        />
      </div>
      <div className="mt-4 grid grid-cols-1 gap-2.5 sm:grid-cols-2">
        {visible.map((n) => (
          <Card key={n.id} className="rounded-xl p-3.5 shadow-card">
            <div className="flex items-baseline justify-between gap-2">
              <span className="text-xs font-bold text-muted-foreground">{toBn(n.id)}.</span>
              <span dir="rtl" className="font-arabic text-2xl text-primary">
                {n.arabic}
              </span>
            </div>
            <p className="mt-1.5 text-sm font-bold">{n.translitBn}</p>
            <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{n.meaningBn}</p>
            {n.virtue ? (
              <p className="mt-2 rounded-lg bg-gold-soft px-2.5 py-1.5 text-[11px] leading-relaxed text-gold-text-foreground">
                {n.virtue}
              </p>
            ) : null}
          </Card>
        ))}
      </div>
      {visible.length === 0 ? <p className="py-6 text-center text-sm text-muted-foreground">কোনো নাম মেলেনি</p> : null}
    </div>
  );
}

// ── ইসলামিক নাম ────────────────────────────────────────────────────────────

function IslamicNamesView({ onBack }: { onBack: () => void }) {
  const { data, loading, error } = useAsync<IslamicNamesPack>(() => getPack("islamicNames") as Promise<IslamicNamesPack>);
  const [query, setQuery] = React.useState("");
  const [gender, setGender] = React.useState<"all" | "boy" | "girl">("all");

  if (loading) return <SkeletonRows count={6} className="h-14" />;
  if (error) return <EmptyState icon={Baby} title="লোড করা যায়নি" hint={error} />;
  const names: IslamicName[] = data?.names ?? [];
  if (names.length === 0) return <EmptyState icon={Baby} title="তালিকা খালি" />;

  const q = query.trim();
  const visible = names.filter(
    (n) => (gender === "all" || n.gender === gender) && (!q || n.name.includes(q) || n.meaningBn.includes(q))
  );

  const genders: { key: "all" | "boy" | "girl"; label: string }[] = [
    { key: "all", label: "সব" },
    { key: "boy", label: "ছেলেদের" },
    { key: "girl", label: "মেয়েদের" },
  ];

  return (
    <div>
      <BackBar label="আরও-তে ফিরুন" onBack={onBack} />
      <h2 className="text-lg font-bold">ইসলামিক নাম</h2>
      <p className="mt-0.5 text-xs text-muted-foreground">
        নবীজি ﷺ বলেছেন — সত্য দোয়ার দিন তোমাদের নাম ডেকে ডাকা হবে, সুতরাং সুন্দর নাম রাখো (আবু দাউদ ৪৯৪৮)
      </p>
      <div className="relative mt-3">
        <Input
          value={query}
          onChange={(e) => setQuery(e.target.value)}
          placeholder="নাম বা অর্থ খুঁজুন…"
          className="h-11 rounded-xl"
          aria-label="নাম খুঁজুন"
        />
      </div>
      <div className="mt-3 flex gap-1.5">
        {genders.map((g) => (
          <button
            key={g.key}
            onClick={() => setGender(g.key)}
            aria-pressed={gender === g.key}
            className={cn(
              "tap-target flex-1 rounded-full text-xs font-semibold transition-colors",
              gender === g.key ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
            )}
          >
            {g.label}
          </button>
        ))}
      </div>
      <div className="mt-4 space-y-2">
        {visible.map((n) => (
          <Card key={n.id} className="rounded-xl p-3.5 shadow-card">
            <div className="flex items-baseline justify-between gap-3">
              <p className="text-sm font-bold">{n.name}</p>
              <span className="text-xs text-muted-foreground">{n.gender === "boy" ? "ছেলে" : "মেয়ে"}</span>
            </div>
            <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{n.meaningBn}</p>
            {n.gender_note ? <p className="mt-1.5 text-[11px] leading-relaxed text-gold-text-foreground">{n.gender_note}</p> : null}
          </Card>
        ))}
        {visible.length === 0 ? <p className="py-6 text-center text-sm text-muted-foreground">কোনো নাম মেলেনি</p> : null}
      </div>
    </div>
  );
}

// ── প্রবন্ধ ─────────────────────────────────────────────────────────────────

function ArticlesView({ onBack, openId }: { onBack: () => void; openId?: string }) {
  const { data, loading, error } = useAsync<ArticlesPack>(() => getPack("articles") as Promise<ArticlesPack>);
  const [open, setOpen] = React.useState<string | null>(null);

  React.useEffect(() => {
    if (openId) setOpen(openId);
  }, [openId]);

  if (loading) return <SkeletonRows count={4} className="h-20" />;
  if (error) return <EmptyState icon={Newspaper} title="লোড করা যায়নি" hint={error} />;
  const items: ArticleItem[] = data?.items ?? [];
  if (items.length === 0) return <EmptyState icon={Newspaper} title="এখনো কোনো প্রবন্ধ নেই" />;

  const article = open ? items.find((a) => a.id === open) ?? null : null;

  return (
    <div>
      <BackBar label="আরও-তে ফিরুন" onBack={onBack} />
      <h2 className="text-lg font-bold">প্রবন্ধ</h2>
      <div className="mt-3 space-y-2.5">
        {items.map((a) => (
          <button
            key={a.id}
            onClick={() => setOpen(a.id)}
            className="tap-target block w-full rounded-xl border border-border bg-card p-4 text-start shadow-card transition-colors hover:bg-muted/50"
          >
            <div className="flex items-start justify-between gap-2">
              <h3 className="text-[15px] font-bold leading-snug">{a.titleBn}</h3>
              {a.readMinutes ? (
                <span className="shrink-0 text-xs text-muted-foreground">{toBn(a.readMinutes)} মিনিট পাঠ</span>
              ) : null}
            </div>
            <p className="mt-1.5 line-clamp-2 text-sm leading-relaxed text-muted-foreground">{a.excerptBn}</p>
            {a.category ? <p className="mt-2 text-xs font-medium text-primary">{a.category}</p> : null}
          </button>
        ))}
      </div>

      <Dialog open={article !== null} onOpenChange={(o) => !o && setOpen(null)}>
        <DialogContent className="max-h-[82vh] overflow-y-auto rounded-2xl scroll-thin">
          <DialogHeader>
            <DialogTitle className="text-start leading-snug">{article?.titleBn}</DialogTitle>
          </DialogHeader>
          <div className="space-y-3">
            {article?.bodyBn.split(/\n{2,}/).map((para, i) => (
              <p key={i} className="text-sm leading-relaxed">
                {para}
              </p>
            ))}
          </div>
          {article?.category ? <p className="text-xs font-medium text-primary">{article.category}</p> : null}
        </DialogContent>
      </Dialog>
    </div>
  );
}

// ── সুন্নাহ সমূহ ────────────────────────────────────────────────────────────

const SUNNAH_CATS: { key: SunnahItem["category"]; label: string }[] = [
  { key: "daily", label: "দৈনন্দিন সুন্নাহ" },
  { key: "forgotten", label: "বিস্মৃত সুন্নাহ" },
  { key: "salah", label: "নামাজের সুন্নাহ" },
];

function SunnahsView({ onBack }: { onBack: () => void }) {
  const { data, loading, error } = useAsync<SunnahsPack>(() => getPack("sunnahs") as Promise<SunnahsPack>);
  if (loading) return <SkeletonRows count={5} className="h-20" />;
  if (error) return <EmptyState icon={Sun} title="লোড করা যায়নি" hint={error} />;
  const items: SunnahItem[] = data?.items ?? [];
  if (items.length === 0) return <EmptyState icon={Sun} title="এখনো কোনো সুন্নাহ যুক্ত হয়নি" />;

  return (
    <div>
      <BackBar label="আরও-তে ফিরুন" onBack={onBack} />
      <h2 className="text-lg font-bold">সুন্নাহ সমূহ</h2>
      {SUNNAH_CATS.map((cat) => {
        const list = items.filter((i) => i.category === cat.key);
        if (list.length === 0) return null;
        return (
          <div key={cat.key} className="mt-4">
            <h3 className="text-sm font-bold text-primary">
              {cat.label} <span className="font-normal text-muted-foreground">({toBn(list.length)})</span>
            </h3>
            <div className="mt-2 space-y-2">
              {list.map((s) => (
                <Card key={s.id} className="rounded-xl p-3.5 shadow-card">
                  <p className="text-sm font-bold">{s.titleBn}</p>
                  <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{s.detailBn}</p>
                  {s.reference ? <p className="mt-1.5 text-xs font-medium text-primary">{s.reference}</p> : null}
                </Card>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}

// ── ঈমানের ৭০ শাখা ─────────────────────────────────────────────────────────

const IMAN_GROUPS: { key: ImanBranch["group"]; label: string }[] = [
  { key: "heart", label: "অন্তরের শাখা" },
  { key: "tongue", label: "মুখের শাখা" },
  { key: "body", label: "দেহের শাখা" },
];

function ImanBranchesView({ onBack }: { onBack: () => void }) {
  const { data, loading, error } = useAsync<ImanBranchesPack>(() => getPack("imanBranches") as Promise<ImanBranchesPack>);
  if (loading) return <SkeletonRows count={5} className="h-20" />;
  if (error) return <EmptyState icon={Heart} title="লোড করা যায়নি" hint={error} />;
  const branches: ImanBranch[] = data?.branches ?? [];
  if (branches.length === 0) return <EmptyState icon={Heart} title="তালিকা খালি" />;

  return (
    <div>
      <BackBar label="আরও-তে ফিরুন" onBack={onBack} />
      <h2 className="text-lg font-bold">ঈমানের ৭০ শাখা</h2>
      <p className="mt-0.5 flex items-center gap-1.5 text-xs text-muted-foreground">
        <BookHeart className="size-3.5 shrink-0" /> ঈমানের সত্তরটিরও অধিক শাখা রয়েছে (বুখারী ৯, মুসলিম ৩৫)
      </p>
      {IMAN_GROUPS.map((g) => {
        const list = branches.filter((b) => b.group === g.key);
        if (list.length === 0) return null;
        return (
          <div key={g.key} className="mt-4">
            <h3 className="text-sm font-bold text-primary">
              {g.label} <span className="font-normal text-muted-foreground">({toBn(list.length)})</span>
            </h3>
            <div className="mt-2 space-y-1.5">
              {list.map((b) => (
                <div key={b.id} className="flex items-start gap-2.5 rounded-xl border border-border bg-card p-3 shadow-card">
                  <span className="mt-0.5 text-xs font-bold text-muted-foreground">{toBn(b.id)}.</span>
                  <div className="min-w-0">
                    <p className="text-sm font-semibold leading-snug">{b.titleBn}</p>
                    {b.detailBn ? <p className="mt-0.5 text-xs leading-relaxed text-muted-foreground">{b.detailBn}</p> : null}
                  </div>
                </div>
              ))}
            </div>
          </div>
        );
      })}
    </div>
  );
}
