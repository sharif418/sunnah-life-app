"use client";

// অ্যাপ শেল — §3.3 টপ নেভিগেশন: সবুজ হেডারে হোম/আর্টিকেল-রুলস/সেবা/আমাদের
// সম্পর্কে + স্থায়ী হাইলাইটে সোনালি "দান করুন" + নোটিফিকেশন/রিমাইন্ডার +
// লগইন/প্রোফাইল। মোবাইল প্রস্থে সব হ্যামবার্গার শিটে, নিচে ৫-ট্যাব বার।

import * as React from "react";
import { AnimatePresence, motion } from "framer-motion";
import { useApp, type Tab } from "@/lib/store";
import { translate } from "@/lib/i18n";
import { api } from "@/lib/api";
import { AppTitle, LogoMark } from "@/components/app/logo";
import { AuthModal } from "@/components/app/auth-modal";
import { InstallPrompt } from "@/components/app/install-prompt";
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
  Menu,
  ChevronDown,
  HeartHandshake,
  Calculator,
  Compass,
  Landmark,
  MessageCircleQuestion,
  Link as LinkIcon,
  AlarmClock,
  Newspaper,
  Info,
} from "lucide-react";
import { useTheme } from "next-themes";
import { toast } from "sonner";
import type { ReminderItem, Role } from "@/types/domain";
import { ROLE_RANK, ROLE_LABELS_BN } from "@/types/domain";
import { cn } from "@/lib/utils";
import { useDonationUrl } from "@/hooks/use-donation-url";

const TABS: { key: Tab; icon: React.ElementType }[] = [
  { key: "home", icon: Home },
  { key: "amal", icon: ClipboardCheck },
  { key: "dawah", icon: Users },
  { key: "ilm", icon: BookOpen },
  { key: "more", icon: LayoutGrid },
];

/** সেবা — মোর ট্যাবের যন্ত্রপাতি; টপ-নেভিগেশন ও মোবাইল শিট উভয় জায়গায় একই তালিকা। */
const SERVICES: { view: string; icon: React.ElementType }[] = [
  { view: "zakat", icon: Calculator },
  { view: "qibla", icon: Compass },
  { view: "mosques", icon: Landmark },
  { view: "masala", icon: MessageCircleQuestion },
  { view: "contacts", icon: LinkIcon },
  { view: "settings", icon: AlarmClock },
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
    <div className="min-h-screen flex flex-col bg-background">
      <Header />
      <main className="flex-1 w-full mx-auto max-w-6xl px-4 sm:px-6 pt-4 pb-28 xl:pb-12">
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

      {/* Bottom navigation (mobile) — the app's fixed footer; desktop moves
          to the top nav at xl. */}
      <nav
        aria-label={t("nav.primary")}
        className="xl:hidden fixed bottom-0 inset-x-0 z-40 border-t border-border bg-card/95 backdrop-blur supports-[backdrop-filter]:bg-card/85 safe-bottom"
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
      <InstallPrompt />

      {syncState === "offline" && (
        <div className="fixed bottom-20 xl:bottom-4 inset-x-4 z-30 mx-auto max-w-sm flex items-center gap-2 rounded-xl bg-alert-soft text-alert px-3.5 py-2.5 text-sm shadow-lg border border-alert/20">
          <CloudOff className="size-4 shrink-0" />
          {t("offline.message")}
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
  const [menuOpen, setMenuOpen] = React.useState(false);
  const donationUrl = useDonationUrl();
  const lang = profile.language;
  const t = (k: string) => translate(lang, k);
  // If the active tab becomes gated (e.g. after logout), snap back to home.
  React.useEffect(() => {
    if (tab === "dawah" && user && ROLE_RANK[user.role] < ROLE_RANK.daee) nav("home");
  }, [tab, user, nav]);

  const pill = (active: boolean) =>
    cn(
      "flex items-center gap-1.5 rounded-full px-3 py-2 text-[13.5px] font-medium transition-colors whitespace-nowrap",
      active
        ? "bg-primary-foreground/15 text-primary-foreground font-semibold"
        : "text-primary-foreground/80 hover:text-primary-foreground hover:bg-primary-foreground/10"
    );

  return (
    <header className="sticky top-0 z-40 bg-primary text-primary-foreground">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 h-16 flex items-center gap-2.5">
        <button
          className="flex items-center gap-2.5"
          onClick={() => nav("home")}
          aria-label={`${t("app.name")} — ${t("nav.home")}`}
        >
          <LogoMark size={38} />
          <AppTitle className="hidden min-[420px]:flex text-primary-foreground" />
        </button>

        {/* Desktop top nav — স্পেক §3.3: হোম, আর্টিকেল/রুলস, সেবা, আমাদের সম্পর্কে
            (+ the app's own আমল/দাওয়াত/ইলম tabs, which the bottom bar owns < xl). */}
        <nav className="hidden xl:flex items-center gap-0.5 mx-auto" aria-label={t("nav.top")}>
          {visibleTabs(user).map(({ key, icon: Icon }) => (
            <button key={key} onClick={() => nav(key)} className={pill(tab === key)}>
              <Icon className="size-4" />
              {t(`nav.${key}`)}
            </button>
          ))}
          <button onClick={() => nav("ilm", "articles")} className={pill(false)}>
            <Newspaper className="size-4" />
            {t("nav.articles")}
          </button>
          <ServicesMenu pill={pill(false)} lang={lang} />
          <button onClick={() => nav("more", "about")} className={pill(false)}>
            <Info className="size-4" />
            {t("nav.about")}
          </button>
        </nav>

        <div className="ms-auto xl:ms-0 flex items-center gap-1.5">
          <SyncBadge />
          <NotificationsButton open={remindersOpen} onOpenChange={setRemindersOpen} />

          {/* দান করুন — the ONLY gold-filled element in the header, permanently highlighted. */}
          <a
            href={donationUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="tap-target inline-flex h-9 shrink-0 items-center gap-1.5 rounded-full bg-gold px-3.5 sm:px-4 text-sm font-bold text-gold-foreground shadow-sm transition-colors hover:bg-gold/85"
          >
            <HeartHandshake className="size-4" />
            <span className="hidden min-[420px]:inline">{t("nav.donate")}</span>
          </a>

          <ThemeToggle
            theme={theme}
            setTheme={setTheme}
            className="hidden xl:inline-flex text-primary-foreground/85 hover:bg-primary-foreground/10"
          />

          {authChecked && !user ? (
            <Button
              size="sm"
              className="hidden xl:inline-flex h-9 rounded-full bg-primary-foreground/10 text-primary-foreground hover:bg-primary-foreground/20 hover:text-primary-foreground"
              onClick={() => setAuthModal(true)}
            >
              <LogIn className="size-4 me-1" /> {t("auth.signIn")}
            </Button>
          ) : user ? (
            <ProfileMenu />
          ) : null}

          <button
            aria-label={t("nav.menu")}
            className="xl:hidden tap-target inline-flex size-9 items-center justify-center rounded-full text-primary-foreground/85 hover:bg-primary-foreground/10 transition-colors"
            onClick={() => setMenuOpen(true)}
          >
            <Menu className="size-5" />
          </button>
        </div>
      </div>

      <MobileMenuSheet open={menuOpen} onOpenChange={setMenuOpen} onOpenReminders={() => setRemindersOpen(true)} />
    </header>
  );
}

/** সেবা ড্রপডাউন (desktop) — more-view-এর সাব-ভিউগুলোর শর্টকাট। */
function ServicesMenu({ pill, lang }: { pill: string; lang: ReturnType<typeof useApp.getState>["profile"]["language"] }) {
  const t = (k: string) => translate(lang, k);
  const nav = useApp((s) => s.nav);
  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button className={pill}>
          {t("nav.services")}
          <ChevronDown className="size-3.5 opacity-70" />
        </button>
      </DropdownMenuTrigger>
      <DropdownMenuContent align="start" className="rounded-xl">
        {SERVICES.map(({ view, icon: Icon }) => (
          <DropdownMenuItem key={view} className="gap-2.5" onClick={() => nav("more", view)}>
            <Icon className="size-4" /> {t(`more.${view === "settings" ? "prayerSettings" : view}`)}
          </DropdownMenuItem>
        ))}
      </DropdownMenuContent>
    </DropdownMenu>
  );
}

/** হ্যামবার্গার শিট (mobile-width) — পুরো টপ-নেভিগেশন + অ্যাকাউন্ট + দান। */
function MobileMenuSheet({
  open,
  onOpenChange,
  onOpenReminders,
}: {
  open: boolean;
  onOpenChange: (v: boolean) => void;
  onOpenReminders: () => void;
}) {
  const { user, profile, nav, setAuthModal, setAdminOpen } = useApp();
  const { theme, setTheme } = useTheme();
  const donationUrl = useDonationUrl();
  const lang = profile.language;
  const t = (k: string) => translate(lang, k);
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);

  const close = () => onOpenChange(false);
  const go = (tab: Tab, view?: string) => {
    close();
    nav(tab, view);
  };

  const isSupervisor = user && ROLE_RANK[user.role] >= ROLE_RANK.usrah_head;

  const row =
    "tap-target w-full flex items-center gap-3 rounded-xl px-3 py-3 text-start text-sm font-medium transition-colors hover:bg-muted";

  return (
    <Sheet open={open} onOpenChange={onOpenChange}>
      {/* side is physical in shadcn Sheet — flip for RTL so the sheet opens
          from the same edge as the hamburger button. */}
      <SheetContent side={lang === "ar" ? "left" : "right"} className="w-[19.5rem] p-0 flex flex-col">
        <SheetHeader className="border-b border-border pb-4">
          <SheetTitle className="flex items-center gap-2.5 text-start">
            <LogoMark size={30} />
            {t("app.name")}
          </SheetTitle>
        </SheetHeader>

        <div className="flex-1 overflow-y-auto scroll-thin px-3 py-4 space-y-5">
          {/* প্রধান */}
          <nav className="space-y-0.5" aria-label={t("nav.top")}>
            {visibleTabs(user).map(({ key, icon: Icon }) => (
              <button key={key} className={row} onClick={() => go(key)}>
                <Icon className="size-4.5 text-primary shrink-0" />
                {t(`nav.${key}`)}
              </button>
            ))}
            <button className={row} onClick={() => go("ilm", "articles")}>
              <Newspaper className="size-4.5 text-primary shrink-0" />
              {t("nav.articles")}
            </button>
            <button className={row} onClick={() => go("more", "about")}>
              <Info className="size-4.5 text-primary shrink-0" />
              {t("nav.about")}
            </button>
          </nav>

          {/* সেবা */}
          <div>
            <p className="px-3 mb-1 text-xs font-bold text-muted-foreground">{t("nav.services")}</p>
            <div className="space-y-0.5">
              {SERVICES.map(({ view, icon: Icon }) => (
                <button key={view} className={row} onClick={() => go("more", view)}>
                  <Icon className="size-4.5 text-primary shrink-0" />
                  {t(`more.${view === "settings" ? "prayerSettings" : view}`)}
                </button>
              ))}
            </div>
          </div>

          {/* অ্যাকাউন্ট — নোটিফিকেশন/রিমাইন্ডার + থিম + লগইন/প্রোফাইল */}
          <div>
            <p className="px-3 mb-1 text-xs font-bold text-muted-foreground">{t("header.account")}</p>
            <div className="space-y-0.5">
              <button
                className={row}
                onClick={() => {
                  close();
                  onOpenReminders();
                }}
              >
                <Bell className="size-4.5 text-primary shrink-0" />
                {t("header.reminders")}
              </button>
              <button className={row} onClick={() => setTheme(theme === "dark" ? "light" : "dark")}>
                {mounted && theme === "dark" ? (
                  <Sun className="size-4.5 text-primary shrink-0" />
                ) : (
                  <Moon className="size-4.5 text-primary shrink-0" />
                )}
                {t("header.theme")}
              </button>
              {user ? (
                <>
                  <button className={row} onClick={() => go("more", "profile")}>
                    <UserRound className="size-4.5 text-primary shrink-0" />
                    {t("more.profile")}
                  </button>
                  {isSupervisor && (
                    <button
                      className={row}
                      onClick={() => {
                        close();
                        setAdminOpen(true);
                      }}
                    >
                      <ShieldCheck className="size-4.5 text-primary shrink-0" />
                      {t("header.adminPanel")}
                    </button>
                  )}
                  <button
                    className={cn(row, "text-alert hover:bg-alert-soft")}
                    onClick={async () => {
                      await api.logout().catch(() => null);
                      useApp.setState({ user: null });
                      close();
                      toast.success(t("header.signedOut"));
                    }}
                  >
                    <LogOut className="size-4.5 shrink-0" />
                    {t("auth.signOut")}
                  </button>
                </>
              ) : (
                <button
                  className={row}
                  onClick={() => {
                    close();
                    setAuthModal(true);
                  }}
                >
                  <LogIn className="size-4.5 text-primary shrink-0" />
                  {t("auth.signIn")}
                </button>
              )}
            </div>
          </div>
        </div>

        <div className="border-t border-border p-3 space-y-2">
          <a
            href={donationUrl}
            target="_blank"
            rel="noopener noreferrer"
            className="tap-target flex h-11 items-center justify-center gap-2 rounded-xl bg-gold text-sm font-bold text-gold-foreground shadow-sm transition-colors hover:bg-gold/85"
          >
            <HeartHandshake className="size-4" />
            {t("nav.donate")}
          </a>
          <p className="text-center text-[11px] text-muted-foreground">{t("app.tagline")}</p>
        </div>
      </SheetContent>
    </Sheet>
  );
}

function AdminOverlay() {
  const { adminOpen } = useApp();
  return <AnimatePresence>{adminOpen && <AdminConsole />}</AnimatePresence>;
}

function SyncBadge() {
  const { syncState, user } = useApp();
  const t = (k: string) => translate(useApp.getState().profile.language, k);
  if (!user || syncState === "idle") return null;
  if (syncState === "syncing")
    return (
      <span
        className="hidden min-[420px]:inline-flex size-9 items-center justify-center rounded-full text-primary-foreground animate-pulse"
        title={t("header.syncing")}
      >
        <CloudUpload className="size-4" />
      </span>
    );
  if (syncState === "error")
    return (
      <span
        className="hidden min-[420px]:inline-flex size-9 items-center justify-center rounded-full text-primary-foreground/90"
        title={t("header.syncFailed")}
      >
        <AlertTriangle className="size-4" />
      </span>
    );
  return null;
}

function ThemeToggle({
  theme,
  setTheme,
  className,
}: {
  theme: string | undefined;
  setTheme: (t: string) => void;
  className?: string;
}) {
  const [mounted, setMounted] = React.useState(false);
  React.useEffect(() => setMounted(true), []);
  const t = (k: string) => translate(useApp.getState().profile.language, k);
  return (
    <button
      aria-label={t("header.theme")}
      className={cn(
        "tap-target inline-flex size-9 items-center justify-center rounded-full transition-colors",
        className ?? "text-muted-foreground hover:bg-muted"
      )}
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
    >
      {mounted && theme === "dark" ? <Sun className="size-4" /> : <Moon className="size-4" />}
    </button>
  );
}

function NotificationsButton({ open, onOpenChange }: { open: boolean; onOpenChange: (v: boolean) => void }) {
  const { user, profile } = useApp();
  const t = (k: string) => translate(profile.language, k);
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
        aria-label={t("header.notifications")}
        className="tap-target relative inline-flex size-9 items-center justify-center rounded-full text-primary-foreground/85 hover:bg-primary-foreground/10 transition-colors"
        onClick={() => onOpenChange(true)}
      >
        <Bell className="size-4" />
        {unread > 0 && <span className="absolute top-1.5 end-1.5 size-2 rounded-full bg-alert ring-2 ring-primary" />}
      </button>
      <Sheet open={open} onOpenChange={onOpenChange}>
        <SheetContent side="bottom" className="rounded-t-2xl">
          <SheetHeader>
            <SheetTitle>{t("header.reminders")}</SheetTitle>
          </SheetHeader>
          <div className="px-4 pb-6 max-h-96 overflow-y-auto scroll-thin">
            {!user ? (
              <p className="py-8 text-center text-sm text-muted-foreground leading-relaxed">{t("header.remindersHint")}</p>
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
                <p className="mt-3 text-sm text-muted-foreground">{t("header.noReminders")}</p>
              </div>
            )}
          </div>
        </SheetContent>
      </Sheet>
    </>
  );
}

function ProfileMenu() {
  const { user, nav, setAdminOpen, profile } = useApp();
  const t = (k: string) => translate(profile.language, k);
  if (!user) return null;
  const isSupervisor = ROLE_RANK[user.role] >= ROLE_RANK.usrah_head;
  const initials = user.name.slice(0, 2);

  return (
    <DropdownMenu>
      <DropdownMenuTrigger asChild>
        <button
          aria-label={t("header.profileMenu")}
          className="flex size-9 items-center justify-center rounded-full bg-primary-foreground text-primary text-sm font-bold ring-2 ring-gold/50"
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
          <UserRound className="size-4" /> {t("more.profile")}
        </DropdownMenuItem>
        {isSupervisor && (
          <DropdownMenuItem onClick={() => setAdminOpen(true)} className="gap-2">
            <ShieldCheck className="size-4" /> {t("header.adminPanel")}
          </DropdownMenuItem>
        )}
        <DropdownMenuSeparator />
        <DropdownMenuItem
          className="gap-2 text-alert focus:text-alert"
          onClick={async () => {
            await api.logout().catch(() => null);
            useApp.setState({ user: null });
            toast.success(t("header.signedOut"));
          }}
        >
          <LogOut className="size-4" /> {t("auth.signOut")}
        </DropdownMenuItem>
      </DropdownMenuContent>
    </DropdownMenu>
  );
}
