/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  A P P   S T A T E  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Central state management for the MindType app.            ║
  ║   Uses MindTypeCore for pipeline and correction types.      ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import SwiftUI
import Combine
import MindTypeCore

// MARK: - App State

@MainActor
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    @Published var isEnabled = false
    @Published var lmStatus: AppLMStatus = .initializing
    @Published var markerState: AppMarkerState = .idle
    @Published var lastError: String?
    
    // Configuration — these directly affect correction behavior
    @Published var activeRegionWords: Int = 20 {
        didSet { scheduleReinitialization() }
    }
    @Published var confidenceThreshold: Double = 0.80 {
        didSet { scheduleReinitialization() }
    }
    @Published var temperature: Float = 0.1 {
        didSet { scheduleReinitialization() }
    }
    @Published var toneTarget: MindTypeCore.ToneTarget = .none
    
    // Stats
    @Published var correctionsApplied: Int = 0
    @Published var lastLatencyMs: Double = 0
    
    // MARK: - Private Properties
    
    private var pipeline: MindTypeCore.CorrectionPipeline?
    private var lmAdapter: (any MindTypeCore.LMAdapter)?
    private var reinitTask: Task<Void, Never>?
    
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
    
    /// Debounced reinitialization when settings change
    private func scheduleReinitialization() {
        reinitTask?.cancel()
        reinitTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms debounce
            guard !Task.isCancelled else { return }
            await initializePipeline()
        }
    }
    
    func runCorrection(text: String, caret: Int) async -> AppCorrectionResult {
        guard let pipeline = pipeline else {
            return AppCorrectionResult(
                originalText: text,
                correctedText: text,
                diffs: [],
                stagesApplied: [],
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
            
            // Use the new correctedText property if available
            let correctedText = result.correctedText ?? text
            if result.correctedText != nil {
                correctionsApplied += result.stagesApplied.count
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
            
            return AppCorrectionResult(
                originalText: text,
                correctedText: correctedText,
                diffs: result.diffs.map { AppCorrectionDiff(from: $0) },
                stagesApplied: result.stagesApplied.map { AppCorrectionStage(from: $0) },
                latencyMs: result.durationMs,
                error: nil
            )
        } catch {
            markerState = .error
            lastError = error.localizedDescription
            
            return AppCorrectionResult(
                originalText: text,
                correctedText: text,
                diffs: [],
                stagesApplied: [],
                latencyMs: 0,
                error: error.localizedDescription
            )
        }
    }
    
    // MARK: - Private Methods
    
    private func initializePipeline() async {
        lmStatus = .loading
        
        // Build pipeline config from current settings
        let pipelineConfig = MindTypeCore.PipelineConfiguration(
            activeRegionWords: activeRegionWords,
            confidenceThreshold: confidenceThreshold,
            toneTarget: toneTarget,
            temperature: temperature
        )
        
        do {
            // Try to use real LLM if model is available
            if let modelPath = MindTypeCore.ModelDiscovery.findModel() {
                print("🧠 Model: \(modelPath.split(separator: "/").last ?? "")")
                let llamaAdapter = MindTypeCore.LlamaLMAdapter()
                do {
                    // Pass temperature to LM config
                    try await llamaAdapter.initialize(config: .gguf(modelPath, temperature: temperature))
                    self.lmAdapter = llamaAdapter
                    self.pipeline = MindTypeCore.CorrectionPipeline(
                        lmAdapter: llamaAdapter,
                        config: pipelineConfig
                    )
                    lmStatus = .ready
                    print("✅ Pipeline ready (words=\(activeRegionWords), conf=\(String(format: "%.0f%%", confidenceThreshold*100)), temp=\(temperature))")
                    return
                } catch {
                    print("⚠️  LLM failed: \(error.localizedDescription), using mock")
                }
            }
            
            // Fall back to mock adapter
            let mockAdapter = MindTypeCore.MockLMAdapter()
            try await mockAdapter.initialize(config: .default)
            
            self.lmAdapter = mockAdapter
            self.pipeline = MindTypeCore.CorrectionPipeline(
                lmAdapter: mockAdapter,
                config: pipelineConfig
            )
            
            lmStatus = .ready
            print("✅ Pipeline ready (mock, words=\(activeRegionWords), conf=\(String(format: "%.0f%%", confidenceThreshold*100)))")
        } catch {
            lmStatus = .error(error.localizedDescription)
            lastError = error.localizedDescription
            print("❌ Pipeline failed: \(error)")
        }
    }
}
        
// MARK: - App-Level Types (thin wrappers for SwiftUI compatibility)

/// LM status for display
enum AppLMStatus: Equatable {
    case initializing
    case loading
    case ready
    case error(String)
}

/// Marker state for UI animation
enum AppMarkerState: Equatable {
    case idle
    case listening
    case correcting
    case done
    case error
}

/// Correction stage wrapper for UI
enum AppCorrectionStage: String, CaseIterable {
    case noise = "noise"
    case context = "context"
    case tone = "tone"
    
    init(from core: MindTypeCore.CorrectionStage) {
        switch core {
        case .noise: self = .noise
        case .context: self = .context
        case .tone: self = .tone
        }
    }
    
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

/// Correction diff wrapper for UI
struct AppCorrectionDiff: Equatable {
    let start: Int
    let end: Int
    let text: String
    let stage: AppCorrectionStage
    let confidence: Double
    
    init(from core: MindTypeCore.CorrectionDiff) {
        self.start = core.start
        self.end = core.end
        self.text = core.text
        self.stage = AppCorrectionStage(from: core.stage)
        self.confidence = core.confidence
    }
    
    var lengthDelta: Int {
        text.count - (end - start)
    }
}

/// Result of running a correction
struct AppCorrectionResult {
    let originalText: String
    let correctedText: String
    let diffs: [AppCorrectionDiff]
    let stagesApplied: [AppCorrectionStage]
    let latencyMs: Double
    let error: String?
    
    var hasChanges: Bool {
        originalText != correctedText
    }
}
