#!/bin/bash
#╔══════════════════════════════════════════════════════════════════════════════╗
#║  M I N D F L O W   Q W E N   T R A I N I N G                                ║
#║                                                                              ║
#║  Fine-tune Qwen 3B for fuzzy typing interpretation                          ║
#╚══════════════════════════════════════════════════════════════════════════════╝

set -e
cd "$(dirname "$0")/.."

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  MindFlow Qwen Training                                      ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo

# ─── Configuration ────────────────────────────────────────────────────────────
BASE_MODEL="Qwen/Qwen2.5-3B-Instruct"
MODEL_DIR="apple/Models"
# Increment version for each new training run
VERSION="v4"  # Change this to create a new version
ADAPTER_NAME="mindflow-qwen-3b-${VERSION}-adapters"
FINAL_NAME="mindflow-qwen-3b-${VERSION}"
SAMPLES=2000
ITERS=250

echo "Configuration:"
echo "  Base Model: $BASE_MODEL"
echo "  Output Dir: $MODEL_DIR"
echo "  Training Samples: $SAMPLES"
echo "  Training Iterations: $ITERS"
echo

# ─── Step 1: Evaluate Baseline ────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 1: Evaluating current model (baseline)"
echo "═══════════════════════════════════════════════════════════════"

if [ -d "$MODEL_DIR/$FINAL_NAME" ]; then
    python3 tools/evaluate_model.py --model "$MODEL_DIR/$FINAL_NAME" --save "tools/eval/baseline.json"
    echo "✓ Baseline saved"
else
    echo "⚠ No existing fine-tuned model found."
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

mkdir -p "$MODEL_DIR/$ADAPTER_NAME"

python3 -m mlx_lm lora \
    --model "$BASE_MODEL" \
    --train \
    --data tools/mlx_data \
    --batch-size 2 \
    --num-layers 16 \
    --learning-rate 1e-5 \
    --iters $ITERS \
    --save-every 50 \
    --adapter-path "$MODEL_DIR/$ADAPTER_NAME"

echo "✓ Training complete"
echo

# ─── Step 4: Fuse Adapters ────────────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 4: Fusing adapters with base model"
echo "═══════════════════════════════════════════════════════════════"

# Remove old model if exists
rm -rf "$MODEL_DIR/$FINAL_NAME"

python3 -m mlx_lm fuse \
    --model "$BASE_MODEL" \
    --adapter-path "$MODEL_DIR/$ADAPTER_NAME" \
    --save-path "$MODEL_DIR/$FINAL_NAME"

# Clean up adapters after fusing
rm -rf "$MODEL_DIR/$ADAPTER_NAME"

echo "✓ Fused model saved to $MODEL_DIR/$FINAL_NAME"
echo

# ─── Step 5: Evaluate New Model ───────────────────────────────────────────────
echo "═══════════════════════════════════════════════════════════════"
echo "Step 5: Evaluating fine-tuned model"
echo "═══════════════════════════════════════════════════════════════"

mkdir -p tools/eval
python3 tools/evaluate_model.py --model "$MODEL_DIR/$FINAL_NAME" --save "tools/eval/finetuned.json"
echo

echo "═══════════════════════════════════════════════════════════════"
echo "Training Complete!"
echo "═══════════════════════════════════════════════════════════════"
echo
echo "Model saved at: $MODEL_DIR/$FINAL_NAME"
echo
echo "Test with:"
echo "  python3 tools/mindtype_mlx.py"
echo "  python3 tools/evaluate_model.py"
