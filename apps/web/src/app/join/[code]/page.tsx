import type { Metadata } from "next";
import { redirect } from "next/navigation";
import { JoinLanding } from "./join-landing";

/** Same shape as the API's member codes (apps/api nextMemberCode: DS-XXXXXX). */
const MEMBER_CODE_RE = /^ds-\d{6,}$/i;

interface JoinPageProps {
  params: Promise<{ code: string }>;
}

/** Referral landing: /join/DS-000123 — link previews in Bengali. */
export async function generateMetadata({ params }: JoinPageProps): Promise<Metadata> {
  const { code } = await params;
  const normalized = code.toUpperCase();
  return {
    title: "সুন্নাহ লাইফ-এ যোগ দিন",
    description: `রেফারেল কোড ${normalized} দিয়ে সুন্নাহ লাইফ অ্যাপে যোগ দিন — নামাজের সময়সূচি, আমলনামা, কুরআন ও তারবিয়াত এক অ্যাপে।`,
    openGraph: {
      title: "সুন্নাহ লাইফ-এ যোগ দিন",
      description: `রেফারেল কোড ${normalized} দিয়ে সুন্নাহ লাইফ অ্যাপে যোগ দিন।`,
      type: "website",
    },
  };
}

export default async function JoinCodePage({ params }: JoinPageProps) {
  const { code } = await params;
  // A garbage code is not a landing — same treatment as bare /join.
  if (!MEMBER_CODE_RE.test(code)) redirect("/");
  return <JoinLanding code={code} />;
}
