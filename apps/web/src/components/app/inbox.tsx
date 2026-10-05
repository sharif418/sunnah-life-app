"use client";

// The header bell (mobile parity, NAV-03): one inbox, three sections —
//   • ফাউন্ডেশন: the Foundation's announcements (GET /api/announcements;
//     guests see them too, a sisters-only notice only reaches sisters),
//   • উসরা: my usrah's announcements (GET /api/usrah — plain members too),
//   • আপনার জন্য: messages for me (GET /api/reminders, message kinds whose
//     time has come) — tapping one marks it read and opens where it points.
// The unread dot is fetched on load and every two minutes, not only when
// the sheet opens.

import * as React from "react";
import { Bell, Building2, Megaphone, MessageSquareText } from "lucide-react";
import { useApp, type Tab } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { api } from "@/lib/api";
import type { Announcement, Lang, ReminderItem } from "@/types/domain";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import { cn } from "@/lib/utils";
import { formatTime, toBn } from "@/lib/calendars";

/** The reminder kinds that are messages for the member (mobile kInboxKinds). */
const INBOX_KINDS = new Set(["review", "goal", "assessment", "broadcast", "masala", "unlock_request"]);

const LOCALES: Record<Lang, string> = { bn: "bn-BD", en: "en-GB", ar: "ar" };

/** "৪ অক্টোবর · রাত ১০:২০" — the app's own Bengali day-part time, not the
 * browser's "এ ১০:২০ PM". */
function when(iso: string, lang: Lang): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const day = new Intl.DateTimeFormat(LOCALES[lang] ?? "bn-BD", { day: "numeric", month: "long" }).format(d);
  return `${day} · ${formatTime(d.getHours() * 60 + d.getMinutes(), lang)}`;
}

/** A reminder's link ("dawah", "assessment", "/more/masala") → a web tab/view. */
function target(link: string | null): { tab: Tab; view?: string } | null {
  if (!link) return null;
  const [head, view] = link.replace(/^\/+/, "").split("/");
  switch (head) {
    case "home":
    case "amal":
    case "dawah":
    case "ilm":
    case "more":
      return { tab: head, view };
    case "assessment":
    case "reviews":
    case "usrah":
      return { tab: "dawah" };
    default:
      return null;
  }
}

function inboxOf(reminders: ReminderItem[]): ReminderItem[] {
  const now = Date.now();
  return reminders
    .filter((r) => INBOX_KINDS.has(r.kind) && (!r.scheduledAt || new Date(r.scheduledAt).getTime() <= now))
    .sort((a, b) => b.createdAt.localeCompare(a.createdAt));
}

export function NotificationsInbox({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { user, profile, nav } = useApp();
  const lang = profile.language;
  const t = (k: string) => translate(lang, k);

  const [mine, setMine] = React.useState<ReminderItem[] | null>(null);
  const [foundation, setFoundation] = React.useState<Announcement[] | null>(null);
  const [usrah, setUsrah] = React.useState<Announcement[] | null>(null);
  const [loading, setLoading] = React.useState(false);

  // the unread dot: on load and every two minutes while signed in
  const loadMine = React.useCallback(() => {
    if (!user) {
      setMine(null);
      return Promise.resolve();
    }
    return api
      .reminders()
      .then((r) => setMine(inboxOf(r.reminders)))
      .catch(() => setMine((m) => m ?? []));
  }, [user]);

  React.useEffect(() => {
    void loadMine();
    if (!user) return;
    const id = window.setInterval(() => void loadMine(), 120_000);
    return () => window.clearInterval(id);
  }, [user, loadMine]);

  React.useEffect(() => {
    if (!open) return;
    setLoading(true);
    Promise.all([
      api
        .announcements()
        .then((r) => setFoundation(r.announcements))
        .catch(() => setFoundation([])),
      user?.usrahId
        ? api
            .usrah()
            .then((r) => setUsrah(r.announcements.slice(0, 10)))
            .catch(() => setUsrah([]))
        : Promise.resolve(setUsrah(null)),
      loadMine(),
    ]).finally(() => setLoading(false));
  }, [open, user, loadMine]);

  const unread = mine?.filter((r) => !r.read).length ?? 0;
  // an announcement already shows in its own section (ফাউন্ডেশন / উসরা): its
  // "broadcast" message only lights the dot, and opening the bell reads it
  const forYou = mine?.filter((r) => r.kind !== "broadcast") ?? null;

  React.useEffect(() => {
    if (!open || !mine) return;
    const seen = mine.filter((r) => r.kind === "broadcast" && !r.read);
    if (seen.length === 0) return;
    setMine((list) => list?.map((x) => (x.kind === "broadcast" ? { ...x, read: true } : x)) ?? null);
    for (const r of seen) api.readReminder(r.id).catch(() => undefined);
  }, [open, mine]);

  const openMessage = async (r: ReminderItem) => {
    if (!r.read) {
      setMine((list) => list?.map((x) => (x.id === r.id ? { ...x, read: true } : x)) ?? null);
      api.readReminder(r.id).catch(() => undefined);
    }
    const to = target(r.link);
    if (to) {
      onOpenChange(false);
      nav(to.tab, to.view);
    }
  };

  const empty =
    !loading && (foundation?.length ?? 0) === 0 && (usrah?.length ?? 0) === 0 && (forYou?.length ?? 0) === 0;

  return (
    <>
      <button
        aria-label={
          unread > 0
            ? `${t("header.notifications")} — ${lang === "bn" ? toBn(unread) : unread} ${t("inbox.new")}`
            : t("header.notifications")
        }
        className="tap-target relative inline-flex size-9 items-center justify-center rounded-full text-primary-foreground/85 hover:bg-primary-foreground/10 transition-colors"
        onClick={() => onOpenChange(true)}
      >
        <Bell className="size-4" />
        {unread > 0 && <span className="absolute top-1.5 end-1.5 size-2 rounded-full bg-alert ring-2 ring-primary" />}
      </button>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>{t("header.notifications")}</SheetTitle>
          </SheetHeader>
          <div className="max-h-[70vh] space-y-5 overflow-y-auto px-4 pb-6 scroll-thin">
            {loading && !foundation ? (
              <div className="space-y-2 py-2">
                {[0, 1, 2].map((i) => (
                  <div key={i} className="h-16 animate-pulse rounded-xl bg-muted" />
                ))}
              </div>
            ) : null}

            {forYou && forYou.length > 0 ? (
              <section aria-label={t("inbox.forYou")} className="space-y-2">
                <h3 className="flex items-center gap-2 text-sm font-bold text-primary">
                  <MessageSquareText className="size-4" /> {t("inbox.forYou")}
                </h3>
                {forYou.slice(0, 20).map((r) => (
                  <button
                    key={r.id}
                    onClick={() => openMessage(r)}
                    className={cn(
                      "block w-full rounded-xl border p-3.5 text-start transition-colors hover:bg-muted/60",
                      r.read ? "border-border bg-card" : "border-primary/30 bg-primary-soft"
                    )}
                  >
                    <div className="flex items-start justify-between gap-2">
                      <p className={cn("text-sm", r.read ? "font-medium" : "font-bold")}>{r.title}</p>
                      {!r.read && <span className="mt-1.5 size-2 shrink-0 rounded-full bg-primary" aria-label={t("inbox.new")} />}
                    </div>
                    {r.body && <p className="mt-1 line-clamp-3 text-sm leading-relaxed text-muted-foreground">{r.body}</p>}
                    <p className="mt-1 text-xs text-muted-foreground">{when(r.createdAt, lang)}</p>
                  </button>
                ))}
              </section>
            ) : null}

            {foundation && foundation.length > 0 ? (
              <section aria-label={t("inbox.foundation")} className="space-y-2">
                <h3 className="flex items-center gap-2 text-sm font-bold text-primary">
                  <Building2 className="size-4" /> {t("inbox.foundation")}
                </h3>
                {foundation.slice(0, 10).map((a) => (
                  <div key={a.id} className="rounded-xl border border-border bg-card p-3.5">
                    <p className="whitespace-pre-line text-sm leading-relaxed">{a.body}</p>
                    <p className="mt-1 text-xs text-muted-foreground">{when(a.createdAt, lang)}</p>
                  </div>
                ))}
              </section>
            ) : null}

            {usrah && usrah.length > 0 ? (
              <section aria-label={t("inbox.usrah")} className="space-y-2">
                <h3 className="flex items-center gap-2 text-sm font-bold text-primary">
                  <Megaphone className="size-4" /> {t("inbox.usrah")}
                </h3>
                {usrah.map((a) => (
                  <div key={a.id} className="rounded-xl border border-border bg-card p-3.5">
                    <p className="whitespace-pre-line text-sm leading-relaxed">{a.body}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {[a.authorName, when(a.createdAt, lang)].filter(Boolean).join(" · ")}
                    </p>
                  </div>
                ))}
              </section>
            ) : null}

            {empty ? (
              <div className="py-10 text-center">
                <div className="mx-auto flex size-16 items-center justify-center rounded-full bg-primary-soft">
                  <Bell className="size-7 text-primary/50" />
                </div>
                <p className="mt-3 text-sm text-muted-foreground">{t("header.noReminders")}</p>
                {!user ? (
                  <p className="mx-auto mt-2 max-w-xs text-xs leading-relaxed text-muted-foreground">{t("header.remindersHint")}</p>
                ) : null}
              </div>
            ) : null}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}
