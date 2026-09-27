# Accessibility — WCAG AA contrast table (both themes)

Computed programmatically from `packages/design-tokens/tokens.json` (script
re-runnable; values verified by `node packages/design-tokens/build.mjs --check`
→ "globals.css in sync with tokens.json (70 color values verified)").

## Contrast — WCAG 2.1 AA

| # | Pair (foreground / background) | Ratio | Required | Result |
|---|---|---|---|---|
| 1 | light: foreground / background — body text | 14.48:1 | 4.5:1 | PASS |
| 2 | light: muted-foreground / background — secondary text | 5.22:1 | 4.5:1 | PASS |
| 3 | light: primary / background — links & emphasis | 8.74:1 | 4.5:1 | PASS |
| 4 | light: primary-foreground / primary — buttons | 8.74:1 | 4.5:1 | PASS |
| 5 | light: card-foreground / card — card text | 15.91:1 | 4.5:1 | PASS |
| 6 | light: gold-text / background — large gold text (countdown ≥18.66px bold) | 3.31:1 | 3.0:1 | PASS |
| 7 | light: alert / alert-soft — error text | 4.82:1 | 4.5:1 | PASS |
| 8 | dark: foreground / background — body text | 15.81:1 | 4.5:1 | PASS |
| 9 | dark: muted-foreground / background — secondary text | 7.7:1 | 4.5:1 | PASS |
| 10 | dark: primary / background — links & emphasis | 5.49:1 | 4.5:1 | PASS |
| 11 | dark: primary-foreground / primary — buttons | 5.56:1 | 4.5:1 | PASS |
| 12 | dark: card-foreground / card — card text | 14.16:1 | 4.5:1 | PASS |
| 13 | dark: gold-text / background — large gold text (countdown ≥18.66px bold) | 9.23:1 | 3.0:1 | PASS |
| 14 | dark: alert / alert-soft — error text | 4.51:1 | 4.5:1 | PASS |

### Fixes applied during the audit (this pass)

- **gold text** (light theme): raw brand gold `#C99A3B` measured 2.34:1 (FAIL
  for large text). Added a dedicated `--gold-text` semantic token
  (light `#B7791F` = goldDeep, 3.31:1 PASS; dark `#D9B25F`, 9.23:1 PASS) and
  swept all 23 `text-gold` usages in `apps/web` to `text-gold-text`. The raw
  gold remains for decorative borders/badges where contrast rules don't apply.
- **alert text** (light theme): `#C0392B` on `alert-soft` measured 4.49:1
  (0.01 short). Darkened to `#B93527` → 4.82:1 PASS. Changed in tokens.json +
  globals.css (parity check green).

## Other accessibility measures (this pass)

- **Flutter**: ARB-based localizations for bn/en/ar with full RTL when the
  Arabic locale is active (Directionality-driven; hard-coded left/right
  audited to directional variants); Semantics labels on interactive widgets
  (icon buttons, gesture detectors); Material minimum tap-target sizing.
- **Web**: logical CSS properties sweep (ms-/me-/ps-/pe-/start-/end-) so the
  `dir="rtl"` shell renders mirrored correctly; aria-labels on icon-only
  buttons; `tap-target` class (min 44px) on the bottom navigation and
  primary buttons; focus-visible ring via `outline-ring/50` base layer.
- **Text scaling (1.3×)**: Flutter screens use scale-safe layouts (no
  hard-coded heights on text containers; Amal widget tests run under an
  elevated textScaler).

Reproduce the table: the script is embedded in the project history
(`Phase B` worklog, Task B7) — thresholds: 4.5:1 normal text, 3:1 large text
(≥18.66px bold or ≥24px), WCAG 2.1 §1.4.3.
