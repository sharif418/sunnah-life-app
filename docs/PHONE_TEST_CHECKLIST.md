# Sunnah Life — Phone test checklist (PHONE_TEST_CHECKLIST.md)

The owner's on-device runbook: what to tap, on which build, and what "pass"
looks like. This is the Wave-5 deliverable the AUDIT rows marked
"Ready for device test" were waiting for (docs/AUDIT.md) — run it on every
release before announcing one.

---

## 0. Get the right build

From the repo's GitHub → **Actions** → the latest green run:

| Artifact (job) | What it is | Use it for |
|---|---|---|
| `internal-test-arm64-v8a` (`Flutter — release APKs · split-per-ABI (device test)`) | release build, **debug-signed** until the keystore secrets exist (docs/HUMAN_STEPS.md §4), arm64 | the main test build — realistic performance/fonts; most phones made since ~2016 |
| `internal-test-armeabi-v7a` (same job) | same, 32-bit armv7 | older devices only |
| `mobile-debug-apk` (`Flutter — analyze · test · debug APK`) | debug build | flows that need the mock-SMS `devCode` auto-fill (§2 below) — release builds hide it (`kDebugMode`-gated) |

Download → unzip → install (allow "install unknown apps" for the
browser/files app when prompted). Artifacts live 14 days; re-run the
workflow if expired. Release builds target the API base from the
`SUNNAH_API_BASE` repository variable (currently the staging API,
`https://api-staging.sunnahlife.ailearnersbd.com`) — CI fails the build if
it is unset, so a built APK always signs in.

|  | ✔ |
|---|---|
| App installs and launches (no crash on the splash/onboarding) | ☐ |
| App version under About matches the released `version:` in `apps/mobile/pubspec.yaml` (today `1.0.0+1`) | ☐ |

**Debug-signed expectations (not bugs):** App Links show the *chooser sheet*
instead of opening the app directly (verification requires the release
key's SHA-256 in `assetlinks.json` — docs/RELEASE.md §8.1); Play Protect may
ask for confirmation; the APK cannot be uploaded to Play.

---

## 1. Wave-5 fixes (this release's reason to re-test)

|  | How | Pass | ✔ |
|---|---|---|---|
| Bengali fonts everywhere — no tofu | walk every tab: হোম, আমল, দাওয়াত, ইলম, আরও; settings sub-screens; dialogs | every Bengali string renders as real letters — **no □□□ boxes anywhere** (the goldens now render with the real families; the on-device check is the last mile) | ☐ |
| ListTile / chip text visible in BOTH themes | toggle dark mode; open any screen with list rows + chips (More sections, dawah stats, assessment rows) | titles, subtitles and chip labels are dark-on-cream in light, light-on-dark in dark — **no invisible (near-white-on-cream) text** | ☐ |
| দুপুর label 11:30–15:00 · সন্ধ্যা from 17:00 | look at the Home schedule rows around midday and evening (or any list of prayer/program times) | a Zuhr row at ~11:59 reads **দুপুর ১১:৫৯** (not সকাল); a Maghrib row at ~17:51 reads **সন্ধ্যা ৫:৫১** (not বিকাল); 15:00–17:00 stays বিকাল | ☐ |
| More list scrolls clear of the headset button | আরও tab: scroll to the very bottom of the sectioned list | the last rows sit fully **above** the floating headset (contact) button with visible breathing room — nothing stays hidden under it on ANY of the five root tabs (home, amal, dawah, ilm, more) | ☐ |
| Dawah stat-cell labels wrap to 2 lines | দাওয়াত tab, top stats row | the label reads **মোট দাওয়াত / দিয়েছি** on two lines — no "মোট দাওয়াত দি…" ellipsis; same on a narrow screen / larger font | ☐ |

---

## 2. Sign-in & account (staging API)

|  | ✔ |
|---|---|
| OTP request on a demo phone (`01000000001`… — docs/DEMO_ACCOUNTS.md §1) returns within a few seconds | ☐ |
| On the **debug build**: the OTP auto-fills and the `ডেভ কোড` banner shows the code; on the release build the banner is suppressed (mock SMS, `kDebugMode`-gated) — use the debug artifact or a real provider (docs/HUMAN_STEPS.md §2) | ☐ |
| Wrong code → Bengali error; 4th code within 10 min → rate-limit message | ☐ |
| Sign-in lands on Home; kill + relaunch keeps the session | ☐ |
| Gender + name completion appears for a fresh social/genderless account, once | ☐ |
| Sign out → onboarding/auth state resets | ☐ |

---

## 3. Home: prayer times, calendar, amal

|  | ✔ |
|---|---|
| Prayer countdown matches a local mosque/Dhaka time (64-district snap: pick the district manually if GPS is off) | ☐ |
| Triple calendar (Bengali + Hijri + Gregorian) dates agree with a reference | ☐ |
| **Notification bells actually fire** on time while the app is backgrounded and after a reboot (receiver statics + boot restore — the W3b fix) | ☐ |
| With "exact alarms" denied by the system → the app still schedules (inexact fallback) and says so | ☐ |
| Amal today: tap amals, undo; streak/percentages update | ☐ |
| Amal history heatmap month grid renders for a demo account with seeded history | ☐ |

## 4. Qur'an & Ilm

|  | ✔ |
|---|---|
| Reader opens any surah; Arabic renders RTL and legibly; dark theme too | ☐ |
| Recitation: tap play per-ayah — audio streams (needs network), auto-advance, offline after cache | ☐ |
| Ilm search: type a Bengali word (e.g. রহম) — grouped results; offline strip appears in airplane mode | ☐ |

## 5. Tools (More tab)

|  | ✔ |
|---|---|
| Qibla compass needle points to Makkah from your location; magnetic-vs-true note shown | ☐ |
| Mosques near me — the bundled 24-Dhaka list with distance/bearing | ☐ |
| Zakat calculator computes; মাসআলা opens | ☐ |
| Auto-silent: requests DND permission on Android, applies during prayer window | ☐ |
| **Detox screen (Android)**: usage-access explainer → grant → today's report + top apps appear (no data = access not granted); daily reminder schedules | ☐ |
| Foundation section: five contacts with tel/website actions; Donate card opens the configured URL | ☐ |

## 6. Home screen widget (Android)

|  | ✔ |
|---|---|
| Add the widget — next-prayer name + countdown render | ☐ |
| Kills: force-stop the app → widget still shows (persisted snapshot) | ☐ |
| Reboot the phone → widget restores within ~15 min | ☐ |

## 7. Dawah & sharing

|  | ✔ |
|---|---|
| Madu tree renders the seeded downline with level chips | ☐ |
| Share the referral card → the branded 1080×1350 PNG goes out via WhatsApp/etc. (not a text-only share) | ☐ |
| `https://sunnahlife.app/join/<code>` opens the chooser with the app (debug-signed: chooser is expected; direct open needs the release key) — the landing page opens in a browser otherwise | ☐ |
| Assessment confirm: pending assessment → OTP confirm flow (debug build) → status chip turns নিশ্চিত | ☐ |

## 8. Notifications & push (end-to-end)

|  | ✔ |
|---|---|
| Bell + post-prayer prompt notifications arrive on device (not only in-app) | ☐ |
| **Push** (needs docs/HUMAN_STEPS.md §1 done): broadcast from an usrah-head/admin → phone shows নতুন ঘোষণা → tap deep-links to the screen | ☐ |
| **Real SMS** (needs docs/HUMAN_STEPS.md §2 done): real phone number sign-in, code arrives by SMS on the release build | ☐ |

## 9. Resilience & UI stress

|  | ✔ |
|---|---|
| Airplane mode: home/amal work; dawah/ilm show the cached-state banners (no dead spinners) | ☐ |
| Bengali + English languages both render (settings toggle) | ☐ |
| System font scale at ~1.3× — no clipped labels anywhere (esp. the stats row, prayer rows) | ☐ |
| Dark ↔ light toggle across all five tabs + settings | ☐ |
| Back navigation never dead-ends; double-back to exit works | ☐ |

---

## Reporting failures

Note the screen, the exact Bengali text involved, light/dark, device model +
Android version, and the artifact name — the owner's earlier visual findings
(#1 tofu, #2..#4) each became a one-commit fix; that is the expected
granularity. A failing item here = a "Ready for device" AUDIT row stays open.

*Build/version this checklist was written against: main @ the W5 fixes
(c906d9b day-parts, 8a4a657 FAB clearance, 8a9e1bf stat-cell wrap, 25ed835
component-theme text colors, ee7c5fb real-font goldens), pubspec
`1.0.0+1`, artifact `internal-test-arm64-v8a`.*
