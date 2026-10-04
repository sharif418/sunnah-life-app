"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import { useQuery } from "@tanstack/react-query";
import {
  BookOpen,
  ChevronRight,
  FileCheck2,
  ClipboardCheck,
  Download,
  Headset,
  MessageSquareText,
  BookOpenCheck,
  LayoutDashboard,
  ListChecks,
  LogOut,
  Megaphone,
  Menu,
  Moon,
  Network,
  Radio,
  ScrollText,
  Settings,
  SlidersHorizontal,
  Sun,
  TrendingUp,
  UserCog,
  Users,
  X,
} from "lucide-react";
import { useSession } from "@/lib/session";
import { ROLE_LABELS_BN } from "@/lib/labels";
import { cn } from "@/lib/utils";
import { api } from "@/lib/api";
import { RoleBadge } from "@/components/badges";
import { Button } from "@/components/ui/button";
import { toBn, todayLineBn } from "@/lib/bn";

type QueueKey = "reviews" | "support" | "masala" | "feedback" | "joinRequests";

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
  /** full_admin only (the API surface behind it is full_admin-only) */
  admin?: boolean;
  /** the waiting-work count shown beside the label */
  queue?: QueueKey;
}

interface NavGroup {
  label: string | null;
  items: NavItem[];
}

// The menu follows the WORK, not the org chart: what a tarbiyah team does
// in a week (reviews, assessments, usrahs), who talks to them (inboxes),
// who the members are, what the app shows, and the system itself. Each
// item knows its role floor; supervisors simply see a shorter menu. The
// numbers are what is waiting (GET /api/admin/queues, refreshed each
// minute), so nobody has to open five pages to find the work.
const NAV: NavGroup[] = [
  { label: null, items: [{ href: "/", label: "ড্যাশবোর্ড", icon: LayoutDashboard }] },
  {
    label: "তারবিয়াত",
    items: [
      { href: "/reviews", label: "সাপ্তাহিক রিভিউ", icon: ClipboardCheck, queue: "reviews" },
      { href: "/assessments", label: "মূল্যায়ন", icon: FileCheck2 },
      { href: "/usrah", label: "উসরা", icon: Users, queue: "joinRequests" },
      { href: "/levels", label: "স্তর ও অগ্রগতি", icon: TrendingUp },
    ],
  },
  {
    label: "যোগাযোগ",
    items: [
      { href: "/broadcast", label: "ঘোষণা পাঠান", icon: Megaphone },
      { href: "/support", label: "সাপোর্ট বার্তা", icon: Headset, admin: true, queue: "support" },
      { href: "/masala", label: "মাসআলা প্রশ্ন", icon: BookOpenCheck, admin: true, queue: "masala" },
      { href: "/feedback", label: "অ্যাপের মতামত", icon: MessageSquareText, admin: true, queue: "feedback" },
    ],
  },
  {
    label: "সদস্য",
    items: [
      { href: "/users", label: "সদস্য তালিকা", icon: UserCog, admin: true },
      { href: "/referrals", label: "দাওয়াহ নেটওয়ার্ক", icon: Network, admin: true },
    ],
  },
  {
    label: "অ্যাপের কনটেন্ট",
    items: [
      { href: "/content", label: "দোয়া, আর্টিকেল ও কোর্স", icon: BookOpen, admin: true },
      { href: "/live", label: "লাইভ প্রোগ্রাম", icon: Radio },
      { href: "/catalog", label: "ডায়েরির আমল", icon: ListChecks, admin: true },
    ],
  },
  {
    label: "সিস্টেম",
    items: [
      { href: "/exports", label: "রিপোর্ট ডাউনলোড", icon: Download },
      { href: "/level-rules", label: "স্তরের নিয়ম", icon: SlidersHorizontal, admin: true },
      { href: "/settings", label: "অ্যাপ সেটিংস", icon: Settings, admin: true },
      { href: "/audit", label: "কার্যক্রমের রেকর্ড", icon: ScrollText, admin: true },
    ],
  },
];

/** The page's place in the menu: (group, label) — the top bar shows it as a
 * quiet breadcrumb so the page's own heading is not repeated above it. */
function navPlace(pathname: string): { group: string | null; label: string } | null {
  if (pathname.startsWith("/members/")) return { group: "সদস্য", label: "সদস্য প্রোফাইল" };
  if (pathname.startsWith("/users/import")) return { group: "সদস্য", label: "সদস্য ইমপোর্ট" };
  for (const g of NAV) {
    for (const it of g.items) {
      const hit = it.href === "/" ? pathname === "/" : pathname === it.href || pathname.startsWith(`${it.href}/`);
      if (hit) return { group: g.label, label: it.label };
    }
  }
  return null;
}

function QueueCount({ n, active }: { n: number | null | undefined; active: boolean }) {
  if (!n) return null;
  return (
    <span
      className={cn(
        "ml-auto min-w-6 rounded-full px-2 text-center text-xs font-bold leading-6 tabular-nums",
        active ? "bg-primary-foreground text-primary" : "bg-gold text-gold-foreground"
      )}
      aria-label={`${toBn(n)}টি অপেক্ষায়`}
    >
      {toBn(n > 99 ? "৯৯+" : n)}
    </span>
  );
}

function BrandMark() {
  return (
    <svg viewBox="0 0 48 48" aria-hidden className="h-10 w-10">
      <circle cx="24" cy="24" r="22" fill="var(--primary)" />
      <path
        d="M31 13a11.5 11.5 0 1 0 3.2 15.9A9.6 9.6 0 0 1 31 13z"
        fill="var(--gold)"
      />
      <path d="M34.5 18.2l1.05 2.6 2.65.3-2 1.85.55 2.62-2.25-1.45-2.25 1.45.55-2.62-2-1.85 2.65-.3z" fill="var(--gold)" />
    </svg>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  const { user, fullAdmin, logout } = useSession();
  const pathname = usePathname();
  const router = useRouter();
  const { resolvedTheme, setTheme } = useTheme();
  const [drawerOpen, setDrawerOpen] = React.useState(false);

  // Close the drawer on navigation — render-phase adjustment on pathname.
  const [prevPathname, setPrevPathname] = React.useState(pathname);
  if (pathname !== prevPathname) {
    setPrevPathname(pathname);
    setDrawerOpen(false);
  }

  const place = React.useMemo(() => navPlace(pathname), [pathname]);

  const navGroups = React.useMemo(
    () =>
      NAV.map((g) => ({ ...g, items: g.items.filter((it) => !it.admin || fullAdmin) })).filter(
        (g) => g.items.length > 0
      ),
    [fullAdmin]
  );

  const queues = useQuery({
    queryKey: ["admin-queues"],
    queryFn: () => api.queues(),
    enabled: !!user,
    refetchInterval: 60_000,
  });

  const onLogout = async () => {
    await logout();
    router.replace("/login");
  };

  const sidebar = (
    <div className="flex h-full flex-col">
      <div className="flex items-center gap-3 px-5 pb-4 pt-5">
        <BrandMark />
        <div className="leading-tight">
          <p className="text-sm font-bold text-foreground">সুন্নাহ লাইফ</p>
          <p className="text-xs text-muted-foreground">অ্যাডমিন প্যানেল</p>
        </div>
        <button
          className="ml-auto rounded-md p-2 text-muted-foreground hover:bg-primary-soft lg:hidden focus-ring"
          onClick={() => setDrawerOpen(false)}
          aria-label="মেনু বন্ধ করুন"
        >
          <X className="h-5 w-5" aria-hidden />
        </button>
      </div>
      <nav aria-label="প্রধান মেনু" className="scroll-thin flex-1 space-y-4 overflow-y-auto px-3 pb-4">
        {navGroups.map((group) => (
          <div key={group.label ?? "home"}>
            {group.label ? (
              <p className="px-2.5 pb-1 text-xs font-semibold text-muted-foreground">{group.label}</p>
            ) : null}
            <ul className="space-y-0.5">
              {group.items.map((item) => {
                const active =
                  item.href === "/" ? pathname === "/" : pathname.startsWith(item.href);
                const Icon = item.icon;
                return (
                  <li key={item.href}>
                    <Link
                      href={item.href}
                      aria-current={active ? "page" : undefined}
                      className={cn(
                        "focus-ring flex min-h-10 items-center gap-3 rounded-md px-2.5 py-1.5 text-sm font-medium transition-colors duration-200",
                        active
                          ? "bg-primary text-primary-foreground shadow-card"
                          : "text-foreground/85 hover:bg-primary-soft hover:text-primary"
                      )}
                    >
                      <Icon className="h-[18px] w-[18px] shrink-0" aria-hidden />
                      <span className="min-w-0 truncate">{item.label}</span>
                      {item.queue ? <QueueCount n={queues.data?.[item.queue]} active={active} /> : null}
                    </Link>
                  </li>
                );
              })}
            </ul>
          </div>
        ))}
      </nav>
      <div className="border-t border-border p-3">
        <div className="flex items-center gap-2.5 rounded-md bg-muted/60 p-2.5">
          <div
            className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-primary text-sm font-bold text-primary-foreground"
            aria-hidden
          >
            {(user?.name ?? "?").slice(0, 2)}
          </div>
          <div className="min-w-0 flex-1 leading-tight">
            <p className="truncate text-sm font-semibold text-foreground">{user?.name}</p>
            <p className="text-xs text-muted-foreground">
              {user ? ROLE_LABELS_BN[user.role] : ""}
            </p>
          </div>
          <button
            onClick={onLogout}
            aria-label="লগআউট"
            title="লগআউট"
            className="focus-ring rounded-md p-2.5 text-muted-foreground transition-colors duration-200 hover:bg-alert-soft hover:text-alert"
          >
            <LogOut className="h-4 w-4" aria-hidden />
          </button>
        </div>
      </div>
    </div>
  );

  return (
    <div className="flex min-h-screen bg-background">
      {/* desktop sidebar */}
      <aside className="no-print sticky top-0 hidden h-screen w-64 shrink-0 border-r border-border bg-card lg:block">
        {sidebar}
      </aside>

      {/* mobile drawer */}
      {drawerOpen ? (
        <div className="no-print fixed inset-0 z-50 lg:hidden">
          <div className="absolute inset-0 bg-black/45" onClick={() => setDrawerOpen(false)} aria-hidden />
          <aside className="absolute left-0 top-0 h-full w-72 border-r border-border bg-card shadow-lifted">
            {sidebar}
          </aside>
        </div>
      ) : null}

      <div className="flex min-w-0 flex-1 flex-col">
        <header className="no-print sticky top-0 z-40 flex min-h-16 items-center gap-3 border-b border-border bg-card/90 px-4 backdrop-blur sm:px-6">
          <button
            className="focus-ring rounded-md p-2.5 text-muted-foreground hover:bg-primary-soft lg:hidden"
            onClick={() => setDrawerOpen(true)}
            aria-label="মেনু খুলুন"
          >
            <Menu className="h-5 w-5" aria-hidden />
          </button>
          {/* a quiet breadcrumb — each page carries its own heading */}
          <p className="flex min-w-0 items-center gap-1.5 truncate text-sm">
            {place?.group ? (
              <>
                <span className="hidden text-muted-foreground sm:inline">{place.group}</span>
                <ChevronRight className="hidden h-3.5 w-3.5 shrink-0 text-muted-foreground sm:block" aria-hidden />
              </>
            ) : null}
            <span className="truncate font-semibold">{place?.label ?? "সুন্নাহ লাইফ অ্যাডমিন"}</span>
          </p>
          <div className="ml-auto flex items-center gap-2">
            <span className="hidden text-xs text-muted-foreground md:block">{todayLineBn()}</span>
            {user ? (
              <span className="hidden sm:inline-flex">
                <RoleBadge role={user.role} />
              </span>
            ) : null}
            <button
              onClick={() => setTheme(resolvedTheme === "dark" ? "light" : "dark")}
              className="focus-ring min-h-11 min-w-11 rounded-md p-2.5 text-muted-foreground transition-colors duration-200 hover:bg-primary-soft hover:text-primary"
              aria-label={resolvedTheme === "dark" ? "লাইট মোডে যান" : "ডার্ক মোডে যান"}
              title={resolvedTheme === "dark" ? "লাইট মোড" : "ডার্ক মোড"}
            >
              {resolvedTheme === "dark" ? (
                <Sun className="h-4 w-4" aria-hidden />
              ) : (
                <Moon className="h-4 w-4" aria-hidden />
              )}
            </button>
          </div>
        </header>
        <main className="print-full min-w-0 flex-1 p-4 sm:p-6">{children}</main>
        <footer className="no-print mt-auto border-t border-border bg-card px-6 py-3 text-center text-xs text-muted-foreground">
          সুন্নাহ লাইফ অ্যাডমিন · দাওয়াতুস সুন্নাহ বিভাগ — আস-সুন্নাহ ফাউন্ডেশন · সংস্করণ {toBn(1)}
        </footer>
      </div>
    </div>
  );
}
