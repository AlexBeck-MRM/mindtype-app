# Mind⠶Type

**v0.9.0** — Apple-native typing intelligence with on-device LLM

---

## What is Mind⠶Type?

Mind⠶Type is a **fuzzy typing interpreter** that understands what you *meant* to type, not just what you typed. Unlike autocorrect, which fixes individual words, Mind⠶Type interprets your **intent** from the full context—even when your typing is completely garbled.

| What it does | Example |
|--------------|---------|
| **Interprets garbled words** | `iualpio` → "upon" |
| **Decodes velocity typing** | `msaasexd` → "masses" |
| **Understands run-togethers** | `crezt e` → "create" |
| **Preserves meaning** | Your intent, not your keystrokes |

### This is NOT Autocorrect

| Autocorrect | Mind⠶Type |
|-------------|-----------|
| Matches words in dictionary | Interprets intent from context |
| Fails on unknown words | Decodes any garbled input |
| Per-word corrections | Whole-sentence understanding |
| "Did you mean...?" | Just knows |

### Core Principles

- 🔒 **Private** — 100% on-device processing, no cloud
- ⚡ **Fast** — Metal-accelerated inference on Apple Silicon
- 🎯 **Caret-safe** — Never modifies text at or after your cursor
- 🧠 **Intelligent** — LLM-powered intent interpretation via MLX/Qwen

---

## Fuzzy Typing in Action

Type at the speed of thought. Mind⠶Type figures out what you meant.

**Input (garbled):**
```
once iualpio a time tbere weas a prince tgbhat wanted to crezt e a new 
ways to write. the msaasexd has no idea who he wa showever he was a 
visionsary that create d a new ftookl atht the workds hasnf experiencex before.
```

**Output (interpreted):**
```
Once upon a time there was a prince who wanted to create a new way to 
write. The masses had no idea who he was, however he was a visionary 
that created a new tool that the world hadn't experienced before.
```

### How it Works

Mind⠶Type uses a fine-tuned language model to **interpret** rather than **correct**:

1. **Word-level interpretation** — `iualpio` becomes "upon" through phonetic and contextual reasoning
2. **Structure preservation** — Same number of sentences, same overall meaning
3. **Self-review** — The model validates its interpretations make sense
4. **Structural guards** — Output must match input structure (length, sentences)

### Try the Demo

```bash
# ENTER mode - type, press Enter, see interpretation
python3 tools/mindtype_mlx.py

# Real-time mode - interpretations happen as you type
python3 tools/mindtype_realtime.py
```

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

# 2. Download the model (~1GB for best quality, or ~470MB for fastest)
mkdir -p apple/Models

# Recommended: Qwen 1.5B (best balance of speed and quality)
curl -L -o apple/Models/qwen2.5-1.5b-instruct-q4_k_m.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"

# Alternative: Qwen 0.5B (faster, lower quality)
# curl -L -o apple/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
#   "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"

# 3. Switch to Xcode toolchain (one-time)
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# 4. Build and run demo
cd apple/MindType
swift build
swift run MindTypeDemo
```

---

## Demo Modes

```bash
# Seven Scenarios test (default)
swift run MindTypeDemo

# Interactive REPL - type your own text
swift run MindTypeDemo --interactive

# Quick test suite
swift run MindTypeDemo --quick

# Help
swift run MindTypeDemo --help
```

### Sample Output

```
╔══════════════════════════════════════════════════════════════╗
║           M I N D ⠶ T Y P E   D E M O   v 0 . 9              ║
║                                                              ║
║   Three-stage on-device typing intelligence                  ║
║   Noise → Context → Tone                                     ║
╚══════════════════════════════════════════════════════════════╝

🧠 Found model: qwen2.5-0.5b-instruct-q4_k_m.gguf
✅ Llama adapter ready (Metal-accelerated)
─────────────────────────────────────────────────────────────────
  Mode: 🚀 Real LLM (Qwen 0.5B, Metal)
─────────────────────────────────────────────────────────────────

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Maya 📚  Academic writing with scientific terminology
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   Input:  "The resarch shows that enviromental sustainabile practices..."
   Output: "The research shows that environmental sustainability practices..."
   ⏱️  1675ms │ 📊 2 correction(s)
      🔧 Typo Fix: Fixed 5 misspellings
      📖 Grammar: Improved sentence structure
```

### Interactive Mode

```bash
swift run MindTypeDemo -i
```

```
⠶ I was writting a lettr to my freind
   Input:  "I was writting a lettr to my freind"
   Output: "I was writing a letter to my friend"
   ⏱️  1102ms │ 📊 1 correction(s)

⠶ :tone professional
   → Tone set to: Professional

⠶ :quit
👋 Goodbye!
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
│   ├── CORE.md                     # Vision, scenarios, principles
│   ├── IMPLEMENTATION.md           # Architecture, API, build status
│   └── adr/                        # Architecture decisions
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
| [docs/CORE.md](docs/CORE.md) | Vision, scenarios, principles |
| [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) | Architecture, API, build status |
| [docs/adr/](docs/adr/) | Architecture decision records |
| [ARCHITECTURE-MIGRATION.md](ARCHITECTURE-MIGRATION.md) | Why we migrated from Rust to Swift |

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
