"use client";

// কুইজ — quizzes.json প্যাক থেকে কুইজ কার্ড → প্রশ্ন-ধারাবাহিক খেলা (উত্তর দিন →
// সঠিক/ভুল + ব্যাখ্যা → পরের প্রশ্ন) → চূড়ান্ত স্কোর (সাইন-ইন থাকলে
// POST /api/quiz-attempt) + সর্বশেষ স্কোরের ইতিহাস (GET /api/quiz-attempts)।
// অতিথিরাও খেলতে পারেন — স্কোর শুধু সার্ভারে জমা হয় না।

import * as React from "react";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Award, Brain, Check, ChevronRight, Clock, ListChecks, RefreshCw, Swords, Trophy, X } from "lucide-react";
import { api } from "@/lib/api";
import { getPack } from "@/lib/content";
import type { QuizzesPack } from "@/lib/content";
import type { Quiz, QuizAttemptItem } from "@/types/domain";
import { useApp } from "@/lib/store";
import { toBn } from "@/lib/calendars";
import { EmptyState, SkeletonRows, StatusPill, useAsync, relTimeBn } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { Progress } from "@/components/ui/progress";
import { cn } from "@/lib/utils";

export function QuizzesSection({ startQuizId }: { startQuizId?: string }) {
  const user = useApp((s) => s.user);
  const { data, loading, error } = useAsync<QuizzesPack>(() => getPack("quizzes") as Promise<QuizzesPack>);
  const [playing, setPlaying] = React.useState<string | null>(null);

  // my attempt history (signed-in only; guests skip the badges)
  const attempts = useAsync<{ attempts: QuizAttemptItem[] } | null>(
    async () => (user ? api.quizAttempts() : null),
    user ? "auth" : "guest"
  );

  React.useEffect(() => {
    if (startQuizId) setPlaying(startQuizId);
  }, [startQuizId]);

  if (loading) return <SkeletonRows count={3} className="h-28" />;
  if (error) return <EmptyState icon={Brain} title="কুইজ লোড করা যায়নি" hint={error} />;
  const quizzes: Quiz[] = data?.quizzes ?? [];
  if (quizzes.length === 0)
    return (
      <EmptyState icon={Brain} title="কুইজ শীঘ্রই আসছে, ইনশাআল্লাহ" hint="কুরআন-সুন্নাহ, আকীদা ও ফিকহের কুইজ এখানে যুক্ত হবে।" />
    );

  const active = playing ? quizzes.find((q) => q.id === playing) ?? null : null;
  if (active) return <QuizPlay key={active.id} quiz={active} onExit={() => setPlaying(null)} />;

  const byQuiz = new Map<string, QuizAttemptItem[]>();
  for (const a of attempts.data?.attempts ?? []) {
    byQuiz.set(a.quizId, [...(byQuiz.get(a.quizId) ?? []), a]);
  }

  return (
    <div className="space-y-3">
      {quizzes.map((q) => {
        const mine = byQuiz.get(q.id) ?? [];
        const best = mine.length ? Math.max(...mine.map((a) => a.score)) : null;
        return (
          <Card key={q.id} className="rounded-xl p-4 shadow-card">
            <div className="flex items-start justify-between gap-2">
              <div className="min-w-0">
                <h3 className="text-[15px] font-bold leading-snug">{q.titleBn}</h3>
                <p className="mt-1 line-clamp-2 text-sm leading-relaxed text-muted-foreground">{q.descBn}</p>
              </div>
              {best !== null ? (
                <StatusPill tone="gold">
                  <Trophy className="size-3.5" /> {toBn(best)}/{toBn(q.questions.length)}
                </StatusPill>
              ) : null}
            </div>
            <div className="mt-3 flex flex-wrap items-center gap-x-4 gap-y-1 text-xs text-muted-foreground">
              <span className="inline-flex items-center gap-1">
                <ListChecks className="size-3.5" /> {toBn(q.questions.length)} প্রশ্ন
              </span>
              <span className="inline-flex items-center gap-1">
                <Clock className="size-3.5" /> {toBn(q.minutes)} মিনিট
              </span>
              {q.live ? (
                <span className="inline-flex items-center gap-1">
                  <Swords className="size-3.5" /> লাইভ কুইজযোগ্য
                </span>
              ) : null}
            </div>
            {mine.length > 0 ? (
              <p className="mt-2 text-xs text-muted-foreground">
                সর্বশেষ: {toBn(mine[0].score)}/{toBn(mine[0].total)} · {relTimeBn(mine[0].createdAt)}
              </p>
            ) : null}
            <Button className="mt-4 h-11 w-full rounded-xl" onClick={() => setPlaying(q.id)}>
              <Brain className="size-4" /> {mine.length > 0 ? "আবার খেলুন" : "কুইজ শুরু করুন"}
            </Button>
          </Card>
        );
      })}

      {(attempts.data?.attempts?.length ?? 0) > 0 ? (
        <div className="pt-2">
          <h3 className="mb-2 text-sm font-bold">আমার সর্বশেষ স্কোর</h3>
          <div className="space-y-1.5">
            {attempts.data!.attempts.slice(0, 5).map((a) => {
              const quiz = quizzes.find((q) => q.id === a.quizId);
              return (
                <div
                  key={a.id}
                  className="flex items-center justify-between rounded-xl border border-border bg-card px-3 py-2 text-sm shadow-card"
                >
                  <span className="min-w-0 truncate">{quiz?.titleBn ?? a.quizId}</span>
                  <span className="shrink-0 tabular-nums text-muted-foreground">
                    {toBn(a.score)}/{toBn(a.total)} · {relTimeBn(a.createdAt)}
                  </span>
                </div>
              );
            })}
          </div>
        </div>
      ) : null}
      {!user ? (
        <p className="pt-1 text-center text-xs text-muted-foreground">
          সাইন ইন করলে আপনার স্কোর সেভ হবে ও উসরার লাইভ কুইজে যোগ দিতে পারবেন।
        </p>
      ) : null}
    </div>
  );
}

// ── খেলার ফ্লো ──────────────────────────────────────────────────────────────

function QuizPlay({ quiz, onExit }: { quiz: Quiz; onExit: () => void }) {
  const { user, setAuthModal } = useApp();
  const total = quiz.questions.length;
  const [index, setIndex] = React.useState(0);
  const [chosen, setChosen] = React.useState<number | null>(null); // current question's pick
  const [answers, setAnswers] = React.useState<number[]>([]); // graded picks per question
  const [done, setDone] = React.useState(false);
  const [saved, setSaved] = React.useState(false);

  const score = answers.reduce((acc, c, i) => acc + (quiz.questions[i] && c === quiz.questions[i].answerIndex ? 1 : 0), 0);
  const current = quiz.questions[done ? total - 1 : index];

  const next = () => {
    if (chosen === null) return;
    const graded = [...answers];
    graded[index] = chosen;
    setAnswers(graded);
    if (index + 1 >= total) {
      setDone(true);
    } else {
      setIndex(index + 1);
      setChosen(null);
    }
  };

  // persist the attempt once on finish (signed-in only)
  React.useEffect(() => {
    if (!done || saved || !user) return;
    setSaved(true);
    api.quizAttempt(quiz.id, score, total).catch(() => toast.error("স্কোর সেভ করা যায়নি — পরে আবার চেষ্টা করুন"));
  }, [done, saved, user, quiz.id, score, total]);

  const restart = () => {
    setIndex(0);
    setChosen(null);
    setAnswers([]);
    setDone(false);
    setSaved(false);
  };

  const revealed = chosen !== null && !done;
  const pct = Math.round((100 * (done ? total : index + (revealed ? 1 : 0))) / total);

  return (
    <motion.div initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }} className="space-y-4">
      <Button variant="ghost" className="h-11 rounded-xl px-2 text-muted-foreground" onClick={onExit}>
        কুইজ তালিকায় ফিরুন
      </Button>

      <div>
        <div className="flex items-center justify-between gap-2">
          <h2 className="text-lg font-bold leading-snug">{quiz.titleBn}</h2>
          <StatusPill tone="primary">
            {toBn(done ? total : index + 1)}/{toBn(total)}
          </StatusPill>
        </div>
        <Progress value={pct} className="mt-3 h-1.5" />
      </div>

      {done ? (
        <Card className="rounded-xl p-6 text-center shadow-card">
          <div className="mx-auto flex size-20 items-center justify-center rounded-full bg-primary-soft">
            {score >= Math.ceil(total * 0.8) ? <Trophy className="size-9 text-gold-foreground" /> : <Award className="size-9 text-primary" />}
          </div>
          <p className="mt-4 text-3xl font-extrabold tabular-nums">
            {toBn(score)}/{toBn(total)}
          </p>
          <p className="mt-1 text-sm text-muted-foreground">
            {score === total
              ? "আলহামদুলিল্লাহ — পুরো নম্বর!"
              : score >= Math.ceil(total * 0.8)
                ? "মাশাআল্লাহ — চমৎকার করেছেন!"
                : "চালিয়ে যান — অনুশীলনেই দক্ষতা আসে।"}
          </p>
          {user ? (
            <p className="mt-2 text-xs text-muted-foreground">স্কোর আপনার প্রোফাইলে সেভ হয়েছে।</p>
          ) : (
            <Button
              variant="outline"
              className="mt-4 h-11 rounded-xl"
              onClick={() => {
                setAuthModal(true);
                toast.info("স্কোর সেভ করতে সাইন ইন করুন");
              }}
            >
              স্কোর সেভ করতে সাইন ইন করুন
            </Button>
          )}
          <Button className="mt-4 h-11 w-full rounded-xl" onClick={restart}>
            <RefreshCw className="size-4" /> আবার খেলুন
          </Button>
        </Card>
      ) : (
        <Card className="rounded-xl p-4 shadow-card">
          <p className="text-[15px] font-bold leading-relaxed">{current?.questionBn}</p>
          <div className="mt-4 space-y-2">
            {current?.options.map((opt, i) => {
              const isCorrect = current.answerIndex === i;
              const isMine = chosen === i;
              return (
                <button
                  key={i}
                  disabled={revealed}
                  onClick={() => setChosen(i)}
                  className={cn(
                    "tap-target flex w-full items-center gap-3 rounded-xl border border-border bg-card p-3 text-start text-sm leading-relaxed transition-colors",
                    !revealed && "hover:border-primary/40 hover:bg-muted/50",
                    revealed && isCorrect && "border-primary bg-primary-soft",
                    revealed && isMine && !isCorrect && "border-alert bg-alert-soft",
                    revealed && !isMine && !isCorrect && "opacity-60"
                  )}
                >
                  <span
                    className={cn(
                      "flex size-8 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                      revealed && isCorrect
                        ? "bg-primary text-primary-foreground"
                        : revealed && isMine
                          ? "bg-alert text-white"
                          : "bg-muted text-muted-foreground"
                    )}
                  >
                    {revealed && isCorrect ? <Check className="size-4" /> : revealed && isMine ? <X className="size-4" /> : toBn(i + 1)}
                  </span>
                  <span className="flex-1">{opt}</span>
                </button>
              );
            })}
          </div>

          {revealed ? (
            <motion.div initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} className="mt-4">
              <div
                className={cn(
                  "rounded-xl px-3.5 py-3 text-sm leading-relaxed",
                  chosen === current.answerIndex ? "bg-primary-soft text-primary-foreground" : "bg-alert-soft text-alert"
                )}
              >
                <p className="font-bold">
                  {chosen === current.answerIndex
                    ? "সঠিক উত্তর, মাশাআল্লাহ!"
                    : `সঠিক উত্তর হলো: ${current.options[current.answerIndex]}`}
                </p>
                {current.explanationBn ? <p className="mt-1 text-xs opacity-90">{current.explanationBn}</p> : null}
              </div>
              <Button className="mt-3 h-11 w-full rounded-xl" disabled={chosen === null} onClick={next}>
                {index + 1 >= total ? "ফলাফল দেখুন" : "পরের প্রশ্ন"}
                <ChevronRight className="size-4" />
              </Button>
            </motion.div>
          ) : (
            <p className="mt-3 text-center text-xs text-muted-foreground">একটি উত্তর বেছে নিন</p>
          )}
        </Card>
      )}
    </motion.div>
  );
}
