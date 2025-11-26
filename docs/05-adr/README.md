# Architecture Decision Records

This folder contains Architecture Decision Records (ADRs) that document significant technical decisions in MindType's evolution.

## Active ADRs

| ADR | Title | Status | Notes |
|-----|-------|--------|-------|
| [0001](0001-template.md) | ADR Template | Template | Use for new decisions |
| [0002](0002-caret-safe-diff.md) | Caret-Safe Diff | Active | Core UX guarantee |
| [0003](0003-architecture-constraints.md) | Architecture Constraints | Active | Design boundaries |
| **[0009](0009-apple-native-rewrite.md)** | **Apple-Native Rewrite** | **Active** | **v1.0 architecture** |

## Superseded ADRs (Archived)

The following ADRs documented the previous Rust/TypeScript/WASM architecture and have been moved to `_archived/v0.8-web/docs/05-adr/`:

- ADR-0005: Rust-First Orchestrator
- ADR-0006: LM-Only Rollback
- ADR-0007: macOS LM Strategy
- ADR-0008: FFI JSON Bridge

These are preserved for historical reference and to understand the project's evolution.

## Creating New ADRs

1. Copy `0001-template.md`
2. Number sequentially (e.g., `0010-new-decision.md`)
3. Fill in context, decision, and consequences
4. Submit for review

<!-- DOC META: VERSION=2.0 | UPDATED=2025-11-26T00:00:00Z -->
