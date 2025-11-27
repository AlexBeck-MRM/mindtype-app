<!--══════════════════════════════════════════════════════════════════════════
  ╔═══════════════════════════════════════════════════════════════════════════╗
  ║  M I N D ⠶ T Y P E   I M P L E M E N T A T I O N                          ║
  ║                                                                           ║
  ║  Technical Architecture · Model Training · Pipeline Design                 ║
  ╚═══════════════════════════════════════════════════════════════════════════╝
-->

# MindType Implementation Guide

This document explains the technical architecture, model training methodology, and the clever engineering decisions that make Mind⠶Type fast and accurate.

---

## Overview

Mind⠶Type is a fuzzy typing interpreter built on:

| Component | Technology | Purpose |
|-----------|------------|---------|
| **Model** | MindFlow Qwen 3B | Fine-tuned LLM for typo interpretation |
| **Framework** | MLX | Apple Silicon-native ML inference |
| **Training** | LoRA | Efficient fine-tuning (6.6M params / 3B total) |
| **App** | Swift + SwiftUI | Native macOS app (future) |
| **Demo** | Python | Rapid prototyping and testing |

---

## The MindFlow Qwen Model

### Why Custom Training?

Base language models (GPT, Claude, Qwen) are trained to be helpful assistants. When you give them garbled text:

```
User: "th wthtr hs bn rly nce ltly"
Base Qwen: "It seems like you're trying to say 'the weather has been really nice 
            lately.' Is there something specific you'd like to discuss about the 
            weather?"
```

This is wrong for our use case. We need:
```
User: "th wthtr hs bn rly nce ltly"
MindFlow: "The weather has been really nice lately"
```

Just the corrected text. No conversation. No explanations.

### Model Versions

| Version | Training Data | Characteristics |
|---------|--------------|-----------------|
| **v2** (default) | 2000 samples, 43 handcrafted context examples | Literal interpretation, 100% accuracy on test suite |
| **v3** | 4000 samples, human typing pattern simulation | More creative, may paraphrase (75% exact match) |

**v2 is recommended** because it does what you asked—fixes typos without adding its own interpretation.

---

## Training Data Generation

The training data generator (`tools/generate_fuzzy_training.py`) creates realistic typing errors based on human typing research.

### Error Types (Based on Typing Research)

#### 1. Muscle Memory Errors
Common words get typed so fast they blur:
```python
MUSCLE_MEMORY_ERRORS = {
    'the': ['teh', 'hte', 'th', 'thw'],
    'that': ['taht', 'tath', 'htat'],
    'just': ['jsut', 'juts', 'ujst'],
    'because': ['becuase', 'becasue', 'beacuse'],
    ...
}
```

#### 2. Same-Finger Sequences
Letters typed by the same finger are slow and error-prone:
```python
SAME_FINGER_PAIRS = {
    'e': 'd', 'd': 'e',  # Left middle finger
    'r': 'f', 'f': 'r',  # Left index
    'u': 'j', 'j': 'u',  # Right index
    ...
}
```
When you type "ed" quickly, you might get "de" or just "e".

#### 3. Adjacent Key Errors
QWERTY proximity causes substitutions:
```python
# 'e' is next to 'w', 'r', 'd', 's'
# So "the" might become "thw" or "thr"
```

#### 4. Vowel Dropping
Speed typing often drops vowels:
```
"please review the report before tomorrow"
→ "plse rvw th rprt bfre tmrrw"
```

#### 5. Hand Shift Errors
Entire hand shifts one key position:
```
"the" → "yhr" (hand shifted right)
"algorithm" → "slgptithm" (hand shifted left)
```

#### 6. Rhythm Errors
Double letters go wrong:
```
"coming" → "commming" (extra tap)
"really" → "realy" (missing double)
```

### Context-Dependent Examples

The key innovation: **handcrafted examples showing how the same garbled word has different meanings in context**:

```python
HANDCRAFTED_EXAMPLES = [
    # "msses" means different things based on context
    ("the msses were amzd by the prfrmance on stage", 
     "The masses were amazed by the performance on stage"),
    
    ("she msses her fmly when shes away frm home", 
     "She misses her family when she's away from home"),
    
    ("he mde a lot of msses while lrning to cook", 
     "He made a lot of messes while learning to cook"),
    ...
]
```

This teaches the model that `"msses"` isn't a fixed mapping—it depends on the surrounding words.

### Corruption Levels

```python
LIGHT   = CorruptionLevel("light",   1, 0.2)   # 20% of words, light errors
MEDIUM  = CorruptionLevel("medium",  2, 0.35)  # 40% of words, medium errors
HEAVY   = CorruptionLevel("heavy",   3, 0.5)   # 60% of words, heavy errors
EXTREME = CorruptionLevel("extreme", 4, 0.7)   # 80% of words, heavy errors
```

Dataset composition:
- 13.5% light (easy cases)
- 31.5% medium (typical typing)
- 31.5% heavy (fast typing)
- 13.5% extreme (velocity mode)
- 9% clean (prevent over-correction)
- 1% handcrafted (context disambiguation)

---

## The Correction Engine

The `CorrectionEngine` class (`tools/mindtype_core.py`) implements a multi-pass validation system.

### Pass 1: Generate Interpretation

```python
def _interpret(self, text: str) -> str:
    """Call the LLM to interpret garbled text."""
    prompt = f"""<|im_start|>system
Fix typos in the text. Return only the corrected text.<|im_end|>
<|im_start|>user
{text}<|im_end|>
<|im_start|>assistant
"""
    return generate(self.model, self.tokenizer, prompt=prompt)
```

### Pass 2: Self-Review (Optional)

The model reviews its own output:

```python
def _review(self, original: str, interpretation: str) -> bool:
    """Ask the model: is this interpretation reasonable?"""
    prompt = f"""Original: {original}
Interpretation: {interpretation}
Is this a reasonable interpretation?"""
    response = self._generate("Answer ONLY with REASONABLE or UNREASONABLE.", prompt)
    return "UNREASONABLE" not in response.upper()
```

### Pass 3: Structural Validation

Even if the LLM says it's reasonable, we apply hard structural checks:

```python
def validate_interpretation(input_text, output_text, config):
    # Check 1: Not a conversational response
    for pattern in REJECTION_PATTERNS:
        if re.search(pattern, output_lower):
            return ValidationResult(False, 0.0, "conversational response")
    
    # Check 2: Length ratio
    ratio = len(output) / len(input)
    if ratio > 1.8 or ratio < 0.5:
        return ValidationResult(False, 0.0, "length mismatch")
    
    # Check 3: Sentence count preserved
    if abs(count_sentences(output) - count_sentences(input)) > 1:
        return ValidationResult(False, 0.0, "structure changed")
    
    # Check 4: Not still garbled
    non_words = len(re.findall(r'\b[bcdfghjklmnpqrstvwxz]{4,}\b', output))
    if non_words > 2:
        return ValidationResult(False, 0.0, "output still garbled")
    
    return ValidationResult(True, confidence, "valid")
```

### Why This Works

1. **LLM handles interpretation** — It's good at understanding what garbled text means
2. **Structural checks prevent hallucination** — Can't add sentences or change length dramatically
3. **Rejection patterns catch chat mode** — If the model starts explaining, we reject
4. **Fail-safe** — On any doubt, return the original text unchanged

---

## MLX and Apple Silicon Optimization

Mind⠶Type uses [MLX](https://github.com/ml-explore/mlx), Apple's machine learning framework optimized for Apple Silicon.

### Why MLX over PyTorch/llama.cpp?

| Aspect | MLX | PyTorch | llama.cpp |
|--------|-----|---------|-----------|
| Apple Silicon | Native | MPS backend | Metal |
| Memory | Unified memory | CPU/GPU copies | Efficient |
| LoRA Training | Built-in | Needs libraries | Not supported |
| Model Format | Safetensors | Various | GGUF |
| Setup | `pip install mlx` | Complex | brew install |

MLX gives us:
- **Zero-copy memory** — Model weights live in unified memory, no CPU↔GPU transfers
- **Lazy evaluation** — Computations only run when needed
- **Built-in LoRA** — Fine-tuning with `python3 -m mlx_lm lora`

### LoRA Fine-Tuning

We don't retrain the entire 3B parameter model. LoRA (Low-Rank Adaptation) adds small trainable matrices:

```
Base model: 3,085,939,000 parameters (frozen)
LoRA adapters: 6,652,000 parameters (trained)
Trainable: 0.216%
```

This means:
- **Fast training** — 5 minutes on M1 Max
- **Small adapters** — ~25MB instead of 6GB
- **Preserved base knowledge** — Model still understands language

Training command:
```bash
python3 -m mlx_lm lora \
    --model Qwen/Qwen2.5-3B-Instruct \
    --train \
    --data tools/mlx_data \
    --batch-size 2 \
    --num-layers 16 \        # How many layers to adapt
    --learning-rate 1e-5 \   # Conservative learning rate
    --iters 300 \            # Training iterations
    --adapter-path adapters
```

After training, fuse adapters into the base model:
```bash
python3 -m mlx_lm fuse \
    --model Qwen/Qwen2.5-3B-Instruct \
    --adapter-path adapters \
    --save-path apple/Models/mindflow-qwen-3b
```

---

## Real-Time Input Handling

The real-time demo (`tools/mindtype_realtime.py`) implements non-blocking keyboard input with state machine logic.

### State Machine

```
IDLE → TYPING → PAUSED → CORRECTING → IDLE
  ↑       ↓        ↓         |
  └───────┴────────┴─────────┘
          (on keystroke)
```

- **IDLE** — Waiting for input
- **TYPING** — User is actively typing (reset timer on each key)
- **PAUSED** — No keystroke for 500ms, about to interpret
- **CORRECTING** — LLM is running

### Terminal Raw Mode

To capture keystrokes without waiting for Enter:

```python
import termios, tty, sys

def enable_raw_mode():
    fd = sys.stdin.fileno()
    old_settings = termios.tcgetattr(fd)
    tty.setraw(fd)
    return old_settings

def disable_raw_mode(old_settings):
    termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, old_settings)
```

**Critical:** Always restore terminal settings on exit, including crashes:
```python
import atexit, signal

atexit.register(disable_raw_mode, old_settings)
signal.signal(signal.SIGINT, cleanup_handler)
signal.signal(signal.SIGTERM, cleanup_handler)
```

### Braille Activity Symbols

Visual feedback without cluttering the screen:

```python
SYMBOLS = {
    'idle':      '⠶',  # Dots: waiting
    'typing':    '⠷',  # More dots: active
    'paused':    '⠾',  # Pattern: about to act
    'thinking':  '⠿',  # Full: processing
    'success':   '✓',  # Check: done
    'waiting':   '⠴',  # Partial: ready
}
```

---

## Configuration Options

### MindTypeConfig

```python
@dataclass
class MindTypeConfig:
    # Model path (auto-detected if None)
    model_path: Path = None
    
    # Minimum input thresholds
    min_words: int = 3          # Don't process < 3 words
    min_chars: int = 10         # Don't process < 10 chars
    
    # Validation thresholds
    length_ratio_max: float = 1.8   # Output can't be 1.8x longer
    length_ratio_min: float = 0.5   # Output can't be 0.5x shorter
    sentence_tolerance: int = 1     # Allow ±1 sentence difference
    
    # Real-time mode
    pause_ms: int = 500         # Wait before interpreting
    
    # Behavior
    enable_self_review: bool = True
    return_original_on_failure: bool = True
    show_confidence: bool = False
```

### Presets

```python
STRICT_CONFIG = MindTypeConfig(
    length_ratio_max=1.3,
    length_ratio_min=0.7,
    enable_self_review=True,
)

LENIENT_CONFIG = MindTypeConfig(
    length_ratio_max=2.0,
    length_ratio_min=0.4,
    enable_self_review=False,
)
```

---

## File Reference

### Python Tools (`tools/`)

| File | Purpose | Key Functions |
|------|---------|---------------|
| `mindtype_core.py` | Shared engine | `CorrectionEngine`, `MindTypeConfig`, `validate_interpretation` |
| `mindtype_mlx.py` | ENTER mode demo | Interactive CLI |
| `mindtype_realtime.py` | Real-time demo | State machine, raw terminal input |
| `generate_fuzzy_training.py` | Training data | `corrupt_word`, `HANDCRAFTED_EXAMPLES` |
| `evaluate_model.py` | Model evaluation | `evaluate_model`, test suite |
| `train_mlx_simple.py` | LoRA training | MLX lora wrapper |
| `train_fuzzy.sh` | Training workflow | End-to-end training script |

### Swift Core (`apple/MindType/Sources/MindTypeCore/`)

| File | Purpose |
|------|---------|
| `Types.swift` | Core types: `TextRegion`, `CorrectionDiff`, `CorrectionStage` |
| `CorrectionPipeline.swift` | Three-stage correction orchestration |
| `ActiveRegion.swift` | Compute region before caret |
| `CaretSafety.swift` | Ensure corrections don't pass caret |
| `LlamaLMAdapter.swift` | llama.cpp CLI integration |

### Models (`apple/Models/`)

| Directory | Description |
|-----------|-------------|
| `mindflow-qwen-3b-v2/` | Default model, literal interpretation |
| `mindflow-qwen-3b-v3/` | Alternative, more creative |

---

## Performance Characteristics

| Operation | Typical Time | Notes |
|-----------|--------------|-------|
| Model load | ~3s | First inference only |
| Interpretation | 200-800ms | Depends on input length |
| Validation | <1ms | Pure Python checks |
| Full pipeline | 300-1000ms | Including all passes |

Memory usage:
- Model loaded: ~6GB unified memory
- Per-inference: Negligible additional

---

## Extending the System

### Adding New Error Patterns

Edit `tools/generate_fuzzy_training.py`:

```python
# Add to MUSCLE_MEMORY_ERRORS
MUSCLE_MEMORY_ERRORS['should'] = ['shoudl', 'shuold', 'shold']

# Add new corruption function
def corrupt_my_pattern(word: str) -> str:
    # Your logic here
    return corrupted_word

# Add to operation weights in corrupt_word()
operations = [
    (corrupt_my_pattern, 0.15),  # 15% weight
    ...
]
```

### Custom Validation Rules

Edit `tools/mindtype_core.py`:

```python
def validate_interpretation(input_text, output_text, config):
    # Add your custom check
    if my_custom_check_fails(output_text):
        return ValidationResult(False, 0.0, "my check failed")
    
    # Continue with other checks...
```

### Training with Different Base Models

```bash
# Use a different base model
python3 -m mlx_lm lora \
    --model mistralai/Mistral-7B-Instruct-v0.2 \  # Different model
    --train \
    --data tools/mlx_data \
    ...
```

---

## Troubleshooting

### Model not loading

```bash
# Check model exists
ls -la apple/Models/

# Verify with direct MLX test
python3 -c "from mlx_lm import load; load('apple/Models/mindflow-qwen-3b-v2')"
```

### Terminal corrupted after crash

```bash
reset
# or
stty sane
```

### Output is conversational

The model may have reverted to chat mode. Retrain with stricter prompts or use v2.

### Interpretation too slow

- Use smaller model (1.5B instead of 3B)
- Reduce max_tokens in generation
- Check for thermal throttling on laptop

---

*Mind⠶Type: where context makes garbled text clear.*
