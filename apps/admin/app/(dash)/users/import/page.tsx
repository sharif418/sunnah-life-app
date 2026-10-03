"use client";

// সদস্য ইমপোর্ট — the Dawatus Sunnah member register from a spreadsheet.
// Choose a CSV → যাচাই (dry run, nothing saved) → review every row →
// সংরক্ষণ. Big sheets go up in chunks of 200 rows (the API's JSON body
// limit); row numbers stay those of the spreadsheet.

import * as React from "react";
import Link from "next/link";
import { ArrowLeft, Download, FileUp, ShieldCheck } from "lucide-react";
import { api, type ImportAction, type MemberImportResponse } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn } from "@/lib/bn";
import { downloadCsvSafe, parseCsv } from "@/lib/csv";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { useToast } from "@/components/ui/toast";

const CHUNK = 200;

const TEMPLATE_HEADERS = ["নাম", "মোবাইল", "লিঙ্গ", "ভূমিকা", "সদস্য কোড", "উসরা", "জেলা", "কর্মস্থল", "বিভাগ / পদবি", "ক্যাটাগরি", "ইমেইল"];

const ACTION_LABEL: Record<ImportAction, { label: string; variant: "success" | "gold" | "muted" | "alert" }> = {
  create: { label: "নতুন", variant: "success" },
  update: { label: "হালনাগাদ", variant: "gold" },
  skip: { label: "বাদ", variant: "muted" },
  error: { label: "ত্রুটি", variant: "alert" },
};

type Results = MemberImportResponse["results"];

export default function MemberImportPage() {
  const { fullAdmin } = useSession();
  const { toast } = useToast();
  const [fileName, setFileName] = React.useState("");
  const [rows, setRows] = React.useState<Record<string, string>[]>([]);
  const [headers, setHeaders] = React.useState<string[]>([]);
  const [results, setResults] = React.useState<Results | null>(null);
  const [committed, setCommitted] = React.useState(false);
  const [busy, setBusy] = React.useState<"" | "check" | "save">("");
  const [progress, setProgress] = React.useState(0);
  const [onlyProblems, setOnlyProblems] = React.useState(false);

  async function run(dryRun: boolean): Promise<Results> {
    const all: Results = [];
    for (let i = 0; i < rows.length; i += CHUNK) {
      const res = await api.importUsers(rows.slice(i, i + CHUNK), dryRun, i);
      all.push(...res.results);
      setProgress(Math.min(rows.length, i + CHUNK));
    }
    return all;
  }

  async function onFile(e: React.ChangeEvent<HTMLInputElement>) {
    const f = e.target.files?.[0];
    if (!f) return;
    const parsed = parseCsv(await f.text());
    setFileName(f.name);
    setHeaders(parsed.headers);
    setRows(parsed.rows);
    setResults(null);
    setCommitted(false);
  }

  async function check() {
    setBusy("check");
    setProgress(0);
    try {
      setResults(await run(true));
      setCommitted(false);
    } catch (err) {
      toast((err as Error).message, "error");
    } finally {
      setBusy("");
    }
  }

  async function save() {
    const t = totals(results);
    if (!window.confirm(`${toBn(t.create)} জন নতুন সদস্য তৈরি ও ${toBn(t.update)} জনের খালি ঘর পূরণ হবে। নিশ্চিত?`)) return;
    setBusy("save");
    setProgress(0);
    try {
      const out = await run(false);
      setResults(out);
      setCommitted(true);
      const s = totals(out);
      toast(`সংরক্ষিত — নতুন ${toBn(s.create)}, হালনাগাদ ${toBn(s.update)} (অডিট-লগড)`, "success");
    } catch (err) {
      toast((err as Error).message, "error");
    } finally {
      setBusy("");
    }
  }

  if (!fullAdmin) {
    return (
      <Card>
        <CardContent className="p-6 text-sm text-muted-foreground">শুধু ফুল অ্যাডমিন সদস্য ইমপোর্ট করতে পারেন।</CardContent>
      </Card>
    );
  }

  const t = totals(results);
  const shown = (results ?? []).filter((r) => !onlyProblems || r.action === "error" || r.action === "skip");

  return (
    <div className="space-y-4">
      <Link href="/users" className="inline-flex items-center gap-1 text-sm text-muted-foreground hover:text-foreground">
        <ArrowLeft className="h-4 w-4" aria-hidden />
        ব্যবহারকারী
      </Link>
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <FileUp className="h-[18px] w-[18px] text-primary" aria-hidden />
            সদস্য ইমপোর্ট (CSV)
          </CardTitle>
          <CardDescription>
            দাওয়াতুস সুন্নাহর সদস্য-তালিকা স্প্রেডশিট থেকে আনুন। Excel-এ “CSV UTF-8” হিসেবে সেভ করুন। আগে যাচাই হবে —
            কিছুই সংরক্ষণ হবে না; ফলাফল দেখে তারপর সংরক্ষণ করুন।
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-4">
          <ul className="list-disc space-y-1 pl-5 text-sm text-muted-foreground">
            <li>
              কলাম: <span className="font-medium text-foreground">{TEMPLATE_HEADERS.join(" · ")}</span> — নাম ও মোবাইল
              বাধ্যতামূলক; নতুন সদস্যের জন্য লিঙ্গ (পুরুষ / নারী) লাগবে।
            </li>
            <li>মোবাইল নম্বরই পরিচয় — আগে থেকে থাকা সদস্যের লিঙ্গ / ভূমিকা বদলায় না, শুধু খালি ঘরগুলো পূরণ হয়।</li>
            <li>উসরা নাম হুবহু মিলতে হবে এবং সদস্যের লিঙ্গের সাথে মিলতে হবে। পুরনো DS কোড (যেমন DS-123) রাখা হবে।</li>
            <li>ভূমিকা: সদস্য বা দাঈ — উসরা প্রধান / পরিদর্শক নিয়োগ কনসোল থেকে।</li>
          </ul>
          <div className="flex flex-wrap items-center gap-2">
            <Button variant="outline" onClick={() => downloadCsvSafe("sunnahlife-member-template.csv", TEMPLATE_HEADERS, [])}>
              <Download className="h-4 w-4" aria-hidden />
              টেমপ্লেট ডাউনলোড
            </Button>
            <label className="focus-ring inline-flex min-h-10 cursor-pointer items-center gap-2 rounded-md border border-border bg-card px-3.5 text-sm font-semibold hover:bg-primary-soft">
              <FileUp className="h-4 w-4" aria-hidden />
              CSV বাছাই করুন
              <input type="file" accept=".csv,text/csv" className="sr-only" onChange={onFile} aria-label="CSV ফাইল" />
            </label>
            {fileName ? (
              <span className="text-sm text-muted-foreground">
                {fileName} · {toBn(rows.length)} সারি · কলাম: {headers.join(", ")}
              </span>
            ) : null}
          </div>
          {rows.length ? (
            <div className="flex flex-wrap items-center gap-2">
              <Button onClick={check} loading={busy === "check"} disabled={!!busy}>
                যাচাই করুন (সংরক্ষণ হবে না)
              </Button>
              <Button
                variant="outline"
                onClick={save}
                loading={busy === "save"}
                disabled={!!busy || !results || committed || t.create + t.update === 0}
              >
                <ShieldCheck className="h-4 w-4" aria-hidden />
                সংরক্ষণ করুন
              </Button>
              {busy ? (
                <span className="text-sm text-muted-foreground">
                  {toBn(progress)} / {toBn(rows.length)}
                </span>
              ) : null}
            </div>
          ) : null}
        </CardContent>
      </Card>

      {results ? (
        <Card>
          <CardHeader>
            <CardTitle>{committed ? "সংরক্ষণের ফলাফল" : "যাচাইয়ের ফলাফল — এখনো কিছু সংরক্ষণ হয়নি"}</CardTitle>
            <CardDescription className="flex flex-wrap items-center gap-2">
              {(Object.keys(ACTION_LABEL) as ImportAction[]).map((a) => (
                <Badge key={a} variant={ACTION_LABEL[a].variant}>
                  {ACTION_LABEL[a].label}: {toBn(t[a])}
                </Badge>
              ))}
              <label className="ml-2 inline-flex items-center gap-1.5 text-sm">
                <input type="checkbox" checked={onlyProblems} onChange={(e) => setOnlyProblems(e.target.checked)} />
                শুধু ত্রুটি ও বাদ
              </label>
              <Button
                size="sm"
                variant="ghost"
                onClick={() =>
                  downloadCsvSafe(
                    "sunnahlife-import-report.csv",
                    ["সারি", "নাম", "মোবাইল", "ফলাফল", "বিবরণ"],
                    results.map((r) => [r.row, r.name, r.phone, ACTION_LABEL[r.action].label, r.message])
                  )
                }
              >
                <Download className="h-4 w-4" aria-hidden />
                রিপোর্ট
              </Button>
            </CardDescription>
          </CardHeader>
          <CardContent>
            <div className="overflow-x-auto rounded-lg border border-border">
              <table className="w-full text-sm">
                <thead>
                  <tr className="border-b border-border text-xs text-muted-foreground">
                    <th className="px-3 py-2 text-left font-semibold">সারি</th>
                    <th className="px-3 py-2 text-left font-semibold">নাম</th>
                    <th className="px-3 py-2 text-left font-semibold">মোবাইল</th>
                    <th className="px-3 py-2 text-left font-semibold">ফলাফল</th>
                    <th className="px-3 py-2 text-left font-semibold">বিবরণ</th>
                  </tr>
                </thead>
                <tbody>
                  {shown.map((r) => (
                    <tr key={r.row} className="border-b border-border/60">
                      <td className="px-3 py-2 tabular-nums">{toBn(r.row)}</td>
                      <td className="px-3 py-2">{r.name}</td>
                      <td className="px-3 py-2 tabular-nums" dir="ltr">
                        {r.phone}
                      </td>
                      <td className="px-3 py-2">
                        <Badge variant={ACTION_LABEL[r.action].variant}>{ACTION_LABEL[r.action].label}</Badge>
                      </td>
                      <td className="px-3 py-2 text-muted-foreground">{r.message}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </CardContent>
        </Card>
      ) : null}
    </div>
  );
}

function totals(results: Results | null): Record<ImportAction, number> {
  const t: Record<ImportAction, number> = { create: 0, update: 0, skip: 0, error: 0 };
  for (const r of results ?? []) t[r.action]++;
  return t;
}
