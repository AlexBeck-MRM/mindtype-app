#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   T R A I N I N G   D A T A   G E N E R A T O R          ║
║                                                                              ║
║  Generates realistic typos from clean text for fine-tuning LLMs.            ║
║  Based on dyslexia research, keyboard layout, and common error patterns.    ║
╚══════════════════════════════════════════════════════════════════════════════╝

Usage:
    python generate_training_data.py --input clean_text.txt --output training_data.jsonl
    python generate_training_data.py --samples 10000  # Generate from built-in corpus

Output format (JSONL):
    {"input": "Teh quikc brown fox", "output": "The quick brown fox", "error_types": ["transpose", "adjacent"]}
"""

import argparse
import json
import random
import re
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Tuple, Optional, Set
from collections import defaultdict

# =============================================================================
# KEYBOARD LAYOUT DATA
# =============================================================================

# QWERTY keyboard adjacency map (which keys are next to each other)
QWERTY_ADJACENT = {
    # Top row
    'q': 'wa12', 'w': 'qeas23', 'e': 'wrsd34', 'r': 'etdf45', 't': 'ryfg56',
    'y': 'tugh67', 'u': 'yijh78', 'i': 'uokj89', 'o': 'iplk90', 'p': 'ol0',
    # Middle row
    'a': 'qwsz', 's': 'awedxz', 'd': 'serfcx', 'f': 'drtgvc', 'g': 'ftyhbv',
    'h': 'gyujnb', 'j': 'huikmn', 'k': 'jiolm', 'l': 'kop',
    # Bottom row
    'z': 'asx', 'x': 'zsdc', 'c': 'xdfv', 'v': 'cfgb', 'b': 'vghn',
    'n': 'bhjm', 'm': 'njk',
    # Numbers (common on mobile)
    '1': 'q2', '2': 'w13', '3': 'e24', '4': 'r35', '5': 't46',
    '6': 'y57', '7': 'u68', '8': 'i79', '9': 'o80', '0': 'p9',
}

# Keys that are commonly confused (visual similarity)
VISUAL_CONFUSIONS = {
    'b': 'd', 'd': 'b', 'p': 'q', 'q': 'p',  # Dyslexia common
    'm': 'n', 'n': 'm', 'u': 'v', 'v': 'u',
    'i': 'l', 'l': 'i', 'o': '0', '0': 'o',
    'g': 'q', 'a': 'e', 'e': 'a',
}

# Common phonetic substitutions
PHONETIC_SUBSTITUTIONS = {
    'ph': 'f', 'f': 'ph',
    'tion': 'shun', 'sion': 'shun',
    'ght': 't',
    'ck': 'k', 'k': 'ck',
    'ie': 'ei', 'ei': 'ie',  # i before e confusion
}

# =============================================================================
# COMMON ERROR PATTERNS (from dyslexia research)
# =============================================================================

# Words with known common misspellings
COMMON_MISSPELLINGS = {
    # Word -> list of common misspellings
    'the': ['teh', 'hte', 'th'],
    'and': ['adn', 'nad', 'annd'],
    'that': ['taht', 'tath', 'htat'],
    'with': ['wiht', 'wtih', 'wth'],
    'have': ['hvae', 'ahve', 'hve'],
    'this': ['thsi', 'tihs', 'htis'],
    'from': ['form', 'fom', 'frmo'],
    'they': ['tehy', 'htey', 'tey'],
    'been': ['bene', 'ben', 'eben'],
    'said': ['siad', 'sadi', 'sid'],
    'because': ['becuase', 'becasue', 'beacuse', 'becuz'],
    'definitely': ['definately', 'definatly', 'defintely', 'defiantly'],
    'receive': ['recieve', 'recive', 'receve'],
    'believe': ['beleive', 'belive', 'beleave'],
    'weird': ['wierd', 'werd', 'werid'],
    'friend': ['freind', 'frend', 'freend'],
    'which': ['wich', 'whcih', 'whihc'],
    'their': ['thier', 'ther', 'tehir'],
    'would': ['woudl', 'wuold', 'woud'],
    'could': ['coudl', 'cuold', 'coud'],
    'should': ['shoudl', 'shuold', 'shoud'],
    'people': ['poeple', 'peopel', 'ppl'],
    'through': ['thorugh', 'trough', 'thru'],
    'thought': ['thougt', 'thougth', 'thot'],
    'something': ['somthing', 'somehting', 'smth'],
    'different': ['diffrent', 'diferent', 'diffrent'],
    'important': ['importnat', 'importent', 'improtant'],
    'technology': ['technolgy', 'techonology', 'technmology'],
    'experience': ['experiance', 'expereince', 'expreience'],
    'environment': ['enviroment', 'enviornment', 'envrionment'],
    'government': ['goverment', 'governmnet', 'govenrment'],
    'necessary': ['neccessary', 'necesary', 'neccesary'],
    'immediately': ['immediatly', 'imediately', 'immidiatley'],
    'tomorrow': ['tommorow', 'tommorrow', 'tomorow'],
    'together': ['togehter', 'togather', 'togheter'],
    'beautiful': ['beatiful', 'beutiful', 'beauitful'],
    'successful': ['succesful', 'successfull', 'sucessful'],
    'beginning': ['begining', 'beggining', 'begginning'],
    'writing': ['writting', 'writng', 'wrtiting'],
    'probably': ['probaly', 'porbably', 'prolly'],
}

# Abbreviation expansions (velocity mode)
ABBREVIATIONS = {
    'th': 'the',
    'tht': 'that',
    'wth': 'with',
    'hv': 'have',
    'ths': 'this',
    'frm': 'from',
    'thy': 'they',
    'bn': 'been',
    'sd': 'said',
    'bc': 'because',
    'def': 'definitely',
    'rcv': 'receive',
    'blv': 'believe',
    'frd': 'friend',
    'wch': 'which',
    'thr': 'their',
    'wld': 'would',
    'cld': 'could',
    'shd': 'should',
    'ppl': 'people',
    'thru': 'through',
    'thot': 'thought',
    'smth': 'something',
    'diff': 'different',
    'imp': 'important',
    'tech': 'technology',
    'exp': 'experience',
    'env': 'environment',
    'gov': 'government',
    'nec': 'necessary',
    'imm': 'immediately',
    'tmrw': 'tomorrow',
    'tgt': 'together',
    'prob': 'probably',
    # Domain-specific (legal)
    'defdnt': 'defendant',
    'plntff': 'plaintiff',
    'contrct': 'contract',
    'evdnce': 'evidence',
    'testmny': 'testimony',
    'crt': 'court',
    'jdge': 'judge',
    # Domain-specific (finance)
    'rvn': 'revenue',
    'grwth': 'growth',
    'invstmt': 'investment',
    'rtrns': 'returns',
    'stk': 'stock',
    'mkt': 'market',
}

# =============================================================================
# SAMPLE CLEAN TEXT CORPUS (200+ diverse sentences)
# =============================================================================

SAMPLE_CORPUS = [
    # =========================================================================
    # EVERYDAY COMMUNICATION
    # =========================================================================
    "The quick brown fox jumps over the lazy dog.",
    "I was writing a letter to my friend because I believe it's necessary to express my feelings.",
    "This technology is amazing and could change everything we know about communication.",
    "I'm not sure if this world is ready for this type of innovation.",
    "The results are definitely weird but I can't help noticing the pattern.",
    "We should probably think about this more carefully before making a decision.",
    "The meeting has been rescheduled to tomorrow afternoon.",
    "I received your message and will respond as soon as possible.",
    "The experience was different from what I expected.",
    "This is something important that we need to discuss immediately.",
    "Can you please send me the document by the end of the day?",
    "I thought about what you said and I think you're right.",
    "Let me know when you're available to talk about this.",
    "Thanks for getting back to me so quickly.",
    "I appreciate your help with this project.",
    "Sorry for the late reply, I've been really busy lately.",
    "Just wanted to follow up on our conversation from yesterday.",
    "Looking forward to hearing from you soon.",
    "Please let me know if you have any questions.",
    "I'll get back to you as soon as I have more information.",
    "Would it be possible to reschedule our meeting?",
    "I completely understand your concern about this issue.",
    "Thank you for bringing this to my attention.",
    "I wanted to check in and see how things are going.",
    "Feel free to reach out if you need anything else.",
    
    # =========================================================================
    # ACADEMIC & SCIENTIFIC (Maya persona)
    # =========================================================================
    "The research shows that environmental sustainability practices are necessary for long-term success.",
    "The experimental hypothesis was validated through rigorous testing procedures.",
    "The methodology employed in this study demonstrates significant improvements.",
    "Our analysis reveals important correlations between the variables.",
    "The theoretical framework provides a foundation for future research.",
    "The literature review encompasses studies from the past decade.",
    "Statistical significance was achieved at the point zero five level.",
    "The sample size was determined using power analysis calculations.",
    "Qualitative data was collected through semi-structured interviews.",
    "The findings suggest a paradigm shift in our understanding of the phenomenon.",
    "Peer review feedback indicated several areas for improvement.",
    "The bibliography includes both primary and secondary sources.",
    "Cross-sectional analysis revealed unexpected demographic patterns.",
    "The control group showed no significant deviation from baseline measurements.",
    "Longitudinal studies are necessary to confirm these preliminary findings.",
    "The dissertation committee approved the research proposal unanimously.",
    "Citation analysis demonstrates the impact of the original publication.",
    "The abstract summarizes the key findings and methodology.",
    "Interdisciplinary collaboration enhanced the scope of the investigation.",
    "The appendix contains supplementary materials and raw data tables.",
    "Ethical approval was obtained from the institutional review board.",
    "The hypothesis was derived from existing theoretical models.",
    "Replication studies have confirmed the validity of these results.",
    "The conclusion synthesizes findings from multiple research streams.",
    "Quantitative methods were supplemented with qualitative observations.",
    
    # =========================================================================
    # BUSINESS & PROFESSIONAL (Carlos/Emma personas)
    # =========================================================================
    "The financial analysis shows strong management and development strategy.",
    "Our quarterly revenue growth exceeded expectations across all segments.",
    "The investment returns demonstrate the effectiveness of our approach.",
    "We need to schedule a meeting to discuss the project timeline.",
    "The client requested additional documentation for the contract.",
    "Please find attached the quarterly report for your review.",
    "The budget proposal requires approval from senior management.",
    "Our competitive analysis indicates significant market opportunity.",
    "The stakeholder presentation has been scheduled for next week.",
    "Performance metrics show improvement across all key indicators.",
    "The strategic initiative aligns with our long-term objectives.",
    "Resource allocation decisions will be finalized by month end.",
    "The compliance audit revealed no significant issues.",
    "Customer satisfaction scores have increased substantially.",
    "The marketing campaign generated impressive engagement rates.",
    "Supply chain disruptions have impacted delivery schedules.",
    "The profit margin has improved compared to last quarter.",
    "Human resources is coordinating the onboarding process.",
    "The vendor contract negotiations are progressing smoothly.",
    "Quality assurance testing is scheduled to begin tomorrow.",
    "The project scope has been expanded to include additional features.",
    "Risk assessment indicates moderate exposure to market volatility.",
    "The organizational restructuring will be implemented gradually.",
    "Employee feedback surveys show high levels of job satisfaction.",
    "The partnership agreement includes favorable terms for both parties.",
    
    # =========================================================================
    # LEGAL (Marcus persona - speed demon)
    # =========================================================================
    "The defendant claimed the contract was invalid and the evidence supports this.",
    "The plaintiff filed a motion for summary judgment yesterday.",
    "The court ruled in favor of the defense based on the testimony.",
    "The evidence presented was insufficient to establish liability.",
    "The settlement agreement was reached after extensive negotiations.",
    "The jury deliberated for three days before reaching a verdict.",
    "Witness testimony contradicted the allegations made by the prosecution.",
    "The appellate court overturned the lower court's decision.",
    "Discovery documents revealed previously undisclosed communications.",
    "The statute of limitations has expired for this particular claim.",
    "Legal precedent supports the argument presented by counsel.",
    "The deposition transcript contains several key admissions.",
    "Breach of fiduciary duty was alleged in the complaint.",
    "The arbitration clause requires disputes to be resolved privately.",
    "Due diligence review uncovered potential regulatory concerns.",
    "The affidavit was notarized and submitted to the court.",
    "Cross-examination revealed inconsistencies in the witness account.",
    "The injunction prevents the defendant from continuing operations.",
    "Intellectual property rights are central to this litigation.",
    "The retainer agreement outlines the scope of legal services.",
    "Mediation failed to produce a mutually acceptable resolution.",
    "The subpoena requires production of all relevant documents.",
    "Constitutional rights were allegedly violated during the arrest.",
    "The verdict was appealed on procedural grounds.",
    "Attorney-client privilege protects these communications.",
    
    # =========================================================================
    # FINANCE & DATA (Priya persona)
    # =========================================================================
    "High revenue growth in the tech sector with strong investment returns.",
    "The algorithm calculates risk-adjusted returns using modern portfolio theory.",
    "Quarterly earnings exceeded analyst expectations by fifteen percent.",
    "The correlation coefficient indicates a strong positive relationship.",
    "Market volatility has increased following the policy announcement.",
    "Dividend yield remains attractive relative to fixed income alternatives.",
    "The regression analysis identifies key drivers of performance.",
    "Asset allocation strategies should consider current valuations.",
    "The price to earnings ratio suggests the stock is undervalued.",
    "Cash flow projections indicate sustainable growth trajectory.",
    "The beta coefficient measures systematic risk exposure.",
    "Sector rotation strategies have outperformed the benchmark.",
    "The Sharpe ratio demonstrates superior risk-adjusted performance.",
    "Quantitative models incorporate multiple data sources.",
    "The moving average crossover signals a potential trend reversal.",
    "Fundamental analysis supports the bullish thesis.",
    "The yield curve inversion historically precedes recessions.",
    "Portfolio rebalancing should occur on a quarterly basis.",
    "Technical indicators suggest overbought conditions.",
    "The discounted cash flow model implies significant upside.",
    "Momentum strategies have generated alpha consistently.",
    "The standard deviation measures return volatility.",
    "Backtesting results validate the trading strategy.",
    "The efficient frontier illustrates optimal portfolio combinations.",
    "Market capitalization weighted indices dominate passive investing.",
    
    # =========================================================================
    # CREATIVE & CASUAL (James persona)
    # =========================================================================
    "I think this is kinda cool but also a bit scary when you think about it.",
    "We had an amazing time at the concert last night.",
    "The movie was surprisingly good despite the mixed reviews.",
    "I'm feeling tired today but still want to finish this project.",
    "Let's grab coffee sometime and catch up on everything.",
    "The sunset was absolutely beautiful from the rooftop.",
    "I've been meaning to tell you about what happened last weekend.",
    "Sometimes I wonder what life would be like in a different city.",
    "The restaurant downtown has the best pizza I've ever tasted.",
    "I finished reading that book you recommended and loved it.",
    "The weather has been perfect for outdoor activities lately.",
    "I'm thinking about taking a vacation somewhere tropical.",
    "The new album by that band is actually pretty great.",
    "I've been trying to exercise more but it's hard to stay motivated.",
    "The party was fun even though not many people showed up.",
    "I can't believe how fast this year has gone by.",
    "The coffee shop on the corner makes an excellent latte.",
    "I've been watching that show everyone's talking about.",
    "The hiking trail was more challenging than I expected.",
    "I'm excited about the upcoming holiday weekend.",
    "The neighborhood has changed so much over the years.",
    "I've been meaning to learn how to cook more elaborate meals.",
    "The garden is finally starting to bloom after all that rain.",
    "I met some interesting people at the networking event.",
    "The podcast episode about history was really fascinating.",
    
    # =========================================================================
    # TECHNOLOGY & SOFTWARE
    # =========================================================================
    "The algorithm processes the data in real-time using parallel computation.",
    "The system architecture supports scalable deployment across multiple servers.",
    "The user interface was redesigned for better accessibility.",
    "The database query optimization reduced response time significantly.",
    "The API endpoint handles authentication and authorization seamlessly.",
    "The machine learning model achieved ninety-five percent accuracy.",
    "Cloud infrastructure enables rapid scaling during peak demand.",
    "The microservices architecture improves system maintainability.",
    "Continuous integration pipelines automate the testing process.",
    "The encryption protocol ensures secure data transmission.",
    "Version control enables collaborative development workflows.",
    "The caching layer significantly improves application performance.",
    "Load balancing distributes traffic across multiple instances.",
    "The debugging process identified a memory leak in the application.",
    "Containerization simplifies deployment across different environments.",
    "The framework provides robust error handling capabilities.",
    "Asynchronous processing improves system responsiveness.",
    "The monitoring dashboard displays real-time performance metrics.",
    "Code review practices help maintain quality standards.",
    "The documentation includes comprehensive API reference guides.",
    "Automated backups ensure data recovery capabilities.",
    "The configuration management system tracks infrastructure changes.",
    "Security patches should be applied promptly to prevent vulnerabilities.",
    "The logging system captures detailed diagnostic information.",
    "Performance profiling revealed bottlenecks in the rendering pipeline.",
    
    # =========================================================================
    # HEALTHCARE & MEDICAL
    # =========================================================================
    "The patient's symptoms indicate a possible respiratory infection.",
    "Blood pressure readings have been consistently elevated.",
    "The diagnostic imaging revealed no significant abnormalities.",
    "Medication adherence is essential for effective treatment outcomes.",
    "The surgical procedure was completed without complications.",
    "Follow-up appointments should be scheduled within two weeks.",
    "The laboratory results confirm the preliminary diagnosis.",
    "Physical therapy exercises will help with rehabilitation.",
    "The vaccination schedule should be followed as recommended.",
    "Chronic conditions require ongoing management and monitoring.",
    "The specialist consultation provided valuable diagnostic insights.",
    "Preventive screenings can detect issues before symptoms appear.",
    "The prescription dosage was adjusted based on patient response.",
    "Medical history review revealed relevant family health patterns.",
    "The treatment plan incorporates both medication and lifestyle changes.",
    
    # =========================================================================
    # EDUCATION & LEARNING
    # =========================================================================
    "The curriculum covers fundamental concepts and advanced topics.",
    "Student engagement improved with interactive learning methods.",
    "The assessment criteria were clearly explained in the syllabus.",
    "Office hours provide opportunities for additional support.",
    "The group project requires collaboration among team members.",
    "Feedback on assignments helps students identify areas for improvement.",
    "The lecture materials are available online for review.",
    "Prerequisites ensure students have necessary background knowledge.",
    "The tutoring center offers assistance with challenging subjects.",
    "Academic integrity policies prohibit plagiarism and cheating.",
    "The graduation requirements include both core and elective courses.",
    "Study groups facilitate peer learning and discussion.",
    "The scholarship application deadline is approaching quickly.",
    "Career services helps students prepare for job interviews.",
    "The internship program provides valuable professional experience.",
]

# =============================================================================
# ERROR GENERATION FUNCTIONS
# =============================================================================

@dataclass
class CorruptionResult:
    """Result of corrupting a word or sentence."""
    original: str
    corrupted: str
    error_types: List[str] = field(default_factory=list)
    

def adjacent_key_error(char: str) -> Tuple[str, bool]:
    """Replace character with an adjacent key. Returns (new_char, was_modified)."""
    lower = char.lower()
    if lower in QWERTY_ADJACENT:
        adjacent = QWERTY_ADJACENT[lower]
        new_char = random.choice(adjacent)
        if char.isupper():
            new_char = new_char.upper()
        return new_char, True
    return char, False


def visual_confusion_error(char: str) -> Tuple[str, bool]:
    """Replace character with visually similar one. Returns (new_char, was_modified)."""
    lower = char.lower()
    if lower in VISUAL_CONFUSIONS:
        new_char = VISUAL_CONFUSIONS[lower]
        if char.isupper():
            new_char = new_char.upper()
        return new_char, True
    return char, False


def transpose_adjacent(word: str) -> Tuple[str, bool]:
    """Swap two adjacent characters in a word."""
    if len(word) < 2:
        return word, False
    # Prefer transposing vowel-consonant or consonant-vowel pairs (more common)
    vowels = set('aeiouAEIOU')
    positions = []
    for i in range(len(word) - 1):
        is_vowel_consonant = (word[i] in vowels) != (word[i+1] in vowels)
        positions.append((i, 2 if is_vowel_consonant else 1))
    
    if not positions:
        return word, False
    
    # Weighted random selection
    total = sum(w for _, w in positions)
    r = random.uniform(0, total)
    cumulative = 0
    pos = 0
    for p, w in positions:
        cumulative += w
        if r <= cumulative:
            pos = p
            break
    
    return word[:pos] + word[pos+1] + word[pos] + word[pos+2:], True


def delete_character(word: str) -> Tuple[str, bool]:
    """Delete a random character from the word."""
    if len(word) < 3:
        return word, False
    # Prefer deleting repeated characters or vowels
    positions = []
    for i, char in enumerate(word):
        weight = 1
        if i > 0 and word[i-1].lower() == char.lower():
            weight = 3  # More likely to delete doubled letters
        if char.lower() in 'aeiou':
            weight += 1  # Slightly more likely to drop vowels
        positions.append((i, weight))
    
    total = sum(w for _, w in positions)
    r = random.uniform(0, total)
    cumulative = 0
    pos = 0
    for p, w in positions:
        cumulative += w
        if r <= cumulative:
            pos = p
            break
    
    return word[:pos] + word[pos+1:], True


def duplicate_character(word: str) -> Tuple[str, bool]:
    """Duplicate a random character in the word."""
    if len(word) < 2:
        return word, False
    # Prefer duplicating consonants (common typing error)
    consonants = set('bcdfghjklmnpqrstvwxyzBCDFGHJKLMNPQRSTVWXYZ')
    positions = []
    for i, char in enumerate(word):
        weight = 2 if char in consonants else 1
        positions.append((i, weight))
    
    total = sum(w for _, w in positions)
    r = random.uniform(0, total)
    cumulative = 0
    pos = 0
    for p, w in positions:
        cumulative += w
        if r <= cumulative:
            pos = p
            break
    
    return word[:pos] + word[pos] + word[pos:], True


def insert_adjacent_key(word: str) -> Tuple[str, bool]:
    """Insert an adjacent key next to a character."""
    if len(word) < 2:
        return word, False
    pos = random.randint(0, len(word) - 1)
    char = word[pos].lower()
    if char in QWERTY_ADJACENT:
        insert = random.choice(QWERTY_ADJACENT[char])
        # Insert before or after
        if random.random() < 0.5:
            return word[:pos] + insert + word[pos:], True
        else:
            return word[:pos+1] + insert + word[pos+1:], True
    return word, False


def apply_known_misspelling(word: str) -> Tuple[str, bool]:
    """Replace word with a known common misspelling."""
    lower = word.lower()
    if lower in COMMON_MISSPELLINGS:
        misspelling = random.choice(COMMON_MISSPELLINGS[lower])
        # Preserve original capitalization
        if word[0].isupper():
            misspelling = misspelling.capitalize()
        if word.isupper():
            misspelling = misspelling.upper()
        return misspelling, True
    return word, False


def abbreviate_word(word: str) -> Tuple[str, bool]:
    """Create an abbreviation (for velocity mode training)."""
    lower = word.lower()
    # Find matching abbreviation
    for abbrev, full in ABBREVIATIONS.items():
        if full == lower:
            if word[0].isupper():
                abbrev = abbrev.capitalize()
            return abbrev, True
    
    # Generate abbreviation by removing vowels (for longer words)
    if len(word) >= 6:
        vowels = set('aeiouAEIOU')
        # Keep first letter and consonants
        abbreviated = word[0] + ''.join(c for c in word[1:] if c not in vowels)
        if len(abbreviated) >= 3 and abbreviated != word:
            return abbreviated, True
    
    return word, False


def corrupt_word(word: str, error_types: Optional[Set[str]] = None, intensity: float = 0.5) -> CorruptionResult:
    """
    Apply random corruptions to a word.
    
    Args:
        word: The word to corrupt
        error_types: Set of allowed error types (None = all)
        intensity: Probability of applying each corruption (0.0-1.0)
    
    Returns:
        CorruptionResult with original, corrupted text, and error types applied
    """
    if len(word) < 2:
        return CorruptionResult(word, word)
    
    # Skip punctuation-only
    if not any(c.isalpha() for c in word):
        return CorruptionResult(word, word)
    
    all_corruptions = [
        ('transpose', transpose_adjacent),
        ('delete', delete_character),
        ('duplicate', duplicate_character),
        ('adjacent', lambda w: (adjacent_key_error(random.choice(w))[0] if random.random() < 0.3 
                                else w, True)),
        ('visual', lambda w: apply_visual_corruption(w)),
        ('misspelling', apply_known_misspelling),
    ]
    
    if error_types:
        corruptions = [(name, func) for name, func in all_corruptions if name in error_types]
    else:
        corruptions = all_corruptions
    
    if not corruptions:
        return CorruptionResult(word, word)
    
    applied_errors = []
    result = word
    
    # Apply 1-3 corruptions based on intensity
    num_corruptions = 1 if random.random() > intensity else (2 if random.random() > 0.5 else 3)
    
    for _ in range(num_corruptions):
        if random.random() > intensity:
            continue
        
        name, func = random.choice(corruptions)
        new_result, was_modified = func(result)
        if was_modified and new_result != result:
            result = new_result
            applied_errors.append(name)
    
    return CorruptionResult(word, result, applied_errors)


def apply_visual_corruption(word: str) -> Tuple[str, bool]:
    """Apply visual confusion errors to a word."""
    chars = list(word)
    modified = False
    for i, char in enumerate(chars):
        if random.random() < 0.2:  # 20% chance per character
            new_char, was_modified = visual_confusion_error(char)
            if was_modified:
                chars[i] = new_char
                modified = True
    return ''.join(chars), modified


def corrupt_sentence(sentence: str, 
                     word_error_rate: float = 0.3,
                     intensity: float = 0.5,
                     error_types: Optional[Set[str]] = None,
                     include_abbreviations: bool = True) -> CorruptionResult:
    """
    Corrupt a sentence with realistic typos.
    
    Args:
        sentence: Clean sentence to corrupt
        word_error_rate: Probability of corrupting each word (0.0-1.0)
        intensity: How severely to corrupt each word (0.0-1.0)
        error_types: Set of allowed error types
        include_abbreviations: Whether to include velocity-mode abbreviations
    
    Returns:
        CorruptionResult with the corrupted sentence
    """
    words = sentence.split()
    corrupted_words = []
    all_errors = []
    
    for word in words:
        if random.random() < word_error_rate:
            # Decide corruption type
            if include_abbreviations and random.random() < 0.15:
                # 15% chance of abbreviation (velocity mode)
                abbrev, was_modified = abbreviate_word(word.strip('.,!?;:'))
                if was_modified:
                    # Preserve trailing punctuation
                    trailing = ''
                    for char in reversed(word):
                        if char in '.,!?;:':
                            trailing = char + trailing
                        else:
                            break
                    corrupted_words.append(abbrev + trailing)
                    all_errors.append('abbreviation')
                    continue
            
            # Regular corruption
            result = corrupt_word(word, error_types, intensity)
            corrupted_words.append(result.corrupted)
            all_errors.extend(result.error_types)
        else:
            corrupted_words.append(word)
    
    return CorruptionResult(
        sentence,
        ' '.join(corrupted_words),
        list(set(all_errors))
    )


# =============================================================================
# DATASET GENERATION
# =============================================================================

def generate_training_pairs(sentences: List[str],
                           samples_per_sentence: int = 5,
                           intensity_levels: List[float] = [0.2, 0.4, 0.6, 0.8],
                           include_abbreviations: bool = True) -> List[dict]:
    """
    Generate training pairs from clean sentences.
    
    Args:
        sentences: List of clean sentences
        samples_per_sentence: How many corrupted versions per sentence
        intensity_levels: Corruption intensity levels to use
        include_abbreviations: Include velocity-mode abbreviations
    
    Returns:
        List of training examples as dicts
    """
    pairs = []
    
    for sentence in sentences:
        sentence = sentence.strip()
        if not sentence:
            continue
        
        for _ in range(samples_per_sentence):
            intensity = random.choice(intensity_levels)
            word_error_rate = 0.2 + (intensity * 0.4)  # 0.2-0.6 based on intensity
            
            result = corrupt_sentence(
                sentence,
                word_error_rate=word_error_rate,
                intensity=intensity,
                include_abbreviations=include_abbreviations
            )
            
            # Only include if there's a meaningful difference
            if result.corrupted != result.original:
                pairs.append({
                    'input': result.corrupted,
                    'output': result.original,
                    'error_types': result.error_types,
                    'intensity': intensity
                })
    
    return pairs


def generate_abbreviation_pairs() -> List[dict]:
    """Generate training pairs specifically for abbreviation expansion."""
    pairs = []
    
    for abbrev, full in ABBREVIATIONS.items():
        # Create sentence contexts
        contexts = [
            f"{abbrev} is important",
            f"I think {abbrev} works well",
            f"We need to discuss {abbrev}",
            f"The {abbrev} was great",
        ]
        
        for context in contexts:
            full_context = context.replace(abbrev, full)
            pairs.append({
                'input': context,
                'output': full_context,
                'error_types': ['abbreviation'],
                'intensity': 0.0
            })
    
    return pairs


def write_jsonl(pairs: List[dict], output_path: str):
    """Write pairs to JSONL file."""
    with open(output_path, 'w', encoding='utf-8') as f:
        for pair in pairs:
            f.write(json.dumps(pair, ensure_ascii=False) + '\n')


def write_plain_pairs(pairs: List[dict], output_path: str):
    """Write pairs as simple tab-separated file."""
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write("input\toutput\n")
        for pair in pairs:
            f.write(f"{pair['input']}\t{pair['output']}\n")


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Generate MindType training data from clean text.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Generate from built-in corpus
    python generate_training_data.py --samples 1000 --output training.jsonl
    
    # Generate from custom text file
    python generate_training_data.py --input my_text.txt --output training.jsonl
    
    # Generate with high intensity (more severe errors)
    python generate_training_data.py --intensity 0.8 --samples 5000
    
    # Generate abbreviation-only training data
    python generate_training_data.py --abbreviations-only --output abbrev.jsonl
        """
    )
    
    parser.add_argument('--input', '-i', type=str, 
                        help='Input file with clean sentences (one per line)')
    parser.add_argument('--output', '-o', type=str, default='mindtype_training_data.jsonl',
                        help='Output file path (default: mindtype_training_data.jsonl)')
    parser.add_argument('--samples', '-n', type=int, default=5,
                        help='Number of corrupted samples per sentence (default: 5)')
    parser.add_argument('--intensity', type=float, default=0.5,
                        help='Base corruption intensity 0.0-1.0 (default: 0.5)')
    parser.add_argument('--format', choices=['jsonl', 'tsv'], default='jsonl',
                        help='Output format (default: jsonl)')
    parser.add_argument('--no-abbreviations', action='store_true',
                        help='Disable velocity-mode abbreviations')
    parser.add_argument('--abbreviations-only', action='store_true',
                        help='Only generate abbreviation expansion pairs')
    parser.add_argument('--seed', type=int, default=None,
                        help='Random seed for reproducibility')
    
    args = parser.parse_args()
    
    if args.seed is not None:
        random.seed(args.seed)
    
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  M I N D ⠶ T Y P E   T R A I N I N G   D A T A              ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    # Load sentences
    if args.input:
        print(f"📖 Loading sentences from: {args.input}")
        with open(args.input, 'r', encoding='utf-8') as f:
            sentences = [line.strip() for line in f if line.strip()]
    else:
        print("📖 Using built-in sample corpus")
        sentences = SAMPLE_CORPUS
    
    print(f"   Found {len(sentences)} sentences")
    print()
    
    # Generate pairs
    pairs = []
    
    if args.abbreviations_only:
        print("🔤 Generating abbreviation pairs only...")
        pairs = generate_abbreviation_pairs()
    else:
        print(f"⚡ Generating {args.samples} corrupted versions per sentence...")
        print(f"   Intensity: {args.intensity}")
        print(f"   Abbreviations: {'disabled' if args.no_abbreviations else 'enabled'}")
        
        intensity_levels = [
            max(0.1, args.intensity - 0.2),
            args.intensity,
            min(1.0, args.intensity + 0.2)
        ]
        
        pairs = generate_training_pairs(
            sentences,
            samples_per_sentence=args.samples,
            intensity_levels=intensity_levels,
            include_abbreviations=not args.no_abbreviations
        )
        
        # Add some abbreviation pairs
        if not args.no_abbreviations:
            print("   Adding abbreviation expansion pairs...")
            pairs.extend(generate_abbreviation_pairs())
    
    # Shuffle
    random.shuffle(pairs)
    
    print()
    print(f"✅ Generated {len(pairs)} training pairs")
    
    # Analyze error distribution
    error_counts = defaultdict(int)
    for pair in pairs:
        for error in pair.get('error_types', []):
            error_counts[error] += 1
    
    print()
    print("📊 Error type distribution:")
    for error_type, count in sorted(error_counts.items(), key=lambda x: -x[1]):
        print(f"   {error_type}: {count}")
    
    # Write output
    print()
    print(f"💾 Writing to: {args.output}")
    
    if args.format == 'jsonl':
        write_jsonl(pairs, args.output)
    else:
        write_plain_pairs(pairs, args.output)
    
    print()
    print("🎉 Done!")
    print()
    print("Example pairs:")
    print("-" * 60)
    for pair in random.sample(pairs, min(5, len(pairs))):
        print(f"  IN:  {pair['input']}")
        print(f"  OUT: {pair['output']}")
        print(f"  ERR: {pair.get('error_types', [])}")
        print()


if __name__ == '__main__':
    main()

