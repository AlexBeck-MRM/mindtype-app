#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   F I N E - T U N E D   M O D E L   T E S T              ║
╚══════════════════════════════════════════════════════════════════════════════╝

Test the fine-tuned model with realistic MindType inputs.
"""

from mlx_lm import load, generate
import sys

print()
print("╔══════════════════════════════════════════════════════════════╗")
print("║  M I N D ⠶ T Y P E   F I N E - T U N E D   T E S T          ║")
print("╚══════════════════════════════════════════════════════════════╝")
print()

MODEL_PATH = "apple/Models/mindflow-qwen-3b-v2"

print(f"📦 Loading fine-tuned model from {MODEL_PATH}...")
model, tokenizer = load(MODEL_PATH)
print("✓ Model loaded (Apple Silicon Metal accelerated)")
print()

SYSTEM_PROMPT = """You decode garbled, abbreviated, or typo-filled text into what the user intended to write.

Rules:
1. Preserve the user's meaning and intent
2. Expand abbreviations to full words
3. Fix typos, transpositions, and missing letters
4. ONLY return the corrected text, nothing else
5. Do NOT add explanations or extra content"""

TESTS = [
    # Basic typos
    ("definately wierd becuase teh world is strage", "definitely weird because the world is strange"),
    ("Th qck brwn fox jmps ovr th lazy dg", "The quick brown fox jumps over the lazy dog"),
    
    # Missing letters (velocity mode)
    ("ths is hw ppl typ whn thy r in a hrry", "this is how people type when they are in a hurry"),
    ("wld u lk sm tea", "would you like some tea"),
    
    # Transpositions
    ("teh probelm iwth tihs sitatuion is taht", "the problem with this situation is that"),
    ("I jsut wnat to sa ythat", "I just want to say that"),
    
    # Real-world fuzzy typing (like user's example)
    ("ideallytrhis should feel liek magic and clairvoicnce", "ideally this should feel like magic and clairvoyance"),
    ("inaginefc tpeing without htbereaking the rypthg", "imagine typing without breaking the rhythm"),
    
    # Domain-specific (legal/finance)
    ("defdnt clamd innocnce in crt", "defendant claimed innocence in court"),
    ("hgh rvn grwth in tch stks", "high revenue growth in tech stocks"),
]

print("🧪 Running tests...")
print("─" * 60)
print()

passed = 0
failed = 0

for input_text, expected in TESTS:
    prompt = f"""<|im_start|>system
{SYSTEM_PROMPT}<|im_end|>
<|im_start|>user
{input_text}<|im_end|>
<|im_start|>assistant
"""
    
    response = generate(model, tokenizer, prompt=prompt, max_tokens=100)
    
    # Extract assistant response
    output = response.split("<|im_start|>assistant")[-1]
    output = output.split("<|im_end|}")[0].strip()
    output = output.replace("\n", " ").strip()
    
    # Check if output is close to expected
    is_correct = output.lower().strip() == expected.lower().strip()
    
    status = "✓" if is_correct else "○"
    if is_correct:
        passed += 1
    else:
        failed += 1
    
    print(f"{status}  IN:  {input_text}")
    print(f"   OUT: {output}")
    if not is_correct:
        print(f"   EXP: {expected}")
    print()

print("─" * 60)
print(f"Results: {passed}/{len(TESTS)} passed")
print()

if passed >= len(TESTS) * 0.6:
    print("✅ Model is working well for basic typo correction!")
else:
    print("⚠️  Model may need more training or a larger base model for complex cases")

print()
print("To use this model in MindType, either:")
print("  1. Convert to GGUF: python convert_hf_to_gguf.py tools/mlx_output/fused_model --outfile mindtype-finetuned.gguf")
print("  2. Use MLX directly (recommended for Apple Silicon)")

