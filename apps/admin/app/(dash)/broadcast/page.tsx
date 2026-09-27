"use client";

// ঘোষণা ও রিমাইন্ডার — usrah_head+ broadcast composer (audience: usrah / gender /
// all-in-scope) + the admin's own reminder inbox (usrah questions, review
// reminders, system notifications).

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Megaphone, Pin, Send } from "lucide-react";
import { api, type Gender } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, toBn } from "@/lib/bn";
import { GENDER_LABELS_BN, ROLE_LABELS_BN, isFullAdmin, isSupervisor } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

const KIND_LABELS_BN: Record<string, string> = {
  announcement: "ঘোষণা",
  review_reminder: "রিভিউ রিমাইন্ডার",
  live_start: "লাইভ শুরু",
  question: "উসরা প্রশ্ন",
  goal_reminder: "লক্ষ্য রিমাইন্ডার",
  system: "সিস্টেম",
};

export default function BroadcastPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const fullAdmin = isFullAdmin(user?.role);

  const usrah = useQuery({ queryKey: ["my-usrah"], queryFn: () => api.myUsrah(), enabled: isSupervisor(user?.role) });
  const reminders = useQuery({ queryKey: ["reminders"], queryFn: () => api.reminders(), enabled: !!user });

  const [body, setBody] = React.useState("");
  const [scope, setScope] = React.useState<"usrah" | "gender" | "all">("usrah");

  const send = useMutation({
    mutationFn: () => {
      const gender = user?.gender as Gender | undefined;
      const dto: { usrahId?: string | null; gender?: Gender | null; body: string } = { body: body.trim() };
      if (scope === "usrah") dto.usrahId = usrah.data?.usrah?.id ?? null;
      if (scope === "gender") dto.gender = gender ?? null;
      return api.broadcast(dto);
    },
    onSuccess: () => {
      toast("ঘোষণা পাঠানো হয়েছে", "success");
      setBody("");
      qc.invalidateQueries({ queryKey: ["reminders"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const canSend = isSupervisor(user?.role) && body.trim().length > 3 && !send.isPending;
  const unread = (reminders.data?.reminders ?? []).filter((r) => !r.read).length;

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <div className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary-soft text-primary">
            <Megaphone className="h-6 w-6" aria-hidden />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-foreground md:text-2xl">ঘোষণা ও রিমাইন্ডার</h1>
            <p className="mt-0.5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              উসরার সদস্যদের কাছে ঘোষণা পাঠান, আর নিজের ইনবক্সে সিস্টেম রিমাইন্ডারগুলো দেখুন।
            </p>
          </div>
        </div>
        {unread > 0 ? <Badge variant="alert">{toBn(unread)} টি অপঠিত</Badge> : null}
      </div>

      {isSupervisor(user?.role) ? (
        <Card>
          <CardHeader>
            <CardTitle>নতুন ঘোষণা</CardTitle>
            <CardDescription>
              {fullAdmin
                ? "প্রধান অ্যাডমিন — সব দায়ী ও তত্ত্বাবধায়ক পর্যন্ত পাঠাতে পারেন।"
                : "আপনার এখতিয়ারভুক্ত মানুষের কাছেই যাবে — RLS নিশ্চিত করে।"}
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <Field label="শ্রোতা">
              <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="শ্রোতা নির্বাচন">
                {(
                  [
                    ["usrah", usrah.data?.usrah ? `আমার উসরা (${usrah.data.usrah.name})` : "আমার উসরা"],
                    ["gender", `আমার লিঙ্গ (${user ? GENDER_LABELS_BN[user.gender] : ""})`],
                    ["all", "আমার পরিধির সবাই"],
                  ] as const
                ).map(([value, label]) => (
                  <button
                    key={value}
                    type="button"
                    role="radio"
                    aria-checked={scope === value}
                    onClick={() => setScope(value)}
                    className={`min-h-11 rounded-lg border px-4 text-sm font-semibold transition-colors ${
                      scope === value
                        ? "border-primary bg-primary text-primary-foreground"
                        : "border-border bg-card text-foreground hover:bg-primary-soft/50"
                    }`}
                  >
                    {label}
                  </button>
                ))}
              </div>
            </Field>
            <Field label="বার্তা" hint={`${toBn(body.length)} অক্ষর — সংক্ষিপ্ত ও স্পষ্ট রাখুন`}>
              <Textarea
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="যেমন: আগামী শুক্রবার উসরার বৈঠক সকাল ১০টায়…"
                aria-label="ঘোষণার বার্তা"
              />
            </Field>
            <div className="flex justify-end">
              <Button onClick={() => send.mutate()} disabled={!canSend} loading={send.isPending}>
                <Send className="h-4 w-4" aria-hidden />
                পাঠান
              </Button>
            </div>
          </CardContent>
        </Card>
      ) : (
        <Card>
          <CardContent className="py-6">
            <p className="text-sm text-muted-foreground">
              ঘোষণা পাঠানোর এখতিয়ার শুধু উসরা প্রধান ও তত্ত্বাবধায়কদের ({ROLE_LABELS_BN.usrah_head}+)।
            </p>
          </CardContent>
        </Card>
      )}

      <Card>
        <CardHeader>
          <CardTitle>ইনবক্স — রিমাইন্ডার</CardTitle>
          <CardDescription>রিভিউ, লাইভ, লক্ষ্য ও সিস্টেম রিমাইন্ডার।</CardDescription>
        </CardHeader>
        <CardContent>
          {reminders.isLoading ? (
            <p className="py-8 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
          ) : reminders.error ? (
            <EmptyState title="রিমাইন্ডার আনা যায়নি" hint="আবার চেষ্টা করুন।" />
          ) : (reminders.data?.reminders.length ?? 0) === 0 ? (
            <EmptyState title="ইনবক্স খালি" hint="কোনো নতুন রিমাইন্ডার নেই।" />
          ) : (
            <ul className="divide-y divide-border">
              {reminders.data!.reminders.map((r) => (
                <li key={r.id} className="flex items-start gap-3 py-3">
                  <span
                    className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${r.read ? "bg-border" : "bg-gold"}`}
                    aria-label={r.read ? "পঠিত" : "অপঠিত"}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`text-sm ${r.read ? "font-medium" : "font-bold"}`}>{r.title}</span>
                      <Badge variant="outline">{KIND_LABELS_BN[r.kind] ?? r.kind}</Badge>
                    </div>
                    {r.body ? (
                      <p className="mt-0.5 text-sm leading-relaxed text-muted-foreground">{r.body}</p>
                    ) : null}
                    <p className="mt-1 text-xs text-muted-foreground">
                      {dateTimeBn(r.scheduledAt ?? r.createdAt)}
                    </p>
                  </div>
                  {r.link ? (
                    <a
                      href={r.link}
                      className="text-xs font-semibold text-primary hover:underline"
                      target="_blank"
                      rel="noopener noreferrer"
                    >
                      দেখুন
                    </a>
                  ) : null}
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
