"use client";

// লাইভ সাপোর্ট (W4d, mobile parity): a member's own conversations with the
// support team — open a new one (subject + first message), read a thread,
// reply until the team closes it. Same endpoints as the app.

import * as React from "react";
import { Headset, Loader2, MessageSquarePlus, Send } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { cn } from "@/lib/utils";
import { formatTime, toBn } from "@/lib/calendars";
import type { SupportMessage, SupportThread } from "@/types/domain";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { EmptyState, ErrorRetry, SubShell } from "@/components/more/bits";

const STATUS: Record<string, { label: string; cls: string }> = {
  open: { label: "উত্তরের অপেক্ষায়", cls: "bg-gold-soft text-gold-text-foreground" },
  answered: { label: "উত্তর এসেছে", cls: "bg-primary-soft text-primary" },
  closed: { label: "বন্ধ", cls: "bg-muted text-muted-foreground" },
};

function when(iso: string): string {
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return "";
  const day = new Intl.DateTimeFormat("bn-BD", { day: "numeric", month: "long" }).format(d);
  return `${day} · ${formatTime(d.getHours() * 60 + d.getMinutes(), "bn")}`;
}

export function SupportView() {
  const user = useApp((s) => s.user);
  const setAuthModal = useApp((s) => s.setAuthModal);
  const [threads, setThreads] = React.useState<SupportThread[] | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [openId, setOpenId] = React.useState<string | null>(null);
  const [composing, setComposing] = React.useState(false);

  const load = React.useCallback(() => {
    setError(null);
    api
      .supportThreads()
      .then((r) => setThreads(r.threads))
      .catch((e: Error) => setError(e.message));
  }, []);

  React.useEffect(() => {
    if (user) load();
  }, [user, load]);

  if (!user) {
    return (
      <SubShell title="লাইভ সাপোর্ট">
        <EmptyState
          icon={<Headset className="size-9" />}
          message="সাপোর্টের সাথে কথা বলতে সাইন-ইন করুন"
          hint="আপনার বার্তা ও উত্তর আপনার অ্যাকাউন্টে থাকবে।"
        />
        <div className="flex justify-center">
          <Button className="h-11 rounded-xl" onClick={() => setAuthModal(true)}>
            সাইন ইন
          </Button>
        </div>
      </SubShell>
    );
  }

  if (openId) {
    return (
      <ThreadView
        id={openId}
        onBack={() => {
          setOpenId(null);
          load();
        }}
      />
    );
  }

  return (
    <SubShell title="লাইভ সাপোর্ট">
      <div className="space-y-4">
        <p className="text-sm leading-relaxed text-muted-foreground">
          অ্যাপ, অ্যাকাউন্ট বা উসরা নিয়ে কোনো সমস্যা হলে লিখুন — ফাউন্ডেশনের সাপোর্ট টিম উত্তর দেবে।
        </p>
        {composing ? (
          <NewThreadForm
            onCancel={() => setComposing(false)}
            onCreated={(id) => {
              setComposing(false);
              setOpenId(id);
            }}
          />
        ) : (
          <Button className="h-11 w-full rounded-xl" onClick={() => setComposing(true)}>
            <MessageSquarePlus className="size-4" /> নতুন বার্তা
          </Button>
        )}

        {error ? (
          <ErrorRetry message={error} onRetry={load} />
        ) : threads === null ? (
          <div className="space-y-2">
            {[0, 1].map((i) => (
              <div key={i} className="h-16 animate-pulse rounded-xl bg-muted" />
            ))}
          </div>
        ) : threads.length === 0 ? (
          <EmptyState icon={<Headset className="size-9" />} message="এখনো কোনো আলাপ নেই" />
        ) : (
          <div className="space-y-2">
            {threads.map((t) => (
              <button
                key={t.id}
                onClick={() => setOpenId(t.id)}
                className="block w-full rounded-xl border border-border bg-card p-3.5 text-start shadow-card transition-colors hover:bg-muted/60"
              >
                <div className="flex items-start gap-2">
                  <p className="min-w-0 flex-1 truncate font-semibold">{t.subject}</p>
                  <span className={cn("shrink-0 rounded-full px-2.5 py-0.5 text-xs font-semibold", STATUS[t.status]?.cls)}>
                    {STATUS[t.status]?.label ?? t.status}
                  </span>
                </div>
                {t.lastPreview ? <p className="mt-1 line-clamp-2 text-sm text-muted-foreground">{t.lastPreview}</p> : null}
                <p className="mt-1 flex items-center gap-2 text-xs text-muted-foreground">
                  {t.unreadForUser && t.status !== "closed" ? (
                    <span className="rounded-full bg-primary px-2 py-0.5 font-semibold text-primary-foreground">নতুন উত্তর</span>
                  ) : null}
                  {when(t.updatedAt)}
                </p>
              </button>
            ))}
          </div>
        )}
      </div>
    </SubShell>
  );
}

function NewThreadForm({ onCancel, onCreated }: { onCancel: () => void; onCreated: (id: string) => void }) {
  const [subject, setSubject] = React.useState("");
  const [message, setMessage] = React.useState("");
  const [busy, setBusy] = React.useState(false);

  const submit = async (e: React.FormEvent) => {
    e.preventDefault();
    setBusy(true);
    try {
      const r = await api.supportCreate(subject.trim(), message.trim());
      toast.success("বার্তা পাঠানো হয়েছে");
      onCreated(r.thread.id);
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "পাঠানো যায়নি");
    } finally {
      setBusy(false);
    }
  };

  return (
    <Card className="rounded-xl shadow-card">
      <CardContent className="p-4">
        <form onSubmit={submit} className="space-y-3" aria-label="নতুন সাপোর্ট বার্তা">
          <div className="space-y-1.5">
            <Label htmlFor="sp-subject">বিষয়</Label>
            <Input
              id="sp-subject"
              maxLength={120}
              value={subject}
              onChange={(e) => setSubject(e.target.value)}
              placeholder="যেমন: ডায়েরির একটা দিন খুলছে না"
              required
            />
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="sp-message">বার্তা</Label>
            <Textarea id="sp-message" rows={4} value={message} onChange={(e) => setMessage(e.target.value)} required />
          </div>
          <div className="flex gap-2">
            <Button type="button" variant="ghost" className="flex-1" onClick={onCancel} disabled={busy}>
              বাতিল
            </Button>
            <Button type="submit" className="flex-1" disabled={busy || !subject.trim() || message.trim().length < 2}>
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : <Send aria-hidden />}
              পাঠান
            </Button>
          </div>
        </form>
      </CardContent>
    </Card>
  );
}

function ThreadView({ id, onBack }: { id: string; onBack: () => void }) {
  const [thread, setThread] = React.useState<SupportThread | null>(null);
  const [messages, setMessages] = React.useState<SupportMessage[] | null>(null);
  const [error, setError] = React.useState<string | null>(null);
  const [reply, setReply] = React.useState("");
  const [busy, setBusy] = React.useState(false);

  const load = React.useCallback(() => {
    setError(null);
    api
      .supportThread(id)
      .then((r) => {
        setThread(r.thread);
        setMessages(r.messages);
      })
      .catch((e: Error) => setError(e.message));
  }, [id]);

  React.useEffect(() => {
    load();
    const t = window.setInterval(load, 30_000); // the team's answer appears without a reload
    return () => window.clearInterval(t);
  }, [load]);

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!reply.trim()) return;
    setBusy(true);
    try {
      const r = await api.supportAppend(id, reply.trim());
      setMessages((m) => [...(m ?? []), r.message]);
      setReply("");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "পাঠানো যায়নি");
    } finally {
      setBusy(false);
    }
  };

  const closed = thread?.status === "closed";
  return (
    <div>
      <div className="mb-4 flex items-center gap-2">
        <Button variant="ghost" size="sm" className="h-9 rounded-full" onClick={onBack}>
          ← সব আলাপ
        </Button>
        <h1 className="min-w-0 flex-1 truncate text-lg font-bold">{thread?.subject ?? "লাইভ সাপোর্ট"}</h1>
      </div>
      {error ? (
        <ErrorRetry message={error} onRetry={load} />
      ) : messages === null ? (
        <div className="h-40 animate-pulse rounded-xl bg-muted" />
      ) : (
        <div className="space-y-2">
          {messages.map((m) => (
            <div key={m.id} className={cn("flex", m.isAdmin ? "justify-start" : "justify-end")}>
              <div
                className={cn(
                  "max-w-[85%] rounded-2xl px-3.5 py-2.5 text-sm leading-relaxed",
                  m.isAdmin ? "rounded-bl-md bg-card border border-border" : "rounded-br-md bg-primary text-primary-foreground"
                )}
              >
                {m.isAdmin ? <p className="mb-0.5 text-xs font-semibold text-primary">সাপোর্ট টিম</p> : null}
                <p className="whitespace-pre-line">{m.body}</p>
                <p className={cn("mt-1 text-[11px]", m.isAdmin ? "text-muted-foreground" : "text-primary-foreground/75")}>
                  {when(m.createdAt)}
                </p>
              </div>
            </div>
          ))}
          {closed ? (
            <p className="rounded-xl bg-muted px-4 py-3 text-center text-sm text-muted-foreground">
              এই আলাপটি বন্ধ হয়েছে — নতুন কিছু জানাতে নতুন বার্তা লিখুন।
            </p>
          ) : (
            <form onSubmit={send} className="flex items-end gap-2 pt-2" aria-label="উত্তর লিখুন">
              <Textarea
                rows={2}
                value={reply}
                onChange={(e) => setReply(e.target.value)}
                placeholder="লিখুন…"
                aria-label="বার্তা"
                className="min-h-0 flex-1 rounded-xl"
              />
              <Button type="submit" size="icon" className="size-11 rounded-full" disabled={busy || !reply.trim()} aria-label="পাঠান">
                {busy ? <Loader2 className="animate-spin" /> : <Send />}
              </Button>
            </form>
          )}
          <p className="text-center text-[11px] text-muted-foreground">
            {toBn(messages.length)}টি বার্তা · নতুন উত্তর এলে এখানে নিজে থেকে দেখাবে
          </p>
        </div>
      )}
    </div>
  );
}
