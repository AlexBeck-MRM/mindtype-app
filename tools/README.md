# MindFlow Tools

Python tools for training and testing the MindFlow Qwen fuzzy typing interpreter.

## Quick Start

```bash
# Interactive demo (press ENTER to interpret)
python3 tools/mindtype_mlx.py

# Real-time demo (auto-interprets after pause)
python3 tools/mindtype_realtime.py
```

## Files

| File | Purpose |
|------|---------|
| `mindtype_core.py` | Shared engine: model loading, validation, correction |
| `mindtype_mlx.py` | Interactive ENTER-mode demo |
| `mindtype_realtime.py` | Real-time auto-correction demo |
| `generate_fuzzy_training.py` | Generate synthetic training data |
| `evaluate_model.py` | Evaluate model accuracy on test cases |
| `train_mlx_simple.py` | LoRA fine-tuning with MLX |
| `train_fuzzy.sh` | Full training workflow script |

## Model Versions

Models live in `apple/Models/`:

- **mindflow-qwen-3b-v2** — Context-aware, literal interpretation (default)

## Training New Models

```bash
# 1. Generate training data
python3 tools/generate_fuzzy_training.py --samples 4000

# 2. Run training
bash tools/train_fuzzy.sh

# 3. Evaluate
python3 tools/evaluate_model.py
```

## Configuration

Edit `mindtype_core.py` → `MindTypeConfig` for:

- `min_words` / `min_chars` — Minimum input size
- `similarity_threshold` — Validation strictness
- `pause_ms` — Real-time mode pause duration
- `enable_self_review` — Two-pass verification
