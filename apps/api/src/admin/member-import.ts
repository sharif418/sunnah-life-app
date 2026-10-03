// ─────────────────────────────────────────────────────────────────────────────
// Member register import (2026-10-03 audit: "no importer for the old data";
// "legacy DS ids can't be entered"). The Dawatus Sunnah office keeps its
// member list in a spreadsheet; full_admin uploads it as CSV, previews
// (dryRun) and then commits. Row by row — a bad row is reported and skipped,
// never aborts the rest.
//
// Rules
//  · phone is the identity (normalised like sign-in). An existing account is
//    never re-gendered or re-roled here — only its EMPTY register fields
//    (district / workplace / department / email / member code) are filled.
//  · gender is required for a new account (M/F or পুরুষ/নারী/ভাই/বোন).
//  · usrah by name; it must exist and match the member's gender (an usrah is
//    single-gender — the same rule as every other path).
//  · member code: a legacy "DS-123" is kept (normalised to DS-000123) when
//    free; a new দাঈ without one gets the next code.
// ─────────────────────────────────────────────────────────────────────────────
import { ApiProperty } from "@nestjs/swagger";
import { ArrayMaxSize, IsArray, IsBoolean, IsInt, IsOptional, Min } from "class-validator";
import type { Prisma } from "../common/prisma-client";
import { ApiError } from "../common/api-error";

/** Per request — the admin client sends a big sheet in chunks (the JSON
 *  body limit is 100 kB), passing `offset` so row numbers stay true. */
export const IMPORT_MAX_ROWS = 300;

export class MemberImportDto {
  @ApiProperty({ description: "Parsed CSV rows (header → value)", type: [Object] })
  @IsArray()
  @ArrayMaxSize(IMPORT_MAX_ROWS, { message: `একবারে সর্বোচ্চ ${IMPORT_MAX_ROWS} সারি` })
  rows!: Record<string, string>[];

  @ApiProperty({ required: false, description: "index of rows[0] in the whole sheet" })
  @IsOptional()
  @IsInt()
  @Min(0)
  offset?: number;

  @ApiProperty({ required: false, description: "true = validate + report only" })
  @IsOptional()
  @IsBoolean()
  dryRun?: boolean;
}

export type ImportAction = "create" | "update" | "skip" | "error";

export interface ImportRowResult {
  row: number; // 1-based, as in the spreadsheet (header = row 1 ⇒ data from 2)
  name: string;
  phone: string;
  action: ImportAction;
  message: string;
}

/** Header aliases (Bengali / English, case-insensitive). */
const HEADERS: Record<string, string[]> = {
  name: ["name", "নাম"],
  phone: ["phone", "mobile", "ফোন", "মোবাইল", "মোবাইল নম্বর"],
  gender: ["gender", "লিঙ্গ"],
  role: ["role", "ভূমিকা"],
  memberCode: ["member code", "membercode", "code", "সদস্য কোড", "ডিএস কোড", "ds code"],
  usrah: ["usrah", "উসরা", "উসরাহ"],
  district: ["district", "জেলা"],
  workplace: ["workplace", "কর্মস্থল", "প্রতিষ্ঠান"],
  department: ["department", "বিভাগ", "পদবি", "বিভাগ / পদবি"],
  category: ["category", "ক্যাটাগরি"],
  email: ["email", "ইমেইল"],
};

export function pickField(row: Record<string, string>, field: keyof typeof HEADERS): string {
  for (const [k, v] of Object.entries(row)) {
    if (HEADERS[field].includes(k.trim().toLowerCase())) return (v ?? "").trim();
  }
  return "";
}

const BN_DIGITS = "০১২৩৪৫৬৭৮৯";
export function normalizePhone(raw: string): string | null {
  const ascii = raw.replace(/[০-৯]/g, (d) => String(BN_DIGITS.indexOf(d)));
  let p = ascii.replace(/[^\d+]/g, "");
  // Excel drops the leading 0 of "01712…" (stored as a number)
  if (/^1\d{9}$/.test(p)) p = `0${p}`;
  return /^\+?\d{10,15}$/.test(p) ? p : null;
}

export function normalizeGender(raw: string): "M" | "F" | null {
  const g = raw.trim().toLowerCase();
  if (["m", "male", "পুরুষ", "ভাই"].includes(g)) return "M";
  if (["f", "female", "নারী", "মহিলা", "বোন"].includes(g)) return "F";
  return null;
}

export function normalizeRole(raw: string): "user" | "daee" | null {
  const r = raw.trim().toLowerCase();
  if (!r || ["user", "সদস্য", "সাধারণ"].includes(r)) return "user";
  if (["daee", "da'ee", "দাঈ", "দায়ী"].includes(r)) return "daee";
  return null; // heads / invigilators are appointed in the console, not imported
}

export function normalizeCategory(raw: string): "general" | "hafez" | "alim" | null {
  const c = raw.trim().toLowerCase();
  if (!c || ["general", "সাধারণ"].includes(c)) return "general";
  if (["hafez", "hafiz", "হাফেজ", "হাফিজ"].includes(c)) return "hafez";
  if (["alim", "আলিম", "আলেম"].includes(c)) return "alim";
  return null;
}

export function normalizeMemberCode(raw: string): string | null | undefined {
  const t = raw.trim().toUpperCase().replace(/[০-৯]/g, (d) => String(BN_DIGITS.indexOf(d)));
  if (!t) return undefined; // not given
  const m = /^DS-?(\d{1,6})$/.exec(t);
  return m ? `DS-${m[1].padStart(6, "0")}` : null; // null = malformed
}

const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Validate + (unless dryRun) apply. Runs inside the caller's full_admin RLS
 * transaction; returns one result per input row plus the totals.
 */
export async function importMembers(
  tx: Prisma.TransactionClient,
  rows: Record<string, string>[],
  dryRun: boolean,
  nextMemberCode: (tx: Prisma.TransactionClient) => Promise<string>,
  offset = 0
): Promise<{ results: ImportRowResult[]; totals: Record<ImportAction, number> }> {
  if (!rows.length) throw new ApiError(400, "ফাইলে কোনো সারি নেই");

  const usrahs = await tx.usrah.findMany({ select: { id: true, name: true, gender: true } });
  const usrahByName = new Map(usrahs.map((u) => [u.name.trim(), u]));
  const seenPhones = new Set<string>();
  const seenCodes = new Set<string>();
  const results: ImportRowResult[] = [];

  for (let i = 0; i < rows.length; i++) {
    const r = rows[i];
    const rowNo = offset + i + 2;
    const name = pickField(r, "name");
    const rawPhone = pickField(r, "phone");
    const out = (action: ImportAction, message: string, phone = rawPhone) =>
      results.push({ row: rowNo, name, phone, action, message });

    const phone = normalizePhone(rawPhone);
    if (!name) { out("error", "নাম নেই"); continue; }
    if (!phone) { out("error", "মোবাইল নম্বর ঠিক নয়"); continue; }
    if (seenPhones.has(phone)) { out("skip", "ফাইলে এই নম্বর আগেও আছে", phone); continue; }
    seenPhones.add(phone);

    const emailRaw = pickField(r, "email").toLowerCase();
    if (emailRaw && !EMAIL.test(emailRaw)) { out("error", "ইমেইল ঠিক নয়", phone); continue; }
    const code = normalizeMemberCode(pickField(r, "memberCode"));
    if (code === null) { out("error", "সদস্য কোড ঠিক নয় (যেমন DS-000123)", phone); continue; }
    if (code && seenCodes.has(code)) { out("error", `কোড ${code} ফাইলে দুবার`, phone); continue; }
    if (code) seenCodes.add(code);
    const category = normalizeCategory(pickField(r, "category"));
    if (!category) { out("error", "ক্যাটাগরি ঠিক নয়", phone); continue; }

    const register = {
      district: pickField(r, "district") || null,
      workplace: pickField(r, "workplace") || null,
      department: pickField(r, "department") || null,
      email: emailRaw || null,
    };

    const existing = await tx.user.findUnique({ where: { phone } });
    if (code) {
      const holder = await tx.user.findUnique({ where: { memberCode: code }, select: { id: true } });
      if (holder && holder.id !== existing?.id) {
        out("error", `কোড ${code} অন্য সদস্যের`, phone);
        continue;
      }
    }

    if (existing) {
      // never re-gender / re-role here — fill only what is empty
      const data: Record<string, unknown> = {};
      for (const [k, v] of Object.entries(register)) {
        if (v && !(existing as Record<string, unknown>)[k]) data[k] = v;
      }
      if (code && !existing.memberCode) data.memberCode = code;
      if (!Object.keys(data).length) { out("skip", "আগে থেকেই আছে — নতুন কিছু নেই", phone); continue; }
      if (!dryRun) await tx.user.update({ where: { id: existing.id }, data: data as never });
      out("update", `খালি ঘর পূরণ: ${Object.keys(data).join(", ")}`, phone);
      continue;
    }

    const gender = normalizeGender(pickField(r, "gender"));
    if (!gender) { out("error", "লিঙ্গ দিন (পুরুষ / নারী)", phone); continue; }
    const role = normalizeRole(pickField(r, "role"));
    if (!role) { out("error", "ভূমিকা: সদস্য বা দাঈ (দায়িত্বশীল নিয়োগ কনসোল থেকে)", phone); continue; }
    const usrahName = pickField(r, "usrah");
    let usrahId: string | null = null;
    if (usrahName) {
      const u = usrahByName.get(usrahName);
      if (!u) { out("error", `উসরা "${usrahName}" পাওয়া যায়নি`, phone); continue; }
      if (u.gender !== gender) { out("error", "উসরা এক-লিঙ্গ — লিঙ্গ মেলে না", phone); continue; }
      usrahId = u.id;
    }

    if (!dryRun) {
      const memberCode = code ?? (role === "daee" ? await nextMemberCode(tx) : null);
      await tx.user.create({
        data: {
          phone,
          name,
          gender,
          role,
          category,
          usrahId,
          memberCode,
          ...register,
        },
      });
    }
    out("create", role === "daee" ? "নতুন দাঈ" : "নতুন সদস্য", phone);
  }

  const totals = { create: 0, update: 0, skip: 0, error: 0 } as Record<ImportAction, number>;
  for (const r of results) totals[r.action]++;
  return { results, totals };
}
