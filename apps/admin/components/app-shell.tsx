"use client";

import * as React from "react";
import Link from "next/link";
import { usePathname, useRouter } from "next/navigation";
import { useTheme } from "next-themes";
import {
  BookOpen,
  FileCheck2,
  ClipboardCheck,
  Download,
  Headset,
  MessageSquareText,
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
import { RoleBadge } from "@/components/badges";
import { Button } from "@/components/ui/button";
import { toBn, todayLineBn } from "@/lib/bn";

interface NavItem {
  href: string;
  label: string;
  icon: React.ComponentType<{ className?: string }>;
}

// W4h — role-based nav, mirroring the API's actual role floors:
//   • the তত্ত্বাবধায়ক group is supervisor-floor (usrah_head AND invigilator
//     share rank 2 — the API differs only in RLS data scope, never by route);
//   • the প্রধান অ্যাডমিন group lists the pages whose whole surface is
//     @Roles("full_admin"). The usrah JOIN queue lives inside /usrah as a
//     full_admin section (heads never assign membership — W4d boundary).
const COMMON_NAV: NavItem[] = [
  { href: "/", label: "ড্যাশবোর্ড", icon: LayoutDashboard },
  { href: "/usrah", label: "উসরা", icon: Users },
  { href: "/reviews", label: "সাপ্তাহিক রিভিউ", icon: ClipboardCheck },
  { href: "/assessments", label: "মূল্যায়ন", icon: FileCheck2 },
  { href: "/levels", label: "স্তর ও শর্তাবলি", icon: TrendingUp },
  { href: "/broadcast", label: "ঘোষণা ও রিমাইন্ডার", icon: Megaphone },
  { href: "/live", label: "লাইভ প্রোগ্রাম", icon: Radio },
  { href: "/exports", label: "রিপোর্ট ও এক্সপোর্ট", icon: Download },
];

const FULL_ADMIN_NAV: NavItem[] = [
  { href: "/support", label: "সাপোর্ট ইনবক্স", icon: Headset },
  { href: "/feedback", label: "মতামত", icon: MessageSquareText },
  { href: "/users", label: "ব্যবহারকারী", icon: UserCog },
  { href: "/referrals", label: "রেফারেল ট্রি", icon: Network },
  { href: "/catalog", label: "আমল ক্যাটালগ", icon: ListChecks },
  { href: "/level-rules", label: "লেভেল রুলস", icon: SlidersHorizontal },
  { href: "/content", label: "কন্টেন্ট ম্যানেজমেন্ট", icon: BookOpen },
  { href: "/settings", label: "অ্যাপ কনফিগারেশন", icon: Settings },
  { href: "/audit", label: "অডিট লগ", icon: ScrollText },
];

const PAGE_TITLES: Record<string, string> = {
  "/": "ড্যাশবোর্ড",
  "/usrah": "উসরা",
  "/reviews": "সাপ্তাহিক রিভিউ",
  "/assessments": "মূল্যায়ন",
  "/levels": "স্তর ও শর্তাবলি",
  "/broadcast": "ঘোষণা ও রিমাইন্ডার",
  "/live": "লাইভ প্রোগ্রাম",
  "/exports": "রিপোর্ট ও এক্সপোর্ট",
  "/users": "ব্যবহারকারী ব্যবস্থাপনা",
  "/referrals": "রেফারেল ট্রি",
  "/catalog": "আমল ক্যাটালগ",
  "/level-rules": "লেভেল রুলস",
  "/content": "কন্টেন্ট ম্যানেজমেন্ট",
  "/settings": "অ্যাপ কনফিগারেশন",
  "/audit": "অডিট লগ",
  "/support": "সাপোর্ট ইনবক্স",
  "/feedback": "মতামত",
};

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

  const title = React.useMemo(() => {
    if (pathname.startsWith("/members/")) return "সদস্য প্রোফাইল";
    return PAGE_TITLES[pathname] ?? "সুন্নাহ লাইফ অ্যাডমিন";
  }, [pathname]);

  const navGroups = React.useMemo(
    () => [
      { label: "তত্ত্বাবধায়ক", items: COMMON_NAV },
      ...(fullAdmin ? [{ label: "প্রধান অ্যাডমিন", items: FULL_ADMIN_NAV }] : []),
    ],
    [fullAdmin]
  );

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
      <nav aria-label="প্রধান মেনু" className="scroll-thin flex-1 space-y-5 overflow-y-auto px-3 pb-4">
        {navGroups.map((group) => (
          <div key={group.label}>
            <p className="px-2.5 pb-1.5 text-[11px] font-bold uppercase tracking-wide text-muted-foreground/80">
              {group.label}
            </p>
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
                        "focus-ring flex min-h-11 items-center gap-3 rounded-md px-2.5 py-2 text-sm font-medium transition-colors duration-200",
                        active
                          ? "bg-primary text-primary-foreground shadow-card"
                          : "text-foreground/85 hover:bg-primary-soft hover:text-primary"
                      )}
                    >
                      <Icon className="h-[18px] w-[18px] shrink-0" aria-hidden />
                      {item.label}
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
          <h1 className="truncate text-base font-bold sm:text-lg">{title}</h1>
          <div className="ml-auto flex items-center gap-2">
            <span className="hidden text-xs text-muted-foreground md:block">{todayLineBn()}</span>
            {user ? <RoleBadge role={user.role} /> : null}
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
