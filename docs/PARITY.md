# Splice Stack — PARITY (capability matrix, evidence-based)
Updated 2026-10-25. Scores come only from the test/sim evidence listed.

| Capability (spec Game 2 + Roadmap P2) | Web MVP | Godot MVP | Evidence |
|---|---|---|---|
| Core loop: slide, drop, slice overhang | ✅ | ✅ | Web sim perfect-play Floor 36; Godot harness Floor 30 |
| PERFECT streak + width restore every 5th | ✅ | ✅ | Both harnesses end at full width 220 / 376 |
| CLOSE near-miss bonus (≤14px web / ≤24px Godot) | ✅ | ✅ | Code + popup; counted in stats (closes) |
| Falling-slice knock-loose physics | ✅ | ✅ | Web geometry test knocked=1, stack 2→1; Godot harness knocked=1, stack 2→1 |
| Endless mode + per-mode best score | ✅ | ✅ | localStorage / user:// files |
| Daily Tower — date-seeded spawn pattern | ✅ | ✅ | Both harnesses: two fresh daily runs give identical dir/jitter sequences |
| Daily floor record + streak calendar | ✅ (history + 🔥 streak in header) | Partial (records best floor per date to user://splice_daily.txt; no calendar UI) | Web sim: floor-0 day now counts (falsy-0 bug found & fixed) |
| Share card | ✅ (PNG card, Web Share API w/ download fallback) | ❌ Not built | Web code path only; not exercised headlessly — **Unverified in a real browser share sheet** |
| Settings (sound, haptics, colorblind palette, reduced flash, erase data) | ✅ | ❌ Not built (keys 1/2 switch modes instead) | Web sim: settings defaults + persistence exercised |
| Colorblind palette + floor numbers | ✅ | ❌ | Web only |
| Pause on tab hidden | ✅ | n/a | Web visibilitychange handler |
| Sounds / haptics feel | ✅ (WebAudio synth + vibrate) | Partial (vibrate calls only, no audio) | Unverified on a real device |
| APK build | n/a | ✅ (CI) | GitHub Actions (public repo SeanShaffer88/SpliceStack) run #5 SUCCESS 2026-10-25: harness step passed in CI, export-debug APK produced + verified after download — 24,145,351 B, SHA-256 b626cc3d…, contains classes.dex, AndroidManifest.xml, lib/arm64-v8a/libgodot_android.so, debug signature (META-INF/ANDROIDD.RSA). Debug-signed sideload build (Godot default SDK levels: min 24 / target 34). On-device install/runtime still **Unverified** — SEAN's phone is the verdict. CI fixes that got it green: editor settings need a Java SDK path; SDK overrides must stay empty without Gradle build; platform 34 + build-tools 34 installed via sdkmanager; project must enable `textures/vram_compression/import_etc2_astc` (Godot reports that one as a blank configuration error) |

## P1 Feel Pass (2026-10-25, SEAN-directed) — tuning resolved from bot evidence
- **Streak scoring capped:** PERFECT = 10 + 25×min(streak, 6) in both builds (was 10 + 50×streak unbounded). Evidence: flawless 30-floor score fell from 23,550 → **4,425** (Godot harness) and web perfect runs now score in the low thousands instead of 33k. Scores are now comparable between good and great runs.
- **Knock-loose measured first:** the MVP note below was wrong for zigzag play — a zigzag bot (alternating ±30% offsets) took **112 knocks in 682 drops (~1 in 6)** on the pre-P1 build, while flush/monotonic towers take ~0 (by geometry, correct). So P1 did NOT raise raw frequency; it added a **damage gradient**:
  - Solid hit (overlap >18px web / >30px Godot) = knock loose, as before.
  - Graze (overlap 5–18px web / 8–30px Godot) = **CHIP**: the block narrows by the overlap instead of falling; chipped below ~30px (52 Godot) it crumbles out. "CHIPPED!" popup + stat on game over.
  - Slices tumble slightly inward (14px/s web / 24px/s Godot) and the catch window widened (0.5 level) so fast slices can't skip a ledge between frames.
  - Post-P1 zigzag measurement (3 runs, high variance): ~93–119 knocks **and ~94 chips** per 600–780 drops — contact is more common, catastrophic loss per contact is down, average survival floor rose in 2 of 3 runs (27.8 → 32.0/32.5, third run 25.3).
- Godot CHIP path: implemented identically, exercised only via code path review + web aggregate evidence — **Partially Verified** for Godot specifically.
- Web/Godot thresholds are scale-matched (420-wide vs 720-wide logical) but not pixel-identical games; scores are not comparable across builds.
