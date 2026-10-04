import type { Metadata } from "next";
import Link from "next/link";
import { LogoMark } from "@/components/app/logo";

// The privacy policy the Play listing links to (and the app's About screen).
// Plain Bengali first, a short English summary after — what we collect, why,
// who sees it, who we share it with, how long we keep it, how to delete it.
// Keep it in step with apps/api (account deletion: src/me/account-deletion.ts).

export const metadata: Metadata = {
  title: "গোপনীয়তা নীতি",
  description: "সুন্নাহ লাইফ অ্যাপ কোন তথ্য রাখে, কেন রাখে, কারা দেখেন এবং কীভাবে মুছবেন।",
};

const UPDATED = "৫ অক্টোবর ২০২৬";

function Section({ id, title, children }: { id: string; title: string; children: React.ReactNode }) {
  return (
    <section id={id} className="scroll-mt-6 space-y-2">
      <h2 className="text-lg font-bold text-foreground">{title}</h2>
      <div className="space-y-2 text-[15px] leading-7 text-foreground/90">{children}</div>
    </section>
  );
}

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-background">
      <div className="mx-auto max-w-2xl px-4 py-10 sm:px-6">
        <header className="mb-8 flex items-center gap-3">
          <LogoMark size={44} />
          <div>
            <p className="text-sm text-muted-foreground">সুন্নাহ লাইফ · আস-সুন্নাহ ফাউন্ডেশন</p>
            <h1 className="text-2xl font-bold tracking-tight">গোপনীয়তা নীতি</h1>
          </div>
        </header>
        <p className="mb-8 text-sm text-muted-foreground">সর্বশেষ হালনাগাদ: {UPDATED}</p>

        <div className="space-y-8">
          <Section id="intro" title="সংক্ষেপে">
            <p>
              সুন্নাহ লাইফ আস-সুন্নাহ ফাউন্ডেশনের দাওয়াতুস সুন্নাহ বিভাগের অ্যাপ। আমরা শুধু সেই তথ্য রাখি যা
              অ্যাপটি চালাতে দরকার। কোনো বিজ্ঞাপন নেই, আর আপনার তথ্য কখনো বিক্রি করা হয় না।
            </p>
            <p>
              সাইন-ইন ছাড়াও অ্যাপ ব্যবহার করা যায়। তখন আপনার ডায়েরি শুধু আপনার ফোনেই থাকে, সার্ভারে যায় না।
            </p>
          </Section>

          <Section id="collect" title="কোন তথ্য রাখি এবং কেন">
            <ul className="list-disc space-y-1.5 ps-5">
              <li>
                <b>মোবাইল নম্বর:</b> সাইন-ইনের জন্য (একবারের কোড পাঠাতে)।
              </li>
              <li>
                <b>গুগল অ্যাকাউন্ট:</b> গুগল দিয়ে সাইন-ইন করলে আপনার গুগল আইডি, নাম ও ইমেইল।
              </li>
              <li>
                <b>নাম ও লিঙ্গ:</b> নাম দেখানোর জন্য; লিঙ্গ দিয়ে ভাই ও বোনদের তথ্য আলাদা রাখা হয়।
              </li>
              <li>
                <b>প্রোফাইল:</b> ক্যাটাগরি (সাধারণ/হাফেজ/আলেম), শহর বা জেলা, মাযহাব, নামাজের সময়ের হিসাবপদ্ধতি; ইচ্ছা হলে
                ইমেইল, কর্মস্থল ও বিভাগ।
              </li>
              <li>
                <b>আমলের মুহাসাবা:</b> সাইন-ইন করা সদস্যদের দৈনিক ডায়েরি, লক্ষ্য, সাপ্তাহিক রিভিউ ও মূল্যায়ন, যাতে
                উসরা প্রধান তারবিয়াতে সহায়তা করতে পারেন।
              </li>
              <li>
                <b>আপনার লেখা:</b> মাসআলা প্রশ্ন, উসরার প্রশ্ন, সাপোর্ট বার্তা ও মতামত। মতামতের সাথে অ্যাপের সংস্করণ ও ফোনের
                মডেল যায়, যাতে সমস্যা খুঁজে পাওয়া সহজ হয়।
              </li>
              <li>
                <b>কোর্স ও কুইজ:</b> কোন লেসন শেষ করেছেন, কুইজের ফলাফল।
              </li>
              <li>
                <b>নোটিফিকেশন টোকেন:</b> নামাজ, রিভিউ ও ঘোষণার নোটিফিকেশন পাঠাতে।
              </li>
            </ul>
          </Section>

          <Section id="device" title="যা শুধু আপনার ফোনেই থাকে">
            <ul className="list-disc space-y-1.5 ps-5">
              <li>
                <b>অবস্থান (GPS):</b> কাছের জেলা খুঁজতে ও মসজিদের দূরত্ব দেখাতে ফোনেই ব্যবহার হয়। সার্ভারে যায় শুধু
                আপনার বেছে নেওয়া শহরের নাম ও তার কেন্দ্রের অবস্থান, নামাজের সময়ের জন্য।
              </li>
              <li>
                <b>স্ক্রিন টাইম (ইউসেজ অ্যাক্সেস):</b> সোশ্যাল মিডিয়া ডিটক্সের হিসাব শুধু ফোনে দেখানো হয়, কোথাও পাঠানো হয় না।
              </li>
              <li>
                <b>ঈমানের শাখা আত্মমূল্যায়ন</b>, কুরআনের বুকমার্ক ও পড়ার অবস্থান।
              </li>
              <li>
                <b>কম্পাস:</b> কিবলার দিক দেখাতে ফোনের সেন্সর ব্যবহার হয়; কোনো তথ্য রাখা হয় না।
              </li>
            </ul>
          </Section>

          <Section id="who" title="কারা দেখতে পান">
            <ul className="list-disc space-y-1.5 ps-5">
              <li>আপনি নিজে আপনার সব তথ্য দেখেন।</li>
              <li>
                আপনার উসরা প্রধান ও পরিদর্শক আপনার ডায়েরি, লক্ষ্য ও রিভিউ দেখেন, তবে শুধু একই লিঙ্গের হলে। ভাইদের তথ্য
                বোন তত্ত্বাবধায়ক দেখেন না, বোনদের তথ্য ভাই তত্ত্বাবধায়ক দেখেন না। এই বিভাজন ডাটাবেস স্তরেই প্রয়োগ করা।
              </li>
              <li>ফাউন্ডেশনের প্রধান অ্যাডমিনরা ব্যবস্থাপনার প্রয়োজনে দেখতে পারেন।</li>
              <li>উসরার অন্য সদস্যরা শুধু আপনার নাম ও স্তর দেখেন, ডায়েরি নয়।</li>
            </ul>
          </Section>

          <Section id="share" title="যাদের সাথে তথ্য যায়">
            <ul className="list-disc space-y-1.5 ps-5">
              <li>
                <b>গুগল:</b> গুগল সাইন-ইন ও নোটিফিকেশন পাঠানোর সেবা (Firebase Cloud Messaging)।
              </li>
              <li>
                <b>এসএমএস সেবাদাতা:</b> সাইন-ইনের কোড পাঠাতে আপনার মোবাইল নম্বর।
              </li>
              <li>
                <b>সার্ভার:</b> আমাদের নিজস্ব সার্ভারে সব তথ্য এনক্রিপ্টেড সংযোগে (HTTPS) আসা-যাওয়া করে।
              </li>
            </ul>
            <p>এর বাইরে কারো সাথে আপনার তথ্য শেয়ার, বিক্রি বা বিজ্ঞাপনে ব্যবহার করা হয় না।</p>
          </Section>

          <Section id="keep" title="কতদিন রাখি">
            <p>
              অ্যাকাউন্ট যতদিন আছে, ততদিন তথ্য থাকে। অ্যাকাউন্ট মুছে ফেললে আপনার নিজের তথ্য মুছে যায়।
            </p>
          </Section>

          <Section id="delete" title="অ্যাকাউন্ট ও তথ্য মুছে ফেলা">
            <p>
              অ্যাপে: <b>আরও → প্রোফাইল → অ্যাকাউন্ট মুছে ফেলুন</b>। অথবা ওয়েবে:{" "}
              <Link href="/delete-account" className="font-semibold text-primary underline">
                অ্যাকাউন্ট মুছে ফেলার পাতা
              </Link>
              ।
            </p>
            <p>
              মুছে যায়: ডায়েরি, লক্ষ্য, রিভিউ, মূল্যায়ন, প্রশ্ন, মতামত, সাপোর্ট বার্তা, নাম, ফোন, ইমেইল, সদস্য কোড ও গুগল
              সংযোগ। অন্যদের জন্য আপনি যা লিখেছিলেন (যেমন কাউকে দেওয়া রিভিউ বা ঘোষণা), তা আপনার নাম ছাড়া “মুছে ফেলা
              অ্যাকাউন্ট” হিসেবে থেকে যায়, যাতে তাদের রেকর্ড নষ্ট না হয়। পরিবর্তনের নিরাপত্তা-রেকর্ডে মুছে ফেলার ঘটনাটুকু
              থাকে।
            </p>
          </Section>

          <Section id="contact" title="যোগাযোগ">
            <p>
              এই নীতি নিয়ে প্রশ্ন থাকলে অ্যাপের <b>আরও → লাইভ সাপোর্ট</b> থেকে লিখুন। নীতিতে বড় কোনো পরিবর্তন হলে অ্যাপে
              জানানো হবে।
            </p>
          </Section>

          <section lang="en" className="space-y-2 rounded-xl border border-border bg-card p-5 text-[15px] leading-7">
            <h2 className="text-lg font-bold">In English, briefly</h2>
            <p>
              Sunnah Life (As-Sunnah Foundation) stores only what the app needs: your phone number or Google account for
              sign-in, your name and gender, your profile, and — for signed-in members — your daily deeds diary, goals,
              reviews and assessments, plus anything you write (questions, feedback, support messages) and a push token.
              GPS location, screen-time totals and the self-review stay on your phone. Supervisors see a member&apos;s diary
              only within the same gender; Foundation administrators may see it to run the programme. Data goes only to
              Google (sign-in, notifications), the SMS provider (sign-in codes) and our own server, always over HTTPS. No
              ads, no selling. Delete your account in the app (More → Profile → Delete account) or at{" "}
              <Link href="/delete-account" className="font-semibold text-primary underline">
                /delete-account
              </Link>
              ; your own data is erased and what you wrote for others stays as &quot;deleted account&quot;.
            </p>
          </section>
        </div>
      </div>
    </main>
  );
}
