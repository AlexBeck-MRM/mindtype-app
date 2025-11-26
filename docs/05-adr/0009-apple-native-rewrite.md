<!--══════════════════════════════════════════════════════════
  ╔══════════════════════════════════════════════════════════════╗
  ║  ░  ADR-0009: APPLE-NATIVE REWRITE  ░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Swift/SwiftUI implementation replacing Rust/TypeScript.    ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
    • WHAT ▸ Complete rewrite in Swift with llama.cpp LLM
    • WHY  ▸ Simplicity, shipping velocity, Apple platform focus
    • HOW  ▸ Single-language stack, GGUF models, Metal acceleration
-->

# ADR-0009: Apple-Native Rewrite

**Status**: Accepted  
**Date**: 2025-11-26  
**Supersedes**: ADR-0005 (Rust-First), ADR-0007 (macOS LM Strategy), ADR-0008 (FFI Bridge)

## Context

After 6+ months developing a cross-platform Rust/TypeScript/WASM architecture, several factors converged that made an Apple-native rewrite the pragmatic choice:

1. **Target market clarity**: Power typists on macOS, not general web users
2. **LLM ecosystem maturation**: llama.cpp + GGUF became the de facto standard
3. **Complexity tax**: FFI boundaries consumed 30%+ of debugging effort
4. **Shipping pressure**: Working product > theoretical cross-platform flexibility

## Decision

**Rewrite MindType in Swift/SwiftUI** with the following characteristics:

1. **Single language**: Swift for all core logic and UI
2. **Single platform**: macOS-first (iOS as natural extension)
3. **Single LLM runtime**: llama.cpp via CLI (future: C library integration)
4. **Zero FFI**: No cross-language boundaries in core logic

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MindType (Swift)                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ MindTypeUI   │  │ MindTypeCore │  │ LlamaLMAdapter   │  │
│  │ (SwiftUI)    │──│ (Pipeline)   │──│ (llama.cpp CLI)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### LLM Integration

- **Runtime**: llama.cpp (Homebrew install)
- **Model**: Qwen2.5-0.5B-Instruct (~470MB GGUF)
- **Acceleration**: Metal GPU on Apple Silicon
- **Latency**: ~1.2s per correction wave

## Consequences

### Positive

| Metric | Before (Rust/TS) | After (Swift) |
|--------|------------------|---------------|
| Languages | 3 | 1 |
| Lines of code | ~20,000 | ~1,700 |
| Build systems | 4 | 1 |
| Setup time | 2+ hours | 10 minutes |
| LLM working | No (macOS) | Yes |

### Negative

| Loss | Impact | Mitigation |
|------|--------|------------|
| Web platform | No browser demo | Video demo, landing page |
| Windows/Linux | Not supported | Target market is macOS |
| Rust safety | Runtime vs compile-time | Actor model, testing |
| Test coverage | 90% → ~40% | Priority for v1.1 |

## Alternatives Considered

1. **Continue Rust/TypeScript**: Rejected due to complexity and shipping delays
2. **MLX Swift**: Rejected due to model conversion overhead
3. **Core ML**: Rejected due to conversion pipeline complexity
4. **Server-side LLM**: Rejected because it breaks privacy promise

## Implementation

See [ARCHITECTURE-MIGRATION.md](/ARCHITECTURE-MIGRATION.md) for comprehensive analysis.

### Key Components

- `apple/MindType/Sources/MindTypeCore/` — Pipeline, types, caret safety
- `apple/MindType/Sources/MindTypeCore/LlamaLMAdapter.swift` — llama.cpp integration
- `apple/MindType/Sources/MindTypeDemo/` — CLI demonstration

### Quick Start

```bash
brew install llama.cpp
curl -L -o apple/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf [model-url]
cd apple/MindType && swift run MindTypeDemo
```

## Related Documents

- [ARCHITECTURE-MIGRATION.md](/ARCHITECTURE-MIGRATION.md) — Full migration analysis
- [ADR-0002: Caret-Safe Diff](0002-caret-safe-diff.md) — Still applies
- [ADR-0003: Architecture Constraints](0003-architecture-constraints.md) — Partially applies

---

*"The mark of good engineering is not building the most sophisticated system, but building the right system for the current context."*

<!-- DOC META: VERSION=1.0 | UPDATED=2025-11-26T00:00:00Z -->

