# Mind⠶Type

**v1.0** — Apple-native typing intelligence with on-device language model

---

## What is Mind⠶Type?

Mind⠶Type is a caret-safe text correction system that improves your typing in real-time. It runs entirely on-device, processing text through a three-stage pipeline:

| Stage | Purpose | Examples |
|-------|---------|----------|
| **Noise** | Fix typos | teh → the, becuase → because |
| **Context** | Improve grammar | "Me and him went" → "He and I went" |
| **Tone** | Adjust style | casual ↔ professional |

### Key Principles

- 🔒 **Private** — All processing happens locally, no data leaves your device
- ⚡ **Fast** — Metal-accelerated inference on Apple Silicon
- 🎯 **Caret-safe** — Never modifies text at or after your cursor position
- 👁 **Transparent** — Visual feedback via the Correction Marker (⠶)

---

## Quick Start

### macOS App

```bash
# Build the Swift package
cd apple/MindType
swift build

# Run tests
swift test

# Open Testing Ground (requires Xcode project generation)
cd apple/MindTypeApp
xcodegen generate  # if using XcodeGen
open MindTypeApp.xcodeproj
```

### Testing Ground Demo

The Testing Ground provides an interactive demo:
1. Type or paste text with typos
2. Click "Run Correction" (⌘↵)
3. View corrections and latency metrics

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     MindType App                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Menu Bar    │  │ Testing     │  │ Settings        │ │
│  │ (⠶)         │  │ Ground      │  │                 │ │
│  └─────────────┘  └─────────────┘  └─────────────────┘ │
└───────────────────────┬─────────────────────────────────┘
                        │
┌───────────────────────▼─────────────────────────────────┐
│                   MindTypeCore                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────┐ │
│  │ Correction  │  │ Active      │  │ Caret           │ │
│  │ Pipeline    │──│ Region      │──│ Safety          │ │
│  └──────┬──────┘  └─────────────┘  └─────────────────┘ │
│         │                                               │
│  ┌──────▼──────┐                                       │
│  │ LM Adapter  │ ← Mock / llama.cpp                    │
│  └─────────────┘                                       │
└─────────────────────────────────────────────────────────┘
```

---

## Project Structure

```
project/
├── apple/                    # Apple-native implementation
│   ├── MindType/             # Swift Package (core library)
│   │   ├── Sources/
│   │   │   ├── MindTypeCore/ # Pipeline, types, LM adapter
│   │   │   └── MindTypeUI/   # SwiftUI components
│   │   └── Tests/
│   │
│   ├── MindTypeApp/          # macOS menu bar app
│   │   └── MindTypeApp/
│   │       ├── Views/        # SwiftUI views
│   │       └── AppState.swift
│   │
│   └── Models/               # GGUF model files
│
├── docs/                     # Documentation
│   ├── 01-prd/               # Product requirements
│   ├── 02-implementation/    # Technical specs
│   └── 05-adr/               # Architecture decisions
│
└── [archived web code]       # v0.8 TypeScript/WASM (tagged)
```

---

## Configuration

| Setting | Default | Range | Description |
|---------|---------|-------|-------------|
| Active Region | 20 words | 5–50 | Text before cursor to process |
| Pause Delay | 600 ms | 300–1500 | Wait time before correction |
| Confidence | 80% | 50–95% | Minimum certainty threshold |
| Tone Target | None | — | None / Casual / Professional |

---

## Caret Safety

The core UX guarantee: **corrections never disrupt your typing flow**.

```swift
/// A region is only safe to modify if entirely before the caret
func isCaretSafe(start: Int, end: Int, caret: Int) -> Bool {
    end <= caret && start < end
}
```

This means:
- Text at the cursor is never touched
- Text after the cursor is never touched
- No visual jumps or cursor displacement

---

## Requirements

- **macOS 14.0+** (Sonoma)
- **Apple Silicon** (M1/M2/M3) — recommended for Metal acceleration
- **Xcode 15.0+** — for building the app
- **Swift 5.9+**

---

## Development

### Build & Test

```bash
# Swift Package
cd apple/MindType
swift build
swift test

# Or use project scripts
pnpm swift:build
pnpm swift:test
```

### Model Setup (Optional)

The v1.0 demo uses a mock LM. For real inference:

```bash
# Download GGUF model
curl -L -o apple/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf
```

---

## Version History

| Version | Date | Platform | Notes |
|---------|------|----------|-------|
| **1.0.0** | 2025-11 | Apple | Swift/SwiftUI native rewrite |
| 0.8.0 | 2025-11 | Web | TypeScript/WASM (archived as tag) |

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Mind⠶Type</strong><br>
  <em>Type naturally. Corrections happen.</em>
</p>
