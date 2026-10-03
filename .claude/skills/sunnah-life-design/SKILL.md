---
name: sunnah-life-design
description: Design, redesign or review any Sunnah Life screen (Flutter mobile, Next.js web or admin). Use before changing UI, when auditing screens, when building a prototype for the Foundation, or when the user asks for better UI/UX. Covers the audience, the design rules, how to render real screens for review, and the per-screen checklist.
---

# Sunnah Life design workflow

## 1. Load the brief

- Read `DESIGN.md` (repo root): audience, the ten rules, known design debt.
- Values: `packages/design-tokens/tokens.json` (compiled to
  `apps/mobile/lib/design/design_tokens.dart` and `apps/web/src/app/globals.css`
  by `node packages/design-tokens/build.mjs`; never hand-edit those two).
- Component reference with live previews: the design system artifact
  https://claude.ai/artifact/PANErGmH2zS4YE3TG1u4eB. Read its
  `project/README.md` (Artifact `read` with `path`) when you need the brand
  book, and `project/components/<Name>/README.md` for a component's rules.
  If a change alters tokens or a component's look, update the artifact too
  (revise only the changed files).
- Spec sources: `docs/PLAN.md`, `packages/content` (verbatim Foundation forms:
  diary, monthly sheet, Farze Ain assessment, Muhibbus outline). Paper forms win
  over invention.

## 2. See the real screen before changing it

Render the actual app, never guess from code:

```bash
cd apps/mobile
MSYS_NO_PATHCONV=1 SL_RENDER_DIR=<scratch>/screens SL_RENDER_PATHS=/amal,/amal/month flutter test test/render_screens_test.dart
```

`MSYS_NO_PATHCONV=1` stops Git Bash rewriting `/` routes into Windows paths.
Without `SL_RENDER_PATHS` it renders every main route. Each route comes out in
light and dark, at 412dp/1.0x and 360dp/1.3x text. Look at the PNGs with
Read. The fixtures (pinned clock, signed-in da'ee, fake API) live in
`test/golden_fixtures.dart`; extend `GoldenApi` when a screen needs data.
For widgets in isolation the debug route `/__gallery` (kit gallery) renders
every shared component.

## 3. Big redesigns: prototype first

For a new or heavily changed major screen (Home, Today diary, Dawah, the
assessment), build an interactive HTML prototype as an Artifact from the
design system's tokens and components, at phone width, Bengali content, both
themes. Get the user's (and through them the Foundation's) approval before
writing Flutter. Small fixes go straight to code.

## 4. Per-screen checklist

Run it on the rendered PNGs before and after a change.

- **Job.** The screen's single job is obvious within 3 seconds; one filled
  primary action at most.
- **Hierarchy.** Title `heading-large`, sections `heading` with a 20px icon,
  `space-24` between sections, shape hierarchy hero > card > control > pill.
- **Tokens.** No raw colours or sizes; `primary-soft` for selected/now; gold
  only for marks or on green.
- **Text.** No clipped or ellipsised meaningful text at 360dp/1.3x; Bengali
  body ≥ 16sp, line-height ≥ 1.45; Bengali numerals; correct Islamic terms;
  paper wording where a paper form exists.
- **Contrast.** Every text/background pair ≥ 4.5:1 in both themes (3:1 at
  24sp+, icons, control borders). Check selected states too.
- **Touch.** Every control ≥ 44dp; icon-only controls carry a Bengali
  semantics label; tristates are radio groups.
- **States.** Empty, error, offline and loading are designed (vignette, retry,
  gold offline strip, skeleton); no raw exception text.
- **RTL.** Arabic blocks RTL + end-aligned; under `ar` the layout mirrors and
  directional icons flip.
- **Tone.** Calm, encouraging, no shame, no emoji as UI, motion ≤ 320ms.
- **Privacy.** Where data is entered, the screen says who can see it.
- **Device.** Finally check on a real low-end phone via the signed APK
  (Desktop\SunnahLife-APK) — scrolling smoothness and tap accuracy only show
  there.

## 5. Ship

Small commits on main; `flutter analyze` and the test suite green; if a golden
in `test/goldens/` changes intentionally, regenerate it on Linux (CI) rather
than Windows. Then merge to staging and deploy as described in the project
memory.
