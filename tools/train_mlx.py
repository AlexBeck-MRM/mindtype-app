#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   M L X   F I N E - T U N I N G                          ║
║                                                                              ║
║  Apple Silicon native fine-tuning using MLX (Metal accelerated)             ║
╚══════════════════════════════════════════════════════════════════════════════╝

Optimized for M1/M2/M3 Macs with unified memory.
"""

import json
import os
import sys
from pathlib import Path

# Configuration
PROJECT_DIR = Path(__file__).parent.parent
MODELS_DIR = PROJECT_DIR / "apple" / "Models"
OUTPUT_DIR = PROJECT_DIR / "apple" / "Models"

# Training config
CONFIG = {
    "model": "Qwen/Qwen2.5-1.5B-Instruct",  # Base model from HuggingFace
    "batch_size": 4,
    "lora_layers": 16,
    "lora_rank": 8,
    "learning_rate": 1e-4,
    "iters": 500,  # Adjust based on dataset size
    "warmup": 50,
    "save_every": 100,
}

def convert_to_mlx_format():
    """Convert MindType training data to MLX format."""
    print("📊 Converting training data to MLX format...")
    
    input_file = MODELS_DIR / "mindtype_train.json"
    output_file = MODELS_DIR / "mlx_train.jsonl"
    val_output = MODELS_DIR / "mlx_valid.jsonl"
    
    with open(input_file) as f:
        data = json.load(f)
    
    # Convert ShareGPT format to MLX chat format
    train_examples = []
    for item in data:
        conversations = item.get("conversations", [])
        
        # Extract system, user, assistant
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
            train_examples.append({"messages": messages})
    
    # Split train/validation (90/10)
    split_idx = int(len(train_examples) * 0.9)
    train_data = train_examples[:split_idx]
    val_data = train_examples[split_idx:]
    
    # Write JSONL files
    with open(output_file, 'w') as f:
        for example in train_data:
            f.write(json.dumps(example) + '\n')
    
    with open(val_output, 'w') as f:
        for example in val_data:
            f.write(json.dumps(example) + '\n')
    
    print(f"   ✓ Training examples: {len(train_data)}")
    print(f"   ✓ Validation examples: {len(val_data)}")
    print(f"   ✓ Saved to: {output_file}")
    
    return output_file, val_output


def run_training():
    """Run MLX LoRA training."""
    import subprocess
    
    print("\n🚀 Starting MLX LoRA training (Apple Silicon native)...")
    print(f"   Model: {CONFIG['model']}")
    print(f"   Batch size: {CONFIG['batch_size']}")
    print(f"   LoRA rank: {CONFIG['lora_rank']}")
    print(f"   Iterations: {CONFIG['iters']}")
    print()
    
    train_file = MODELS_DIR / "mlx_train.jsonl"
    val_file = MODELS_DIR / "mlx_valid.jsonl"
    adapter_path = OUTPUT_DIR / "adapters"
    
    # Create output directory
    adapter_path.mkdir(parents=True, exist_ok=True)
    
    cmd = [
        sys.executable, "-m", "mlx_lm", "lora",
        "--model", CONFIG["model"],
        "--train",
        "--data", str(train_file),
        "--batch-size", str(CONFIG["batch_size"]),
        "--num-layers", str(CONFIG["lora_layers"]),
        "--learning-rate", str(CONFIG["learning_rate"]),
        "--iters", str(CONFIG["iters"]),
        "--save-every", str(CONFIG["save_every"]),
        "--adapter-path", str(adapter_path),
        "--test",  # Run validation after training
        "--test-batches", "20",
    ]
    
    print(f"Running: {' '.join(cmd[:6])}...")
    print()
    
    # Run training
    process = subprocess.run(cmd, cwd=str(PROJECT_DIR))
    
    return process.returncode == 0, adapter_path


def fuse_and_convert(adapter_path: Path):
    """Fuse LoRA weights and convert to GGUF."""
    import subprocess
    
    print("\n📦 Fusing LoRA adapters with base model...")
    
    fused_path = OUTPUT_DIR / "fused_model"
    
    cmd = [
        sys.executable, "-m", "mlx_lm", "fuse",
        "--model", CONFIG["model"],
        "--adapter-path", str(adapter_path),
        "--save-path", str(fused_path),
    ]
    
    process = subprocess.run(cmd, cwd=str(PROJECT_DIR))
    
    if process.returncode == 0:
        print(f"   ✓ Fused model saved to: {fused_path}")
        return fused_path
    else:
        print("   ✗ Fusion failed")
        return None


def convert_to_gguf(fused_path: Path):
    """Convert MLX model to GGUF for llama.cpp."""
    print("\n🔄 Converting to GGUF format...")
    
    # Check if llama.cpp convert script is available
    convert_script = Path.home() / "llama.cpp" / "convert_hf_to_gguf.py"
    
    if not convert_script.exists():
        # Try using mlx_lm's built-in conversion if available
        print("   ⚠️  llama.cpp not found. Manual conversion needed:")
        print()
        print("   Option 1: Use llama.cpp")
        print(f"     git clone https://github.com/ggerganov/llama.cpp")
        print(f"     python llama.cpp/convert_hf_to_gguf.py {fused_path} --outfile mindtype-finetuned.gguf")
        print()
        print("   Option 2: Use mlx_lm.convert (if supported)")
        print(f"     python -m mlx_lm.convert --hf-path {fused_path} -q")
        print()
        print(f"   Then copy the .gguf file to: {MODELS_DIR}/mindtype-finetuned-q4_k_m.gguf")
        return None
    
    output_gguf = MODELS_DIR / "mindtype-finetuned.gguf"
    
    import subprocess
    cmd = [
        sys.executable, str(convert_script),
        str(fused_path),
        "--outfile", str(output_gguf),
        "--outtype", "q4_k_m",
    ]
    
    process = subprocess.run(cmd)
    
    if process.returncode == 0:
        print(f"   ✓ GGUF saved to: {output_gguf}")
        return output_gguf
    
    return None


def main():
    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  M I N D ⠶ T Y P E   M L X   F I N E - T U N I N G          ║")
    print("║                                                              ║")
    print("║  Apple Silicon Native (Metal Accelerated)                    ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    # Check MLX is available
    try:
        import mlx.core as mx
        import mlx_lm
        print(f"✓ MLX available (Apple Silicon accelerated)")
    except ImportError:
        print("✗ MLX not installed. Run: pip install mlx mlx-lm")
        sys.exit(1)
    
    # Step 1: Convert training data
    train_file, val_file = convert_to_mlx_format()
    
    # Step 2: Run training
    print()
    success, adapter_path = run_training()
    
    if not success:
        print("\n❌ Training failed!")
        sys.exit(1)
    
    print("\n✅ Training complete!")
    print(f"   Adapters saved to: {adapter_path}")
    
    # Step 3: Fuse model
    fused_path = fuse_and_convert(adapter_path)
    
    if fused_path:
        # Step 4: Convert to GGUF
        convert_to_gguf(fused_path)
    
    print()
    print("═══════════════════════════════════════════════════════════════")
    print("Next steps:")
    print(f"  1. Copy the fused model or GGUF to: {MODELS_DIR}")
    print(f"  2. Name it: mindtype-finetuned-q4_k_m.gguf")
    print(f"  3. Run: swift run MindTypeDemo -i")
    print("═══════════════════════════════════════════════════════════════")


if __name__ == "__main__":
    main()

