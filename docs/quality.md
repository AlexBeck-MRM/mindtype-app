<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  Q U A L I T Y   &   A C C E P T A N C E  ░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Canonical view of gates, acceptance criteria, and tests.   ║
  ║   Maps requirements to code, tests, and manual sign‑off.     ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Living QA plan covering acceptance + verification
    • WHY  ▸ Keep every spec traceable to code/tests/mac QA
    • HOW  ▸ Link criteria → modules → Vitest/Playwright/manual
-->

# Mind⠶Flow Quality & Acceptance Guide

This document is the single place to confirm that requirements match the current code. Every criterion lists the modules that implement it, the automated tests that prove it, and any manual QA notes that must stay in sync with the codebase.

## Quality Gates & Commands

- Type safety: `pnpm typecheck`
- Linting: `pnpm lint`
- Formatting audit: `pnpm format:check`
- Unit + integration coverage: `pnpm test`
- Documentation traceability: `pnpm doc:check`
- Playwright end-to-end sweep: `pnpm -r --filter e2e test`
- Rust parity (optional but recommended): `cargo test -p core-rs`

All gates must pass locally before sharing work. When a gate fails, fix the implementation or extend the tests—never delete or comment them out.

## Acceptance Criteria (AC)

Each acceptance criterion is referenced by specs (e.g., `REQ-CARET-SAFETY`). Anchors below are used by `doc2code`.

<a id="AC-CARET-SAFE"></a>
### AC-CARET-SAFE — Never touch the caret

- Modules: `src/region/policy.ts`, `src/safety/grapheme.ts`, `src/safety/caretMonitor.ts`, `src/ui/swapRenderer.ts`
- Tests: `tests/activeRegion.spec.ts`, `tests/grapheme.spec.ts`, `tests/diff.spec.ts`, `tests/diffusionController_policy_guard.spec.ts`
- Playwright: `e2e/tests/caret-status.spec.ts`, `e2e/tests/undo-isolation.spec.ts`
- Notes: Corrections must abort if the caret re-enters the active region. Secure/IME spans automatically block edits.

<a id="AC-ACTIVE-AREA"></a>
### AC-ACTIVE-AREA — Stay inside the active bubble

- Modules: `src/region/policy.ts`, `src/region/diffusion.ts`
- Tests: `tests/activeRegionPolicy_v06.spec.ts`, `tests/diffusionController.spec.ts`, `tests/diffusionController_band.spec.ts`
- Notes: The render range follows ~20 trailing words, while the context range can stretch farther for LM prompts but never overlaps secure zones.

<a id="AC-CONFIDENCE-GATE"></a>
### AC-CONFIDENCE-GATE — Only commit when confident

- Modules: `src/pipeline/confidenceGate.ts`, `src/stages/context.ts`, `src/stages/tone.ts`
- Tests: `tests/confidenceGate.spec.ts`, `tests/confidenceGate_branches.spec.ts`, `tests/contextTransformer_gating.spec.ts`, `tests/toneTransformer.spec.ts`
- Notes: Stages emit `Pending`, `Hold`, or `Commit`. Low-confidence proposals are dropped without surfacing partial text.

<a id="AC-DETERMINISTIC-FIRST"></a>
### AC-DETERMINISTIC-FIRST — Noise keeps running under load

- Modules: `src/stages/noise.ts`, `src/pipeline/scheduler.ts`, `src/pipeline/logger.ts`
- Tests: `tests/sweepScheduler_tiers.spec.ts`, `tests/sweepScheduler_dynamicThresholds.spec.ts`, `tests/noiseTransformer*.spec.ts`
- Notes: When LM tiers degrade (e.g., CPU fallback) we still run deterministic typo fixes and record the tier in the wave log.

<a id="AC-UNDO-ATOMIC"></a>
### AC-UNDO-ATOMIC — One undo per wave

- Modules: `src/ui/rollback.ts`, `src/pipeline/correctionWave.ts`, `src/region/diffusion.ts`
- Tests: `tests/rollbackHandler.spec.ts`, `tests/waveHistory.spec.ts`
- Playwright: `e2e/tests/undo-isolation.spec.ts`
- Notes: Cmd+Alt+Z (or Option on macOS) reverts the last wave only; host undo stacks stay untouched.

<a id="AC-PRIVACY-ON-DEVICE"></a>
### AC-PRIVACY-ON-DEVICE — On-device by default, guard secure fields

- Modules: `src/safety/security.ts`, `src/safety/caretMonitor.ts`, `src/lm/factory.ts`
- Tests: `tests/secureFields.spec.ts`, `tests/secureFields_web.spec.ts`, `tests/security_default.spec.ts`
- Notes: Text never leaves the device unless the user explicitly opts in. Secure inputs and IME composition spans halt the pipeline instantly.

<a id="AC-ACCESSIBILITY"></a>
### AC-ACCESSIBILITY — Reduced motion + batched announcements

- Modules: `src/ui/motion.ts`, `src/ui/liveRegion.ts`, `src/ui/highlighter.ts`
- Tests: `tests/motion.spec.ts`, `tests/liveRegion.spec.ts`, `e2e/tests/a11y-announcements.spec.ts`
- Notes: Respect `prefers-reduced-motion` by swapping shimmer animations for static fades, and issue exactly one polite ARIA announcement per batch.

<a id="AC-PAUSE-TRIGGER"></a>
### AC-PAUSE-TRIGGER — Burst → pause → sweep timing

- Modules: `src/pipeline/monitor.ts`, `src/pipeline/scheduler.ts`, `src/pipeline/correctionWave.ts`
- Tests: `tests/typingMonitor.spec.ts`, `tests/sweepScheduler_pause.spec.ts`, `tests/sweepScheduler_cadence.spec.ts`
- Notes: Short pauses (~300 ms) schedule catch-up noise; 500 ms+ pauses trigger full waves that stop precisely at the caret.

<a id="AC-FALLBACKS"></a>
### AC-FALLBACKS — Graceful degradation

- Modules: `src/lm/deviceTiers.ts`, `src/lm/resilientAdapter.ts`, `src/pipeline/scheduler.ts`
- Tests: `tests/transformersRunner_fallback.spec.ts`, `tests/lmAdapter.spec.ts`, `tests/sweepScheduler_tiers.spec.ts`
- Notes: Hardware tier detection adjusts token budgets and debounce windows. If LM assets are missing, the UI surfaces an “LM offline” badge and halts waves safely.

## macOS Acceptance Anchors

The macOS menu-bar host shares the same engine but has extra platform acceptance duties. Each anchor mirrors the old `.feature` files.

<a id="HIG-001"></a>
### HIG-001 — Menu bar labeling

Menu bar extra exposes the ⠶ icon with an accessible name and tooltip. Covered by `hosts/macos/MindFlowApp.swift` and manual QA (see below).

<a id="HIG-002"></a>
### HIG-002 — Panel visuals

Preferences/test panels use `.ultraThinMaterial`, respect high-contrast mode, and never exceed 320 pt width. Verified via manual QA.

<a id="HIG-003"></a>
### HIG-003 — Keyboard navigation

Every button, toggle, and slider is focusable via keyboard. VoiceOver order mirrors the visual layout.

<a id="AX-TRUST"></a>
### AX-TRUST — Accessibility trust flow

`AXIsProcessTrustedWithOptions` prompts with rationale and deep link. Logs appear in the mac console on success/failure.

<a id="AX-SECURE"></a>
### AX-SECURE — Secure-field and IME guards

The mac host reuses `SecurityMonitor.swift` to skip secure fields and IME composition. Manual QA verifies the badge indicates “paused for secure field.”

<a id="AX-ANNOUNCE"></a>
### AX-ANNOUNCE — Single announcement per batch

VoiceOver receives one polite announcement (“Mind⠶Flow updated text behind the cursor”) for each committed wave. Duplicates are treated as bugs.

<a id="PERF-LATENCY"></a>
### PERF-LATENCY — 15 ms budget

Activity Monitor + Instruments runs confirm ≤15 ms p95 on M-series chips. Capture logs from `hosts/macos/DiagnosticsOverlay.swift`.

<a id="PERF-IDLE"></a>
### PERF-IDLE — Stay near idle when listening

Idle CPU <2 % and steady RAM <300 MB when the user is only typing. Diagnostics recorded in QA notes.

## Test Coverage Map

- **TypeScript unit + integration**: `tests/**/*.spec.ts` (Vitest). Focus areas include active region (`activeRegion*.spec.ts`), scheduler (`sweepScheduler*.spec.ts`), LM adapters (`lmAdapter*.spec.ts`), UI feedback (`marker.ts`, `motion.ts`, `liveRegion.ts`), and safety (`secureFields*.spec.ts`).
- **Rust**: `cargo test -p core-rs` covers `active_region.rs`, `diff.rs`, `workers/*`, and FFI validation.
- **Playwright**: `e2e/tests/*.spec.ts` validates user journeys—typing flow, reduced-motion, language gating, tone controls, rollback, IME safety, and LM responsiveness. Run via `pnpm -r --filter e2e test`.
- **macOS manual QA**: checklist lives alongside this file; log findings in PRs and attach Instruments captures for performance anchors.

## Manual QA Workflow

1. **Web demo** (hosts/web): `pnpm --filter hosts/web dev`, then run the on-screen diagnostics panel. Verify controls (active region size, tone, device tier) update live and persist.
2. **Reduced motion**: Toggle system setting and confirm the marker swaps to static fades; Playwright `a11y-announcements` covers this but still perform a visual spot check.
3. **Rollback hotkey**: In both web and mac hosts, press Cmd+Alt+Z immediately after a wave; ensure only the last sweep is reverted.
4. **Mac menu bar**: Build via `just build-macos` or open the Xcode project. Confirm trust prompts, secure-field guards, and VoiceOver announcements.
5. **LM asset health**: Run `pnpm setup:local` before demos. If assets are missing, the UI badge should turn red and waves stop—file an issue if silent failures occur.

Document new findings directly in this file (or link to an attached QA note) so the acceptance map always matches the real system.

<!-- DOC META: VERSION=1.0 | UPDATED=2025-11-20T00:00:00Z -->

