"use client";

// ঘোষণা পাঠান — who can hear whom, said plainly:
//   • প্রধান অ্যাডমিন: everyone in the app (guests too — it shows in the app's
//     notification bell under "ফাউন্ডেশন"), only brothers, only sisters, or
//     one usrah;
//   • উসরা প্রধান / পরিদর্শক: their own usrah, or everyone of their own
//     gender in their scope (the API refuses anything wider).
// Below: what the Foundation has announced recently, and the admin's own
// notifications.

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Bell, Megaphone, Send } from "lucide-react";
import { api, type Gender } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { isFullAdmin, isSupervisor } from "@/lib/labels";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, Select, Textarea } from "@/components/ui/input";
import { EmptyState, PageHeading } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

const KIND_LABELS_BN: Record<string, string> = {
  announcement: "ঘোষণা",
  review_reminder: "রিভিউ",
  live_start: "লাইভ",
  question: "উসরার প্রশ্ন",
  goal_reminder: "লক্ষ্য",
  masala: "মাসআলা",
  system: "সিস্টেম",
};

type Audience = "all" | "M" | "F" | "usrah" | "own_usrah" | "own_gender";

interface AudienceOption {
  value: Audience;
  label: string;
  /** who receives it and where it shows — the line under the choices */
  note: string;
}

export default function BroadcastPage() {
  const { user } = useSession();
  const { toast } = useToast();
  const qc = useQueryClient();
  const fullAdmin = isFullAdmin(user?.role);
  const supervisor = isSupervisor(user?.role);

  const myUsrah = useQuery({ queryKey: ["my-usrah"], queryFn: () => api.myUsrah(), enabled: supervisor && !fullAdmin });
  const overview = useQuery({ queryKey: ["admin-overview"], queryFn: () => api.overview(), enabled: fullAdmin });
  const reminders = useQuery({ queryKey: ["reminders"], queryFn: () => api.reminders(), enabled: !!user });
  const sent = useQuery({ queryKey: ["public-announcements"], queryFn: () => api.publicAnnouncements(), enabled: fullAdmin });

  const ownUsrah = myUsrah.data?.usrah ?? null;
  const ownGender = user?.gender === "F" ? "বোনেরা" : "ভাইয়েরা";

  const options: AudienceOption[] = fullAdmin
    ? [
        { value: "all", label: "সবাই", note: "অ্যাপের সবাই পাবেন — অতিথিরাও। অ্যাপের ঘণ্টায় “ফাউন্ডেশন” অংশে দেখাবে।" },
        { value: "M", label: "শুধু ভাইয়েরা", note: "শুধু ভাইদের অ্যাপে যাবে।" },
        { value: "F", label: "শুধু বোনেরা", note: "শুধু বোনদের অ্যাপে যাবে।" },
        { value: "usrah", label: "একটি উসরা", note: "শুধু বেছে নেওয়া উসরার সদস্যরা পাবেন — উসরা ট্যাবে দেখাবে।" },
      ]
    : [
        ...(ownUsrah
          ? [{ value: "own_usrah" as const, label: `আমার উসরা (${ownUsrah.name})`, note: "আপনার উসরার সদস্যরা পাবেন — উসরা ট্যাবে দেখাবে।" }]
          : []),
        { value: "own_gender", label: `আমার পরিসরের ${ownGender}`, note: `আপনার তত্ত্বাবধানের সব ${ownGender} পাবেন।` },
      ];

  const [audience, setAudience] = React.useState<Audience | null>(null);
  const chosen = options.find((o) => o.value === audience) ?? options[0];
  const [usrahId, setUsrahId] = React.useState("");
  const [body, setBody] = React.useState("");

  const send = useMutation({
    mutationFn: () => {
      const dto: { usrahId?: string | null; gender?: Gender | null; body: string } = { body: body.trim() };
      switch (chosen.value) {
        case "M":
        case "F":
          dto.gender = chosen.value;
          break;
        case "usrah":
          dto.usrahId = usrahId;
          break;
        case "own_usrah":
          dto.usrahId = ownUsrah?.id ?? null;
          break;
        case "own_gender":
          dto.gender = (user?.gender as Gender) ?? null;
          break;
        default:
          break; // "all": no usrah, no gender
      }
      return api.broadcast(dto);
    },
    onSuccess: () => {
      toast("ঘোষণা পাঠানো হয়েছে", "success");
      setBody("");
      qc.invalidateQueries({ queryKey: ["reminders"] });
      qc.invalidateQueries({ queryKey: ["public-announcements"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const needsUsrah = chosen?.value === "usrah" && !usrahId;
  const canSend = supervisor && !!chosen && body.trim().length > 3 && !needsUsrah && !send.isPending;
  const unread = (reminders.data?.reminders ?? []).filter((r) => !r.read).length;

  return (
    <div className="space-y-6">
      <PageHeading
        icon={<Megaphone className="h-6 w-6" aria-hidden />}
        title="ঘোষণা পাঠান"
        description="অ্যাপের সদস্যদের কাছে ঘোষণা পাঠান — নোটিফিকেশন হিসেবে পৌঁছাবে।"
      />

      {supervisor && chosen ? (
        <Card>
          <CardHeader>
            <CardTitle>নতুন ঘোষণা</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <Field label="কারা পাবেন">
              <div className="flex flex-wrap gap-2" role="radiogroup" aria-label="কারা পাবেন">
                {options.map((o) => (
                  <button
                    key={o.value}
                    type="button"
                    role="radio"
                    aria-checked={chosen.value === o.value}
                    onClick={() => setAudience(o.value)}
                    className={`min-h-11 rounded-lg border px-4 text-sm font-semibold transition-colors ${
                      chosen.value === o.value
                        ? "border-primary bg-primary text-primary-foreground"
                        : "border-border bg-card text-foreground hover:bg-primary-soft/50"
                    }`}
                  >
                    {o.label}
                  </button>
                ))}
              </div>
              <p className="mt-2 text-sm text-muted-foreground">{chosen.note}</p>
            </Field>
            {chosen.value === "usrah" ? (
              <Field label="উসরা" htmlFor="bc-usrah">
                <Select id="bc-usrah" value={usrahId} onChange={(e) => setUsrahId(e.target.value)}>
                  <option value="">— উসরা বেছে নিন —</option>
                  {(overview.data?.usrahs ?? []).map((u) => (
                    <option key={u.id} value={u.id}>
                      {u.name} ({u.gender === "F" ? "বোন" : "ভাই"} · {toBn(u.members)} সদস্য)
                    </option>
                  ))}
                </Select>
              </Field>
            ) : null}
            <Field label="বার্তা" hint={`${toBn(body.length)} অক্ষর — সংক্ষিপ্ত ও স্পষ্ট রাখুন`}>
              <Textarea
                rows={4}
                value={body}
                onChange={(e) => setBody(e.target.value)}
                placeholder="যেমন: আগামী শুক্রবার বাদ জুমা মজলিস ইনশাআল্লাহ…"
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
            <p className="text-sm text-muted-foreground">ঘোষণা পাঠাতে পারেন উসরা প্রধান, পরিদর্শক ও প্রধান অ্যাডমিন।</p>
          </CardContent>
        </Card>
      )}

      {fullAdmin ? (
        <Card>
          <CardHeader>
            <CardTitle>ফাউন্ডেশনের সাম্প্রতিক ঘোষণা</CardTitle>
            <CardDescription>যেগুলো অ্যাপের ঘণ্টায় সবাই দেখছেন</CardDescription>
          </CardHeader>
          <CardContent>
            {sent.isLoading ? (
              <p className="py-6 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
            ) : (sent.data?.announcements.length ?? 0) === 0 ? (
              <EmptyState title="এখনো কোনো ঘোষণা নেই" hint="উপরের ফর্ম থেকে প্রথম ঘোষণাটি পাঠান।" />
            ) : (
              <ul className="divide-y divide-border">
                {sent.data!.announcements.slice(0, 10).map((a) => (
                  <li key={a.id} className="py-3">
                    <p className="whitespace-pre-line text-sm leading-relaxed">{a.body}</p>
                    <p className="mt-1 text-xs text-muted-foreground">
                      {a.authorName ?? "অ্যাডমিন"} · {relativeBn(a.createdAt)}
                    </p>
                  </li>
                ))}
              </ul>
            )}
          </CardContent>
        </Card>
      ) : null}

      <Card>
        <CardHeader className="flex-row items-center justify-between gap-3">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Bell className="h-[18px] w-[18px] text-primary" aria-hidden />
              আমার নোটিফিকেশন
            </CardTitle>
            <CardDescription>রিভিউ, লাইভ, লক্ষ্য ও অন্যান্য রিমাইন্ডার</CardDescription>
          </div>
          {unread > 0 ? <Badge variant="alert">{toBn(unread)}টি নতুন</Badge> : null}
        </CardHeader>
        <CardContent>
          {reminders.isLoading ? (
            <p className="py-8 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
          ) : reminders.error ? (
            <EmptyState title="নোটিফিকেশন আনা যায়নি" hint="আবার চেষ্টা করুন।" />
          ) : (reminders.data?.reminders.length ?? 0) === 0 ? (
            <EmptyState title="কোনো নোটিফিকেশন নেই" hint="নতুন কিছু এলে এখানে দেখাবে।" />
          ) : (
            <ul className="divide-y divide-border">
              {reminders.data!.reminders.map((r) => (
                <li key={r.id} className="flex items-start gap-3 py-3">
                  <span
                    className={`mt-1.5 h-2 w-2 shrink-0 rounded-full ${r.read ? "bg-border" : "bg-gold"}`}
                    aria-label={r.read ? "পড়া হয়েছে" : "নতুন"}
                  />
                  <div className="min-w-0 flex-1">
                    <div className="flex flex-wrap items-center gap-2">
                      <span className={`text-sm ${r.read ? "font-medium" : "font-bold"}`}>{r.title}</span>
                      <Badge variant="outline">{KIND_LABELS_BN[r.kind] ?? "নোটিফিকেশন"}</Badge>
                    </div>
                    {r.body ? <p className="mt-0.5 text-sm leading-relaxed text-muted-foreground">{r.body}</p> : null}
                    <p className="mt-1 text-xs text-muted-foreground">{dateTimeBn(r.scheduledAt ?? r.createdAt)}</p>
                  </div>
                </li>
              ))}
            </ul>
          )}
        </CardContent>
      </Card>
    </div>
  );
}
