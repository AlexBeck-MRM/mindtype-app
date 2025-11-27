#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  F U Z Z Y   T Y P I N G   T R A I N I N G   D A T A   G E N E R A T O R    ║
║                                                                              ║
║  Generates training data for INTERPRETATION, not just correction            ║
║  Includes realistic hand-slip patterns and extreme velocity typing          ║
╚══════════════════════════════════════════════════════════════════════════════╝
"""

import json
import random
import argparse
from pathlib import Path
from dataclasses import dataclass
from typing import List, Tuple

# ═══════════════════════════════════════════════════════════════════════════════
# KEYBOARD LAYOUT - Physical key positions for realistic errors
# ═══════════════════════════════════════════════════════════════════════════════

# QWERTY layout with physical positions (row, col)
QWERTY_POS = {
    'q': (0, 0), 'w': (0, 1), 'e': (0, 2), 'r': (0, 3), 't': (0, 4),
    'y': (0, 5), 'u': (0, 6), 'i': (0, 7), 'o': (0, 8), 'p': (0, 9),
    'a': (1, 0), 's': (1, 1), 'd': (1, 2), 'f': (1, 3), 'g': (1, 4),
    'h': (1, 5), 'j': (1, 6), 'k': (1, 7), 'l': (1, 8),
    'z': (2, 0), 'x': (2, 1), 'c': (2, 2), 'v': (2, 3), 'b': (2, 4),
    'n': (2, 5), 'm': (2, 6),
}

# Which hand types which keys
LEFT_HAND = set('qwertasdfgzxcvb')
RIGHT_HAND = set('yuiophjklnm')

# Same-finger key pairs (slow sequences prone to errors)
SAME_FINGER_PAIRS = {
    'e': 'd', 'd': 'e', 'c': 'd', 'd': 'c',  # Left middle
    'r': 'f', 'f': 'r', 'v': 'f', 'f': 'v',  # Left index
    'w': 's', 's': 'w', 'x': 's', 's': 'x',  # Left ring
    'u': 'j', 'j': 'u', 'm': 'j', 'j': 'm',  # Right index
    'i': 'k', 'k': 'i',                       # Right middle
    'o': 'l', 'l': 'o',                       # Right ring
}

# Common muscle memory errors (words typed so fast they blur)
MUSCLE_MEMORY_ERRORS = {
    'the': ['teh', 'hte', 'th', 'thw'],
    'that': ['taht', 'tath', 'htat'],
    'this': ['tihs', 'thsi', 'htis'],
    'have': ['hvae', 'ahve', 'hve'],
    'with': ['wiht', 'wtih', 'iwth'],
    'from': ['form', 'fomr', 'frmo'],
    'they': ['tehy', 'thye', 'htey'],
    'what': ['waht', 'whta', 'hwat'],
    'your': ['yoru', 'yuor', 'oyur'],
    'just': ['jsut', 'juts', 'ujst'],
    'been': ['eben', 'bene', 'benn'],
    'would': ['woudl', 'owuld', 'wuold'],
    'could': ['coudl', 'cuold', 'colud'],
    'should': ['shoudl', 'shuold', 'shold'],
    'about': ['abuot', 'abotu', 'baout'],
    'there': ['tehre', 'theer', 'htere'],
    'their': ['thier', 'teir', 'tehir'],
    'which': ['whihc', 'wihch', 'hwich'],
    'think': ['thnk', 'thikn', 'htink'],
    'people': ['poeple', 'peopel', 'pepole'],
    'because': ['becuase', 'becasue', 'beacuse'],
    'through': ['thorugh', 'throuhg', 'trhough'],
    'before': ['befroe', 'beofre', 'bfore'],
    'after': ['aftre', 'atfer', 'afetr'],
    'something': ['somehting', 'somthing', 'soemthing'],
    'different': ['differnet', 'diferent', 'diferrent'],
}

# Adjacent keys (including diagonal)
def get_adjacent_keys(char: str) -> List[str]:
    if char not in QWERTY_POS:
        return [char]
    row, col = QWERTY_POS[char]
    adjacent = []
    for r in range(max(0, row-1), min(3, row+2)):
        for c in range(max(0, col-1), min(10, col+2)):
            for k, (kr, kc) in QWERTY_POS.items():
                if kr == r and kc == c and k != char:
                    adjacent.append(k)
    return adjacent if adjacent else [char]


# ═══════════════════════════════════════════════════════════════════════════════
# CORRUPTION PATTERNS - Realistic typing error models
# ═══════════════════════════════════════════════════════════════════════════════

def corrupt_adjacent(word: str, intensity: float = 0.3) -> str:
    """Replace chars with adjacent keys."""
    result = []
    for c in word:
        if c.lower() in QWERTY_POS and random.random() < intensity:
            adj = get_adjacent_keys(c.lower())
            replacement = random.choice(adj)
            result.append(replacement.upper() if c.isupper() else replacement)
        else:
            result.append(c)
    return ''.join(result)


def corrupt_hand_shift(word: str) -> str:
    """
    Simulate entire hand shifted one position left or right.
    This creates words like "upon" → "iualpio" (hand shifted left)
    """
    if len(word) < 3:
        return word
    
    # Build shift mappings
    keys_by_row = [
        list('qwertyuiop'),
        list('asdfghjkl'),
        list('zxcvbnm'),
    ]
    
    shift = random.choice([-1, 1])  # Left or right shift
    shift_map = {}
    
    for row in keys_by_row:
        for i, key in enumerate(row):
            new_idx = i + shift
            if 0 <= new_idx < len(row):
                shift_map[key] = row[new_idx]
            else:
                shift_map[key] = key  # Edge keys stay same
    
    result = []
    for c in word:
        if c.lower() in shift_map and random.random() < 0.7:
            shifted = shift_map[c.lower()]
            result.append(shifted.upper() if c.isupper() else shifted)
        else:
            result.append(c)
    
    return ''.join(result)


def corrupt_double_tap(word: str) -> str:
    """Insert doubled characters (finger bounced)."""
    if len(word) < 2:
        return word
    result = list(word)
    for _ in range(random.randint(1, 2)):
        if len(result) > 1:
            idx = random.randint(0, len(result) - 1)
            result.insert(idx, result[idx])
    return ''.join(result)


def corrupt_skip(word: str, intensity: float = 0.3) -> str:
    """Skip characters (finger moved too fast)."""
    if len(word) < 3:
        return word
    result = []
    for i, c in enumerate(word):
        if random.random() > intensity:
            result.append(c)
    return ''.join(result) if result else word


def corrupt_transpose(word: str) -> str:
    """Transpose adjacent characters."""
    if len(word) < 2:
        return word
    result = list(word)
    swaps = random.randint(1, max(1, len(word) // 3))
    for _ in range(swaps):
        idx = random.randint(0, len(result) - 2)
        result[idx], result[idx + 1] = result[idx + 1], result[idx]
    return ''.join(result)


def corrupt_insert_random(word: str) -> str:
    """Insert random characters (adjacent keys hit accidentally)."""
    if len(word) < 2:
        return word
    result = list(word)
    insertions = random.randint(1, 2)
    for _ in range(insertions):
        idx = random.randint(0, len(result))
        # Insert key adjacent to the key at that position
        if idx < len(result) and result[idx].lower() in QWERTY_POS:
            adj = get_adjacent_keys(result[idx].lower())
            result.insert(idx, random.choice(adj))
        else:
            result.insert(idx, random.choice('asdfghjkl'))
    return ''.join(result)


# ═══════════════════════════════════════════════════════════════════════════════
# HUMAN RAPID TYPING PATTERNS - Based on typing research
# ═══════════════════════════════════════════════════════════════════════════════

def corrupt_muscle_memory(word: str) -> str:
    """Apply common muscle memory errors for frequent words."""
    word_lower = word.lower()
    if word_lower in MUSCLE_MEMORY_ERRORS:
        corrupted = random.choice(MUSCLE_MEMORY_ERRORS[word_lower])
        # Preserve original case pattern
        if word[0].isupper():
            corrupted = corrupted[0].upper() + corrupted[1:]
        return corrupted
    return word


def corrupt_same_finger(word: str) -> str:
    """Errors on same-finger sequences (slowest key combinations)."""
    if len(word) < 3:
        return word
    result = list(word)
    for i in range(len(result) - 1):
        c1, c2 = result[i].lower(), result[i+1].lower()
        # Same-finger sequences often get transposed or dropped
        if c1 in SAME_FINGER_PAIRS and SAME_FINGER_PAIRS.get(c1) == c2:
            if random.random() < 0.5:
                # Transpose
                result[i], result[i+1] = result[i+1], result[i]
            else:
                # Drop one
                result[i] = ''
            break
    return ''.join(result)


def corrupt_rhythm_error(word: str) -> str:
    """Rhythm errors: doubled letters wrong, or missing doubles."""
    result = list(word)
    
    # Find double letters
    for i in range(len(result) - 1):
        if result[i] == result[i+1]:
            # Sometimes doubles become singles
            if random.random() < 0.4:
                result[i] = ''
            break
    else:
        # No doubles found - maybe add one incorrectly
        if len(result) > 2 and random.random() < 0.3:
            idx = random.randint(1, len(result) - 1)
            result.insert(idx, result[idx-1])
    
    return ''.join(result)


def corrupt_anticipation(word: str) -> str:
    """Anticipation error: letter from later in word appears early."""
    if len(word) < 4:
        return word
    result = list(word)
    # Pick a letter from the second half
    late_idx = random.randint(len(result) // 2, len(result) - 1)
    early_idx = random.randint(1, late_idx - 1)
    # Insert the later letter early
    result.insert(early_idx, result[late_idx])
    return ''.join(result)


def corrupt_perseveration(word: str) -> str:
    """Perseveration: repeat a character or motion."""
    if len(word) < 2:
        return word
    result = list(word)
    idx = random.randint(0, len(result) - 1)
    # Repeat the character 1-2 extra times
    repeats = random.randint(1, 2)
    for _ in range(repeats):
        result.insert(idx + 1, result[idx])
    return ''.join(result)


def corrupt_vowel_drop(word: str, intensity: float = 0.5) -> str:
    """Drop vowels (very common in speed typing)."""
    vowels = 'aeiouAEIOU'
    result = []
    vowel_count = sum(1 for c in word if c in vowels)
    dropped = 0
    
    for c in word:
        # Keep at least one vowel
        if c in vowels and dropped < vowel_count - 1 and random.random() < intensity:
            dropped += 1
            continue
        result.append(c)
    
    return ''.join(result) if result else word


def corrupt_home_row_drift(word: str) -> str:
    """Fingers drift from home row position."""
    # Map: intended key -> key hit when finger drifted up/down
    drift_up = {'a': 'q', 's': 'w', 'd': 'e', 'f': 'r', 'g': 't',
                'h': 'y', 'j': 'u', 'k': 'i', 'l': 'o'}
    drift_down = {'a': 'z', 's': 'x', 'd': 'c', 'f': 'v', 'g': 'b',
                  'h': 'n', 'j': 'm'}
    
    drift = drift_up if random.random() < 0.5 else drift_down
    result = []
    
    for c in word:
        if c.lower() in drift and random.random() < 0.3:
            replacement = drift[c.lower()]
            result.append(replacement.upper() if c.isupper() else replacement)
        else:
            result.append(c)
    
    return ''.join(result)


def corrupt_run_together(words: List[str]) -> str:
    """Remove spaces between words."""
    if len(words) < 2:
        return ' '.join(words)
    # Randomly remove 1-2 spaces
    result = list(words)
    for _ in range(random.randint(1, min(2, len(words) - 1))):
        idx = random.randint(0, len(result) - 2)
        result[idx] = result[idx] + result[idx + 1]
        del result[idx + 1]
    return ' '.join(result)


def corrupt_split(word: str) -> str:
    """Insert accidental space in middle of word."""
    if len(word) < 4:
        return word
    split_point = random.randint(2, len(word) - 2)
    return word[:split_point] + ' ' + word[split_point:]


# ═══════════════════════════════════════════════════════════════════════════════
# CORRUPTION LEVELS
# ═══════════════════════════════════════════════════════════════════════════════

@dataclass(frozen=True)
class CorruptionLevel:
    name: str
    operations: int  # Number of corruption operations to apply
    intensity: float  # How aggressive each operation is
    
LIGHT = CorruptionLevel("light", 1, 0.2)
MEDIUM = CorruptionLevel("medium", 2, 0.35)
HEAVY = CorruptionLevel("heavy", 3, 0.5)
EXTREME = CorruptionLevel("extreme", 4, 0.7)


def corrupt_word(word: str, level: CorruptionLevel) -> str:
    """Apply corruption operations to a word based on human typing patterns."""
    if len(word) < 2 or not word.isalpha():
        return word
    
    # First: check for muscle memory errors on common words
    if word.lower() in MUSCLE_MEMORY_ERRORS and random.random() < 0.6:
        return corrupt_muscle_memory(word)
    
    # Different operation weights based on level - ordered by human frequency
    if level == EXTREME:
        # Extreme: hand shift, vowel drop, heavy skipping
        operations = [
            (corrupt_hand_shift, 0.25),
            (corrupt_vowel_drop, 0.25),
            (corrupt_skip, 0.20),
            (corrupt_adjacent, 0.15),
            (corrupt_transpose, 0.15),
        ]
    elif level == HEAVY:
        # Heavy: mix of all patterns
        operations = [
            (corrupt_vowel_drop, 0.20),
            (corrupt_adjacent, 0.20),
            (corrupt_transpose, 0.15),
            (corrupt_skip, 0.15),
            (corrupt_same_finger, 0.10),
            (corrupt_rhythm_error, 0.10),
            (corrupt_home_row_drift, 0.10),
        ]
    elif level == MEDIUM:
        # Medium: common typing errors
        operations = [
            (corrupt_adjacent, 0.25),
            (corrupt_transpose, 0.25),
            (corrupt_rhythm_error, 0.15),
            (corrupt_same_finger, 0.15),
            (corrupt_skip, 0.10),
            (corrupt_double_tap, 0.10),
        ]
    else:  # LIGHT
        # Light: subtle errors
        operations = [
            (corrupt_transpose, 0.35),
            (corrupt_adjacent, 0.30),
            (corrupt_rhythm_error, 0.20),
            (corrupt_same_finger, 0.15),
        ]
    
    result = word
    num_ops = level.operations
    
    for _ in range(num_ops):
        op = random.choices(
            [o[0] for o in operations],
            weights=[o[1] for o in operations]
        )[0]
        if op in (corrupt_adjacent, corrupt_skip, corrupt_vowel_drop):
            result = op(result, level.intensity)
        else:
            result = op(result)
    
    # Prevent complete destruction - keep at least 40% of original length
    if len(result) < len(word) * 0.4:
        result = corrupt_adjacent(word, 0.5)
    
    return result


def corrupt_sentence(sentence: str, level: CorruptionLevel) -> str:
    """Corrupt an entire sentence at the specified level."""
    words = sentence.split()
    
    # Decide how many words to corrupt based on level
    if level == LIGHT:
        num_corrupt = max(1, int(len(words) * 0.2))
    elif level == MEDIUM:
        num_corrupt = max(1, int(len(words) * 0.4))
    elif level == HEAVY:
        num_corrupt = max(2, int(len(words) * 0.6))
    else:  # EXTREME
        num_corrupt = max(3, int(len(words) * 0.8))
    
    # Select random words to corrupt
    corrupt_indices = random.sample(range(len(words)), min(num_corrupt, len(words)))
    
    result = []
    for i, word in enumerate(words):
        if i in corrupt_indices:
            result.append(corrupt_word(word, level))
        else:
            result.append(word)
    
    # Maybe run words together or split them
    if level in (HEAVY, EXTREME) and random.random() < 0.3:
        result = corrupt_run_together(result).split()
    
    if level == EXTREME and random.random() < 0.2:
        idx = random.randint(0, len(result) - 1)
        result[idx] = corrupt_split(result[idx])
    
    return ' '.join(result)


# ═══════════════════════════════════════════════════════════════════════════════
# TRAINING CORPUS - Diverse sentence types
# ═══════════════════════════════════════════════════════════════════════════════

CORPUS = [
    # ═══════════════════════════════════════════════════════════════════════════
    # NARRATIVE / STORYTELLING
    # ═══════════════════════════════════════════════════════════════════════════
    "Once upon a time there was a prince who wanted to create something new",
    "The masses had no idea who he was however he was a visionary",
    "She walked through the ancient forest looking for answers",
    "The old wizard spoke words of wisdom to the young apprentice",
    "They traveled across mountains and valleys to reach the kingdom",
    "The hero stood at the edge of the cliff watching the sun rise",
    "Her story began in a small village on the outskirts of the empire",
    "The dragon had been sleeping for a thousand years before awakening",
    "Nobody believed him when he said he had seen the future",
    "The map led them to a place that should not have existed",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # BUSINESS / PROFESSIONAL
    # ═══════════════════════════════════════════════════════════════════════════
    "Please review the quarterly report and provide your feedback",
    "The meeting has been rescheduled to next Thursday afternoon",
    "We need to discuss the budget allocation for the upcoming project",
    "The client requested additional features for the mobile application",
    "Our team will deliver the presentation by end of day Friday",
    "The stakeholders have approved the proposed timeline for launch",
    "I wanted to follow up on our conversation from yesterday",
    "The performance metrics show significant improvement this quarter",
    "We should schedule a call to discuss the next steps",
    "The contract has been reviewed by legal and is ready for signature",
    "Please ensure all team members have access to the shared drive",
    "The deadline for submissions has been extended to next week",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ACADEMIC / TECHNICAL
    # ═══════════════════════════════════════════════════════════════════════════
    "The research demonstrates a significant correlation between variables",
    "Neural networks have revolutionized the field of machine learning",
    "The hypothesis was validated through extensive experimentation",
    "Quantum computing promises to transform computational capabilities",
    "The algorithm processes data with logarithmic time complexity",
    "Statistical analysis revealed patterns that were previously unknown",
    "The methodology was designed to minimize experimental bias",
    "Preliminary results suggest further investigation is warranted",
    "The peer review process identified several areas for improvement",
    "Cross validation confirmed the reliability of our findings",
    "The database contains over fifty million records for analysis",
    "Implementation required careful consideration of edge cases",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CASUAL / EVERYDAY
    # ═══════════════════════════════════════════════════════════════════════════
    "I think we should grab coffee sometime this week",
    "The weather has been really nice lately dont you think",
    "My favorite restaurant just opened a new location downtown",
    "Have you seen the latest episode of that show everyone talks about",
    "The concert last night was absolutely incredible",
    "What time are you planning to leave for the airport tomorrow",
    "I forgot to mention that Sarah called while you were out",
    "The traffic was terrible this morning took me an hour to get here",
    "My phone battery dies so fast now I need to get it replaced",
    "Remember when we used to hang out at that place every weekend",
    "I heard they are closing that store at the end of the month",
    "The movie was better than I expected honestly",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CREATIVE / DESCRIPTIVE
    # ═══════════════════════════════════════════════════════════════════════════
    "The sunset painted the sky in brilliant shades of orange and purple",
    "Music filled the air as dancers moved gracefully across the stage",
    "The ancient library held secrets waiting to be discovered",
    "Waves crashed against the rocky shore under the moonlit sky",
    "The garden bloomed with flowers of every imaginable color",
    "Shadows lengthened as evening approached the quiet village",
    "The aroma of fresh bread drifted through the narrow streets",
    "Raindrops traced patterns on the window as the storm continued",
    "The mountains rose majestically against the clear blue sky",
    "Stars emerged one by one as darkness settled over the land",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # INSTRUCTIONS / PROCEDURAL
    # ═══════════════════════════════════════════════════════════════════════════
    "First you need to install the required dependencies",
    "Make sure to save your work before closing the application",
    "The process involves several steps that must be followed carefully",
    "Remember to check your email for the verification link",
    "Please complete the form and submit it by the deadline",
    "Click the button in the top right corner to access settings",
    "You will need to restart the computer for changes to take effect",
    "Enter your password and then confirm it in the second field",
    "Select all the files you want to include in the backup",
    "The system will automatically update when connected to wifi",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # OPINION / ARGUMENTATIVE
    # ═══════════════════════════════════════════════════════════════════════════
    "I believe that education is the foundation of a better society",
    "Technology has fundamentally changed how we communicate",
    "The evidence suggests that early intervention is most effective",
    "We should prioritize sustainable solutions for future generations",
    "Quality matters more than quantity in most situations",
    "There are valid arguments on both sides of this debate",
    "The benefits clearly outweigh the potential risks in this case",
    "History has shown that progress requires patience and persistence",
    "Innovation often comes from unexpected places and perspectives",
    "The data speaks for itself when you look at the numbers",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # QUESTIONS / CONVERSATIONAL
    # ═══════════════════════════════════════════════════════════════════════════
    "What do you think about the proposed changes to the policy",
    "How long have you been working on this particular problem",
    "Where should we meet for the discussion tomorrow",
    "Can you explain the reasoning behind your decision",
    "Would it be possible to extend the deadline by a few days",
    "Have you had a chance to look at the document I sent",
    "Do you know if anyone else is planning to attend the event",
    "What would you suggest we do about the current situation",
    "Is there anything else I should know before we proceed",
    "When was the last time you updated the software",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # EMAILS / MESSAGES (very common rapid typing context)
    # ═══════════════════════════════════════════════════════════════════════════
    "Thanks for getting back to me so quickly about this",
    "Just wanted to check in and see how things are going",
    "Let me know if you have any questions about the attached",
    "Sorry for the late reply I was traveling last week",
    "Looking forward to hearing from you soon",
    "Hope this email finds you well",
    "I appreciate your help with this matter",
    "Please find attached the documents you requested",
    "Feel free to reach out if you need anything else",
    "Thanks again for all your hard work on this project",
    
    # ═══════════════════════════════════════════════════════════════════════════
    # CODING / TECHNICAL DISCUSSIONS
    # ═══════════════════════════════════════════════════════════════════════════
    "The function returns null when the input is empty",
    "We should refactor this code to improve readability",
    "The bug was caused by an off by one error in the loop",
    "Make sure to handle the edge case where the array is empty",
    "The tests are failing because of a race condition",
    "I pushed the changes to the feature branch for review",
    "The API response includes all the fields we need",
    "We need to add error handling for network failures",
    "The performance bottleneck is in the database query",
    "Consider using a cache to reduce the number of requests",
]


# ═══════════════════════════════════════════════════════════════════════════════
# HANDCRAFTED EXTREME EXAMPLES
# These are gold-standard examples of fuzzy interpretation
# ═══════════════════════════════════════════════════════════════════════════════

HANDCRAFTED_EXAMPLES = [
    # ═══════════════════════════════════════════════════════════════════════════
    # CONTEXT-DEPENDENT INTERPRETATION
    # These examples show how sentence context makes garbled words clear
    # ═══════════════════════════════════════════════════════════════════════════
    
    # "msses" could be masses/messes/misses - but context clarifies
    ("the msses were amzd by the prfrmance on stage", "The masses were amazed by the performance on stage"),
    ("she msses her fmly when shes away frm home", "She misses her family when she's away from home"),
    ("he mde a lot of msses while lrning to cook", "He made a lot of messes while learning to cook"),
    
    # "cnt" could be can't/count/content - context clarifies
    ("i cnt bleve how fst time flys", "I can't believe how fast time flies"),
    ("plz cnt the nmber of itms in the bx", "Please count the number of items in the box"),
    ("the cnt of the artcle was vry informtve", "The content of the article was very informative"),
    
    # "prsnt" could be present/prevent/print - context clarifies
    ("she will prsnt her findngs at the confrnce", "She will present her findings at the conference"),
    ("we mst prsnt ths from happning agn", "We must prevent this from happening again"),
    
    # "rd" could be read/red/road - context clarifies
    ("i rd the book lst nght it ws grt", "I read the book last night it was great"),
    ("the rd car drve dwn the strret", "The red car drove down the street"),
    ("the rd to sccss is nvr strght", "The road to success is never straight"),
    
    # ═══════════════════════════════════════════════════════════════════════════
    # HEAVILY GARBLED BUT CONTEXT MAKES IT CLEAR
    # ═══════════════════════════════════════════════════════════════════════════
    
    # Narrative context
    ("once iualpio a time tbere weas a prince who wntd to chng the wrld", 
     "Once upon a time there was a prince who wanted to change the world"),
    ("teh msaasexd had no idea who he ws hwever he ws a visionsary",
     "The masses had no idea who he was however he was a visionary"),
    ("he creatd a nw ftookl tht the wrld hadnt exprienced bfre",
     "He created a new tool that the world hadn't experienced before"),
    
    # Technical context
    ("th algrthm prcsss th dat vry effcntly wth lgrthmuc complxty",
     "The algorithm processes the data very efficiently with logarithmic complexity"),
    ("th nurl ntwrk ws trnd on mlllns of exmpls",
     "The neural network was trained on millions of examples"),
    ("dpndncs nd to b instlld bfre rnnng th prgrm",
     "Dependencies need to be installed before running the program"),
    
    # Business context
    ("th mtng ws rschduld to thrsdy bcse of cnflcts",
     "The meeting was rescheduled to Thursday because of conflicts"),
    ("pls rvw th rport nd snd fdbck by eod frdy",
     "Please review the report and send feedback by end of day Friday"),
    ("th qrtrly rvnue excdd expcttons ths yr",
     "The quarterly revenue exceeded expectations this year"),
    
    # Casual/everyday context
    ("i thnk w shld grb cffe smtm ths wk if ur fre",
     "I think we should grab coffee sometime this week if you're free"),
    ("th wthr hs bn rly nce ltly dnt u thnk",
     "The weather has been really nice lately don't you think"),
    ("my fvrt rstrant jst opnd a nw lctn dwntwn",
     "My favorite restaurant just opened a new location downtown"),
    
    # Academic/research context  
    ("th rsrch dmnstrts a sgnfcnt crrltn btwn vrbles",
     "The research demonstrates a significant correlation between variables"),
    ("th hypthss ws vlddtd thrgh extnsve exprmnttn",
     "The hypothesis was validated through extensive experimentation"),
    ("qntm cmptng prmsses to trnsfm cmpttnl cpblts",
     "Quantum computing promises to transform computational capabilities"),
    
    # ═══════════════════════════════════════════════════════════════════════════
    # EXTREME GARBLING - Only sentence context makes this work
    # ═══════════════════════════════════════════════════════════════════════════
    
    # These would be impossible to decode without the full sentence
    ("th snsst pntd th sky n brllnt shds of orng nd prpl",
     "The sunset painted the sky in brilliant shades of orange and purple"),
    ("msc flld th ar as dncrs mvd grclly acrss th stg",
     "Music filled the air as dancers moved gracefully across the stage"),
    ("th ancnt lbrry hld scrts wtng to b dscvrd",
     "The ancient library held secrets waiting to be discovered"),
    ("wvs crshd agnst th rcky shr undr th mnlt sky",
     "Waves crashed against the rocky shore under the moonlit sky"),
    
    # Mixed garbling patterns in single sentences
    ("i ws wrtng a lttr to my frnd abt th mtng we hd ystrd",
     "I was writing a letter to my friend about the meeting we had yesterday"),
    ("th tm ndds to fnsh th prjct bfr th ddlne nxt wk",
     "The team needs to finish the project before the deadline next week"),
    ("cn u hlp me undrstnd hw ths systm wrks its cnfsng",
     "Can you help me understand how this system works it's confusing"),
    
    # ═══════════════════════════════════════════════════════════════════════════
    # ABBREVIATIONS + TYPOS (velocity typing)
    # ═══════════════════════════════════════════════════════════════════════════
    
    ("plz reviw th rport asap", "Please review the report as soon as possible"),
    ("mtg reschd to thurs aftrnn", "Meeting rescheduled to Thursday afternoon"),
    ("frst u nd to instll dpndncs", "First you need to install dependencies"),
    ("wat do u thnk abt th chngs", "What do you think about the changes"),
    ("cn u expln yr rsnng", "Can you explain your reasoning"),
    ("th mtng ws vry prdctv tdy", "The meeting was very productive today"),
    ("pls snd th dcmnts b4 tmrw", "Please send the documents before tomorrow"),
    ("th prjct s almst cmplt nw", "The project is almost complete now"),
    ("lts scdl a cll fr nxt wk", "Let's schedule a call for next week"),
    ("thx fr yr hlp w ths", "Thanks for your help with this"),
]


# ═══════════════════════════════════════════════════════════════════════════════
# DATA GENERATION
# ═══════════════════════════════════════════════════════════════════════════════

def generate_training_pair(sentence: str, level: CorruptionLevel) -> Tuple[str, str]:
    """Generate a (corrupted, clean) training pair."""
    corrupted = corrupt_sentence(sentence, level)
    return (corrupted, sentence)


def generate_dataset(
    num_samples: int = 1000,
    include_handcrafted: bool = True,
    level_distribution: dict = None
) -> List[dict]:
    """
    Generate a balanced training dataset.
    
    level_distribution: dict mapping CorruptionLevel to proportion (should sum to 1.0)
    """
    if level_distribution is None:
        level_distribution = {
            LIGHT: 0.15,
            MEDIUM: 0.35,
            HEAVY: 0.35,
            EXTREME: 0.15,
        }
    
    dataset = []
    
    # Add handcrafted examples first (gold standard)
    if include_handcrafted:
        for corrupted, clean in HANDCRAFTED_EXAMPLES:
            dataset.append({
                "input": corrupted,
                "output": clean,
                "level": "handcrafted",
                "source": "curated"
            })
    
    # Generate synthetic examples
    for level, proportion in level_distribution.items():
        level_samples = int(num_samples * proportion)
        for _ in range(level_samples):
            sentence = random.choice(CORPUS)
            corrupted, clean = generate_training_pair(sentence, level)
            dataset.append({
                "input": corrupted,
                "output": clean,
                "level": level.name,
                "source": "synthetic"
            })
    
    # Add some "no change needed" examples (prevent over-correction)
    no_change_samples = int(num_samples * 0.1)
    for _ in range(no_change_samples):
        sentence = random.choice(CORPUS)
        dataset.append({
            "input": sentence,
            "output": sentence,
            "level": "none",
            "source": "identity"
        })
    
    random.shuffle(dataset)
    return dataset


def to_chatml_format(dataset: List[dict]) -> List[dict]:
    """Convert to MLX ChatML format for fine-tuning."""
    chatml_data = []
    
    system_prompt = """You interpret garbled/fuzzy typing into what the user intended to write.

The user types VERY fast, so:
- Letters may be transposed, missing, or wrong
- Keys may be adjacent wrong keys
- Words may be run together or split
- Words may be completely garbled

Output the interpreted text, nothing else. Keep the same meaning and structure."""

    for item in dataset:
        # MLX expects "messages" key (not "conversations")
        chatml_data.append({
            "messages": [
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": item["input"]},
                {"role": "assistant", "content": item["output"]}
            ]
        })
    
    return chatml_data


def split_dataset(dataset: List[dict], val_ratio: float = 0.1) -> Tuple[List[dict], List[dict]]:
    """Split into training and validation sets."""
    random.shuffle(dataset)
    split_idx = int(len(dataset) * (1 - val_ratio))
    return dataset[:split_idx], dataset[split_idx:]


# ═══════════════════════════════════════════════════════════════════════════════
# MAIN
# ═══════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="Generate fuzzy typing training data")
    parser.add_argument("--samples", type=int, default=2000, help="Number of samples to generate")
    parser.add_argument("--output", type=str, default="tools/mlx_data", help="Output directory")
    parser.add_argument("--val-ratio", type=float, default=0.1, help="Validation set ratio")
    parser.add_argument("--seed", type=int, default=42, help="Random seed for reproducibility")
    args = parser.parse_args()
    
    random.seed(args.seed)
    
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  Fuzzy Typing Training Data Generator                        ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    # Generate dataset
    print(f"Generating {args.samples} samples...")
    raw_dataset = generate_dataset(args.samples, include_handcrafted=True)
    
    # Convert to ChatML format
    chatml_dataset = to_chatml_format(raw_dataset)
    
    # Split into train/val
    train_data, val_data = split_dataset(chatml_dataset, args.val_ratio)
    
    # Count levels
    level_counts = {}
    for item in raw_dataset:
        level = item["level"]
        level_counts[level] = level_counts.get(level, 0) + 1
    
    print(f"\nDataset composition:")
    for level, count in sorted(level_counts.items()):
        print(f"  {level}: {count} ({count/len(raw_dataset)*100:.1f}%)")
    
    # Save
    output_dir = Path(args.output)
    output_dir.mkdir(parents=True, exist_ok=True)
    
    train_path = output_dir / "train.jsonl"
    val_path = output_dir / "valid.jsonl"
    
    with open(train_path, 'w') as f:
        for item in train_data:
            f.write(json.dumps(item) + '\n')
    
    with open(val_path, 'w') as f:
        for item in val_data:
            f.write(json.dumps(item) + '\n')
    
    print(f"\n✓ Saved {len(train_data)} training samples to {train_path}")
    print(f"✓ Saved {len(val_data)} validation samples to {val_path}")
    
    # Show some examples
    print("\n─── Sample Training Pairs ───")
    for i, item in enumerate(raw_dataset[:5]):
        print(f"\n[{item['level']}]")
        print(f"  IN:  {item['input']}")
        print(f"  OUT: {item['output']}")
    
    print("\n─── Handcrafted Examples ───")
    for item in raw_dataset:
        if item["source"] == "curated":
            print(f"  IN:  {item['input']}")
            print(f"  OUT: {item['output']}")
            break


if __name__ == "__main__":
    main()

