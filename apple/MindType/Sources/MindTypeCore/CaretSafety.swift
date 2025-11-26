/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C A R E T   S A F E T Y  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Guarantees that corrections never modify text at or       ║
  ║   after the user's cursor position.                         ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Caret-safe diff validation and application
  • WHY  ▸ Core UX contract: never disrupt typing flow
  • HOW  ▸ Strict validation before any text modification
*/

import Foundation

// MARK: - Caret Safety

/// Validates that a region is safe to modify given caret position
public func isCaretSafe(start: Int, end: Int, caret: Int) -> Bool {
    // Region must be entirely before the caret
    end <= caret && start < end
}

/// Validates that a diff is safe to apply given caret position
public func isCaretSafe(diff: CorrectionDiff, caret: Int) -> Bool {
    isCaretSafe(start: diff.start, end: diff.end, caret: caret)
}

/// Validates that a region is safe
public func isCaretSafe(region: TextRegion, caret: Int) -> Bool {
    isCaretSafe(start: region.start, end: region.end, caret: caret)
}

// MARK: - Safe Text Replacement

/// Safely replace a range of text, validating caret safety
/// - Returns: The new text if safe, nil if operation would violate caret safety
public func safeReplace(
    text: String,
    start: Int,
    end: Int,
    replacement: String,
    caret: Int
) -> String? {
    guard isCaretSafe(start: start, end: end, caret: caret) else {
        return nil
    }
    
    guard start >= 0, end <= text.count, start <= end else {
        return nil
    }
    
    let startIndex = text.index(text.startIndex, offsetBy: start)
    let endIndex = text.index(text.startIndex, offsetBy: end)
    
    var result = text
    result.replaceSubrange(startIndex..<endIndex, with: replacement)
    return result
}

/// Apply a diff to text with caret safety validation
/// - Returns: The new text and adjusted caret if safe, nil if operation would violate caret safety
public func applyDiff(
    text: String,
    diff: CorrectionDiff,
    caret: Int
) -> (text: String, caret: Int)? {
    guard let newText = safeReplace(
        text: text,
        start: diff.start,
        end: diff.end,
        replacement: diff.text,
        caret: caret
    ) else {
        return nil
    }
    
    // Caret doesn't move since diff is entirely before it
    return (newText, caret + diff.lengthDelta)
}

/// Apply multiple diffs in reverse order (from end to start) to preserve indices
public func applyDiffs(
    text: String,
    diffs: [CorrectionDiff],
    caret: Int
) -> (text: String, caret: Int)? {
    // Sort diffs by start position descending
    let sortedDiffs = diffs.sorted { $0.start > $1.start }
    
    var currentText = text
    var currentCaret = caret
    
    for diff in sortedDiffs {
        guard let result = applyDiff(text: currentText, diff: diff, caret: currentCaret) else {
            // If any diff fails, abort the entire operation
            return nil
        }
        currentText = result.text
        currentCaret = result.caret
    }
    
    return (currentText, currentCaret)
}

// MARK: - Grapheme Safety

/// Ensure indices align to grapheme cluster boundaries
public func alignToGraphemeBoundary(in text: String, index: Int) -> Int {
    guard !text.isEmpty, index > 0, index < text.count else {
        return max(0, min(index, text.count))
    }
    
    let stringIndex = text.index(text.startIndex, offsetBy: min(index, text.count))
    let rangeStart = text.rangeOfComposedCharacterSequence(at: stringIndex).lowerBound
    return text.distance(from: text.startIndex, to: rangeStart)
}

/// Align a region to grapheme boundaries
public func alignRegionToGraphemeBoundaries(in text: String, region: TextRegion) -> TextRegion {
    TextRegion(
        start: alignToGraphemeBoundary(in: text, index: region.start),
        end: alignToGraphemeBoundary(in: text, index: region.end)
    )
}

