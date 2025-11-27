#!/bin/bash
#╔══════════════════════════════════════════════════════════════════════════════╗
#║  F U Z Z Y   T Y P I N G   M O D E L   T R A I N I N G                       ║
#║                                                                              ║
#║  Safe training workflow with evaluation checkpoints                          ║
#╚══════════════════════════════════════════════════════════════════════════════╝

set -e
cd "$(dirname "$0")/.."

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  MindType Fuzzy Typing Model Training                        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

# ─── Configuration ────────────────────────────────────────────────────────────
BASE_MODEL="Qwen/Qwen2.5-0.5B-Instruct"
OUTPUT_DIR="tools/mlx_output"
ADAPTER_NAME="fuzzy_v1"
SAMPLES=3000
ITERS=300

echo "Configuration:"
echo "  Base Model: $BASE_MODEL"
echo "  Training Samples: $SAMPLES"
echo "  Training Iterations: $ITERS"
echo

# ─── Step 1: Evaluate Baseline ────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 1: Evaluating current model (baseline)"
echo "═══════════════════════════════════════════════════════════════"

if [ -d "$OUTPUT_DIR/fused_v2" ]; then
    python3 tools/evaluate_model.py --model "$OUTPUT_DIR/fused_v2" --save "$OUTPUT_DIR/baseline_eval.json"
    echo "✓ Baseline saved to $OUTPUT_DIR/baseline_eval.json"
else
    echo "⚠ No existing fine-tuned model found. Will compare against base model."
fi
echo

# ─── Step 2: Generate Training Data ───────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 2: Generating fuzzy typing training data"
echo "═══════════════════════════════════════════════════════════════"

python3 tools/generate_fuzzy_training.py --samples $SAMPLES --seed 42
echo

# ─── Step 3: Train with LoRA ──────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 3: Fine-tuning with LoRA (MLX)"
echo "═══════════════════════════════════════════════════════════════"

mkdir -p "$OUTPUT_DIR/$ADAPTER_NAME"

python3 -m mlx_lm lora \
    --model "$BASE_MODEL" \
    --train \
    --data tools/mlx_data \
    --batch-size 2 \
    --num-layers 8 \
    --learning-rate 2e-5 \
    --iters $ITERS \
    --save-every 100 \
    --adapter-path "$OUTPUT_DIR/$ADAPTER_NAME"

echo "✓ Training complete"
echo

# ─── Step 4: Fuse Adapters ────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 4: Fusing adapters with base model"
echo "═══════════════════════════════════════════════════════════════"

python3 -m mlx_lm fuse \
    --model "$BASE_MODEL" \
    --adapter-path "$OUTPUT_DIR/$ADAPTER_NAME" \
    --save-path "$OUTPUT_DIR/fused_$ADAPTER_NAME"

echo "✓ Fused model saved to $OUTPUT_DIR/fused_$ADAPTER_NAME"
echo

# ─── Step 5: Evaluate New Model ───────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 5: Evaluating fine-tuned model"
echo "═══════════════════════════════════════════════════════════════"

python3 tools/evaluate_model.py --model "$OUTPUT_DIR/fused_$ADAPTER_NAME" --save "$OUTPUT_DIR/finetuned_eval.json"
echo

# ─── Step 6: Compare Results ──────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 6: Comparison"
echo "═══════════════════════════════════════════════════════════════"

if [ -f "$OUTPUT_DIR/baseline_eval.json" ]; then
    echo "Comparing baseline vs fine-tuned..."
    python3 -c "
import json

with open('$OUTPUT_DIR/baseline_eval.json') as f:
    baseline = json.load(f)
with open('$OUTPUT_DIR/finetuned_eval.json') as f:
    finetuned = json.load(f)

base_sim = baseline['scores']['similarity']
ft_sim = finetuned['scores']['similarity']
delta = ft_sim - base_sim

print(f'Baseline Similarity:   {base_sim:.1%}')
print(f'Fine-tuned Similarity: {ft_sim:.1%}')
print(f'Improvement:           {delta:+.1%}')
print()

if delta > 0.05:
    print('✓ IMPROVEMENT: Fine-tuning helped!')
    print(f'  New model saved at: $OUTPUT_DIR/fused_$ADAPTER_NAME')
elif delta < -0.05:
    print('✗ DEGRADATION: Fine-tuning made things worse.')
    print('  Consider:')
    print('  - Reducing training iterations')
    print('  - Adjusting learning rate')
    print('  - Improving training data quality')
else:
    print('○ MINIMAL CHANGE: Fine-tuning had little effect.')
    print('  Consider:')
    print('  - Adding more training data')
    print('  - Increasing iterations')
"
fi

echo
echo "═══════════════════════════════════════════════════════════════"
echo "Training Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "Next steps:"
echo "  1. Test: python3 tools/mindtype_mlx.py --model $OUTPUT_DIR/fused_$ADAPTER_NAME"
echo "  2. If better, update mindtype_core.py to use new model"
echo "  3. If worse, try adjusting hyperparameters"

