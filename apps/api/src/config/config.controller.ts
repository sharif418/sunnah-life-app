import { Controller, Get } from "@nestjs/common";
import { ApiOperation, ApiTags } from "@nestjs/swagger";
import type { AppConfig } from "../shared/domain";
import { PrismaService } from "../common/prisma.service";

// ─────────────────────────────────────────────────────────────────────────────
// /api/config — ONE source of truth for the editable app configuration
// (Phase C/W1b): Hijri ±adjust, donation URL, the five institution contacts,
// app-user group links, leaderboard + detox flags, nisab prices, audio base.
//
// Precedence: AppConfigRow (key "app", written by the admin CMS —
// PATCH /api/admin/config) → content-pack defaults seeded by seed:reference
// (packages/content/app-config.json) → the hard-coded fallback below.
// Read path is cached 60 s per process — config is hot on every app open.
// ─────────────────────────────────────────────────────────────────────────────

const FALLBACK: AppConfig = {
  donationUrl: "https://as-sunnah.org/donation",
  domain: "sunnahlife.app",
  hijriAdjust: 0,
  nisab: { goldPerGramBdt: 16500, silverPerGramBdt: 220 },
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
  leaderboardEnabled: false,
  detoxEnabled: true,
};

/** Merge a partial stored value over the fallback (unknown keys ignored). */
export function mergeConfig(stored: unknown): AppConfig {
  if (!stored || typeof stored !== "object" || Array.isArray(stored)) return { ...FALLBACK };
  const s = stored as Record<string, unknown>;
  const out: AppConfig = { ...FALLBACK, nisab: { ...FALLBACK.nisab } };
  if (typeof s.donationUrl === "string" && s.donationUrl) out.donationUrl = s.donationUrl;
  if (typeof s.domain === "string" && s.domain) out.domain = s.domain;
  if (typeof s.hijriAdjust === "number" && Number.isInteger(s.hijriAdjust) && Math.abs(s.hijriAdjust) <= 2) {
    out.hijriAdjust = s.hijriAdjust;
  }
  if (s.nisab && typeof s.nisab === "object") {
    const n = s.nisab as Record<string, unknown>;
    if (typeof n.goldPerGramBdt === "number" && n.goldPerGramBdt > 0) out.nisab.goldPerGramBdt = n.goldPerGramBdt;
    if (typeof n.silverPerGramBdt === "number" && n.silverPerGramBdt > 0) out.nisab.silverPerGramBdt = n.silverPerGramBdt;
  }
  if (Array.isArray(s.contacts)) {
    const contacts = s.contacts
      .filter((c): c is Record<string, unknown> => !!c && typeof c === "object" && typeof c.org === "string")
      .map((c) => ({
        org: String(c.org),
        descBn: String(c.descBn ?? ""),
        ...(typeof c.phone === "string" ? { phone: c.phone } : {}),
        ...(typeof c.email === "string" ? { email: c.email } : {}),
        ...(typeof c.website === "string" ? { website: c.website } : {}),
        ...(typeof c.address === "string" ? { address: c.address } : {}),
      }));
    if (contacts.length) out.contacts = contacts;
  }
  if (Array.isArray(s.groups)) {
    const groups = s.groups
      .filter((g): g is Record<string, unknown> => !!g && typeof g === "object" && typeof g.url === "string")
      .map((g) => ({
        titleBn: String(g.titleBn ?? ""),
        url: String(g.url),
        ...(typeof g.descBn === "string" ? { descBn: g.descBn } : {}),
      }));
    if (groups.length) out.groups = groups;
  }
  if (typeof s.audioBase === "string" && s.audioBase) out.audioBase = s.audioBase;
  if (typeof s.leaderboardEnabled === "boolean") out.leaderboardEnabled = s.leaderboardEnabled;
  if (typeof s.detoxEnabled === "boolean") out.detoxEnabled = s.detoxEnabled;
  return out;
}

const CACHE_TTL_MS = 60_000;
const cache = globalThis as unknown as { slAppConfig?: { at: number; value: AppConfig } };

export function invalidateAppConfigCache(): void {
  cache.slAppConfig = undefined;
}

@ApiTags("config")
@Controller("config")
export class ConfigApiController {
  constructor(private readonly prisma: PrismaService) {}

  /** GET /api/config — public app configuration (AppConfig, cached 60 s). */
  @Get()
  @ApiOperation({ summary: "Public app configuration (admin-editable)" })
  async getConfig(): Promise<AppConfig> {
    const hit = cache.slAppConfig;
    if (hit && Date.now() - hit.at < CACHE_TTL_MS) return hit.value;
    let value = FALLBACK;
    try {
      // AppConfigRow is RLS-exempt (public config) — direct read as the
      // runtime role is the documented pattern for exempt tables.
      const row = await this.prisma.appConfigRow.findUnique({ where: { key: "app" } });
      if (row) value = mergeConfig(row.valueJson);
    } catch {
      /* DB not reachable → fallback */
    }
    cache.slAppConfig = { at: Date.now(), value };
    return value;
  }
}
