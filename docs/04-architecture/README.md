<!--══════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  04-architecture — Index  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌                      ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Index of this folder
    • WHY  ▸ Quick navigation and discovery
    • HOW  ▸ Auto-generated; edit children, not this list
-->

# Mind⠶Flow Revolutionary Architecture

Start with `architecture.mmd` in this folder—it's the canonical mermaid diagram that mirrors the codebase. This README summarizes each layer and points to the current contracts and ADRs.

## Core Layers

1. **Scenarios & intent** — The seven reference scenarios in `docs/01-prd/01-PRD.md` explain why the system exists and what success looks like.
2. **Correction Marker system** — `src/ui/marker.ts`, `src/ui/motion.ts`, and `src/ui/swapRenderer.ts` render listening vs. correction states, respect reduced motion, and trail the caret.
3. **Burst → Pause → Correct pipeline** — `src/pipeline/monitor.ts` and `src/pipeline/scheduler.ts` feed `src/stages/noise|context|tone.ts` with single-flight LM waves.
4. **Active Region & Safety** — `src/region/policy.ts` + `src/region/diffusion.ts` enforce caret-safe windows; see `docs/contracts.md#contract-active-region`.
5. **LM Adapter + Stream** — `src/lm/adapter_v06.ts`, `src/lm/types.ts`, and `hosts/web/src/worker/lmWorker.ts` obey the JSONL stream contract (`docs/contracts.md#contract-lm-stream`).
6. **Hosts** — Web (React/Vite) and macOS (SwiftUI) consume the same pipeline. Mac-specific HIG/AX/Perf anchors live in `docs/quality.md`.

## Reference Material

- **Diagram**: [`architecture.mmd`](./architecture.mmd)
- **Contracts**: [`../contracts.md`](../contracts.md)
- **Quality & QA**: [`../quality.md`](../quality.md)
- **ADRs**:
  - [ADR-0002 — Caret-Safe Diffs](../05-adr/0002-caret-safe-diff.md)
  - [ADR-0003 — Architecture Constraints](../05-adr/0003-architecture-constraints.md)
  - [ADR-0005 — Rust-First Orchestrator](../05-adr/0005-rust-first-orchestrator.md)
  - [ADR-0006 — LM-only Rollback Hotkey](../05-adr/0006-lm-only-rollback.md)
  - [ADR-0008 — FFI JSON Bridge](../05-adr/0008-ffi-json-bridge.md)

Stay aligned with the diagram: when code drifts, either update the implementation or submit a diagram change alongside your PR.

<!-- DOC META: VERSION=1.0 | UPDATED=2025-09-17T20:45:45Z -->
