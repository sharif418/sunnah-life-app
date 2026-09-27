import { json } from "@/lib/server/guard";
import type { AppConfig } from "@/types/domain";

// Static config pack (content/config.json is the editable source; values here
// mirror it for resilience). Nisab prices are admin-editable at deploy time.
export async function GET() {
  const config: AppConfig = {
    donationUrl: "https://as-sunnah.org/donation",
    domain: "sunnahlife.app",
    hijriAdjust: 0,
    nisab: {
      goldPerGramBdt: 16500, // 2025 approximate — configurable
      silverPerGramBdt: 220,
    },
    contacts: [
      {
        org: "দাওয়াতুস সুন্নাহ",
        descBn: "আস-সুন্নাহ ফাউন্ডেশনের দাওয়াত ও তারবিয়াত বিভাগ — সুন্নাহ লাইফ প্ল্যাটফর্মের আয়োজক।",
        website: "https://as-sunnah.org",
      },
      {
        org: "আস-সুন্নাহ ফাউন্ডেশন",
        descBn: "মূল সংস্থা — দাওয়াত, শিক্ষা ও সমাজকল্যাণমূলক কার্যক্রম।",
        website: "https://as-sunnah.org",
        email: "info@as-sunnah.org",
      },
      {
        org: "স্কিল ডেভেলপমেন্ট",
        descBn: "যুব সমাজের দক্ষতা উন্নয়ন ও কর্মসংস্থান সহায়তা বিভাগ।",
        website: "https://as-sunnah.org/skill",
      },
      {
        org: "দাওয়াহ ইনস্টিটিউট",
        descBn: "দায়ীদের প্রশিক্ষণ ও গবেষণা প্রতিষ্ঠান।",
        website: "https://as-sunnah.org/dawah",
      },
      {
        org: "মাদরাসাতুস সুন্নাহ",
        descBn: "আলেম ও হাফেজ প্রশিক্ষণ প্রতিষ্ঠান।",
        website: "https://as-sunnah.org/madrasah",
      },
    ],
    groups: [
      { titleBn: "সুন্নাহ লাইফ অ্যাপ গ্রুপ (টেলিগ্রাম)", url: "https://t.me/sunnahlife", descBn: "নিয়মিত আপডেট ও ঘোষণা" },
      { titleBn: "দাওয়াতুস সুন্নাহ ফেসবুক পেজ", url: "https://facebook.com/dawatussunnah", descBn: "অনুষ্ঠানের আপডেট" },
      { titleBn: "অডিও লাইব্রেরি", url: "https://as-sunnah.org/audio", descBn: "ওয়াজ ও তাফসির" },
    ],
    audioBase: "https://download.quranicaudio.com/quran/mishaari_raashid_al_3afaasee",
  };
  return json(config);
}
