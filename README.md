# Mind⠶Type

**v0.9.0** — Apple-native typing intelligence with on-device LLM

---

## What is Mind⠶Type?

Mind⠶Type is a **caret-safe text correction system** that improves your typing in real-time using on-device language models. All processing happens locally—no data ever leaves your device.

| Stage | Purpose | Examples |
|-------|---------|----------|
| **Noise** | Fix typos | teh → the, becuase → because |
| **Context** | Improve grammar | "Me and him went" → "He and I went" |
| **Tone** | Adjust style | casual ↔ professional |

### Core Principles

- 🔒 **Private** — 100% on-device processing, no cloud
- ⚡ **Fast** — Metal-accelerated inference on Apple Silicon (~1.2s latency)
- 🎯 **Caret-safe** — Never modifies text at or after your cursor
- 🧠 **Intelligent** — Real LLM corrections via Qwen 0.5B

---

## Quick Start

### Prerequisites

- macOS 14.0+ (Sonoma)
- Xcode 15+ (for toolchain)
- Homebrew

### Setup

```bash
# 1. Install llama.cpp
brew install llama.cpp

# 2. Download the model (~470MB)
mkdir -p apple/Models
curl -L -o apple/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"

# 3. Switch to Xcode toolchain (one-time)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 4. Build and run demo
cd apple/MindType
swift build
swift run MindTypeDemo
```

### Expected Output

```
╔══════════════════════════════════════════════════════════════╗
║           M I N D ⠶ T Y P E   D E M O   v 1 . 0              ║
╚══════════════════════════════════════════════════════════════╝

🧠 Found model: .../qwen2.5-0.5b-instruct-q4_k_m.gguf
✅ Llama adapter initialized (Metal-accelerated)

📝 Test 1: Multiple typos
   Input:  "I was writting a letter to my freind becuase I beleive its neccessary."
   Output: "I was writing a letter to my friend because I believe it is necessary."
   ⏱️  Latency: 1291.5 ms
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    MindType App (Future)                    │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Menu Bar ⠶  │  │ Testing     │  │ Settings            │ │
│  └─────────────┘  │ Ground      │  └─────────────────────┘ │
│                   └─────────────┘                           │
└───────────────────────┬─────────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────────┐
│                    MindTypeCore                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │ Correction  │──│ Active      │──│ Caret               │ │
│  │ Pipeline    │  │ Region      │  │ Safety              │ │
│  └──────┬──────┘  └─────────────┘  └─────────────────────┘ │
│         │                                                   │
│  ┌──────▼──────────────────────────────────────────────┐   │
│  │ LM Adapter (Protocol)                               │   │
│  │   ├── MockLMAdapter     (pattern matching)          │   │
│  │   └── LlamaLMAdapter    (llama.cpp + Metal)         │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
mindtype/
├── apple/                          # Apple-native implementation
│   ├── MindType/                   # Swift Package
│   │   ├── Package.swift
│   │   ├── Sources/
│   │   │   ├── MindTypeCore/       # Core logic
│   │   │   │   ├── Types.swift
│   │   │   │   ├── CaretSafety.swift
│   │   │   │   ├── ActiveRegion.swift
│   │   │   │   ├── CorrectionPipeline.swift
│   │   │   │   ├── LMAdapter.swift
│   │   │   │   └── LlamaLMAdapter.swift
│   │   │   ├── MindTypeUI/         # SwiftUI components
│   │   │   └── MindTypeDemo/       # CLI demo
│   │   └── Tests/
│   ├── MindTypeApp/                # macOS menu bar app
│   └── Models/                     # GGUF model files (gitignored)
│
├── docs/                           # Documentation
│   ├── 01-prd/                     # Product requirements
│   ├── 02-implementation/          # Technical specs
│   ├── 05-adr/                     # Architecture decisions
│   └── ...
│
├── _archived/                      # Previous v0.8 TypeScript/Rust code
│   └── v0.8-web/
│
├── README.md                       # This file
├── ARCHITECTURE-MIGRATION.md       # Why we moved from Rust to Swift
├── CHANGELOG.md                    # Release history
└── package.json                    # npm scripts for convenience
```

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Active Region | 20 words | 5–50 | Text before cursor to process |
| Temperature | 0.1 | 0.0–1.0 | LLM creativity (lower = more consistent) |
| Max Tokens | 64 | 16–256 | Maximum generation length |
| GPU Layers | 99 | -1 to 99 | Metal layers (-1 = auto) |

---

## Caret Safety

The **core UX guarantee**: corrections never disrupt your typing flow.

```swift
/// A region is only safe to modify if entirely before the caret
func isCaretSafe(start: Int, end: Int, caret: Int) -> Bool {
    end <= caret && start < end
}
```

This means:
- ✅ Text **before** the cursor can be corrected
- ❌ Text **at** the cursor is never touched
- ❌ Text **after** the cursor is never touched
- ❌ No visual jumps or cursor displacement

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 14.0+ (Sonoma) |
| Chip | Apple Silicon recommended (M1/M2/M3/M4) |
| Xcode | 15.0+ |
| Swift | 5.9+ |
| llama.cpp | Via Homebrew |
| Model | Qwen2.5-0.5B (~470MB) |

---

## Commands

```bash
# Build
npm run build          # or: cd apple/MindType && swift build

# Test
npm run test           # or: cd apple/MindType && swift test

# Demo
npm run demo           # or: cd apple/MindType && swift run MindTypeDemo
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [ARCHITECTURE-MIGRATION.md](ARCHITECTURE-MIGRATION.md) | Why we migrated from Rust to Swift |
| [docs/01-prd/](docs/01-prd/) | Product requirements |
| [docs/05-adr/](docs/05-adr/) | Architecture decision records |
| [docs/contracts.md](docs/contracts.md) | API contracts |

---

## Version History

| Version | Date | Platform | Notes |
|---------|------|----------|-------|
| **0.9.0** | 2025-11 | Apple | Swift/SwiftUI native, llama.cpp LLM |
| 0.8.0 | 2025-11 | Web | TypeScript/WASM restructure (archived) |
| 0.5.0 | 2025-09 | Web | Rust core + TypeScript UI |
| 0.4.0 | 2025-09 | Web | LM integration + dual context |

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Mind⠶Type</strong><br>
  <em>Type naturally. Corrections happen.</em>
</p>
