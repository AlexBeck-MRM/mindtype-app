# Mind⠶Type

**v0.9.1** — Fuzzy typing interpreter with custom-trained on-device LLM

---

## What is Mind⠶Type?

Mind⠶Type is a **fuzzy typing interpreter** that understands what you *meant* to type, not just what you typed. Unlike autocorrect (which matches dictionary words), Mind⠶Type uses a **custom-trained language model** to interpret your intent from full sentence context—even when your typing is completely garbled.

| What it does | Example |
|--------------|---------|
| **Interprets garbled words** | `iualpio` → "upon" |
| **Context-dependent decoding** | `msses` → "masses" (performance) or "misses" (family) |
| **Handles extreme velocity** | `th wthtr hs bn rly nce ltly` → "The weather has been really nice lately" |
| **Preserves intent** | Your meaning, not your keystrokes |

### This is NOT Autocorrect

| Autocorrect | Mind⠶Type |
|-------------|-----------|
| Dictionary lookup per word | LLM interprets full context |
| Fails on `msaasexd` | Decodes to "masses" from context |
| Per-word corrections | Whole-sentence understanding |
| "Did you mean...?" | Just knows |

---

## Quick Start

### Python Demo (Fastest)

```bash
# Install dependencies
pip install mlx mlx-lm

# Run ENTER mode demo
python3 tools/mindtype_mlx.py

# Run real-time demo (corrects as you type)
python3 tools/mindtype_realtime.py
```

### Demo Output

```
╔══════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   D E M O                                 ║
║                                                              ║
║  Type naturally. Press ENTER to interpret.                   ║
╚══════════════════════════════════════════════════════════════╝

Loading mindflow-qwen-3b-v2...

⠶ Type something (or 'quit' to exit):
> th wthtr hs bn rly nce ltly

⠿ Interpreting...
✓ The weather has been really nice lately

> once iualpio a time tbere weas a prince

⠿ Interpreting...
✓ Once upon a time there was a prince
```

---

## The Custom Model: MindFlow Qwen

Mind⠶Type uses **MindFlow Qwen**, a custom fine-tuned model optimized for fuzzy typing interpretation:

### Model Versions

| Model | Training | Best For | Accuracy |
|-------|----------|----------|----------|
| **mindflow-qwen-3b-v2** (default) | 2000 samples, context-aware | Literal interpretation | 100% on test suite |

### Why Custom Training?

Base Qwen models are trained for general chat. When given garbled text, they:
- Try to have a conversation
- Add explanatory text
- Hallucinate content

MindFlow Qwen is trained specifically to:
- **Only fix typos** — no conversation, no additions
- **Preserve structure** — same sentence count in = same out
- **Context-disambiguate** — `"msses"` becomes "masses" or "misses" based on surrounding words

### Training Methodology

The model is trained on **synthetically corrupted text** that mimics real human typing patterns:

```python
# Training data generation pipeline
1. Start with clean sentences → "The weather has been really nice lately"
2. Apply human typing error patterns:
   - Muscle memory errors (teh, jsut, taht, waht)
   - Same-finger sequences (ed, rf - slow combos)
   - Rhythm errors (commming, realy)
   - Vowel dropping (plse, rvw, th, rprt)
   - Hand shift errors (yhr → the)
   - Adjacent key errors (QWERTY proximity)
3. Output: "th wthtr hs bn rly nce ltly" → "The weather has been really nice lately"
```

**Key insight:** Context-dependent disambiguation examples teach the model that `"msses"` could be:
- "masses" when talking about a performance/audience
- "misses" when talking about family/emotion
- "messes" when talking about cooking/cleaning

---

## How It Works

### The Interpretation Pipeline

```
┌─────────────────────────────────────────────────────────────────┐
│ INPUT: "the msses were amzd by the prfrmance"                   │
├─────────────────────────────────────────────────────────────────┤
│ 1. INTERPRET (MindFlow Qwen LLM)                                │
│    ├─ Read full sentence context                                │
│    ├─ Phonetic reasoning: "amzd" sounds like "amazed"          │
│    ├─ Context reasoning: "performance" → audience context       │
│    └─ Output: "The masses were amazed by the performance"       │
├─────────────────────────────────────────────────────────────────┤
│ 2. VALIDATE (Structural Checks)                                 │
│    ├─ Same sentence count? ✓                                    │
│    ├─ Length ratio 0.5x–1.8x? ✓                                 │
│    └─ Not conversational? ✓                                     │
├─────────────────────────────────────────────────────────────────┤
│ 3. SELF-REVIEW (Optional)                                       │
│    └─ "Is this interpretation reasonable?" → REASONABLE         │
└─────────────────────────────────────────────────────────────────┘
│ OUTPUT: "The masses were amazed by the performance"             │
```

### Why Context Matters

The same garbled word can mean different things:

| Input | Context | Interpretation |
|-------|---------|----------------|
| `the msses were amzd by the prfrmance` | performance/stage | **masses** |
| `she msses her fmly when shes away` | family/emotion | **misses** |
| `he mde a lot of msses while lrning` | learning/cooking | **messes** |

Base autocorrect can't do this—it sees `msses` and guesses. Mind⠶Type reads the whole sentence.

---

## Core Principles

### 🔒 Private
100% on-device. No cloud. No data leaves your machine.

### ⚡ Fast
Metal-accelerated MLX inference on Apple Silicon. ~500ms per interpretation.

### 🎯 Caret-Safe
Never modifies text at or after your cursor. Corrections happen behind you.

### 🧠 Context-Aware
Full sentence understanding, not word-by-word matching.

---

## Project Structure

```
mindtype/
├── apple/                          # Apple-native implementation
│   ├── MindType/                   # Swift Package (macOS app)
│   │   ├── Sources/MindTypeCore/   # Core logic (Swift)
│   │   └── Tests/
│   ├── MindTypeApp/                # macOS menu bar app
│   └── Models/                     # Fine-tuned models live here
│       └── mindflow-qwen-3b-v2/    # Default model (literal interpretation)
│
├── tools/                          # Python tooling
│   ├── mindtype_core.py            # Shared engine + config
│   ├── mindtype_mlx.py             # ENTER mode demo
│   ├── mindtype_realtime.py        # Real-time demo
│   ├── generate_fuzzy_training.py  # Training data generator
│   ├── evaluate_model.py           # Model evaluation
│   ├── train_fuzzy.sh              # Training workflow
│   ├── train_mlx_simple.py         # LoRA fine-tuning
│   └── mlx_data/                   # Training data
│
├── docs/                           # Documentation
│   ├── CORE.md                     # Vision, scenarios, principles
│   ├── IMPLEMENTATION.md           # Technical deep-dive
│   └── ARCHITECTURE-MIGRATION.md   # Why Swift over Rust
│
└── README.md                       # This file
```

---

## Configuration

All tunable parameters are in `tools/mindtype_core.py`:

```python
@dataclass
class MindTypeConfig:
    # Minimum input requirements
    min_words: int = 3              # Need at least 3 words
    min_chars: int = 10             # Need at least 10 characters
    
    # Validation strictness
    similarity_threshold: float = 0.3     # Base similarity requirement
    length_ratio_max: float = 1.8         # Output can't be 1.8x longer
    length_ratio_min: float = 0.5         # Output can't be 0.5x shorter
    
    # Timing (real-time mode)
    pause_ms: int = 500             # Pause before interpretation
    
    # Model behavior
    enable_self_review: bool = True # Two-pass verification
    return_original_on_failure: bool = True
```

---

## Training Your Own Model

### Generate Training Data

```bash
# Generate 4000 samples with human typing patterns
python3 tools/generate_fuzzy_training.py --samples 4000 --seed 42
```

### Fine-Tune with MLX

```bash
# Full training workflow
bash tools/train_fuzzy.sh

# Or manually:
python3 -m mlx_lm lora \
    --model Qwen/Qwen2.5-3B-Instruct \
    --train \
    --data tools/mlx_data \
    --batch-size 2 \
    --num-layers 16 \
    --learning-rate 1e-5 \
    --iters 300 \
    --adapter-path apple/Models/my-adapters

# Fuse adapters into final model
python3 -m mlx_lm fuse \
    --model Qwen/Qwen2.5-3B-Instruct \
    --adapter-path apple/Models/my-adapters \
    --save-path apple/Models/my-model
```

### Evaluate

```bash
python3 tools/evaluate_model.py --model apple/Models/my-model
```

---

## Requirements

| Component | Requirement |
|-----------|-------------|
| macOS | 14.0+ (Sonoma) |
| Chip | Apple Silicon (M1/M2/M3/M4) |
| Python | 3.10+ |
| MLX | `pip install mlx mlx-lm` |
| Storage | ~6GB for 3B model |

---

## Commands

```bash
# Demo modes
python3 tools/mindtype_mlx.py          # ENTER mode
python3 tools/mindtype_realtime.py     # Real-time mode

# Evaluation
python3 tools/evaluate_model.py

# Training
python3 tools/generate_fuzzy_training.py --samples 4000
bash tools/train_fuzzy.sh
```

---

## Documentation

| Document | Description |
|----------|-------------|
| [docs/CORE.md](docs/CORE.md) | Vision, scenarios, principles |
| [docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md) | Technical architecture deep-dive |
| [docs/ARCHITECTURE-MIGRATION.md](docs/ARCHITECTURE-MIGRATION.md) | Why Swift over Rust |
| [tools/README.md](tools/README.md) | Python tools guide |

---

## License

MIT License — See [LICENSE](LICENSE) for details.

---

<p align="center">
  <strong>Mind⠶Type</strong><br>
  <em>Type at the speed of thought. Context makes it clear.</em>
</p>
