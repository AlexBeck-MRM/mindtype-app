#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   C O R E   E N G I N E                                  ║
║                                                                              ║
║  Interprets fuzzy/garbled typing into intended meaning                       ║
║  Designed for velocity typing where words may be completely unrecognizable   ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import re
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# ═══════════════════════════════════════════════════════════════════════════════
# CONFIGURATION
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass
class MindTypeConfig:
    """
    Tunable parameters for fuzzy typing interpretation.
    
    Philosophy: Trust the LLM for word-level interpretation.
    Only reject outputs that are structurally wrong or off-topic.
    """
    
    # ─── Minimum Input ────────────────────────────────────────────────────────
    min_words: int = 3
    """Minimum words before attempting interpretation."""
    
    min_chars: int = 10
    """Minimum characters before attempting interpretation."""
    
    # ─── Structure Constraints (Macro Level) ──────────────────────────────────
    length_ratio_max: float = 1.8
    """Output can be up to 1.8x input length (allow expansion of abbreviations)."""
    
    length_ratio_min: float = 0.5
    """Output must be at least 0.5x input length."""
    
    sentence_tolerance: int = 1
    """Allow ±1 sentence difference (punctuation may be missing in input)."""
    
    # ─── Self-Review ──────────────────────────────────────────────────────────
    enable_self_review: bool = True
    """LLM verifies its interpretation makes sense."""
    
    # ─── Timing ───────────────────────────────────────────────────────────────
    pause_ms: int = 600
    """Milliseconds of pause before auto-correction (realtime mode)."""
    
    # ─── Behavior ─────────────────────────────────────────────────────────────
    return_original_on_failure: bool = True
    """If interpretation fails, return original text."""
    
    show_confidence: bool = True
    """Show confidence percentage in output."""
    
    # ─── Model ────────────────────────────────────────────────────────────────
    model_path: Optional[Path] = None
    
    def __post_init__(self):
        if self.model_path is None:
            project_root = Path(__file__).parent.parent
            # MindFlow Qwen models live in apple/Models/
            # v2 = context-aware, literal interpretation (default)
            for candidate in [
                project_root / "apple" / "Models" / "mindflow-qwen-3b-v2",
            ]:
                if candidate.exists():
                    self.model_path = candidate
                    break


DEFAULT_CONFIG = MindTypeConfig()


# ═══════════════════════════════════════════════════════════════════════════════
# PROMPTS - Optimized for Fuzzy Interpretation
# ═══════════════════════════════════════════════════════════════════════════════

INTERPRETATION_PROMPT = """You interpret garbled/fuzzy typing into what the user intended to write.

The user types VERY fast, so:
- Letters may be transposed (teh → the)
- Letters may be missing (bcause → because)
- Keys may be adjacent wrong keys (wprds → words)
- Words may be run together (onceupon → once upon)
- Words may be split (cre ate → create)
- Words may be completely garbled but sound similar

Your job: Figure out what they MEANT to type.

RULES:
1. Output the interpreted text, nothing else
2. Keep the same meaning and intent
3. Keep roughly the same structure (sentence count)
4. Fix ALL the typing errors
5. Do NOT add new ideas or change the topic
6. Do NOT respond conversationally

Example:
Input: "once iualpio a time tbere weas a prince"
Output: "Once upon a time there was a prince"

Now interpret this:"""


REVIEW_PROMPT = """You are checking if an interpretation of garbled typing is reasonable.

ORIGINAL (garbled): {original}

INTERPRETATION: {interpretation}

Is this interpretation REASONABLE? Consider:
- Does it preserve the apparent meaning/topic?
- Does it have similar structure (sentence count)?
- Does it make sense as what someone typing fast might have meant?

Answer ONLY: REASONABLE or UNREASONABLE"""


# ═══════════════════════════════════════════════════════════════════════════════
# VALIDATION - Structural Only (for fuzzy typing)
# ═══════════════════════════════════════════════════════════════════════════════

# Patterns that indicate LLM is responding conversationally instead of interpreting
REJECTION_PATTERNS = [
    r"^i'?m not sure",
    r"^i don'?t understand",
    r"^i can'?t",
    r"^sorry",
    r"^please provide",
    r"^what do you mean",
    r"^could you",
    r"^can you",
    r"^it seems like",
    r"^i think you",
    r"^this (text|input|message)",
    r"^the (text|input|message)",
]


def count_sentences(text: str) -> int:
    """Count sentences (handles missing punctuation gracefully)."""
    # Count by terminal punctuation
    explicit = len(re.findall(r'[.!?]+', text))
    if explicit > 0:
        return explicit
    # If no punctuation, estimate by capitalized words after spaces
    caps = len(re.findall(r'\.\s+[A-Z]|^\s*[A-Z]', text))
    return max(1, caps)


@dataclass
class ValidationResult:
    is_valid: bool
    confidence: float
    reason: str
    
    def __bool__(self):
        return self.is_valid


def validate_interpretation(
    input_text: str,
    output_text: str,
    config: MindTypeConfig = DEFAULT_CONFIG
) -> ValidationResult:
    """
    Validate interpretation using STRUCTURAL checks only.
    We trust the LLM for word-level interpretation.
    """
    if not output_text or not output_text.strip():
        return ValidationResult(False, 0.0, "empty output")
    
    input_clean = input_text.strip()
    output_clean = output_text.strip()
    
    # ─── Check 1: Conversational Response ─────────────────────────────────────
    output_lower = output_clean.lower()
    for pattern in REJECTION_PATTERNS:
        if re.search(pattern, output_lower):
            return ValidationResult(False, 0.0, "conversational response")
    
    # ─── Check 2: Length Ratio ────────────────────────────────────────────────
    if len(input_clean) > 0:
        ratio = len(output_clean) / len(input_clean)
        if ratio > config.length_ratio_max:
            return ValidationResult(False, 0.0, f"too long ({ratio:.1f}x)")
        if ratio < config.length_ratio_min:
            return ValidationResult(False, 0.0, f"too short ({ratio:.1f}x)")
    
    # ─── Check 3: Sentence Count ──────────────────────────────────────────────
    input_sentences = count_sentences(input_clean)
    output_sentences = count_sentences(output_clean)
    diff = abs(output_sentences - input_sentences)
    
    if diff > config.sentence_tolerance:
        return ValidationResult(
            False, 0.0,
            f"structure changed ({input_sentences}→{output_sentences} sentences)"
        )
    
    # ─── Check 4: Not Just Echoing Garbage ────────────────────────────────────
    # If output looks like garbled input, LLM failed to interpret
    # Check if output has too many non-word sequences
    non_words = len(re.findall(r'\b[bcdfghjklmnpqrstvwxz]{4,}\b', output_clean.lower()))
    if non_words > 2:
        return ValidationResult(False, 0.0, "output still garbled")
    
    # Passed all checks - calculate confidence based on structure match
    length_score = 1.0 - abs(1.0 - ratio) * 0.5 if len(input_clean) > 0 else 0.5
    sentence_score = 1.0 if diff == 0 else 0.7
    confidence = (length_score + sentence_score) / 2
    
    return ValidationResult(True, confidence, "valid")


# ═══════════════════════════════════════════════════════════════════════════════
# CORRECTION ENGINE
# ═══════════════════════════════════════════════════════════════════════════════

class CorrectionEngine:
    """
    Fuzzy typing interpreter with optional self-review.
    
    Pass 1: Interpret garbled text
    Pass 2: (Optional) Self-review - is interpretation reasonable?
    Pass 3: Structural validation
    """
    
    def __init__(self, config: MindTypeConfig = None):
        self.config = config or MindTypeConfig()
        self.model = None
        self.tokenizer = None
        self._loaded = False
    
    def load_model(self) -> bool:
        if self._loaded:
            return True
        if not self.config.model_path or not self.config.model_path.exists():
            return False
        from mlx_lm import load
        self.model, self.tokenizer = load(str(self.config.model_path))
        self._loaded = True
        return True
    
    @property
    def is_loaded(self) -> bool:
        return self._loaded
    
    def _generate(self, system: str, user: str, max_tokens: int = 250) -> str:
        """Raw LLM generation."""
        from mlx_lm import generate
        prompt = f"<|im_start|>system\n{system}<|im_end|>\n<|im_start|>user\n{user}<|im_end|>\n<|im_start|>assistant\n"
        response = generate(self.model, self.tokenizer, prompt=prompt, max_tokens=max_tokens)
        output = response.split("<|im_start|>assistant")[-1].split("<|im_end|>")[0].strip()
        # Take first paragraph only (avoid runaway generation)
        return output.split("\n\n")[0].strip()
    
    def _interpret(self, text: str) -> str:
        """Pass 1: Interpret garbled text."""
        return self._generate(INTERPRETATION_PROMPT, text)
    
    def _review(self, original: str, interpretation: str) -> bool:
        """Pass 2: Self-review - is this reasonable?"""
        prompt = REVIEW_PROMPT.format(original=original, interpretation=interpretation)
        response = self._generate(
            "Answer ONLY with REASONABLE or UNREASONABLE.",
            prompt,
            max_tokens=20
        )
        return "UNREASONABLE" not in response.upper()
    
    def correct(self, text: str) -> 'CorrectionResult':
        """
        Interpret fuzzy/garbled typing.
        """
        # Auto-load model if needed
        if not self._loaded:
            if not self.load_model():
                return CorrectionResult(
                    success=False,
                    text=text,
                    confidence=0.0,
                    reason="model not found"
                )
        
        text = text.strip()
        
        # Check minimum requirements
        word_count = len(text.split())
        if word_count < self.config.min_words:
            return CorrectionResult(
                success=False,
                text=text if self.config.return_original_on_failure else None,
                confidence=0.0,
                reason=f"need {self.config.min_words - word_count} more words"
            )
        
        if len(text) < self.config.min_chars:
            return CorrectionResult(
                success=False,
                text=text if self.config.return_original_on_failure else None,
                confidence=0.0,
                reason="need more text"
            )
        
        # ─── Pass 1: Interpret ────────────────────────────────────────────────
        try:
            interpreted = self._interpret(text)
        except Exception as e:
            return CorrectionResult(
                success=False,
                text=text if self.config.return_original_on_failure else None,
                confidence=0.0,
                reason="interpretation error"
            )
        
        # If no change needed
        if interpreted.lower().strip() == text.lower().strip():
            return CorrectionResult(
                success=True,
                text=text,
                confidence=1.0,
                reason="no changes needed"
            )
        
        # ─── Pass 2: Self-Review ──────────────────────────────────────────────
        if self.config.enable_self_review:
            try:
                is_reasonable = self._review(text, interpreted)
                if not is_reasonable:
                    return CorrectionResult(
                        success=False,
                        text=text if self.config.return_original_on_failure else None,
                        confidence=0.0,
                        reason="self-review: unreasonable"
                    )
            except:
                pass  # Continue if review fails
        
        # ─── Pass 3: Structural Validation ────────────────────────────────────
        validation = validate_interpretation(text, interpreted, self.config)
        
        if validation.is_valid:
            return CorrectionResult(
                success=True,
                text=interpreted,
                confidence=validation.confidence,
                reason=validation.reason
            )
        else:
            return CorrectionResult(
                success=False,
                text=text if self.config.return_original_on_failure else None,
                confidence=validation.confidence,
                reason=validation.reason
            )


@dataclass
class CorrectionResult:
    success: bool
    text: Optional[str]
    confidence: float
    reason: str
    
    def __bool__(self):
        return self.success


# ═══════════════════════════════════════════════════════════════════════════════
# PRESETS
# ═══════════════════════════════════════════════════════════════════════════════

# Strict: More validation, less hallucination risk
STRICT_CONFIG = MindTypeConfig(
    min_words=4,
    length_ratio_max=1.5,
    length_ratio_min=0.6,
    enable_self_review=True,
)

# Balanced: Default settings
BALANCED_CONFIG = MindTypeConfig()

# Lenient: Trust LLM more, faster
LENIENT_CONFIG = MindTypeConfig(
    min_words=2,
    length_ratio_max=2.0,
    length_ratio_min=0.4,
    enable_self_review=False,
)
