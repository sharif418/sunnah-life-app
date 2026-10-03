import type { Metadata, Viewport } from "next";
import { Noto_Sans_Bengali, Inter } from "next/font/google";
import "./globals.css";
import { AppProviders } from "@/components/providers";

// Noto Sans Bengali — the Bengali face Android itself uses (the most
// familiar to Bangladeshi readers; standard digits). Same family as mobile.
const notoBengali = Noto_Sans_Bengali({
  subsets: ["bengali", "latin"],
  weight: ["300", "400", "500", "600", "700"],
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
      <body className={`${notoBengali.variable} ${inter.variable} antialiased`}>
        <AppProviders>{children}</AppProviders>
      </body>
    </html>
  );
}
