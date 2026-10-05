"use client";

// মাসআলা জিজ্ঞাসা — প্রশ্ন ফর্ম (→ POST /api/masala) + FAQ অ্যাকর্ডিয়ন।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Textarea } from "@/components/ui/textarea";
import { Skeleton } from "@/components/ui/skeleton";
import {
  Accordion,
  AccordionContent,
  AccordionItem,
  AccordionTrigger,
} from "@/components/ui/accordion";
import { SubShell, SectionLabel } from "@/components/more/bits";
import { api } from "@/lib/api";
import { getPack } from "@/lib/content";
import type { FaqPack } from "@/lib/content";
import { useApp } from "@/lib/store";
import type { MyMasala } from "@/types/domain";
import { Loader2, Send, MailCheck, MessageCircleQuestion, HelpCircle } from "lucide-react";
import { toast } from "sonner";

export function MasalaView() {
  const profile = useApp((s) => s.profile);
  const user = useApp((s) => s.user);

  const [name, setName] = React.useState(user?.name || profile.name);
  const [phone, setPhone] = React.useState(user?.phone ?? "");
  const [question, setQuestion] = React.useState("");
  const [sending, setSending] = React.useState(false);
  const [sent, setSent] = React.useState(false);

  const [faqs, setFaqs] = React.useState<{ q: string; a: string }[] | null>(null);
  React.useEffect(() => {
    let alive = true;
    getPack("faq")
      // content.ts-এর getPack রিটার্ন-টাইপ জেনেরিক ইনফারেন্সে ভেঙে থাকায় কাস্ট (lib ফাইল আমার নয়)।
      .then((p) => {
        const pack = p as unknown as FaqPack;
        if (alive) setFaqs(Array.isArray(pack.items) ? pack.items : []);
      })
      .catch(() => alive && setFaqs([]));
    return () => {
      alive = false;
    };
  }, []);

  const send = async (e: React.FormEvent) => {
    e.preventDefault();
    if (name.trim().length === 0 || question.trim().length < 10) return;
    setSending(true);
    try {
      await api.masala({
        name: name.trim(),
        phone: phone.trim() || undefined,
        question: question.trim(),
      });
      setSent(true);
      toast.success("প্রশ্ন পাঠানো হয়েছে");
    } catch (err) {
      toast.error(err instanceof Error ? err.message : "পাঠানো যায়নি — আবার চেষ্টা করুন");
    } finally {
      setSending(false);
    }
  };

  return (
    <SubShell title="মাসআলা জিজ্ঞাসা">
      <div className="space-y-4">
        {sent ? (
          <Card className="rounded-xl shadow-card">
            <CardContent className="p-8 text-center">
              <div className="mx-auto size-20 rounded-full bg-primary-soft flex items-center justify-center">
                <MailCheck className="size-9 text-primary" />
              </div>
              <p className="mt-4 text-sm leading-relaxed">
                প্রশ্ন পাঠানো হয়েছে — মুফতি সাহেব উত্তর দিলে জানানো হবে ইনশাআল্লাহ।
              </p>
              <Button
                variant="outline"
                className="mt-4 h-11 rounded-xl"
                onClick={() => {
                  setSent(false);
                  setQuestion("");
                }}
              >
                আরেকটি প্রশ্ন করুন
              </Button>
            </CardContent>
          </Card>
        ) : (
          <>
            <p className="text-sm text-muted-foreground leading-relaxed">
              দ্বীনি মাসআলা লিখে জানান — মুফতি সাহেব ইনশাআল্লাহ উত্তর দিবেন।
            </p>

            <Card className="rounded-xl shadow-card">
              <CardContent className="p-4 sm:p-5">
                <form onSubmit={send} className="space-y-4" aria-label="মাসআলা জিজ্ঞাসা ফর্ম">
                  <div className="space-y-1.5">
                    <Label htmlFor="ms-name">আপনার নাম</Label>
                    <Input
                      id="ms-name"
                      value={name}
                      onChange={(e) => setName(e.target.value)}
                      className="h-12 rounded-xl"
                      placeholder="যেমন: আব্দুল্লাহ"
                      required
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="ms-phone">মোবাইল (ঐচ্ছিক)</Label>
                    <Input
                      id="ms-phone"
                      type="tel"
                      inputMode="tel"
                      value={phone}
                      onChange={(e) => setPhone(e.target.value)}
                      className="h-12 rounded-xl"
                      placeholder="01XXXXXXXXX"
                    />
                  </div>
                  <div className="space-y-1.5">
                    <Label htmlFor="ms-q">আপনার প্রশ্ন লিখুন</Label>
                    <Textarea
                      id="ms-q"
                      value={question}
                      onChange={(e) => setQuestion(e.target.value)}
                      rows={6}
                      className="rounded-xl text-base leading-relaxed"
                      placeholder="বিস্তারিত লিখুন যেন সঠিক মাসআলা বোঝা যায়…"
                      required
                      minLength={10}
                    />
                    {question.trim().length > 0 && question.trim().length < 10 && (
                      <p className="text-xs text-muted-foreground">অন্তত ১০ অক্ষরের প্রশ্ন লিখুন।</p>
                    )}
                  </div>
                  <Button type="submit" disabled={sending} className="w-full h-12 rounded-xl text-base font-semibold">
                    {sending ? <Loader2 className="size-4 animate-spin" /> : <Send className="size-4" />}
                    {sending ? "পাঠানো হচ্ছে…" : "প্রশ্ন পাঠান"}
                  </Button>
                  <p className="text-center text-[11px] text-muted-foreground">
                    অফলাইনে পাঠানো যাবে না — ইন্টারনেট সংযোগ দরকার।
                  </p>
                </form>
              </CardContent>
            </Card>
          </>
        )}

        {/* my questions and the mufti's answers (signed in) */}
        {user ? <MyQuestions refreshKey={sent ? 1 : 0} /> : null}

        {/* FAQ */}
        <div className="pt-1">
          <SectionLabel icon={<HelpCircle className="size-4" />}>জিজ্ঞাসা (FAQ)</SectionLabel>
          {faqs === null ? (
            <div className="mt-3 space-y-2">
              {[0, 1, 2].map((i) => (
                <Skeleton key={i} className="h-12 rounded-xl" />
              ))}
            </div>
          ) : faqs.length === 0 ? (
            <p className="mt-3 rounded-xl bg-muted px-4 py-3 text-sm text-muted-foreground">
              এখনো কোনো জিজ্ঞাসা যোগ করা হয়নি।
            </p>
          ) : (
            <Card className="mt-3 rounded-xl shadow-card">
              <CardContent className="p-2">
                <Accordion type="single" collapsible>
                  {faqs.map((f, i) => (
                    <AccordionItem key={i} value={`faq-${i}`}>
                      <AccordionTrigger className="text-start text-sm font-semibold py-3.5">
                        {f.q}
                      </AccordionTrigger>
                      <AccordionContent className="text-sm leading-relaxed text-muted-foreground">
                        {f.a}
                      </AccordionContent>
                    </AccordionItem>
                  ))}
                </Accordion>
              </CardContent>
            </Card>
          )}
        </div>

        {/* সহায়তা আইকন স্ট্রিপ */}
        <div className="flex items-center justify-center gap-2 text-muted-foreground">
          <MessageCircleQuestion className="size-4" />
          <p className="text-[11px]">আপনার প্রশ্ন গোপন রাখা হয় — শুধু মুফতির সাথে শেয়ার হয়।</p>
        </div>
      </div>
    </SubShell>
  );
}

/** My questions and their answers (GET /api/masala/mine) — on the web a
 * member could ask but never read the answer before. */
function MyQuestions({ refreshKey }: { refreshKey: number }) {
  const [items, setItems] = React.useState<MyMasala[] | null>(null);
  React.useEffect(() => {
    api
      .myMasala()
      .then((r) => setItems(r.questions))
      .catch(() => setItems([]));
  }, [refreshKey]);
  if (!items || items.length === 0) return null;
  return (
    <div className="pt-1">
      <SectionLabel icon={<MessageCircleQuestion className="size-4" />}>আমার প্রশ্ন ও উত্তর</SectionLabel>
      <div className="mt-3 space-y-2">
        {items.map((q) => (
          <Card key={q.id} className="rounded-xl shadow-card">
            <CardContent className="space-y-2 p-4">
              <p className="text-sm font-semibold leading-relaxed">{q.question}</p>
              {q.status === "answered" && q.answer ? (
                <div className="rounded-lg bg-primary-soft px-3 py-2">
                  <p className="text-xs font-bold text-primary">উত্তর</p>
                  <p className="mt-0.5 whitespace-pre-line text-sm leading-relaxed">{q.answer}</p>
                </div>
              ) : (
                <p className="text-xs text-muted-foreground">উত্তরের অপেক্ষায় — উত্তর এলে নোটিফিকেশন পাবেন।</p>
              )}
            </CardContent>
          </Card>
        ))}
      </div>
    </div>
  );
}
