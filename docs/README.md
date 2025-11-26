# Mind⠶Type Documentation

**v0.9** — Apple-native typing intelligence

---

## Quick Navigation

| Document | Purpose | Read When |
|----------|---------|-----------|
| **[CORE.md](CORE.md)** | Vision, scenarios, principles | Understanding *what* and *why* |
| **[IMPLEMENTATION.md](IMPLEMENTATION.md)** | Architecture, API, build guide | Understanding *how* |
| **[adr/](adr/)** | Architecture decisions | Understanding *why this way* |

---

## At a Glance

**Mind⠶Type** transforms typing into fluid thought expression through:

1. **Three-Stage Pipeline** — Noise → Context → Tone
2. **Caret-Safe Guarantee** — Never modifies text at/after cursor
3. **On-Device LLM** — Private, fast, Metal-accelerated

---

## Current Build Status (v0.9.0)

| Layer | Component | Status |
|-------|-----------|--------|
| **Core** | Three-stage pipeline | ✅ Working |
| | Caret safety | ✅ Enforced |
| | LlamaLMAdapter | ✅ With timeout |
| | MockLMAdapter | ✅ For dev/test |
| **UX** | Burst-Pause-Correct | 📋 Planned |
| | Correction Marker | 🔧 Scaffold |
| | System-wide input | 📋 Planned |
| **App** | CLI Demo | ✅ Working |
| | Menu Bar App | 📋 Planned |

---

## For AI Agents

When working with this codebase:

1. **Start with [CORE.md](CORE.md)** — Contains the Seven Scenarios that drive all features
2. **Reference [IMPLEMENTATION.md](IMPLEMENTATION.md)** — For API contracts and code patterns
3. **Check [adr/0009-swift-rewrite.md](adr/0009-swift-rewrite.md)** — For architecture context
4. **Validate against caret-safety** — The invariant in [adr/0002-caret-safe.md](adr/0002-caret-safe.md)

---

## For Human Developers

```bash
# Quick start
brew install llama.cpp
cd apple/MindType && swift run MindTypeDemo

# Full setup
see IMPLEMENTATION.md → Build & Run
```

---

## Historical Documentation

Previous Rust/TypeScript/WASM architecture docs are in `/_archived/v0.8-web/docs/`.

<!-- DOC META: VERSION=2.0 | UPDATED=2025-11-26 -->
