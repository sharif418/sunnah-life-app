"use client";

// উসরা প্রশ্নোত্তর — সদস্য প্রশ্ন করেন (POST /api/usrah-questions), উসরা প্রধান
// উত্তর দেন (POST /api/usrah-questions/:id/answers)। তালিকা শুধু নিজের উসরার
// (RLS)। অতিথিদের সাইন-ইন প্রম্পট।

import * as React from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { CheckCircle2, Loader2, LogIn, MessageCircleQuestion, Send } from "lucide-react";
import { api } from "@/lib/api";
import type { UsrahQuestionItem } from "@/types/domain";
import { useApp } from "@/lib/store";
import { ROLE_RANK } from "@/types/domain";
import { toBn } from "@/lib/calendars";
import { EmptyState, SkeletonRows, useAsync, relTimeBn } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { cn } from "@/lib/utils";

const CATEGORIES: { key: UsrahQuestionItem["category"]; label: string }[] = [
  { key: "general", label: "সাধারণ" },
  { key: "aqeedah", label: "আকীদা" },
  { key: "salah", label: "সালাত" },
  { key: "quran", label: "কুরআন" },
  { key: "muamalah", label: "লেনদেন" },
  { key: "tarbiyah", label: "তারবিয়াত" },
];

export function UsrahQuestionsView() {
  const user = useApp((s) => s.user);
  const setAuthModal = useApp((s) => s.setAuthModal);
  const [question, setQuestion] = React.useState("");
  const [category, setCategory] = React.useState<UsrahQuestionItem["category"]>("general");
  const [sending, setSending] = React.useState(false);
  const [answering, setAnswering] = React.useState<string | null>(null);
  const [answerText, setAnswerText] = React.useState("");

  const board = useAsync<{ questions: UsrahQuestionItem[] } | null>(
    async () => (user ? api.usrahQuestions() : null),
    user ? "auth" : "guest"
  );

  if (!user)
    return (
      <EmptyState
        icon={MessageCircleQuestion}
        title="উসরার প্রশ্নোত্তর বোর্ড"
        hint="দায়ী হিসেবে সাইন ইন করলে আপনার উসরার ভেতরে প্রশ্ন করতে পারবেন এবং উসরা প্রধানের উত্তর দেখতে পারবেন।"
        action={
          <Button className="h-11 rounded-xl" onClick={() => setAuthModal(true)}>
            <LogIn className="size-4" /> সাইন ইন করুন
          </Button>
        }
      />
    );

  const isHead = ROLE_RANK[user.role] >= ROLE_RANK["usrah_head"];
  const questions = board.data?.questions ?? [];

  const ask = async (e: React.FormEvent) => {
    e.preventDefault();
    const text = question.trim();
    if (text.length < 8) {
      toast.error("প্রশ্নটি আরেকটু বিস্তারিত লিখুন");
      return;
    }
    setSending(true);
    try {
      await api.askUsrahQuestion({ question: text, category });
      setQuestion("");
      toast.success("প্রশ্ন পাঠানো হয়েছে — উসরা প্রধান উত্তর দিলে এখানে দেখা যাবে");
      void board.reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "পাঠানো যায়নি");
    } finally {
      setSending(false);
    }
  };

  const submitAnswer = async (id: string) => {
    const text = answerText.trim();
    if (!text) return;
    setSending(true);
    try {
      await api.answerUsrahQuestion(id, text);
      setAnswerText("");
      setAnswering(null);
      toast.success("উত্তর প্রকাশিত হয়েছে");
      void board.reload();
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "উত্তর দেওয়া যায়নি");
    } finally {
      setSending(false);
    }
  };

  return (
    <div className="space-y-4">
      <div>
        <h2 className="text-lg font-bold">উসরার প্রশ্নোত্তর</h2>
        <p className="mt-0.5 text-sm text-muted-foreground">
          আপনার উসরার ভেতরের প্রশ্ন ও উত্তর — শুধু উসরার সদস্যরাই দেখতে পারেন।
        </p>
      </div>

      <Card className="rounded-xl p-4 shadow-card">
        <form onSubmit={ask} className="space-y-3" aria-label="উসরায় প্রশ্ন করুন">
          <div className="space-y-1.5">
            <Label htmlFor="uq-text">আপনার প্রশ্ন</Label>
            <Textarea
              id="uq-text"
              value={question}
              onChange={(e) => setQuestion(e.target.value)}
              rows={3}
              className="rounded-xl text-base leading-relaxed"
              placeholder="যা জানতে চান লিখুন…"
            />
          </div>
          <div className="no-scrollbar -mx-1 flex gap-1.5 overflow-x-auto px-1">
            {CATEGORIES.map((c) => (
              <button
                key={c.key}
                type="button"
                onClick={() => setCategory(c.key)}
                className={cn(
                  "tap-target shrink-0 rounded-full px-3 py-1.5 text-xs font-semibold transition-colors",
                  category === c.key ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
                )}
              >
                {c.label}
              </button>
            ))}
          </div>
          <Button type="submit" disabled={sending} className="h-11 w-full rounded-xl">
            {sending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
            {sending ? "পাঠানো হচ্ছে…" : "প্রশ্ন পাঠান"}
          </Button>
        </form>
      </Card>

      {board.loading ? (
        <SkeletonRows count={3} className="h-24" />
      ) : board.error ? (
        <EmptyState icon={MessageCircleQuestion} title="তালিকা আনা যায়নি" hint={board.error} />
      ) : questions.length === 0 ? (
        <EmptyState
          icon={MessageCircleQuestion}
          title="এখনো কোনো প্রশ্ন নেই"
          hint="উপরের ফর্ম থেকে প্রথম প্রশ্নটি করুন — উসরার সবাই দেখতে পাবে।"
        />
      ) : (
        <div className="space-y-2.5">
          {questions.map((q, i) => (
            <motion.div key={q.id} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: Math.min(i * 0.03, 0.2) }}>
              <Card className={cn("rounded-xl p-4 shadow-card", q.answer ? "border-primary/20" : "border-gold/25")}>
                <div className="flex items-start justify-between gap-2">
                  <div className="min-w-0">
                    <p className="text-sm font-bold leading-relaxed">{q.question}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {q.authorName ?? "সদস্য"} · {relTimeBn(q.createdAt)}
                      {q.category !== "general" ? ` · ${CATEGORIES.find((c) => c.key === q.category)?.label ?? ""}` : ""}
                    </p>
                  </div>
                  {q.answer ? (
                    <span className="shrink-0">
                      <CheckCircle2 className="size-5 text-primary" />
                    </span>
                  ) : (
                    <span className="shrink-0 rounded-full bg-gold-soft px-2 py-0.5 text-[11px] font-semibold text-warning">উত্তরের অপেক্ষায়</span>
                  )}
                </div>

                {q.answer ? (
                  <div className="mt-3 rounded-xl bg-primary-soft px-3.5 py-3">
                    <p className="text-xs font-bold text-primary">{q.answeredByName ?? "উসরা প্রধান"} — উত্তর</p>
                    <p className="mt-1 text-sm leading-relaxed">{q.answer}</p>
                    {q.answeredAt ? <p className="mt-1 text-[11px] text-muted-foreground">{relTimeBn(q.answeredAt)}</p> : null}
                  </div>
                ) : isHead ? (
                  answering === q.id ? (
                    <div className="mt-3 space-y-2">
                      <Textarea
                        value={answerText}
                        onChange={(e) => setAnswerText(e.target.value)}
                        rows={3}
                        className="rounded-xl text-sm leading-relaxed"
                        placeholder="উত্তর লিখুন…"
                        aria-label="উত্তর লিখুন"
                      />
                      <div className="flex gap-2">
                        <Button size="sm" className="h-10 flex-1 rounded-xl" disabled={sending || !answerText.trim()} onClick={() => void submitAnswer(q.id)}>
                          {sending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />} প্রকাশ করুন
                        </Button>
                        <Button size="sm" variant="outline" className="h-10 rounded-xl" onClick={() => { setAnswering(null); setAnswerText(""); }}>
                          বাতিল
                        </Button>
                      </div>
                    </div>
                  ) : (
                    <Button size="sm" variant="outline" className="mt-3 h-10 rounded-xl" onClick={() => { setAnswering(q.id); setAnswerText(""); }}>
                      <MessageCircleQuestion className="size-4" /> উত্তর দিন
                    </Button>
                  )
                ) : null}
              </Card>
            </motion.div>
          ))}
        </div>
      )}

      {questions.length > 0 ? (
        <p className="text-center text-xs text-muted-foreground">{toBn(questions.length)}টি প্রশ্ন — সব আপনার উসরার ভেতরেই।</p>
      ) : null}
    </div>
  );
}
