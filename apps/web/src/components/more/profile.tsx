"use client";

// প্রোফাইল — সাইন-ইন: পরিচয় + সম্পাদনাযোগ্য ফিল্ড (/api/me PATCH);
// গেস্ট: সাইন-ইন আহ্বান + স্থানীয় পছন্দ (store-এ সংরক্ষিত)।

import * as React from "react";
import { Card, CardContent } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Badge } from "@/components/ui/badge";
import { Separator } from "@/components/ui/separator";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { SubShell, SectionLabel } from "@/components/more/bits";
import { PrayerSettingsControls } from "@/components/more/prayer-settings";
import { api } from "@/lib/api";
import { useApp } from "@/lib/store";
import { LEVEL_LABELS_BN, ROLE_LABELS_BN } from "@/types/domain";
import type { Lang } from "@/types/domain";
import { toast } from "sonner";
import {
  UserRound,
  Phone,
  LogIn,
  LogOut,
  Loader2,
  Copy,
  GraduationCap,
  Pencil,
  BadgeCheck,
} from "lucide-react";

const LANG_LABELS: Record<Lang, string> = { bn: "বাংলা", en: "English", ar: "العربية" };

export function ProfileView() {
  const { user } = useApp();

  return (
    <SubShell title="প্রোফাইল">{user ? <SignedIn /> : <GuestProfile />}</SubShell>
  );
}

// ── গেস্ট ────────────────────────────────────────────────────────────────────

function GuestProfile() {
  const { profile, updateProfile, setAuthModal } = useApp();
  const [name, setName] = React.useState(profile.name);

  return (
    <div className="space-y-4">
      <Card className="rounded-xl shadow-card">
        <CardContent className="p-6 text-center">
          <span className="mx-auto flex size-[72px] items-center justify-center rounded-full bg-primary-soft text-primary">
            <UserRound className="size-8" />
          </span>
          <p className="mt-3 font-bold">{profile.name || "অতিথি"}</p>
          <p className="mt-0.5 text-xs text-muted-foreground">অতিথি — সাইন ইন করা হয়নি</p>
          <Button className="mt-4 h-12 rounded-xl w-full" onClick={() => setAuthModal(true)}>
            <LogIn className="size-4" /> সাইন ইন করুন
          </Button>
          <p className="mt-2 text-xs text-muted-foreground leading-relaxed">
            সাইন ইন করলে আজকের অবধি লেখা সব আমল আপনার অ্যাকাউন্টে চলে যাবে — কিছুই হারাবে না।
          </p>
        </CardContent>
      </Card>

      <Card className="rounded-xl shadow-card">
        <CardContent className="p-4 sm:p-5 space-y-4">
          <SectionLabel icon={<Pencil className="size-4" />}>গেস্ট পছন্দসমূহ</SectionLabel>
          <div className="space-y-1.5">
            <Label htmlFor="g-name">নাম</Label>
            <Input
              id="g-name"
              value={name}
              onChange={(e) => {
                setName(e.target.value);
                updateProfile({ name: e.target.value });
              }}
              placeholder="যেমন: আব্দুল্লাহ"
              className="h-12 rounded-xl"
            />
          </div>
          <LangSelect
            value={profile.language}
            onChange={(v) => updateProfile({ language: v })}
          />
          <Separator />
          <p className="text-xs text-muted-foreground leading-relaxed">
            এই পছন্দগুলো শুধু এই ডিভাইসে সংরক্ষিত থাকে।
          </p>
        </CardContent>
      </Card>

      <PrayerSettingsControls />
    </div>
  );
}

// ── সাইন-ইন ──────────────────────────────────────────────────────────────────

function SignedIn() {
  const { user, setUser, updateProfile, setAuthModal } = useApp();
  const [name, setName] = React.useState(user!.name);
  const [district, setDistrict] = React.useState(user!.district ?? "");
  const [workplace, setWorkplace] = React.useState(user!.workplace ?? "");
  const [department, setDepartment] = React.useState(user!.department ?? "");
  const [saving, setSaving] = React.useState(false);

  const dirty =
    name.trim() !== user!.name ||
    district !== (user!.district ?? "") ||
    workplace !== (user!.workplace ?? "") ||
    department !== (user!.department ?? "");

  const save = async () => {
    if (!dirty || !name.trim()) return;
    setSaving(true);
    try {
      const res = await api.updateMe({
        name: name.trim(),
        district: district.trim() || null,
        workplace: workplace.trim() || null,
        department: department.trim() || null,
      });
      setUser(res.user);
      toast.success("সংরক্ষিত হয়েছে");
    } catch (e) {
      toast.error(e instanceof Error ? e.message : "সংরক্ষণ করা যায়নি");
    } finally {
      setSaving(false);
    }
  };

  const copyCode = async () => {
    if (!user!.memberCode) return;
    try {
      await navigator.clipboard.writeText(user!.memberCode);
      toast.success("কপি হয়েছে");
    } catch {
      toast.error("কপি করা যায়নি");
    }
  };

  return (
    <div className="space-y-4">
      {/* পরিচয় */}
      <Card className="rounded-xl shadow-card">
        <CardContent className="p-5 text-center">
          <span className="mx-auto flex size-[72px] items-center justify-center rounded-full bg-primary text-primary-foreground text-2xl font-extrabold ring-4 ring-gold/40">
            {user!.name.slice(0, 2)}
          </span>
          <p className="mt-3 font-bold text-lg leading-snug">{user!.name}</p>
          <p className="mt-0.5 text-xs text-muted-foreground">{ROLE_LABELS_BN[user!.role]}</p>
          <div className="mt-2 flex flex-wrap justify-center gap-1.5">
            {user!.memberCode && (
              <Badge variant="secondary" className="rounded-full gap-1 font-mono">
                <BadgeCheck className="size-3" />
                {user!.memberCode}
                <button
                  onClick={copyCode}
                  aria-label="মেম্বার কোড কপি করুন"
                  className="ms-0.5 inline-flex"
                >
                  <Copy className="size-3 hover:text-primary" />
                </button>
              </Badge>
            )}
            {user!.level !== "none" && (
              <Badge variant="outline" className="rounded-full gap-1">
                <GraduationCap className="size-3" />
                {LEVEL_LABELS_BN[user!.level]}
              </Badge>
            )}
          </div>
          {user!.phone && (
            <p className="mt-2.5 inline-flex items-center gap-1.5 text-xs text-muted-foreground">
              <Phone className="size-3.5" /> {user!.phone}
            </p>
          )}
        </CardContent>
      </Card>

      {/* সম্পাদনাযোগ্য তথ্য */}
      <Card className="rounded-xl shadow-card">
        <CardContent className="p-4 sm:p-5 space-y-4">
          <SectionLabel icon={<Pencil className="size-4" />}>তথ্য সম্পাদনা</SectionLabel>
          <div className="space-y-1.5">
            <Label htmlFor="p-name">নাম</Label>
            <Input
              id="p-name"
              value={name}
              onChange={(e) => setName(e.target.value)}
              className="h-12 rounded-xl"
            />
          </div>
          <div className="grid gap-4 min-[480px]:grid-cols-2">
            <div className="space-y-1.5">
              <Label htmlFor="p-district">জেলা</Label>
              <Input
                id="p-district"
                value={district}
                onChange={(e) => setDistrict(e.target.value)}
                placeholder="যেমন: ঢাকা"
                className="h-12 rounded-xl"
              />
            </div>
            <div className="space-y-1.5">
              <Label htmlFor="p-workplace">কর্মস্থল</Label>
              <Input
                id="p-workplace"
                value={workplace}
                onChange={(e) => setWorkplace(e.target.value)}
                placeholder="যেমন: আস-সুন্নাহ ফাউন্ডেশন"
                className="h-12 rounded-xl"
              />
            </div>
          </div>
          <div className="space-y-1.5">
            <Label htmlFor="p-dept">বিভাগ</Label>
            <Input
              id="p-dept"
              value={department}
              onChange={(e) => setDepartment(e.target.value)}
              placeholder="যেমন: দাওয়াতুস সুন্নাহ"
              className="h-12 rounded-xl"
            />
          </div>
          <Button onClick={save} disabled={!dirty || saving || !name.trim()} className="w-full h-11 rounded-xl">
            {saving && <Loader2 className="size-4 animate-spin" />}
            {saving ? "সংরক্ষণ হচ্ছে…" : "সংরক্ষণ করুন"}
          </Button>
        </CardContent>
      </Card>

      {/* ভাষা */}
      <Card className="rounded-xl shadow-card">
        <CardContent className="p-4 sm:p-5 space-y-3">
          <SectionLabel>ভাষা</SectionLabel>
          <LangSelect
            value={user!.language}
            onChange={(lang) => {
              updateProfile({ language: lang });
              api
                .updateMe({ language: lang })
                .then((r) => setUser(r.user))
                .catch(() => toast.error("সার্ভারে সংরক্ষণ করা যায়নি"));
            }}
          />
        </CardContent>
      </Card>

      {/* নামাজ ও অবস্থান */}
      <PrayerSettingsControls />

      <Button
        variant="outline"
        className="w-full h-12 rounded-xl text-alert border-alert/30 hover:bg-alert-soft hover:text-alert"
        onClick={async () => {
          await api.logout().catch(() => null);
          setUser(null);
          setAuthModal(false);
          toast.success("সাইন আউট হয়েছে");
        }}
      >
        <LogOut className="size-4" /> সাইন আউট
      </Button>
    </div>
  );
}

function LangSelect({ value, onChange }: { value: Lang; onChange: (v: Lang) => void }) {
  return (
    <div className="space-y-1.5">
      <Label>ভাষা</Label>
      <Select value={value} onValueChange={(v) => onChange(v as Lang)}>
        <SelectTrigger className="h-12 rounded-xl w-full" aria-label="ভাষা নির্বাচন করুন">
          <SelectValue />
        </SelectTrigger>
        <SelectContent>
          {(["bn", "en", "ar"] as Lang[]).map((l) => (
            <SelectItem key={l} value={l} className="py-2.5">
              {LANG_LABELS[l]}
              {l === "ar" ? " (RTL)" : l === "bn" ? " (ডিফল্ট)" : ""}
            </SelectItem>
          ))}
        </SelectContent>
      </Select>
    </div>
  );
}
