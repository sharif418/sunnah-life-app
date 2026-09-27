// The 15 seeded demo accounts (docs/DEMO_ACCOUNTS.md — verified against
// apps/api/prisma/seed.ts). Used by the login screen's quick-login grid.

import type { Gender, Level, Role } from "./api";

export interface DemoAccount {
  phone: string;
  name: string;
  gender: Gender;
  role: Role;
  memberCode: string | null;
  level: Level;
  usrah: string | null;
  note?: string;
}

export const ROLE_GROUP_LABELS: Record<string, string> = {
  full_admin: "প্রধান অ্যাডমিন",
  invigilator: "পরিদর্শক",
  usrah_head: "উসরা প্রধান",
  daee: "দায়ী",
  user: "সাধারণ ব্যবহারকারী",
};

export const DEMO_ACCOUNTS: DemoAccount[] = [
  {
    phone: "01000000001",
    name: "আব্দুল্লাহ আল মামুন",
    gender: "M",
    role: "full_admin",
    memberCode: null,
    level: "none",
    usrah: null,
  },
  {
    phone: "01000000002",
    name: "হাফেজ যাকারিয়া",
    gender: "M",
    role: "invigilator",
    memberCode: null,
    level: "none",
    usrah: null,
  },
  {
    phone: "01000000015",
    name: "উস্তায়া সালেহা আক্তার",
    gender: "F",
    role: "invigilator",
    memberCode: null,
    level: "none",
    usrah: null,
  },
  {
    phone: "01000000003",
    name: "মাওলানা ইউসুফ",
    gender: "M",
    role: "usrah_head",
    memberCode: "DS-000003",
    level: "farze_ain_1",
    usrah: "উসরা আল-ফুরকান",
  },
  {
    phone: "01000000005",
    name: "উম্মে হাবিবা",
    gender: "F",
    role: "usrah_head",
    memberCode: "DS-000005",
    level: "farze_ain_1",
    usrah: "উসরা আয়েশা সিদ্দিকা",
  },
  {
    phone: "01000000004",
    name: "রাফিউল ইসলাম",
    gender: "M",
    role: "daee",
    memberCode: "DS-000004",
    level: "muhibbus_sunnah",
    usrah: "আল-ফুরকান",
    note: "উত্তীর্ণ মূল্যায়ন · ৯১%",
  },
  {
    phone: "01000000006",
    name: "মারিয়াম হাসান",
    gender: "F",
    role: "daee",
    memberCode: "DS-000006",
    level: "muhibbus_sunnah",
    usrah: "আয়েশা সিদ্দিকা",
    note: "উত্তীর্ণ মূল্যায়ন · ৮৮%",
  },
  {
    phone: "01000000009",
    name: "মেহেদী হাসান",
    gender: "M",
    role: "daee",
    memberCode: "DS-000009",
    level: "muhibbus_sunnah",
    usrah: "আল-ফুরকান",
    note: "আখলাক খাতায় অনুত্তীর্ণ",
  },
  {
    phone: "01000000013",
    name: "সাদিয়া রহমান",
    gender: "F",
    role: "daee",
    memberCode: "DS-000013",
    level: "muhibbus_sunnah",
    usrah: "আয়েশা সিদ্দিকা",
  },
  {
    phone: "01000000007",
    name: "তানভীর হোসেন",
    gender: "M",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আল-ফুরকান",
  },
  {
    phone: "01000000008",
    name: "সাইফুল ইসলাম",
    gender: "M",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আল-ফুরকান",
    note: "ডেমো ডে-আনলক আছে",
  },
  {
    phone: "01000000010",
    name: "আব্দুর রহিম",
    gender: "M",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আল-ফুরকান",
  },
  {
    phone: "01000000011",
    name: "ফাতিমা আক্তার",
    gender: "F",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আয়েশা সিদ্দিকা",
  },
  {
    phone: "01000000012",
    name: "নুসরাত জাহান",
    gender: "F",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আয়েশা সিদ্দিকা",
  },
  {
    phone: "01000000014",
    name: "রাইসা খাতুন",
    gender: "F",
    role: "user",
    memberCode: null,
    level: "none",
    usrah: "আয়েশা সিদ্দিকা",
  },
];

export const ROLE_ORDER: Role[] = ["full_admin", "invigilator", "usrah_head", "daee", "user"];
