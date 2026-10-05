// Qur'an reader helpers (mobile parity with lib/features/ilm/quran_audio.dart):
// per-ayah recitation URLs, the reciter catalog, ayah bookmarks and the
// go-to-ayah input. The app-config `audioBase` (quranicaudio) hosts per-SURAH
// files only, so per-ayah audio comes from the everyayah.com layout, as in
// the app; `audioBase` stays the on/off gate for the audio buttons.

export const AYAH_AUDIO_BASE = "https://everyayah.com/data";

export interface Reciter {
  id: string;
  path: string;
  nameBn: string;
}

export const RECITERS: Reciter[] = [
  { id: "alafasy", path: "Alafasy_128kbps", nameBn: "মিশারি রশিদ আল-আফাসি" },
  { id: "husary", path: "Husary_128kbps", nameBn: "মাহমুদ খলিল আল-হুসারি" },
  { id: "minshawi", path: "Minshawy_Murattal_128kbps", nameBn: "মুহাম্মদ সিদ্দিক আল-মিনশাবি" },
  { id: "sudais", path: "Abdurrahmaan_As-Sudais_192kbps", nameBn: "আব্দুর রহমান আস-সুদাইস" },
];

export function reciterById(id: string | null | undefined): Reciter {
  return RECITERS.find((r) => r.id === id) ?? RECITERS[0];
}

export function ayahAudioUrl(reciter: Reciter, surah: number, ayah: number): string {
  const pad = (n: number) => String(n).padStart(3, "0");
  return `${AYAH_AUDIO_BASE}/${reciter.path}/${pad(surah)}${pad(ayah)}.mp3`;
}

const RECITER_KEY = "sl-quran-reciter";
const BOOKMARKS_KEY = "sl-quran-bookmarks";

export function readReciter(): Reciter {
  try {
    return reciterById(localStorage.getItem(RECITER_KEY));
  } catch {
    return RECITERS[0];
  }
}

export function saveReciter(r: Reciter) {
  try {
    localStorage.setItem(RECITER_KEY, r.id);
  } catch {}
}

export interface AyahBookmark {
  surah: number;
  ayah: number;
  nameBn: string;
}

export function readBookmarks(): AyahBookmark[] {
  try {
    const raw = JSON.parse(localStorage.getItem(BOOKMARKS_KEY) ?? "[]") as AyahBookmark[];
    return Array.isArray(raw) ? raw.filter((b) => typeof b?.surah === "number" && typeof b?.ayah === "number") : [];
  } catch {
    return [];
  }
}

/** Adds or removes one bookmark; returns the new list (newest first). */
export function toggleBookmark(b: AyahBookmark): AyahBookmark[] {
  const all = readBookmarks();
  const has = all.some((x) => x.surah === b.surah && x.ayah === b.ayah);
  const next = has ? all.filter((x) => !(x.surah === b.surah && x.ayah === b.ayah)) : [b, ...all];
  try {
    localStorage.setItem(BOOKMARKS_KEY, JSON.stringify(next));
  } catch {}
  return next;
}

/** The go-to-ayah input: Bengali or ASCII digits → number (else null). */
export function parseAyahInput(input: string): number | null {
  const ascii = input.trim().replace(/[০-৯]/g, (d) => String("০১২৩৪৫৬৭৮৯".indexOf(d)));
  if (!/^\d{1,3}$/.test(ascii)) return null;
  return Number(ascii);
}
