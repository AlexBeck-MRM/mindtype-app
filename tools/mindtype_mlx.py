#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   M L X   I N T E N T   I N T E R P R E T E R            ║
║                                                                              ║
║  Apple Silicon native text intent interpretation                             ║
╚══════════════════════════════════════════════════════════════════════════════╝

Interactive demo using the fine-tuned MLX model.
This is the fastest way to run MindType on Apple Silicon.
"""

import sys
import os
from pathlib import Path
from mlx_lm import load, generate

# Reset terminal in case a previous crash left it in raw mode
os.system('stty sane 2>/dev/null')

# Paths
PROJECT_DIR = Path(__file__).parent.parent
MODEL_PATH = PROJECT_DIR / "tools" / "mlx_output" / "fused_v2"

SYSTEM_PROMPT = """Fix ONLY obvious typos. Keep everything else exactly as written.

Do NOT:
- Add words that aren't there
- Change meaning or rephrase sentences
- Hallucinate content

Return the text with typos fixed, nothing more."""


def main():
    print()
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  M I N D ⠶ T Y P E   M L X   D E M O   (Fine-tuned)         ║")
    print("║                                                              ║")
    print("║  Type at the speed of thought ✨                             ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    print(f"📦 Loading fine-tuned model...")
    print(f"   Path: {MODEL_PATH}")
    
    if not MODEL_PATH.exists():
        print(f"❌ Model not found at {MODEL_PATH}")
        print("   Run fine-tuning first: python tools/train_mlx.py")
        sys.exit(1)
    
    model, tokenizer = load(str(MODEL_PATH))
    print("✓ Model loaded (Apple Silicon Metal accelerated)")
    print()
    print("─" * 60)
    print("Type fuzzy text and press Enter. Type 'quit' to exit.")
    print("─" * 60)
    print()
    
    while True:
        try:
            user_input = input("⠶ You: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() in ('quit', 'exit', 'q'):
                print("\n👋 Goodbye!")
                break
            
            # Build prompt
            prompt = f"""<|im_start|>system
{SYSTEM_PROMPT}<|im_end|>
<|im_start|>user
{user_input}<|im_end|>
<|im_start|>assistant
"""
            
            # Generate
            response = generate(model, tokenizer, prompt=prompt, max_tokens=200)
            
            # Extract assistant response
            output = response.split("<|im_start|>assistant")[-1]
            output = output.split("<|im_end|>")[0].strip()
            output = output.split("\n")[0].strip()  # Take first line only
            
            print(f"✨ Mind: {output}")
            print()
            
        except KeyboardInterrupt:
            print("\n\n👋 Goodbye!")
            break
        except EOFError:
            break


if __name__ == "__main__":
    main()

