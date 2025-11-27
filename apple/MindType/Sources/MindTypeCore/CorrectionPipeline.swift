/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C O R R E C T I O N   P I P E L I N E  ░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Three-stage correction pipeline: Noise → Context → Tone   ║
  ║   Each stage is LM-powered with confidence gating.          ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Main correction orchestration
  • WHY  ▸ Structured approach to text improvement
  • HOW  ▸ Sequential stages with caret safety at each step
*/

import Foundation

// MARK: - Correction Pipeline

/// The main correction pipeline that orchestrates the three stages
public actor CorrectionPipeline {
    private let lmAdapter: any LMAdapter
    private let config: PipelineConfiguration
    private let regionPolicy: ActiveRegionPolicy
    
    public init(
        lmAdapter: any LMAdapter,
        config: PipelineConfiguration = .default
    ) {
        self.lmAdapter = lmAdapter
        self.config = config
        // Create region policy from config — ensures activeRegionWords is actually used
        self.regionPolicy = ActiveRegionPolicy(targetWords: config.activeRegionWords)
    }
    
    /// Run the correction wave on the given text
    /// 
    /// Returns a single cumulative diff representing all corrections applied.
    /// This avoids the issue of overlapping diffs from multiple stages.
    public func runCorrectionWave(
        text: String,
        caret: Int,
        toneTarget: ToneTarget? = nil
    ) async throws -> CorrectionWaveResult {
        let startTime = Date()
        
        // Compute active region on original text
        let activeRegion = regionPolicy.computeRegion(text: text, caret: caret)
        
        guard !activeRegion.isEmpty else {
            return CorrectionWaveResult(
                diffs: [],
                activeRegion: activeRegion,
                durationMs: Date().timeIntervalSince(startTime) * 1000
            )
        }
        
        // Ensure region is caret-safe
        guard isCaretSafe(region: activeRegion, caret: caret) else {
            return CorrectionWaveResult(
                diffs: [],
                activeRegion: TextRegion(start: caret, end: caret),
                durationMs: Date().timeIntervalSince(startTime) * 1000
            )
        }
        
        var stageDiffs: [CorrectionDiff] = []  // Track individual stage contributions
        var currentText = text
        var currentRegion = activeRegion
        var currentCaret = caret
        
        // Stage 1: Noise (typo fixes)
        if let noiseDiff = try await runNoiseStage(
            text: currentText,
            caret: currentCaret,
            region: currentRegion
        ), noiseDiff.confidence >= config.confidenceThreshold {
            stageDiffs.append(noiseDiff)
            if let result = applyDiff(text: currentText, diff: noiseDiff, caret: currentCaret) {
                // Update tracking variables for next stage
                let lengthDelta = noiseDiff.lengthDelta
                currentText = result.text
                currentCaret = result.caret
                // Adjust region end to match new text length
                currentRegion = TextRegion(
                    start: currentRegion.start,
                    end: currentRegion.end + lengthDelta
                )
            }
        }
        
        // Stage 2: Context (grammar/coherence) — uses updated region
        if let contextDiff = try await runContextStage(
            text: currentText,
            caret: currentCaret,
            region: currentRegion
        ), contextDiff.confidence >= config.confidenceThreshold {
            stageDiffs.append(contextDiff)
            if let result = applyDiff(text: currentText, diff: contextDiff, caret: currentCaret) {
                let lengthDelta = contextDiff.lengthDelta
                currentText = result.text
                currentCaret = result.caret
                currentRegion = TextRegion(
                    start: currentRegion.start,
                    end: currentRegion.end + lengthDelta
                )
            }
        }
        
        // Stage 3: Tone (optional style adjustment) — uses updated region
        let effectiveTone = toneTarget ?? config.toneTarget
        if effectiveTone != .none {
            if let toneDiff = try await runToneStage(
                text: currentText,
                caret: currentCaret,
                region: currentRegion,
                toneTarget: effectiveTone
            ), toneDiff.confidence >= config.confidenceThreshold {
                stageDiffs.append(toneDiff)
                if let result = applyDiff(text: currentText, diff: toneDiff, caret: currentCaret) {
                    let lengthDelta = toneDiff.lengthDelta
                    currentText = result.text
                    currentCaret = result.caret
                    // Adjust region end to match new text length
                    currentRegion = TextRegion(
                        start: currentRegion.start,
                        end: currentRegion.end + lengthDelta
                    )
                }
            }
        }
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        
        // Track which stages actually made changes
        let stagesApplied = stageDiffs.map(\.stage)
        
        // Create a single cumulative diff from original to final
        // This avoids overlapping diffs problem when caller applies them
        var finalDiffs: [CorrectionDiff] = []
        
        if currentText != text && !stageDiffs.isEmpty {
            // Extract what the final corrected region looks like
            let finalRegionText = extractSpan(from: currentText, region: currentRegion)
            let originalRegionText = extractSpan(from: text, region: activeRegion)
            
            if finalRegionText != originalRegionText {
                // Create ONE diff that captures the cumulative change
                // Use activeRegion boundaries (original text positions) as diff applies to original text
                // Extract finalRegionText using currentRegion which tracks where the region ended up after all changes
                let cumulativeDiff = CorrectionDiff(
                    start: activeRegion.start,
                    end: activeRegion.end,
                    text: finalRegionText,
                    stage: stageDiffs.last?.stage ?? .noise,
                    confidence: stageDiffs.map(\.confidence).min() ?? 0.9
                )
                finalDiffs.append(cumulativeDiff)
            }
        }
        
        return CorrectionWaveResult(
            diffs: finalDiffs,
            activeRegion: activeRegion,
            durationMs: durationMs,
            stagesApplied: stagesApplied,
            correctedText: currentText != text ? currentText : nil
        )
    }
    
    // MARK: - Stage Implementations
    
    private func runNoiseStage(
        text: String,
        caret: Int,
        region: TextRegion
    ) async throws -> CorrectionDiff? {
        try await runStage(
            stage: .noise,
            text: text,
            caret: caret,
            region: region,
            toneTarget: nil
        )
    }
    
    private func runContextStage(
        text: String,
        caret: Int,
        region: TextRegion
    ) async throws -> CorrectionDiff? {
        try await runStage(
            stage: .context,
            text: text,
            caret: caret,
            region: region,
            toneTarget: nil
        )
    }
    
    private func runToneStage(
        text: String,
        caret: Int,
        region: TextRegion,
        toneTarget: ToneTarget
    ) async throws -> CorrectionDiff? {
        try await runStage(
            stage: .tone,
            text: text,
            caret: caret,
            region: region,
            toneTarget: toneTarget
        )
    }
    
    private func runStage(
        stage: CorrectionStage,
        text: String,
        caret: Int,
        region: TextRegion,
        toneTarget: ToneTarget?
    ) async throws -> CorrectionDiff? {
        guard isCaretSafe(region: region, caret: caret) else {
            return nil
        }
        
        // Get context around the region
        let contextBefore = extractContext(from: text, before: region.start, maxLength: 50)
        let contextAfter = extractContext(from: text, after: region.end, maxLength: 50)
        
        // Build prompt
        let prompt = PromptBuilder.build(
            stage: stage,
            text: text,
            region: region,
            contextBefore: contextBefore,
            contextAfter: contextAfter,
            toneTarget: toneTarget
        )
        
        // Generate correction
        let response = try await lmAdapter.generate(prompt: prompt, maxTokens: 128)
        
        // Parse response
        guard let replacement = ResponseParser.extractReplacement(from: response) else {
            return nil
        }
        
        // Extract original span
        let originalSpan = extractSpan(from: text, region: region)
        
        // Only create diff if there's an actual change
        guard replacement != originalSpan, !replacement.isEmpty else {
            return nil
        }
        
        return CorrectionDiff(
            start: region.start,
            end: region.end,
            text: replacement,
            stage: stage,
            confidence: 0.9  // TODO: Implement proper confidence scoring
        )
    }
    
    // MARK: - Helpers
    
    private func extractSpan(from text: String, region: TextRegion) -> String {
        guard region.start >= 0, region.end <= text.count, region.start < region.end else {
            return ""
        }
        let start = text.index(text.startIndex, offsetBy: region.start)
        let end = text.index(text.startIndex, offsetBy: region.end)
        return String(text[start..<end])
    }
    
    private func extractContext(from text: String, before index: Int, maxLength: Int) -> String? {
        guard index > 0 else { return nil }
        let start = max(0, index - maxLength)
        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: index)
        let context = String(text[startIndex..<endIndex])
        return context.isEmpty ? nil : context
    }
    
    private func extractContext(from text: String, after index: Int, maxLength: Int) -> String? {
        guard index < text.count else { return nil }
        let end = min(text.count, index + maxLength)
        let startIndex = text.index(text.startIndex, offsetBy: index)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        let context = String(text[startIndex..<endIndex])
        return context.isEmpty ? nil : context
    }
}

// MARK: - Convenience Extension

extension CorrectionPipeline {
    /// Create a pipeline with the mock adapter for testing
    public static func mock(config: PipelineConfiguration = .default) -> CorrectionPipeline {
        CorrectionPipeline(lmAdapter: MockLMAdapter(), config: config)
    }
    
    /// Create a pipeline with the real Llama adapter
    /// - Parameter modelPath: Path to GGUF model, or nil to auto-discover
    public static func withLlama(
        modelPath: String? = nil,
        config: PipelineConfiguration = .default
    ) -> CorrectionPipeline {
        CorrectionPipeline(lmAdapter: LlamaLMAdapter(), config: config)
    }
    
    /// Helper to get the recommended model path
    public static var recommendedModelPath: String? {
        ModelDiscovery.findModel()
    }
}

