#!/bin/bash
#╔══════════════════════════════════════════════════════════════════════════════╗
#║  M I N D ⠶ T Y P E   F I N E - T U N I N G   S C R I P T                    ║
#║                                                                              ║
#║  Fine-tunes a model on MindType training data using llama.cpp or Unsloth    ║
#╚══════════════════════════════════════════════════════════════════════════════╝

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
MODELS_DIR="$PROJECT_DIR/apple/Models"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  M I N D ⠶ T Y P E   F I N E - T U N I N G                   ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check what's available
echo -e "${YELLOW}📁 Checking Models directory...${NC}"
ls -lh "$MODELS_DIR"/*.gguf 2>/dev/null || echo "No GGUF models found"
echo ""

echo -e "${YELLOW}📊 Training data available:${NC}"
ls -lh "$MODELS_DIR"/mindtype_train* 2>/dev/null || echo "No training data found"
echo ""

# Check for fine-tuning tools
LLAMA_FINETUNE=""
if command -v llama-finetune &> /dev/null; then
    LLAMA_FINETUNE="llama-finetune"
elif [ -f "/opt/homebrew/bin/llama-finetune" ]; then
    LLAMA_FINETUNE="/opt/homebrew/bin/llama-finetune"
elif [ -f "$HOME/llama.cpp/finetune" ]; then
    LLAMA_FINETUNE="$HOME/llama.cpp/finetune"
fi

UNSLOTH_AVAILABLE=false
if python3 -c "import unsloth" 2>/dev/null; then
    UNSLOTH_AVAILABLE=true
fi

MLX_AVAILABLE=false
if python3 -c "import mlx_lm" 2>/dev/null; then
    MLX_AVAILABLE=true
fi

echo -e "${YELLOW}🔧 Available fine-tuning tools:${NC}"
[ -n "$LLAMA_FINETUNE" ] && echo -e "  ${GREEN}✓${NC} llama.cpp finetune: $LLAMA_FINETUNE"
[ -z "$LLAMA_FINETUNE" ] && echo -e "  ${RED}✗${NC} llama.cpp finetune not found"
[ "$UNSLOTH_AVAILABLE" = true ] && echo -e "  ${GREEN}✓${NC} Unsloth (pip install unsloth)"
[ "$UNSLOTH_AVAILABLE" = false ] && echo -e "  ${RED}✗${NC} Unsloth not installed"
[ "$MLX_AVAILABLE" = true ] && echo -e "  ${GREEN}✓${NC} MLX (Apple Silicon native)"
[ "$MLX_AVAILABLE" = false ] && echo -e "  ${RED}✗${NC} MLX not installed"
echo ""

# Menu
echo -e "${BLUE}Select fine-tuning method:${NC}"
echo "  1) llama.cpp LoRA (if available)"
echo "  2) Unsloth (recommended, requires CUDA or MPS)"
echo "  3) MLX (Apple Silicon native)"
echo "  4) Show manual instructions"
echo "  5) Exit"
echo ""
read -p "Choice [1-5]: " choice

case $choice in
    1)
        if [ -z "$LLAMA_FINETUNE" ]; then
            echo -e "${RED}llama.cpp finetune not found. Install with:${NC}"
            echo "  brew install llama.cpp"
            echo "  # or build from source with finetune enabled"
            exit 1
        fi
        
        echo -e "${GREEN}Starting llama.cpp LoRA fine-tuning...${NC}"
        
        # Find base model
        BASE_MODEL=$(ls -1 "$MODELS_DIR"/qwen*.gguf | head -1)
        if [ -z "$BASE_MODEL" ]; then
            echo -e "${RED}No base model found in $MODELS_DIR${NC}"
            exit 1
        fi
        
        echo "Base model: $BASE_MODEL"
        echo "Training data: $MODELS_DIR/mindtype_train.txt"
        
        $LLAMA_FINETUNE \
            --model-base "$BASE_MODEL" \
            --train-data "$MODELS_DIR/mindtype_train.txt" \
            --lora-out "$MODELS_DIR/mindtype_lora.gguf" \
            --ctx 2048 \
            --batch 4 \
            --threads 8 \
            --epochs 3 \
            --save-every 100
        ;;
        
    2)
        if [ "$UNSLOTH_AVAILABLE" = false ]; then
            echo -e "${YELLOW}Installing Unsloth...${NC}"
            pip install unsloth
        fi
        
        echo -e "${GREEN}Creating Unsloth training script...${NC}"
        
        cat > "$PROJECT_DIR/tools/train_unsloth.py" << 'UNSLOTH_SCRIPT'
#!/usr/bin/env python3
"""MindType fine-tuning with Unsloth (2x faster, 70% less memory)"""

import json
import torch
from unsloth import FastLanguageModel
from datasets import Dataset
from trl import SFTTrainer
from transformers import TrainingArguments

# Configuration
MODEL_NAME = "unsloth/Qwen2.5-1.5B-Instruct-bnb-4bit"  # or 3B
MAX_SEQ_LENGTH = 2048
LORA_R = 16
OUTPUT_DIR = "mindtype_finetuned"

print("🧠 Loading base model...")
model, tokenizer = FastLanguageModel.from_pretrained(
    model_name=MODEL_NAME,
    max_seq_length=MAX_SEQ_LENGTH,
    load_in_4bit=True,
)

print("🔧 Adding LoRA adapters...")
model = FastLanguageModel.get_peft_model(
    model,
    r=LORA_R,
    target_modules=["q_proj", "k_proj", "v_proj", "o_proj",
                    "gate_proj", "up_proj", "down_proj"],
    lora_alpha=16,
    lora_dropout=0,
    bias="none",
    use_gradient_checkpointing="unsloth",
)

print("📊 Loading training data...")
with open("../apple/Models/mindtype_train.json", "r") as f:
    train_data = json.load(f)

# Convert to dataset format
def format_conversation(conv):
    messages = conv["conversations"]
    text = ""
    for msg in messages:
        role = msg["from"]
        content = msg["value"]
        if role == "system":
            text += f"<|im_start|>system\n{content}<|im_end|>\n"
        elif role == "human":
            text += f"<|im_start|>user\n{content}<|im_end|>\n"
        elif role == "gpt":
            text += f"<|im_start|>assistant\n{content}<|im_end|>\n"
    return {"text": text}

dataset = Dataset.from_list([format_conversation(c) for c in train_data])

print(f"   Training examples: {len(dataset)}")

print("🚀 Starting training...")
trainer = SFTTrainer(
    model=model,
    tokenizer=tokenizer,
    train_dataset=dataset,
    dataset_text_field="text",
    max_seq_length=MAX_SEQ_LENGTH,
    args=TrainingArguments(
        per_device_train_batch_size=2,
        gradient_accumulation_steps=4,
        warmup_steps=10,
        max_steps=500,  # Adjust based on dataset size
        learning_rate=2e-4,
        fp16=not torch.cuda.is_bf16_supported(),
        bf16=torch.cuda.is_bf16_supported(),
        logging_steps=10,
        output_dir=OUTPUT_DIR,
        save_steps=100,
    ),
)

trainer.train()

print("💾 Saving model...")
model.save_pretrained(f"{OUTPUT_DIR}_lora")

print("📦 Exporting to GGUF...")
model.save_pretrained_gguf(
    f"{OUTPUT_DIR}_gguf",
    tokenizer,
    quantization_method="q4_k_m"
)

print("✅ Done! Model saved to:")
print(f"   LoRA: {OUTPUT_DIR}_lora/")
print(f"   GGUF: {OUTPUT_DIR}_gguf/")
print("\nCopy the GGUF to apple/Models/ to use with MindType")
UNSLOTH_SCRIPT

        echo -e "${GREEN}Script created: tools/train_unsloth.py${NC}"
        echo ""
        echo "Run with:"
        echo "  cd tools && python train_unsloth.py"
        ;;
        
    3)
        if [ "$MLX_AVAILABLE" = false ]; then
            echo -e "${YELLOW}Installing MLX...${NC}"
            pip install mlx mlx-lm
        fi
        
        echo -e "${GREEN}MLX fine-tuning (Apple Silicon native)${NC}"
        echo ""
        echo "Run these commands:"
        echo ""
        echo "  # Convert training data to MLX format"
        echo "  python -c \"import json; d=json.load(open('apple/Models/mindtype_train.json')); open('apple/Models/train.jsonl','w').writelines(json.dumps(x)+'\n' for x in d)\""
        echo ""
        echo "  # Fine-tune with LoRA"
        echo "  python -m mlx_lm.lora \\"
        echo "      --model Qwen/Qwen2.5-1.5B-Instruct \\"
        echo "      --train \\"
        echo "      --data apple/Models/train.jsonl \\"
        echo "      --batch-size 4 \\"
        echo "      --lora-layers 16 \\"
        echo "      --iters 500"
        echo ""
        echo "  # Merge LoRA and convert"
        echo "  python -m mlx_lm.fuse --model Qwen/Qwen2.5-1.5B-Instruct --adapter-path adapters"
        ;;
        
    4)
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo -e "${GREEN}MANUAL FINE-TUNING INSTRUCTIONS${NC}"
        echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Training data location:"
        echo "  $MODELS_DIR/mindtype_training_data.jsonl  (raw pairs)"
        echo "  $MODELS_DIR/mindtype_train.json           (ShareGPT format)"
        echo "  $MODELS_DIR/mindtype_train.txt            (ChatML format)"
        echo "  $MODELS_DIR/mindtype_train_val.json       (validation set)"
        echo ""
        echo "Base models available:"
        ls -1 "$MODELS_DIR"/*.gguf 2>/dev/null | while read f; do
            echo "  $(basename "$f")"
        done
        echo ""
        echo "Recommended tools:"
        echo "  1. Unsloth (fastest): pip install unsloth"
        echo "  2. MLX (Mac native):  pip install mlx mlx-lm"
        echo "  3. llama.cpp:         brew install llama.cpp"
        echo ""
        echo "See docs/FINE-TUNING.md for detailed instructions"
        ;;
        
    5)
        echo "Exiting."
        exit 0
        ;;
        
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}Done!${NC}"

