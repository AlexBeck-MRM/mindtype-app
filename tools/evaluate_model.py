#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M O D E L   E V A L U A T I O N   S C R I P T                               ║
║                                                                              ║
║  Compare model performance before and after fine-tuning                      ║
║  Uses held-out test cases to measure interpretation accuracy                 ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import json
import time
from pathlib import Path
from dataclasses import dataclass
from typing import List, Optional
import difflib

# ═══════════════════════════════════════════════════════════════════════════════
# TEST CASES - Gold standard for evaluation
# These should NEVER be in the training data
# ═══════════════════════════════════════════════════════════════════════════════

# Format: (corrupted_input, expected_output, difficulty, description)
# Focus on FULL SENTENCES - real typing scenarios, not isolated words
TEST_CASES = [
    # LIGHT - Standard typos in context
    ("I was writting a lettr to my freind about the meeting", 
     "I was writing a letter to my friend about the meeting", 
     "light", "common typos in sentence"),
    ("Plese send me the docuemnts by tomorow morning", 
     "Please send me the documents by tomorrow morning", 
     "light", "adjacent key errors"),
    ("The reserach team discoverd an intresting patern in the data",
     "The research team discovered an interesting pattern in the data",
     "light", "academic writing typos"),
    
    # MEDIUM - Missing vowels and abbreviations
    ("th meetng ws rescheduld to thrsday bcause of the storm", 
     "the meeting was rescheduled to Thursday because of the storm", 
     "medium", "missing vowels"),
    ("we nd to discss th prject tmrrw with the client", 
     "we need to discuss the project tomorrow with the client", 
     "medium", "abbreviated words"),
    ("cn u reviw ths report and snd feedback by friday",
     "can you review this report and send feedback by Friday",
     "medium", "business shorthand"),
    
    # HEAVY - Significant garbling but context helps
    ("oncee iupon a tiem there ws a prince who wantd to chng the wrld", 
     "once upon a time there was a prince who wanted to change the world", 
     "heavy", "fairy tale with hand shift"),
    ("th msses wr amzd by th visionary's prfrmance at the confrence", 
     "the masses were amazed by the visionary's performance at the conference", 
     "heavy", "missing letters in context"),
    ("plz snd th rprt asap its urgnt we nd it for th mtng", 
     "please send the report asap it's urgent we need it for the meeting", 
     "heavy", "heavy abbreviation"),
    
    # FUZZY - Your example case and similar
    ("once iualpio a time tbere weas a prince tgbhat wanted to crezt e a new ways to write",
     "Once upon a time there was a prince who wanted to create a new way to write",
     "fuzzy", "original example - hand shifted"),
    ("the msaasexd has no idea who he wa showever he was a visionsary that create d a nw tool",
     "the masses had no idea who he was however he was a visionary that created a new tool",
     "fuzzy", "heavily garbled narrative"),
    ("th algoritm prcsss th dat vry effciently nd prdcs accurt rslts",
     "the algorithm processes the data very efficiently and produces accurate results",
     "fuzzy", "technical writing garbled"),
    
    # STRUCTURAL - Sentence preservation
    ("frst do ths. thn do tht. fnlly chck evrythng bfore submtng.",
     "First do this. Then do that. Finally check everything before submitting.",
     "structural", "multi-sentence instructions"),
    ("wat do u thnk abt the prposal? cn u hlp me improv it?",
     "What do you think about the proposal? Can you help me improve it?",
     "structural", "questions"),
    ("the prjct is almst done. we jst need to finsh testing. then we cn deploy.",
     "The project is almost done. We just need to finish testing. Then we can deploy.",
     "structural", "three sentences"),
]


@dataclass
class EvalResult:
    input_text: str
    expected: str
    actual: str
    difficulty: str
    description: str
    similarity: float
    exact_match: bool
    time_ms: float


def calculate_similarity(expected: str, actual: str) -> float:
    """Calculate similarity between expected and actual output."""
    # Normalize: lowercase, strip, collapse whitespace
    exp_norm = ' '.join(expected.lower().split())
    act_norm = ' '.join(actual.lower().split())
    
    # Use difflib for sequence matching
    return difflib.SequenceMatcher(None, exp_norm, act_norm).ratio()


def evaluate_model(model_path: str, test_cases: List[tuple] = None) -> List[EvalResult]:
    """Evaluate a model against test cases."""
    from mlx_lm import load, generate
    
    if test_cases is None:
        test_cases = TEST_CASES
    
    print(f"Loading model from {model_path}...")
    model, tokenizer = load(model_path)
    print("✓ Model loaded\n")
    
    system_prompt = """You interpret garbled/fuzzy typing into what the user intended to write.
Output the interpreted text, nothing else. Keep the same meaning and structure."""
    
    results = []
    
    for corrupted, expected, difficulty, description in test_cases:
        prompt = f"<|im_start|>system\n{system_prompt}<|im_end|>\n<|im_start|>user\n{corrupted}<|im_end|>\n<|im_start|>assistant\n"
        
        start_time = time.time()
        response = generate(model, tokenizer, prompt=prompt, max_tokens=100)
        elapsed_ms = (time.time() - start_time) * 1000
        
        # Extract assistant response
        actual = response.split("<|im_start|>assistant")[-1].split("<|im_end|>")[0].strip()
        actual = actual.split("\n")[0].strip()  # First line only
        
        similarity = calculate_similarity(expected, actual)
        exact_match = expected.lower().strip() == actual.lower().strip()
        
        results.append(EvalResult(
            input_text=corrupted,
            expected=expected,
            actual=actual,
            difficulty=difficulty,
            description=description,
            similarity=similarity,
            exact_match=exact_match,
            time_ms=elapsed_ms
        ))
    
    return results


def print_results(results: List[EvalResult], model_name: str = "Model"):
    """Print evaluation results in a nice format."""
    print(f"\n{'═' * 70}")
    print(f"  {model_name} Evaluation Results")
    print(f"{'═' * 70}\n")
    
    # Group by difficulty
    by_difficulty = {}
    for r in results:
        if r.difficulty not in by_difficulty:
            by_difficulty[r.difficulty] = []
        by_difficulty[r.difficulty].append(r)
    
    total_similarity = 0
    total_exact = 0
    total_time = 0
    
    for difficulty in ["light", "medium", "heavy", "extreme", "structural"]:
        if difficulty not in by_difficulty:
            continue
        
        group = by_difficulty[difficulty]
        avg_sim = sum(r.similarity for r in group) / len(group)
        exact_count = sum(1 for r in group if r.exact_match)
        avg_time = sum(r.time_ms for r in group) / len(group)
        
        total_similarity += sum(r.similarity for r in group)
        total_exact += exact_count
        total_time += sum(r.time_ms for r in group)
        
        print(f"─── {difficulty.upper()} ({len(group)} cases) ───")
        print(f"  Avg Similarity: {avg_sim:.1%}")
        print(f"  Exact Matches:  {exact_count}/{len(group)}")
        print(f"  Avg Time:       {avg_time:.0f}ms")
        print()
        
        # Show individual results
        for r in group:
            status = "✓" if r.exact_match else "○" if r.similarity > 0.8 else "✗"
            print(f"  {status} [{r.similarity:.0%}] {r.description}")
            print(f"    IN:  {r.input_text}")
            print(f"    EXP: {r.expected}")
            if not r.exact_match:
                print(f"    GOT: {r.actual}")
            print()
    
    # Overall stats
    overall_sim = total_similarity / len(results)
    overall_exact = total_exact / len(results)
    overall_time = total_time / len(results)
    
    print(f"{'═' * 70}")
    print(f"  OVERALL SCORE")
    print(f"{'═' * 70}")
    print(f"  Average Similarity: {overall_sim:.1%}")
    print(f"  Exact Match Rate:   {overall_exact:.1%} ({total_exact}/{len(results)})")
    print(f"  Average Latency:    {overall_time:.0f}ms")
    print()
    
    return {
        "similarity": overall_sim,
        "exact_match_rate": overall_exact,
        "avg_latency_ms": overall_time
    }


def compare_models(base_path: str, finetuned_path: str):
    """Compare base model vs fine-tuned model."""
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Model Comparison: Base vs Fine-tuned                        ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    print("Evaluating BASE model...")
    base_results = evaluate_model(base_path)
    base_scores = print_results(base_results, "BASE (Pre-training)")
    
    print("\n" + "═" * 70 + "\n")
    
    print("Evaluating FINE-TUNED model...")
    ft_results = evaluate_model(finetuned_path)
    ft_scores = print_results(ft_results, "FINE-TUNED (Post-training)")
    
    # Comparison
    print("\n" + "═" * 70)
    print("  COMPARISON")
    print("═" * 70)
    
    sim_delta = ft_scores["similarity"] - base_scores["similarity"]
    exact_delta = ft_scores["exact_match_rate"] - base_scores["exact_match_rate"]
    
    sim_arrow = "↑" if sim_delta > 0 else "↓" if sim_delta < 0 else "→"
    exact_arrow = "↑" if exact_delta > 0 else "↓" if exact_delta < 0 else "→"
    
    print(f"  Similarity:   {base_scores['similarity']:.1%} → {ft_scores['similarity']:.1%} ({sim_arrow} {abs(sim_delta):.1%})")
    print(f"  Exact Match:  {base_scores['exact_match_rate']:.1%} → {ft_scores['exact_match_rate']:.1%} ({exact_arrow} {abs(exact_delta):.1%})")
    
    if sim_delta > 0.05:
        print("\n  ✓ Fine-tuning IMPROVED the model")
    elif sim_delta < -0.05:
        print("\n  ✗ Fine-tuning DEGRADED the model - consider reverting")
    else:
        print("\n  ○ Fine-tuning had minimal effect")


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Evaluate MindType models")
    parser.add_argument("--model", type=str, help="Path to model to evaluate")
    parser.add_argument("--compare", nargs=2, metavar=("BASE", "FINETUNED"), 
                       help="Compare two models")
    parser.add_argument("--save", type=str, help="Save results to JSON file")
    args = parser.parse_args()
    
    if args.compare:
        compare_models(args.compare[0], args.compare[1])
    elif args.model:
        results = evaluate_model(args.model)
        scores = print_results(results, Path(args.model).name)
        
        if args.save:
            with open(args.save, 'w') as f:
                json.dump({
                    "model": args.model,
                    "scores": scores,
                    "results": [
                        {
                            "input": r.input_text,
                            "expected": r.expected,
                            "actual": r.actual,
                            "similarity": r.similarity,
                            "exact_match": r.exact_match,
                            "difficulty": r.difficulty
                        }
                        for r in results
                    ]
                }, f, indent=2)
            print(f"✓ Results saved to {args.save}")
    else:
        # Default: evaluate current fine-tuned model
        project_root = Path(__file__).parent.parent
        default_model = project_root / "tools" / "mlx_output" / "fused_v2"
        if default_model.exists():
            results = evaluate_model(str(default_model))
            print_results(results, "fused_v2")
        else:
            print("No model found. Use --model to specify a model path.")


if __name__ == "__main__":
    main()

