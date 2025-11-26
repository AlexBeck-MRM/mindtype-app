<!--══════════════════════════════════════════════════════════════════════════
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  ADR-0009: APPLE-NATIVE REWRITE                                           ║
  ╚═══════════════════════════════════════════════════════════════════════════╝
    • WHAT  ▸  Complete rewrite in Swift with llama.cpp LLM
    • WHY   ▸  Simplicity, shipping velocity, platform focus
-->

# ADR-0009: Apple-Native Rewrite

**Status:** Accepted  
**Date:** 2025-11-26  
**Supersedes:** ADR-0005 (Rust-First), ADR-0007 (macOS LM Strategy), ADR-0008 (FFI Bridge)

---

## Context

After 6+ months developing a cross-platform Rust/TypeScript/WASM architecture, several factors converged:

1. **Target market clarity:** Power typists on macOS, not general web users
2. **LLM ecosystem maturation:** llama.cpp + GGUF became de facto standard
3. **Complexity tax:** FFI boundaries consumed 30%+ of debugging effort
4. **Shipping pressure:** Working product > theoretical cross-platform flexibility

## Decision

**Rewrite MindType in Swift/SwiftUI** with:

| Aspect | Choice |
|--------|--------|
| Language | Swift only |
| Platform | macOS-first (iOS natural extension) |
| LLM Runtime | llama.cpp via CLI (future: C library) |
| FFI | Zero cross-language boundaries |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    MindType (Swift)                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ MindTypeUI   │  │ MindTypeCore │  │ LlamaLMAdapter       │  │
│  │ (SwiftUI)    │──│ (Pipeline)   │──│ (llama.cpp CLI)      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

### LLM Integration

- **Runtime:** llama.cpp (Homebrew: `brew install llama.cpp`)
- **Model:** Qwen2.5-0.5B-Instruct (~470MB GGUF)
- **Acceleration:** Metal GPU on Apple Silicon
- **Latency:** ~1.2s per correction wave

## Consequences

### Quantified Impact

| Metric | Before (Rust/TS) | After (Swift) |
|--------|------------------|---------------|
| Languages | 3 | 1 |
| Lines of code | ~20,000 | ~1,700 |
| Build systems | 4 | 1 |
| Setup time | 2+ hours | 10 minutes |
| LLM working | No | Yes |

### Accepted Tradeoffs

| Loss | Impact | Mitigation |
|------|--------|------------|
| Web platform | No browser demo | Video demo, landing page |
| Windows/Linux | Not supported | Target market is macOS |
| Rust safety | Runtime vs compile-time | Actor model, testing |
| Test coverage | 90% → ~40% | Priority for v1.1 |

## Alternatives Considered

| Alternative | Reason Rejected |
|-------------|-----------------|
| Continue Rust/TypeScript | Complexity, shipping delays |
| MLX Swift | Model conversion overhead |
| Core ML | Conversion pipeline complexity |
| Server-side LLM | Breaks privacy promise |

## Related Documents

- [ARCHITECTURE-MIGRATION.md](/ARCHITECTURE-MIGRATION.md) — Full migration analysis
- [ADR-0002: Caret-Safe Diff](0002-caret-safe.md) — Still applies

---

*"The mark of good engineering is not building the most sophisticated system, but building the right system for the current context."*

<!-- DOC META: VERSION=0.9 | UPDATED=2025-11-26 -->

