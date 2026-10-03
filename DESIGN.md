# DESIGN.md — Sunnah Life

The design brief every UI change follows (mobile, web, admin). Values live in
`packages/design-tokens/tokens.json`; the full reference with live component
previews is the **Sunnah Life design system**
(https://claude.ai/artifact/PANErGmH2zS4YE3TG1u4eB, private to the project
owner; `docs/DESIGN_SYSTEM.md` is the in-repo version). The review workflow
is the `sunnah-life-design` skill in `.claude/skills/`.

## Who it is for

Bangladeshi Muslims on low-end Android phones (2–3 GB RAM, 5–6 inch, patchy
data), from teenagers to grandparents, and the Dawatus Sunnah da'ees, usrah
heads and supervisors who run their tarbiyah through it. Men and women live in
strictly separated circles. The app should feel **calm, trustworthy and
worshipful**: a clean prayer mat, not a game or a bank.

## Rules

1. **Bengali first.** Every visible string goes through l10n (`bn`, `en`,
   `ar` RTL). Bengali numerals in `bn` (DS codes stay Latin). Times with day
   parts (`ভোর ৫:১১`), dates in three calendars on the header.
2. **Tokens only.** No raw hex, no ad-hoc font sizes. Colour roles:
   `primary` green for identity and action, `gold` for honour and marks,
   `primary-soft` for "selected / now", `alert` on `alert-soft` for calm
   warnings, `muted-foreground` for secondary text.
3. **Type.** Hind Siliguri, body 16sp at line-height 1.6 minimum; Amiri Quran
   26/2.2 for ayahs, Amiri 20/2.1 for du'as (always RTL, end-aligned, meaning
   below). Weights 400/600/700 only.
4. **Shape hierarchy.** Hero `radius-xl` + `shadow-lifted`; cards
   `radius-lg` + 1px `border`, no shadow; controls `radius-md`; badges
   `radius-pill`. Never nest cards.
5. **Reachable and readable.** 44dp targets, 4.5:1 text contrast in both
   themes (3:1 at 24sp+), no clipping or ellipsis of meaningful text at 360dp
   width and 1.3x text, Bengali labels on every icon-only control.
6. **One main action per screen.** One filled button; the rest outlined or
   text.
7. **Never blank, never raw.** Designed empty, error and offline states;
   skeletons shaped like the final layout; no raw exception text.
8. **Calm feedback.** Missed prayers and low scores get forward-looking copy,
   never red floods or guilt. Leaderboards show bands, not ranks. No emoji as
   UI, no confetti, motion ≤ 320ms, respect reduced motion.
9. **Privacy visible.** Where personal data is entered, say who can see it.
   Gender isolation is non-negotiable.
10. **Paper-faithful.** The muhasaba diary, the monthly sheet and the Farze
    Ain assessment keep the Foundation's paper wording, order and grouping.

## Known design debt (fix when touching these)

- Selected **একা** tristate chip paints `primary-foreground` on `secondary`
  (1.1:1).
- `gold-text` on light grounds is 3.1–3.3:1 (level pills such as শুরুর
  পর্যায়); needs a darker gold ink token.
- StreakBadge appends a 🔥 emoji after the count.
- 0% completion rings nearly vanish in dark (`muted` track on `card`).
