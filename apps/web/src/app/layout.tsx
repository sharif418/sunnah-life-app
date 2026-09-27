import type { Metadata, Viewport } from "next";
import { Hind_Siliguri, Inter, Amiri, Amiri_Quran } from "next/font/google";
import "./globals.css";
import { Providers } from "@/components/app/providers";

const hindSiliguri = Hind_Siliguri({
  subsets: ["bengali", "latin"],
  weight: ["300", "400", "500", "600", "700"],
  variable: "--font-hind-siliguri",
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
  icons: {
    icon: [{ url: "/icon.svg", type: "image/svg+xml" }],
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
    <html lang="bn" suppressHydrationWarning>
      <body
        className={`${hindSiliguri.variable} ${inter.variable} ${amiri.variable} ${amiriQuran.variable} antialiased bg-background text-foreground`}
      >
        <Providers>{children}</Providers>
      </body>
    </html>
  );
}
