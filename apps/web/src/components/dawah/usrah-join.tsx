"use client";

// Asking to join an usrah (W4d, mobile parity): a member without an usrah
// sends a request (with an optional note); the Foundation's tarbiyah office
// assigns them to a same-gender usrah. Shows the request's state after.

import * as React from "react";
import { CheckCircle2, Clock, Loader2, Users } from "lucide-react";
import { toast } from "sonner";
import { api } from "@/lib/api";
import type { UsrahJoinRequestItem } from "@/types/domain";
import { Button } from "@/components/ui/button";
import { Card, CardContent } from "@/components/ui/card";
import { Textarea } from "@/components/ui/textarea";

export function UsrahJoinCard({ onJoined }: { onJoined?: () => void }) {
  const [request, setRequest] = React.useState<UsrahJoinRequestItem | null | undefined>(undefined);
  const [note, setNote] = React.useState("");
  const [busy, setBusy] = React.useState(false);

  React.useEffect(() => {
    api
      .joinRequestStatus()
      .then((r) => {
        setRequest(r.request);
        if (r.request?.status === "approved") onJoined?.();
      })
      .catch(() => setRequest(null));
  }, [onJoined]);

  const send = async () => {
    setBusy(true);
    try {
      const r = await api.joinRequestCreate(note.trim() || undefined);
      setRequest(r.request);
      toast.success("অনুরোধ পাঠানো হয়েছে");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "পাঠানো যায়নি");
    } finally {
      setBusy(false);
    }
  };

  if (request === undefined) return <div className="h-40 animate-pulse rounded-xl bg-muted" />;

  if (request?.status === "pending") {
    return (
      <Card className="rounded-xl shadow-card">
        <CardContent className="flex items-start gap-3 p-4">
          <Clock className="mt-0.5 size-5 shrink-0 text-gold" aria-hidden />
          <div>
            <p className="font-semibold">অনুরোধ পাঠানো হয়েছে</p>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
              তারবিয়াত বিভাগ আপনাকে একটি উসরায় যুক্ত করে দেবে ইনশাআল্লাহ। যুক্ত হলে নোটিফিকেশন পাবেন।
            </p>
          </div>
        </CardContent>
      </Card>
    );
  }

  return (
    <Card className="rounded-xl shadow-card">
      <CardContent className="space-y-3 p-4">
        <div className="flex items-start gap-3">
          <Users className="mt-0.5 size-5 shrink-0 text-primary" aria-hidden />
          <div>
            <p className="font-semibold">উসরায় যোগ দিন</p>
            <p className="mt-1 text-sm leading-relaxed text-muted-foreground">
              উসরা হলো ছোট একটি দল, যেখানে একজন উসরা প্রধান নিয়মিত আমলের খোঁজ নেন ও তারবিয়াতে সাহায্য করেন।
            </p>
          </div>
        </div>
        {request?.status === "rejected" ? (
          <p className="rounded-lg bg-muted px-3 py-2 text-sm">
            আগের অনুরোধটি গ্রহণ করা যায়নি{request.reason ? `: ${request.reason}` : "।"} চাইলে আবার অনুরোধ করতে পারেন।
          </p>
        ) : null}
        {request?.status === "approved" ? (
          <p className="flex items-center gap-2 rounded-lg bg-primary-soft px-3 py-2 text-sm text-primary">
            <CheckCircle2 className="size-4" aria-hidden /> আপনাকে একটি উসরায় যুক্ত করা হয়েছে।
          </p>
        ) : (
          <>
            <Textarea
              rows={3}
              value={note}
              onChange={(e) => setNote(e.target.value)}
              maxLength={500}
              aria-label="তারবিয়াত বিভাগের জন্য নোট"
              placeholder="ঐচ্ছিক: আপনার এলাকা বা সুবিধাজনক সময় লিখুন"
            />
            <Button className="h-11 w-full rounded-xl" onClick={send} disabled={busy}>
              {busy ? <Loader2 className="animate-spin" aria-hidden /> : null}
              যোগ দিতে অনুরোধ করুন
            </Button>
          </>
        )}
      </CardContent>
    </Card>
  );
}
