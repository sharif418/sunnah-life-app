import type { Metadata, Viewport } from "next";
import { Noto_Sans_Bengali, Inter, Amiri, Amiri_Quran } from "next/font/google";
import localFont from "next/font/local";
import "./globals.css";
import { Providers } from "@/components/app/providers";
import { ServiceWorkerRegister } from "@/components/app/sw-register";
import { LocaleSync } from "@/components/app/locale-sync";

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

const amiri = Amiri({
  subsets: ["arabic"],
  weight: ["400", "700"],
  variable: "--font-amiri",
  display: "swap",
});

const amiriQuran = Amiri_Quran({
  subsets: ["arabic"],
  weight: "400",
  variable: "--font-amiri-quran",
  display: "swap",
});

export const metadata: Metadata = {
  title: {
    default: "সুন্নাহ লাইফ — Sunnah Life",
    template: "%s · সুন্নাহ লাইফ",
  },
  description:
    "নামাজের সময়সূচি, আমলের মুহাসাবা, কুরআন, দোয়া ও যিকর, দাওয়াত প্রোগ্রাম — আস-সুন্নাহ ফাউন্ডেশনের দাওয়াতুস সুন্নাহ বিভাগের ইসলামিক সঙ্গী।",
  applicationName: "সুন্নাহ লাইফ",
  manifest: "/manifest.webmanifest",
  appleWebApp: {
    capable: true,
    statusBarStyle: "default",
    title: "সুন্নাহ লাইফ",
  },
  icons: {
    icon: [{ url: "/icon.svg", type: "image/svg+xml" }, { url: "/icon-192.png", sizes: "192x192", type: "image/png" }],
    apple: [{ url: "/icon-192.png" }],
  },
};

export const viewport: Viewport = {
  themeColor: [
    { media: "(prefers-color-scheme: light)", color: "#1F4D3D" },
    { media: "(prefers-color-scheme: dark)", color: "#0E1613" },
  ],
  width: "device-width",
  initialScale: 1,
  maximumScale: 5,
  viewportFit: "cover",
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="bn" dir="ltr" suppressHydrationWarning>
      <body
        className={`${solaiman.variable} ${notoBengali.variable} ${inter.variable} ${amiri.variable} ${amiriQuran.variable} antialiased bg-background text-foreground`}
      >
        <Providers>
          <LocaleSync />
          <ServiceWorkerRegister />
          {children}
        </Providers>
      </body>
    </html>
  );
}
