"use client";

// অ্যাপ কনফিগারেশন (full_admin) — W4h। GET/PATCH /api/admin/config: দানের লিংক,
// ডোমেইন, হিজরি ±adjust, নিসাব, যোগাযোগ (contacts), গ্রুপ/চ্যানেল (groups), অডিও
// বেস, লিডারবোর্ড/ডিটক্স ফিচার ফ্ল্যাগ। PATCH merge-সিমেন্টিক্স + mergeConfig
// যাচাই (খালি তালিকা পাঠালে আগেরটাই থেকে যায় — তাই শেষ সারি মোছা বন্ধ)। প্রতিটি
// সংরক্ষণ update_app_config অডিট লগ হয়।

import * as React from "react";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { Building2, Link2, Plus, Save, Settings, Trash2 } from "lucide-react";
import { api, type AdminAppConfig } from "@/lib/api";
import { useSession } from "@/lib/session";
import { toBn } from "@/lib/bn";
import { isFullAdmin } from "@/lib/labels";
import { Button } from "@/components/ui/button";
import { BoolToggle } from "@/components/ui/bool-toggle";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Field, Input, Textarea } from "@/components/ui/input";
import { ErrorState, PageHeading, RoleGate } from "@/components/ui/states";
import { useToast } from "@/components/ui/toast";

interface ContactForm {
  org: string;
  descBn: string;
  phone: string;
  email: string;
  website: string;
  address: string;
}

interface GroupForm {
  titleBn: string;
  url: string;
  descBn: string;
}

interface ConfigForm {
  donationUrl: string;
  domain: string;
  audioBase: string;
  hijriAdjust: string;
  goldPerGramBdt: string;
  silverPerGramBdt: string;
  leaderboardEnabled: boolean;
  detoxEnabled: boolean;
  contacts: ContactForm[];
  groups: GroupForm[];
}

function configToForm(c: AdminAppConfig): ConfigForm {
  return {
    donationUrl: c.donationUrl,
    domain: c.domain,
    audioBase: c.audioBase,
    hijriAdjust: String(c.hijriAdjust),
    goldPerGramBdt: String(c.nisab?.goldPerGramBdt ?? ""),
    silverPerGramBdt: String(c.nisab?.silverPerGramBdt ?? ""),
    leaderboardEnabled: !!c.leaderboardEnabled,
    detoxEnabled: !!c.detoxEnabled,
    contacts: (c.contacts ?? []).map((x) => ({
      org: x.org ?? "",
      descBn: x.descBn ?? "",
      phone: x.phone ?? "",
      email: x.email ?? "",
      website: x.website ?? "",
      address: x.address ?? "",
    })),
    groups: (c.groups ?? []).map((g) => ({
      titleBn: g.titleBn ?? "",
      url: g.url ?? "",
      descBn: g.descBn ?? "",
    })),
  };
}

function formToPatch(form: ConfigForm): Record<string, unknown> {
  const num = (v: string) => {
    const n = Number(v);
    return v !== "" && Number.isFinite(n) && n > 0 ? n : undefined;
  };
  const gold = num(form.goldPerGramBdt);
  const silver = num(form.silverPerGramBdt);
  return {
    donationUrl: form.donationUrl.trim(),
    domain: form.domain.trim(),
    audioBase: form.audioBase.trim(),
    hijriAdjust: Number(form.hijriAdjust) || 0,
    nisab: {
      ...(gold !== undefined ? { goldPerGramBdt: gold } : {}),
      ...(silver !== undefined ? { silverPerGramBdt: silver } : {}),
    },
    leaderboardEnabled: form.leaderboardEnabled,
    detoxEnabled: form.detoxEnabled,
    contacts: form.contacts
      .filter((c) => c.org.trim())
      .map((c) => ({
        org: c.org.trim(),
        descBn: c.descBn.trim(),
        ...(c.phone.trim() ? { phone: c.phone.trim() } : {}),
        ...(c.email.trim() ? { email: c.email.trim() } : {}),
        ...(c.website.trim() ? { website: c.website.trim() } : {}),
        ...(c.address.trim() ? { address: c.address.trim() } : {}),
      })),
    groups: form.groups
      .filter((g) => g.url.trim())
      .map((g) => ({
        titleBn: g.titleBn.trim(),
        url: g.url.trim(),
        ...(g.descBn.trim() ? { descBn: g.descBn.trim() } : {}),
      })),
  };
}

/** ফর্ম-বডি — mount-এ একবারই সার্ভার-ডেটা থেকে তৈরি; সংরক্ষণের পর PATCH-এর
 *  রেসপন্স (সম্পূর্ণ কনফিগ) নতুন key দিয়ে রিমাউন্ট হয় (revision প্যাটার্ন)। */
function SettingsForm({
  initial,
  onSaved,
}: {
  initial: AdminAppConfig;
  onSaved: (fresh: AdminAppConfig) => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [form, setForm] = React.useState<ConfigForm>(() => configToForm(initial));

  const save = useMutation({
    mutationFn: async () => {
      const hijri = Number(form.hijriAdjust);
      if (form.hijriAdjust !== "" && (!Number.isInteger(hijri) || Math.abs(hijri) > 2)) {
        throw new Error("হিজরি adjust −২ থেকে +২ এর মধ্যে হতে হবে");
      }
      return api.updateAdminConfig(formToPatch(form) as never);
    },
    onSuccess: (after) => {
      toast("সংরক্ষিত", "success");
      onSaved(after);
      qc.invalidateQueries({ queryKey: ["admin-config"] });
    },
    onError: (err: Error) => toast(err.message || "সংরক্ষণ করা যায়নি", "error"),
  });

  const set = <K extends keyof ConfigForm>(k: K, v: ConfigForm[K]) =>
    setForm((f) => ({ ...f, [k]: v }));

  const setContact = (i: number, patch: Partial<ContactForm>) =>
    setForm((f) => ({ ...f, contacts: f.contacts.map((x, idx) => (idx === i ? { ...x, ...patch } : x)) }));
  const setGroup = (i: number, patch: Partial<GroupForm>) =>
    setForm((f) => ({ ...f, groups: f.groups.map((x, idx) => (idx === i ? { ...x, ...patch } : x)) }));

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-end">
        <Button onClick={() => save.mutate()} disabled={save.isPending}>
          <Save className="h-4 w-4" aria-hidden />
          {save.isPending ? "সংরক্ষণ হচ্ছে…" : "সংরক্ষণ করুন"}
        </Button>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>সাধারণ</CardTitle>
          <CardDescription>দানের বাটন, শেয়ার-লিংকের ডোমেইন, অডিও বেস ইউআরএল</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Field label="দানের লিংক (donationUrl)" htmlFor="cf-donation">
            <Input
              id="cf-donation"
              value={form.donationUrl}
              onChange={(e) => set("donationUrl", e.target.value)}
              placeholder="https://as-sunnah.org/donation"
            />
          </Field>
          <Field label="ডোমেইন" htmlFor="cf-domain" hint="রেফারেল লিংক বানাতে ব্যবহার হয়">
            <Input
              id="cf-domain"
              value={form.domain}
              onChange={(e) => set("domain", e.target.value)}
              placeholder="sunnahlife.app"
            />
          </Field>
          <Field label="অডিও বেস ইউআরএল" htmlFor="cf-audio">
            <Input
              id="cf-audio"
              value={form.audioBase}
              onChange={(e) => set("audioBase", e.target.value)}
              className="font-mono text-xs"
            />
          </Field>
          <Field label="হিজরি adjust (−২..+২)" htmlFor="cf-hijri" hint="চান্দ্র তারিখ ±দিন ঠিক করতে">
            <Input
              id="cf-hijri"
              type="number"
              min={-2}
              max={2}
              step={1}
              value={form.hijriAdjust}
              onChange={(e) => set("hijriAdjust", e.target.value)}
            />
          </Field>
          <Field label="লিডারবোর্ড" hint="লিঙ্গ-পরিসর নিয়ে পণ্ডিতদের সিদ্ধান্ত বাকি — এখন বন্ধ রাখা ভালো">
            <BoolToggle
              value={form.leaderboardEnabled}
              onChange={(v) => set("leaderboardEnabled", v)}
              labels={["চালু", "বন্ধ"]}
              ariaLabel="লিডারবোর্ড"
            />
          </Field>
          <Field label="ডিজিটাল ডিটক্স" hint="নিষিদ্ধ বিনোদন থেকে সংযম ট্র্যাকিং ফিচার">
            <BoolToggle
              value={form.detoxEnabled}
              onChange={(v) => set("detoxEnabled", v)}
              labels={["চালু", "বন্ধ"]}
              ariaLabel="ডিজিটাল ডিটক্স"
            />
          </Field>
        </CardContent>
      </Card>

      <Card>
        <CardHeader>
          <CardTitle>যাকাতের নিসাব (প্রতি গ্রাম, টাকা)</CardTitle>
          <CardDescription>জাকাত ক্যালকুলেটর এই দরেই হিসাব করে — বাজার বদলালে এখানে হালনাগাদ করুন</CardDescription>
        </CardHeader>
        <CardContent className="grid grid-cols-1 gap-4 md:grid-cols-2">
          <Field label="স্বর্ণ (গ্রাম)" htmlFor="cf-gold">
            <Input
              id="cf-gold"
              type="number"
              min={0}
              step="any"
              value={form.goldPerGramBdt}
              onChange={(e) => set("goldPerGramBdt", e.target.value)}
            />
          </Field>
          <Field label="রুপা (গ্রাম)" htmlFor="cf-silver">
            <Input
              id="cf-silver"
              type="number"
              min={0}
              step="any"
              value={form.silverPerGramBdt}
              onChange={(e) => set("silverPerGramBdt", e.target.value)}
            />
          </Field>
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-2">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Building2 className="h-[18px] w-[18px] text-primary" aria-hidden />
              যোগাযোগ তালিকা ({toBn(form.contacts.length)})
            </CardTitle>
            <CardDescription>
              অ্যাপের «যোগাযোগ» অংশে দেখায় — নাম ছাড়া সারি বাদ যায়; খালি তালিকা রাখা যায় না (API
              আগেরটা রেখে দেয়)
            </CardDescription>
          </div>
          <Button
            variant="outline"
            size="sm"
            onClick={() =>
              set("contacts", [
                ...form.contacts,
                { org: "", descBn: "", phone: "", email: "", website: "", address: "" },
              ])
            }
          >
            <Plus className="h-4 w-4" aria-hidden />
            যোগাযোগ যোগ
          </Button>
        </CardHeader>
        <CardContent className="space-y-3">
          {form.contacts.map((c, i) => (
            <fieldset key={i} className="space-y-3 rounded-lg border border-border p-4">
              <legend className="px-1.5 text-xs font-bold text-muted-foreground">
                {toBn(i + 1)} নং সংস্থা
              </legend>
              <div className="flex items-start gap-2">
                <div className="grid flex-1 grid-cols-1 gap-3 sm:grid-cols-2">
                  <Field label="সংস্থার নাম *" htmlFor={`ct-org-${i}`}>
                    <Input id={`ct-org-${i}`} value={c.org} onChange={(e) => setContact(i, { org: e.target.value })} />
                  </Field>
                  <Field label="ওয়েবসাইট" htmlFor={`ct-web-${i}`}>
                    <Input
                      id={`ct-web-${i}`}
                      value={c.website}
                      onChange={(e) => setContact(i, { website: e.target.value })}
                      className="font-mono text-xs"
                    />
                  </Field>
                  <Field label="ফোন" htmlFor={`ct-phone-${i}`}>
                    <Input id={`ct-phone-${i}`} value={c.phone} onChange={(e) => setContact(i, { phone: e.target.value })} />
                  </Field>
                  <Field label="ইমেইল" htmlFor={`ct-mail-${i}`}>
                    <Input
                      id={`ct-mail-${i}`}
                      type="email"
                      value={c.email}
                      onChange={(e) => setContact(i, { email: e.target.value })}
                    />
                  </Field>
                </div>
                <Button
                  variant="ghost"
                  size="icon"
                  className="mt-6 text-alert hover:bg-alert-soft hover:text-alert"
                  onClick={() => {
                    if (form.contacts.length <= 1) {
                      toast("শেষ সারি মোছা যায় না — প্রয়োজন হলে ফাঁকা রাখুন", "error");
                      return;
                    }
                    set("contacts", form.contacts.filter((_, idx) => idx !== i));
                  }}
                  aria-label="যোগাযোগ সারি মুছুন"
                >
                  <Trash2 className="h-4 w-4" aria-hidden />
                </Button>
              </div>
              <Field label="বিবরণ (বাংলা)" htmlFor={`ct-desc-${i}`}>
                <Textarea
                  id={`ct-desc-${i}`}
                  value={c.descBn}
                  onChange={(e) => setContact(i, { descBn: e.target.value })}
                  className="min-h-[64px]"
                />
              </Field>
              <Field label="ঠিকানা" htmlFor={`ct-addr-${i}`}>
                <Input id={`ct-addr-${i}`} value={c.address} onChange={(e) => setContact(i, { address: e.target.value })} />
              </Field>
            </fieldset>
          ))}
        </CardContent>
      </Card>

      <Card>
        <CardHeader className="flex-row flex-wrap items-center justify-between gap-2">
          <div>
            <CardTitle className="flex items-center gap-2">
              <Link2 className="h-[18px] w-[18px] text-primary" aria-hidden />
              গ্রুপ ও চ্যানেল ({toBn(form.groups.length)})
            </CardTitle>
            <CardDescription>টেলিগ্রাম/ফেসবুক লিংক — লিংক ছাড়া সারি সংরক্ষণ হয় না</CardDescription>
          </div>
          <Button variant="outline" size="sm" onClick={() => set("groups", [...form.groups, { titleBn: "", url: "", descBn: "" }])}>
            <Plus className="h-4 w-4" aria-hidden />
            গ্রুপ যোগ
          </Button>
        </CardHeader>
        <CardContent className="space-y-3">
          {form.groups.map((g, i) => (
            <div key={i} className="grid grid-cols-1 gap-3 rounded-lg border border-border p-4 md:grid-cols-[1fr_1fr_auto]">
              <Field label="নাম (বাংলা)" htmlFor={`gr-title-${i}`}>
                <Input id={`gr-title-${i}`} value={g.titleBn} onChange={(e) => setGroup(i, { titleBn: e.target.value })} />
              </Field>
              <Field label="লিংক *" htmlFor={`gr-url-${i}`}>
                <Input
                  id={`gr-url-${i}`}
                  value={g.url}
                  onChange={(e) => setGroup(i, { url: e.target.value })}
                  className="font-mono text-xs"
                />
              </Field>
              <div className="flex items-end pb-0.5">
                <Button
                  variant="ghost"
                  size="icon"
                  className="text-alert hover:bg-alert-soft hover:text-alert"
                  onClick={() => {
                    if (form.groups.length <= 1) {
                      toast("শেষ সারি মোছা যায় না — প্রয়োজন হলে ফাঁকা রাখুন", "error");
                      return;
                    }
                    set("groups", form.groups.filter((_, idx) => idx !== i));
                  }}
                  aria-label="গ্রুপ সারি মুছুন"
                >
                  <Trash2 className="h-4 w-4" aria-hidden />
                </Button>
              </div>
              <Field label="বিবরণ (বাংলা)" htmlFor={`gr-desc-${i}`} className="md:col-span-2">
                <Input id={`gr-desc-${i}`} value={g.descBn} onChange={(e) => setGroup(i, { descBn: e.target.value })} />
              </Field>
            </div>
          ))}
        </CardContent>
      </Card>
    </div>
  );
}

export default function SettingsPage() {
  const { user } = useSession();
  const fullAdmin = isFullAdmin(user?.role);

  const config = useQuery({
    queryKey: ["admin-config"],
    queryFn: () => api.adminConfig(),
    enabled: fullAdmin,
  });
  /** PATCH-এর রেসপন্স (সম্পূর্ণ কনফিগ) — সংরক্ষণের পর ফর্ম এটা দিয়েই রিমাউন্ট। */
  const [saved, setSaved] = React.useState<AdminAppConfig | null>(null);

  return (
    <RoleGate allow={isFullAdmin} role={user?.role}>
      <div className="space-y-6">
        <PageHeading
          icon={<Settings className="h-6 w-6" aria-hidden />}
          title="অ্যাপ কনফিগারেশন"
          description="অ্যাপ-জুড়ে কনফিগ — দানের লিংক, হিজরি তারিখ ঠিককরণ, নিসাবের দর, যোগাযোগ ও গ্রুপের তালিকা। প্রতিটি সংরক্ষণ অডিট-লগড।"
        />

        {config.isLoading ? (
          <div className="space-y-3">
            <div className="skeleton h-12" />
            <div className="skeleton h-48" />
            <div className="skeleton h-64" />
          </div>
        ) : config.isError ? (
          <ErrorState error={config.error} onRetry={() => config.refetch()} />
        ) : config.data ? (
          <SettingsForm key={saved ? "saved" : "initial"} initial={saved ?? config.data} onSaved={setSaved} />
        ) : null}
      </div>
    </RoleGate>
  );
}
