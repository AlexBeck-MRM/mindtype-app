#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   R E A L - T I M E   D E M O                            ║
║                                                                              ║
║  Burst → Pause → Correct → Resume                                           ║
╚══════════════════════════════════════════════════════════════════════════════╝

Single-threaded implementation to avoid Metal crashes.
All inference happens on the main thread during idle time.
"""

import sys
import os
import tty
import termios
import select
import time
import atexit
import signal
from pathlib import Path

# Global for terminal restoration
_original_terminal_settings = None

def restore_terminal():
    """Restore terminal settings on exit."""
    global _original_terminal_settings
    if _original_terminal_settings:
        try:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, _original_terminal_settings)
        except:
            pass
    # Also run stty sane as backup
    os.system('stty sane 2>/dev/null')

# Register cleanup handlers
atexit.register(restore_terminal)
signal.signal(signal.SIGINT, lambda s, f: (restore_terminal(), sys.exit(0)))
signal.signal(signal.SIGTERM, lambda s, f: (restore_terminal(), sys.exit(0)))

# Configuration
PAUSE_THRESHOLD_MS = 600      # Pause before correction triggers
ACTIVE_REGION_WORDS = 20      # Words before caret to process

MODEL_PATH = Path(__file__).parent.parent / "tools" / "mlx_output" / "fused_v2"

# ANSI codes
CLEAR_LINE = "\033[2K"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
CYAN = "\033[36m"
RESET = "\033[0m"

SYSTEM_PROMPT = """Fix ONLY obvious typos. Keep everything else exactly as written.

Do NOT:
- Add words that aren't there
- Change meaning or rephrase sentences  
- Hallucinate content

Return the text with typos fixed, nothing more."""


class MindTypeDemo:
    def __init__(self):
        self.model = None
        self.tokenizer = None
        self.text = ""
        self.last_keystroke = 0
        self.needs_correction = False
        self.running = True
        
    def load_model(self):
        print(f"  {DIM}Loading model...{RESET}", end="", flush=True)
        from mlx_lm import load
        self.model, self.tokenizer = load(str(MODEL_PATH))
        print(f"\r  {GREEN}✓{RESET} Model loaded (Apple Silicon Metal)")
        
    def correct_text(self, text: str) -> str:
        """Run LLM correction."""
        if not text.strip():
            return text
            
        from mlx_lm import generate
        
        prompt = f"<|im_start|>system\n{SYSTEM_PROMPT}<|im_end|>\n<|im_start|>user\n{text}<|im_end|>\n<|im_start|>assistant\n"
        
        try:
            response = generate(self.model, self.tokenizer, prompt=prompt, max_tokens=150)
            output = response.split("<|im_start|>assistant")[-1].split("<|im_end|>")[0].strip()
            return output.split("\n")[0].strip()
        except:
            return text
    
    def redraw(self, status=""):
        if status == "correcting":
            indicator = f"{YELLOW}⏳{RESET}"
        elif status == "corrected":
            indicator = f"{GREEN}✨{RESET}"
        else:
            indicator = f"{CYAN}⠶{RESET}"
        
        display = self.text if self.text else f"{DIM}Start typing...{RESET}"
        sys.stdout.write(f"\r{CLEAR_LINE}{indicator} {display}")
        sys.stdout.flush()
    
    def run(self):
        print()
        print(f"{BOLD}╔══════════════════════════════════════════════════════════════╗{RESET}")
        print(f"{BOLD}║  M I N D ⠶ T Y P E   R E A L - T I M E                       ║{RESET}")
        print(f"{BOLD}╚══════════════════════════════════════════════════════════════╝{RESET}")
        print()
        print(f"  {DIM}Type naturally. Corrections happen after {PAUSE_THRESHOLD_MS}ms pause.{RESET}")
        print(f"  {DIM}Press Enter to finalize. Ctrl+C to quit.{RESET}")
        print()
        
        self.load_model()
        print()
        print("─" * 60)
        print()
        
        global _original_terminal_settings
        fd = sys.stdin.fileno()
        _original_terminal_settings = termios.tcgetattr(fd)
        
        try:
            tty.setraw(fd)
            self.redraw()
            
            while self.running:
                # Check for input with short timeout
                if select.select([sys.stdin], [], [], 0.1)[0]:
                    key = sys.stdin.read(1)
                    self.last_keystroke = time.time()
                    self.needs_correction = False
                    
                    if key == '\x03':  # Ctrl+C
                        break
                    elif key == '\x1b':  # Escape
                        if select.select([sys.stdin], [], [], 0.01)[0]:
                            sys.stdin.read(2)
                        continue
                    elif key == '\x7f':  # Backspace
                        self.text = self.text[:-1] if self.text else ""
                    elif key == '\x17':  # Ctrl+W
                        words = self.text.split()
                        self.text = " ".join(words[:-1]) if words else ""
                    elif key == '\x15':  # Ctrl+U
                        self.text = ""
                    elif key in ('\r', '\n'):  # Enter
                        if self.text.strip():
                            self.redraw("correcting")
                            corrected = self.correct_text(self.text)
                            print(f"\r{CLEAR_LINE}{GREEN}✨{RESET} {corrected}")
                            self.text = ""
                        else:
                            print()
                    elif key.isprintable():
                        self.text += key
                    
                    self.redraw()
                else:
                    # No input - check if we should correct
                    elapsed = time.time() - self.last_keystroke
                    
                    if (self.text.strip() and 
                        elapsed > PAUSE_THRESHOLD_MS / 1000.0 and 
                        not self.needs_correction):
                        
                        self.needs_correction = True
                        self.redraw("correcting")
                        
                        corrected = self.correct_text(self.text)
                        
                        if corrected != self.text:
                            self.text = corrected
                            self.redraw("corrected")
                            time.sleep(0.2)
                        
                        self.redraw()
                        
        finally:
            restore_terminal()
            print(f"\n\n{DIM}Goodbye!{RESET}\n")


def main():
    if not MODEL_PATH.exists():
        print(f"❌ Model not found at {MODEL_PATH}")
        sys.exit(1)
    
    MindTypeDemo().run()


if __name__ == "__main__":
    main()
