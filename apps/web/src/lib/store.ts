"use client";

// Global app state: tab/subview navigation, session, guest profile (persisted),
// referral capture, and the offline-first amal cache + outbox.
// The outbox is the "Drift (SQLite)" of the web workspace: local writes land
// here first, then batched-upsert to the API; guest data merges on sign-up.

import { create } from "zustand";
import { persist, createJSONStorage } from "zustand/middleware";
import type { AmalEntry, Gender, Lang, CalcMethodKey, Madhhab, PrayerAdjust, User } from "@/types/domain";
import { CITIES, DHAKA } from "@/lib/cities";
import { API_BASE, apiUrl } from "@/lib/api-base";

export type Tab = "home" | "amal" | "dawah" | "ilm" | "more";

export interface LocalProfile {
  name: string;
  gender: Gender | null;
  language: Lang;
  city: string; // city nameEn
  lat: number;
  lng: number;
  method: CalcMethodKey;
  madhhab: Madhhab;
  onboardingDone: boolean;
  /** the member's own Hijri correction, −2..2 days (kept on this device) */
  hijriAdjust?: number;
  /** minutes per waqt to match the member's own mosque (synced to the account) */
  prayerAdjust?: PrayerAdjust;
}

export type SyncState = "idle" | "syncing" | "offline" | "error";

const entryKey = (e: { date: string; amalKey: string }) => `${e.date}#${e.amalKey}`;

interface AppState {
  hydrated: boolean;
  // navigation
  tab: Tab;
  view: string;
  params: Record<string, string | number>;
  navHistory: { tab: Tab; view: string; params: Record<string, string | number> }[];
  adminOpen: boolean;
  // auth
  user: User | null;
  authChecked: boolean;
  authModal: boolean;
  referralCode: string | null;
  // local profile (guest preferences; also pre-signup for logged users)
  profile: LocalProfile;
  // amal local cache + outbox (offline-first)
  amalCache: Record<string, AmalEntry>;
  outbox: Record<string, AmalEntry>;
  syncState: SyncState;

  // actions
  nav: (tab: Tab, view?: string, params?: Record<string, string | number>) => void;
  back: () => void;
  setAdminOpen: (open: boolean) => void;
  setUser: (user: User | null) => void;
  setAuthModal: (open: boolean) => void;
  setAuthChecked: (v: boolean) => void;
  setReferralCode: (code: string | null) => void;
  updateProfile: (partial: Partial<LocalProfile>) => void;
  writeEntry: (entry: AmalEntry) => void;
  hydrateFromServer: (entries: AmalEntry[]) => void;
  setSyncState: (s: SyncState) => void;
  clearOutboxKeys: (keys: string[]) => void;
  dropRejected: (rejections: { date: string; amalKey: string }[]) => void;
  mergeGuestData: () => AmalEntry[];
}

const DEFAULT_PROFILE: LocalProfile = {
  name: "",
  gender: null,
  language: "bn",
  city: DHAKA.nameEn,
  lat: DHAKA.lat,
  lng: DHAKA.lng,
  method: "ifb",
  madhhab: "hanafi",
  onboardingDone: false,
};

let flushTimer: ReturnType<typeof setTimeout> | null = null;

export const useApp = create<AppState>()(
  persist(
    (set, get) => ({
      hydrated: false,
      tab: "home",
      view: "default",
      params: {},
      navHistory: [],
      adminOpen: false,
      user: null,
      authChecked: false,
      authModal: false,
      referralCode: null,
      profile: DEFAULT_PROFILE,
      amalCache: {},
      outbox: {},
      syncState: "idle",

      nav: (tab, view = "default", params = {}) => {
        const s = get();
        const current = { tab: s.tab, view: s.view, params: s.params };
        set({
          tab,
          view,
          params,
          navHistory: current.view !== "default" || current.tab !== tab ? [...s.navHistory, current].slice(-20) : s.navHistory,
          adminOpen: false,
        });
        if (typeof window !== "undefined") window.scrollTo({ top: 0 });
      },

      back: () => {
        const s = get();
        const prev = s.navHistory[s.navHistory.length - 1];
        if (prev) {
          set({ ...prev, navHistory: s.navHistory.slice(0, -1) });
        } else {
          set({ view: "default", params: {} });
        }
        if (typeof window !== "undefined") window.scrollTo({ top: 0 });
      },

      setAdminOpen: (open) => set({ adminOpen: open }),

      setUser: (user) => {
        set({ user, authChecked: true, authModal: false });
        if (user) {
          // language/location follow the account
          set({
            profile: {
              ...get().profile,
              name: user.name,
              gender: user.gender,
              language: user.language,
              city: user.city ?? get().profile.city,
              lat: user.lat ?? get().profile.lat,
              lng: user.lng ?? get().profile.lng,
              method: user.calcMethod,
              madhhab: user.madhhab,
              // the account's mosque adjustment wins once it has one
              prayerAdjust:
                user.prayerAdjust && Object.keys(user.prayerAdjust).length > 0
                  ? user.prayerAdjust
                  : get().profile.prayerAdjust,
              onboardingDone: true,
            },
          });
          scheduleFlush(get, set);
        }
      },
      setAuthModal: (open) => set({ authModal: open }),
      setAuthChecked: (v) => set({ authChecked: v }),
      setReferralCode: (code) => set({ referralCode: code }),

      updateProfile: (partial) => set({ profile: { ...get().profile, ...partial } }),

      writeEntry: (entry) => {
        const k = entryKey(entry);
        set({
          amalCache: { ...get().amalCache, [k]: entry },
          outbox: { ...get().outbox, [k]: entry },
        });
        scheduleFlush(get, set);
      },

      hydrateFromServer: (entries) => {
        const s = get();
        const next = { ...s.amalCache };
        for (const e of entries) {
          const k = entryKey(e);
          // local un-synced edits win until flushed
          if (s.outbox[k]) continue;
          next[k] = e;
        }
        set({ amalCache: next });
      },

      setSyncState: (syncState) => set({ syncState }),
      clearOutboxKeys: (keys) => {
        const s = get();
        const outbox = { ...s.outbox };
        for (const k of keys) delete outbox[k];
        set({ outbox });
      },
      dropRejected: (rejections) => {
        const s = get();
        const outbox = { ...s.outbox };
        for (const r of rejections) delete outbox[`${r.date}#${r.amalKey}`];
        set({ outbox });
      },
      mergeGuestData: () => Object.values(get().outbox),
    }),
    {
      name: "sunnahlife-app",
      storage: createJSONStorage(() => localStorage),
      // v1 (2026-10-09): IFB became the default; Karachi was only ever the
      // default before, so a stored "karachi" moves too (server migration does
      // the same).
      version: 1,
      migrate: (persisted, version) => {
        const st = persisted as { profile?: LocalProfile };
        if (version < 1 && st?.profile?.method === "karachi") st.profile.method = "ifb";
        return st as never;
      },
      partialize: (s) => ({
        profile: s.profile,
        amalCache: s.amalCache,
        outbox: s.outbox,
        referralCode: s.referralCode,
      }),
      onRehydrateStorage: () => (state) => {
        state?.setSyncState(typeof navigator !== "undefined" && !navigator.onLine ? "offline" : "idle");
        // zustand hydrates sync storages DURING create() — `useApp` is still in
        // its temporal dead zone there. Defer the flag flip past module init.
        queueMicrotask(() => useApp.setState({ hydrated: true }));
      },
    }
  )
);

/** Debounced outbox flush (batched upsert). Called after every write/login. */
function scheduleFlush(get: () => AppState, set: (p: Partial<AppState>) => void) {
  if (typeof window === "undefined") return;
  if (flushTimer) clearTimeout(flushTimer);
  flushTimer = setTimeout(async () => {
    const s = get();
    if (!s.user || !navigator.onLine) {
      set({ syncState: s.user ? "error" : "idle" });
      return;
    }
    const pending = Object.values(s.outbox);
    if (pending.length === 0) {
      set({ syncState: "idle" });
      return;
    }
    set({ syncState: "syncing" });
    try {
      // Outbox flush goes through the sanctioned URL builder too (same-origin
      // gateway in the sandbox, absolute API base in production).
      const res = await fetch(apiUrl("/api/amal/entries"), {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        credentials: API_BASE ? "include" : "same-origin",
        body: JSON.stringify({ entries: pending }),
      });
      if (!res.ok) throw new Error("flush failed");
      const data = (await res.json()) as { accepted: AmalEntry[]; rejected: { date: string; amalKey: string }[] };
      const acceptedKeys = data.accepted.map(entryKey);
      const { clearOutboxKeys, dropRejected } = useApp.getState();
      clearOutboxKeys(acceptedKeys);
      if (data.rejected?.length) dropRejected(data.rejected);
      set({ syncState: useApp.getState().outbox && Object.keys(useApp.getState().outbox).length > 0 ? "error" : "idle" });
    } catch {
      set({ syncState: navigator.onLine ? "error" : "offline" });
    }
  }, 1200);
}

// Fire a flush when connectivity returns
if (typeof window !== "undefined") {
  window.addEventListener("online", () => {
    useApp.setState({ syncState: "idle" });
    scheduleFlush(() => useApp.getState(), (p) => useApp.setState(p));
  });
  window.addEventListener("offline", () => useApp.setState({ syncState: "offline" }));
}

/** Convenience selectors */
export function currentPrayerConfig(): { lat: number; lng: number; city: string; method: CalcMethodKey; madhhab: Madhhab; tzOffsetHours: number; adjust: PrayerAdjust } {
  const p = useApp.getState().profile;
  const city = CITIES.find((c) => c.nameEn === p.city);
  const tz = city?.tz ?? -new Date().getTimezoneOffset() / 60;
  return { lat: p.lat, lng: p.lng, city: p.city, method: p.method, madhhab: p.madhhab, tzOffsetHours: tz, adjust: p.prayerAdjust ?? {} };
}
