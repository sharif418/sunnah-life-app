// ─────────────────────────────────────────────────────────────────────────────
// Sunnah Life — live usrah quiz (socket.io mini-service, port 3030).
//
// Repo rule: WebSocket services are independent bun projects (own port +
// `bun --hot`); the browser NEVER connects to an absolute host:port — the
// Caddy gateway forwards `/?XTransformPort=3030` here (path MUST stay "/").
//
// AUTH: the NestJS API mints a short-lived HMAC token per user
// (GET /api/quiz/live-token?quizId=…) and this service verifies it with the
// same QUIZ_SECRET. The token payload is imported DIRECTLY from the API's
// source (../../apps/api/src/engagement/quiz-token.ts — a dependency-free
// node:crypto module) so both ends share one wire format.
//
// GENDER ISOLATION (documented): the room id IS the usrah id and usrahs are
// single-gender by design; the API only mints tokens for a user's OWN usrah
// (room), so no room can ever mix genders. The leaderboard broadcasts first
// names + member codes only — full identities never leave the usrah.
//
// PROTOCOL
//   client → server                          server → client
//   ─ connect (auth: {token})                 ─ room:state   {phase, role, players, …}
//   ─ host:start  {quizId}                   ─ quiz:started {quizId, titleBn, questionCount}
//   ─ host:next   {}                         ─ quiz:question {index, questionBn, options, seconds, endsAt}
//   ─ player:answer {index, choice}           ─ quiz:reveal  {index, answerIndex, explanationBn, tally, scoreboard}
//   ─ host:end    {}                          ─ quiz:ended   {scoreboard}
//                                            ─ quiz:error   {messageBn}
//
// Scoring: correct → 100 points + a speed bonus (up to +40, linear in the
// time left when the answer landed). Wrong / no answer → 0. One answer per
// question per player; a reconnecting player keeps their score.
// ─────────────────────────────────────────────────────────────────────────────
import { createServer } from "http";
import { Server, type Socket } from "socket.io";
import { readFileSync } from "fs";
import { fileURLToPath } from "url";
import { dirname, join } from "path";
// single source of truth for the HMAC format (pure node:crypto — no Nest deps)
import { verifyQuizToken, type QuizTokenPayload } from "../../apps/api/src/engagement/quiz-token";

const here = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.QUIZ_SERVICE_PORT || 3030);
const SECONDS_PER_QUESTION = 20;

// ── quiz content (packages/content/quizzes.json — the same pack the API serves)
interface QuizQuestion {
  id: string;
  questionBn: string;
  options: string[];
  answerIndex: number;
  explanationBn?: string;
  difficulty?: string;
}
interface Quiz {
  id: string;
  titleBn: string;
  questions: QuizQuestion[];
}

const quizzes = new Map<string, Quiz>();
try {
  const raw = JSON.parse(readFileSync(join(here, "../../packages/content/quizzes.json"), "utf8")) as {
    quizzes: Quiz[];
  };
  for (const q of raw.quizzes ?? []) quizzes.set(q.id, q);
  console.log(`[quiz-service] loaded ${quizzes.size} quizzes from packages/content/quizzes.json`);
} catch (e) {
  console.error("[quiz-service] could not load quizzes.json:", e);
}

// ── room state ──────────────────────────────────────────────────────────────

interface PublicQuestion {
  index: number;
  questionBn: string;
  options: string[];
  seconds: number;
}

interface Player {
  socketId: string;
  userId: string;
  name: string; // first name only (from the token)
  memberCode: string | null;
  score: number;
  correctCount: number;
  answer: { choice: number; atMs: number } | null;
}

type Phase = "lobby" | "question" | "reveal" | "ended";

interface Room {
  usrahId: string;
  hostSocketId: string | null;
  quizId: string | null;
  quizTitle: string | null;
  questions: QuizQuestion[] | null;
  currentIndex: number;
  questionStartsAt: number;
  questionEndsAt: number;
  phase: Phase;
  players: Map<string, Player>; // by userId (reconnect-safe)
  timer: ReturnType<typeof setTimeout> | null;
}

const rooms = new Map<string, Room>();

function scoreboard(room: Room, lastPoints?: Map<string, number>) {
  return [...room.players.values()]
    .map((p) => ({
      name: p.name,
      memberCode: p.memberCode,
      score: p.score,
      lastPoints: lastPoints?.get(p.userId) ?? null,
    }))
    .sort((a, b) => b.score - a.score || a.name.localeCompare(b.name, "bn"));
}

function playerList(room: Room) {
  return [...room.players.values()].map((p) => ({
    name: p.name,
    memberCode: p.memberCode,
    online: io.sockets.sockets.has(p.socketId),
  }));
}

function roomState(room: Room, self: QuizTokenPayload) {
  return {
    room: room.usrahId,
    role: room.hostSocketId && self.u === roomHostUserId(room) ? "host" : self.r,
    phase: room.phase,
    quizId: room.quizId,
    quizTitle: room.quizTitle,
    questionCount: room.questions?.length ?? 0,
    currentIndex: room.phase === "question" || room.phase === "reveal" ? room.currentIndex : null,
    players: playerList(room),
    scoreboard: scoreboard(room),
  };
}

/** userId of the socket currently hosting (null when the host is offline). */
function roomHostUserId(room: Room): string | null {
  return socketIdentity.get(room.hostSocketId)?.u ?? null;
}

// socket.id → verified token payload (identity of every live connection)
const socketIdentity = new Map<string, QuizTokenPayload>();

function getRoom(usrahId: string): Room {
  let room = rooms.get(usrahId);
  if (!room) {
    room = {
      usrahId,
      hostSocketId: null,
      quizId: null,
      quizTitle: null,
      questions: null,
      currentIndex: -1,
      questionStartsAt: 0,
      questionEndsAt: 0,
      phase: "lobby",
      players: new Map(),
      timer: null,
    };
    rooms.set(usrahId, room);
  }
  return room;
}

function broadcastState(room: Room) {
  for (const [socketId, identity] of socketIdentity) {
    if (identity.s !== room.usrahId) continue;
    const socket = io.sockets.sockets.get(socketId);
    if (socket) socket.emit("room:state", roomState(room, identity));
  }
}

function clearTimer(room: Room) {
  if (room.timer) {
    clearTimeout(room.timer);
    room.timer = null;
  }
}

// ── quiz flow ───────────────────────────────────────────────────────────────

function startQuiz(room: Room, hostSocket: Socket, quizId: string): void {
  const quiz = quizzes.get(quizId);
  if (!quiz || !quiz.questions?.length) {
    hostSocket.emit("quiz:error", { messageBn: "কুইজটি পাওয়া যায়নি" });
    return;
  }
  clearTimer(room);
  room.quizId = quiz.id;
  room.quizTitle = quiz.titleBn;
  room.questions = quiz.questions;
  room.currentIndex = -1;
  room.phase = "lobby";
  for (const p of room.players.values()) {
    p.score = 0;
    p.correctCount = 0;
    p.answer = null;
  }
  io.to(room.usrahId).emit("quiz:started", {
    quizId: quiz.id,
    titleBn: quiz.titleBn,
    questionCount: quiz.questions.length,
  });
  broadcastState(room);
}

function nextQuestion(room: Room): void {
  if (!room.questions) return;
  if (room.currentIndex + 1 >= room.questions.length) {
    endQuiz(room);
    return;
  }
  clearTimer(room);
  room.currentIndex += 1;
  room.phase = "question";
  room.questionStartsAt = Date.now();
  room.questionEndsAt = room.questionStartsAt + SECONDS_PER_QUESTION * 1000;
  for (const p of room.players.values()) p.answer = null;

  const q = room.questions[room.currentIndex];
  const publicQuestion: PublicQuestion = {
    index: room.currentIndex,
    questionBn: q.questionBn,
    options: q.options,
    seconds: SECONDS_PER_QUESTION,
  };
  io.to(room.usrahId).emit("quiz:question", {
    ...publicQuestion,
    endsAt: room.questionEndsAt,
  });
  broadcastState(room);

  room.timer = setTimeout(() => revealQuestion(room), SECONDS_PER_QUESTION * 1000);
}

function allAnswered(room: Room): boolean {
  if (room.players.size === 0) return false;
  for (const p of room.players.values()) if (!p.answer) return false;
  return true;
}

function revealQuestion(room: Room): void {
  if (!room.questions || room.phase !== "question") return;
  clearTimer(room);
  room.phase = "reveal";

  const q = room.questions[room.currentIndex];
  const total = Math.max(1, room.questionEndsAt - room.questionStartsAt);
  const lastPoints = new Map<string, number>();
  const tally = q.options.map(() => 0);

  for (const p of room.players.values()) {
    if (p.answer) tally[p.answer.choice] += 1;
    if (p.answer && p.answer.choice === q.answerIndex) {
      const remaining = Math.max(0, room.questionEndsAt - p.answer.atMs);
      const points = 100 + Math.round(40 * (remaining / total)); // speed bonus
      p.score += points;
      p.correctCount += 1;
      lastPoints.set(p.userId, points);
    } else {
      lastPoints.set(p.userId, 0);
    }
  }

  io.to(room.usrahId).emit("quiz:reveal", {
    index: room.currentIndex,
    answerIndex: q.answerIndex,
    explanationBn: q.explanationBn ?? null,
    tally,
    scoreboard: scoreboard(room, lastPoints),
  });
  broadcastState(room);
}

function endQuiz(room: Room): void {
  clearTimer(room);
  room.phase = "ended";
  io.to(room.usrahId).emit("quiz:ended", { scoreboard: scoreboard(room) });
  broadcastState(room);
}

// ── server ─────────────────────────────────────────────────────────────────

const httpServer = createServer();
const io = new Server(httpServer, {
  // DO NOT change the path — Caddy forwards /?XTransformPort=3030 with it.
  path: "/",
  cors: { origin: "*", methods: ["GET", "POST"] },
  pingTimeout: 60000,
  pingInterval: 25000,
});

io.on("connection", (socket: Socket) => {
  const token = (socket.handshake.auth?.token as string | undefined) ?? "";
  const identity = verifyQuizToken(token);
  if (!identity) {
    console.log(`[quiz-service] rejected socket ${socket.id} (invalid/expired token)`);
    socket.emit("quiz:error", { messageBn: "সংযোগ বাতিল — আবার কুইজে প্রবেশ করুন" });
    socket.disconnect(true);
    return;
  }

  socketIdentity.set(socket.id, identity);
  const room = getRoom(identity.s);
  socket.join(room.usrahId);
  console.log(`[quiz-service] ${identity.r} ${identity.n} (${identity.m ?? "-"}) joined room ${room.usrahId}`);

  if (identity.r === "host") {
    // one live host at a time — a reconnecting host replaces the old socket
    room.hostSocketId = socket.id;
  } else {
    const existing = room.players.get(identity.u);
    room.players.set(identity.u, {
      socketId: socket.id,
      userId: identity.u,
      name: identity.n,
      memberCode: identity.m,
      score: existing?.score ?? 0, // reconnect keeps the score
      correctCount: existing?.correctCount ?? 0,
      answer: null,
    });
  }

  // join state for the newcomer, then let the room see the player list
  socket.emit("room:state", roomState(room, identity));
  broadcastState(room);

  // ── host controls ─────────────────────────────────────────────────────────
  socket.on("host:start", (payload: { quizId?: string }) => {
    if (identity.r !== "host" || room.hostSocketId !== socket.id) {
      socket.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান কুইজ চালু করতে পারবেন" });
      return;
    }
    const quizId = String(payload?.quizId ?? "");
    if (!quizId) {
      socket.emit("quiz:error", { messageBn: "কুইজ নির্বাচন করা হয়নি" });
      return;
    }
    startQuiz(room, socket, quizId);
  });

  socket.on("host:next", () => {
    if (identity.r !== "host" || room.hostSocketId !== socket.id) {
      socket.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান প্রশ্ন এগিয়ে নিতে পারবেন" });
      return;
    }
    if (!room.questions) {
      socket.emit("quiz:error", { messageBn: "আগে একটি কুইজ শুরু করুন" });
      return;
    }
    if (room.phase === "question") {
      revealQuestion(room); // early reveal ("সবাই উত্তর দিয়েছে"-style skip)
      return;
    }
    nextQuestion(room);
  });

  socket.on("host:end", () => {
    if (identity.r !== "host" || room.hostSocketId !== socket.id) {
      socket.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান কুইজ শেষ করতে পারবেন" });
      return;
    }
    if (room.questions) endQuiz(room);
  });

  // ── player answer ───────────────────────────────────────────────────────
  socket.on("player:answer", (payload: { index?: number; choice?: number }) => {
    if (identity.r === "host") return; // the host runs the quiz, not plays it
    if (room.phase !== "question") {
      socket.emit("quiz:error", { messageBn: "এখন কোনো প্রশ্ন চলছে না" });
      return;
    }
    const player = room.players.get(identity.u);
    if (!player || player.socketId !== socket.id) return;
    if (player.answer) return; // one answer per question
    const choice = Number(payload?.choice);
    const index = Number(payload?.index);
    if (!Number.isInteger(choice) || choice < 0 || choice >= (room.questions?.[room.currentIndex]?.options.length ?? 0)) {
      socket.emit("quiz:error", { messageBn: "উত্তরটি সঠিক নয়" });
      return;
    }
    if (index !== room.currentIndex) return; // stale answer for an old question
    player.answer = { choice, atMs: Date.now() };
    socket.emit("player:accepted", { index: room.currentIndex, choice });
    if (allAnswered(room)) revealQuestion(room);
  });

  socket.on("disconnect", () => {
    socketIdentity.delete(socket.id);
    if (room.hostSocketId === socket.id) {
      room.hostSocketId = null; // players keep their scores; a host may rejoin
    }
    // a player's row stays PARKED (score kept for a reconnect); the room
    // dies only when nobody at all is connected anymore.
    broadcastState(room);
    const anyLive =
      room.hostSocketId !== null ||
      [...room.players.values()].some((p) => io.sockets.sockets.has(p.socketId));
    if (!anyLive) {
      clearTimer(room);
      rooms.delete(room.usrahId); // fully empty room → cleaned up
      console.log(`[quiz-service] room ${room.usrahId} closed (empty)`);
    }
  });
});

httpServer.listen(PORT, () => {
  console.log(`[quiz-service] socket.io listening on :${PORT} (room = usrah, HMAC tokens via QUIZ_SECRET)`);
});

// graceful shutdown
for (const sig of ["SIGTERM", "SIGINT"] as const) {
  process.on(sig, () => {
    console.log(`[quiz-service] ${sig} — closing`);
    io.close(() => process.exit(0));
  });
}
