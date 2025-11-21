<!--
╔═══════════════════════════════════════════════════════════════════╗
║  ░  M I N D T Y P E R  ░  C Y B E R - P U N K   T Y P I N G  ░░░  ║
║                                                                   ║
║   Mental helper and project guide for navigating the codebase.    ║
║   Communicates with `.cursor/rules/workflow.mdc` and docs/*.md.   ║
║                                                                   ║
║           ╌╌  P L A C E H O L D E R  ╌╌                           ║
║                                                                   ║
║                                                                   ║
║                                                                   ║
║                                                                   ║
╚═══════════════════════════════════════════════════════════════════╝
  • WHAT ▸ High-signal README: structure, files, flows, commands
  • WHY  ▸ Faster onboarding and assisted coding in Cursor
  • HOW  ▸ Explains every folder/file; links to tasks and rules
-->

![build](https://img.shields.io/badge/build-passing-brightgreen)
![license](https://img.shields.io/badge/license-MIT-green)
![version](https://img.shields.io/badge/version-0.8.0-purple)
![monitor](https://img.shields.io/badge/monitor-live-cyan)

### TL;DR

- Typing engines propose caret-safe diffs in real time via three-stage pipeline (Noise → Context → Tone). An active region (~20 words, 2–3 sentences) trails the caret and "draws in" corrections during natural pauses.
- A small TypeScript core wires input monitoring and scheduling. A Rust crate powers WASM-ready primitives. Local LM target: Transformers.js + Qwen2.5‑0.5B‑Instruct (q4, WebGPU/WASM/CPU) with **LM-only corrections** (no rule fallback).
- Quality gates: pnpm typecheck, lint, format:check, test. Tasks live in `docs/02-implementation/02-Implementation.md`.

### Demo • _add GIF here_

### Table of Contents

- Overview
- Quick Start
- Development Workflow & Quality Gates
- Project Structure (tree)
- Directory and File Guide (every source file)
- Deep Directory Guide (purpose, responsibilities, when to change, contracts)
- Contracts (what this means)
- Cross-Module Data Flow
- Task Board & Docs
- What's New
- License

### Recommended reading

- Product narrative: `docs/mindtyper_manifesto.md`
- Architecture diagram: `docs/04-architecture/architecture.mmd`
- Product requirements: `docs/01-prd/01-PRD.md` + `docs/00-index/pdf-guide-requirements.md`
- Contracts & QA: `docs/contracts.md` and `docs/quality.md`
- Changelog: `CHANGELOG.md`

## Overview

Mind::Type turns noisy keystreams into clean text via small, reversible diffs. Forward passes keep typing tidy; reverse passes backfill consistency using accumulating context. All edits respect the CARET and are designed to be grouped into coherent undo steps.

### Beginner primer: key terms

- **Rust crate**: A Rust library/package. Our core logic is in `crates/core-rs`.
- **TypeScript (TS) core**: Lightweight glue in `src/pipeline`, `src/stages`, `src/region`, and `src/ui` that orchestrates typing events and corrections.
- **Tests**: Small programs that verify behavior. TS tests live in `tests/**`; Rust tests live next to Rust files.
- **WASM (WebAssembly)**: Lets Rust run in the browser. We compile Rust to a `.wasm` file and import it from TS.
- **wasm-bindgen**: Rust tooling that makes Rust functions callable from JS/TS.
- **Local dependency**: The web demo imports the locally built WASM package from a folder on disk (no publishing needed).
- **Fragment extractor**: Finds the last finished sentence near the end of your text so we only correct complete thoughts.
- **Merger**: Combines incoming tokens into text. Today it appends words; later it will apply precise diffs.
- **Stub token stream**: A fake “stream of words” used to test our pipeline without a real network.
- **In-memory logger**: Collects logs in Rust and exposes them to the web demo.

## Quick Start

1. Install toolchain
   - Node (pnpm), Rust, wasm-pack (for WASM builds), Playwright optional for e2e
2. Install deps: `pnpm install`
3. Run unit tests: `pnpm test`
4. Run quality gates: `pnpm typecheck && pnpm lint && pnpm format:check && pnpm test`
5. Explore tasks: open `docs/02-implementation/02-Implementation.md`

### Web demo: build and run

1. Install tools (once): Rust toolchain, `wasm-pack`, Node, pnpm
2. From repo root, build the WASM package and the demo:
   - With `just`: `just build-web`
   - Or manually:
     - `wasm-pack build core-rs --target web --out-dir bindings/wasm/pkg`
     - `pnpm --prefix hosts/web install`
3. Run: `pnpm --prefix hosts/web dev` → open the printed URL
4. Type a sentence and watch the active region trail behind your cursor; pause to see diffusion catch up.

### Monitor visualization

View the live pipeline architecture:

```bash
cd monitor && pnpm dev
```

Open http://localhost:3001 to see the interactive system map.

## Development Workflow & Quality Gates

- Follow `.cursor/rules/workflow.mdc` when planning and executing tasks.
- Scripts
  - `pnpm typecheck`: strict TS compile (no emit)
  - `pnpm lint`: ESLint (flat config) for TS
  - `pnpm format`: Prettier write
  - `pnpm format:check`: Prettier check
  - `pnpm test`: Vitest unit tests (scoped to `tests/**`)
- Optional: `just test-all` for broader matrix including Rust/e2e, if you use `just`.

## Project Structure (v0.8+)

```text
mindtype/
  src/                       # TypeScript pipeline (v0.8 reorganization)
    pipeline/                # Orchestration (scheduler, monitor, correctionWave)
    stages/                  # Three-stage transformers (Noise → Context → Tone)
    region/                  # Active Region policy + diffusion controller
    lm/                      # Language model adapters (Transformers.js, workers)
    safety/                  # Caret-safe diff, grapheme handling, security
    ui/                      # Visual feedback (marker, highlighter, rollback)
    config/                  # Thresholds & configuration
  core-rs/                   # Rust cognitive engine (WASM + FFI)
  hosts/                     # Platform implementations
    web/                     # Web demo (Vite + React)
    macos/                   # macOS menu bar app (SwiftUI + AX)
  monitor/                   # NEW: Interactive pipeline visualization
  mindtype/                  # Local LM + WASM assets
  docs/                      # Architecture, guides, ADRs, QA
  tests/                     # Unit tests (Vitest)
  e2e/                       # End-to-end tests (Playwright)
  scripts/                   # Build automation
  bindings/                  # C/Swift FFI headers, WASM pkg
```

## Directory and File Guide (v0.8)

### src/ — TypeScript Pipeline

#### src/pipeline/

- `index.ts`: Main entry point — `boot()` function, LM adapter injection
- `monitor.ts`: Typing event capture and emission (`TypingMonitor`)
- `scheduler.ts`: Orchestrates pause detection, streaming ticks, correction waves
- `correctionWave.ts`: Executes three-stage pipeline (Noise → Context → Tone)
- `confidenceGate.ts`: Quality gating for proposals (τ_input, τ_commit, τ_tone)
- `logger.ts`: Namespaced logging with pluggable sinks

#### src/stages/

- `noise.ts`: Stage 1 — Deterministic + LM typo fixes within Active Region
- `context.ts`: Stage 2 — LM-powered grammar/coherence, confidence-gated
- `tone.ts`: Stage 3 — Optional tone adjustment (None/Casual/Professional)

#### src/region/

- `policy.ts`: Computes Active Region boundaries (~20 words behind caret)
- `diffusion.ts`: Manages validation frontier, word-by-word streaming, catch-up

#### src/lm/

- `adapter_v06.ts`: Primary LM adapter (Qwen2.5-0.5B q4, device-tier aware)
- `factory.ts`: `createDefaultLMAdapter()` with platform defaults
- `transformersClient.ts`: Transformers.js integration
- `workerAdapter.ts`: Web Worker wrapper for off-main-thread processing

#### src/safety/

- `diff.ts`: Caret-safe `replaceRange()` — never modifies at/after cursor
- `grapheme.ts`: Unicode-aware boundary alignment
- `security.ts`: Secure field + IME composition detection
- `caretMonitor.ts`: Caret position tracking and change detection

#### src/ui/

- `marker.ts`: Correction Marker renderer (braille animation, listening/correction modes)
- `highlighter.ts`: Active Region visual feedback
- `rollback.ts`: Atomic wave undo handler (Cmd+Alt+Z)
- `swapRenderer.ts`: Diff application with visual feedback
- `liveRegion.ts`: Screen reader announcements (accessibility)

#### src/config/

- `thresholds.ts`: Central parameters (pause timing, Active Region size, confidence thresholds)

### core-rs/ — Rust Engine

Rust implementation of core algorithms with FFI/WASM bindings:

- `src/lib.rs`: Public API + WASM exports
- `src/ffi.rs`: C ABI for Swift/macOS integration
- `src/fragment.rs`: Sentence extraction
- `src/logger.rs`: In-memory logging

### hosts/ — Platform Hosts

#### hosts/web/

React + Vite demo with live controls for testing the pipeline:

- `src/App.tsx`: Main playground interface with autopilot + diagnostics
- `src/App_v06.tsx`: LM-only demo with Correction Wave visualization
- `vite.config.ts`: Build configuration

#### hosts/macos/

SwiftUI menu bar app with system-wide Accessibility integration:

- `MindFlowApp.swift`: Main app entry point
- `RustBridge.swift`: FFI bridge to Rust core
- `Template/project.yml`: XcodeGen project definition

### monitor/ — Pipeline Visualization

Interactive web app showing live system architecture:

- `src/SystemMap.tsx`: Node graph visualization
- `public/system-map.json`: Canonical pipeline definition
- Retro 16-bit aesthetic with drill-down detail panels
- Run with: `cd monitor && pnpm dev` → http://localhost:3001

### tests/

- `tests/noiseTransformer.spec.ts`: Verifies noise transformer returns no crossing-caret edits.
- `tests/contextTransformer*.spec.ts`: Tests context stage gating and LM integration.
- `tests/diff.spec.ts`: Validates `replaceRange` correctness and caret guardrails.

### docs/

- `docs/00-index/00-README.md`: Master index + onboarding breadcrumbs
- `docs/01-prd/01-PRD.md`: Product requirements + seven scenarios
- `docs/02-implementation/02-Implementation.md`: Phase plan and task board
- `docs/03-system-principles/03-System-Principles.md`: Safety, privacy, and design tenets
- `docs/04-architecture/README.md` + `architecture.mmd`: Canonical architecture walkthrough
- `docs/05-adr/*.md`: Architectural decisions (caret safety, Rust-first, FFI JSON, etc.)
- `docs/00-index/pdf-guide-requirements.md`: PDF-aligned requirement extract
- `docs/contracts.md`: Active region, LM adapter, and LM stream contracts
- `docs/quality.md`: Acceptance criteria, macOS HIG/AX/Perf anchors, and QA flow

### crates/core-rs/ (Rust)

- `src/lib.rs`: WASM bindings and exported types; exposes logger, timer, fragment extractor, merger, and token stream stubs.
- `src/fragment.rs`: Extracts the last complete sentence using Unicode segmentation.
- `src/merge.rs`: Simple token-appending merger (placeholder for diff-based merge).
- `src/pause_timer.rs`: Idle detection utility; used to decide when to schedule sweeps.
- `src/logger.rs`: In-memory logger; serializable to JS via WASM.
- `src/llm.rs`: Token stream trait + stub tokenizer; placeholders for OpenAI/CoreML streams.
- Cargo files: crate metadata/lock; `target/` contains build artifacts.

### playground/

- `playground/` is a Vite + React demo shell. Key files:
  - `src/App.tsx`, `src/App_v06.tsx`: Demo UI components.
  - `src/worker/lmWorker.ts`: LM worker integration with Transformers.js.
  - `vite.config.ts`, `vitest.config.ts`: Build/test configs.
  - Note: Demo is deprecated in favor of macOS app; see `demo/README.md`.

### web-lab-v0.6/

- `web-lab-v0.6/`: Standalone testing app with comprehensive pipeline logging and visualization.
  - `src/PipelineLogger.ts`: Captures every pipeline event for debugging.
  - `src/PipelineVisualizer.ts`: Real-time visualization of stage status, Active Region, confidence scores.

### e2e/

- `playwright.config.ts`: E2E runner config.
- `tests/*.spec.ts`: Example tests (demo placeholders).
- `package.json`: Separate package marker for E2E scope.

### .cursor/rules/

- `workflow.mdc`: Cursor execution rules (PLAN_ONLY/EXECUTE/LIB_TOUCH, gates, commit style).
- `generate.mdc`: Structure/naming/documentation conventions for generated code.
- `glossary.mdc`: Quick terms reference.
- `comment_style.mdc`: Boxed comment style (WHAT/WHY/HOW) used across the repo.

### Root files

- `eslint.config.js`: ESLint v9 flat config for TypeScript with Prettier harmony.
- `vitest.config.ts`: Unit test scope limited to `tests/**`; excludes e2e and web-demo.
- `tsconfig.json`: ES2024 target, Node types, excludes `e2e/**` and `web-demo/**` for core typecheck.
- `package.json`: Scripts (typecheck, lint, format, test) and dev deps.
- `Justfile`: Recipes for bootstrap, web build (WASM + Vite), mac build (Rust/Xcode), and test-all.
- `specs.md`: Product and technical specification notes.
- `Cargo.toml`, `Cargo.lock`: Rust workspace metadata.
- `pnpm-lock.yaml`: Node dependency lockfile.

## Cross-Module Data Flow (high level)

- Host editor → `src/pipeline/monitor.ts` (keystrokes, caret, timestamps)
- `src/pipeline/scheduler.ts` drives `src/stages/noise|context|tone.ts` based on pause detection
- Stage diffs stream through `src/region/diffusion.ts` → `src/ui/marker.ts`/`swapRenderer.ts` for visual + caret-safe application
- Rust crate (`crates/core-rs`) supplies fragment extraction, pause timers, logging, and FFI/WASM shims reused by hosts

## How Rust and TypeScript work together

- We compile the Rust crate to WASM and import it in the web demo as a normal package. The demo calls Rust functions directly.
- Example JS/TS flow:

```ts
const extractor = new WasmFragmentExtractor();
const fragment = extractor.extract_fragment(text);
if (fragment) {
  const fragmentIndex = text.lastIndexOf(fragment);
  const prefix = text.substring(0, fragmentIndex);
  let merger = new WasmMerger(prefix);
  let stream = new WasmStubStream('This is a corrected sentence.');
  let token = await stream.next_token();
  while (token) {
    merger.apply_token(token);
    token = await stream.next_token();
  }
  setText(merger.get_result());
}
```

Corresponding Rust exports (simplified):

```rust
#[wasm_bindgen]
impl WasmFragmentExtractor { /* new(), extract_fragment(&str) -> Option<String> */ }
#[wasm_bindgen]
impl WasmMerger { /* new(&str), apply_token(&str), get_result() -> String */ }
#[wasm_bindgen]
impl WasmStubStream { /* new(&str), async next_token() -> Option<String> */ }
```

Why both languages?

- Rust provides speed and safety for fragmenting, merging, and timing.
- TypeScript/React provides rapid UI development and ecosystem tooling.

Where Swift fits (mac app):

- The macOS app UI will be Swift/SwiftUI calling the same Rust core via FFI (native interface). The Swift project isn’t in this repo yet.

## Task Board & Docs

- Tasks: `docs/02-implementation/02-Implementation.md` (first unchecked drives work in Cursor)
- System rules: `.cursor/rules/workflow.mdc`, `.cursor/rules/comment_style.mdc`, `.cursor/rules/generate.mdc`
- Glossary: `.cursor/rules/glossary.mdc`

## What's New

For the current code line, the docs canon is:

📋 **[Quality & Acceptance](docs/quality.md)** — gates, macOS HIG/AX/Perf anchors, and coverage links.

Key highlights:

- **LM-only correction wave**: `src/pipeline/correctionWave.ts` + `src/lm/adapter_v06.ts` run the same on web and mac hosts.
- **Atomic undo**: `src/ui/rollback.ts` + `src/region/diffusion.ts` keep Cmd+Z separate from Mind⠶Flow undo (see `AC-UNDO-ATOMIC`).
- **Diagnostics-first UI**: Playwright suites cover reduced motion, tone controls, and scenario presets; logs surface LM tier and health badges.
- **Docs consolidation**: Contracts + QA moved into `docs/contracts.md` and `docs/quality.md`, replacing dozens of stale guide files.

## License

MIT — see the badge above.

# Mind::Type

- See `docs/contracts.md#contract-active-region` for the Caret Monitor (active region) contract and APIs.
