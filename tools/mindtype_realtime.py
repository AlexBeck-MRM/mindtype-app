#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ F L O W   R E A L T I M E   M O D E                              ║
║                                                                              ║
║  Burst → Pause → Correct — Type at the speed of thought                      ║
║  Implements the "Caret Organism" behavior from Mind⠶Flow guide               ║
╚══════════════════════════════════════════════════════════════════════════════╝
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
from enum import Enum
from dataclasses import dataclass
from typing import Optional

# Add tools to path for imports
sys.path.insert(0, str(Path(__file__).parent))

from mindtype_core import CorrectionEngine, MindTypeConfig

# ═══════════════════════════════════════════════════════════════════════════════
# TERMINAL SAFETY
# ═══════════════════════════════════════════════════════════════════════════════

_original_terminal = None

def restore_terminal():
    """Restore terminal on exit."""
    global _original_terminal
    if _original_terminal:
        try:
            termios.tcsetattr(sys.stdin.fileno(), termios.TCSADRAIN, _original_terminal)
        except:
            pass
    os.system('stty sane 2>/dev/null')

atexit.register(restore_terminal)
signal.signal(signal.SIGINT, lambda s, f: (restore_terminal(), sys.exit(0)))
signal.signal(signal.SIGTERM, lambda s, f: (restore_terminal(), sys.exit(0)))


# ═══════════════════════════════════════════════════════════════════════════════
# MIND⠶FLOW MARKER STATE (Caret Organism)
# ═══════════════════════════════════════════════════════════════════════════════

class MarkerState(Enum):
    """
    The "Caret Organism" state machine per Mind⠶Flow guide.
    
    State flow:
        dormant → idle → listening → thinking → sweeping → complete → idle
    """
    DORMANT   = "dormant"    # No field focused
    IDLE      = "idle"       # Field focused, no activity
    LISTENING = "listening"  # User is typing (burst phase)
    THINKING  = "thinking"   # Pause detected, preparing
    SWEEPING  = "sweeping"   # Marker traveling, applying fixes
    COMPLETE  = "complete"   # Sweep finished
    DISABLED  = "disabled"   # User toggled off (⌥◀)
    ERROR     = "error"      # Model failed, etc.


# Braille symbols per state — middle 2x2 grid (dots 2,3,5,6)
# Grid:  2 5
#        3 6
BRAILLE = {
    MarkerState.DORMANT:   "",
    MarkerState.IDLE:      "⠤",  # dots 3,6 — horizontal, stable
    MarkerState.LISTENING: "⠴",  # dots 3,5,6 — growing, active
    MarkerState.THINKING:  "⠦",  # dots 2,3,6 — processing
    MarkerState.SWEEPING:  "⠶",  # dots 2,3,5,6 — full, traveling
    MarkerState.COMPLETE:  "⠲",  # dots 2,5,6 — satisfied
    MarkerState.DISABLED:  "⠠",  # dot 6 — minimal
    MarkerState.ERROR:     "⠆",  # dots 2,3 — interrupted
}

# Animation frames for sweep effect (middle 2x2)
SWEEP_FRAMES = ["⠶", "⠦", "⠴", "⠲"]

# ANSI escape codes
CLEAR_LINE = "\033[2K"
CURSOR_UP = "\033[A"
DIM = "\033[2m"
BOLD = "\033[1m"
GREEN = "\033[32m"
YELLOW = "\033[33m"
ORANGE = "\033[38;5;208m"
CYAN = "\033[36m"
MAGENTA = "\033[35m"
RESET = "\033[0m"


@dataclass
class SweepState:
    """Represents an in-progress sweep animation."""
    original_text: str
    corrected_text: str
    progress: float = 0.0
    duration: float = 0.3
    
    @property
    def current_position(self) -> int:
        """Current character position of the sweep marker."""
        return int(len(self.corrected_text) * self.progress)


# ═══════════════════════════════════════════════════════════════════════════════
# MIND⠶FLOW REALTIME DEMO
# ═══════════════════════════════════════════════════════════════════════════════

class MindFlowDemo:
    """
    Mind⠶Flow realtime correction demo.
    
    Implements the Burst-Pause-Correct rhythm:
    1. BURST  — User types rapidly, trusting the system
    2. PAUSE  — Natural breathing moment (≥500ms trigger)  
    3. CORRECT — Marker travels through text, applying fixes
    4. RESUME — Seamless continuation with enhanced confidence
    """
    
    def __init__(self, config: MindTypeConfig):
        self.config = config
        self.engine = CorrectionEngine(config)
        self.text = ""
        self.last_keystroke = 0.0
        self.state = MarkerState.IDLE
        self.running = True
        self.last_correction_applied = False
        self.enabled = True  # Can be toggled with ⌥◀
        self._last_display = ""
        self._sweep: Optional[SweepState] = None
    
    def get_colored_symbol(self) -> str:
        """Get the braille symbol with appropriate color."""
        symbol = BRAILLE.get(self.state, BRAILLE[MarkerState.IDLE])
        
        colors = {
            MarkerState.IDLE:      DIM,
            MarkerState.LISTENING: CYAN,
            MarkerState.THINKING:  YELLOW,
            MarkerState.SWEEPING:  ORANGE,
            MarkerState.COMPLETE:  GREEN,
            MarkerState.DISABLED:  DIM,
            MarkerState.ERROR:     YELLOW,
        }
        color = colors.get(self.state, DIM)
        return f"{color}{symbol}{RESET}"
    
    def redraw(self, status: str = "", force: bool = False):
        """Redraw current state with braille indicator."""
        symbol = self.get_colored_symbol()
        
        if self.text:
            display = self.text
        else:
            display = f"{DIM}Start typing...{RESET}"
        
        status_str = f"  {DIM}{status}{RESET}" if status else ""
        full_line = f"{symbol} {display}{status_str}"
        
        # Only write if changed (reduces flicker)
        display_key = f"{self.state.value}|{self.text}|{status}"
        if display_key != self._last_display or force:
            self._last_display = display_key
            sys.stdout.write(f"\r{CLEAR_LINE}{full_line}")
            sys.stdout.flush()
    
    def animate_sweep(self, original: str, corrected: str):
        """
        Animate the sweep effect — marker travels through text, unveiling fixes.
        
        Per Mind⠶Flow guide:
        - Marker travels toward the caret
        - Unveils fixes as it passes
        - Trail effect (represented by color transition in terminal)
        """
        self.state = MarkerState.SWEEPING
        sweep_duration = 0.4  # seconds
        frames = 20
        frame_delay = sweep_duration / frames
        
        for i in range(frames + 1):
            progress = i / frames
            
            # Calculate current position in text
            pos = int(len(corrected) * progress)
            
            # Build display: corrected portion + remaining original
            if pos < len(corrected):
                # Show corrected text up to marker, then original after
                revealed = corrected[:pos]
                remaining_orig = original[pos:] if pos < len(original) else ""
                
                # Sweep frame animation
                sweep_symbol = SWEEP_FRAMES[i % len(SWEEP_FRAMES)]
                
                display = (
                    f"{ORANGE}{sweep_symbol}{RESET} "
                    f"{GREEN}{revealed}{RESET}"
                    f"{DIM}{remaining_orig}{RESET}"
                )
            else:
                display = f"{GREEN}⠿{RESET} {GREEN}{corrected}{RESET}"
            
            sys.stdout.write(f"\r{CLEAR_LINE}{display}")
            sys.stdout.flush()
            time.sleep(frame_delay)
        
        # Final state
        self.text = corrected
        self.state = MarkerState.COMPLETE
        self.redraw(force=True)
        
        # Brief pause to show completion
        time.sleep(0.3)
        self.state = MarkerState.IDLE
        self.redraw(force=True)
    
    def handle_key(self, key: str):
        """Handle a single keystroke."""
        self.last_keystroke = time.time()
        self.state = MarkerState.LISTENING
        self.last_correction_applied = False
        
        if key == '\x7f':  # Backspace
            self.text = self.text[:-1] if self.text else ""
        elif key == '\x17':  # Ctrl+W - delete word
            words = self.text.split()
            self.text = " ".join(words[:-1]) if words else ""
        elif key == '\x15':  # Ctrl+U - clear line
            self.text = ""
        elif key in ('\r', '\n'):  # Enter - force correction now
            if self.text.strip():
                self.do_correction(force_now=True)
        elif key.isprintable():
            self.text += key
        
        self.redraw()
    
    def do_correction(self, force_now: bool = False):
        """
        Execute a correction wave.
        
        Per Mind⠶Flow guide, this is the "CORRECT" phase of Burst-Pause-Correct.
        """
        if not self.text.strip():
            return
        
        original = self.text
        
        self.state = MarkerState.THINKING
        self.redraw("interpreting...", force=True)
        
        result = self.engine.correct(self.text)
        
        if result.success and result.text != original:
            # Animate the sweep from original to corrected
            self.animate_sweep(original, result.text)
            self.last_correction_applied = True
        elif result.success:
            # No changes needed
            self.state = MarkerState.COMPLETE
            self.redraw(f"{result.confidence:.0%} (no changes)", force=True)
            time.sleep(0.3)
            self.state = MarkerState.IDLE
            self.redraw(force=True)
            self.last_correction_applied = True
        else:
            # Low confidence - show waiting state
            self.state = MarkerState.IDLE
            self.redraw(result.reason, force=True)
    
    def toggle(self):
        """Toggle enabled state (⌥◀ per Mind⠶Flow guide)."""
        self.enabled = not self.enabled
        if self.enabled:
            self.state = MarkerState.IDLE
        else:
            self.state = MarkerState.DISABLED
        self.redraw(force=True)
    
    def run(self):
        global _original_terminal
        
        print()
        print(f"{BOLD}╔══════════════════════════════════════════════════════════════╗{RESET}")
        print(f"{BOLD}║  M I N D {CYAN}⠶{RESET}{BOLD} F L O W   R E A L T I M E                        ║{RESET}")
        print(f"{BOLD}║                                                              ║{RESET}")
        print(f"{BOLD}║  {DIM}Burst → Pause → Correct — Type at thought-speed{RESET}{BOLD}           ║{RESET}")
        print(f"{BOLD}╚══════════════════════════════════════════════════════════════╝{RESET}")
        print()
        print(f"  Type naturally. Corrections sweep through after {self.config.pause_ms}ms pause.")
        print(f"  {DIM}Enter = force now │ Ctrl+C = quit{RESET}")
        print()
        
        # Marker state guide (middle 2x2: dots 2,3,5,6)
        print(f"  {DIM}Caret organism states:{RESET}")
        print(f"    ⠤ idle   ⠴ listening   ⠦ thinking   ⠶ sweeping   ⠲ complete")
        print()
        
        print(f"  {BRAILLE[MarkerState.THINKING]} Loading model...")
        
        if not self.engine.load_model():
            print(f"  {DIM}❌ Model not found{RESET}")
            sys.exit(1)
        
        print(f"  {GREEN}✓{RESET} Model loaded (Apple Silicon Metal)")
        print()
        print("─" * 60)
        print()
        
        fd = sys.stdin.fileno()
        _original_terminal = termios.tcgetattr(fd)
        
        try:
            tty.setraw(fd)
            self.redraw()
            
            while self.running:
                # Check for input
                if select.select([sys.stdin], [], [], 0.05)[0]:
                    key = sys.stdin.read(1)
                    
                    if key == '\x03':  # Ctrl+C
                        break
                    elif key == '\x1b':  # Escape sequence
                        if select.select([sys.stdin], [], [], 0.01)[0]:
                            seq = sys.stdin.read(2)
                            # Check for ⌥◀ (Option+Left Arrow)
                            if seq == '[D':  # Left arrow - simplified toggle
                                self.toggle()
                        continue
                    
                    if not self.enabled:
                        continue  # Ignore input when disabled
                    
                    self.handle_key(key)
                else:
                    # No input - check for pause
                    if self.enabled and self.text.strip() and not self.last_correction_applied:
                        elapsed_ms = (time.time() - self.last_keystroke) * 1000
                        
                        if elapsed_ms > self.config.pause_ms:
                            # Pause detected - transition to thinking
                            if self.state == MarkerState.LISTENING:
                                self.state = MarkerState.THINKING
                                self.redraw()
                                time.sleep(0.1)
                            
                            self.do_correction()
                            
        finally:
            restore_terminal()
            print(f"\n\n{DIM}👋 Goodbye!{RESET}\n")


def main():
    # Configuration per Mind⠶Flow guide
    config = MindTypeConfig(
        min_words=3,
        similarity_threshold=0.35,
        pause_ms=500,  # Per guide: ~500ms pause trigger
        return_original_on_failure=True,
    )
    
    MindFlowDemo(config).run()


if __name__ == "__main__":
    main()
