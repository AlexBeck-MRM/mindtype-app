<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D ⠶ F L O W   1 0 - M I N   G U I D E  ░░░░░░░░░░  ║
  ║                                                              ║
  ║   Fast, precise onboarding for curious builders.             ║
  ║   Serious substance, lightly fun delivery.                   ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ A ten-minute learning path for Mind⠶Flow
    • WHY  ▸ Give newcomers a mental model before they touch code
    • HOW  ▸ Minute-by-minute tour + concrete next actions
-->

# Mind⠶Flow Learning Guide (10-Min Tour)

Welcome! Set a timer for ten minutes and follow the checkpoints below. Each segment stacks context so that by the end you can explain what Mind⠶Flow does, where the logic lives, and how to extend it without breaking trust.

## Minute 0–2 — Purpose + People

Mind⠶Flow turns noisy keystreams into crystal text without stealing momentum. The **Correction Marker** (the animated braille worker) waits while you sprint, then sweeps the text behind your caret during natural pauses. Everything is tuned to the seven reference scenarios from `docs/01-prd/01-PRD.md`: academic focus, multilingual polish, accessibility peace, creative cadence, professional tone, speed demons, and data whisperers. Each scenario pairs with a principle in `docs/03-system-principles/03-System-Principles.md`, so when you tweak behavior you can immediately see which human story you’re serving.

> ✱ Quick vibe-check: This is cognitive augmentation, not autocorrect. If a change risks flow, tone ownership, privacy, or caret safety, it’s out.

## Minute 2–4 — Core Mental Model

Think “**Burst → Pause → Correct**.” While you type, `src/pipeline/monitor.ts` logs keystrokes and caret drift. Once a ~500 ms pause hits, `src/pipeline/scheduler.ts` launches a **Correction Wave** that runs three deterministic + LM stages (`src/stages/noise.ts`, `context.ts`, `tone.ts`). The wave only touches the **Active Region** (≈20 trailing words) enforced by `src/region/policy.ts` and `diffusion.ts`, and every diff must satisfy the caret-safe contract in `docs/contracts.md#contract-active-region`. The Correction Marker mirrors the wave’s status via `src/ui/marker.ts` and swaps modes without crossing the caret. Rollback stays atomic thanks to `src/ui/rollback.ts`.

## Minute 4–5 — Architecture Stack Tour

Four layers keep the system honest:

| Layer | What it owns | Key paths |
| --- | --- | --- |
| Experience | Marker visuals, tone controls, rollback hotkey, reduced-motion UX | `hosts/web/src/App.tsx`, `hosts/macos/*.swift`, `src/ui/*`, `docs/quality.md#AC-ACCESSIBILITY` |
| Pipeline | Typing monitor, pause scheduler, confidence gates, wave orchestration | `src/pipeline/*.ts`, `src/stages/*.ts`, `src/config/thresholds.ts` |
| Intelligence | LM adapters, device-tier fallbacks, stream protocol | `src/lm/*.ts`, `mindtype/models/*`, `docs/contracts.md#contract-lm-stream` |
| Engine | Rust primitives shared by WASM + macOS FFI (fragment extractor, diff, logger) | `core-rs/src/*.rs`, `bindings/wasm`, `hosts/macos/RustBridge.swift` |

All hosts reuse the same contracts and acceptances. If you add a feature, update the relevant contract spec first (`docs/contracts.md`) and note the impact in `docs/02-implementation/02-Implementation.md`.

## Minute 5–6 — Diff vs Diffusion (why two files?)

**Diffs (`src/safety/diff.ts`, `src/ui/swapRenderer.ts`, `core-rs/src/diff.rs`)**

- A *diff* is the smallest caret-safe edit we apply: `{ start, end, replacement }` within the active region and strictly before the caret.
- `replaceRange()` double-checks grapheme boundaries and rejects edits that would split emojis, ligatures, or RTL pairs.
- Rust mirrors the same logic so WASM + macOS FFI hosts share behavior; both sides serialize through the `MTString` contract.
- When a diff is approved, `swapRenderer.ts` animates the swap and hands the new buffer back to the host editor.

**Diffusion controller (`src/region/diffusion.ts`)**

- Treats LM output like a paint roller: it diffuses committed text across the active region word by word, never leaping over untouched spans.
- Merges multiple stage feeds (noise/context/tone) into a single queue, throttles them to match marker progress, and cancels anything invalidated by new typing.
- Talks constantly with `scheduler.ts` and `policy.ts`: if the caret re-enters the bubble or a secure/IME guard trips, diffusion purges pending diffs before they reach the renderer.

**Together**

- Think of diffs as *what* to change and diffusion as *how/when* to apply the backlog without breaking flow.
- This separation keeps the math for caret safety and the choreography for visual pacing independent, which is why the files live in different folders but reference the same contracts.

## Minute 6–7 — Data Flow Walkthrough

1. **Capture** — A host (web textarea, macOS AX watcher) forwards text + caret snapshots into `monitor.ts`.
2. **Shape** — `policy.ts` slices the active region and attaches safety metadata (secure field, IME, tone).
3. **Wave prep** — `scheduler.ts` checks pause timers (`core-rs/src/pause_timer.rs`) and device tier, then creates a correction wave ticket.
4. **Stage run** — Noise fixes deterministic slips; Context streams LM suggestions through the JSONL protocol; Tone optionally adjusts register. Confidence gates decide whether to commit.
5. **Apply** — `diffusion.ts` sequences the backlog, hands each diff to `safety/diff.ts` for last-mile validation, then `swapRenderer.ts` animates the swap while `liveRegion.ts` issues a single polite announcement.
6. **History** — `rollback.ts` snapshots the wave, enabling Cmd+Alt+Z (“Mind⠶Flow undo”) without touching the host undo stack.

## Minute 7–8 — Build & Quality Rituals

Mind⠶Flow ships only when every gate in `docs/quality.md` is green. The usual local cadence:

```bash
pnpm install             # once per clone
pnpm typecheck && pnpm lint && pnpm format:check
pnpm test                # Vitest unit+integration
pnpm -r --filter e2e test   # Playwright (optional but expected before demos)
cargo test -p core-rs    # Rust parity (fast)
```

Keep docs in sync via `pnpm doc:check`. When you grab a task from `docs/02-implementation/02-Implementation.md`, mention the acceptance anchors you’re touching and confirm corresponding tests exist (or add them). No gate? No merge.

## Minute 8–9 — UX, Safety, Privacy Anchors

Three non-negotiables define product quality:

- **Caret Safety (AC-CARET-SAFE)** — Never edit at/after the caret; bail instantly if a user re-enters the active region or trips secure-field/IME detection (`src/safety/security.ts`).
- **On-Device Trust (AC-PRIVACY-ON-DEVICE)** — LM assets live under `mindtype/`. The UI must surface an “LM offline” badge if initialization fails (see `src/lm/adapter_v06.ts` and `docs/quality.md#AC-FALLBACKS`).
- **Accessibility Fidelity (AC-ACCESSIBILITY, AX anchors)** — Respect `prefers-reduced-motion`, announce one polite update per wave, and keep the macOS Overlay within HIG spec (`docs/quality.md#HIG-001` et al.).

If you implement visual controls (e.g., the customizable panel in the web demo), align with the gestalt note in the user rules: floating to the right, 5 vh margin, collapsible, resumable via click or key.

## Minute 9–10 — Hands-On + Next Reads

You're ready to drive:

1. **Web playground** — `just build-web` or follow `README.md#web-demo-build-and-run`, tweak active-region sliders, and watch the marker respond in real time.
2. **System monitor** — `cd monitor && pnpm dev` loads the live architecture map so you can trace events visually.
3. **macOS host** — Run `just build-macos` or the XcodeGen flow in `docs/02-implementation/02-Implementation.md`, then verify AX permissions + rollback.
4. **Deep dives** — Keep this guide open and branch off into:
   - `docs/04-architecture/architecture.mmd` for the canonical diagram
   - `docs/05-adr/*.md` to understand why major decisions were locked
   - `docs/contracts.md` whenever you change a boundary

> 🎯 Rule of thumb: if you can narrate “monitor → scheduler → wave → marker” without pausing, you’re oriented. If not, re-run the relevant minute segment above.

---

_This guide ages with the product—update it whenever new scenarios, hosts, or gates land so future readers keep their ten-minute promise._

<!-- DOC META: VERSION=1.1 | UPDATED=2025-11-21T12:00:00Z -->

