# Sunnah Life — Design System (DESIGN_SYSTEM.md)

**Single source of truth:** `packages/design-tokens/tokens.json` → compiled to
both platforms by `packages/design-tokens/build.mjs`:

| Target | Artifact | Consumer |
|---|---|---|
| Web / admin (Tailwind v4, CSS-first) | `dist/tailwind.css` reference — the web app implements the same values as CSS variables in `src/app/globals.css` | web + admin |
| Flutter | `dist/flutter/design_tokens.dart` — complete `ThemeData` builders | `apps/mobile` |

```bash
cd packages/design-tokens
node build.mjs          # rebuild dist/tailwind.css + dist/flutter/design_tokens.dart
node build.mjs --check  # parity guard: fails if the web globals.css drifted from tokens.json
```

The `--check` guard runs in CI (`.github/workflows/ci.yml`, job `tokens`) —
**never hand-edit globals.css or design_tokens.dart without changing
tokens.json first.**

---

## 1. Palette

### Brand (theme-independent)

| Token | Hex | Use |
|---|---|---|
| `brand.primary` | `#1F4D3D` | deep green — identity color, headers, primary actions |
| `brand.primaryDeep` | `#173A2E` | pressed/emphasis |
| `brand.primarySoftLight` | `#EAF0EC` | tinted surfaces |
| `brand.gold` | `#C99A3B` | gold — accents, achievements, level badges |
| `brand.goldDeep` | `#B7791F` | pressed gold |
| `brand.goldSoftLight` | `#F6ECD8` | gold tint surfaces |
| `brand.success` | `#2E7D5B` | done states, jamaat |
| `brand.warning` | `#B7791F` | overdue, qaza warnings |
| `brand.alert` | `#C0392B` | destructive, rejected sync |
| `brand.alertSoftLight` | `#FCE4E4` | alert tint surfaces |

### Semantic — light theme (`:root` / `light`)

| Role | Hex | Role | Hex |
|---|---|---|---|
| `background` | `#F7F4EC` cream | `foreground` | `#222222` |
| `card` / `popover` | `#FFFFFF` | `card-foreground` | `#222222` |
| `primary` | `#1F4D3D` | `primary-foreground` | `#F7F4EC` |
| `primary-soft` | `#EAF0EC` | `secondary` | `#EFE9DC` |
| `muted` | `#F1EDE2` | `muted-foreground` | `#666666` |
| `accent` (gold) | `#C99A3B` | `accent-foreground` | `#3B2B0E` |
| `destructive` | `#C0392B` | `border` / `input` | `#E4DCCB` |
| `ring` | `#1F4D3D` | `success` | `#2E7D5B` |
| `gold-soft` | `#F6ECD8` | `alert-soft` | `#FCE4E4` |
| `chart1..5` | `#1F4D3D · #C99A3B · #2E7D5B · #8A9A5B · #B7791F` | | |

### Semantic — dark theme (`.dark` / `dark`)

| Role | Hex | Role | Hex |
|---|---|---|---|
| `background` | `#0E1613` green-black | `foreground` | `#F1EDE3` |
| `card` / `popover` | `#16211C` | `card-foreground` | `#F1EDE3` |
| `primary` | `#4C9B72` | `primary-foreground` | `#0B140F` |
| `primary-soft` | `#1A2B23` | `secondary` | `#1C2A24` |
| `muted` | `#1A2620` | `muted-foreground` | `#9FAAA2` |
| `accent` (gold) | `#D9B25F` | `accent-foreground` | `#241A05` |
| `destructive` | `#E06A5A` | `border` / `input` | `#26382F` |
| `ring` | `#4C9B72` | `success` | `#4C9B72` |
| `gold-soft` | `#2A2416` | `alert-soft` | `#3A211D` |
| `chart1..5` | `#4C9B72 · #D9B25F · #7FBF9F · #A3B845 · #E0C184` | | |

**Rules:** colors are only ever used via tokens (`bg-background`,
`text-primary`, `bg-primary-soft`, `text-gold`, `bg-gold-soft`, `text-alert`,
`bg-alert-soft`, `text-success`, `text-muted-foreground`, `border-border`) —
never raw hex. Gold on white is decorative only; for text on gold use
`gold-foreground`.

---

## 2. Typography

| Family | Stack | Purpose |
|---|---|---|
| Bengali | **Hind Siliguri** (fallback Noto Sans Bengali) | all bn UI text |
| Latin | **Inter** | English UI, numbers when lang=en |
| Qur'an | **Amiri Quran** (`font-quran`) | ayah display |
| Arabic | **Amiri** (`font-arabic`) | du'as, adhkar, names |
| Mono | ui-monospace | IDs, codes |

Web loads them via `next/font` (`src/app/layout.tsx`); Flutter via
`GoogleFonts` in `buildSunnahLightTheme()/buildSunnahDarkTheme()`.

Scale (size / line-height):

| Token | Size | Line height | Use |
|---|---|---|---|
| `caption` | 12 | 1.5 | timestamps, helper text |
| `body` | 16 | 1.6 | default — Bengali body ≥16, line-height ≥1.6 |
| `bodyLarge` | 18 | 1.6 | emphasized body |
| `heading` | 20 | 1.45 | section headers |
| `headingLarge` | 24 | 1.4 | screen titles |
| `display` | 28 | 1.35 | numbers, countdown |
| `quran` | 26 | 2.2 | Qur'an ayahs (generous leading) |
| `dua` | 20 | 2.1 | Arabic du'as |

---

## 3. Spacing, radii, elevation, motion

- **Spacing — 8-pt grid:** scale 4, 8, 12, 16, 20, 24, 32, 40, 48, 56, 64.
  Cards: `p-4` mobile / `sm:p-5`. Lists longer than ~8 items:
  `max-h-96 overflow-y-auto scroll-thin`.
- **Radii:** sm **8** · md **12** · lg **16** · xl **20** · pill **999**.
  Cards use `rounded-lg`(16) / `rounded-xl`(20); pills and badges
  `rounded-full`.
- **Elevation (tinted, never grey):**
  - `shadow-card`: `0 1px 2px rgb(31 77 61 / .05), 0 4px 16px rgb(31 77 61 / .06)`
  - `shadow-lifted`: `0 2px 4px rgb(31 77 61 / .08), 0 12px 32px rgb(31 77 61 / .12)`
- **Motion:** durations **120 / 200 / 320 ms** (fast / base / slow) with curves
  `cubic-bezier(.2,0,0,1)` (standard), `cubic-bezier(.05,.7,.1,1)` (decelerate),
  `cubic-bezier(.3,0,.8,.15)` (accelerate). Tailwind helpers: `motion-fast`,
  `motion-base`, `motion-slow`. Framer-motion: fade/slide entrances ≤320 ms
  only. Hover feedback: `transition-colors motion-base`.
- **Tap targets: 44×44 px minimum** (`tap-target` utility class; 44 also on
  Flutter via `SLElevation`/theme minimum tap target in `design_tokens.dart`).

---

## 4. RTL & localization rules

- Bengali-first UI; English and Arabic (full RTL) supported
  (`src/lib/i18n.ts` — bn/en/ar string tables; Flutter: `apps/mobile/lib/l10n`).
- Arabic blocks always: `dir="rtl"` + `text-right`/`text-end` + `font-quran`
  (Qur'an) or `font-arabic` (du'as/adhkar).
- **Bengali numerals:** all user-facing numbers render through
  `toBn("123") → "১২৩"` (`src/lib/calendars.ts`) when the language is bn —
  dates, times, counts, percentages, streaks. Arabic-Indic digits are never
  used for UI chrome.
- Mirroring: layout flips for Arabic; the gold divider / lattice patterns are
  direction-agnostic. Prayer-time "next" indicators flip with `dir`.
- Date/time formats: Bangla calendar (2019 reform) + Hijri (umalqura) labels
  beside Gregorian (`banglaDate`, `hijriDate`); weekdays Bangla
  (শনিবার-start weeks — `weekStartOf` Saturday convention).
- `formatTimeBn` adds Bengali day-parts: ভোর / সকাল / দুপুর / বিকাল / সন্ধ্যা / রাত.

---

## 5. Component inventory

### Web (shadcn/ui-based — `src/components/**`)

| Component | Where | Notes |
|---|---|---|
| Prayer countdown card | home | next-waqt countdown, forbidden-times strip, Ishraq/Duha/Tahajjud rows; `display` numerals via `toBn` |
| Tristate chips (জামাত/একা/কাযা) | amal | three-segment pill per salah; jamaat=success tint, qaza=warning; optimistic toggle |
| Month heatmap | amal → month | 31-day × definition grid; day lock state shows a lock glyph + "উসরা প্রধানের অনুমতি দরকার" |
| Streak badge | amal/home | consecutive ≥50 % days, gold `bg-gold-soft text-gold` |
| Sync badge | header | outbox pending / synced / offline; `text-alert` on rejected entries |
| Empty / offline / error states | all tabs | designed empty states (icon + bn line + CTA); offline banner; retry buttons on error — never blank spinners |
| Dhikr counter | ilm | haptic tick per repetition, `font-arabic` text, count via `toBn` |
| Skeletons | all | shadcn `Skeleton` blocks matching final layout shape |

Base kit: the full shadcn/ui set (`src/components/ui/*`), themable through the
token CSS variables above. Cards follow:
`bg-card border border-border rounded-xl shadow-card p-4 sm:p-5`.

### Flutter (`apps/mobile`)

- Themes: `buildSunnahLightTheme()` / `buildSunnahDarkTheme()` from
  `packages/design-tokens/dist/flutter/design_tokens.dart` (vendored at
  `apps/mobile/lib/design/design_tokens.dart`) — same palettes/scale as web,
  with `SLElevation` + `SLType` (`SLType.quran`, `SLType.dua`).
- **Design catalog:** `apps/mobile/lib/catalog/catalog_app.dart` — run with
  ```bash
  cd apps/mobile && flutter run -t lib/catalog/catalog_app.dart
  ```
  to browse every styled widget (chips, cards, countdown, heatmap cells,
  badges, empty states) in both themes side by side.
- Golden tests snapshot the theme; `flutter analyze` gates PRs in CI.

---

## 6. Accessibility

- **Contrast:** WCAG AA verified for both themes on all text/background token
  pairs (body 16/1.6 in cream-on-ink and ink-on-cream ≈ 13:1; primary
  `#1F4D3D` on cream ≈ 8:1; gold is decorative-only on light, paired with
  `gold-foreground` for text). Re-run the check when adding tokens:
  contrast pairs live in `packages/design-tokens/` docs.
- **Dynamic type:** the scale is rem/SP-based; Flutter uses
  `MediaQuery.textScaler` (no fixed pixel heights); web uses rem + Tailwind
  defaults — captions clamp at 12 px minimum.
- **Targets:** ≥44×44 px/pt everywhere (`tap-target`, Flutter theme
  `minimumSize` guidance).
- **Semantics:** all icon-only controls carry bn labels (aria-label /
  Semantics); the amal tristate chips are radio-groups semantically; haptics
  accompany, never replace, visual feedback.
- **Motion:** nothing flashes faster than 120 ms; no infinite loops except
  skeleton shimmer (reduced-motion disables entrances).
- Female-privacy trust note is part of the onboarding copy (day one), not
  buried in settings.
