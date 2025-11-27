# MindType Model Fine-Tuning Guide

This guide explains how to fine-tune a language model specifically for MindType's typing intelligence capabilities.

---

## Overview

MindType requires a model that can:
1. **Interpret garbled input** → Decode speed-typing and typos
2. **Expand abbreviations** → "defdnt clamd" → "defendant claimed"
3. **Preserve meaning** → Don't change what the user meant to say
4. **Be fast** → Run on-device with low latency

Fine-tuning a base model on MindType-specific data dramatically improves accuracy.

---

## Quick Start

### Step 1: Generate Training Data

```bash
cd tools/

# Install dependencies
pip install requests beautifulsoup4 nltk

# Download corpus from Wikipedia (10,000 sentences)
python download_corpus.py --source wikipedia --sentences 10000 --output corpus.txt

# Generate training pairs with corruptions
python generate_training_data.py --input corpus.txt --samples 10 --output training_data.jsonl

# Check output
head -5 training_data.jsonl
```

### Step 2: Convert to Training Format

Create a script to convert JSONL to the format required by your training tool:

```python
#!/usr/bin/env python3
"""Convert MindType training data to chat format for fine-tuning."""

import json
import sys

def convert_to_chat_format(input_file, output_file):
    """Convert to ShareGPT/chat format."""
    conversations = []
    
    with open(input_file, 'r') as f:
        for line in f:
            data = json.loads(line)
            
            conversation = {
                "conversations": [
                    {
                        "from": "system",
                        "value": "You decode garbled typing into clear English. Return ONLY the corrected text."
                    },
                    {
                        "from": "human", 
                        "value": data["input"]
                    },
                    {
                        "from": "gpt",
                        "value": data["output"]
                    }
                ]
            }
            conversations.append(conversation)
    
    with open(output_file, 'w') as f:
        json.dump(conversations, f, indent=2)
    
    print(f"Converted {len(conversations)} examples to {output_file}")

if __name__ == "__main__":
    convert_to_chat_format(sys.argv[1], sys.argv[2])
```

Save as `convert_format.py` and run:
```bash
python convert_format.py training_data.jsonl training_chat.json
```

---

## Fine-Tuning Methods

### Option A: Using Unsloth (Recommended - Fastest)

[Unsloth](https://github.com/unslothai/unsloth) provides 2x faster fine-tuning with 70% less memory.

```bash
# Install
pip install unsloth

# Create training script
```

```python
# train_unsloth.py
from unsloth import FastLanguageModel
import torch

# Load base model
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name="unsloth/Qwen2.5-3B-Instruct-bnb-4bit",
    max_seq_length=2048,
    load_in_4bit=True,
)

# Add LoRA adapters
model = FastLanguageModel.get_peft_model(
    model,
    r=16,  # LoRA rank
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)

# Load your training data
from datasets import load_dataset
dataset = load_dataset("json", data_files="training_chat.json")

# Training
from trl import SFTTrainer
from transformers import TrainingArguments

trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset["train"],
    dataset_text_field="text",
    max_seq_length=2048,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=5,
        max_steps=100,  # Adjust based on dataset size
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=1,
        output_dir="mindtype_model",
    ),
)

trainer.train()

# Save LoRA adapter
model.save_pretrained("mindtype_lora")

# Merge and export to GGUF
model.save_pretrained_gguf("mindtype_gguf", tokenizer, quantization_method="q4_k_m")
```

### Option B: Using llama.cpp (CPU/Metal)

llama.cpp includes fine-tuning capabilities:

```bash
# Clone llama.cpp
git clone https://github.com/ggerganov/llama.cpp
cd llama.cpp

# Build with Metal support
make LLAMA_METAL=1

# Convert training data to llama.cpp format
python convert-hf-to-gguf.py /path/to/model --outfile model.gguf

# Fine-tune with LoRA
./finetune \
    --model-base model.gguf \
    --train-data training_data.txt \
    --lora-out mindtype_lora.gguf \
    --ctx 2048 \
    --batch 4 \
    --threads 8 \
    --epochs 3
```

### Option C: Using MLX (Apple Silicon Native)

For M1/M2/M3 Macs, MLX provides native performance:

```bash
# Install MLX
pip install mlx mlx-lm

# Fine-tune
python -m mlx_lm.lora \
    --model Qwen/Qwen2.5-3B-Instruct \
    --train \
    --data training_chat.json \
    --batch-size 4 \
    --lora-layers 16 \
    --iters 1000

# Convert to GGUF
python -m mlx_lm.convert --hf-path ./lora_fused_model -q
```

---

## Training Data Guidelines

### Recommended Dataset Size

| Use Case | Min Examples | Recommended | Training Time (M1) |
|----------|-------------|-------------|-------------------|
| Basic improvement | 1,000 | 5,000 | ~30 min |
| Good quality | 10,000 | 25,000 | ~2 hours |
| High quality | 50,000 | 100,000 | ~8 hours |

### Data Quality Checklist

- [ ] Diverse sentence types (academic, casual, legal, technical)
- [ ] Varying error intensities (light, medium, heavy)
- [ ] Include abbreviation expansions
- [ ] Include transpositions, deletions, insertions
- [ ] No duplicate input/output pairs
- [ ] Clean, grammatically correct outputs

### Error Distribution

Aim for this distribution in your training data:

```
transpose:     25%  (teh → the)
delete:        20%  (wrld → world)  
duplicate:     15%  (helllo → hello)
adjacent:      15%  (wprld → world)
abbreviation:  15%  (defdnt → defendant)
visual:        5%   (befinitely → definitely)
misspelling:   5%   (definately → definitely)
```

---

## Evaluation

### Test Set Creation

Reserve 10% of your data for evaluation:

```bash
# Split training data
head -n 9000 training_data.jsonl > train.jsonl
tail -n 1000 training_data.jsonl > test.jsonl
```

### Metrics to Track

1. **Exact Match Rate** - % of outputs exactly matching expected
2. **Word Error Rate (WER)** - Levenshtein distance at word level
3. **Character Error Rate (CER)** - Levenshtein distance at char level
4. **Intent Preservation** - Does output mean the same thing?

### Evaluation Script

```python
#!/usr/bin/env python3
"""Evaluate fine-tuned model on test set."""

import json
from difflib import SequenceMatcher

def word_error_rate(reference, hypothesis):
    """Calculate WER."""
    ref_words = reference.split()
    hyp_words = hypothesis.split()
    
    # Simple Levenshtein at word level
    matcher = SequenceMatcher(None, ref_words, hyp_words)
    return 1.0 - matcher.ratio()

def evaluate(test_file, model_outputs_file):
    """Evaluate model outputs against expected."""
    exact_matches = 0
    total_wer = 0
    count = 0
    
    with open(test_file) as tf, open(model_outputs_file) as mf:
        for test_line, model_line in zip(tf, mf):
            test = json.loads(test_line)
            model = json.loads(model_line)
            
            expected = test["output"]
            actual = model["output"]
            
            if expected.strip().lower() == actual.strip().lower():
                exact_matches += 1
            
            total_wer += word_error_rate(expected, actual)
            count += 1
    
    print(f"Exact Match Rate: {exact_matches/count*100:.1f}%")
    print(f"Average WER: {total_wer/count*100:.1f}%")

if __name__ == "__main__":
    import sys
    evaluate(sys.argv[1], sys.argv[2])
```

---

## Using Your Fine-Tuned Model

### 1. Copy the Model

```bash
# Copy your fine-tuned GGUF to MindType models folder
cp mindtype_gguf/model-q4_k_m.gguf \
   "/path/to/MindType/project/apple/Models/mindtype-finetuned.gguf"
```

### 2. Update Model Discovery

The model will be automatically discovered if you name it appropriately. Or update `LlamaLMAdapter.swift`:

```swift
public static let supportedModels = [
    "mindtype-finetuned.gguf",        // Your fine-tuned model (best)
    "qwen2.5-3b-instruct-q4_k_m.gguf", // Fallback
    "qwen2.5-0.5b-instruct-q4_k_m.gguf", // Smallest
]
```

### 3. Test

```bash
cd apple/MindType
swift run MindTypeDemo -i
```

---

## Troubleshooting

### "Out of memory" during training

- Reduce batch size to 1
- Use gradient checkpointing
- Use 4-bit quantization during training
- Use a smaller base model (1.5B instead of 3B)

### Model outputs are worse after fine-tuning

- Training data may have errors - review samples
- Learning rate too high - reduce to 1e-5
- Overtrained - reduce epochs/steps
- Data format mismatch - check chat template

### Model is slow on device

- Ensure Metal/GPU acceleration is enabled
- Use smaller quantization (q4_k_m)
- Reduce context length in prompts

---

## Resources

- [Unsloth GitHub](https://github.com/unslothai/unsloth) - Fast fine-tuning
- [llama.cpp](https://github.com/ggerganov/llama.cpp) - GGUF and inference
- [MLX](https://github.com/ml-explore/mlx) - Apple Silicon native
- [LoRA Paper](https://arxiv.org/abs/2106.09685) - Low-Rank Adaptation
- [QLoRA Paper](https://arxiv.org/abs/2305.14314) - Quantized LoRA

---

*Last updated: November 2025*

