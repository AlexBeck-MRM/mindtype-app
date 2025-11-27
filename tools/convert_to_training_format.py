#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   T R A I N I N G   F O R M A T   C O N V E R T E R      ║
║                                                                              ║
║  Converts MindType training data to various fine-tuning formats.            ║
╚══════════════════════════════════════════════════════════════════════════════╝

Usage:
    python convert_to_training_format.py training_data.jsonl --format sharegpt --output train.json
    python convert_to_training_format.py training_data.jsonl --format alpaca --output train.json
    python convert_to_training_format.py training_data.jsonl --format chatml --output train.txt
"""

import argparse
import json
from pathlib import Path


SYSTEM_PROMPT = """You decode garbled speed-typing into clear English. 
Consider phonetic similarity, keyboard adjacency, and context.
Return ONLY the corrected text, nothing else."""


def load_mindtype_data(input_file: str) -> list:
    """Load MindType JSONL training data."""
    data = []
    with open(input_file, 'r', encoding='utf-8') as f:
        for line in f:
            if line.strip():
                data.append(json.loads(line))
    return data


def convert_to_sharegpt(data: list) -> list:
    """
    Convert to ShareGPT/OpenAI conversation format.
    Used by: Unsloth, Axolotl, LLaMA-Factory
    """
    conversations = []
    
    for item in data:
        conv = {
            "conversations": [
                {"from": "system", "value": SYSTEM_PROMPT},
                {"from": "human", "value": item["input"]},
                {"from": "gpt", "value": item["output"]}
            ]
        }
        conversations.append(conv)
    
    return conversations


def convert_to_alpaca(data: list) -> list:
    """
    Convert to Alpaca instruction format.
    Used by: Stanford Alpaca, many fine-tuning scripts
    """
    instructions = []
    
    for item in data:
        inst = {
            "instruction": "Decode this garbled typing into clear English. Return only the corrected text.",
            "input": item["input"],
            "output": item["output"]
        }
        instructions.append(inst)
    
    return instructions


def convert_to_chatml(data: list) -> str:
    """
    Convert to ChatML format (plain text).
    Used by: llama.cpp finetune, some training scripts
    """
    lines = []
    
    for item in data:
        text = f"""<|im_start|>system
{SYSTEM_PROMPT}<|im_end|>
<|im_start|>user
{item["input"]}<|im_end|>
<|im_start|>assistant
{item["output"]}<|im_end|>"""
        lines.append(text)
    
    return "\n\n".join(lines)


def convert_to_pairs(data: list) -> str:
    """
    Convert to simple input/output pairs (tab-separated).
    Used by: Simple training scripts, evaluation
    """
    lines = ["input\toutput"]
    
    for item in data:
        # Escape tabs and newlines
        inp = item["input"].replace("\t", " ").replace("\n", " ")
        out = item["output"].replace("\t", " ").replace("\n", " ")
        lines.append(f"{inp}\t{out}")
    
    return "\n".join(lines)


def convert_to_openai(data: list) -> list:
    """
    Convert to OpenAI fine-tuning format (JSONL with messages).
    Used by: OpenAI API fine-tuning
    """
    examples = []
    
    for item in data:
        example = {
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": item["input"]},
                {"role": "assistant", "content": item["output"]}
            ]
        }
        examples.append(example)
    
    return examples


def main():
    parser = argparse.ArgumentParser(
        description='Convert MindType training data to various formats.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Supported formats:
    sharegpt  - ShareGPT conversation format (JSON array)
    alpaca    - Stanford Alpaca instruction format (JSON array)
    chatml    - ChatML plain text format
    pairs     - Simple tab-separated pairs
    openai    - OpenAI fine-tuning format (JSONL)

Examples:
    python convert_to_training_format.py training.jsonl --format sharegpt -o train.json
    python convert_to_training_format.py training.jsonl --format chatml -o train.txt
        """
    )
    
    parser.add_argument('input', help='Input JSONL file from generate_training_data.py')
    parser.add_argument('--format', '-f', 
                        choices=['sharegpt', 'alpaca', 'chatml', 'pairs', 'openai'],
                        default='sharegpt',
                        help='Output format (default: sharegpt)')
    parser.add_argument('--output', '-o', type=str, default=None,
                        help='Output file (default: input_name.format.json/txt)')
    parser.add_argument('--split', type=float, default=0.0,
                        help='Fraction to split for validation (0.0-0.3)')
    
    args = parser.parse_args()
    
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  M I N D ⠶ T Y P E   F O R M A T   C O N V E R T E R        ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    # Load data
    print(f"📖 Loading: {args.input}")
    data = load_mindtype_data(args.input)
    print(f"   Loaded {len(data)} examples")
    
    # Split if requested
    if args.split > 0:
        import random
        random.shuffle(data)
        split_idx = int(len(data) * (1 - args.split))
        train_data = data[:split_idx]
        val_data = data[split_idx:]
        print(f"   Split: {len(train_data)} train, {len(val_data)} validation")
    else:
        train_data = data
        val_data = None
    
    # Determine output filename
    input_path = Path(args.input)
    if args.output:
        output_path = Path(args.output)
    else:
        ext = '.txt' if args.format in ['chatml', 'pairs'] else '.json'
        output_path = input_path.with_suffix(f'.{args.format}{ext}')
    
    # Convert
    print(f"🔄 Converting to {args.format} format...")
    
    if args.format == 'sharegpt':
        converted = convert_to_sharegpt(train_data)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(converted, f, indent=2, ensure_ascii=False)
    
    elif args.format == 'alpaca':
        converted = convert_to_alpaca(train_data)
        with open(output_path, 'w', encoding='utf-8') as f:
            json.dump(converted, f, indent=2, ensure_ascii=False)
    
    elif args.format == 'chatml':
        converted = convert_to_chatml(train_data)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted)
    
    elif args.format == 'pairs':
        converted = convert_to_pairs(train_data)
        with open(output_path, 'w', encoding='utf-8') as f:
            f.write(converted)
    
    elif args.format == 'openai':
        converted = convert_to_openai(train_data)
        with open(output_path, 'w', encoding='utf-8') as f:
            for item in converted:
                f.write(json.dumps(item, ensure_ascii=False) + '\n')
    
    print(f"✅ Saved to: {output_path}")
    
    # Save validation set if split
    if val_data:
        val_path = output_path.with_stem(output_path.stem + '_val')
        
        if args.format == 'sharegpt':
            val_converted = convert_to_sharegpt(val_data)
            with open(val_path, 'w', encoding='utf-8') as f:
                json.dump(val_converted, f, indent=2, ensure_ascii=False)
        elif args.format == 'alpaca':
            val_converted = convert_to_alpaca(val_data)
            with open(val_path, 'w', encoding='utf-8') as f:
                json.dump(val_converted, f, indent=2, ensure_ascii=False)
        elif args.format == 'chatml':
            val_converted = convert_to_chatml(val_data)
            with open(val_path, 'w', encoding='utf-8') as f:
                f.write(val_converted)
        elif args.format == 'pairs':
            val_converted = convert_to_pairs(val_data)
            with open(val_path, 'w', encoding='utf-8') as f:
                f.write(val_converted)
        elif args.format == 'openai':
            val_converted = convert_to_openai(val_data)
            with open(val_path, 'w', encoding='utf-8') as f:
                for item in val_converted:
                    f.write(json.dumps(item, ensure_ascii=False) + '\n')
        
        print(f"✅ Validation saved to: {val_path}")
    
    print()
    print("Next steps:")
    if args.format == 'sharegpt':
        print("  Use with Unsloth or Axolotl for fine-tuning")
    elif args.format == 'alpaca':
        print("  Use with Stanford Alpaca training scripts")
    elif args.format == 'chatml':
        print("  Use with llama.cpp finetune command")
    elif args.format == 'openai':
        print("  Upload to OpenAI for fine-tuning")
    print()


if __name__ == '__main__':
    main()

