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
    public let diffs: [CorrectionDiff]
    public let activeRegion: TextRegion
    public let durationMs: Double
    
    public init(diffs: [CorrectionDiff], activeRegion: TextRegion, durationMs: Double) {
        self.diffs = diffs
        self.activeRegion = activeRegion
        self.durationMs = durationMs
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
    public let activeRegionWords: Int
    public let pauseDelayMs: Int
    public let confidenceThreshold: Double
    public let toneTarget: ToneTarget
    
    public init(
        activeRegionWords: Int = 20,
        pauseDelayMs: Int = 600,
        confidenceThreshold: Double = 0.80,
        toneTarget: ToneTarget = .none
    ) {
        self.activeRegionWords = activeRegionWords
        self.pauseDelayMs = pauseDelayMs
        self.confidenceThreshold = confidenceThreshold
        self.toneTarget = toneTarget
    }
    
    public static var `default`: PipelineConfiguration {
        PipelineConfiguration()
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
        }
    }
}

