#!/bin/bash
set -e

# ═══════════════════════════════════════════════════════════════
# Cleanup obsolete files after v0.8 restructure
# ═══════════════════════════════════════════════════════════════

echo "🧹 Cleaning up obsolete files..."
echo ""

cd "$(dirname "${BASH_SOURCE[0]}")/.."

# Track deleted count
DELETED=0

# ═══════════════════════════════════════════════════════════════
# 1. Remove old migration/planning docs (kept in git history)
# ═══════════════════════════════════════════════════════════════

echo "📄 Removing temporary planning docs..."

rm -f docs/00-index/restructure-plan.md && echo "  ✓ restructure-plan.md" && ((DELETED++))
rm -f docs/00-index/realignment-plan.md && echo "  ✓ realignment-plan.md" && ((DELETED++))
rm -f docs/00-index/misalignment-analysis.md && echo "  ✓ misalignment-analysis.md" && ((DELETED++))

echo ""

# ═══════════════════════════════════════════════════════════════
# 2. Remove duplicate/obsolete architecture docs
# ═══════════════════════════════════════════════════════════════

echo "📐 Checking for obsolete architecture docs..."

# Keep: architecture.mmd (the actual working diagram)
# Remove: any revolutionary-architecture.mmd if it exists (was never created)

if [ ! -f "docs/04-architecture/revolutionary-architecture.mmd" ]; then
    echo "  ℹ️  revolutionary-architecture.mmd doesn't exist (expected)"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# 3. Remove old playground/ and scenarios/ if they exist
# ═══════════════════════════════════════════════════════════════

echo "🎮 Removing old playground/ and scenarios/ if present..."

if [ -d "playground" ]; then
    rm -rf playground && echo "  ✓ playground/" && ((DELETED++))
fi

if [ -d "scenarios" ]; then
    rm -rf scenarios && echo "  ✓ scenarios/" && ((DELETED++))
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# 4. Remove obsolete questionnaire cleanup script
# ═══════════════════════════════════════════════════════════════

echo "📝 Removing obsolete scripts..."

# This script has hardcoded wrong path and references non-existent folder
rm -f scripts/qna_cleanup.cjs && echo "  ✓ qna_cleanup.cjs (broken path)" && ((DELETED++))

echo ""

# ═══════════════════════════════════════════════════════════════
# 5. Check for any remaining old structure folders
# ═══════════════════════════════════════════════════════════════

echo "📁 Checking for leftover old directories..."

for dir in core engines ui utils config crates; do
    if [ -d "$dir" ]; then
        # Check if empty
        if [ -z "$(ls -A $dir 2>/dev/null)" ]; then
            rmdir "$dir" && echo "  ✓ Removed empty: $dir/" && ((DELETED++))
        else
            echo "  ⚠️  $dir/ still has files - review manually"
            ls -la "$dir/"
        fi
    fi
done

echo ""

# ═══════════════════════════════════════════════════════════════
# 6. Remove dist/ and build artifacts (will be regenerated)
# ═══════════════════════════════════════════════════════════════

echo "🗑️  Removing build artifacts (will regenerate)..."

if [ -d "dist" ]; then
    rm -rf dist && echo "  ✓ dist/" && ((DELETED++))
fi

if [ -d "coverage" ]; then
    rm -rf coverage && echo "  ✓ coverage/" && ((DELETED++))
fi

echo ""

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════

echo "═══════════════════════════════════════════════════════════"
echo "✅ Cleanup complete!"
echo "═══════════════════════════════════════════════════════════"
echo ""
echo "Removed: $DELETED items"
echo ""
echo "Note: Migration scripts in scripts/ are KEPT for reference"
echo "Note: Summary docs (V08-RESTRUCTURE-SUMMARY.md, QUICKSTART-V08.md) are KEPT"
echo ""
echo "Next: Run 'git status' to review changes"
echo ""




