import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "সুন্নাহ লাইফ অ্যাডমিন",
  description: "উসরা প্রধান · পরিদর্শক · প্রধান অ্যাডমিন প্যানেল — Dawatus Sunnah Tarbiyah Engine",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="bn">
      <body>{children}</body>
    </html>
  );
}
