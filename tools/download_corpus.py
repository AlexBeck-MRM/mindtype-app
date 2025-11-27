#!/usr/bin/env python3
"""
╔══════════════════════════════════════════════════════════════════════════════╗
║  M I N D ⠶ T Y P E   C O R P U S   D O W N L O A D E R                      ║
║                                                                              ║
║  Downloads clean text from various sources for training data generation.    ║
║  Sources: Wikipedia, Project Gutenberg, News articles, Reddit               ║
╚══════════════════════════════════════════════════════════════════════════════╝

Usage:
    python download_corpus.py --source wikipedia --sentences 10000 --output corpus.txt
    python download_corpus.py --source gutenberg --sentences 5000
    python download_corpus.py --source all --sentences 50000

Requirements:
    pip install wikipedia-api requests beautifulsoup4 nltk
"""

import argparse
import json
import os
import random
import re
import sys
import time
from pathlib import Path
from typing import List, Optional, Generator
from dataclasses import dataclass

# Check for required packages
MISSING_PACKAGES = []
try:
    import requests
except ImportError:
    MISSING_PACKAGES.append('requests')

try:
    from bs4 import BeautifulSoup
except ImportError:
    MISSING_PACKAGES.append('beautifulsoup4')

try:
    import nltk
    from nltk.tokenize import sent_tokenize
except ImportError:
    MISSING_PACKAGES.append('nltk')

if MISSING_PACKAGES:
    print("Missing required packages. Install with:")
    print(f"  pip install {' '.join(MISSING_PACKAGES)}")
    sys.exit(1)

# Download NLTK data if needed
try:
    nltk.data.find('tokenizers/punkt')
except LookupError:
    print("Downloading NLTK punkt tokenizer...")
    nltk.download('punkt', quiet=True)
try:
    nltk.data.find('tokenizers/punkt_tab')
except LookupError:
    nltk.download('punkt_tab', quiet=True)


# =============================================================================
# CONFIGURATION
# =============================================================================

# Wikipedia categories to sample from (diverse topics)
WIKIPEDIA_CATEGORIES = [
    "Technology", "Science", "Business", "Law", "Medicine", 
    "Education", "History", "Geography", "Arts", "Sports",
    "Politics", "Economics", "Philosophy", "Psychology", "Sociology",
    "Engineering", "Mathematics", "Physics", "Chemistry", "Biology",
    "Literature", "Music", "Film", "Architecture", "Food",
]

# Popular Wikipedia articles for high-quality text
WIKIPEDIA_ARTICLES = [
    "Artificial_intelligence", "Machine_learning", "Natural_language_processing",
    "Computer_science", "Software_engineering", "Data_science",
    "Climate_change", "Renewable_energy", "Electric_vehicle",
    "Cryptocurrency", "Blockchain", "Financial_technology",
    "United_States", "European_Union", "United_Nations",
    "World_War_II", "Industrial_Revolution", "Renaissance",
    "Democracy", "Human_rights", "International_law",
    "Psychology", "Cognitive_science", "Neuroscience",
    "Medicine", "Public_health", "Vaccination",
    "Education", "University", "Online_learning",
    "Internet", "Social_media", "Smartphone",
    "Space_exploration", "Mars", "Moon",
    "Evolution", "Genetics", "DNA",
    "Economics", "Gross_domestic_product", "Inflation",
]

# Project Gutenberg books (public domain, high-quality English)
GUTENBERG_BOOKS = [
    ("1342", "Pride and Prejudice"),
    ("11", "Alice's Adventures in Wonderland"),
    ("1661", "The Adventures of Sherlock Holmes"),
    ("98", "A Tale of Two Cities"),
    ("84", "Frankenstein"),
    ("1232", "The Prince"),
    ("2701", "Moby Dick"),
    ("74", "The Adventures of Tom Sawyer"),
    ("1400", "Great Expectations"),
    ("5200", "Metamorphosis"),
]


# =============================================================================
# SENTENCE EXTRACTION
# =============================================================================

def clean_text(text: str) -> str:
    """Clean and normalize text."""
    # Remove citations [1], [2], etc.
    text = re.sub(r'\[\d+\]', '', text)
    # Remove parenthetical references
    text = re.sub(r'\([^)]*\d{4}[^)]*\)', '', text)
    # Normalize whitespace
    text = re.sub(r'\s+', ' ', text)
    # Remove URLs
    text = re.sub(r'http\S+', '', text)
    # Remove email addresses
    text = re.sub(r'\S+@\S+', '', text)
    return text.strip()


def is_good_sentence(sentence: str) -> bool:
    """Check if a sentence is suitable for training."""
    sentence = sentence.strip()
    
    # Length checks
    if len(sentence) < 30 or len(sentence) > 500:
        return False
    
    # Must start with capital letter
    if not sentence[0].isupper():
        return False
    
    # Must end with sentence punctuation
    if not sentence[-1] in '.!?':
        return False
    
    # Must have at least 5 words
    words = sentence.split()
    if len(words) < 5 or len(words) > 80:
        return False
    
    # Skip sentences with too many numbers
    num_count = sum(1 for c in sentence if c.isdigit())
    if num_count > len(sentence) * 0.2:
        return False
    
    # Skip sentences with special characters
    special_chars = set('{}[]<>|\\^~`')
    if any(c in special_chars for c in sentence):
        return False
    
    # Skip sentences that look like lists or references
    if sentence.startswith(('•', '-', '*', '1.', '2.', 'a)', 'b)')):
        return False
    
    # Skip sentences with ALL CAPS words (likely headers)
    if any(word.isupper() and len(word) > 2 for word in words):
        return False
    
    return True


def extract_sentences(text: str, max_sentences: int = 1000) -> List[str]:
    """Extract clean sentences from text."""
    text = clean_text(text)
    
    try:
        sentences = sent_tokenize(text)
    except Exception:
        # Fallback to simple splitting
        sentences = re.split(r'(?<=[.!?])\s+', text)
    
    good_sentences = []
    for sentence in sentences:
        sentence = sentence.strip()
        if is_good_sentence(sentence):
            good_sentences.append(sentence)
            if len(good_sentences) >= max_sentences:
                break
    
    return good_sentences


# =============================================================================
# DATA SOURCES
# =============================================================================

def fetch_wikipedia_article(title: str) -> Optional[str]:
    """Fetch Wikipedia article content."""
    url = f"https://en.wikipedia.org/w/api.php"
    params = {
        'action': 'query',
        'titles': title,
        'prop': 'extracts',
        'explaintext': True,
        'format': 'json',
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        pages = data.get('query', {}).get('pages', {})
        for page_id, page in pages.items():
            if page_id != '-1':
                return page.get('extract', '')
        return None
    except Exception as e:
        print(f"  ⚠️  Failed to fetch {title}: {e}")
        return None


def fetch_wikipedia_random() -> Optional[str]:
    """Fetch a random Wikipedia article."""
    url = "https://en.wikipedia.org/w/api.php"
    params = {
        'action': 'query',
        'list': 'random',
        'rnnamespace': 0,  # Main namespace only
        'rnlimit': 1,
        'format': 'json',
    }
    
    try:
        response = requests.get(url, params=params, timeout=30)
        response.raise_for_status()
        data = response.json()
        
        random_pages = data.get('query', {}).get('random', [])
        if random_pages:
            title = random_pages[0]['title']
            return fetch_wikipedia_article(title)
        return None
    except Exception as e:
        print(f"  ⚠️  Failed to fetch random article: {e}")
        return None


def download_wikipedia(target_sentences: int, progress_callback=None) -> List[str]:
    """Download sentences from Wikipedia."""
    all_sentences = []
    articles_fetched = 0
    
    print(f"📚 Downloading from Wikipedia (target: {target_sentences} sentences)")
    
    # First, fetch known high-quality articles
    for title in WIKIPEDIA_ARTICLES:
        if len(all_sentences) >= target_sentences:
            break
        
        content = fetch_wikipedia_article(title)
        if content:
            sentences = extract_sentences(content, max_sentences=100)
            all_sentences.extend(sentences)
            articles_fetched += 1
            print(f"   ✓ {title}: {len(sentences)} sentences (total: {len(all_sentences)})")
        
        time.sleep(0.5)  # Rate limiting
    
    # Then fetch random articles to fill the gap
    while len(all_sentences) < target_sentences:
        content = fetch_wikipedia_random()
        if content:
            sentences = extract_sentences(content, max_sentences=50)
            if sentences:
                all_sentences.extend(sentences)
                articles_fetched += 1
                if articles_fetched % 10 == 0:
                    print(f"   📖 Fetched {articles_fetched} articles, {len(all_sentences)} sentences")
        
        time.sleep(0.5)  # Rate limiting
    
    # Deduplicate and shuffle
    all_sentences = list(set(all_sentences))
    random.shuffle(all_sentences)
    
    return all_sentences[:target_sentences]


def fetch_gutenberg_book(book_id: str) -> Optional[str]:
    """Fetch a book from Project Gutenberg."""
    url = f"https://www.gutenberg.org/files/{book_id}/{book_id}-0.txt"
    
    try:
        response = requests.get(url, timeout=60)
        if response.status_code != 200:
            # Try alternate URL format
            url = f"https://www.gutenberg.org/cache/epub/{book_id}/pg{book_id}.txt"
            response = requests.get(url, timeout=60)
        
        response.raise_for_status()
        return response.text
    except Exception as e:
        print(f"  ⚠️  Failed to fetch book {book_id}: {e}")
        return None


def download_gutenberg(target_sentences: int) -> List[str]:
    """Download sentences from Project Gutenberg."""
    all_sentences = []
    
    print(f"📖 Downloading from Project Gutenberg (target: {target_sentences} sentences)")
    
    for book_id, title in GUTENBERG_BOOKS:
        if len(all_sentences) >= target_sentences:
            break
        
        content = fetch_gutenberg_book(book_id)
        if content:
            # Remove Gutenberg header/footer
            start_markers = ['*** START OF', '***START OF']
            end_markers = ['*** END OF', '***END OF']
            
            for marker in start_markers:
                if marker in content:
                    content = content.split(marker, 1)[-1]
                    break
            
            for marker in end_markers:
                if marker in content:
                    content = content.split(marker, 1)[0]
                    break
            
            sentences = extract_sentences(content, max_sentences=500)
            all_sentences.extend(sentences)
            print(f"   ✓ {title}: {len(sentences)} sentences (total: {len(all_sentences)})")
        
        time.sleep(1)  # Rate limiting
    
    # Deduplicate and shuffle
    all_sentences = list(set(all_sentences))
    random.shuffle(all_sentences)
    
    return all_sentences[:target_sentences]


def download_news_sample(target_sentences: int) -> List[str]:
    """Download sample news sentences (from public APIs)."""
    all_sentences = []
    
    print(f"📰 Generating news-style sentences (target: {target_sentences} sentences)")
    
    # Since most news APIs require keys, we'll generate news-style sentences
    # based on common patterns
    news_templates = [
        "The {adj} {noun} announced {action} on {day}.",
        "Experts say the {noun} could {verb} by {percent} percent this year.",
        "The government is considering new {noun} regulations.",
        "Scientists discovered a {adj} method for {gerund} {noun}.",
        "The company reported {adj} earnings for the quarter.",
        "Officials confirmed the {noun} will begin next month.",
        "The study found that {percent} percent of participants {verb}.",
        "Leaders gathered to discuss the future of {noun}.",
        "The report highlights concerns about {noun} in the region.",
        "Analysts predict the market will {verb} in the coming weeks.",
    ]
    
    adjectives = ['new', 'significant', 'major', 'important', 'recent', 'growing', 
                  'increasing', 'notable', 'substantial', 'remarkable']
    nouns = ['policy', 'technology', 'economy', 'industry', 'research', 'development',
             'initiative', 'program', 'investment', 'partnership']
    verbs = ['improve', 'change', 'grow', 'expand', 'develop', 'increase', 'advance']
    gerunds = ['improving', 'developing', 'understanding', 'processing', 'analyzing']
    days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday']
    percents = ['5', '10', '15', '20', '25', '30']
    
    while len(all_sentences) < target_sentences:
        template = random.choice(news_templates)
        sentence = template.format(
            adj=random.choice(adjectives),
            noun=random.choice(nouns),
            verb=random.choice(verbs),
            gerund=random.choice(gerunds),
            day=random.choice(days),
            percent=random.choice(percents),
            action='new initiatives',
        )
        if sentence not in all_sentences:
            all_sentences.append(sentence)
    
    return all_sentences


# =============================================================================
# MAIN
# =============================================================================

def main():
    parser = argparse.ArgumentParser(
        description='Download clean text corpus for MindType training.',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
    # Download 10,000 sentences from Wikipedia
    python download_corpus.py --source wikipedia --sentences 10000
    
    # Download from Project Gutenberg
    python download_corpus.py --source gutenberg --sentences 5000
    
    # Download from all sources
    python download_corpus.py --source all --sentences 50000
    
    # Then generate training data
    python generate_training_data.py --input corpus.txt --samples 10 --output training.jsonl
        """
    )
    
    parser.add_argument('--source', '-s', 
                        choices=['wikipedia', 'gutenberg', 'news', 'all'],
                        default='wikipedia',
                        help='Data source (default: wikipedia)')
    parser.add_argument('--sentences', '-n', type=int, default=10000,
                        help='Target number of sentences (default: 10000)')
    parser.add_argument('--output', '-o', type=str, default='corpus.txt',
                        help='Output file (default: corpus.txt)')
    parser.add_argument('--seed', type=int, default=None,
                        help='Random seed for reproducibility')
    
    args = parser.parse_args()
    
    if args.seed is not None:
        random.seed(args.seed)
    
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║  M I N D ⠶ T Y P E   C O R P U S   D O W N L O A D E R      ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print()
    
    all_sentences = []
    
    if args.source in ['wikipedia', 'all']:
        target = args.sentences if args.source == 'wikipedia' else args.sentences // 2
        sentences = download_wikipedia(target)
        all_sentences.extend(sentences)
        print(f"   → Wikipedia: {len(sentences)} sentences")
        print()
    
    if args.source in ['gutenberg', 'all']:
        target = args.sentences if args.source == 'gutenberg' else args.sentences // 3
        sentences = download_gutenberg(target)
        all_sentences.extend(sentences)
        print(f"   → Gutenberg: {len(sentences)} sentences")
        print()
    
    if args.source in ['news', 'all']:
        target = args.sentences if args.source == 'news' else args.sentences // 6
        sentences = download_news_sample(target)
        all_sentences.extend(sentences)
        print(f"   → News: {len(sentences)} sentences")
        print()
    
    # Deduplicate and shuffle
    all_sentences = list(set(all_sentences))
    random.shuffle(all_sentences)
    
    # Write output
    output_path = Path(args.output)
    with open(output_path, 'w', encoding='utf-8') as f:
        for sentence in all_sentences:
            f.write(sentence + '\n')
    
    print(f"✅ Saved {len(all_sentences)} sentences to {output_path}")
    print()
    print("Next steps:")
    print(f"  python generate_training_data.py --input {output_path} --samples 10 --output training.jsonl")
    print()


if __name__ == '__main__':
    main()

