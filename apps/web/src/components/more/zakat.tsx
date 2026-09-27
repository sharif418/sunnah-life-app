"use client";

// যাকাত ক্যালকুলেটর — স্বর্ণ/রূপা/নগদ/ব্যবসা/ঋণ ইনপুট; নিসাব (৮৫ গ্রাম স্বর্ণ)
// /api/config থেকে; নেট সম্পদের ২.৫% প্রদেয়। বাংলা অঙ্কে ৳ পরিমাণ।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Progress } from "@/components/ui/progress";
import { Separator } from "@/components/ui/separator";
import { SubShell, SectionLabel } from "@/components/more/bits";
import { api } from "@/lib/api";
import { toBn } from "@/lib/calendars";
import type { AppConfig } from "@/types/domain";
import { Coins, HeartHandshake, Scale } from "lucide-react";

const FALLBACK_GOLD = 16500; // ২০২৫ আনুমানিক — কনফিগ আনা না গেলে
const FALLBACK_SILVER = 220;
const NISAB_GOLD_G = 85;

/** বাংলা অঙ্ক + কমা মেনে নেওয়া সংখ্যা পার্সার। */
function parseNum(s: string): number {
  const latin = s.replace(/[০-৯]/g, (d) => String("০১২৩৪৫৬৭৮৯".indexOf(d)));
  const n = Number(latin.replace(/[,\s৳]/g, ""));
  return isFinite(n) && n > 0 ? n : 0;
}

/** ৳ + বাংলা অঙ্কে ভারতীয় গ্রুপিং (লাখ/কোটি)। */
function moneyBn(v: number): string {
  return `৳${toBn(Math.round(v).toLocaleString("en-IN"))}`;
}

export function ZakatView() {
  const [gold, setGold] = React.useState("");
  const [silver, setSilver] = React.useState("");
  const [cash, setCash] = React.useState("");
  const [business, setBusiness] = React.useState("");
  const [debts, setDebts] = React.useState("");

  const [nisab, setNisab] = React.useState<AppConfig["nisab"] | null>(null);
  const [estimated, setEstimated] = React.useState(false);

  React.useEffect(() => {
    api
      .config()
      .then((c) => setNisab(c.nisab))
      .catch(() => setEstimated(true));
  }, []);

  const goldPrice = nisab?.goldPerGramBdt ?? FALLBACK_GOLD;
  const silverPrice = nisab?.silverPerGramBdt ?? FALLBACK_SILVER;

  const goldVal = parseNum(gold) * goldPrice;
  const silverVal = parseNum(silver) * silverPrice;
  const wealth = goldVal + silverVal + parseNum(cash) + parseNum(business);
  const net = Math.max(0, wealth - parseNum(debts));
  const nisabAmount = NISAB_GOLD_G * goldPrice;
  const eligible = net >= nisabAmount && nisabAmount > 0;
  const zakat = eligible ? net * 0.025 : 0;
  const nisabPct = Math.min(100, nisabAmount > 0 ? (net / nisabAmount) * 100 : 0);

  const fields: { id: string; label: string; unit: string; value: string; set: (v: string) => void; icon: React.ReactNode }[] = [
    { id: "zk-gold", label: "স্বর্ণ (গ্রাম)", unit: "গ্রাম", value: gold, set: setGold, icon: <Coins className="size-4" /> },
    { id: "zk-silver", label: "রূপা (গ্রাম)", unit: "গ্রাম", value: silver, set: setSilver, icon: <Coins className="size-4" /> },
    { id: "zk-cash", label: "নগদ ও ব্যাংক", unit: "৳", value: cash, set: setCash, icon: <Scale className="size-4" /> },
    { id: "zk-biz", label: "ব্যবসা ও বিনিয়োগ", unit: "৳", value: business, set: setBusiness, icon: <Scale className="size-4" /> },
    { id: "zk-debt", label: "ঋণ (বাদ যাবে)", unit: "৳", value: debts, set: setDebts, icon: <Scale className="size-4" /> },
  ];

  return (
    <SubShell title="যাকাত ক্যালকুলেটর">
      <div className="space-y-4">
        {/* ফলাফল হিরো */}
        <section
          aria-live="polite"
          className="rounded-2xl bg-primary text-primary-foreground bg-pattern-islamic p-5 shadow-lifted"
        >
          <p className="text-sm text-primary-foreground/80">যাকাত দিতে হবে</p>
          <p className="mt-1 text-4xl font-extrabold text-gold-text tabular-nums leading-tight">
            {moneyBn(zakat)}
          </p>
          <p className="mt-1.5 text-xs leading-relaxed text-primary-foreground/75">
            {eligible ? (
              <>নিট সম্পদের ২.৫% · নিট {moneyBn(net)}</>
            ) : (
              "নিসাব পরিমাণ সম্পদ নেই — যাকাত ফরজ নয়"
            )}
          </p>
        </section>

        {/* ইনপুট */}
        <Card className="rounded-xl shadow-card">
          <CardContent className="p-4 sm:p-5 space-y-3.5">
            {fields.map((f) => (
              <div key={f.id} className="space-y-1.5">
                <Label htmlFor={f.id} className="text-sm font-medium flex items-center gap-1.5">
                  <span className="text-primary">{f.icon}</span>
                  {f.label}
                </Label>
                <div className="relative">
                  <Input
                    id={f.id}
                    inputMode="decimal"
                    value={f.value}
                    onChange={(e) => f.set(e.target.value)}
                    placeholder="০"
                    className="h-12 rounded-xl text-base pe-14"
                    aria-label={f.label}
                  />
                  <span className="absolute end-3 top-1/2 -translate-y-1/2 text-xs text-muted-foreground pointer-events-none">
                    {f.unit}
                  </span>
                </div>
              </div>
            ))}
            <p className="text-[11px] text-muted-foreground leading-relaxed">
              বাংলা বা ইংরেজি — দুই ধরনের অঙ্কেই লিখতে পারবেন।
            </p>
          </CardContent>
        </Card>

        {/* হিসাবের বিবরণ */}
        <Card className="rounded-xl shadow-card">
          <CardContent className="p-4 sm:p-5">
            <SectionLabel icon={<Scale className="size-4" />}>হিসাবের বিবরণ</SectionLabel>
            <dl className="mt-3 space-y-2 text-sm">
              <Row label="স্বর্ণের মূল্য" value={moneyBn(goldVal)} sub={gold.trim() ? `${toBn(parseNum(gold))} গ্রাম × ${moneyBn(goldPrice)}` : undefined} />
              <Row label="রূপার মূল্য" value={moneyBn(silverVal)} sub={silver.trim() ? `${toBn(parseNum(silver))} গ্রাম × ${moneyBn(silverPrice)}` : undefined} />
              {parseNum(cash) > 0 && <Row label="নগদ ও ব্যাংক" value={moneyBn(parseNum(cash))} />}
              {parseNum(business) > 0 && <Row label="ব্যবসা ও বিনিয়োগ" value={moneyBn(parseNum(business))} />}
              {parseNum(debts) > 0 && <Row label="ঋণ (বাদ)" value={`− ${moneyBn(parseNum(debts))}`} />}
            </dl>
            <Separator className="my-3" />
            <div className="flex items-center justify-between gap-2 text-sm">
              <span className="font-medium">নিট সম্পদ</span>
              <span className="font-extrabold tabular-nums">{moneyBn(net)}</span>
            </div>
            <div className="mt-1 flex items-center justify-between gap-2 text-sm">
              <span className="text-muted-foreground">নিসাব ({toBn(NISAB_GOLD_G)} গ্রাম স্বর্ণ)</span>
              <span className="font-semibold tabular-nums text-muted-foreground">{moneyBn(nisabAmount)}</span>
            </div>

            {/* নিসাবের দিকে অগ্রগতি */}
            <div className="mt-3.5" aria-label={`নিসাবের ${Math.round(nisabPct)} শতাংশ`}>
              <div className="flex justify-between text-[11px] text-muted-foreground mb-1">
                <span>নিসাবের দিকে অগ্রগতি</span>
                <span className="tabular-nums">{toBn(Math.round(nisabPct))}%</span>
              </div>
              <Progress value={nisabPct} className="h-2" />
            </div>
            {estimated && (
              <p className="mt-2 text-[11px] text-warning leading-relaxed">
                দর আনা যায়নি — আনুমানিক স্বর্ণ দর ব্যবহৃত হচ্ছে।
              </p>
            )}
          </CardContent>
        </Card>

        {/* দান */}
        {eligible && <DonateButton />}
      </div>
    </SubShell>
  );
}

function Row({ label, value, sub }: { label: string; value: string; sub?: string }) {
  return (
    <div className="flex items-start justify-between gap-3">
      <dt className="text-muted-foreground">
        {label}
        {sub && <span className="block text-[11px] text-muted-foreground/70">{sub}</span>}
      </dt>
      <dd className="font-semibold tabular-nums text-end">{value}</dd>
    </div>
  );
}

function DonateButton() {
  const [url, setUrl] = React.useState("https://as-sunnah.org/donation");
  React.useEffect(() => {
    api
      .config()
      .then((c) => setUrl(c.donationUrl))
      .catch(() => null);
  }, []);
  return (
    <>
      <Button
        className="w-full h-12 rounded-xl text-base font-semibold"
        onClick={() => window.open(url, "_blank", "noopener,noreferrer")}
      >
        <HeartHandshake className="size-5" /> দান করুন
      </Button>
      <p className="text-center text-[11px] text-muted-foreground break-all">দানের লিংক: {url}</p>
    </>
  );
}
