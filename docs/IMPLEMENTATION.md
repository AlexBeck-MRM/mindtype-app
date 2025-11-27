<!--══════════════════════════════════════════════════════════════════════════
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  M I N D ⠶ T Y P E   I M P L E M E N T A T I O N                           ║
  ║                                                                           ║
  ║  Architecture · API · Build Status · Integration                          ║
  ╚═══════════════════════════════════════════════════════════════════════════╝
    • WHAT  ▸  Technical implementation reference
    • WHO   ▸  AI agents and developers building on MindType
    • WHY   ▸  Reduce onboarding time, ensure consistent integration
-->

# Implementation Guide

**Version:** 0.9.0  
**Platform:** macOS 14+ / iOS 17+ (Apple Silicon)  
**Language:** Swift 5.9+

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           MindType System                               │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                        MindTypeCore                              │  │
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐  │  │
│  │  │ CorrectionPipe  │  │ ActiveRegion    │  │ CaretSafety     │  │  │
│  │  │ line            │→ │ Policy          │→ │                 │  │  │
│  │  └────────┬────────┘  └─────────────────┘  └─────────────────┘  │  │
│  │           │                                                      │  │
│  │  ┌────────▼────────┐                                            │  │
│  │  │   LMAdapter     │ ← Protocol (Mock | Llama | CoreML)         │  │
│  │  └─────────────────┘                                            │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                        MindTypeUI                                │  │
│  │  ┌─────────────────┐  ┌─────────────────┐                       │  │
│  │  │ CorrectionMarker│  │ StatusIndicator │                       │  │
│  │  └─────────────────┘  └─────────────────┘                       │  │
│  └──────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Core Types

### TextRegion

Defines a contiguous range of text for processing.

```swift
public struct TextRegion: Sendable, Equatable {
    public let start: Int   // Inclusive, character offset
    public let end: Int     // Exclusive, character offset
    
    public var isEmpty: Bool { start >= end }
    public var length: Int { max(0, end - start) }
}
```

### CorrectionDiff

Represents a single text modification.

```swift
public struct CorrectionDiff: Sendable, Equatable {
    public let start: Int           // Where the replacement begins
    public let end: Int             // Where the original text ends
    public let text: String         // Replacement text
    public let stage: CorrectionStage
    public let confidence: Float    // 0.0–1.0
}
```

### CorrectionStage

```swift
public enum CorrectionStage: String, Sendable, CaseIterable {
    case noise      // Typos, transpositions
    case context    // Grammar, coherence
    case tone       // Style adjustment
}
```

### ToneTarget

```swift
public enum ToneTarget: String, Sendable {
    case none           // No tone adjustment
    case casual         // Relaxed, conversational
    case professional   // Formal, polished
}
```

---

## Key Protocols

### LMAdapter

The abstraction for language model interaction.

```swift
public protocol LMAdapter: Actor {
    func initialize(config: LMConfiguration) async throws
    func generate(prompt: String, maxTokens: Int) async throws -> String
    var isReady: Bool { get }
    var status: LMStatus { get }
}
```

**Implementations:**
- `MockLMAdapter` — Pattern-matching for testing/demo
- `LlamaLMAdapter` — llama.cpp CLI integration (production)

---

## Pipeline API

### CorrectionPipeline

The main entry point for text correction.

```swift
public actor CorrectionPipeline {
    /// Run a complete correction wave
    public func runCorrectionWave(
        text: String,
        caret: Int,
        toneTarget: ToneTarget? = nil
    ) async throws -> CorrectionWaveResult
}
```

### Usage Example

```swift
// Initialize with LLM
let adapter = LlamaLMAdapter()
try await adapter.initialize(config: LMConfiguration(
    modelPath: "/path/to/model.gguf"
))

let pipeline = CorrectionPipeline(lmAdapter: adapter)

// Run correction
let result = try await pipeline.runCorrectionWave(
    text: "I was writting a lettr",
    caret: 22  // End of text
)

// Apply diffs
for diff in result.diffs {
    print("[\(diff.stage)] \(diff.start):\(diff.end) → \"\(diff.text)\"")
}
```

---

## Caret Safety

All corrections must pass safety validation:

```swift
public func isCaretSafe(region: TextRegion, caret: Int) -> Bool {
    region.end <= caret && region.start < region.end
}
```

**Invariants:**
1. `diff.end <= caret` — Never modify at/after cursor
2. `diff.start < diff.end` — Region must be non-empty
3. `diff.start >= 0` — No negative indices

---

## Configuration

### PipelineConfiguration

```swift
public struct PipelineConfiguration: Sendable {
    public let toneTarget: ToneTarget       // Default: .none
    public let confidenceThreshold: Float   // Default: 0.80
    
    public static var `default`: PipelineConfiguration
}
```

### ActiveRegionPolicy

```swift
public struct ActiveRegionPolicy: Sendable {
    public let maxWords: Int        // Default: 20
    public let sentenceBoundary: Bool
    
    public static var `default`: ActiveRegionPolicy { ... }
}
```

### LMConfiguration

```swift
public struct LMConfiguration: Sendable {
    public let modelPath: String
    public let maxTokens: Int       // Default: 64
    public let temperature: Float   // Default: 0.1
    public let contextSize: Int     // Default: 2048
    public let gpuLayers: Int       // Default: -1 (all)
}
```

---

## Build & Run

### Prerequisites

```bash
# Install llama.cpp (provides llama-cli)
brew install llama.cpp

# Verify installation
llama-cli --version
```

### Download Model

```bash
mkdir -p apple/Models
curl -L -o apple/Models/qwen2.5-0.5b-instruct-q4_k_m.gguf \
  "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf"
```

### Build & Test

```bash
cd apple/MindType

# Build
swift build

# Test
swift test

# Run demo
swift run MindTypeDemo
```

### Xcode Integration

```bash
# Ensure Xcode toolchain is active
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer

# Open package in Xcode
open Package.swift
```

---

## File Structure

```
apple/MindType/
├── Package.swift
├── Sources/
│   ├── MindTypeCore/
│   │   ├── Types.swift              # Data structures
│   │   ├── CorrectionPipeline.swift # Main pipeline
│   │   ├── CaretSafety.swift        # Safety validation
│   │   ├── LMAdapter.swift          # Protocol + MockLMAdapter
│   │   ├── LlamaLMAdapter.swift     # llama.cpp integration
│   │   └── Errors.swift             # Error types
│   ├── MindTypeUI/
│   │   ├── CorrectionMarker.swift   # Visual indicator
│   │   └── StatusIndicator.swift    # State display
│   └── MindTypeDemo/
│       └── main.swift               # CLI demo
└── Tests/
    └── MindTypeCoreTests/
        ├── CaretSafetyTests.swift
        ├── CorrectionPipelineTests.swift
        └── TypesTests.swift
```

---

## Python Demos (MLX)

For rapid prototyping and Apple Silicon optimization, MindType includes Python demos using MLX.

### Demo Scripts

```bash
# ENTER mode - type, press Enter, see interpretation
python3 tools/mindtype_mlx.py

# Real-time mode - interpretations happen as you pause
python3 tools/mindtype_realtime.py
```

### Core Engine (`tools/mindtype_core.py`)

The Python core implements the fuzzy typing interpreter:

```python
from tools.mindtype_core import CorrectionEngine, MindTypeConfig

config = MindTypeConfig(
    min_words=3,           # Minimum words before interpreting
    length_ratio_max=1.8,  # Output can be up to 1.8x input length
    length_ratio_min=0.5,  # Output must be at least 0.5x input
    sentence_tolerance=1,  # Allow ±1 sentence difference
    enable_self_review=True,  # LLM validates its own output
    pause_ms=600,          # Pause before auto-correct (realtime)
)

engine = CorrectionEngine(config)
engine.load_model()

result = engine.correct("once iualpio a time tbere weas a prince")
print(result.text)  # "Once upon a time there was a prince"
```

### Configuration Presets

| Preset | Use Case |
|--------|----------|
| `STRICT_CONFIG` | More validation, less hallucination risk |
| `BALANCED_CONFIG` | Default settings |
| `LENIENT_CONFIG` | Trust LLM more, faster |

### Validation Strategy

The engine validates interpretations structurally (not lexically):

1. **Reject conversational responses** — "I'm not sure...", "Can you..."
2. **Check length ratio** — Output must be 0.5x–1.8x input length
3. **Check sentence count** — Must match within tolerance (±1)
4. **Check for garbled output** — Rejects if output still looks garbled

**Why no word matching?** With fuzzy typing, input words are garbled (`"msaasexd"`) and don't match output words (`"masses"`). We trust the LLM for word-level interpretation and validate structure only.

---

## Prompt Engineering

The LM receives ChatML-formatted prompts for **interpretation** (not correction):

```xml
<|im_start|>system
You interpret garbled/fuzzy typing into what the user intended to write.

The user types VERY fast, so:
- Letters may be transposed (teh → the)
- Letters may be missing (bcause → because)
- Keys may be adjacent wrong keys (wprds → words)
- Words may be run together (onceupon → once upon)
- Words may be split (cre ate → create)
- Words may be completely garbled but sound similar

Your job: Figure out what they MEANT to type.

RULES:
1. Output the interpreted text, nothing else
2. Keep the same meaning and intent
3. Keep roughly the same structure (sentence count)
4. Fix ALL the typing errors
5. Do NOT add new ideas or change the topic
<|im_end|>
<|im_start|>user
once iualpio a time tbere weas a prince tgbhat wanted to crezt e
<|im_end|>
<|im_start|>assistant
```

**Expected response:**
```
Once upon a time there was a prince who wanted to create
```

---

## Performance Targets

| Metric | Target | Current |
|--------|--------|---------|
| Correction wave latency | <2000ms | ~1200ms |
| Memory (idle) | <100MB | ~50MB |
| Memory (processing) | <500MB | ~400MB |
| GPU utilization | >80% | ~90% (Metal) |
| Generation timeout | — | 30s |

---

## Implementation Status

**Legend:** ✅ Complete | 🔧 Partial | 📋 Planned

### Core Pipeline
| Component | Status | Notes |
|-----------|--------|-------|
| Three-stage pipeline (Noise/Context/Tone) | ✅ | Working with real LLM |
| Caret safety validation | ✅ | Enforced at all stages |
| Active region computation | ✅ | Word-boundary aware |
| Diff application | ✅ | With length adjustment |
| MockLMAdapter | ✅ | Pattern-matching for dev |
| LlamaLMAdapter | ✅ | llama-cli with timeout |
| Model discovery | ✅ | Multi-path search |

### User Experience
| Component | Status | Notes |
|-----------|--------|-------|
| Burst-Pause-Correct timing | 📋 | Documented, not implemented |
| Correction Marker animation | 🔧 | Scaffold only |
| Typing monitor | 📋 | Needs Accessibility API |
| System-wide integration | 📋 | Needs InputMethodKit |

### Reliability
| Component | Status | Notes |
|-----------|--------|-------|
| Process timeout | ✅ | 30s default |
| Graceful degradation | ✅ | Mock fallback |
| Cancellation support | 📋 | Task-based |
| Structured logging | 📋 | Needs os.log |

### Testing
| Component | Status | Notes |
|-----------|--------|-------|
| CaretSafety tests | ✅ | Comprehensive |
| Pipeline tests | 📋 | Priority for v1.1 |
| Integration tests | 📋 | Priority for v1.1 |

---

## Error Handling

```swift
public enum MindTypeError: Error, Sendable {
    case modelLoadFailed(String)
    case modelNotLoaded
    case generationFailed(String)
    case invalidRegion(String)
    case caretSafetyViolation(String)
}
```

---

## Next Steps (v1.1)

- [ ] Direct llama.cpp C library integration (remove CLI wrapper)
- [ ] Accessibility API integration for system-wide corrections
- [ ] Menu bar app with real-time status
- [ ] Test coverage to 80%+

---

*For product vision and design principles, see [CORE.md](CORE.md).*

<!-- DOC META: VERSION=0.9.1 | UPDATED=2025-11-27 -->

