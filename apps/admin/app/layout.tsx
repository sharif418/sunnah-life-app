import type { Metadata, Viewport } from "next";
import { Noto_Sans_Bengali, Inter } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";
import { AppProviders } from "@/components/providers";

// SolaimanLipi (2026-10-07, the Foundation's choice) — the Bengali face of
// bdnews24 and most Bangladeshi news and government text; plain digits.
// Ekushey's v2.002 under the SIL OFL 1.1 (fonts/SolaimanLipi-OFL.txt), the
// same files as the app. Noto Sans Bengali below stays as the per-glyph
// fallback for the few symbols SolaimanLipi lacks (… • − ✓).
const solaiman = localFont({
  src: [
    { path: "./fonts/SolaimanLipi-Regular.woff2", weight: "400", style: "normal" },
    { path: "./fonts/SolaimanLipi-Bold.woff2", weight: "700", style: "normal" },
  ],
  variable: "--font-solaiman",
  display: "swap",
});

// the per-glyph fallback (see above)
const notoBengali = Noto_Sans_Bengali({
  subsets: ["bengali", "latin"],
  weight: ["400", "700"],
  variable: "--font-noto-bengali",
  display: "swap",
});

const inter = Inter({
  subsets: ["latin"],
  variable: "--font-inter",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "সুন্নাহ লাইফ অ্যাডমিন",
    template: "%s · সুন্নাহ লাইফ অ্যাডমিন",
  },
  description:
    "উসরা প্রধান · পরিদর্শক · প্রধান অ্যাডমিন প্যানেল — দাওয়াতুস সুন্নাহ তারবিয়াত ইঞ্জিন, আস-সুন্নাহ ফাউন্ডেশন।",
  applicationName: "সুন্নাহ লাইফ অ্যাডমিন",
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#1F4D3D" },
    { media: "(prefers-color-scheme: dark)", color: "#0E1613" },
  ],
  width: "device-width",
  initialScale: 1,
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="bn" suppressHydrationWarning>
      <body className={`${solaiman.variable} ${notoBengali.variable} ${inter.variable} antialiased`}>
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
