/**
 * DELETE /api/me — a member deletes their own account (Google Play's
 * account-deletion requirement; also offered on the web at /delete-account).
 *
 * What goes: everything that is the member's OWN — diary entries, goals,
 * reviews and assessments OF them, reports, reminders, quiz attempts,
 * questions, feedback, support threads, join requests, referral links,
 * sessions and device tokens — and the identifying profile fields (name,
 * phone, email, Google link, member code, location, workplace).
 *
 * What stays, anonymised: what they did FOR others (reviews they gave,
 * announcements they posted, answers they wrote). Those rows keep pointing
 * at the user row, which now reads "মুছে ফেলা অ্যাকাউন্ট" with no phone,
 * email or social link, so nobody's record breaks and nothing identifies
 * the person. The audit log keeps the deletion itself.
 *
 * A usrah head or invigilator cannot delete themselves while they carry a
 * usrah (members would be left without a head); a full admin neither.
 */
import type { RlsService } from "../common/rls.service";
import type { StorageService } from "../storage/storage.service";
import type { GuardService } from "../common/guard.service";
import type { User } from "../shared/domain";
import { ApiError } from "../common/api-error";

export const DELETED_NAME = "মুছে ফেলা অ্যাকাউন্ট";

export async function deleteOwnAccount(
  deps: { rls: RlsService; storage: StorageService; guard: GuardService },
  user: User
): Promise<{ ok: true }> {
  const { rls, storage, guard } = deps;
  if (user.role === "full_admin") {
    throw new ApiError(409, "প্রধান অ্যাডমিন অ্যাকাউন্ট এভাবে মোছা যায় না — অন্য একজন প্রধান অ্যাডমিনকে বলুন");
  }

  const reportKeys = await rls.system(async (tx) => {
    const carries = await tx.usrah.count({
      where: { OR: [{ headUserId: user.id }, { invigilatorUserId: user.id }] },
    });
    if (carries > 0) {
      throw new ApiError(
        409,
        "আপনি একটি উসরার দায়িত্বে আছেন — আগে অ্যাডমিনকে বলে দায়িত্ব হস্তান্তর করুন, তারপর অ্যাকাউন্ট মুছুন"
      );
    }
    const me = await tx.user.findUnique({ where: { id: user.id }, select: { phone: true } });
    const reports = await tx.monthlyReport.findMany({ where: { userId: user.id }, select: { storageKey: true } });

    // the member's own content
    await tx.session.deleteMany({ where: { userId: user.id } });
    await tx.deviceToken.deleteMany({ where: { userId: user.id } });
    await tx.refreshToken.deleteMany({ where: { userId: user.id } });
    await tx.amalEntry.deleteMany({ where: { userId: user.id } });
    await tx.dayUnlock.deleteMany({ where: { userId: user.id } });
    await tx.personalGoal.deleteMany({ where: { userId: user.id } });
    await tx.monthlyReport.deleteMany({ where: { userId: user.id } });
    await tx.weeklyReview.deleteMany({ where: { userId: user.id } });
    await tx.assessment.deleteMany({ where: { assesseeId: user.id } });
    await tx.levelTransition.deleteMany({ where: { userId: user.id } });
    await tx.reminder.deleteMany({ where: { userId: user.id } });
    await tx.enrollment.deleteMany({ where: { userId: user.id } });
    await tx.quizAttempt.deleteMany({ where: { userId: user.id } });
    await tx.feedback.deleteMany({ where: { userId: user.id } });
    await tx.masalaQuestion.deleteMany({ where: { userId: user.id } });
    await tx.usrahQuestion.deleteMany({ where: { authorId: user.id } });
    const threads = await tx.supportThread.findMany({ where: { userId: user.id }, select: { id: true } });
    if (threads.length) {
      await tx.supportMessage.deleteMany({ where: { threadId: { in: threads.map((t) => t.id) } } });
      await tx.supportThread.deleteMany({ where: { userId: user.id } });
    }
    await tx.usrahJoinRequest.deleteMany({ where: { userId: user.id } });
    await tx.referralClosure.deleteMany({
      where: { OR: [{ ancestorId: user.id }, { descendantId: user.id }] },
    });
    // the people they invited keep their accounts, without the link
    await tx.user.updateMany({ where: { referredById: user.id }, data: { referredById: null } });
    if (me?.phone) await tx.otpCode.deleteMany({ where: { phone: me.phone } });

    // the profile itself: nothing left that identifies the person
    await tx.user.update({
      where: { id: user.id },
      data: {
        name: DELETED_NAME,
        phone: null,
        email: null,
        socialProvider: null,
        socialSub: null,
        photoUrl: null,
        memberCode: null,
        referredById: null,
        usrahId: null,
        role: "user",
        level: "none",
        levelStartedAt: null,
        district: null,
        workplace: null,
        department: null,
        lat: null,
        lng: null,
        city: null,
        deletedAt: new Date(),
      } as never,
    });
    return reports.map((r) => r.storageKey);
  });

  // the stored monthly PDFs, best effort (rows are already gone)
  for (const key of reportKeys) {
    await storage.remove(key).catch(() => undefined);
  }
  await guard.audit(user.id, "delete_account", "user", user.id, {});
  return { ok: true };
}
