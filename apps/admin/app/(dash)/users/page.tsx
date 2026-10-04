"use client";

import * as React from "react";
import Link from "next/link";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import type { ColumnDef } from "@tanstack/react-table";
import { ArrowUpRight, Search, TrendingUp, UserCog } from "lucide-react";
import { api, type Gender, type Level, type Role, type User, type UserCategory } from "@/lib/api";
import { useSession } from "@/lib/session";
import { relativeBn, toBn } from "@/lib/bn";
import {
  CATEGORY_LABELS_BN,
  LEVEL_LABELS_BN,
  LEVEL_ORDER,
  ROLE_LABELS_BN,
  isFullAdmin,
} from "@/lib/labels";
import { CategoryBadge, GenderBadge, LevelBadge, RoleBadge } from "@/components/badges";
import { Badge } from "@/components/ui/badge";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { DataTable } from "@/components/ui/data-table";
import { Dialog } from "@/components/ui/dialog";
import { Field, Input, Select, Textarea } from "@/components/ui/input";
import { useToast } from "@/components/ui/toast";
import { PageHeading } from "@/components/ui/states";

const SAVED_FILTER_KEY = "sl_admin_users_filter_v1";

interface SavedFilter {
  q: string;
  role: string;
  gender: string;
}

function EditUserDialog({
  user,
  usrahs,
  onClose,
  onPromote,
}: {
  user: User | null;
  usrahs: { id: string; name: string; gender: Gender }[];
  onClose: () => void;
  onPromote: (u: User) => void;
}) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [role, setRole] = React.useState<Role>("user");
  const [gender, setGender] = React.useState<Gender>("M");
  const [usrahId, setUsrahId] = React.useState<string>("");
  const [category, setCategory] = React.useState<UserCategory>("general");

  // Sync the form when the target user changes — render-phase adjustment.
  const [syncedUserId, setSyncedUserId] = React.useState<string | null>(user?.id ?? null);
  if ((user?.id ?? null) !== syncedUserId) {
    setSyncedUserId(user?.id ?? null);
    setRole(user!.role);
    setGender(user!.gender);
    setUsrahId(user!.usrahId ?? "");
    setCategory(user!.category);
  }

  const patch = useMutation({
    mutationFn: (dto: Parameters<typeof api.patchUser>[0]) => api.patchUser(dto),
    onSuccess: (res) => {
      toast(`${res.user.name} — পরিবর্তন সংরক্ষিত হয়েছে (অডিট লগড)`, "success");
      qc.invalidateQueries({ queryKey: ["admin-users"] });
      qc.invalidateQueries({ queryKey: ["admin-overview"] });
      onClose();
    },
    onError: (err: Error) => toast(err.message, "error"),
  });

  const [reason, setReason] = React.useState("");
  const [syncedGenderFor, setSyncedGenderFor] = React.useState<string | null>(user?.id ?? null);
  if ((user?.id ?? null) !== syncedGenderFor) {
    setSyncedGenderFor(user?.id ?? null);
    setReason("");
  }

  const save = () => {
    if (!user) return;
    const same =
      role === user.role &&
      gender === user.gender &&
      (usrahId || null) === user.usrahId &&
      category === user.category;
    if (same) {
      toast("কোনো পরিবর্তন হয়নি", "info");
      return;
    }
    if (gender !== user.gender && !reason.trim()) {
      toast("লিঙ্গ পরিবর্তনের কারণ লিখুন (বাংলায়)", "error");
      return;
    }
    patch.mutate({
      userId: user.id,
      role,
      gender,
      usrahId: usrahId || null,
      category,
      ...(gender !== user.gender ? { reason: reason.trim() } : {}),
    });
  };

  const genderChanged = user ? gender !== user.gender : false;

  return (
    <Dialog
      open={user !== null}
      onClose={onClose}
      title={`ভূমিকা ও অ্যাসাইনমেন্ট — ${user?.name ?? ""}`}
      description="ভূমিকা ও লিঙ্গ পরিবর্তন অডিট লগে সংরক্ষিত হয় · দায়ী বানালে সদস্য কোড স্বয়ংক্রিয়ভাবে তৈরি হয়"
      footer={
        <>
          <Button
            variant="ghost"
            onClick={() => user && onPromote(user)}
            disabled={patch.isPending}
          >
            <TrendingUp className="h-4 w-4" aria-hidden />
            স্তর উন্নয়ন…
          </Button>
          <Button variant="outline" onClick={onClose} disabled={patch.isPending}>
            বাতিল
          </Button>
          <Button onClick={save} loading={patch.isPending}>
            সংরক্ষণ করুন
          </Button>
        </>
      }
    >
      {user ? (
        <div className="space-y-4">
          <div className="grid grid-cols-2 gap-3 rounded-md border border-border bg-muted/40 p-3 text-sm">
            <div>
              <p className="text-xs text-muted-foreground">নাম</p>
              <p className="font-semibold">{user.name}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">ফোন</p>
              <p dir="ltr" className="font-mono">{toBn(user.phone ?? "—")}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">সদস্য কোড</p>
              <p className="font-mono">{user.memberCode ?? "—"}</p>
            </div>
            <div>
              <p className="text-xs text-muted-foreground">স্তর</p>
              <p>{LEVEL_LABELS_BN[user.level]}</p>
            </div>
          </div>

          <Field label="ভূমিকা" htmlFor="edit-role">
            <Select id="edit-role" value={role} onChange={(e) => setRole(e.target.value as Role)}>
              {(Object.keys(ROLE_LABELS_BN) as Role[]).map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABELS_BN[r]}
                </option>
              ))}
            </Select>
          </Field>

          <Field
            label="লিঙ্গ"
            htmlFor="edit-gender"
            hint="লিঙ্গ পরিবর্তন নারী-তথ্য সুরক্ষা নীতির সাথে সম্পর্কিত — অডিট লগে লিপিবদ্ধ হবে"
          >
            <Select
              id="edit-gender"
              value={gender}
              onChange={(e) => setGender(e.target.value as Gender)}
            >
              <option value="M">পুরুষ</option>
              <option value="F">নারী</option>
            </Select>
          </Field>

          {genderChanged ? (
            <div className="space-y-2">
              <p className="rounded-md border border-alert/40 bg-alert-soft/70 p-3 text-sm text-alert">
                ⚠ লিঙ্গ পরিবর্তন করলে সদস্যের উসরা ও পরিদর্শক-পরিসর বদলে যেতে পারে — প্রয়োজনে উসরাও
                আবার নির্বাচন করুন। কারণসহ অডিট লগে লিপিবদ্ধ হবে।
              </p>
              <Field label="পরিবর্তনের কারণ (বাংলায়)" htmlFor="edit-gender-reason" hint="অডিট লগে সংরক্ষিত হবে">
                <Textarea
                  id="edit-gender-reason"
                  value={reason}
                  onChange={(e) => setReason(e.target.value)}
                  rows={2}
                  placeholder="যেমন: ভুল তথ্য সংশোধন — সদস্য নিজে অনুরোধ করেছেন"
                  aria-label="লিঙ্গ পরিবর্তনের কারণ"
                />
              </Field>
            </div>
          ) : null}

          <Field label="উসরা" htmlFor="edit-usrah">
            <Select id="edit-usrah" value={usrahId} onChange={(e) => setUsrahId(e.target.value)}>
              <option value="">— কোনো উসরায় নেই —</option>
              {usrahs
                .filter((u) => u.gender === gender)
                .map((u) => (
                  <option key={u.id} value={u.id}>
                    {u.name}
                  </option>
                ))}
            </Select>
          </Field>

          <Field label="ক্যাটাগরি" htmlFor="edit-category" hint="তিলাওয়াতের লক্ষ্যমাত্রা ক্যাটাগরি অনুযায়ী নির্ধারিত">
            <Select
              id="edit-category"
              value={category}
              onChange={(e) => setCategory(e.target.value as UserCategory)}
            >
              {(Object.keys(CATEGORY_LABELS_BN) as UserCategory[]).map((c) => (
                <option key={c} value={c}>
                  {CATEGORY_LABELS_BN[c]}
                </option>
              ))}
            </Select>
          </Field>
        </div>
      ) : null}
    </Dialog>
  );
}

function PromoteDialog({ user, onClose }: { user: User | null; onClose: () => void }) {
  const { toast } = useToast();
  const qc = useQueryClient();
  const [toLevel, setToLevel] = React.useState<Level>("muhibbus_sunnah");
  const [reason, setReason] = React.useState("");

  // Default the picker to the user's NEXT level — render-phase adjustment.
  const [syncedLevelFor, setSyncedLevelFor] = React.useState<string | null>(user?.id ?? null);
  if ((user?.id ?? null) !== syncedLevelFor) {
    setSyncedLevelFor(user?.id ?? null);
    const idx = LEVEL_ORDER.indexOf(user!.level);
    setToLevel(LEVEL_ORDER[Math.min(idx + 1, LEVEL_ORDER.length - 1)]);
    setReason("");
  }

  const promote = useMutation({
    mutationFn: () => api.promote(user!.id, toLevel, reason.trim()),
    onSuccess: (res) => {
      toast(`${res.user.name} — ${LEVEL_LABELS_BN[res.user.level]} স্তরে উন্নীত হয়েছেন`, "success");
      qc.invalidateQueries({ queryKey: ["admin-users"] });
      qc.invalidateQueries({ queryKey: ["level-transitions"] });
      qc.invalidateQueries({ queryKey: ["audit-log"] });
      onClose();
    },
    onError: (err: Error) => toast(err.message, "error"),
  });

  const submit = () => {
    if (!reason.trim()) {
      toast("উন্নয়নের কারণ বাংলায় লিখুন", "error");
      return;
    }
    promote.mutate();
  };

  return (
    <Dialog
      open={user !== null}
      onClose={onClose}
      title={`স্তর উন্নয়ন — ${user?.name ?? ""}`}
      description="মুহিব্বুস সুন্নাহ উন্নয়নে শর্ত যাচাই সার্ভার করে — অপূর্ণ শর্ত থাকলে বাকি শর্তগুলো দেখানো হবে"
      footer={
        <>
          <Button variant="outline" onClick={onClose} disabled={promote.isPending}>
            বাতিল
          </Button>
          <Button onClick={submit} loading={promote.isPending}>
            <TrendingUp className="h-4 w-4" aria-hidden />
            উন্নয়ন করুন
          </Button>
        </>
      }
    >
      {user ? (
        <div className="space-y-4">
          <div className="flex flex-wrap items-center gap-2 text-sm">
            <span className="text-muted-foreground">বর্তমান:</span>
            <LevelBadge level={user.level} />
            <ArrowUpRight className="h-4 w-4 text-muted-foreground" aria-hidden />
            <span className="text-muted-foreground">নতুন:</span>
          </div>
          <Field label="নতুন স্তর" htmlFor="promote-level">
            <Select id="promote-level" value={toLevel} onChange={(e) => setToLevel(e.target.value as Level)}>
              {LEVEL_ORDER.map((l) => (
                <option key={l} value={l} disabled={l === user.level}>
                  {LEVEL_LABELS_BN[l]}
                </option>
              ))}
            </Select>
          </Field>
          <Field
            label="উন্নয়নের কারণ (বাংলায়)"
            htmlFor="promote-reason"
            hint="স্তরের ইতিহাসে ও কার্যক্রমের রেকর্ডে থাকবে"
          >
            <Textarea
              id="promote-reason"
              value={reason}
              onChange={(e) => setReason(e.target.value)}
              rows={2}
              placeholder="যেমন: তারবিয়াত পরিষদের সিদ্ধান্তে সকল শর্ত পূরণ হয়েছে"
              aria-label="উন্নয়নের কারণ"
            />
          </Field>
          <p className="rounded-md border border-gold/40 bg-gold-soft/70 p-3 text-xs leading-relaxed">
            উন্নয়নের কারণ আপনার নামসহ স্তরের ইতিহাসে লেখা থাকে, আর সদস্য অ্যাপে অভিনন্দন বার্তা পান।
            মুহিব্বুস সুন্নাহ স্তরে ওঠানোর আগে শর্তগুলো যাচাই হয় — কোনো শর্ত বাকি থাকলে তা এখানে দেখানো হবে।
          </p>
        </div>
      ) : null}
    </Dialog>
  );
}

export default function UsersPage() {
  const { user: me, fullAdmin } = useSession();
  const { toast } = useToast();
  const [q, setQ] = React.useState("");
  const [debouncedQ, setDebouncedQ] = React.useState("");
  const [roleFilter, setRoleFilter] = React.useState("");
  const [genderFilter, setGenderFilter] = React.useState("");
  const [editing, setEditing] = React.useState<User | null>(null);
  const [promoting, setPromoting] = React.useState<User | null>(null);

  // saved filters (localStorage)
  // Restore saved filters after mount (localStorage is an external system —
  // deferred to a microtask so the effect body stays sync-free and
  // hydration-safe).
  React.useEffect(() => {
    let cancelled = false;
    Promise.resolve().then(() => {
      if (cancelled) return;
      try {
        const raw = window.localStorage.getItem(SAVED_FILTER_KEY);
        if (raw) {
          const f = JSON.parse(raw) as SavedFilter;
          setRoleFilter(f.role ?? "");
          setGenderFilter(f.gender ?? "");
        }
      } catch {
        /* ignore corrupt state */
      }
    });
    return () => {
      cancelled = true;
    };
  }, []);

  React.useEffect(() => {
    const t = window.setTimeout(() => setDebouncedQ(q), 350);
    return () => window.clearTimeout(t);
  }, [q]);

  const users = useQuery({
    queryKey: ["admin-users", debouncedQ],
    queryFn: () => api.users(debouncedQ),
  });
  const overview = useQuery({
    queryKey: ["admin-overview"],
    queryFn: () => api.overview(),
    enabled: fullAdmin,
  });

  const saveFilter = () => {
    const f: SavedFilter = { q, role: roleFilter, gender: genderFilter };
    window.localStorage.setItem(SAVED_FILTER_KEY, JSON.stringify(f));
    toast("ফিল্টার সংরক্ষিত হয়েছে — পরের বার এই পাতায় স্বয়ংক্রিয় প্রয়োগ হবে", "success");
  };

  const filtered = React.useMemo(() => {
    let list = users.data?.users ?? [];
    if (roleFilter) list = list.filter((u) => u.role === roleFilter);
    if (genderFilter) list = list.filter((u) => u.gender === genderFilter);
    return list;
  }, [users.data, roleFilter, genderFilter]);

  const columns = React.useMemo<ColumnDef<User, unknown>[]>(
    () => [
      {
        accessorKey: "name",
        header: "নাম",
        cell: ({ row }) => (
          <div className="min-w-0">
            <span className="block truncate font-semibold">{row.original.name}</span>
            <span className="block text-[11px] text-muted-foreground" dir="ltr">
              {row.original.phone ? toBn(row.original.phone) : ""}
              {row.original.memberCode ? ` · ${row.original.memberCode}` : ""}
            </span>
          </div>
        ),
      },
      {
        accessorKey: "gender",
        header: "লিঙ্গ",
        cell: ({ row }) => <GenderBadge gender={row.original.gender} />,
      },
      {
        accessorKey: "role",
        header: "ভূমিকা",
        cell: ({ row }) => <RoleBadge role={row.original.role} />,
      },
      {
        accessorKey: "level",
        header: "স্তর",
        cell: ({ row }) => <LevelBadge level={row.original.level} />,
      },
      {
        accessorKey: "usrahName",
        header: "উসরা",
        cell: ({ row }) => (
          <span className="text-sm text-muted-foreground">{row.original.usrahName ?? "—"}</span>
        ),
      },
      {
        accessorKey: "category",
        header: "ক্যাটাগরি",
        cell: ({ row }) => <CategoryBadge category={row.original.category} />,
      },
      {
        accessorKey: "lastActiveAt",
        header: "সর্বশেষ সক্রিয়",
        cell: ({ row }) => (
          <span className="text-xs text-muted-foreground">{relativeBn(row.original.lastActiveAt)}</span>
        ),
      },
    ],
    []
  );

  if (!isFullAdmin(me?.role)) {
    return (
      <Card>
        <CardContent className="flex flex-col items-center gap-3 pt-6 text-center">
          <div className="flex h-14 w-14 items-center justify-center rounded-full bg-alert-soft text-alert">
            <UserCog className="h-7 w-7" aria-hidden />
          </div>
          <h2 className="text-lg font-bold">শুধুমাত্র প্রধান অ্যাডমিনের জন্য</h2>
          <p className="max-w-md text-sm text-muted-foreground">
            ব্যবহারকারী ব্যবস্থাপনা (ভূমিকা, লিঙ্গ, উসরা, ক্যাটাগরি পরিবর্তন ও স্তর উন্নয়ন) প্রধান
            অ্যাডমিনের এক্তিয়ারভুক্ত।
          </p>
        </CardContent>
      </Card>
    );
  }

  return (
    <div className="space-y-4">
      <PageHeading
        icon={<UserCog className="h-6 w-6" aria-hidden />}
        title="সদস্য তালিকা"
        description="নাম, ফোন বা সদস্য কোড দিয়ে খুঁজুন — সারিতে চাপ দিয়ে ভূমিকা, উসরা বা স্তর বদলান।"
      />
      <Card>
        <CardHeader>
          <CardTitle className="flex flex-wrap items-center justify-between gap-2">
            সব সদস্য
            {fullAdmin ? (
              <Link
                href="/users/import"
                className="focus-ring inline-flex min-h-9 items-center rounded-md border border-border px-3 text-sm font-semibold hover:bg-primary-soft"
              >
                এক্সেল (CSV) থেকে সদস্য যোগ
              </Link>
            ) : null}
          </CardTitle>
          <CardDescription>
            নাম · ফোন · সদস্য কোড দিয়ে অনুসন্ধান — সারিতে ক্লিক করে সম্পাদনা করুন (ভূমিকা/লিঙ্গ পরিবর্তন
            অডিট-লগড)
          </CardDescription>
        </CardHeader>
        <CardContent className="space-y-3">
          <div className="flex flex-wrap items-end gap-2">
            <div className="relative min-w-56 flex-1">
              <Search
                className="pointer-events-none absolute left-3 top-1/2 h-4 w-4 -translate-y-1/2 text-muted-foreground"
                aria-hidden
              />
              <Input
                aria-label="ব্যবহারকারী খুঁজুন"
                placeholder="নাম, ফোন বা DS-কোড লিখুন…"
                value={q}
                onChange={(e) => setQ(e.target.value)}
                className="pl-9"
              />
            </div>
            <Select
              aria-label="ভূমিকা ফিল্টার"
              value={roleFilter}
              onChange={(e) => setRoleFilter(e.target.value)}
              className="w-40"
            >
              <option value="">সব ভূমিকা</option>
              {(Object.keys(ROLE_LABELS_BN) as Role[]).map((r) => (
                <option key={r} value={r}>
                  {ROLE_LABELS_BN[r]}
                </option>
              ))}
            </Select>
            <Select
              aria-label="লিঙ্গ ফিল্টার"
              value={genderFilter}
              onChange={(e) => setGenderFilter(e.target.value)}
              className="w-32"
            >
              <option value="">উভয় লিঙ্গ</option>
              <option value="M">পুরুষ</option>
              <option value="F">নারী</option>
            </Select>
            <Button variant="secondary" onClick={saveFilter}>
              ফিল্টার সংরক্ষণ
            </Button>
            <Link href="/referrals" className="focus-ring rounded">
              <Button variant="outline">
                রেফারেল ট্রি দেখুন
              </Button>
            </Link>
          </div>

          <DataTable
            columns={columns}
            data={filtered}
            loading={users.isLoading}
            error={users.error}
            onRetry={() => users.refetch()}
            onRowClick={(u) => setEditing(u)}
            rowAriaLabel={(u) => `${u.name} — সম্পাদনা করুন`}
            emptyTitle={debouncedQ ? "অনুসন্ধানে কোনো ব্যবহারকারী মেলেনি" : "কোনো ব্যবহারকারী নেই"}
            emptyHint={debouncedQ ? "বানান পরীক্ষা করে আবার চেষ্টা করুন।" : undefined}
            csvFilename="users.csv"
            csvHeaders={["নাম", "ফোন", "সদস্য কোড", "লিঙ্গ", "ভূমিকা", "স্তর", "ক্যাটাগরি", "উসরা", "সর্বশেষ সক্রিয়"]}
            csvRow={(u) => [
              u.name,
              u.phone ?? "",
              u.memberCode ?? "",
              u.gender === "M" ? "পুরুষ" : "নারী",
              ROLE_LABELS_BN[u.role],
              LEVEL_LABELS_BN[u.level],
              CATEGORY_LABELS_BN[u.category],
              u.usrahName ?? "",
              u.lastActiveAt,
            ]}
          />

          <p className="text-xs text-muted-foreground">
            কোনো সারিতে ক্লিক করলে সম্পাদনা ডায়ালগ খুলবে — সেখান থেকেই ভূমিকা/লিঙ্গ/উসরা পরিবর্তন ও
            স্তর উন্নয়ন করা যায়। প্রোফাইল দেখতে মূল্যায়ন বা উসরা পাতা ব্যবহার করুন।
          </p>
        </CardContent>
      </Card>

      <EditUserDialog
        user={editing}
        usrahs={overview.data?.usrahs ?? []}
        onClose={() => setEditing(null)}
        onPromote={(u) => {
          setEditing(null);
          setPromoting(u);
        }}
      />
      <PromoteDialog user={promoting} onClose={() => setPromoting(null)} />
    </div>
  );
}
