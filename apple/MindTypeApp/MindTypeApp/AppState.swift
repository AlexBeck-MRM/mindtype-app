/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  A P P   S T A T E  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Central state management for the MindType app.            ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import SwiftUI
import Combine

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isEnabled = false
    @Published var lmStatus: LMStatus = .initializing
    @Published var markerState: MarkerState = .idle
    @Published var lastError: String?
    
    // Configuration
    @Published var activeRegionWords: Int = 20
    @Published var pauseDelayMs: Int = 600
    @Published var confidenceThreshold: Double = 0.80
    @Published var toneTarget: ToneTarget = .none
    
    // Stats
    @Published var correctionsApplied: Int = 0
    @Published var lastLatencyMs: Double = 0
    
    // MARK: - Private Properties
    
    private var pipeline: CorrectionPipeline?
    private var lmAdapter: MockLMAdapter?
    
    // MARK: - Initialization
    
    init() {
        Task {
            await initializePipeline()
        }
    }
    
    // MARK: - Public Methods
    
    func toggle() {
        isEnabled.toggle()
        print("MindType \(isEnabled ? "enabled" : "disabled")")
    }
    
    func restart() {
        lmStatus = .initializing
        lastError = nil
        
        Task {
            await initializePipeline()
        }
    }
    
    func runCorrection(text: String, caret: Int) async -> CorrectionResult {
        guard let pipeline = pipeline else {
            return CorrectionResult(
                originalText: text,
                correctedText: text,
                diffs: [],
                latencyMs: 0,
                error: "Pipeline not initialized"
            )
        }
        
        markerState = .correcting
        
        do {
            let result = try await pipeline.runCorrectionWave(
                text: text,
                caret: caret,
                toneTarget: toneTarget
            )
            
            markerState = result.diffs.isEmpty ? .idle : .done
            lastLatencyMs = result.durationMs
            
            // Apply diffs to get corrected text
            var correctedText = text
            if let applied = applyDiffsToText(text: text, diffs: result.diffs, caret: caret) {
                correctedText = applied
                correctionsApplied += result.diffs.count
            }
            
            // Reset marker after delay
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                await MainActor.run {
                    if self.markerState == .done {
                        self.markerState = .idle
                    }
                }
            }
            
            return CorrectionResult(
                originalText: text,
                correctedText: correctedText,
                diffs: result.diffs,
                latencyMs: result.durationMs,
                error: nil
            )
        } catch {
            markerState = .error
            lastError = error.localizedDescription
            
            return CorrectionResult(
                originalText: text,
                correctedText: text,
                diffs: [],
                latencyMs: 0,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func initializePipeline() async {
        lmStatus = .loading
        
        do {
            // Create mock adapter (will be replaced with real LM later)
            let adapter = MockLMAdapter()
            try await adapter.initialize(config: .default)
            
            self.lmAdapter = adapter
            self.pipeline = CorrectionPipeline(
                lmAdapter: adapter,
                config: PipelineConfiguration(
                    activeRegionWords: activeRegionWords,
                    pauseDelayMs: pauseDelayMs,
                    confidenceThreshold: confidenceThreshold,
                    toneTarget: toneTarget
                )
            )
            
            lmStatus = .ready
            print("✅ MindType pipeline initialized")
        } catch {
            lmStatus = .error(error.localizedDescription)
            lastError = error.localizedDescription
            print("❌ Pipeline initialization failed: \(error)")
        }
    }
    
    private func applyDiffsToText(text: String, diffs: [CorrectionDiff], caret: Int) -> String? {
        guard !diffs.isEmpty else { return text }
        
        // Sort by start position descending to preserve indices
        let sortedDiffs = diffs.sorted { $0.start > $1.start }
        
        var result = text
        for diff in sortedDiffs {
            guard diff.start >= 0, diff.end <= result.count, diff.start <= diff.end else {
                continue
            }
            
            let startIndex = result.index(result.startIndex, offsetBy: diff.start)
            let endIndex = result.index(result.startIndex, offsetBy: diff.end)
            result.replaceSubrange(startIndex..<endIndex, with: diff.text)
        }
        
        return result
    }
}

// MARK: - Supporting Types

enum LMStatus: Equatable {
    case initializing
    case loading
    case ready
    case error(String)
}

enum ToneTarget: String, CaseIterable {
    case none = "None"
    case casual = "Casual"
    case professional = "Professional"
}

enum MarkerState: Equatable {
    case idle
    case listening
    case correcting
    case done
    case error
}

struct CorrectionResult {
    let originalText: String
    let correctedText: String
    let diffs: [CorrectionDiff]
    let latencyMs: Double
    let error: String?
    
    var hasChanges: Bool {
        originalText != correctedText
    }
}

// MARK: - Embedded Types (matching MindTypeCore)

struct TextRegion: Equatable {
    let start: Int
    let end: Int
    
    var length: Int { end - start }
    var isEmpty: Bool { start >= end }
}

struct CorrectionDiff: Equatable {
    let start: Int
    let end: Int
    let text: String
    let stage: CorrectionStage
    let confidence: Double
    
    var lengthDelta: Int {
        text.count - (end - start)
    }
}

enum CorrectionStage: String, CaseIterable {
    case noise = "noise"
    case context = "context"
    case tone = "tone"
    
    var displayName: String {
        switch self {
        case .noise: return "Typo Fix"
        case .context: return "Grammar"
        case .tone: return "Tone"
        }
    }
    
    var color: Color {
        switch self {
        case .noise: return .orange
        case .context: return .blue
        case .tone: return .purple
        }
    }
}

// MARK: - Embedded Pipeline (self-contained for demo)

actor CorrectionPipeline {
    private let lmAdapter: MockLMAdapter
    private let config: PipelineConfiguration
    
    init(lmAdapter: MockLMAdapter, config: PipelineConfiguration) {
        self.lmAdapter = lmAdapter
        self.config = config
    }
    
    func runCorrectionWave(
        text: String,
        caret: Int,
        toneTarget: ToneTarget
    ) async throws -> CorrectionWaveResult {
        let startTime = Date()
        
        // Compute active region (last N words before caret)
        let region = computeActiveRegion(text: text, caret: caret)
        
        guard !region.isEmpty, region.end <= caret else {
            return CorrectionWaveResult(diffs: [], activeRegion: region, durationMs: 0)
        }
        
        var diffs: [CorrectionDiff] = []
        var currentText = text
        
        // Stage 1: Noise
        if let diff = try await runStage(.noise, text: currentText, region: region, caret: caret) {
            diffs.append(diff)
            currentText = applyDiff(text: currentText, diff: diff)
        }
        
        // Stage 2: Context (if noise produced changes, recompute region)
        if let diff = try await runStage(.context, text: currentText, region: region, caret: caret) {
            diffs.append(diff)
            currentText = applyDiff(text: currentText, diff: diff)
        }
        
        // Stage 3: Tone (optional)
        if toneTarget != .none {
            if let diff = try await runStage(.tone, text: currentText, region: region, caret: caret, tone: toneTarget) {
                diffs.append(diff)
            }
        }
        
        let durationMs = Date().timeIntervalSince(startTime) * 1000
        return CorrectionWaveResult(diffs: diffs, activeRegion: region, durationMs: durationMs)
    }
    
    private func computeActiveRegion(text: String, caret: Int) -> TextRegion {
        guard caret > 0 else { return TextRegion(start: 0, end: 0) }
        
        let safeCaret = min(caret, text.count)
        let searchText = String(text.prefix(safeCaret))
        
        // Count words backwards
        var wordCount = 0
        var regionStart = safeCaret
        
        for i in stride(from: safeCaret - 1, through: 0, by: -1) {
            let index = searchText.index(searchText.startIndex, offsetBy: i)
            let char = searchText[index]
            
            if char.isWhitespace {
                wordCount += 1
                if wordCount >= config.activeRegionWords {
                    regionStart = i + 1
                    break
                }
            }
            
            if i == 0 {
                regionStart = 0
            }
        }
        
        return TextRegion(start: regionStart, end: safeCaret)
    }
    
    private func runStage(
        _ stage: CorrectionStage,
        text: String,
        region: TextRegion,
        caret: Int,
        tone: ToneTarget? = nil
    ) async throws -> CorrectionDiff? {
        guard region.end <= caret, region.start < region.end else { return nil }
        
        let startIndex = text.index(text.startIndex, offsetBy: region.start)
        let endIndex = text.index(text.startIndex, offsetBy: region.end)
        let snippet = String(text[startIndex..<endIndex])
        
        let prompt = buildPrompt(stage: stage, snippet: snippet, tone: tone)
        let response = try await lmAdapter.generate(prompt: prompt, maxTokens: 128)
        
        guard let replacement = extractReplacement(from: response),
              replacement != snippet,
              !replacement.isEmpty else {
            return nil
        }
        
        return CorrectionDiff(
            start: region.start,
            end: region.end,
            text: replacement,
            stage: stage,
            confidence: 0.9
        )
    }
    
    private func buildPrompt(stage: CorrectionStage, snippet: String, tone: ToneTarget?) -> String {
        "<text>\(snippet)</text>"  // Mock adapter extracts this
    }
    
    private func extractReplacement(from response: String) -> String? {
        // Pattern: {"replacement":"..."}
        let pattern = #"\"replacement\"\s*:\s*\"([^\"]*)\""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: response, range: NSRange(response.startIndex..., in: response)),
              let range = Range(match.range(at: 1), in: response) else {
            return nil
        }
        return String(response[range])
    }
    
    private func applyDiff(text: String, diff: CorrectionDiff) -> String {
        var result = text
        let start = result.index(result.startIndex, offsetBy: diff.start)
        let end = result.index(result.startIndex, offsetBy: diff.end)
        result.replaceSubrange(start..<end, with: diff.text)
        return result
    }
}

struct PipelineConfiguration {
    let activeRegionWords: Int
    let pauseDelayMs: Int
    let confidenceThreshold: Double
    let toneTarget: ToneTarget
}

struct CorrectionWaveResult {
    let diffs: [CorrectionDiff]
    let activeRegion: TextRegion
    let durationMs: Double
}

// MARK: - Embedded Mock LM Adapter

actor MockLMAdapter {
    private var isReady = false
    
    func initialize(config: Any) async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
        isReady = true
    }
    
    func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard isReady else { throw NSError(domain: "MockLM", code: 1) }
        
        try await Task.sleep(nanoseconds: 50_000_000)
        
        // Extract text from prompt
        guard let range = prompt.range(of: #"(?<=<text>).*(?=</text>)"#, options: .regularExpression) else {
            return "{\"replacement\":\"\"}"
        }
        
        let input = String(prompt[range])
        let corrected = applyMockCorrections(input)
        return "{\"replacement\":\"\(corrected)\"}"
    }
    
    private func applyMockCorrections(_ text: String) -> String {
        var result = text
        
        let corrections: [String: String] = [
            "teh": "the", "hte": "the", "adn": "and", "taht": "that",
            "wiht": "with", "dont": "don't", "cant": "can't", "wont": "won't",
            "thier": "their", "recieve": "receive", "occured": "occurred",
            "seperate": "separate", "definately": "definitely",
            "accomodate": "accommodate", "occurence": "occurrence",
            "enviroment": "environment", "goverment": "government",
            "independant": "independent", "neccessary": "necessary",
            "priviledge": "privilege", "succesful": "successful",
            "tommorow": "tomorrow", "untill": "until", "wich": "which",
            "writting": "writing", "helo": "hello", "wrld": "world",
            "tpying": "typing", "corection": "correction",
            "inteligence": "intelligence", "becuase": "because",
            "freind": "friend", "beleive": "believe", "wierd": "weird",
            "alot": "a lot", "truely": "truly", "basicly": "basically",
        ]
        
        for (typo, fix) in corrections {
            result = result.replacingOccurrences(
                of: "\\b\(typo)\\b",
                with: fix,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        
        return result
    }
}

