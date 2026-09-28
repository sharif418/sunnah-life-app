"use client";

// লাইভ কুইজ — উসরাভিত্তিক socket.io কুইজ। B9 থেকে গেটওয়েটি NestJS API-র
// ভেতরেই (একই প্রসেস, একই auth, একই ডিপ্লয়মেন্ট) — পথ /socket.io।
// সংযোগ: NEXT_PUBLIC_API_BASE দিলে সেটিই, নাহলে same-origin (একটি
// reverse proxy /socket.io কে API-র দিকে পাঠায়)। টোকেন API থেকে (GET
// /api/quiz/live-token) — উসরা প্রধান হোস্ট, বাকিরা প্লেয়ার; ঘর = উসরা
// (এক-লিঙ্গ), তাই লিডারবোর্ডে শুধু প্রথম নাম + মেম্বার কোড যায়।

import * as React from "react";
import { io, type Socket } from "socket.io-client";
import { motion } from "framer-motion";
import { toast } from "sonner";
import { Brain, Check, ChevronRight, Crown, LogIn, Radio, RotateCcw, Users, Wifi, WifiOff } from "lucide-react";
import { api } from "@/lib/api";
import { API_BASE } from "@/lib/api-base";
import { getPack } from "@/lib/content";
import type { QuizzesPack } from "@/lib/content";
import type { Quiz } from "@/types/domain";
import { useApp } from "@/lib/store";
import { toBn } from "@/lib/calendars";
import { EmptyState, SkeletonRows, StatusPill, useAsync } from "./parts";
import { Button } from "@/components/ui/button";
import { Card } from "@/components/ui/card";
import { cn } from "@/lib/utils";

// ── wire types (apps/api/src/engagement/quiz.gateway.ts protocol) ────────────

interface LiveQuestion {
  index: number;
  questionBn: string;
  options: string[];
  seconds: number;
  endsAt: number;
}
interface ScoreRow {
  name: string;
  memberCode: string | null;
  score: number;
  lastPoints: number | null;
}
interface RoomStateMsg {
  room: string;
  role: "host" | "player";
  phase: "lobby" | "question" | "reveal" | "ended";
  quizId: string | null;
  quizTitle: string | null;
  questionCount: number;
  currentIndex: number | null;
  players: { name: string; memberCode: string | null; online: boolean }[];
  scoreboard: ScoreRow[];
}
interface RevealMsg {
  index: number;
  answerIndex: number;
  explanationBn: string | null;
  tally: number[];
  scoreboard: ScoreRow[];
}

export function LiveQuizSection() {
  const user = useApp((s) => s.user);
  const setAuthModal = useApp((s) => s.setAuthModal);
  const { data: pack, loading, error } = useAsync<QuizzesPack>(() => getPack("quizzes") as Promise<QuizzesPack>);

  const [socket, setSocket] = React.useState<Socket | null>(null);
  const [role, setRole] = React.useState<"host" | "player">("player");
  const [phase, setPhase] = React.useState<"lobby" | "question" | "reveal" | "ended">("lobby");
  const [quizTitle, setQuizTitle] = React.useState<string | null>(null);
  const [questionCount, setQuestionCount] = React.useState(0);
  const [question, setQuestion] = React.useState<LiveQuestion | null>(null);
  const [reveal, setReveal] = React.useState<RevealMsg | null>(null);
  const [state, setState] = React.useState<RoomStateMsg | null>(null);
  const [myChoice, setMyChoice] = React.useState<number | null>(null);
  const [joining, setJoining] = React.useState(false);

  const quizzes: Quiz[] = pack?.quizzes ?? [];
  const liveQuizzes = quizzes.filter((q) => q.live);

  // countdown ticker for the live question
  const [now, setNow] = React.useState(Date.now());
  React.useEffect(() => {
    if (phase !== "question") return;
    const t = setInterval(() => setNow(Date.now()), 250);
    return () => clearInterval(t);
  }, [phase]);
  const remainingSec = question ? Math.max(0, Math.ceil((question.endsAt - now) / 1000)) : 0;

  // ── join: mint a token through the API, then connect to the API's own
  // socket.io gateway (NEXT_PUBLIC_API_BASE origin, or same-origin when a
  // reverse proxy fronts the API) ────────────
  const join = async () => {
    setJoining(true);
    try {
      const res = await api.quizLiveToken("");
      const url = API_BASE || "/";
      const s = io(url, {
        path: "/socket.io",
        auth: { token: res.token },
        transports: ["websocket", "polling"],
        reconnection: false,
        timeout: 8000,
      });
      setSocket(s);
      setRole(res.role);
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "লাইভ কুইজে যোগ দেওয়া যায়নি");
    } finally {
      setJoining(false);
    }
  };

  React.useEffect(() => {
    if (!socket) return;
    const onState = (s: RoomStateMsg) => {
      setState(s);
      setPhase(s.phase);
    };
    const onStarted = (payload: { titleBn: string; questionCount: number }) => {
      setQuizTitle(payload.titleBn);
      setQuestionCount(payload.questionCount);
      setReveal(null);
      setMyChoice(null);
    };
    const onQuestion = (q: LiveQuestion) => {
      setQuestion(q);
      setReveal(null);
      setMyChoice(null);
      setNow(Date.now());
    };
    const onReveal = (r: RevealMsg) => {
      setReveal(r);
      setQuestion((prev) => (prev && prev.index === r.index ? { ...prev, endsAt: 0 } : prev));
    };
    const onErr = (e: { messageBn: string }) => toast.error(e?.messageBn ?? "সমস্যা হয়েছে");
    const onConnectError = () => toast.error("কুইজ সার্ভারে পৌঁছানো যাচ্ছে না");

    socket.on("room:state", onState);
    socket.on("quiz:started", onStarted);
    socket.on("quiz:question", onQuestion);
    socket.on("quiz:reveal", onReveal);
    socket.on("quiz:ended", onReveal); // ended carries the final scoreboard too
    socket.on("quiz:error", onErr);
    socket.on("connect_error", onConnectError);

    return () => {
      socket.off("room:state", onState);
      socket.off("quiz:started", onStarted);
      socket.off("quiz:question", onQuestion);
      socket.off("quiz:reveal", onReveal);
      socket.off("quiz:ended", onReveal);
      socket.off("quiz:error", onErr);
      socket.off("connect_error", onConnectError);
    };
  }, [socket]);

  // leave on unmount
  React.useEffect(() => {
    return () => {
      socket?.close();
    };
  }, [socket]);

  const answer = (choice: number) => {
    if (!socket || phase !== "question" || myChoice !== null) return;
    setMyChoice(choice);
    socket.emit("player:answer", { index: question?.index, choice });
  };

  // ── render guards ────────────────────────────────────────────────────────

  if (!user)
    return (
      <EmptyState
        icon={Users}
        title="লাইভ কুইজ — উসরার জন্য"
        hint="উসরার সদস্য হিসেবে সাইন ইন করলে আপনার উসরা প্রধানের চালানো লাইভ কুইজে অংশ নিতে পারবেন।"
        action={
          <Button className="h-11 rounded-xl" onClick={() => setAuthModal(true)}>
            <LogIn className="size-4" /> সাইন ইন করুন
          </Button>
        }
      />
    );

  if (loading) return <SkeletonRows count={3} className="h-28" />;
  if (error) return <EmptyState icon={Radio} title="কুইজ তালিকা লোড করা যায়নি" hint={error} />;

  if (!socket) {
    return (
      <div className="space-y-3">
        <Card className="rounded-xl p-5 shadow-card">
          <div className="flex items-start gap-3">
            <span className="flex size-11 shrink-0 items-center justify-center rounded-full bg-primary-soft">
              <Users className="size-5 text-primary" />
            </span>
            <div className="min-w-0">
              <h2 className="text-base font-bold">উসরার লাইভ কুইজ</h2>
              <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
                আপনার উসরার ঘরে ঢুকে একসাথে কুইজ খেলুন — প্রশ্ন আসবে একে একে, সবার স্কোর লিডারবোর্ডে উঠবে।
                উসরা প্রধান কুইজ শুরু করলেই আপনার স্ক্রিনে প্রশ্ন চলে আসবে, ইনশাআল্লাহ।
              </p>
            </div>
          </div>
          <Button className="mt-4 h-11 w-full rounded-xl" disabled={joining} onClick={() => void join()}>
            <Radio className="size-4" /> {joining ? "যোগ হচ্ছে…" : "কুইজ ঘরে প্রবেশ করুন"}
          </Button>
        </Card>
      </div>
    );
  }

  const scoreboard = state?.scoreboard ?? [];
  const isHost = role === "host";

  return (
    <div className="space-y-4">
      <div className="flex items-center justify-between gap-2">
        <h2 className="text-lg font-bold">লাইভ কুইজ</h2>
        <StatusPill tone={phase === "question" ? "alert" : "primary"} pulse={phase === "question"}>
          <Wifi className="size-3.5" /> {socket.connected ? "সংযুক্ত" : "বিচ্ছিন্ন"}
        </StatusPill>
      </div>

      {/* host controls */}
      {isHost ? (
        <HostPanel
          liveQuizzes={liveQuizzes}
          phase={phase}
          quizTitle={quizTitle}
          questionCount={questionCount}
          onStart={(quizId) => socket.emit("host:start", { quizId })}
          onNext={() => socket.emit("host:next")}
          onEnd={() => socket.emit("host:end")}
        />
      ) : null}

      {/* question */}
      {phase === "question" && question ? (
        <motion.div key={question.index} initial={{ opacity: 0, y: 8 }} animate={{ opacity: 1, y: 0 }}>
          <Card className="rounded-xl p-4 shadow-card">
            <div className="flex items-center justify-between gap-2">
              <StatusPill tone="primary">
                প্রশ্ন {toBn(question.index + 1)}{questionCount ? `/${toBn(questionCount)}` : ""}
              </StatusPill>
              <span className={cn("text-2xl font-extrabold tabular-nums", remainingSec <= 5 ? "text-alert" : "text-primary")}>
                {toBn(Math.min(remainingSec, question.seconds))}s
              </span>
            </div>
            <p className="mt-3 text-[15px] font-bold leading-relaxed">{question.questionBn}</p>
            <div className="mt-4 space-y-2">
              {question.options.map((opt, i) => {
                const picked = myChoice === i;
                return (
                  <button
                    key={i}
                    disabled={myChoice !== null || isHost}
                    onClick={() => answer(i)}
                    className={cn(
                      "tap-target flex w-full items-center gap-3 rounded-xl border border-border bg-card p-3 text-start text-sm leading-relaxed transition-colors",
                      myChoice === null && !isHost && "hover:border-primary/40 hover:bg-muted/50",
                      picked && "border-primary bg-primary-soft"
                    )}
                  >
                    <span
                      className={cn(
                        "flex size-8 shrink-0 items-center justify-center rounded-full text-xs font-bold",
                        picked ? "bg-primary text-primary-foreground" : "bg-muted text-muted-foreground"
                      )}
                    >
                      {picked ? <Check className="size-4" /> : toBn(i + 1)}
                    </span>
                    <span className="flex-1">{opt}</span>
                  </button>
                );
              })}
            </div>
            {isHost ? (
              <p className="mt-3 text-center text-xs text-muted-foreground">সবাই উত্তর দিলে অটো ফলাফল — তাড়াতাড়ি দেখতে "ফলাফল" চাপুন</p>
            ) : myChoice !== null ? (
              <p className="mt-3 text-center text-xs text-muted-foreground">উত্তর জমা হয়েছে — অপেক্ষা করুন…</p>
            ) : (
              <p className="mt-3 text-center text-xs text-muted-foreground">একটি উত্তর বেছে নিন</p>
            )}
          </Card>
        </motion.div>
      ) : null}

      {/* reveal */}
      {phase === "reveal" && reveal && question ? (
        <Card className="rounded-xl p-4 shadow-card">
          <StatusPill tone="gold">ফলাফল — প্রশ্ন {toBn(reveal.index + 1)}</StatusPill>
          <p className="mt-3 text-sm font-bold">
            সঠিক উত্তর: {question.options[reveal.answerIndex]}
          </p>
          {reveal.explanationBn ? <p className="mt-1 text-xs leading-relaxed text-muted-foreground">{reveal.explanationBn}</p> : null}
          <div className="mt-3 flex flex-wrap gap-1.5">
            {reveal.tally.map((count, i) => (
              <span key={i} className="rounded-full bg-muted px-2.5 py-0.5 text-xs text-muted-foreground">
                {toBn(i + 1)}: {toBn(count)} জন
              </span>
            ))}
          </div>
        </Card>
      ) : null}

      {/* lobby / ended */}
      {phase === "lobby" ? (
        <Card className="rounded-xl p-5 text-center shadow-card">
          <Users className="mx-auto size-8 text-primary/60" />
          <p className="mt-2 text-sm text-muted-foreground">
            {isHost ? "একটি কুইজ বেছে নিয়ে শুরু করুন — আপনার উসরার সদস্যরা যোগ দিচ্ছেন।" : "উসরা প্রধান কুইজ শুরু করলে প্রশ্ন এখানে আসবে…"}
          </p>
          <div className="mt-3 flex flex-wrap justify-center gap-1.5">
            {(state?.players ?? []).map((p) => (
              <span key={p.memberCode ?? p.name} className="rounded-full bg-primary-soft px-2.5 py-0.5 text-xs font-medium text-primary">
                {p.name}
              </span>
            ))}
          </div>
        </Card>
      ) : null}

      {phase === "ended" ? (
        <Card className="rounded-xl p-5 shadow-card">
          <div className="text-center">
            <Crown className="mx-auto size-8 text-gold-text-foreground" />
            <p className="mt-2 text-sm font-semibold">কুইজ শেষ — চূড়ান্ত ফলাফল</p>
          </div>
          <div className="mt-3 space-y-1.5">
            {scoreboard.map((row, i) => (
              <ScoreRowView key={row.memberCode ?? row.name + i} rank={i + 1} row={row} />
            ))}
          </div>
          <Button
            variant="outline"
            className="mt-4 h-11 w-full rounded-xl"
            onClick={() => {
              socket.close();
              setSocket(null);
              setPhase("lobby");
              setState(null);
              setQuestion(null);
              setReveal(null);
              setQuizTitle(null);
            }}
          >
            <RotateCcw className="size-4" /> ঘর থেকে বেরিয়ে যান
          </Button>
        </Card>
      ) : null}

      {/* live scoreboard */}
      {phase !== "ended" && scoreboard.length > 0 ? (
        <div>
          <h3 className="mb-2 flex items-center gap-1.5 text-sm font-bold">
            <Crown className="size-4 text-gold-text-foreground" /> লিডারবোর্ড
          </h3>
          <div className="space-y-1.5">
            {scoreboard.map((row, i) => (
              <ScoreRowView key={row.memberCode ?? row.name + i} rank={i + 1} row={row} />
            ))}
          </div>
        </div>
      ) : null}
    </div>
  );
}

function ScoreRowView({ rank, row }: { rank: number; row: ScoreRow }) {
  return (
    <div
      className={cn(
        "flex items-center gap-3 rounded-xl border border-border bg-card px-3 py-2 shadow-card",
        rank === 1 && "border-gold/40"
      )}
    >
      <span
        className={cn(
          "flex size-7 shrink-0 items-center justify-center rounded-full text-xs font-bold",
          rank === 1 ? "bg-gold-soft text-gold-text-foreground" : "bg-muted text-muted-foreground"
        )}
      >
        {toBn(rank)}
      </span>
      <span className="min-w-0 flex-1">
        <span className="block truncate text-sm font-semibold">{row.name}</span>
        {row.memberCode ? <span className="block text-[11px] text-muted-foreground">{row.memberCode}</span> : null}
      </span>
      <span className="shrink-0 text-end">
        <span className="block text-sm font-extrabold tabular-nums">{toBn(row.score)}</span>
        {row.lastPoints !== null ? (
          <span className={cn("block text-[11px]", row.lastPoints > 0 ? "text-primary" : "text-muted-foreground")}>
            {row.lastPoints > 0 ? `+${toBn(row.lastPoints)}` : "—"}
          </span>
        ) : null}
      </span>
    </div>
  );
}

function HostPanel({
  liveQuizzes,
  phase,
  quizTitle,
  questionCount,
  onStart,
  onNext,
  onEnd,
}: {
  liveQuizzes: Quiz[];
  phase: RoomStateMsg["phase"];
  quizTitle: string | null;
  questionCount: number;
  onStart: (quizId: string) => void;
  onNext: () => void;
  onEnd: () => void;
}) {
  const [selected, setSelected] = React.useState<string>(liveQuizzes[0]?.id ?? "");
  return (
    <Card className="rounded-xl border-gold/30 p-4 shadow-card">
      <div className="flex items-center gap-2">
        <Crown className="size-4 text-gold-text-foreground" />
        <h3 className="text-sm font-bold">উসরা প্রধান — কুইজ নিয়ন্ত্রণ</h3>
      </div>
      {/*
        Lobby WITHOUT a started quiz → the picker. Once quiz:started lands
        (phase is still "lobby" until the first host:next) show the running
        controls — the host advances to the first question with প্রথম প্রশ্ন.
      */}
      {phase === "lobby" && !quizTitle ? (
        <div className="mt-3 space-y-2">
          {liveQuizzes.map((q) => (
            <button
              key={q.id}
              onClick={() => setSelected(q.id)}
              className={cn(
                "tap-target flex w-full items-center gap-2.5 rounded-xl border p-3 text-start text-sm transition-colors",
                selected === q.id ? "border-primary bg-primary-soft" : "border-border bg-card hover:bg-muted/50"
              )}
            >
              <Brain className="size-4 shrink-0 text-primary" />
              <span className="min-w-0 flex-1">
                <span className="block truncate font-semibold">{q.titleBn}</span>
                <span className="block text-xs text-muted-foreground">{toBn(q.questions.length)} প্রশ্ন</span>
              </span>
              {selected === q.id ? <Check className="size-4 shrink-0 text-primary" /> : null}
            </button>
          ))}
          <Button className="h-11 w-full rounded-xl" disabled={!selected} onClick={() => onStart(selected)}>
            <Radio className="size-4" /> কুইজ শুরু করুন
          </Button>
        </div>
      ) : (
        <div className="mt-3">
          <p className="text-sm font-semibold">{quizTitle ?? "কুইজ চলছে"}</p>
          <p className="mt-0.5 text-xs text-muted-foreground">
            {toBn(questionCount)} প্রশ্ন · ফেজ:{" "}
            {phase === "lobby"
              ? "শুরু হয়েছে — প্রথম প্রশ্ন চালু করুন"
              : phase === "question"
                ? "চলছে"
                : phase === "reveal"
                  ? "ফলাফল"
                  : "শেষ"}
          </p>
          <div className="mt-3 flex gap-2">
            {phase === "lobby" ? (
              <Button className="h-11 flex-1 rounded-xl" onClick={onNext}>
                প্রথম প্রশ্ন <ChevronRight className="size-4" />
              </Button>
            ) : phase === "question" ? (
              <Button variant="secondary" className="h-11 flex-1 rounded-xl" onClick={onNext}>
                ফলাফল দেখান
              </Button>
            ) : phase === "reveal" ? (
              <Button className="h-11 flex-1 rounded-xl" onClick={onNext}>
                পরের প্রশ্ন <ChevronRight className="size-4" />
              </Button>
            ) : null}
            {phase !== "ended" ? (
              <Button variant="outline" className="h-11 rounded-xl" onClick={onEnd}>
                <WifiOff className="size-4" /> শেষ করুন
              </Button>
            ) : null}
          </div>
        </div>
      )}
    </Card>
  );
}
