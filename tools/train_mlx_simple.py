#!/usr/bin/env python3
"""
Simple MLX LoRA fine-tuning for MindType
Uses the smaller 0.5B model for faster iteration
"""

import json
import os
from pathlib import Path

# Paths
PROJECT_DIR = Path(__file__).parent.parent
MODELS_DIR = PROJECT_DIR / "apple" / "Models"
OUTPUT_DIR = PROJECT_DIR / "tools" / "mlx_output"

print("╔══════════════════════════════════════════════════════════════╗")
print("║  M I N D ⠶ T Y P E   M L X   T R A I N I N G                ║")
print("╚══════════════════════════════════════════════════════════════╝")
print()

# Step 1: Prepare training data
print("📊 Preparing training data...")
train_file = MODELS_DIR / "mlx_train.jsonl"

if not train_file.exists():
    print("   Converting training data...")
    input_file = MODELS_DIR / "mindtype_train.json"
    
    with open(input_file) as f:
        data = json.load(f)
    
    with open(train_file, 'w') as f:
        for item in data[:2000]:  # Use subset for faster training
            conversations = item.get("conversations", [])
            messages = []
            for conv in conversations:
                role = conv["from"]
                content = conv["value"]
                if role == "system":
                    messages.append({"role": "system", "content": content})
                elif role == "human":
                    messages.append({"role": "user", "content": content})
                elif role == "gpt":
                    messages.append({"role": "assistant", "content": content})
            if messages:
                f.write(json.dumps({"messages": messages}) + '\n')
    
    print(f"   ✓ Saved 2000 examples to {train_file}")
else:
    print(f"   ✓ Using existing {train_file}")

# Step 2: Create output directory
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
adapter_path = OUTPUT_DIR / "adapters"

print()
print("🚀 Starting training...")
print("   Model: Qwen/Qwen2.5-0.5B-Instruct (smaller, faster)")
print("   Examples: 2000")
print("   Iterations: 200")
print()
print("   This will take approximately 10-20 minutes on M1/M2/M3...")
print()

# Run training via command line
import subprocess
import sys

cmd = [
    sys.executable, "-m", "mlx_lm", "lora",
    "--model", "Qwen/Qwen2.5-0.5B-Instruct",  # Smaller model
    "--train",
    "--data", str(train_file),
    "--batch-size", "2",
    "--num-layers", "8",
    "--learning-rate", "1e-4",
    "--iters", "200",
    "--save-every", "50",
    "--adapter-path", str(adapter_path),
]

print(f"Command: mlx_lm lora --model Qwen/Qwen2.5-0.5B-Instruct ...")
print()
print("─" * 60)

result = subprocess.run(cmd)

print("─" * 60)
print()

if result.returncode == 0:
    print("✅ Training complete!")
    print(f"   Adapters saved to: {adapter_path}")
    print()
    print("Next: Fuse adapters with base model:")
    print(f"  python -m mlx_lm fuse --model Qwen/Qwen2.5-0.5B-Instruct --adapter-path {adapter_path}")
else:
    print("❌ Training failed!")
    print("   Check the error messages above.")

