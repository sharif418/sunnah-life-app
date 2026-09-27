import { Logger } from "@nestjs/common";
import { Processor, WorkerHost } from "@nestjs/bullmq";
import type { Job } from "bullmq";
import { QUEUES } from "../queue.constants";
import { RlsService } from "../../common/rls.service";
import { BD_TZ_HOURS, DHAKA_LAT, DHAKA_LNG } from "../../shared/amal";
import { PRAYER_LABELS_BN, type PrayerKey } from "../../shared/domain";
import { computePrayerTimes } from "../../shared/prayer-times";
import { addDays } from "../../shared/calendars";

const FARZ: PrayerKey[] = ["fajr", "dhuhr", "asr", "maghrib", "isha"];

/**
 * prayer-push — nightly 00:05 BD.
 * For each user with lat/lng compute the NEXT day's waqt times with the
 * shared prayer engine and store one Reminder per farz prayer (kind=prayer,
 * scheduledAt = local wall time). FCM delivery is the documented seam:
 * a push-transport adapter would consume these Reminder rows.
 *
 * Idempotent per (user, day): existing prayer reminders for that day are
 * replaced before inserting.
 */
@Processor(QUEUES.PRAYER_PUSH)
export class PrayerPushProcessor extends WorkerHost {
  private readonly logger = new Logger(PrayerPushProcessor.name);

  constructor(private readonly rls: RlsService) {
    super();
  }

  async process(_job: Job): Promise<{ users: number; reminders: number }> {
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

      await this.rls.system(async (tx) => {
        // idempotency: replace this user's prayer reminders for the target day
        await tx.reminder.deleteMany({
          where: { userId: u.id, kind: "prayer", scheduledAt: { gte: dayStart, lte: dayEnd } },
        });
        await tx.reminder.createMany({
          data: FARZ.map((key) => {
            const minutes = Math.round(times[key]);
            const scheduledAt = new Date(dayStart.getTime() + minutes * 60_000); // BD wall clock stored as UTC-shifted instant
            return {
              userId: u.id,
              kind: "prayer",
              title: `${PRAYER_LABELS_BN[key]} ওয়াক্ত`,
              body: `${PRAYER_LABELS_BN[key]} নামাজের সময় হয়েছে — মাসনূন আমলের জন্য অ্যাপ খুলুন`,
              link: "home",
              scheduledAt,
            };
          }),
        });
      });
      created += FARZ.length;
      this.logger.log(
        `prayer-push ${tomorrow} user ${u.id.slice(0, 6)}… fajr ${Math.round(times.fajr)}m isha ${Math.round(times.isha)}m (+5 reminders)`
      );
    }

    this.logger.log(`prayer-push complete: ${users.length} users × ${FARZ.length} = ${created} reminders for ${tomorrow}`);
    return { users: users.length, reminders: created };
  }
}
