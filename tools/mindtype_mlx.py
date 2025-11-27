#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ F L O W   E N T E R   M O D E                                    ║
║                                                                              ║
║  Type → Press Enter → Watch the sweep                                        ║
║  Interactive demo of the "Caret Organism" correction marker                  ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import sys
import os
import time
from pathlib import Path
from enum import Enum

# Reset terminal in case previous crash left it broken
os.system('stty sane 2>/dev/null')

# Add tools to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from mindtype_core import CorrectionEngine, MindTypeConfig


# ═══════════════════════════════════════════════════════════════════════════════
# MIND⠶FLOW MARKER STATE (Caret Organism)
# ═══════════════════════════════════════════════════════════════════════════════

class MarkerState(Enum):
    """The "Caret Organism" state machine per Mind⠶Flow guide."""
    IDLE      = "idle"       # Ready, at rest beside caret
    LISTENING = "listening"  # Typing detected
    THINKING  = "thinking"   # Processing correction
    SWEEPING  = "sweeping"   # Traveling through text
    COMPLETE  = "complete"   # Correction applied
    ERROR     = "error"      # Failed


# Braille symbols per state — middle 2x2 grid (dots 2,3,5,6)
# Grid:  2 5
#        3 6
BRAILLE = {
    MarkerState.IDLE:      "⠤",  # dots 3,6 — horizontal, stable
    MarkerState.LISTENING: "⠴",  # dots 3,5,6 — growing, active
    MarkerState.THINKING:  "⠦",  # dots 2,3,6 — processing
    MarkerState.SWEEPING:  "⠶",  # dots 2,3,5,6 — full, traveling
    MarkerState.COMPLETE:  "⠲",  # dots 2,5,6 — satisfied
    MarkerState.ERROR:     "⠆",  # dots 2,3 — interrupted
}

# Sweep animation frames (middle 2x2)
SWEEP_FRAMES = ["⠶", "⠦", "⠴", "⠲"]

# ANSI colors
CLEAR_LINE = "\033[2K"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
ORANGE = "\033[38;5;208m"
CYAN = "\033[36m"
RESET = "\033[0m"


def animate_sweep(original: str, corrected: str) -> None:
    """
    Animate the correction sweep — marker travels through text.
    
    Per Mind⠶Flow guide:
    - Frame A: Marker at start, original text visible
    - Frame B: Marker traveling, corrections revealed behind it
    - Catch-up: Marker reaches caret position
    """
    if original == corrected:
        # No changes
        print(f"{GREEN}{BRAILLE[MarkerState.COMPLETE]}{RESET} {corrected}")
        return
    
    sweep_duration = 0.5  # seconds
    frames = 25
    frame_delay = sweep_duration / frames
    
    for i in range(frames + 1):
        progress = i / frames
        pos = int(len(corrected) * progress)
        
        if pos < len(corrected):
            # Corrected text up to marker position
            revealed = corrected[:pos]
            # Remaining text (show original styling)
            remaining_orig = original[pos:] if pos < len(original) else ""
            
            # Sweep symbol animates
            sweep_symbol = SWEEP_FRAMES[i % len(SWEEP_FRAMES)]
            
            # Build: [sweep marker] [revealed corrected] [remaining dim]
            display = (
                f"\r{CLEAR_LINE}"
                f"{ORANGE}{sweep_symbol}{RESET} "
                f"{GREEN}{revealed}{RESET}"
                f"{DIM}{remaining_orig}{RESET}"
            )
        else:
            # Sweep complete
            display = f"\r{CLEAR_LINE}{GREEN}{BRAILLE[MarkerState.COMPLETE]}{RESET} {GREEN}{corrected}{RESET}"
        
        sys.stdout.write(display)
        sys.stdout.flush()
        time.sleep(frame_delay)
    
    # Final newline
    print()


def show_micro_scene(name: str, before: str, after: str):
    """
    Display a micro-scene from the Mind⠶Flow guide.
    
    Shows the "before" state, then animates the sweep to "after".
    """
    print(f"\n{DIM}━━━ {name} ━━━{RESET}")
    print(f"  {DIM}Burst:{RESET}  {BRAILLE[MarkerState.LISTENING]} {before}")
    time.sleep(0.3)
    print(f"  {DIM}Pause →{RESET}", end=" ")
    animate_sweep(before, after)


def main():
    print()
    print(f"{BOLD}╔══════════════════════════════════════════════════════════════╗{RESET}")
    print(f"{BOLD}║  M I N D {CYAN}⠶{RESET}{BOLD} F L O W   D E M O   (Fine-tuned)                 ║{RESET}")
    print(f"{BOLD}║                                                              ║{RESET}")
    print(f"{BOLD}║  {DIM}Type at the speed of thought ✨{RESET}{BOLD}                            ║{RESET}")
    print(f"{BOLD}╚══════════════════════════════════════════════════════════════╝{RESET}")
    print()
    
    # Show marker state guide (middle 2x2: dots 2,3,5,6)
    print(f"  {DIM}Caret organism states:{RESET}")
    print(f"    ⠤ idle   ⠴ listening   ⠦ thinking   ⠶ sweeping   ⠲ complete")
    print()
    
    # Initialize
    config = MindTypeConfig(
        min_words=3,
        return_original_on_failure=True,
        show_confidence=True,
    )
    
    engine = CorrectionEngine(config)
    
    print(f"📦 Loading fine-tuned model...")
    print(f"   {DIM}Path: {config.model_path}{RESET}")
    
    if not engine.load_model():
        print(f"   {DIM}❌ Model not found{RESET}")
        sys.exit(1)
    
    print(f"{GREEN}✓{RESET} Model loaded (Apple Silicon Metal accelerated)")
    print()
    
    # Show micro-scenes from Mind⠶Flow guide
    print(f"{BOLD}Micro-scenes from Mind⠶Flow guide:{RESET}")
    
    micro_scenes = [
        ("Trivial typo burst", "Teh quick borwn fx jumps", "The quick brown fox jumps"),
        ("Punctuation + spacing", "However  this isnt right is it", "However, this isn't right, is it"),
        ("Agreement + article", "It was a unusual event", "It was an unusual event"),
    ]
    
    for name, before, after in micro_scenes:
        show_micro_scene(name, before, after)
        time.sleep(0.5)
    
    print()
    print("─" * 60)
    print(f"{DIM}Type fuzzy text and press Enter. Type 'quit' to exit.{RESET}")
    print("─" * 60)
    print()
    
    while True:
        try:
            # Show idle marker as prompt
            user_input = input(f"{BRAILLE[MarkerState.IDLE]} You: ").strip()
            
            if not user_input:
                continue
            
            if user_input.lower() == 'quit':
                print(f"\n{DIM}👋 Goodbye!{RESET}")
                break
            
            if user_input.lower() == 'demo':
                # Re-run micro-scenes
                for name, before, after in micro_scenes:
                    show_micro_scene(name, before, after)
                    time.sleep(0.5)
                print()
                continue
            
            if user_input.lower() == 'help':
                print(f"\n{DIM}Commands:{RESET}")
                print(f"  {DIM}quit  - Exit the demo{RESET}")
                print(f"  {DIM}demo  - Show micro-scenes again{RESET}")
                print(f"  {DIM}help  - Show this help{RESET}")
                print()
                continue
            
            # Show thinking state
            sys.stdout.write(f"\r{CLEAR_LINE}{YELLOW}{BRAILLE[MarkerState.THINKING]}{RESET} {DIM}interpreting...{RESET}")
            sys.stdout.flush()
            
            # Get correction
            result = engine.correct(user_input)
            
            # Clear thinking line
            sys.stdout.write(f"\r{CLEAR_LINE}")
            
            if result.success:
                # Animate the sweep
                sys.stdout.write(f"{BRAILLE[MarkerState.SWEEPING]} Mind: ")
                sys.stdout.flush()
                animate_sweep(user_input, result.text)
                
                if config.show_confidence:
                    print(f"   {DIM}confidence: {result.confidence:.0%}{RESET}")
            else:
                # Show error/waiting state
                print(f"{YELLOW}{BRAILLE[MarkerState.ERROR]}{RESET} {result.text or user_input}")
                print(f"   {DIM}↳ {result.reason}{RESET}")
            
            print()
            
        except KeyboardInterrupt:
            print(f"\n\n{DIM}👋 Goodbye!{RESET}")
            break
        except EOFError:
            break


if __name__ == "__main__":
    main()
