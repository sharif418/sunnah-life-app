import { Logger } from "@nestjs/common";
import {
  ConnectedSocket,
  MessageBody,
  OnGatewayConnection,
  OnGatewayDisconnect,
  SubscribeMessage,
  WebSocketGateway,
} from "@nestjs/websockets";
import type { Socket } from "socket.io";
import { loadPack } from "../shared/quran";
import { verifyQuizToken, type QuizTokenPayload } from "./quiz-token";

// ─────────────────────────────────────────────────────────────────────────────
// Task B9 — live usrah quiz, folded INTO the NestJS API as a socket.io gateway.
//
// Previously a separate bun mini-service on :3030; now there is ONE backend,
// ONE deployment and ONE auth path: the gateway is a module of the API
// process, mounted on the same HTTP server (path /socket.io), and the HMAC
// room token it verifies is minted by this same process
// (GET /api/quiz/live-token, QUIZ_SECRET) after the caller authenticated
// through the normal JwtAuthGuard + RLS checks (own usrah, real gender).
//
// GENDER ISOLATION (unchanged): the room id IS the usrah id and usrahs are
// single-gender by design; the API only mints tokens for a user's OWN usrah
// (room), so no room can ever mix genders. The leaderboard broadcasts first
// names + member codes only — full identities never leave the usrah.
//
// Room state is EPHEMERAL in-memory game state (scores/timers) — nothing is
// persisted here; every durable write in the platform goes through the
// RLS-scoped REST routes.
//
// PROTOCOL (identical to the retired mini-service — web + Flutter clients)
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

const SECONDS_PER_QUESTION = 20;

/** CORS mirrors main.ts (polling handshakes bypass Express). */
function socketCors() {
  const origins = (process.env.CORS_ORIGINS || "")
    .split(",")
    .map((s) => s.trim())
    .filter(Boolean);
  return { origin: origins.length ? origins : true, credentials: true };
}

// ── quiz content (packages/content/quizzes.json — the same pack the API serves)

interface QuizQuestion {
  id: string;
  questionBn: string;
  options: string[];
  answerIndex: number;
  explanationBn?: string;
}
interface Quiz {
  id: string;
  titleBn: string;
  questions: QuizQuestion[];
}

async function loadQuiz(quizId: string): Promise<Quiz | null> {
  const raw = (await loadPack("quizzes")) as { quizzes?: Quiz[] } | null;
  const quiz = raw?.quizzes?.find((q) => q.id === quizId);
  return quiz && quiz.questions?.length ? quiz : null;
}

// ── room state ──────────────────────────────────────────────────────────────

interface Player {
  socket: Socket;
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
  hostSocket: Socket | null;
  quizId: string | null;
  quizTitle: string | null;
  questions: QuizQuestion[] | null;
  currentIndex: number;
  questionStartsAt: number;
  questionEndsAt: number;
  phase: Phase;
  players: Map<string, Player>; // by userId (reconnect-safe)
  sockets: Map<string, Socket>; // every verified connection in the room
  timer: ReturnType<typeof setTimeout> | null;
}

interface ScoreRow {
  name: string;
  memberCode: string | null;
  score: number;
  lastPoints: number | null;
}

/** Identity attached to every admitted socket at connection time. */
interface SocketData {
  identity?: QuizTokenPayload;
}

function scoreboard(room: Room, lastPoints?: Map<string, number>): ScoreRow[] {
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
    online: room.sockets.has(p.socket.id),
  }));
}

@WebSocketGateway({ path: "/socket.io", cors: socketCors() })
export class QuizGateway implements OnGatewayConnection, OnGatewayDisconnect {
  private readonly logger = new Logger("QuizGateway");
  private readonly rooms = new Map<string, Room>();

  // ── connection lifecycle ────────────────────────────────────────────────────

  handleConnection(client: Socket): void {
    const token = (client.handshake.auth?.token as string | undefined) ?? "";
    const identity = verifyQuizToken(token);
    if (!identity) {
      this.logger.log(`rejected socket ${client.id} (invalid/expired token)`);
      client.emit("quiz:error", { messageBn: "সংযোগ বাতিল — আবার কুইজে প্রবেশ করুন" });
      client.disconnect(true);
      return;
    }

    (client.data as SocketData).identity = identity;
    const room = this.getRoom(identity.s);
    room.sockets.set(client.id, client);
    this.logger.log(`${identity.r} ${identity.n} (${identity.m ?? "-"}) joined room ${room.usrahId}`);

    if (identity.r === "host") {
      // one live host at a time — a reconnecting host replaces the old socket
      room.hostSocket = client;
    } else {
      const existing = room.players.get(identity.u);
      room.players.set(identity.u, {
        socket: client,
        userId: identity.u,
        name: identity.n,
        memberCode: identity.m,
        score: existing?.score ?? 0, // reconnect keeps the score
        correctCount: existing?.correctCount ?? 0,
        answer: null,
      });
    }

    // join state for the newcomer, then let the room see the player list
    client.emit("room:state", this.roomState(room, identity));
    this.broadcastState(room);
  }

  handleDisconnect(client: Socket): void {
    const identity = (client.data as SocketData).identity;
    if (!identity) return; // never admitted
    const room = this.rooms.get(identity.s);
    if (!room) return;

    room.sockets.delete(client.id);
    if (room.hostSocket === client) {
      room.hostSocket = null; // players keep their scores; a host may rejoin
    }
    // a player's row stays PARKED (score kept for a reconnect); the room
    // dies only when nobody at all is connected anymore.
    this.broadcastState(room);
    const anyLive =
      room.hostSocket !== null || [...room.players.values()].some((p) => room.sockets.has(p.socket.id));
    if (!anyLive) {
      this.clearTimer(room);
      this.rooms.delete(room.usrahId);
      this.logger.log(`room ${room.usrahId} closed (empty)`);
    }
  }

  // ── host controls ──────────────────────────────────────────────────────────

  @SubscribeMessage("host:start")
  async onStart(@ConnectedSocket() client: Socket, @MessageBody() payload: { quizId?: string }): Promise<void> {
    const identity = this.identityOf(client);
    const room = identity ? this.rooms.get(identity.s) : null;
    if (!identity || !room) return;
    if (identity.r !== "host" || room.hostSocket !== client) {
      client.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান কুইজ চালু করতে পারবেন" });
      return;
    }
    const quizId = String(payload?.quizId ?? "");
    if (!quizId) {
      client.emit("quiz:error", { messageBn: "কুইজ নির্বাচন করা হয়নি" });
      return;
    }
    await this.startQuiz(room, quizId);
  }

  @SubscribeMessage("host:next")
  onNext(@ConnectedSocket() client: Socket): void {
    const identity = this.identityOf(client);
    const room = identity ? this.rooms.get(identity.s) : null;
    if (!identity || !room) return;
    if (identity.r !== "host" || room.hostSocket !== client) {
      client.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান প্রশ্ন এগিয়ে নিতে পারবেন" });
      return;
    }
    if (!room.questions) {
      client.emit("quiz:error", { messageBn: "আগে একটি কুইজ শুরু করুন" });
      return;
    }
    if (room.phase === "question") {
      this.revealQuestion(room); // early reveal ("সবাই উত্তর দিয়েছে"-style skip)
      return;
    }
    this.nextQuestion(room);
  }

  @SubscribeMessage("host:end")
  onEnd(@ConnectedSocket() client: Socket): void {
    const identity = this.identityOf(client);
    const room = identity ? this.rooms.get(identity.s) : null;
    if (!identity || !room) return;
    if (identity.r !== "host" || room.hostSocket !== client) {
      client.emit("quiz:error", { messageBn: "শুধুমাত্র উসরা প্রধান কুইজ শেষ করতে পারবেন" });
      return;
    }
    if (room.questions) this.endQuiz(room);
  }

  // ── player answer ──────────────────────────────────────────────────────────

  @SubscribeMessage("player:answer")
  onAnswer(@ConnectedSocket() client: Socket, @MessageBody() payload: { index?: number; choice?: number }): void {
    const identity = this.identityOf(client);
    const room = identity ? this.rooms.get(identity.s) : null;
    if (!identity || !room) return;
    if (identity.r === "host") return; // the host runs the quiz, not plays it
    if (room.phase !== "question") {
      client.emit("quiz:error", { messageBn: "এখন কোনো প্রশ্ন চলছে না" });
      return;
    }
    const player = room.players.get(identity.u);
    if (!player || player.socket.id !== client.id) return;
    if (player.answer) return; // one answer per question
    const choice = Number(payload?.choice);
    const index = Number(payload?.index);
    if (
      !Number.isInteger(choice) ||
      choice < 0 ||
      choice >= (room.questions?.[room.currentIndex]?.options.length ?? 0)
    ) {
      client.emit("quiz:error", { messageBn: "উত্তরটি ঠিক নয়" });
      return;
    }
    if (index !== room.currentIndex) return; // stale answer for an old question
    player.answer = { choice, atMs: Date.now() };
    client.emit("player:accepted", { index: room.currentIndex, choice });
    if (this.allAnswered(room)) this.revealQuestion(room);
  }

  // ── room helpers ───────────────────────────────────────────────────────────

  private identityOf(client: Socket): QuizTokenPayload | null {
    return (client.data as SocketData).identity ?? null;
  }

  private getRoom(usrahId: string): Room {
    let room = this.rooms.get(usrahId);
    if (!room) {
      room = {
        usrahId,
        hostSocket: null,
        quizId: null,
        quizTitle: null,
        questions: null,
        currentIndex: -1,
        questionStartsAt: 0,
        questionEndsAt: 0,
        phase: "lobby",
        players: new Map(),
        sockets: new Map(),
        timer: null,
      };
      this.rooms.set(usrahId, room);
    }
    return room;
  }

  private roomState(room: Room, self: QuizTokenPayload) {
    return {
      room: room.usrahId,
      role: self.r,
      phase: room.phase,
      quizId: room.quizId,
      quizTitle: room.quizTitle,
      questionCount: room.questions?.length ?? 0,
      currentIndex: room.phase === "question" || room.phase === "reveal" ? room.currentIndex : null,
      players: playerList(room),
      scoreboard: scoreboard(room),
    };
  }

  /** `room:state` is per-socket (each side must see its own role). */
  private broadcastState(room: Room): void {
    for (const socket of room.sockets.values()) {
      const identity = this.identityOf(socket);
      if (identity) socket.emit("room:state", this.roomState(room, identity));
    }
  }

  private emitRoom(room: Room, event: string, payload?: unknown): void {
    for (const socket of room.sockets.values()) socket.emit(event, payload);
  }

  private clearTimer(room: Room): void {
    if (room.timer) {
      clearTimeout(room.timer);
      room.timer = null;
    }
  }

  // ── quiz flow ──────────────────────────────────────────────────────────────

  private async startQuiz(room: Room, quizId: string): Promise<void> {
    const quiz = await loadQuiz(quizId);
    if (!quiz) {
      room.hostSocket?.emit("quiz:error", { messageBn: "কুইজটি পাওয়া যায়নি" });
      return;
    }
    this.clearTimer(room);
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
    this.emitRoom(room, "quiz:started", {
      quizId: quiz.id,
      titleBn: quiz.titleBn,
      questionCount: quiz.questions.length,
    });
    this.broadcastState(room);
  }

  private nextQuestion(room: Room): void {
    if (!room.questions) return;
    if (room.currentIndex + 1 >= room.questions.length) {
      this.endQuiz(room);
      return;
    }
    this.clearTimer(room);
    room.currentIndex += 1;
    room.phase = "question";
    room.questionStartsAt = Date.now();
    room.questionEndsAt = room.questionStartsAt + SECONDS_PER_QUESTION * 1000;
    for (const p of room.players.values()) p.answer = null;

    const q = room.questions[room.currentIndex];
    this.emitRoom(room, "quiz:question", {
      index: room.currentIndex,
      questionBn: q.questionBn,
      options: q.options,
      seconds: SECONDS_PER_QUESTION,
      endsAt: room.questionEndsAt,
    });
    this.broadcastState(room);

    room.timer = setTimeout(() => this.revealQuestion(room), SECONDS_PER_QUESTION * 1000);
  }

  private allAnswered(room: Room): boolean {
    if (room.players.size === 0) return false;
    for (const p of room.players.values()) if (!p.answer) return false;
    return true;
  }

  private revealQuestion(room: Room): void {
    if (!room.questions || room.phase !== "question") return;
    this.clearTimer(room);
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

    this.emitRoom(room, "quiz:reveal", {
      index: room.currentIndex,
      answerIndex: q.answerIndex,
      explanationBn: q.explanationBn ?? null,
      tally,
      scoreboard: scoreboard(room, lastPoints),
    });
    this.broadcastState(room);
  }

  private endQuiz(room: Room): void {
    this.clearTimer(room);
    room.phase = "ended";
    this.emitRoom(room, "quiz:ended", { scoreboard: scoreboard(room) });
    this.broadcastState(room);
  }
}
