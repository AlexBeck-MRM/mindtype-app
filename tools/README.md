# MindType Training Tools

Tools for generating training data and fine-tuning language models for MindType.

---

## Quick Start

```bash
cd tools/

# 1. Generate training data (9,700+ pairs)
python generate_training_data.py --samples 50 --intensity 0.7 \
    --output ../apple/Models/mindtype_training_data.jsonl

# 2. Convert to training format
python convert_to_training_format.py ../apple/Models/mindtype_training_data.jsonl \
    --format sharegpt --split 0.1 --output ../apple/Models/mindtype_train.json

# 3. Fine-tune
./finetune.sh
```

---

## Tools

| Script | Purpose |
|--------|---------|
| `generate_training_data.py` | Generate corrupted/clean text pairs |
| `download_corpus.py` | Download clean text from Wikipedia/Gutenberg |
| `convert_to_training_format.py` | Convert to ShareGPT/Alpaca/ChatML formats |
| `finetune.sh` | Interactive fine-tuning wizard |

---

## Training Data

Located in `../apple/Models/`:

| File | Description | Size |
|------|-------------|------|
| `mindtype_training_data.jsonl` | Raw input/output pairs | ~10K examples |
| `mindtype_train.json` | ShareGPT format (for Unsloth) | Training set |
| `mindtype_train_val.json` | ShareGPT validation set | 10% holdout |
| `mindtype_train.txt` | ChatML format (for llama.cpp) | Plain text |

---

## Error Types Generated

The training data includes these error types (matching real typing patterns):

```
duplicate:     30%  (helllo → hello)
transpose:     30%  (teh → the)
delete:        28%  (wrld → world)
abbreviation:  20%  (defdnt → defendant)
visual:        20%  (befinitely → definitely)
adjacent:      12%  (wprld → world)
misspelling:    5%  (definately → definitely)
```

---

## Fine-Tuning Options

### Option 1: Unsloth (Recommended)

```bash
pip install unsloth
python train_unsloth.py
```

- 2x faster training
- 70% less memory
- Works with CUDA or Apple MPS

### Option 2: MLX (Apple Silicon Native)

```bash
pip install mlx mlx-lm
python -m mlx_lm.lora --model Qwen/Qwen2.5-1.5B-Instruct --train --data train.jsonl
```

### Option 3: llama.cpp

```bash
brew install llama.cpp
llama-finetune --model-base model.gguf --train-data train.txt --lora-out lora.gguf
```

---

## After Fine-Tuning

1. Copy the output GGUF to `../apple/Models/`
2. Name it `mindtype-finetuned-q4_k_m.gguf`
3. MindType will automatically prefer it over base models

---

See `../docs/FINE-TUNING.md` for detailed instructions.

