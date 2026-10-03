"use client";

// লাইভ প্রোগ্রাম — upcoming/live/past sessions (YouTube unlisted embeds).
// Female-only sessions are visually marked and NEVER carry a public link.
// B6: full_admin can create / edit / delete programs (audited server-side).

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { BellRing, Pencil, Plus, Radio, Trash2, Video } from "lucide-react";
import { api, type Gender, type LiveProgramItem } from "@/lib/api";
import { useSession } from "@/lib/session";
import { dateTimeBn, relativeBn, toBn } from "@/lib/bn";
import { GENDER_LABELS_BN } from "@/lib/labels";
import { GenderBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { EmptyState } from "@/components/ui/states";
import { Tabs, TabsList, TabsPanel, TabsTrigger } from "@/components/ui/tabs";
import { useToast } from "@/components/ui/toast";

function ProgramCard({ p, editable }: { p: LiveProgramItem; editable?: boolean }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const femaleOnly = p.gender === "F";

  const notify = useMutation({
    mutationFn: () => api.notifyLive(p.id),
    onSuccess: () => {
      toast("শুরুর আগে বিজ্ঞপ্তি পাবেন", "success");
      qc.invalidateQueries({ queryKey: ["live"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const del = useMutation({
    mutationFn: () => api.deleteLiveProgram(p.id),
    onSuccess: () => {
      toast("প্রোগ্রাম মুছে ফেলা হয়েছে (অডিট লগড)", "success");
      qc.invalidateQueries({ queryKey: ["live"] });
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  const startsSoon = p.status === "upcoming";

  return (
    <Card className={p.status === "live" ? "border-alert/50 shadow-lifted" : undefined}>
      <CardHeader>
        <CardTitle className="flex flex-wrap items-center gap-2">
          {p.status === "live" ? (
            <span className="inline-flex items-center gap-1.5 rounded-full bg-alert px-2.5 py-0.5 text-xs font-bold text-white">
              <span className="relative flex h-2 w-2">
                <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-white opacity-75" />
                <span className="relative inline-flex h-2 w-2 rounded-full bg-white" />
              </span>
              এখন লাইভ
            </span>
          ) : null}
          <span className="text-base">{p.titleBn}</span>
        </CardTitle>
        <CardDescription className="flex flex-wrap items-center gap-2">
          {p.hostName ? <span>উপস্থাপক: {p.hostName}</span> : null}
          <span>· {dateTimeBn(p.startsAt)}</span>
          {p.endsAt ? <span>(শেষ: {relativeBn(p.endsAt)})</span> : null}
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-3">
        {p.descBn ? <p className="text-sm leading-relaxed text-muted-foreground">{p.descBn}</p> : null}
        <div className="flex flex-wrap items-center gap-2">
          <GenderBadge gender={p.gender} />
          {femaleOnly ? (
            <Badge variant="gold">শুধুমাত্র নারীদের সেশন — প্রকাশ্য লিংক নেই</Badge>
          ) : null}
          {p.quizId ? <Badge variant="outline">লাইভ কুইজ</Badge> : null}
          {p.youtubeId && !femaleOnly && p.status !== "upcoming" ? (
            <Badge variant="outline">YouTube (unlisted)</Badge>
          ) : null}
        </div>
        <div className="flex flex-wrap gap-2">
          {p.status === "live" && p.youtubeId && !femaleOnly ? (
            <Button size="sm" onClick={() => window.open(`https://youtube.com/watch?v=${p.youtubeId}`, "_blank", "noopener")}>
              <Video className="h-4 w-4" aria-hidden />
              দেখুন
            </Button>
          ) : null}
          {startsSoon ? (
            <Button size="sm" variant="outline" onClick={() => notify.mutate()} disabled={notify.isPending}>
              <BellRing className="h-4 w-4" aria-hidden />
              {notify.isPending ? "…" : "আমাকে জানান"}
            </Button>
          ) : null}
          {editable ? (
            <>
              <Button
                size="sm"
                variant="outline"
                onClick={() => window.dispatchEvent(new CustomEvent("sl-edit-live", { detail: p }))}
              >
                <Pencil className="h-4 w-4" aria-hidden />
                সম্পাদনা
              </Button>
              <Button
                size="sm"
                variant="ghost"
                aria-label={`${p.titleBn} মুছুন`}
                disabled={del.isPending}
                onClick={() => {
                  if (window.confirm(`${p.titleBn} — প্রোগ্রামটি মুছে ফেলবেন?`)) del.mutate();
                }}
              >
                <Trash2 className="h-4 w-4 text-alert" aria-hidden />
              </Button>
            </>
          ) : null}
          {p.recordingUrl ? (
            <a
              href={p.recordingUrl}
              target="_blank"
              rel="noopener noreferrer"
              className="inline-flex h-9 items-center rounded-lg border border-border px-3 text-sm font-semibold hover:bg-primary-soft"
            >
              রেকর্ডিং
            </a>
          ) : null}
        </div>
      </CardContent>
    </Card>
  );
}

/** datetime-local ↔ ISO helpers (the form works in the local wall clock). */
function toLocalInput(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

function fromLocalInput(value: string): string {
  return new Date(value).toISOString();
}

function LiveProgramDialog({
  initial,
  onClose,
}: {
  initial: LiveProgramItem | null; // null = create
  onClose: () => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [titleBn, setTitleBn] = React.useState("");
  const [descBn, setDescBn] = React.useState("");
  const [hostName, setHostName] = React.useState("");
  const [startsAt, setStartsAt] = React.useState("");
  const [endsAt, setEndsAt] = React.useState("");
  const [youtubeId, setYoutubeId] = React.useState("");
  const [gender, setGender] = React.useState<Gender>("M");
  const [recordingUrl, setRecordingUrl] = React.useState("");
  const [quizId, setQuizId] = React.useState("");
  // AMOL-17: the quiz pack, for "this program is a live quiz"
  const quizzes = useQuery({
    queryKey: ["content", "quizzes"],
    queryFn: () => api.contentPack("quizzes"),
    select: (r) => ((r.data as { quizzes?: { id: string; titleBn: string }[] })?.quizzes ?? []),
  });

  // sync form on target change — render-phase adjustment
  const [syncedFor, setSyncedFor] = React.useState<string | null>(initial?.id ?? null);
  if ((initial?.id ?? null) !== syncedFor) {
    setSyncedFor(initial?.id ?? null);
    setTitleBn(initial?.titleBn ?? "");
    setDescBn(initial?.descBn ?? "");
    setHostName(initial?.hostName ?? "");
    setStartsAt(initial ? toLocalInput(initial.startsAt) : "");
    setEndsAt(initial?.endsAt ? toLocalInput(initial.endsAt) : "");
    setYoutubeId(initial?.youtubeId ?? "");
    setGender(initial?.gender ?? "M");
    setRecordingUrl(initial?.recordingUrl ?? "");
    setQuizId(initial?.quizId ?? "");
  }

  const save = useMutation({
    mutationFn: async () => {
      const payload = {
        titleBn: titleBn.trim(),
        descBn: descBn.trim() || null,
        hostName: hostName.trim() || null,
        startsAt: fromLocalInput(startsAt),
        endsAt: endsAt ? fromLocalInput(endsAt) : null,
        youtubeId: youtubeId.trim() || null,
        gender,
        recordingUrl: recordingUrl.trim() || null,
        quizId: quizId || null,
      };
      if (initial) return api.patchLiveProgram(initial.id, payload);
      return api.createLiveProgram(payload);
    },
    onSuccess: (res) => {
      toast(
        initial ? `${res.program.titleBn} হালনাগাদ হয়েছে` : `${res.program.titleBn} নির্ধারিত হয়েছে`,
        "success"
      );
      qc.invalidateQueries({ queryKey: ["live"] });
      onClose();
    },
    onError: (e: Error) => toast(e.message, "error"),
  });

  return (
    <Dialog
      open
      onClose={onClose}
      title={initial ? "প্রোগ্রাম সম্পাদনা" : "নতুন লাইভ প্রোগ্রাম"}
      description="নারীদের সেশনের লিংক কখনো প্রকাশ্য হয় না — শুধুমাত্র অ্যাপের ভেতরে দেখা যায়।"
      footer={
        <>
          <Button variant="ghost" onClick={onClose}>
            বাতিল
          </Button>
          <Button
            onClick={() => save.mutate()}
            loading={save.isPending}
            disabled={!titleBn.trim() || !startsAt}
          >
            {initial ? "সংরক্ষণ করুন" : "নির্ধারণ করুন"}
          </Button>
        </>
      }
    >
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="শিরোনাম" htmlFor="live-title">
          <Input id="live-title" value={titleBn} onChange={(e) => setTitleBn(e.target.value)} aria-label="শিরোনাম" />
        </Field>
        <Field label="উপস্থাপক" htmlFor="live-host">
          <Input id="live-host" value={hostName} onChange={(e) => setHostName(e.target.value)} aria-label="উপস্থাপক" />
        </Field>
        <Field label="শুরু" htmlFor="live-start">
          <Input
            id="live-start"
            type="datetime-local"
            value={startsAt}
            onChange={(e) => setStartsAt(e.target.value)}
            aria-label="শুরুর সময়"
          />
        </Field>
        <Field label="শেষ (ঐচ্ছিক)" htmlFor="live-end">
          <Input
            id="live-end"
            type="datetime-local"
            value={endsAt}
            onChange={(e) => setEndsAt(e.target.value)}
            aria-label="শেষের সময়"
          />
        </Field>
        <Field
          label="YouTube আইডি বা লিংক"
          htmlFor="live-youtube"
          hint="আনলিস্টেড ভিডিওর আইডি বা সম্পূর্ণ লিংক — সার্ভার আইডি বের করে নেয়"
        >
          <Input
            id="live-youtube"
            dir="ltr"
            value={youtubeId}
            onChange={(e) => setYoutubeId(e.target.value)}
            placeholder="dQw4w9WgXcQ"
            aria-label="YouTube আইডি বা লিংক"
          />
        </Field>
        <Field label="দর্শক লিঙ্গ" htmlFor="live-gender" hint="নারী: শুধু বোনদের দৃশ্যমান">
          <Select id="live-gender" value={gender} onChange={(e) => setGender(e.target.value as Gender)}>
            <option value="M">সাধারণ (সবাই)</option>
            <option value="F">শুধুমাত্র নারী</option>
          </Select>
        </Field>
        <Field
          label="লাইভ কুইজ (ঐচ্ছিক)"
          htmlFor="live-quiz"
          hint="কুইজ বাছলে অ্যাপে ‘আসন্ন কুইজ’ তালিকায় দেখাবে, লাইভ চলাকালে সদস্যরা সরাসরি অংশ নিতে পারবেন"
        >
          <Select id="live-quiz" value={quizId} onChange={(e) => setQuizId(e.target.value)}>
            <option value="">কুইজ নয় — সাধারণ প্রোগ্রাম</option>
            {(quizzes.data ?? []).map((q) => (
              <option key={q.id} value={q.id}>
                {q.titleBn}
              </option>
            ))}
          </Select>
        </Field>
        <Field label="বিবরণ (ঐচ্ছিক)" htmlFor="live-desc">
          <Textarea
            id="live-desc"
            value={descBn}
            onChange={(e) => setDescBn(e.target.value)}
            rows={2}
            aria-label="বিবরণ"
          />
        </Field>
        <Field label="রেকর্ডিং লিংক (ঐচ্ছিক)" htmlFor="live-recording">
          <Input
            id="live-recording"
            dir="ltr"
            value={recordingUrl}
            onChange={(e) => setRecordingUrl(e.target.value)}
            aria-label="রেকর্ডিং লিংক"
          />
        </Field>
      </div>
    </Dialog>
  );
}

export default function LivePage() {
  const { user, fullAdmin } = useSession();
  const live = useQuery({ queryKey: ["live"], queryFn: () => api.livePrograms(), enabled: !!user });
  const [creating, setCreating] = React.useState(false);
  const [editing, setEditing] = React.useState<LiveProgramItem | null>(null);

  // edit buttons on the cards dispatch a DOM event (sibling-component handoff)
  React.useEffect(() => {
    if (!fullAdmin) return;
    const onEdit = (e: Event) => setEditing((e as CustomEvent<LiveProgramItem>).detail);
    window.addEventListener("sl-edit-live", onEdit as EventListener);
    return () => window.removeEventListener("sl-edit-live", onEdit as EventListener);
  }, [fullAdmin]);

  const programs = live.data?.programs ?? [];
  const now = programs.filter((p) => p.status === "live");
  const upcoming = programs.filter((p) => p.status === "upcoming");
  const past = programs.filter((p) => p.status === "past");

  return (
    <div className="space-y-6">
      <div className="flex flex-wrap items-start justify-between gap-3">
        <div className="flex items-start gap-3">
          <div className="mt-0.5 flex h-11 w-11 shrink-0 items-center justify-center rounded-xl bg-primary-soft text-primary">
            <Radio className="h-6 w-6" aria-hidden />
          </div>
          <div>
            <h1 className="text-xl font-bold tracking-tight text-foreground md:text-2xl">লাইভ প্রোগ্রাম</h1>
            <p className="mt-0.5 max-w-2xl text-sm leading-relaxed text-muted-foreground">
              সরাসরি দারস ও প্রশিক্ষণ — YouTube (unlisted) এমবেডে। নারীদের সেশন কখনো প্রকাশ্য নয়।
            </p>
          </div>
        </div>
        {fullAdmin ? (
          <Button onClick={() => setCreating(true)}>
            <Plus className="h-4 w-4" aria-hidden />
            নতুন প্রোগ্রাম
          </Button>
        ) : null}
      </div>

      {live.isLoading ? (
        <p className="py-10 text-center text-sm text-muted-foreground">লোড হচ্ছে…</p>
      ) : live.error ? (
        <EmptyState title="প্রোগ্রাম তালিকা আনা যায়নি" hint="নেটওয়ার্ক চেক করে আবার চেষ্টা করুন।" />
      ) : programs.length === 0 ? (
        <EmptyState
          title="কোনো লাইভ প্রোগ্রাম নেই"
          hint="নতুন সেশন নির্ধারিত হলে এখানে দেখা যাবে।"
        />
      ) : (
        <Tabs defaultValue="now">
          <TabsList>
            <TabsTrigger value="now">
              এখন ({toBn(now.length)})
            </TabsTrigger>
            <TabsTrigger value="upcoming">
              আসন্ন ({toBn(upcoming.length)})
            </TabsTrigger>
            <TabsTrigger value="past">
              পূর্বের ({toBn(past.length)})
            </TabsTrigger>
          </TabsList>
          <TabsPanel value="now">
            {now.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {now.map((p) => (
                  <ProgramCard key={p.id} p={p} editable={fullAdmin} />
                ))}
              </div>
            ) : (
              <EmptyState title="এই মুহূর্তে কোনো সেশন লাইভ নেই" />
            )}
          </TabsPanel>
          <TabsPanel value="upcoming">
            {upcoming.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {upcoming.map((p) => (
                  <ProgramCard key={p.id} p={p} editable={fullAdmin} />
                ))}
              </div>
            ) : (
              <EmptyState title="কোনো আসন্ন সেশন নেই" />
            )}
          </TabsPanel>
          <TabsPanel value="past">
            {past.length ? (
              <div className="grid gap-4 lg:grid-cols-2">
                {past.map((p) => (
                  <ProgramCard key={p.id} p={p} editable={fullAdmin} />
                ))}
              </div>
            ) : (
              <EmptyState title="কোনো রেকর্ডিং নেই" />
            )}
          </TabsPanel>
        </Tabs>
      )}

      {creating ? <LiveProgramDialog initial={null} onClose={() => setCreating(false)} /> : null}
      {editing ? <LiveProgramDialog initial={editing} onClose={() => setEditing(null)} /> : null}
    </div>
  );
}
