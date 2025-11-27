# Mind⠶Type Documentation

**v0.9.1** — Fuzzy typing interpreter with custom-trained LLM

---

## Quick Navigation

| Document | Purpose | Read When |
|----------|---------|-----------|
| **[CORE.md](CORE.md)** | Vision, scenarios, principles | Understanding *what* and *why* |
| **[IMPLEMENTATION.md](IMPLEMENTATION.md)** | Architecture, training, pipeline | Understanding *how* |
| **[ARCHITECTURE-MIGRATION.md](ARCHITECTURE-MIGRATION.md)** | Why Swift over Rust | Understanding *decisions* |
| **[adr/](adr/)** | Architecture decision records | Deep technical context |

---

## At a Glance

**Mind⠶Type** interprets fuzzy typing through:

1. **Custom-Trained LLM** — MindFlow Qwen, fine-tuned for typo interpretation
2. **Context-Aware Decoding** — `msses` → "masses" OR "misses" based on sentence
3. **Caret-Safe Guarantee** — Never modifies text at/after cursor
4. **On-Device Inference** — MLX on Apple Silicon, private and fast

---

## Current Build Status (v0.9.1)

| Layer | Component | Status |
|-------|-----------|--------|
| **Model** | MindFlow Qwen 3B v2 | ✅ Fine-tuned |
| | MLX inference | ✅ Metal-accelerated |
| **Core** | Correction pipeline | ✅ Working |
| | Caret safety | ✅ Enforced |
| | Multi-pass validation | ✅ Implemented |
| **Demo** | Python ENTER mode | ✅ Working |
| | Python real-time mode | ✅ Working |
| | Swift CLI | ✅ Working |
| **App** | Menu Bar App | 📋 Planned |

---

## Quick Start

```bash
# Install MLX
pip install mlx mlx-lm

# Run ENTER mode demo
python3 tools/mindtype_mlx.py

# Run real-time demo
python3 tools/mindtype_realtime.py
```

---

## For AI Agents

When working with this codebase:

1. **Start with [CORE.md](CORE.md)** — Contains scenarios and design principles
2. **Reference [IMPLEMENTATION.md](IMPLEMENTATION.md)** — For technical architecture and training
3. **Check model versions** — v2 is literal, v3 is creative
4. **Understand validation** — Multi-pass structural checks prevent hallucination

---

## Key Concepts

| Concept | Meaning |
|---------|---------|
| **Fuzzy typing** | Speed typing where words become unrecognizable |
| **Intent interpretation** | Understanding what user *meant*, not just fixing typos |
| **Context disambiguation** | Same garbled word → different meanings based on sentence |
| **Structural validation** | Ensure output preserves sentence count and length |
| **Caret-safe** | Never modify text at or after cursor position |

---

## Historical Documentation

Previous Rust/TypeScript/WASM architecture docs are in `/_archived/v0.8-web/docs/`.

<!-- DOC META: VERSION=2.1 | UPDATED=2025-11-27 -->
