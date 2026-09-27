import { Logger } from "@nestjs/common";
import { Processor, WorkerHost, InjectQueue } from "@nestjs/bullmq";
import type { Job, Queue } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { PushService } from "../../push/push.service";
import { DEEP_LINKS } from "../../push/deep-links";
import { BD_TZ_HOURS, DHAKA_LAT, DHAKA_LNG } from "../../shared/amal";
import { PRAYER_LABELS_BN, type PrayerKey } from "../../shared/domain";
import { computePrayerTimes } from "../../shared/prayer-times";
import { addDays } from "../../shared/calendars";

const FARZ: PrayerKey[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

/** Payload of a delayed per-waqt push job. */
interface PrayerWaqtJobData {
  userId: string;
  title: string;
  body: string;
}

/**
 * prayer-push — two job shapes in one queue:
 *
 *  • "prayer-push-nightly" (repeatable, 00:05 BD): for each user with lat/lng
 *    compute the NEXT day's waqt times with the shared prayer engine, store
 *    one Reminder per farz prayer (kind=prayer, scheduledAt = local wall
 *    time — the in-app bell + reminder inbox) AND enqueue a DELAYED
 *    "prayer-waqt" job per prayer that fires at the waqt instant and pushes
 *    through PushService (FCM HTTP v1 — real delivery, Task B2).
 *
 *  • "prayer-waqt" (delayed): PushService.send to the single target user.
 *
 * Idempotent per (user, day): existing prayer reminders for that day are
 * replaced before inserting; delayed push jobs carry a deterministic jobId
 * (`prayer-waqt:{userId}:{date}:{waqt}`) so a re-run cannot duplicate them.
 */
@Processor(QUEUES.PRAYER_PUSH)
export class PrayerPushProcessor extends WorkerHost {
  private readonly logger = new Logger(PrayerPushProcessor.name);

  constructor(
    private readonly rls: RlsService,
    private readonly push: PushService,
    @InjectQueue(QUEUES.PRAYER_PUSH) private readonly prayerQueue: Queue
  ) {
    super();
  }

  async process(job: Job): Promise<Record<string, unknown>> {
    if (job.name === "prayer-waqt") {
      return this.pushOneWaqt(job.data as PrayerWaqtJobData);
    }
    return this.scheduledNightly();
  }

  /** Delayed job: push one waqt reminder to one user (now is the waqt time). */
  private async pushOneWaqt(data: PrayerWaqtJobData): Promise<Record<string, unknown>> {
    const outcome = await this.push.send([data.userId], {
      title: data.title,
      body: data.body,
      deepLink: DEEP_LINKS.home,
    });
    if (outcome.failed) {
      this.logger.warn(
        `prayer-waqt push to ${data.userId.slice(0, 6)}… had ${outcome.failed} failure(s)`
      );
    }
    return { userId: data.userId, ...outcome };
  }

  /** Nightly sweep: reminders + delayed push jobs for the whole next day. */
  private async scheduledNightly(): Promise<{ users: number; reminders: number; pushJobs: number }> {
    const nowShifted = Date.now() + BD_TZ_HOURS * 3_600_000;
    const today = new Date(nowShifted).toISOString().slice(0, 10);
    const tomorrow = addDays(today, 1);
    const [y, m, d] = tomorrow.split("-").map(Number);

    const users = await this.rls.system((tx) =>
      tx.user.findMany({
        where: { lat: { not: null }, lng: { not: null } },
        select: { id: true, lat: true, lng: true, calcMethod: true, madhhab: true },
      })
    );

    let created = 0;
    let pushJobs = 0;
    for (const u of users) {
      const times = computePrayerTimes(
        { y, m, d },
        {
          lat: u.lat ?? DHAKA_LAT,
          lng: u.lng ?? DHAKA_LNG,
          tzOffsetHours: BD_TZ_HOURS,
          method: u.calcMethod as "karachi",
          madhhab: u.madhhab as "hanafi",
        }
      );
      const dayStart = new Date(Date.UTC(y, m - 1, d, 0, 0, 0));
      const dayEnd = new Date(Date.UTC(y, m - 1, d, 23, 59, 59));

      const payloads = FARZ.map((key) => {
        const minutes = Math.round(times[key]);
        const scheduledAt = new Date(dayStart.getTime() + minutes * 60_000); // BD wall clock stored as UTC-shifted instant
        return {
          key,
          scheduledAt,
          title: `${PRAYER_LABELS_BN[key]} ওয়াক্ত`,
          body: `${PRAYER_LABELS_BN[key]} নামাজের সময় হয়েছে — মাসনূন আমলের জন্য অ্যাপ খুলুন`,
        };
      });

      await this.rls.system(async (tx) => {
        // idempotency: replace this user's prayer reminders for the target day
        await tx.reminder.deleteMany({
          where: { userId: u.id, kind: "prayer", scheduledAt: { gte: dayStart, lte: dayEnd } },
        });
        await tx.reminder.createMany({
          data: payloads.map((p) => ({
            userId: u.id,
            kind: "prayer",
            title: p.title,
            body: p.body,
            link: "home",
            scheduledAt: p.scheduledAt,
          })),
        });
      });
      created += FARZ.length;

      // delayed FCM jobs — deterministic jobIds make the nightly re-runnable
      for (const p of payloads) {
        const delay = p.scheduledAt.getTime() - Date.now();
        if (delay <= 0) continue;
        await this.prayerQueue.add(
          "prayer-waqt",
          { userId: u.id, title: p.title, body: p.body } satisfies PrayerWaqtJobData,
          {
            jobId: `prayer-waqt:${u.id}:${tomorrow}:${p.key}`,
            delay,
            removeOnComplete: { age: 86_400 },
            removeOnFail: { age: 86_400 },
          }
        );
        pushJobs += 1;
      }

      this.logger.log(
        `prayer-push ${tomorrow} user ${u.id.slice(0, 6)}… fajr ${Math.round(times.fajr)}m isha ${Math.round(times.isha)}m (+5 reminders/pushes)`
      );
    }

    this.logger.log(
      `prayer-push complete: ${users.length} users × ${FARZ.length} = ${created} reminders, ${pushJobs} delayed push jobs for ${tomorrow}`
    );
    return { users: users.length, reminders: created, pushJobs };
  }
}
