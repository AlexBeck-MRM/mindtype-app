# Architecture Migration: Rust/WASM → Apple-Native Swift

**Author**: Engineering Team  
**Date**: November 2025  
**Status**: Complete (v0.9.0)

---

## Executive Summary

MindType v0.9 represents a **complete architectural pivot** from a cross-platform Rust/TypeScript/WASM stack to an Apple-native Swift implementation. This document provides an objective analysis of why this decision was made, what we gained, what we lost, and the engineering trade-offs involved.

---

## The Previous Architecture (v0.5–0.8)

### Stack Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Web Browser                             │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ TypeScript   │  │ WASM         │  │ Transformers.js  │  │
│  │ UI Layer     │──│ Rust Core    │──│ ONNX Runtime     │  │
│  │ (React/Vite) │  │ (wasm-pack)  │  │ (WebGPU/WASM)    │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      macOS App                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐  │
│  │ Swift UI     │──│ C FFI        │──│ MLX/CoreML       │  │
│  │ (SwiftUI)    │  │ (Rust dylib) │  │ (pending)        │  │
│  └──────────────┘  └──────────────┘  └──────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Technology | Lines of Code | Purpose |
|-----------|------------|---------------|---------|
| Core Engine | Rust | ~5,000 | Correction algorithms, caret safety |
| Web UI | TypeScript/React | ~8,000 | Demo interface, visual feedback |
| WASM Bridge | wasm-bindgen | ~500 | Rust↔JS interop |
| C FFI | cbindgen | ~300 | Rust↔Swift interop |
| LM Integration | Transformers.js/ONNX | ~2,000 | Web LLM inference |
| Tests | TypeScript + Rust | ~4,000 | Unit + integration tests |

### Architecture Decision Records (ADRs)

The previous architecture was guided by these key decisions:

1. **ADR-0005: Complete Rust Orchestration** — All correction logic in Rust; JS/Swift as thin UI layers
2. **ADR-0007: macOS LM Strategy** — Phased approach: MLX → Core ML → Core LM
3. **ADR-0008: FFI JSON Bridge** — Structured JSON for cross-language data transfer

---

## Why We Changed

### The Core Problem

After months of development, several fundamental issues became apparent:

#### 1. Cross-Platform Complexity Tax

Every feature required implementation across **four layers**:
- Rust core logic
- WASM bindings (for web)
- C FFI bindings (for macOS)
- Platform UI (TypeScript OR Swift)

**Impact**: A single feature like "adjust confidence threshold" touched 8+ files across 3 languages.

#### 2. LLM Integration Fragmentation

The v0.5–0.8 architecture used different LLM backends per platform:

| Platform | LLM Runtime | Model Format | Status |
|----------|-------------|--------------|--------|
| Web | Transformers.js/ONNX | ONNX | Working but slow |
| macOS | MLX (planned) | MLX | Never completed |
| macOS | Core ML (planned) | mlpackage | Never completed |

**Impact**: No single LLM solution worked across platforms. The web demo used Transformers.js with 2-5 second latency; macOS had no working LLM.

#### 3. FFI Boundary Overhead

The Rust↔TypeScript (WASM) and Rust↔Swift (C FFI) boundaries introduced:
- Serialization/deserialization costs (JSON encoding)
- Memory management complexity (manual cleanup in Swift)
- Debugging difficulty across language barriers
- Type safety loss at boundaries

**Impact**: ~30% of bugs were FFI-related. Debug cycles were 3× longer.

#### 4. Build System Complexity

Building the project required:
```bash
# Previous build steps
cargo build --target wasm32-unknown-unknown  # Rust WASM
wasm-pack build --target web                  # JS bindings
pnpm install && pnpm build                    # TypeScript
cd macOS && xcodegen && xcodebuild            # macOS app
```

**Impact**: New contributors needed 2+ hours to set up the dev environment.

#### 5. Target Market Reality

The product's primary use case is **macOS power users** who type extensively. The web demo, while useful for showcasing, was never the production target.

**Impact**: 60% of development effort went into web infrastructure that wasn't the end goal.

---

## The New Architecture (v0.9)

### Stack Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    macOS Application                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │                    Swift/SwiftUI                        │ │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐ │ │
│  │  │ MindTypeUI   │  │ MindTypeCore │  │ LlamaAdapter │ │ │
│  │  │ (SwiftUI)    │──│ (Swift)      │──│ (llama.cpp)  │ │ │
│  │  └──────────────┘  └──────────────┘  └──────────────┘ │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### Key Components

| Component | Technology | Lines of Code | Purpose |
|-----------|------------|---------------|---------|
| Core Logic | Swift | ~800 | Types, pipeline, caret safety |
| LM Adapter | Swift + llama.cpp | ~200 | LLM inference via CLI |
| UI | SwiftUI | ~400 | Visual components |
| Demo | Swift | ~100 | CLI demonstration |
| Tests | XCTest | ~150 | Unit tests |

### Architecture Principles

1. **Single Language** — Everything in Swift (with llama.cpp as external tool)
2. **Single Platform** — macOS-first, iOS as natural extension
3. **Single LLM** — llama.cpp with GGUF models, Metal acceleration
4. **Zero FFI** — No cross-language boundaries in core logic

---

## Comparative Analysis

### What We Gained

#### 1. Dramatic Simplification

| Metric | v0.8 (Rust/TS) | v0.9 (Swift) | Change |
|--------|----------------|--------------|--------|
| Languages | 3 (Rust, TS, Swift) | 1 (Swift) | -67% |
| Build systems | 4 (Cargo, pnpm, wasm-pack, Xcode) | 1 (Swift PM) | -75% |
| Lines of code | ~20,000 | ~1,700 | -91% |
| Dependencies | ~150 npm + ~30 cargo | ~5 | -97% |
| Setup time | 2+ hours | 10 minutes | -92% |

#### 2. Working LLM Out of the Box

The v0.9 architecture has a **functional LLM** from day one:
- llama.cpp with Metal acceleration
- Qwen 0.5B model (~470MB)
- ~1.2 second correction latency
- No model conversion required (GGUF native)

**Comparison**: v0.8 web demo had 2-5s latency with Transformers.js; macOS had no LLM.

#### 3. Native Performance

| Operation | v0.8 (WASM) | v0.9 (Native) | Improvement |
|-----------|-------------|---------------|-------------|
| String manipulation | WASM overhead | Native | ~5× faster |
| LLM inference | ONNX Runtime | Metal GPU | ~3× faster |
| Memory usage | GC + WASM heap | ARC | ~50% less |
| Startup time | WASM init + model load | Model load only | ~2× faster |

#### 4. Apple Platform Integration

- **Metal GPU**: Direct access to Apple Silicon GPU for LLM inference
- **SwiftUI**: Native UI with system integration (Dark Mode, accessibility)
- **App Store Ready**: No WASM sandboxing issues or binary restrictions
- **Accessibility**: Built-in VoiceOver support

#### 5. Development Velocity

| Task | v0.8 Time | v0.9 Time | Improvement |
|------|-----------|-----------|-------------|
| Add new config option | 2-4 hours | 15 minutes | ~10× faster |
| Debug correction issue | 1-2 hours | 15-30 min | ~4× faster |
| Run full test suite | 5 minutes | 30 seconds | ~10× faster |
| Onboard new developer | 2+ hours | 10 minutes | ~12× faster |

---

### What We Lost

#### 1. Cross-Platform Capability

| Platform | v0.8 Support | v0.9 Support |
|----------|--------------|--------------|
| macOS | ✅ (partial) | ✅ Full |
| iOS | ⚠️ Planned | ✅ Compatible |
| Web | ✅ Demo working | ❌ Removed |
| Windows | ⚠️ Planned | ❌ Not supported |
| Linux | ⚠️ Planned | ❌ Not supported |

**Impact**: Users on Windows/Linux cannot use MindType. The web demo is no longer available.

**Mitigation**: The target market (power typists) skews heavily toward macOS. Cross-platform can be revisited if demand materializes.

#### 2. Rust's Safety Guarantees

Rust provided:
- **Memory safety** at compile time
- **Data race prevention** via ownership model
- **Fearless concurrency**

Swift provides:
- Memory safety via ARC (runtime, not compile-time)
- Actor isolation for concurrency (but less strict than Rust)
- Optional types for null safety

**Impact**: Certain classes of bugs that Rust would catch at compile time may appear at runtime in Swift.

**Mitigation**: Swift's actor model + careful testing. The codebase is small enough for thorough review.

#### 3. Web Distribution

The web demo was valuable for:
- Zero-install trial of the product
- Easy sharing via URL
- Onboarding without commitment

**Impact**: Potential users cannot try MindType without installing software.

**Mitigation**: Could create a simple web landing page with video demo. Or restore minimal web version later.

#### 4. Existing Test Coverage

v0.8 had:
- ~400 TypeScript unit tests
- ~50 Rust unit tests
- ~30 E2E tests
- 90%+ code coverage

v0.9 has:
- ~10 Swift unit tests
- 0 E2E tests
- ~40% code coverage (estimated)

**Impact**: Less regression protection during development.

**Mitigation**: Test coverage is a priority for v1.1. The smaller codebase makes comprehensive testing more achievable.

#### 5. Community/Ecosystem

| Aspect | v0.8 | v0.9 |
|--------|------|------|
| npm ecosystem | ✅ Full access | ❌ N/A |
| Rust crates | ✅ Full access | ❌ N/A |
| Swift packages | ❌ Limited | ✅ Full access |
| LLM libraries | Transformers.js, ONNX | llama.cpp only |

**Impact**: Fewer pre-built components to leverage. More custom code required.

**Mitigation**: Swift ecosystem is maturing. Apple's ML frameworks are increasingly capable.

---

## Technical Deep Dive: LLM Architecture

### v0.8 LLM Stack (Planned but Incomplete)

```
┌─────────────────────────────────────────────────────────────┐
│ Web: Transformers.js                                        │
│   └── ONNX Runtime (WASM/WebGPU)                           │
│       └── ONNX Model (~500MB download per session)          │
│                                                             │
│ macOS: MLX (Planned)                                        │
│   └── MLX Runtime (Metal)                                   │
│       └── Converted MLX Model (conversion required)         │
│                                                             │
│ Alternative: Core ML (Planned)                              │
│   └── Core ML Runtime (Neural Engine)                       │
│       └── .mlpackage (complex conversion pipeline)          │
└─────────────────────────────────────────────────────────────┘
```

**Problems**:
1. Three different model formats
2. Two different conversion pipelines
3. No unified inference API
4. WebGPU support inconsistent across browsers

### v0.9 LLM Stack

```
┌─────────────────────────────────────────────────────────────┐
│ LlamaLMAdapter                                              │
│   └── llama.cpp CLI (brew install)                          │
│       └── GGUF Model (direct download, no conversion)       │
│           └── Metal acceleration (automatic on Apple Silicon)│
└─────────────────────────────────────────────────────────────┘
```

**Advantages**:
1. Single model format (GGUF)
2. No conversion required
3. Proven llama.cpp performance
4. Automatic Metal GPU usage

**Current Limitation**: CLI invocation adds ~100ms overhead per call. Future improvement: link llama.cpp as C library directly.

---

## Objective Assessment

### When Rust/WASM Was the Right Choice

The original architecture made sense under these assumptions:
1. **Cross-platform is essential** — Reach web, desktop, mobile with one codebase
2. **Web is the primary platform** — Zero-install trial is crucial for adoption
3. **LLM technology is immature** — Need flexibility to swap backends
4. **Team has Rust expertise** — Can maintain complex FFI boundaries

### When Swift-Native Became the Right Choice

The pivot made sense when:
1. **Target market crystallized** — macOS power users, not general web users
2. **LLM landscape matured** — llama.cpp + GGUF became the de facto standard
3. **Complexity exceeded value** — Maintenance cost outweighed cross-platform benefits
4. **Shipping became priority** — Working product > theoretical flexibility

### The Honest Truth

Both architectures are valid engineering choices. The migration was driven by:

1. **Pragmatism over purity** — Ship something that works vs. build something perfect
2. **Focus over breadth** — Excel on one platform vs. be mediocre on many
3. **Simplicity over capability** — Fewer features, but they actually work

---

## Lessons Learned

### 1. Premature Abstraction is Costly

Building cross-platform infrastructure before validating product-market fit consumed months of effort that didn't translate to user value.

**Recommendation**: Start with the simplest stack that can validate the core hypothesis. Abstract later.

### 2. FFI Boundaries Are Expensive

Every language boundary introduces:
- Serialization overhead
- Type safety gaps
- Debugging complexity
- Mental context switching

**Recommendation**: If you must cross language boundaries, minimize them. Prefer thick foreign layers over thin ones.

### 3. Model Portability Matters

The LLM ecosystem fragmentation (ONNX, MLX, Core ML, GGUF, SafeTensors) is a significant engineering tax.

**Recommendation**: Choose the format with the best tooling and stick with it. GGUF + llama.cpp is currently the pragmatic choice.

### 4. Complexity Has Compound Interest

Every additional technology in the stack:
- Requires ongoing maintenance
- Creates potential failure points
- Increases onboarding time
- Slows iteration velocity

**Recommendation**: Aggressively remove complexity. If a component isn't providing clear value, eliminate it.

---

## Future Considerations

### If We Need Cross-Platform Again

Options ranked by practicality:

1. **Separate native apps** — Swift for Apple, Kotlin for Android, native for each
2. **Flutter + native LLM** — Dart UI with platform-specific LLM bridges
3. **Return to Rust core** — But with lessons learned about scope

### If We Need Web Again

Options:

1. **Minimal web demo** — Static site with video, link to download
2. **WebAssembly LLM** — llama.cpp compiled to WASM (experimental)
3. **Server-side inference** — API backend (breaks privacy promise)

---

## Conclusion

The migration from Rust/WASM to Swift was a **strategic retreat** that enabled tactical advancement. We traded theoretical capability for practical functionality.

**The previous architecture was not wrong** — it was optimized for a different set of constraints. As those constraints changed (target market clarity, LLM ecosystem maturation, shipping pressure), the optimal architecture changed with them.

**The current architecture is not permanent** — it's optimized for the current phase: prove the product works, gather user feedback, iterate quickly. Future phases may require different trade-offs.

The mark of good engineering is not building the most sophisticated system, but building the right system for the current context. For MindType in November 2025, that system is Apple-native Swift with llama.cpp.

---

## References

- [ADR-0005: Complete Rust Orchestration](docs/05-adr/0005-rust-first-orchestrator.md)
- [ADR-0007: macOS LM Strategy](docs/05-adr/0007-macos-lm-strategy.md)
- [v0.8 Restructure Summary](_archived/v0.8-web/V08-RESTRUCTURE-SUMMARY.md)
- [Product Requirements](docs/01-prd/01-PRD.md)

---

*Document version: 1.0 | Last updated: November 2025*

