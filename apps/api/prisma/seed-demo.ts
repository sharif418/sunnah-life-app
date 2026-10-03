// ─────────────────────────────────────────────────────────────────────────────
// seed-demo — the demo dataset (15 users, 2 usrahs, 30 days of amal history,
// reviews, assessments, live programs). DESTRUCTIVE to USER-DOMAIN tables.
//
// Phase C/W2a gate: runs ONLY when SEED_DEMO=true AND NODE_ENV !== production;
// REFUSES (exit 1) when SEED_DEMO=true in production; silently skips demo
// data when SEED_DEMO is unset (the normal boot path = seed:reference only).
// Reference tables (AmalDefinition / AssessmentTemplate / AppConfigRow) are
// NEVER wiped here — seed:reference owns them.
// ─────────────────────────────────────────────────────────────────────────────
import { PrismaClient } from "../src/generated/prisma/client";
import { dateKey, parseKey, addDays, weekStartOfSafe, hijriArithmetic, hijriIso, isAyyamBeez, mulberry32, hashStr } from "./seed-helpers";

export interface DemoSeedResult {
  skipped: boolean;
  reason?: string;
}

export async function seedDemo(db: PrismaClient): Promise<DemoSeedResult> {
  const seedDemo = process.env.SEED_DEMO === "true";
  const nodeEnv = process.env.NODE_ENV ?? "development";

  if (seedDemo && nodeEnv === "production") {
    throw new Error(
      "SEED_DEMO=true is REFUSED in production — demo data would wipe real users. " +
      "Unset SEED_DEMO (boot then seeds reference data only)."
    );
  }
  if (!seedDemo) {
    console.log("— SEED_DEMO not set — skipping demo dataset (reference data only)");
    return { skipped: true, reason: "SEED_DEMO not set" };
  }
  if (!["development", "test", "local", "staging", ""].includes(nodeEnv) && nodeEnv !== "development") {
    // unknown NODE_ENV values: treat as production-side (safe default)
    console.warn(`  (unfamiliar NODE_ENV='${nodeEnv}' — allowing demo seed only because it is not 'production')`);
  }

  console.log("  Wiping user-domain tables (demo reseed)…");
  await db.amalEntry.deleteMany();
  await db.personalGoal.deleteMany();
  await db.dayUnlock.deleteMany();
  await db.weeklyReview.deleteMany();
  await db.assessment.deleteMany();
  await db.levelTransition.deleteMany();
  await db.announcement.deleteMany();
  await db.reminder.deleteMany();
  await db.auditLog.deleteMany();
  await db.masalaQuestion.deleteMany();
  await db.feedback.deleteMany();
  await db.liveProgram.deleteMany();
  await db.enrollment.deleteMany();
  await db.quizAttempt.deleteMany();
  await db.usrahQuestion.deleteMany();
  await db.deviceToken.deleteMany();
  await db.session.deleteMany();
  await db.refreshToken.deleteMany();
  await db.otpCode.deleteMany();
  await db.referralClosure.deleteMany();
  await db.user.deleteMany();
  await db.usrah.deleteMany();
  // NOTE: AmalDefinition / AssessmentTemplate / AppConfigRow are owned by
  // seed:reference and are deliberately NOT wiped here.

  // ── 3) Users ──────────────────────────────────────────────────────────────
  const NOW = new Date();
  const d = (days: number, hours = 0) => new Date(NOW.getTime() - (days * 86400 + hours * 3600) * 1000);

  interface Spec {
    phone: string; name: string; gender: "M" | "F"; role: string; category?: string;
    memberCode?: string; refBy?: string; level?: string; levelDays?: number;
    district?: string; city?: string; lat?: number; lng?: number; devout: number;
  }
  const users: Spec[] = [
    { phone: "01000000001", name: "আব্দুল্লাহ আল মামুন", gender: "M", role: "full_admin", district: "dhaka", city: "ঢাকা", lat: 23.8103, lng: 90.4125, devout: 0.95 },
    { phone: "01000000002", name: "হাফেজ যাকারিয়া", gender: "M", role: "invigilator", category: "hafez", district: "dhaka", city: "ঢাকা", lat: 23.7808, lng: 90.2794, devout: 0.92 },
    { phone: "01000000003", name: "মাওলানা ইউসুফ", gender: "M", role: "usrah_head", category: "alim", memberCode: "DS-000003", level: "farze_ain_1", levelDays: 400, district: "dhaka", city: "ঢাকা", lat: 23.8103, lng: 90.4125, devout: 0.95 },
    { phone: "01000000004", name: "রাফিউল ইসলাম", gender: "M", role: "daee", memberCode: "DS-000004", refBy: "01000000003", level: "muhibbus_sunnah", levelDays: 150, district: "dhaka", city: "ঢাকা", lat: 23.7806, lng: 90.4074, devout: 0.88 },
    { phone: "01000000005", name: "উম্মে হাবিবা", gender: "F", role: "usrah_head", category: "alim", memberCode: "DS-000005", level: "farze_ain_1", levelDays: 380, district: "dhaka", city: "ঢাকা", lat: 23.7925, lng: 90.4045, devout: 0.95 },
    { phone: "01000000006", name: "মারিয়াম হাসান", gender: "F", role: "daee", memberCode: "DS-000006", refBy: "01000000005", level: "muhibbus_sunnah", levelDays: 148, district: "dhaka", city: "ঢাকা", lat: 23.7509, lng: 90.3934, devout: 0.86 },
    { phone: "01000000007", name: "তানভীর হোসেন", gender: "M", role: "user", refBy: "01000000004", district: "chattogram", city: "চট্টগ্রাম", lat: 22.3569, lng: 91.7832, devout: 0.55 },
    { phone: "01000000008", name: "সাইফুল ইসলাম", gender: "M", role: "user", refBy: "01000000004", district: "dhaka", city: "ঢাকা", lat: 23.7383, lng: 90.3945, devout: 0.5 },
    { phone: "01000000009", name: "মেহেদী হাসান", gender: "M", role: "daee", category: "hafez", memberCode: "DS-000009", refBy: "01000000004", level: "muhibbus_sunnah", levelDays: 60, district: "cumilla", city: "কুমিল্লা", lat: 23.4607, lng: 91.1809, devout: 0.72 },
    { phone: "01000000010", name: "আব্দুর রহিম", gender: "M", role: "user", refBy: "01000000009", district: "rajshahi", city: "রাজশাহী", lat: 24.3745, lng: 88.6042, devout: 0.45 },
    { phone: "01000000011", name: "ফাতিমা আক্তার", gender: "F", role: "user", refBy: "01000000006", district: "dhaka", city: "ঢাকা", lat: 23.8114, lng: 90.4373, devout: 0.58 },
    { phone: "01000000012", name: "নুসরাত জাহান", gender: "F", role: "user", refBy: "01000000006", district: "sylhet", city: "সিলেট", lat: 24.8949, lng: 91.8687, devout: 0.52 },
    { phone: "01000000013", name: "সাদিয়া রহমান", gender: "F", role: "daee", memberCode: "DS-000013", refBy: "01000000006", level: "muhibbus_sunnah", levelDays: 90, district: "dhaka", city: "ঢাকা", lat: 23.7261, lng: 90.4086, devout: 0.74 },
    { phone: "01000000014", name: "রাইসা খাতুন", gender: "F", role: "user", refBy: "01000000013", district: "khulna", city: "খুলনা", lat: 22.8456, lng: 89.5403, devout: 0.42 },
    { phone: "01000000015", name: "উস্তায়া সালেহা আক্তার", gender: "F", role: "invigilator", district: "dhaka", city: "ঢাকা", lat: 23.7951, lng: 90.4015, devout: 0.93 },
  ];

  const idByPhone = new Map<string, string>();
  for (const u of users) {
    const created = await db.user.create({
      data: {
        phone: u.phone,
        name: u.name,
        gender: u.gender,
        role: u.role,
        category: u.category ?? "general",
        memberCode: u.memberCode ?? null,
        referredById: u.refBy ? idByPhone.get(u.refBy)! : null,
        level: u.level ?? "none",
        levelStartedAt: u.levelDays ? d(u.levelDays) : null,
        district: u.district ?? null,
        city: u.city ?? null,
        lat: u.lat ?? null,
        lng: u.lng ?? null,
        language: "bn",
        madhhab: "hanafi",
        calcMethod: "karachi",
        createdAt: d(240),
      },
    });
    idByPhone.set(u.phone, created.id);
  }
  console.log(`  Users: ${users.length}`);

  // ── 4) Usrahs ─────────────────────────────────────────────────────────────
  const furqan = await db.usrah.create({
    data: {
      name: "উসরা আল-ফুরকান",
      gender: "M",
      headUserId: idByPhone.get("01000000003")!,
      invigilatorUserId: idByPhone.get("01000000002")!,
      district: "dhaka",
    },
  });
  const ayesha = await db.usrah.create({
    data: {
      name: "উসরা আয়েশা সিদ্দিকা",
      gender: "F",
      headUserId: idByPhone.get("01000000005")!,
      invigilatorUserId: idByPhone.get("01000000015")!,
      district: "dhaka",
    },
  });
  const mMembers = ["01000000003", "01000000004", "01000000007", "01000000008", "01000000009", "01000000010"];
  const fMembers = ["01000000005", "01000000006", "01000000011", "01000000012", "01000000013", "01000000014"];
  for (const p of mMembers) await db.user.update({ where: { phone: p }, data: { usrahId: furqan.id } });
  for (const p of fMembers) await db.user.update({ where: { phone: p }, data: { usrahId: ayesha.id } });
  console.log(`  Usrahs: আল-ফুরকান (M, ${mMembers.length}) + আয়েশা সিদ্দিকা (F, ${fMembers.length})`);

  // ── 5) Referral closure tree ──────────────────────────────────────────────
  const closures: { ancestorId: string; descendantId: string; depth: number }[] = [];
  for (const u of users) {
    if (!u.refBy) continue;
    const me = idByPhone.get(u.phone)!;
    const inviter = idByPhone.get(u.refBy)!;
    for (const c of closures.filter((c) => c.descendantId === inviter)) {
      closures.push({ ancestorId: c.ancestorId, descendantId: me, depth: c.depth + 1 });
    }
    closures.push({ ancestorId: inviter, descendantId: me, depth: 1 });
  }
  await db.referralClosure.createMany({ data: closures });
  console.log(`  ReferralClosure rows: ${closures.length}`);

  // ── 6) 30 days of amal history (deterministic) ────────────────────────────
  const today = dateKey(NOW);
  const dates: string[] = Array.from({ length: 30 }, (_, i) => addDays(today, -(29 - i)));
  const defs = await db.amalDefinition.findMany({ where: { active: true } });
  const dailyDefs = defs.filter((x) => x.cadence === "daily");
  const usersWithDiary = users.filter((u) => mMembers.includes(u.phone) || fMembers.includes(u.phone));

  function cadenceDue(def: { cadence: string }, dateStr: string): boolean {
    const wd = parseKey(dateStr).getDay(); // 0=Sun … 5=Fri, 6=Sat
    switch (def.cadence) {
      case "daily": case "weekly:any": return true;
      case "weekly:fri": return wd === 5;
      case "weekly:mon_thu": return wd === 1 || wd === 4;
      case "monthly:ayyam_beez": return isAyyamBeez(parseKey(dateStr));
      default: return true;
    }
  }
  function targetOf(def: { targetJson: unknown }, category: string): number {
    if (!def.targetJson) return 1;
    try {
      const t = def.targetJson as Record<string, number>;
      return t[category] ?? t.general ?? 1;
    } catch {
      return 1;
    }
  }

  const entries: {
    userId: string; amalKey: string; date: string; hijriDate: string;
    valueJson: object; source: string; clientUpdatedAt: Date;
  }[] = [];

  for (const u of usersWithDiary) {
    const uid = idByPhone.get(u.phone)!;
    const rnd = mulberry32(hashStr(u.phone + "sunnahlife"));
    const category = u.category ?? "general";
    for (const dateStr of dates) {
      const isToday = dateStr === today;
      for (const def of defs) {
        if (!cadenceDue(def, dateStr)) continue;
        const r = rnd();
        // Today: only items whose hour has passed are recorded yet (running day)
        if (isToday) {
          const morningKeys = ["salat_fajr", "adhkar_morning", "tilawat", "durood_100", "istighfar_100", "miswak_5", "dhikr_any", "salat_witr", "tahajjud", "ishraq_salat", "sunnah_muakkadah_12"];
          const eveningKeys = ["salat_dhuhr", "salat_asr", "salat_maghrib", "salat_isha", "adhkar_evening", "post_salat_tasbih", "quran_reading", "dua_private_10min", "muzakara_imani", "help_person", "dawat_15min", "salat_slowly", "avoided_entertainment", "bed_by_1030", "no_sleep_before_ishraq"];
          const nowHour = NOW.getHours();
          const hourOfDef = morningKeys.includes(def.key) ? 7 : eveningKeys.includes(def.key) ? (def.key.startsWith("salat_dhuhr") ? 13 : def.key.startsWith("salat_asr") ? 16 : def.key.startsWith("salat_maghrib") ? 18 : 20) : 21;
          if (nowHour < hourOfDef - 1) continue;
        }
        // every branch assigns or continues before use
        let value: unknown;
        if (def.inputType === "tristate") {
          if (r < u.devout * 0.92) value = rnd() < 0.8 ? "jamaat" : "alone";
          else if (r < u.devout * 0.92 + 0.06) value = "qaza";
          else continue; // missed — no entry
        } else if (def.inputType === "boolean") {
          if (r >= u.devout) continue;
          value = true;
        } else if (def.inputType === "count") {
          const t = targetOf(def, category);
          if (r < u.devout) value = t + Math.floor(rnd() * Math.max(1, t));
          else if (r < u.devout + 0.15) value = Math.max(1, Math.floor(t * (0.3 + rnd() * 0.5)));
          else continue;
        } else if (def.inputType === "quantity") {
          const t = targetOf(def, category);
          if (r < u.devout) value = Math.round((t + rnd() * t) * 10) / 10;
          else if (r < u.devout + 0.12) value = Math.round(t * (0.3 + rnd() * 0.5) * 10) / 10;
          else continue;
        } else {
          continue; // text inputs are user-authored, not seeded
        }
        // auto-source story: product 1 feeds product 2
        let source = "manual";
        if (def.autoSource && rnd() < 0.45) source = def.autoSource;
        const hour = 5 + Math.floor(rnd() * 18);
        const clientUpdatedAt = isToday
          ? new Date(Math.min(NOW.getTime() - 3600_000, parseKey(dateStr).getTime() + hour * 3600_000))
          : new Date(parseKey(dateStr).getTime() + hour * 3600_000 + Math.floor(rnd() * 3600_000));
        entries.push({
          userId: uid,
          amalKey: def.key,
          date: dateStr,
          hijriDate: hijriIso(parseKey(dateStr)),
          valueJson: value as object,
          source,
          clientUpdatedAt,
        });
      }
    }
  }
  for (let i = 0; i < entries.length; i += 500) {
    await db.amalEntry.createMany({ data: entries.slice(i, i + 500) });
  }
  console.log(`  AmalEntries: ${entries.length} across ${usersWithDiary.length} diaries × ${dates.length} days`);

  // ── 7) Weekly reviews (last 2 completed weeks, real computed summaries) ────
  function summaryFor(uid: string, weekStart: string) {
    const days = Array.from({ length: 7 }, (_, i) => addDays(weekStart, i));
    const elapsed = days.filter((x) => x <= today);
    const wk = entries.filter((e) => e.userId === uid && days.includes(e.date) && dailyDefs.some((dd) => dd.key === e.amalKey));
    const user = usersWithDiary.find((u) => idByPhone.get(u.phone) === uid)!;
    const category = user.category ?? "general";
    let points = 0;
    const byCategory: Record<string, { p: number }> = {};
    const perDay: Record<string, number> = {};
    for (const e of wk) {
      const def = defs.find((dd) => dd.key === e.amalKey)!;
      const v: unknown = e.valueJson;
      let p: number;
      if (def.inputType === "tristate") p = v === "jamaat" || v === "alone" ? 1 : 0;
      else if (def.inputType === "boolean") p = v === true ? 1 : 0;
      else {
        const t = targetOf(def, category);
        const n = typeof v === "number" ? v : 0;
        p = n >= t ? 1 : n > 0 ? 0.5 : 0;
      }
      points += p;
      const bc = (byCategory[def.category] ??= { p: 0 });
      bc.p += p;
      perDay[e.date] = (perDay[e.date] ?? 0) + p;
    }
    const expected = dailyDefs.length * elapsed.length;
    const dayPct = (ds: string) => (dailyDefs.length ? (perDay[ds] ?? 0) / dailyDefs.length : 0);
    let streak = 0;
    for (let i = elapsed.length - 1; i >= 0; i--) {
      if (dayPct(elapsed[i]) >= 0.5) streak++;
      else break;
    }
    return {
      overallPct: expected ? Math.round((points / expected) * 100) : 0,
      byCategory: Object.fromEntries(
        Object.entries(byCategory).map(([k, v]) => [k, expected ? Math.round((v.p / (dailyDefs.filter(x => x.category === k).length * elapsed.length)) * 100) : 0])
      ),
      streak,
      missedDays: elapsed.filter((ds) => dayPct(ds) === 0).length,
    };
  }

  const reviewSpecs: { phone: string; reviewer: string }[] = [
    { phone: "01000000004", reviewer: "01000000003" },
    { phone: "01000000007", reviewer: "01000000003" },
    { phone: "01000000009", reviewer: "01000000003" },
    { phone: "01000000006", reviewer: "01000000005" },
    { phone: "01000000012", reviewer: "01000000005" },
  ];
  const comments = [
    "আলহামদুলিল্লাহ, এই সপ্তাহে নামাজের নিয়মিততা ভালো ছিল। তিলাওয়াতের পরিমাণ আরও বাড়ানোর চেষ্টা করুন।",
    "সকালের আযকার কয়েকদিন বাদ পড়েছে — ফজরের পর একই জায়গায় বসে পড়ার অভ্যাস করুন। বাকি সব মাশাআল্লাহ ঠিক আছে।",
    "দাওয়াতি কাজে অগ্রগতি সন্তোষজনক। আগামী সপ্তাহে অন্তত ৩ জনকে প্রোগ্রামে যুক্ত করার লক্ষ্য রাখুন।",
    "এই সপ্তাহে তাহাজ্জুদে ধারাবাহিকতা কমেছে। রাতে ঘুমের সময় একটু এগিয়ে যাওয়ার পরামর্শ দিচ্ছি।",
    "মাশাআল্লাহ খুব ভালো সপ্তাহ কাটিয়েছেন। পরবর্তী লক্ষ্য: প্রতিদিন অন্তত ১ পারা তিলাওয়াত।",
  ];
  let ci = 0;
  for (const spec of reviewSpecs) {
    for (const back of [7, 14]) {
      const ws = addDays(weekStartOfSafe(NOW), -back);
      const uid = idByPhone.get(spec.phone)!;
      await db.weeklyReview.create({
        data: {
          userId: uid,
          reviewerId: idByPhone.get(spec.reviewer)!,
          weekStart: ws,
          summaryJson: summaryFor(uid, ws),
          comment: comments[ci % comments.length],
          rating: 3 + (ci % 3),
          nextGoals: ci % 2 === 0 ? "তিলাওয়াত দৈনিক ১ পৃষ্ঠা → ২ পৃষ্ঠা" : "সপ্তাহে অন্তত ৩ দিন তাহাজ্জুদ",
          status: "done",
          createdAt: new Date(parseKey(addDays(ws, 7)).getTime() + 7200_000),
          completedAt: new Date(parseKey(addDays(ws, 7)).getTime() + 7200_000),
        },
      });
      ci++;
    }
  }
  console.log(`  WeeklyReviews: ${reviewSpecs.length * 2} (done, computed summaries)`);

  // ── 8) Assessments ────────────────────────────────────────────────────────
  const assessSpecs: { phone: string; assessor: string; strong: boolean; cat: number }[] = [
    { phone: "01000000004", assessor: "01000000003", strong: true, cat: 1 },
    { phone: "01000000006", assessor: "01000000005", strong: true, cat: 1 },
    { phone: "01000000009", assessor: "01000000003", strong: false, cat: 1 },
  ];
  // template criteria come from the SEEDED template (seed:reference owns it)
  const template = await db.assessmentTemplate.findFirst({ where: { key: "farze_ain_v1.1" } });
  if (!template) throw new Error("seed:demo needs seed:reference first (farze_ain_v1.1 missing)");
  const allCriteria = (
    (template.sectionsJson as {
      sections?: { key: string; criteria: { key: string }[] }[];
    }).sections ?? (template.sectionsJson as unknown as { key: string; criteria: { key: string }[] }[])
  ).flatMap((s) => s.criteria.map((c) => ({ section: s.key, key: c.key })));
  const assessmentIds: string[] = [];
  for (const a of assessSpecs) {
    const rnd = mulberry32(hashStr(a.phone + "assess"));
    const scores: Record<string, { score: number; comment?: string }> = {};
    for (const c of allCriteria) {
      const r = rnd();
      scores[c.key] = { score: a.strong ? (r < 0.15 ? 1 : 2) : r < 0.5 ? 1 : r < 0.7 ? 0 : 1 };
    }
    // majority-complete-per-section rule (same as API): every section needs >50% criteria ≥1
    let passed = true;
    if (a.strong) {
      for (const c of allCriteria) if (scores[c.key].score === 0) scores[c.key].score = 1;
    } else {
      // deliberately fail akhlaq: set half its criteria to 0 → “not_yet”
      const akhlaqKeys = allCriteria.filter((c) => c.section === "akhlaq").map((c) => c.key);
      akhlaqKeys.slice(0, Math.ceil(akhlaqKeys.length / 2)).forEach((k) => (scores[k].score = 0));
      passed = false;
    }
    const created = await db.assessment.create({
      data: {
        templateKey: "farze_ain_v1.1",
        assesseeId: idByPhone.get(a.phone)!,
        assessorId: idByPhone.get(a.assessor)!,
        participantCategory: a.cat,
        scoresJson: scores,
        overallComment: a.strong
          ? "আলহামদুলিল্লাহ, সামগ্রিকভাবে সন্তোষজনক। কিছু ক্ষেত্রে আরও গভীরতা আসলে ভালো হবে।"
          : "আখলাক অংশে উন্নতি দরকার — বিশেষত পর্দা ও মিথ্যা পরিহারে আরও মনোযোগী হতে হবে। ইনশাআল্লাহ পরবর্তী মূল্যায়নে আবার মিলব।",
        assessorSignedAt: d(10),
        // W4i — the two passed rows are historical CONFIRMED results (the
        // signature is the acknowledgment); the not_yet row stays
        // pending_confirmation with no signature, so the demo data honestly
        // showcases the OTP-acknowledge state.
        ...(passed
          ? { status: "confirmed" as const, confirmedAt: d(10, -1), assesseeSignedAt: d(10, -1) }
          : { status: "pending_confirmation" as const, assesseeSignedAt: null }),
        result: passed ? "passed" : "not_yet",
        createdAt: d(10, 1),
      },
    });
    assessmentIds.push(created.id);
  }
  console.log(`  Assessments: ${assessmentIds.length}`);

  // ── 9) Level transitions + audit ──────────────────────────────────────────
  const ltSpecs: { phone: string; from: string; to: string; days: number; evidence?: object }[] = [
    { phone: "01000000003", from: "muhibbus_sunnah", to: "farze_ain_1", days: 400 },
    { phone: "01000000005", from: "muhibbus_sunnah", to: "farze_ain_1", days: 380 },
    { phone: "01000000004", from: "none", to: "muhibbus_sunnah", days: 150, evidence: { monthsInLevel: 5, referralsAtLevel: 3 } },
    { phone: "01000000006", from: "none", to: "muhibbus_sunnah", days: 148, evidence: { monthsInLevel: 5, referralsAtLevel: 3 } },
    { phone: "01000000009", from: "none", to: "muhibbus_sunnah", days: 60, evidence: { monthsInLevel: 2, referralsAtLevel: 1 } },
    { phone: "01000000013", from: "none", to: "muhibbus_sunnah", days: 90, evidence: { monthsInLevel: 3, referralsAtLevel: 1 } },
  ];
  for (const lt of ltSpecs) {
    await db.levelTransition.create({
      data: {
        userId: idByPhone.get(lt.phone)!,
        fromLevel: lt.from,
        toLevel: lt.to,
        at: d(lt.days),
        evidenceJson: lt.evidence ?? {},
      },
    });
    await db.auditLog.create({
      data: {
        actorId: idByPhone.get("01000000001")!,
        action: "promote_level",
        targetType: "user",
        targetId: idByPhone.get(lt.phone)!,
        metaJson: { from: lt.from, to: lt.to },
        createdAt: d(lt.days),
      },
    });
  }

  // ── 10) Live programs ─────────────────────────────────────────────────────
  await db.liveProgram.createMany({
    data: [
      {
        titleBn: "সাপ্তাহিক তাফসীর মজলিস — সূরা কাহফ",
        descBn: "শুক্রবারের তাফসীর সেশন। সূরা কাহফের শিক্ষা ও বাস্তব প্রয়োগ।",
        hostName: "মাওলানা ইউসুফ",
        startsAt: new Date(NOW.getTime() - 30 * 60_000),
        endsAt: new Date(NOW.getTime() + 90 * 60_000),
        youtubeId: "jfKfPfyJRdk",
        gender: "M",
        status: "live",
      },
      {
        titleBn: "ঈমানের শাখা-প্রশাখা — পর্ব ১২",
        descBn: "৭০টি ঈমানের শাখা নিয়ে ধারাবাহিক আলোচনা।",
        hostName: "হাফেজ যাকারিয়া",
        startsAt: new Date(NOW.getTime() + 2 * 86400_000),
        endsAt: new Date(NOW.getTime() + 2 * 86400_000 + 3600_000),
        gender: "M",
        status: "upcoming",
      },
      {
        // AMOL-17: a scheduled live quiz — the app lists it under আসন্ন কুইজ
        titleBn: "সাপ্তাহিক লাইভ কুইজ — সালাতের মাসায়েল",
        descBn: "উসরার সবাই একসাথে — দশটি প্রশ্ন, ছয় মিনিট।",
        hostName: "মাওলানা ইউসুফ",
        startsAt: new Date(NOW.getTime() + 3 * 86400_000),
        endsAt: new Date(NOW.getTime() + 3 * 86400_000 + 1800_000),
        gender: "M",
        status: "upcoming",
        quizId: "quiz-salah",
      },
      {
        titleBn: "বোনদের তারবিয়াহ সেশন — পর্দা ও চরিত্র",
        descBn: "কেবল বোনদের জন্য। লিঙ্ক শুধু অ্যাপে পাওয়া যাবে।",
        hostName: "উম্মে হাবিবা",
        startsAt: new Date(NOW.getTime() + 86400_000),
        endsAt: new Date(NOW.getTime() + 86400_000 + 3600_000),
        gender: "F",
        status: "upcoming",
      },
      {
        titleBn: "সুন্নাহ লাইফ পরিচিতি ও প্রশ্নোত্তর",
        descBn: "প্ল্যাটফর্মের ব্যবহার ও তারবিয়াহ প্রোগ্রাম নিয়ে বিস্তারিত।",
        hostName: "আব্দুল্লাহ আল মামুন",
        startsAt: new Date(NOW.getTime() - 3 * 86400_000),
        endsAt: new Date(NOW.getTime() - 3 * 86400_000 + 5400_000),
        youtubeId: "aqz-KE-bpKQ",
        gender: "M",
        status: "past",
        recordingUrl: "https://www.youtube.com/embed/aqz-KE-bpKQ",
      },
    ],
  });
  console.log("  LivePrograms: 5 (1 live, 3 upcoming incl. 1 quiz, 1 past)");

  // ── 11) Announcements (usrah-scoped) ───────────────────────────────────────
  await db.announcement.createMany({
    data: [
      {
        usrahId: furqan.id,
        authorId: idByPhone.get("01000000003")!,
        kind: "announcement",
        body: "📢 আগামী শুক্রবার বাদ ইশা উসরার সাপ্তাহিক মজলিস অনুষ্ঠিত হবে ইনশাআল্লাহ। সবাইকে যথাসময়ে উপস্থিত থাকার অনুরোধ রইল।",
        pinned: true,
        createdAt: d(2),
      },
      {
        usrahId: furqan.id,
        authorId: idByPhone.get("01000000003")!,
        kind: "question",
        body: "এই সপ্তাহের উসরা প্রশ্ন: “ইখলাস কী এবং আমলে ইখলাস কীভাবে অর্জন করা যায়?” — নিজের ভাষায় সংক্ষেপে লিখে আনুন।",
        createdAt: d(1),
      },
      {
        usrahId: ayesha.id,
        authorId: idByPhone.get("01000000005")!,
        kind: "announcement",
        body: "🌸 আগামী শনিবার সকাল ১০টায় বোনদের সাপ্তাহিক মুহাসাবা মজলিস। নিজ নিজ ডায়েরি সঙ্গে আনার অনুরোধ রইল।",
        pinned: true,
        createdAt: d(3),
      },
      {
        usrahId: ayesha.id,
        authorId: idByPhone.get("01000000005")!,
        kind: "exam",
        body: "“ঈমানের অপরিহার্য পাঠ” বইয়ের ৩য় অধ্যায় পড়ে আসা — আগামী মজলিসে মৌখিক পরীক্ষা হবে ইনশাআল্লাহ।",
        createdAt: d(2),
      },
    ],
  });

  // ── 12) Reminders ─────────────────────────────────────────────────────────
  await db.reminder.createMany({
    data: [
      {
        userId: idByPhone.get("01000000004")!,
        kind: "review",
        title: "আপনার সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে",
        body: "মাওলানা ইউসুফ আপনার গত সপ্তাহের আমলের রিভিউ সম্পন্ন করেছেন।",
        link: "dawah",
        read: true,
        createdAt: d(2),
      },
      {
        userId: idByPhone.get("01000000006")!,
        kind: "review",
        title: "আপনার সাপ্তাহিক রিভিউ সম্পন্ন হয়েছে",
        body: "উম্মে হাবিবা আপনার গত সপ্তাহের আমলের রিভিউ সম্পন্ন করেছেন।",
        link: "dawah",
        read: true,
        createdAt: d(2),
      },
      {
        userId: idByPhone.get("01000000007")!,
        kind: "live",
        title: "লাইভ প্রোগ্রাম শুরু হয়েছে",
        body: "সাপ্তাহিক তাফসীর মজলিস এখন লাইভ।",
        link: "ilm",
        read: false,
        createdAt: new Date(NOW.getTime() - 1800_000),
      },
      {
        userId: idByPhone.get("01000000004")!,
        kind: "broadcast",
        title: "নতুন মাসের মুহাসাবা ডায়েরি চালু",
        body: "এই মাসের ডায়েরি পূরণ শুরু করুন — প্রতিদিনের হিসাব রাখুন।",
        link: "amal",
        read: false,
        createdAt: d(5),
      },
      {
        userId: idByPhone.get("01000000004")!,
        kind: "goal",
        title: "আজকের ব্যক্তিগত লক্ষ্য মনে করিয়ে দিচ্ছি",
        body: "তাহাজ্জুদ — আজ রাতে জাগার নিয়ত করুন।",
        link: "amal",
        scheduledAt: new Date(NOW.getTime() + 3600_000),
        read: false,
        createdAt: d(0, 2),
      },
    ],
  });

  // ── 13) Personal goals + a demo day-unlock + audit ────────────────────────
  await db.personalGoal.createMany({
    data: [
      {
        userId: idByPhone.get("01000000004")!,
        amalKey: "tahajjud",
        title: "তাহাজ্জুদ নিয়মিত করা",
        note: "রিভিউয়ারের পরামর্শ: এশার পর তাড়াতাড়ি ঘুমানো শুরু করুন।",
        target: "সপ্তাহে অন্তত ৪ দিন",
        startDate: addDays(today, -20),
        active: true,
      },
      {
        userId: idByPhone.get("01000000004")!,
        amalKey: "dua_private_10min",
        title: "মুনাজাতে ১০ মিনিট",
        note: "তাহাজ্জুদের আগে মুনাজাতের সয় রাখুন।",
        target: "প্রতিদিন",
        startDate: addDays(today, -20),
        active: true,
      },
      {
        userId: idByPhone.get("01000000006")!,
        amalKey: "tilawat",
        title: "প্রতিদিন ১ পৃষ্ঠা → ২ পৃষ্ঠা",
        note: "ফজরের পরপরই তিলাওয়াত করার অভ্যাস গড়ুন।",
        target: "দৈনিক ২ পৃষ্ঠা",
        startDate: addDays(today, -15),
        active: true,
      },
    ],
  });
  await db.dayUnlock.create({
    data: {
      userId: idByPhone.get("01000000008")!,
      date: addDays(today, -3),
      byUserId: idByPhone.get("01000000003")!,
      reason: "অসুস্থ ছিলেন — পরে পূরণ করবেন",
      createdAt: d(2),
    },
  });
  await db.auditLog.createMany({
    data: [
      {
        actorId: idByPhone.get("01000000003")!,
        action: "unlock_day",
        targetType: "amal_day",
        targetId: `${idByPhone.get("01000000008")!}:${addDays(today, -3)}`,
        metaJson: { reason: "অসুস্থ ছিলেন" },
        createdAt: d(2),
      },
      {
        actorId: idByPhone.get("01000000001")!,
        action: "change_role",
        targetType: "user",
        targetId: idByPhone.get("01000000009")!,
        metaJson: { from: "user", to: "daee" },
        createdAt: d(60),
      },
      {
        actorId: idByPhone.get("01000000003")!,
        action: "sign_assessment",
        targetType: "assessment",
        targetId: assessmentIds[0],
        metaJson: { assessor: true },
        createdAt: d(10),
      },
    ],
  });

  // ── done ──────────────────────────────────────────────────────────────────
  return { skipped: false };
}
