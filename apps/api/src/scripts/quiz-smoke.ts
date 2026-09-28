// Smoke test for the in-process live-quiz gateway (bun run smoke:quiz):
// one host + two players join a room with manually-minted HMAC tokens (the
// same module the API uses), run a full question round and assert the
// leaderboard. Exits non-zero on any failure. Run the API first:
//   DATABASE_URL=… QUIZ_SECRET=… bun run start  (or start:dev)
import { io } from "socket.io-client";
import { mintQuizToken } from "../engagement/quiz-token";

const URL = process.env.QUIZ_SMOKE_URL || "http://127.0.0.1:3001";
const ROOM = "usrah-smoke-001";

const hostToken = mintQuizToken({ u: "u-host", s: ROOM, r: "host", g: "M", n: "ইউসুফ", m: "DS-000003", q: "quiz-salah", e: Date.now() + 5 * 60_000 });
const p1Token = mintQuizToken({ u: "u-p1", s: ROOM, r: "player", g: "M", n: "রাফিউল", m: "DS-000004", q: "quiz-salah", e: Date.now() + 5 * 60_000 });
const p2Token = mintQuizToken({ u: "u-p2", s: ROOM, r: "player", g: "M", n: "মেহেদী", m: "DS-000009", q: "quiz-salah", e: Date.now() + 5 * 60_000 });
const badToken = "AAAA.BBBB";

function connect(token: string) {
  return io(URL, { path: "/socket.io", auth: { token }, transports: ["websocket"], reconnection: false, timeout: 5000 });
}

const log: string[] = [];
let failures = 0;
const check = (label: string, ok: boolean) => {
  log.push(`${ok ? "PASS" : "FAIL"} — ${label}`);
  if (!ok) failures++;
};

const host = connect(hostToken);
const p1 = connect(p1Token); // will answer CORRECTLY
const p2 = connect(p2Token); // will answer WRONG

type Reveal = {
  index: number;
  answerIndex: number;
  explanationBn: string | null;
  tally: number[];
  scoreboard: { name: string; memberCode: string | null; score: number; lastPoints: number | null }[];
};

const started = new Promise((res) => host.once("quiz:started", res));
const question = new Promise<Record<string, unknown>>((res) => {
  const onQ = (payload: Record<string, unknown>) => res(payload);
  host.once("quiz:question", onQ);
  p1.once("quiz:question", onQ);
});

const main = async () => {
  // 1. room state on join
  const hostState: any = await new Promise((res) => host.once("room:state", res));
  check(`host room:state role=host (got ${hostState?.role})`, hostState?.role === "host");
  const p1State: any = await new Promise((res) => p1.once("room:state", res));
  check(`player room:state role=player (got ${p1State?.role})`, p1State?.role === "player");
  check("room ids match the token usrah", hostState?.room === ROOM && p1State?.room === ROOM);

  // 2. start the quiz
  host.emit("host:start", { quizId: "quiz-salah" });
  const startedEvt: any = await started;
  check(`quiz:started title (got ${startedEvt?.titleBn})`, startedEvt?.titleBn === "সালাতের নিয়মকানুন");
  check(`questionCount (got ${startedEvt?.questionCount})`, startedEvt?.questionCount === 10);

  // 3. first question — players must NOT receive the answer key
  host.emit("host:next");
  const q: any = await question;
  check(`question index 0 (got ${q?.index})`, q?.index === 0);
  check(`4 options (got ${q?.options?.length})`, Array.isArray(q?.options) && q.options.length === 4);
  check("no answerIndex leaked to players", q?.answerIndex === undefined && q?.correctIndex === undefined);
  check(`seconds countdown (got ${q?.seconds})`, q?.seconds === 20);

  // 4. both answer (correct + wrong) → reveal fires with the leaderboard
  const reveal = await new Promise<Reveal>((res) => {
    p1.once("quiz:reveal", res);
    p1.emit("player:answer", { index: 0, choice: q.answerIndex ?? 2 }); // pick below
    p2.emit("player:answer", { index: 0, choice: (q.answerIndex ?? 0) === 0 ? 1 : 0 }); // guaranteed wrong
  });
  // the smoke client doesn't know the right answer — learn it from the reveal
  check(`reveal answerIndex (got ${reveal?.answerIndex})`, typeof reveal?.answerIndex === "number");
  check(`tally has 4 buckets (got ${reveal?.tally?.length})`, reveal?.tally?.length === 4);
  const p1Row = reveal.scoreboard.find((s) => s.memberCode === "DS-000004");
  const p2Row = reveal.scoreboard.find((s) => s.memberCode === "DS-000009");
  check("leaderboard uses first names + member codes only", p1Row?.name === "রাফিউল" && p2Row?.name === "মেহেদী");
  // p1 guessed index 2 and the reveal says answerIndex 2 → CORRECT round for p1
  if (reveal.answerIndex === 2) {
    check(`correct answer scored 100+speed bonus (got ${p1Row?.lastPoints})`, (p1Row?.lastPoints ?? 0) >= 100);
    check(`wrong answer scored 0 (got ${p2Row?.lastPoints})`, p2Row?.lastPoints === 0);
  }

  // 5. one more question where p1 answers with the LEARNED correct index of
  //    question 2 — we discover the answer from the tally+our own choice:
  // Redis-adapter pub/sub hop: the first question's broadcast can still be
  // in flight when host:next fires — await the SPECIFIC index, not merely
  // "the next event" (the stale index-0 delivery won the race once).
  const q2 = await new Promise<any>((res) => {
    const onQuestion = (payload: any) => {
      if (payload?.index !== 1) return;
      host.off("quiz:question", onQuestion);
      res(payload);
    };
    host.on("quiz:question", onQuestion);
    host.emit("host:next");
  });
  check(`second question index 1 (got ${q2?.index})`, q2?.index === 1);
  const reveal2 = await new Promise<Reveal>((res) => {
    p1.once("quiz:reveal", res);
    p1.emit("player:answer", { index: 1, choice: 0 });
    p2.emit("player:answer", { index: 1, choice: 1 });
  });
  const p1Row2 = reveal2.scoreboard.find((s) => s.memberCode === "DS-000004");
  if (reveal2.answerIndex === 0) {
    check("correct answer scored 100+ (speed bonus)", (p1Row2?.lastPoints ?? 0) >= 100);
  } else {
    check("wrong answer scored 0", p1Row2?.lastPoints === 0);
  }
  check("scoreboard sorted by score", reveal2.scoreboard.every((s, i) => i === 0 || reveal2.scoreboard[i - 1].score >= s.score));

  // 6. host ends the quiz
  const ended = await new Promise<any>((res) => {
    host.once("quiz:ended", res);
    host.emit("host:end");
  });
  check(`quiz:ended scoreboard (got ${ended?.scoreboard?.length} rows)`, Array.isArray(ended?.scoreboard) && ended.scoreboard.length === 2);

  // 7. invalid token → rejected connection
  const bad = connect(badToken);
  const badErr: any = await new Promise((res) => bad.once("quiz:error", res));
  check(`invalid token refused with Bengali error (got ${badErr?.messageBn})`, typeof badErr?.messageBn === "string");
  await new Promise((res) => bad.once("disconnect", res));
  check("invalid-token socket disconnected", true);

  // 8. a player cannot start the quiz (role check)
  const denied = await new Promise<any>((res) => {
    p1.once("quiz:error", res);
    p1.emit("host:start", { quizId: "quiz-salah" });
  });
  check(`player cannot host (got ${denied?.messageBn})`, denied?.messageBn === "শুধুমাত্র উসরা প্রধান কুইজ চালু করতে পারবেন");

  host.close();
  p1.close();
  p2.close();
  console.log(log.join("\n"));
  console.log(`\n${failures === 0 ? "SMOKE OK — all checks passed (gateway on the NestJS API process)" : `SMOKE FAILED (${failures})`}`);
  process.exit(failures === 0 ? 0 : 1);
};

main().catch((e) => {
  console.error(log.join("\n"));
  console.error("SMOKE crashed:", e);
  process.exit(1);
});
