"use client";

// App providers — one client boundary at the root layout:
//   • QueryClientProvider (TanStack Query) — all server state flows through it
//   • ThemeProvider (next-themes) — light/dark, class strategy, system default
//   • SessionProvider — token bootstrap + /api/me hydration + role gate
//   • ToastProvider — Bengali toast notifications (aria-live)
import * as React from "react";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { ThemeProvider } from "next-themes";
import { SessionProvider } from "@/lib/session";
import { ToastProvider } from "@/components/ui/toast";

export function AppProviders({ children }: { children: React.ReactNode }) {
  // QueryClient is created once per browser session; on the server every
  // render gets its own (no shared cache across requests).
  const [queryClient] = React.useState(
    () =>
      new QueryClient({
        defaultOptions: {
          queries: {
            // The admin is a live operational console; data must be fresh.
            staleTime: 15_000,
            gcTime: 5 * 60_000,
            refetchOnWindowFocus: true,
            retry: (failureCount, error) => {
              // 401/403 surface via the session layer — don't blind-retry auth.
              const status = (error as { status?: number })?.status;
              if (status === 401 || status === 403) return false;
              return failureCount < 2;
            },
          },
          mutations: { retry: false },
        },
      }),
  );

  return (
    <QueryClientProvider client={queryClient}>
      <ThemeProvider attribute="class" enableSystem disableTransitionOnChange>
        <SessionProvider>
          <ToastProvider>{children}</ToastProvider>
        </SessionProvider>
      </ThemeProvider>
    </QueryClientProvider>
  );
}
