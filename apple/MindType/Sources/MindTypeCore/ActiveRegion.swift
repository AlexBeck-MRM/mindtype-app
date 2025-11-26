/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  A C T I V E   R E G I O N  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Computes the region behind the caret where corrections    ║
  ║   are applied. ~20 words trailing the cursor.               ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Dynamic active region computation
  • WHY  ▸ Focus corrections on recent typing, preserve context
  • HOW  ▸ Word-based boundary detection with sentence alignment
*/

import Foundation

// MARK: - Active Region Policy

/// Computes the active region for correction processing
public struct ActiveRegionPolicy: Sendable {
    public let targetWords: Int
    public let maxCharacters: Int
    
    public init(targetWords: Int = 20, maxCharacters: Int = 500) {
        self.targetWords = targetWords
        self.maxCharacters = maxCharacters
    }
    
    /// Compute the active region given text and caret position
    public func computeRegion(text: String, caret: Int) -> TextRegion {
        guard caret > 0, !text.isEmpty else {
            return TextRegion(start: 0, end: 0)
        }
        
        let safeCaret = min(caret, text.count)
        let textBeforeCaret = String(text.prefix(safeCaret))
        
        // Find word boundaries going backwards
        let words = findWordBoundaries(in: textBeforeCaret)
        
        guard !words.isEmpty else {
            return TextRegion(start: 0, end: safeCaret)
        }
        
        // Take up to targetWords words
        let wordCount = min(targetWords, words.count)
        let startWordIndex = max(0, words.count - wordCount)
        let startOffset = words[startWordIndex].start
        
        // Clamp to maxCharacters
        let clampedStart = max(startOffset, safeCaret - maxCharacters)
        
        // Try to align to sentence boundary if possible
        let alignedStart = alignToSentenceBoundary(in: textBeforeCaret, nearIndex: clampedStart)
        
        return TextRegion(start: alignedStart, end: safeCaret)
    }
    
    // MARK: - Private Helpers
    
    private struct WordBoundary {
        let start: Int
        let end: Int
    }
    
    private func findWordBoundaries(in text: String) -> [WordBoundary] {
        var boundaries: [WordBoundary] = []
        
        // Use natural language word tokenization
        let range = text.startIndex..<text.endIndex
        text.enumerateSubstrings(in: range, options: .byWords) { _, substringRange, _, _ in
            let start = text.distance(from: text.startIndex, to: substringRange.lowerBound)
            let end = text.distance(from: text.startIndex, to: substringRange.upperBound)
            boundaries.append(WordBoundary(start: start, end: end))
        }
        
        return boundaries
    }
    
    private func alignToSentenceBoundary(in text: String, nearIndex: Int) -> Int {
        // Look for sentence-ending punctuation followed by space near the index
        let searchStart = max(0, nearIndex - 50)
        let searchRange = searchStart..<min(nearIndex + 20, text.count)
        
        guard searchRange.lowerBound < searchRange.upperBound else {
            return nearIndex
        }
        
        let startIndex = text.index(text.startIndex, offsetBy: searchRange.lowerBound)
        let endIndex = text.index(text.startIndex, offsetBy: searchRange.upperBound)
        let searchText = String(text[startIndex..<endIndex])
        
        // Find the last sentence boundary in the search range
        let sentenceEnders = CharacterSet(charactersIn: ".!?")
        var bestBoundary = nearIndex
        
        for (i, char) in searchText.enumerated() {
            if let scalar = char.unicodeScalars.first,
               sentenceEnders.contains(scalar) {
                let absoluteIndex = searchRange.lowerBound + i + 1
                // Check if followed by whitespace
                if absoluteIndex < text.count {
                    let nextIndex = text.index(text.startIndex, offsetBy: absoluteIndex)
                    if text[nextIndex].isWhitespace {
                        let boundaryIndex = absoluteIndex + 1
                        if boundaryIndex <= nearIndex + 20 && boundaryIndex >= nearIndex - 20 {
                            bestBoundary = boundaryIndex
                        }
                    }
                }
            }
        }
        
        return bestBoundary
    }
}

// MARK: - Default Policy

extension ActiveRegionPolicy {
    public static let `default` = ActiveRegionPolicy()
}

