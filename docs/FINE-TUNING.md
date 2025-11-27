# MindFlow Model Fine-Tuning Guide

This guide explains how to fine-tune MindFlow Qwen models for fuzzy typing interpretation.

---

## Overview

MindFlow models are fine-tuned Qwen 3B models optimized to:

1. **Interpret garbled input** — Decode velocity typing and typos
2. **Use context** — `"msses"` → "masses" (performance) or "misses" (family)
3. **Preserve structure** — Same sentence count in, same sentence count out
4. **Never converse** — Return only corrected text, no explanations

---

## Quick Start

```bash
# 1. Generate training data
python3 tools/generate_fuzzy_training.py --samples 4000 --seed 42

# 2. Train (LoRA fine-tuning via MLX)
bash tools/train_fuzzy.sh

# 3. Evaluate
python3 tools/evaluate_model.py
```

---

## Training Data Generation

The generator (`tools/generate_fuzzy_training.py`) creates realistic typing errors based on human typing research.

### Error Types

| Type | Example | Cause |
|------|---------|-------|
| **Muscle memory** | `teh` → "the" | Words typed so fast they blur |
| **Same-finger** | `ed` → "de" | Letters on same finger are slow |
| **Adjacent key** | `thw` → "the" | QWERTY proximity |
| **Vowel dropping** | `plse` → "please" | Speed typing skips vowels |
| **Hand shift** | `yhr` → "the" | Hand shifted one key |
| **Rhythm errors** | `commming` → "coming" | Double-tap timing |

### Context-Dependent Examples

The key innovation: handcrafted examples showing the same garbled word with different meanings:

```
"the msses were amzd by the prfrmance" → "masses" (audience context)
"she msses her fmly when shes away"    → "misses" (family context)
"he mde a lot of msses while lrning"   → "messes" (cooking context)
```

### Dataset Composition

```
13.5% light    — Easy corrections (single typos)
31.5% medium   — Typical typing errors
31.5% heavy    — Fast typing errors
13.5% extreme  — Velocity mode (very garbled)
9.0%  clean    — No corruption (prevent over-correction)
1.0%  handcrafted — Context disambiguation examples
```

### Generating Custom Data

```bash
# Default: 2000 samples
python3 tools/generate_fuzzy_training.py

# More samples
python3 tools/generate_fuzzy_training.py --samples 4000 --seed 123

# Output is saved to tools/mlx_data/train.jsonl and valid.jsonl
```

---

## Training with MLX

We use MLX's built-in LoRA training, optimized for Apple Silicon.

### Why LoRA?

Instead of retraining all 3 billion parameters:

```
Base model: 3,085,939,000 parameters (frozen)
LoRA adapters: 6,652,000 parameters (trained)
Trainable: 0.216%
```

Benefits:
- **Fast** — 5 minutes on M1 Max
- **Small** — ~25MB adapters vs 6GB model
- **Safe** — Base knowledge preserved

### Training Command

```bash
python3 -m mlx_lm lora \
    --model Qwen/Qwen2.5-3B-Instruct \
    --train \
    --data tools/mlx_data \
    --batch-size 2 \
    --num-layers 16 \
    --learning-rate 1e-5 \
    --iters 300 \
    --save-every 100 \
    --adapter-path apple/Models/mindflow-qwen-3b-v4-adapters
```

### Training Parameters

| Parameter | Value | Effect |
|-----------|-------|--------|
| `--batch-size` | 2 | Fits in ~8GB memory |
| `--num-layers` | 16 | How many layers to adapt |
| `--learning-rate` | 1e-5 | Conservative to avoid forgetting |
| `--iters` | 300 | ~5 min training |

### Fusing Adapters

After training, merge adapters into the base model:

```bash
python3 -m mlx_lm fuse \
    --model Qwen/Qwen2.5-3B-Instruct \
    --adapter-path apple/Models/mindflow-qwen-3b-v4-adapters \
    --save-path apple/Models/mindflow-qwen-3b-v4
```

---

## Evaluation

### Run Evaluation

```bash
python3 tools/evaluate_model.py --model apple/Models/mindflow-qwen-3b-v2
```

### Metrics

| Metric | Meaning |
|--------|---------|
| **Similarity** | Character-level similarity (Levenshtein) |
| **Exact Match** | Output exactly matches expected |
| **Latency** | Time per interpretation |

### Test Cases

The evaluation script tests:

1. **Muscle memory** — `teh`, `jsut`, `taht`
2. **Vowel dropping** — `th wthtr hs bn rly nce`
3. **Hand shift** — `yhr` → "the"
4. **Context-dependent** — `msses` in different contexts

### Comparing Versions

```bash
# Evaluate v2
python3 tools/evaluate_model.py --model apple/Models/mindflow-qwen-3b-v2

# Evaluate v3
python3 tools/evaluate_model.py --model apple/Models/mindflow-qwen-3b-v3
```

---

## Model Versions

| Version | Training | Best For | Accuracy |
|---------|----------|----------|----------|
| **v2** (default) | 2000 samples, context-aware | Literal interpretation | 100% |
| **v3** | 4000 samples, human patterns | More creative | 75% |

**Recommendation:** Use v2 for most cases. It fixes typos without changing meaning.

---

## Automated Training Workflow

The `train_fuzzy.sh` script handles the full workflow:

```bash
bash tools/train_fuzzy.sh
```

Steps:
1. Evaluate current model (baseline)
2. Generate training data
3. Train LoRA adapters
4. Fuse into final model
5. Evaluate new model
6. Compare results

### Configuring train_fuzzy.sh

Edit the config section:

```bash
VERSION="v4"      # Change for each new training run
SAMPLES=2000      # Training samples
ITERS=250         # Training iterations
```

---

## Troubleshooting

### Model outputs are conversational

The model is reverting to chat mode. Signs:
- "It seems like you're trying to say..."
- Adding explanatory text
- Asking questions

**Fix:** Retrain with stricter prompts or use v2.

### Output is worse than input

Possible causes:
- Learning rate too high (try 5e-6)
- Too many iterations (try 150)
- Bad training data

**Fix:** Check training data quality, reduce training.

### Out of memory

**Fix:** Reduce batch size to 1:

```bash
python3 -m mlx_lm lora --batch-size 1 ...
```

### Terminal corrupted after demo crash

```bash
reset
# or
stty sane
```

---

## Adding New Training Examples

### Handcrafted Examples

Edit `tools/generate_fuzzy_training.py`, find `HANDCRAFTED_EXAMPLES`:

```python
HANDCRAFTED_EXAMPLES = [
    # Add your examples
    ("your garbled input here", "The expected clean output here"),
]
```

### New Error Patterns

Add new corruption functions:

```python
def corrupt_my_pattern(word: str) -> str:
    """My custom corruption pattern."""
    # Your logic here
    return corrupted

# Add to operation weights in corrupt_word()
operations = [
    (corrupt_my_pattern, 0.1),  # 10% chance
    ...
]
```

---

## Using Your Model

### Update Default Path

Edit `tools/mindtype_core.py`:

```python
MODEL_PATHS = [
    project_root / "apple" / "Models" / "mindflow-qwen-3b-v4",  # Your new model
    project_root / "apple" / "Models" / "mindflow-qwen-3b-v2",  # Fallback
]
```

### Test Interactively

```bash
python3 tools/mindtype_mlx.py
```

---

## Resources

- [MLX Documentation](https://ml-explore.github.io/mlx/)
- [MLX-LM GitHub](https://github.com/ml-explore/mlx-examples/tree/main/llms/mlx_lm)
- [LoRA Paper](https://arxiv.org/abs/2106.09685)
- [Qwen Model Card](https://huggingface.co/Qwen/Qwen2.5-3B-Instruct)

---

*Last updated: November 2025*
