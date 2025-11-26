<!--
╔══════════════════════════════════════════════════════╗
║  ░  C H A N G E L O G  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
║                                                      ║
║                                                      ║
║                                                      ║
║                                                      ║
║           ╌╌  P L A C E H O L D E R  ╌╌              ║
║                                                      ║
║                                                      ║
║                                                      ║
║                                                      ║
╚══════════════════════════════════════════════════════╝
  • WHAT ▸ Release history for MindTyper
  • WHY  ▸ Transparent, skeptic‑friendly record of changes
  • HOW  ▸ Keep a Changelog format; date‑stamped entries
-->

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog and this project adheres to Semantic Versioning. Dates are in YYYY‑MM‑DD.

---

## [0.9.0] - 2025-11-26

### 🎉 Apple-Native Rewrite

**Complete architectural pivot** from cross-platform Rust/TypeScript/WASM to Apple-native Swift.

#### Added

- **Swift Package** (`apple/MindType/`) — Core library with SwiftUI components
  - `MindTypeCore` — Pipeline, types, caret safety, active region
  - `MindTypeUI` — SwiftUI visual components (CorrectionMarker)
  - `MindTypeDemo` — CLI demonstration executable

- **LLM Integration** via llama.cpp
  - `LlamaLMAdapter` — Metal-accelerated inference using llama.cpp CLI
  - `MockLMAdapter` — Pattern-matching fallback for testing
  - Qwen 0.5B model support (~470MB GGUF)

- **Documentation**
  - `ARCHITECTURE-MIGRATION.md` — Comprehensive analysis of Rust→Swift migration
  - Updated `README.md` with quick start guide

#### Changed

- **Architecture**: Single-language Swift instead of Rust/TypeScript/Swift hybrid
- **Build System**: Swift Package Manager only (no Cargo, no npm for core)
- **LLM Runtime**: llama.cpp with GGUF instead of Transformers.js/ONNX

#### Removed

- **Web Platform**: TypeScript/WASM web demo (archived to `_archived/v0.8-web/`)
- **Rust Core**: All Rust code moved to archive
- **FFI Layers**: No more C bindings or WASM bridge

#### Migration Notes

Previous v0.8 code is preserved in `_archived/v0.8-web/` for reference. The new architecture is incompatible with the old codebase—this is a clean rewrite.

See [ARCHITECTURE-MIGRATION.md](ARCHITECTURE-MIGRATION.md) for detailed analysis of trade-offs.

---

## [0.8.0] - 2025-11-15

### Major Restructure 🎯

**Complete repository reorganization** to mirror the runtime pipeline and improve developer experience.

#### Added

- **Monitor App** (`monitor/`) — Interactive pipeline visualization with retro 16-bit aesthetic
  - Live system map driven by `system-map.json`
  - Click nodes to drill into module details, connections, and config
  - Viewport-filling, responsive design
  - Run with: `pnpm monitor` → http://localhost:3001

- **Unified `src/` structure** mirroring pipeline flow:
  - `src/pipeline/` — Orchestration (scheduler, monitor, correctionWave, logger)
  - `src/stages/` — Three transformers (Noise → Context → Tone)
  - `src/region/` — Active Region policy + diffusion controller
  - `src/lm/` — Language model adapters (Transformers.js, workers, factories)
  - `src/safety/` — Caret-safe diff, grapheme boundaries, security detection
  - `src/ui/` — Visual feedback (marker, highlighter, rollback, liveRegion)
  - `src/config/` — Central thresholds and configuration

#### Changed

- **Reorganized hosts**: `web-demo/` → `hosts/web/`, `macOS/` → `hosts/macos/`
- **Simplified Rust path**: `crates/core-rs/` → `core-rs/`
- **Updated all imports** across ~200+ TypeScript files to match new structure
- **Version bump**: `0.6.0` → `0.8.0` (clean slate for demo-ready milestone)
- **Justfile** now includes `monitor` recipe
- **Package.json scripts** updated: `pnpm monitor`, `pnpm demo:web`

#### Documentation

- README updated with v0.8 structure guide
- `docs/14-project-structure/` refreshed to match new layout
- `docs/monitor/` added with usage guide and system-map update instructions
- `QUICKSTART-V08.md` now documents LM setup + training options (replacing the scattered guide)
- `docs/quality.md` — Comprehensive audit and derived rules

#### Migration Notes

All existing functionality preserved; only paths changed. If you have local branches:

1. Rebase on v0.8
2. Update imports using the migration scripts in `scripts/`
3. Run `pnpm typecheck` to catch any missed references

---

## [0.4.0] - 2025-09-09

### Added

- Core‑owned LM orchestration in Context stage with dual‑context windowing:
  - `core/lm/contextManager.ts` for Close (2–5 sentences) and Wide (document) contexts
  - Validation of Close‑context proposals against Wide context prior to commit
- Web Worker integration for Transformers.js with robust adapter:
  - `core/lm/workerAdapter.ts` (timeouts, error propagation, health logs)
  - `core/lm/transformersRunner.ts` (CDN wasmPaths default; `/wasm/` fallback)
- Workbench in web demo showing LM health, context windows, logs, and metrics
- Data‑testid hooks in LM Lab for E2E verification; presets JSON support

### Changed

- `engines/contextTransformer.ts` updated to drive LM span selection, prompting, and band‑bounded merges
- `core/sweepScheduler.ts` passes LM adapter/context to Context stage; removed duplicate LM stage
- Docs consolidated: canonical LM reference now lives in `docs/contracts.md`; architecture updated with v0.4 pipeline

### Fixed

- Stabilized ONNX Runtime Web asset loading (CDN by default; local fallback)
- Improved worker error handling and abort on new keystroke

### Docs

- Architecture (C1/C2/C3 and Overview) updated to show LM Worker + dual‑context
- Guides updated: LM reference now includes dual‑context and worker runtime details
- Root docs index clarified that v0.4 content is consolidated; removed redundant v0.4 files

## [0.0.1-alpha] - 2025-08-08

### Added

- MindTyper Manifesto (`docs/mindtyper_manifesto.md`) — product narrative for non‑technical readers with measurable guarantees.
- `.prettierignore` to exclude generated artifacts, subpackages, and lockfiles.

### Changed

- Prettier config aligned with workspace gates (`.prettierrc`).
- ESLint flat config polish and consistent single quotes (`eslint.config.js`).
- `docs/02-implementation/02-Implementation.md` updated with TODOs covering WASM bindings, LLM adapter, engine rules, A11Y, benches, and traceability.

### Removed

- Deprecated `docs/core_details.md` (TypeScript core) to reflect Rust‑first architecture.

### CI / Quality Gates

- Verified green on typecheck, lint, format:check, and unit tests.

### Docs

- `README.md` links to the Manifesto under "Recommended reading".

[0.0.1-alpha]: https://github.com/becktothefuture/mindtyper-qna/releases/tag/v0.0.1-alpha

## [0.0.1-alpha+1] - 2025-08-09

### Added

- FT-212: Punctuation normalization in `engines/noiseTransformer.ts` (spaces around commas/periods, em dash spacing).
- FT-214: Whitespace normalization (collapse multi-spaces/tabs; trim trailing whitespace before newline).
- FT-216: Capitalization rules (sentence-start capitalization; standalone 'i' → 'I').
- Web demo: active region alignment and newline safety improvements; `SecurityContext` gating hooks.

### Tests

- Expanded unit tests across noise transformer rules, diffusion controller, and sweep scheduler; integration harness proves end-to-end flow.
- Added branch-edge tests to lift global branch coverage ≥90%; utils guard at 100% branches.

### CI / Quality Gates

- All gates green: typecheck, lint, format, tests with coverage.

## v0.5.0 (2025-09-13)

- Consolidated demos under (project root)
- Simplified, numbered overview: 5 links across Main & Visual categories
- Vite serves from project-root
- Diagnostics bus + LM context reliability improvements
- Noise/context transformer fixes; caret-safe selection hardening
- E2E test stability and coverage retained
- Version bump to 0.5.0
