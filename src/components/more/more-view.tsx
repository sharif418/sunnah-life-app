"use client";

// আরও — মেনু গ্রিড থেকে সাব-ভিউ: store-এর view প্যারামিটার অনুযায়ী।
// nav("more", "qibla") ধরনের কল এখানেই রুট হয়; back() আগের অবস্থায় ফেরায়।

import { useApp } from "@/lib/store";
import { MoreMenu } from "@/components/more/menu";
import { ProfileView } from "@/components/more/profile";
import { PrayerSettingsView } from "@/components/more/prayer-settings";
import { QiblaView } from "@/components/more/qibla";
import { ZakatView } from "@/components/more/zakat";
import { MosquesView } from "@/components/more/mosques";
import { MasalaView } from "@/components/more/masala";
import { ContactsView } from "@/components/more/contacts";
import { AboutView } from "@/components/more/about";

export function MoreView() {
  const view = useApp((s) => s.view);

  switch (view) {
    case "profile":
      return <ProfileView />;
    case "settings":
      return <PrayerSettingsView />;
    case "qibla":
      return <QiblaView />;
    case "zakat":
      return <ZakatView />;
    case "mosques":
      return <MosquesView />;
    case "masala":
      return <MasalaView />;
    case "contacts":
      return <ContactsView />;
    case "about":
      return <AboutView />;
    default:
      return <MoreMenu />;
  }
}
