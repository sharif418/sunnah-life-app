"use client";

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useApp, type Tab } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { api } from "@/lib/api";
import { AppTitle, LogoMark } from "@/components/app/logo";
import { AuthModal } from "@/components/app/auth-modal";
import { HomeView } from "@/components/home/home-view";
import { AmalView } from "@/components/amal/amal-view";
import { DawahView } from "@/components/dawah/dawah-view";
import { IlmView } from "@/components/ilm/ilm-view";
import { MoreView } from "@/components/more/more-view";
import { AdminConsole } from "@/components/admin/console";
import { Button } from "@/components/ui/button";
import { Sheet, SheetContent, SheetHeader, SheetTitle } from "@/components/ui/sheet";
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuLabel,
  DropdownMenuSeparator,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu";
import {
  Home,
  ClipboardCheck,
  Users,
  BookOpen,
  LayoutGrid,
  Bell,
  LogIn,
  LogOut,
  UserRound,
  ShieldCheck,
  CloudUpload,
  CloudOff,
  AlertTriangle,
  Moon,
  Sun,
} from "lucide-react";
import { useTheme } from "next-themes";
import { toast } from "sonner";
import type { ReminderItem, Role } from "@/types/domain";
import { ROLE_RANK, ROLE_LABELS_BN } from "@/types/domain";
import { cn } from "@/lib/utils";

const TABS: { key: Tab; icon: React.ElementType }[] = [
  { key: "home", icon: Home },
  { key: "amal", icon: ClipboardCheck },
  { key: "dawah", icon: Users },
  { key: "ilm", icon: BookOpen },
  { key: "more", icon: LayoutGrid },
];

/** Dawah is the Tarbiyah engine — visible only to daee and above (guests/users: 4 tabs). */
function visibleTabs(user: ReturnType<typeof useApp.getState>["user"]): typeof TABS {
  if (user && ROLE_RANK[user.role] >= ROLE_RANK.daee) return TABS;
  return TABS.filter((t) => t.key !== "dawah");
}

export function AppShell() {
  const { tab, profile, user, syncState } = useApp();
  const t = (k: string) => translate(profile.language, k);

  return (
    <div className="min-h-screen flex flex-col bg-background" dir={profile.language === "ar" ? "rtl" : "ltr"}>
      <Header />
      <main className="flex-1 w-full mx-auto max-w-6xl px-4 sm:px-6 pt-4 pb-28 lg:pb-12">
        <AnimatePresence mode="wait">
          <motion.div
            key={tab}
            initial={{ opacity: 0, y: 8 }}
            animate={{ opacity: 1, y: 0 }}
            exit={{ opacity: 0, y: -6 }}
            transition={{ duration: 0.12, ease: "easeOut" }}
          >
            {tab === "home" && <HomeView />}
            {tab === "amal" && <AmalView />}
            {tab === "dawah" && <DawahView />}
            {tab === "ilm" && <IlmView />}
            {tab === "more" && <MoreView />}
          </motion.div>
        </AnimatePresence>
      </main>

      {/* Bottom navigation (mobile) — the app's fixed footer */}
      <nav
        aria-label="মূল নেভিগেশন"
        className="lg:hidden fixed bottom-0 inset-x-0 z-40 border-t border-border bg-card/95 backdrop-blur supports-[backdrop-filter]:bg-card/85 safe-bottom"
      >
        <div
          className="grid max-w-lg mx-auto"
          style={{ gridTemplateColumns: `repeat(${visibleTabs(user).length}, minmax(0, 1fr))` }}
        >
          {visibleTabs(user).map(({ key, icon: Icon }) => {
            const active = tab === key;
            return (
              <button
                key={key}
                onClick={() => useApp.getState().nav(key)}
                aria-current={active ? "page" : undefined}
                className={cn(
                  "tap-target relative flex flex-col items-center justify-center gap-0.5 py-2.5 transition-colors",
                  active ? "text-primary" : "text-muted-foreground"
                )}
              >
                {active && (
                  <motion.span
                    layoutId="tab-pill"
                    className="absolute inset-x-3 top-1 h-8 rounded-full bg-primary-soft"
                    transition={{ type: "spring", bounce: 0.25, duration: 0.32 }}
                  />
                )}
                <Icon className={cn("relative size-5", active && "scale-110")} strokeWidth={active ? 2.4 : 1.8} />
                <span className={cn("relative text-[11px] font-medium", active && "font-semibold")}>
                  {t(`nav.${key}`)}
                </span>
              </button>
            );
          })}
        </div>
      </nav>

      <AuthModal />

      {syncState === "offline" && (
        <div className="fixed bottom-20 lg:bottom-4 inset-x-4 z-30 mx-auto max-w-sm flex items-center gap-2 rounded-xl bg-alert-soft text-alert px-3.5 py-2.5 text-sm shadow-lg border border-alert/20">
          <CloudOff className="size-4 shrink-0" />
          অফলাইন — আমল স্থানীয়ভাবে সংরক্ষিত হচ্ছে, ইন্টারনেট এলে সিঙ্ক হবে
        </div>
      )}

      <AdminOverlay />
    </div>
  );
}

function Header() {
  const { user, profile, tab, nav, setAuthModal, authChecked } = useApp();
  const { theme, setTheme } = useTheme();
  const [remindersOpen, setRemindersOpen] = React.useState(false);
  // If the active tab becomes gated (e.g. after logout), snap back to home.
  React.useEffect(() => {
    if (tab === "dawah" && user && ROLE_RANK[user.role] < ROLE_RANK.daee) nav("home");
  }, [tab, user, nav]);

  return (
    <header className="sticky top-0 z-40 border-b border-border bg-card/90 backdrop-blur supports-[backdrop-filter]:bg-card/80">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-3">
        <button className="flex items-center gap-2.5" onClick={() => nav("home")} aria-label="সুন্নাহ লাইফ হোম">
          <LogoMark size={38} />
          <AppTitle className="hidden min-[380px]:flex" />
        </button>

        {/* Desktop tabs */}
        <nav className="hidden lg:flex items-center gap-1 mx-auto" aria-label="ডেস্কটপ নেভিগেশন">
          {visibleTabs(user).map(({ key, icon: Icon }) => {
            const active = tab === key;
            return (
              <button
                key={key}
                onClick={() => nav(key)}
                className={cn(
                  "flex items-center gap-2 rounded-full px-4 py-2 text-sm font-medium transition-colors",
                  active ? "bg-primary-soft text-primary" : "text-muted-foreground hover:text-foreground hover:bg-muted"
                )}
              >
                <Icon className="size-4" />
                {translate(profile.language, `nav.${key}`)}
              </button>
            );
          })}
        </nav>

        <div className="lg:ms-0 ms-auto flex items-center gap-1.5">
          <SyncBadge />
          <NotificationsButton open={remindersOpen} onOpenChange={setRemindersOpen} />
          <ThemeToggle theme={theme} setTheme={setTheme} />

          {authChecked && !user ? (
            <Button size="sm" className="h-9 rounded-full" onClick={() => setAuthModal(true)}>
              <LogIn className="size-4 me-1" /> সাইন ইন
            </Button>
          ) : user ? (
            <ProfileMenu />
          ) : null}
        </div>
      </div>
    </header>
  );
}

function AdminOverlay() {
  const { adminOpen } = useApp();
  return <AnimatePresence>{adminOpen && <AdminConsole />}</AnimatePresence>;
}

function SyncBadge() {
  const { syncState, user } = useApp();
  if (!user || syncState === "idle") return null;
  if (syncState === "syncing")
    return (
      <span className="inline-flex size-9 items-center justify-center rounded-full text-primary animate-pulse" title="সিঙ্ক হচ্ছে…">
        <CloudUpload className="size-4" />
      </span>
    );
  if (syncState === "error")
    return (
      <span className="inline-flex size-9 items-center justify-center rounded-full text-warning" title="সিঙ্ক ব্যর্থ — পরে আবার চেষ্টা হবে">
        <AlertTriangle className="size-4" />
      </span>
    );
  return null;
}

function ThemeToggle({ theme, setTheme }: { theme: string | undefined; setTheme: (t: string) => void }) {
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
  return (
    <button
      aria-label="থিম পরিবর্তন"
      className="inline-flex size-9 items-center justify-center rounded-full text-muted-foreground hover:bg-muted transition-colors"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      {mounted && theme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />}
    </button>
  );
}

function NotificationsButton({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { user } = useApp();
  const [reminders, setReminders] = React.useState<ReminderItem[] | null>(null);
  const [loading, setLoading] = React.useState(false);
  const unread = reminders?.filter((r) => !r.read).length ?? 0;

  React.useEffect(() => {
    if (open && user) {
      setLoading(true);
      api
        .reminders()
        .then((r) => setReminders(r.reminders))
        .catch(() => setReminders([]))
        .finally(() => setLoading(false));
    }
  }, [open, user]);

  return (
    <>
      <button
        aria-label="নোটিফিকেশন"
        className="relative inline-flex size-9 items-center justify-center rounded-full text-muted-foreground hover:bg-muted transition-colors"
        onClick={() => onOpenChange(true)}
      >
        <Bell className="size-4" />
        {unread > 0 && <span className="absolute top-1.5 end-1.5 size-2 rounded-full bg-alert ring-2 ring-card" />}
      </button>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>রিমাইন্ডার ও ঘোষণা</SheetTitle>
          </SheetHeader>
          <div className="px-4 pb-6 max-h-96 overflow-y-auto scroll-thin">
            {!user ? (
              <p className="py-8 text-center text-sm text-muted-foreground leading-relaxed">
                সাইন ইন করলে উসরা ঘোষণা, সাপ্তাহিক রিভিউ ও লাইভ রিমাইন্ডার এখানে দেখা যাবে।
              </p>
            ) : loading ? (
              <div className="space-y-2 py-2">
                {[0, 1, 2].map((i) => (
                  <div key={i} className="h-16 rounded-xl bg-muted animate-pulse" />
                ))}
              </div>
            ) : reminders && reminders.length > 0 ? (
              <div className="space-y-2">
                {reminders.map((r) => (
                  <div key={r.id} className="rounded-xl border border-border bg-card p-3.5">
                    <div className="flex items-start justify-between gap-2">
                      <p className="font-semibold text-sm">{r.title}</p>
                      {!r.read && <span className="mt-1 size-2 shrink-0 rounded-full bg-primary" />}
                    </div>
                    {r.body && <p className="text-sm text-muted-foreground mt-1 leading-relaxed">{r.body}</p>}
                  </div>
                ))}
              </div>
            ) : (
              <div className="py-10 text-center">
                <div className="mx-auto size-16 rounded-full bg-primary-soft flex items-center justify-center">
                  <Bell className="size-7 text-primary/50" />
                </div>
                <p className="mt-3 text-sm text-muted-foreground">এখনো কোনো রিমাইন্ডার নেই</p>
              </div>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}

function ProfileMenu() {
  const { user, nav, setAdminOpen } = useApp();
  if (!user) return null;
  const isSupervisor = ROLE_RANK[user.role] >= ROLE_RANK.usrah_head;
  const initials = user.name.slice(0, 2);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          aria-label="প্রোফাইল মেনু"
          className="flex size-9 items-center justify-center rounded-full bg-primary text-primary-foreground text-sm font-bold ring-2 ring-gold/40"
        >
          {initials}
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="end" className="w-64 rounded-xl">
        <DropdownMenuLabel>
          <div className="flex items-center gap-2.5 py-0.5">
            <div className="flex size-10 items-center justify-center rounded-full bg-primary text-primary-foreground font-bold">
              {initials}
            </div>
            <div>
              <p className="font-semibold text-sm">{user.name}</p>
              <p className="text-xs text-muted-foreground">
                {ROLE_LABELS_BN[user.role as Role]}
                {user.memberCode ? ` · ${user.memberCode}` : ""}
              </p>
            </div>
          </div>
        </DropdownMenuLabel>
        <DropdownMenuSeparator />
        <DropdownMenuItem onClick={() => nav("more", "profile")} className="gap-2">
          <UserRound className="size-4" /> প্রোফাইল
        </DropdownMenuItem>
        {isSupervisor && (
          <DropdownMenuItem onClick={() => setAdminOpen(true)} className="gap-2">
            <ShieldCheck className="size-4" /> অ্যাডমিন প্যানেল
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem
          className="gap-2 text-alert focus:text-alert"
          onClick={async () => {
            await api.logout().catch(() => null);
            useApp.setState({ user: null });
            toast.success("সাইন আউট হয়েছে");
          }}
        >
          <LogOut className="size-4" /> সাইন আউট
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
