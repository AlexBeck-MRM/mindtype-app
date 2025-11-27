/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   C O R E   T Y P E S  ░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Fundamental types for the typing intelligence pipeline.   ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Core data types for corrections, regions, and proposals
  • WHY  ▸ Type-safe foundation for pipeline operations
  • HOW  ▸ Codable structs with clear semantics
*/

import Foundation

// MARK: - Active Region

/// Defines a text region for processing
public struct TextRegion: Equatable, Codable, Sendable {
    public let start: Int
    public let end: Int
    
    public var length: Int { end - start }
    public var isEmpty: Bool { start >= end }
    
    public init(start: Int, end: Int) {
        self.start = max(0, start)
        self.end = max(self.start, end)
    }
    
    public func contains(_ index: Int) -> Bool {
        index >= start && index < end
    }
    
    public func clampedTo(length: Int) -> TextRegion {
        TextRegion(
            start: min(start, length),
            end: min(end, length)
        )
    }
}

// MARK: - Correction Diff

/// A single text correction/replacement
public struct CorrectionDiff: Equatable, Codable, Sendable {
    public let start: Int
    public let end: Int
    public let text: String
    public let stage: CorrectionStage
    public let confidence: Double
    
    public init(start: Int, end: Int, text: String, stage: CorrectionStage, confidence: Double = 1.0) {
        self.start = start
        self.end = end
        self.text = text
        self.stage = stage
        self.confidence = confidence
    }
    
    /// Length change when this diff is applied
    public var lengthDelta: Int {
        text.count - (end - start)
    }
}

// MARK: - Correction Stage

/// The three-stage pipeline stages
public enum CorrectionStage: String, Codable, CaseIterable, Sendable {
    case noise = "noise"
    case context = "context"
    case tone = "tone"
    
    public var displayName: String {
        switch self {
        case .noise: return "Typo Fix"
        case .context: return "Grammar"
        case .tone: return "Tone"
        }
    }
}

// MARK: - Tone Target

/// Tone adjustment targets
public enum ToneTarget: String, Codable, CaseIterable, Sendable {
    case none = "None"
    case casual = "Casual"
    case professional = "Professional"
}

// MARK: - Correction Wave

/// Result of running the three-stage correction pipeline
public struct CorrectionWaveResult: Sendable {
    /// The final cumulative diff(s) to apply to the original text
    public let diffs: [CorrectionDiff]
    /// The active region that was processed
    public let activeRegion: TextRegion
    /// Total processing time in milliseconds
    public let durationMs: Double
    /// Which stages contributed changes (for debugging/display)
    public let stagesApplied: [CorrectionStage]
    /// The final corrected text (convenience)
    public let correctedText: String?
    
    public init(
        diffs: [CorrectionDiff],
        activeRegion: TextRegion,
        durationMs: Double,
        stagesApplied: [CorrectionStage] = [],
        correctedText: String? = nil
    ) {
        self.diffs = diffs
        self.activeRegion = activeRegion
        self.durationMs = durationMs
        self.stagesApplied = stagesApplied
        self.correctedText = correctedText
    }
}

// MARK: - Pipeline State

/// Current state of the typing pipeline
public struct PipelineState: Sendable {
    public let text: String
    public let caret: Int
    public let lastTypingTime: Date
    
    public init(text: String, caret: Int, lastTypingTime: Date = Date()) {
        self.text = text
        self.caret = caret
        self.lastTypingTime = lastTypingTime
    }
}

// MARK: - LM Configuration

/// Configuration for the language model
public struct LMConfiguration: Sendable {
    public let modelPath: String?
    public let maxTokens: Int
    public let temperature: Float
    public let contextSize: Int
    public let gpuLayers: Int
    
    public init(
        modelPath: String? = nil,
        maxTokens: Int = 64,
        temperature: Float = 0.1,
        contextSize: Int = 2048,
        gpuLayers: Int = -1  // -1 = use all available
    ) {
        self.modelPath = modelPath
        self.maxTokens = maxTokens
        self.temperature = temperature
        self.contextSize = contextSize
        self.gpuLayers = gpuLayers
    }
    
    public static var `default`: LMConfiguration {
        LMConfiguration()
    }
    
    /// Create configuration for a GGUF model
    public static func gguf(_ path: String, temperature: Float = 0.1) -> LMConfiguration {
        LMConfiguration(modelPath: path, temperature: temperature)
    }
}

// MARK: - Pipeline Configuration

/// Configuration for the correction pipeline
public struct PipelineConfiguration: Sendable {
    /// Number of words before caret to include in active region (5-50)
    public let activeRegionWords: Int
    /// Minimum confidence threshold for applying corrections (0.5-1.0)
    public let confidenceThreshold: Double
    /// Default tone target for the tone stage
    public let toneTarget: ToneTarget
    /// LLM temperature for generation creativity (0.0-1.0, lower = more deterministic)
    public let temperature: Float
    
    public init(
        activeRegionWords: Int = 20,
        confidenceThreshold: Double = 0.80,
        toneTarget: ToneTarget = .none,
        temperature: Float = 0.1
    ) {
        self.activeRegionWords = max(5, min(50, activeRegionWords))
        self.confidenceThreshold = max(0.5, min(1.0, confidenceThreshold))
        self.toneTarget = toneTarget
        self.temperature = max(0.0, min(1.0, temperature))
    }
    
    public static var `default`: PipelineConfiguration {
        PipelineConfiguration()
    }
}

// MARK: - Marker State (Caret Organism)

/// The state machine for the "Caret Organism" — the intelligent visual marker
/// that accompanies the cursor and travels through text during corrections.
public enum MarkerState: Equatable, Sendable {
    /// No editable field focused — marker invisible
    case dormant
    /// Field focused, no typing activity — marker at rest beside caret
    case idle(position: Int)
    /// User is typing (burst phase) — marker pulses gently
    case listening(position: Int)
    /// Pause detected, preparing correction — marker speeds up
    case thinking(position: Int)
    /// Marker traveling through text, unveiling fixes
    case sweeping(from: Int, to: Int, progress: Double)
    /// Sweep finished — brief success state before returning to idle
    case complete(position: Int)
    /// User disabled with ⌥◀ — marker hidden until blur/refocus
    case disabled
    /// Error state — model failed, etc.
    case error(String)
    
    public var position: Int? {
        switch self {
        case .dormant, .disabled: return nil
        case .idle(let pos), .listening(let pos), .thinking(let pos), .complete(let pos): return pos
        case .sweeping(_, let to, _): return to
        case .error: return nil
        }
    }
    
    public var isActive: Bool {
        switch self {
        case .dormant, .disabled, .error: return false
        default: return true
        }
    }
    
    public var isAnimating: Bool {
        switch self {
        case .listening, .thinking, .sweeping: return true
        default: return false
        }
    }
    
    /// Braille symbol — middle 2x2 grid (dots 2,3,5,6)
    /// Grid:  2 5
    ///        3 6
    public var brailleSymbol: String {
        switch self {
        case .dormant, .disabled: return ""
        case .idle: return "⠤"      // dots 3,6 — horizontal, stable
        case .listening: return "⠴" // dots 3,5,6 — growing, active
        case .thinking: return "⠦"  // dots 2,3,6 — processing
        case .sweeping: return "⠶"  // dots 2,3,5,6 — full, traveling
        case .complete: return "⠲"  // dots 2,5,6 — satisfied
        case .error: return "⠆"     // dots 2,3 — interrupted
        }
    }
    
    public var accessibilityDescription: String {
        switch self {
        case .dormant: return "Correction marker inactive"
        case .idle: return "Correction marker ready"
        case .listening: return "Typing detected"
        case .thinking: return "Preparing corrections"
        case .sweeping: return "Applying corrections"
        case .complete: return "Corrections complete"
        case .disabled: return "Correction marker disabled"
        case .error(let msg): return "Error: \(msg)"
        }
    }
}

// MARK: - Sweep State

/// Represents an in-progress sweep animation
public struct SweepState: Sendable, Equatable {
    public let startPosition: Int
    public let endPosition: Int
    public let progress: Double
    public let corrections: [CorrectionDiff]
    public let duration: TimeInterval
    
    public init(
        startPosition: Int,
        endPosition: Int,
        progress: Double = 0.0,
        corrections: [CorrectionDiff] = [],
        duration: TimeInterval = 0.3
    ) {
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.progress = max(0.0, min(1.0, progress))
        self.corrections = corrections
        self.duration = duration
    }
    
    public var currentPosition: Int {
        let range = Double(endPosition - startPosition)
        return startPosition + Int(range * progress)
    }
    
    public func shouldUnveilCorrection(at index: Int) -> Bool {
        guard index < corrections.count else { return false }
        let correction = corrections[index]
        return currentPosition >= correction.end
    }
}

// MARK: - Typing Rhythm

/// Represents the burst-pause-correct typing rhythm
public enum TypingRhythm: Equatable, Sendable {
    case idle
    case bursting(since: Date)
    case paused(since: Date)
    case correcting
    
    public var isBursting: Bool {
        if case .bursting = self { return true }
        return false
    }
    
    public var isPaused: Bool {
        if case .paused = self { return true }
        return false
    }
}

// MARK: - Device Tier

/// Hardware capability tier for adaptive processing
public enum DeviceTier: String, Sendable, CaseIterable {
    case high
    case balanced
    case graceful
    
    public var tokenWindow: Int {
        switch self {
        case .high: return 48
        case .balanced: return 24
        case .graceful: return 16
        }
    }
    
    public var targetLatencyMs: Int {
        switch self {
        case .high: return 15
        case .balanced: return 25
        case .graceful: return 30
        }
    }
    
    public var markerFPS: Int {
        switch self {
        case .high: return 60
        case .balanced: return 30
        case .graceful: return 15
        }
    }
    
    public var sweepDuration: TimeInterval {
        switch self {
        case .high: return 0.25
        case .balanced: return 0.35
        case .graceful: return 0.5
        }
    }
}

// MARK: - Errors

/// Errors that can occur in the MindType pipeline
public enum MindTypeError: Error, LocalizedError {
    case modelNotLoaded
    case modelLoadFailed(String)
    case generationFailed(String)
    case caretUnsafe
    case regionEmpty
    case invalidState(String)
    case accessibilityNotGranted
    case secureFieldDetected
    case imeActive
    
    public var errorDescription: String? {
        switch self {
        case .modelNotLoaded:
            return "Language model not loaded"
        case .modelLoadFailed(let reason):
            return "Failed to load model: \(reason)"
        case .generationFailed(let reason):
            return "Text generation failed: \(reason)"
        case .caretUnsafe:
            return "Operation would modify text at or after caret"
        case .regionEmpty:
            return "Active region is empty"
        case .invalidState(let reason):
            return "Invalid pipeline state: \(reason)"
        case .accessibilityNotGranted:
            return "Accessibility permissions not granted"
        case .secureFieldDetected:
            return "Cannot process secure text fields"
        case .imeActive:
            return "Cannot process during IME composition"
        }
    }
}

