/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D   F L O W   E D I T O R  ░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Complete Mind⠶Flow editing experience with all features.  ║
  ║   Integrates: typing monitor, sweep renderer, undo, a11y.   ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ SwiftUI text editor with Mind⠶Flow corrections
  • WHY  ▸ Demonstrate the full "burst-pause-correct" experience
  • HOW  ▸ Composes typing monitor, marker, sweep, and pipeline
*/

import SwiftUI
import MindTypeCore

// MARK: - Mind Flow Editor

/// A text editor with integrated Mind⠶Flow corrections.
///
/// Features per Mind⠶Flow guide:
/// - Caret organism marker with state animation
/// - Burst-pause-correct rhythm detection
/// - Sweep animation with trail/wake effects
/// - Atomic undo grouping
/// - Accessibility: reduced motion, screen reader batches
/// - ⌥◀ to toggle corrections
public struct MindFlowEditor: View {
    
    // MARK: - State
    
    @Binding var text: String
    @StateObject private var monitor = TypingMonitor(pauseThresholdMs: 500)
    @StateObject private var undoManager = SweepUndoManager()
    
    @State private var textBounds: CGRect = .zero
    @State private var showToast = false
    @State private var toastMessage = ""
    @State private var toastStages: [CorrectionStage] = []
    @State private var currentSweep: SweepState?
    @State private var activeRegion: TextRegion?
    
    @FocusState private var isFocused: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // MARK: - Configuration
    
    private let pipeline: CorrectionPipeline
    private let placeholder: String
    private let characterWidth: CGFloat
    private let lineHeight: CGFloat
    
    // MARK: - Initialization
    
    public init(
        text: Binding<String>,
        pipeline: CorrectionPipeline? = nil,
        placeholder: String = "Type naturally. Corrections happen after pauses...",
        characterWidth: CGFloat = 8.5,
        lineHeight: CGFloat = 22
    ) {
        self._text = text
        self.pipeline = pipeline ?? .mock()
        self.placeholder = placeholder
        self.characterWidth = characterWidth
        self.lineHeight = lineHeight
    }
    
    // MARK: - Body
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            // Main text editor
            textEditor
            
            // Correction marker (positioned relative to caret)
            markerOverlay
            
            // Sweep animation when active
            if let sweep = currentSweep, !reduceMotion {
                SweepRendererView(
                    sweep: sweep,
                    textBounds: textBounds,
                    characterWidth: characterWidth,
                    lineHeight: lineHeight
                )
            }
            
            // Active region highlight
            if let region = activeRegion, monitor.markerState.isActive {
                ActiveRegionOverlay(
                    region: region,
                    textBounds: textBounds,
                    characterWidth: characterWidth,
                    lineHeight: lineHeight,
                    isVisible: true
                )
            }
        }
        .overlay(alignment: .bottom) {
            // Toast notifications
            CorrectionToast(
                message: toastMessage,
                stages: toastStages,
                isPresented: $showToast
            )
            .padding(.bottom, 8)
        }
        .onAppear(perform: setupMonitor)
        .onChange(of: isFocused) { _, focused in
            if focused {
                monitor.onFocus(text: text, caret: text.count)
            } else {
                monitor.onBlur()
            }
        }
        .onKeyPress(.leftArrow) {
            // ⌥◀ toggle per Mind⠶Flow guide
            monitor.toggle()
            return .handled
        }
    }
    
    // MARK: - Subviews
    
    private var textEditor: some View {
        TextEditor(text: $text)
            .font(.system(size: 16, design: .monospaced))
            .focused($isFocused)
            .scrollContentBackground(.hidden)
            .padding()
            .background(
                GeometryReader { geo in
                    Color.clear
                        .onAppear { textBounds = geo.frame(in: .local) }
                        .onChange(of: geo.frame(in: .local)) { _, newFrame in
                            textBounds = newFrame
                        }
                }
            )
            .onChange(of: text) { oldValue, newValue in
                // Detect keystroke from text change
                if newValue.count > oldValue.count {
                    let diff = String(newValue.suffix(newValue.count - oldValue.count))
                    monitor.handleKeystroke(diff, at: newValue.count)
                } else if newValue.count < oldValue.count {
                    monitor.handleKeystroke("\u{7F}", at: newValue.count) // Backspace
                }
            }
    }
    
    private var markerOverlay: some View {
        CorrectionMarkerView(state: .constant(monitor.markerState))
            .position(markerPosition)
            .opacity(monitor.markerState.isActive ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: monitor.markerState.isActive)
    }
    
    private var markerPosition: CGPoint {
        let caretPos = monitor.caretPosition
        let x = textBounds.minX + CGFloat(caretPos) * characterWidth + 20
        let y = textBounds.minY + lineHeight / 2 + 16
        return CGPoint(x: x, y: y)
    }
    
    // MARK: - Setup
    
    private func setupMonitor() {
        // Configure callbacks
        monitor.onPauseDetected = { [pipeline] buffer, caret in
            do {
                return try await pipeline.runCorrectionWave(
                    text: buffer,
                    caret: caret
                )
            } catch {
                return nil
            }
        }
        
        monitor.onSweepStart = { sweep in
            currentSweep = sweep
            activeRegion = TextRegion(
                start: sweep.startPosition,
                end: sweep.endPosition
            )
        }
        
        monitor.onSweepComplete = { result in
            currentSweep = nil
            
            if !result.diffs.isEmpty {
                // Show toast
                toastMessage = "\(result.diffs.count) correction\(result.diffs.count == 1 ? "" : "s")"
                toastStages = result.stagesApplied
                withAnimation(.spring(response: 0.3)) {
                    showToast = true
                }
                
                // Screen reader announcement
                AccessibilityAnnouncement.announceCorrections(
                    count: result.diffs.count,
                    stages: result.stagesApplied
                )
            }
            
            // Clear active region after brief delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                activeRegion = nil
            }
        }
        
        monitor.onCorrectionsApplied = { [undoManager] original, corrected, region in
            text = corrected
            
            undoManager.registerSweep(
                originalText: original,
                correctedText: corrected,
                region: region,
                diffs: []
            ) { restoredText in
                text = restoredText
            }
        }
    }
}

// MARK: - Mind Flow Demo View

/// Complete demo view showing Mind⠶Flow in action
public struct MindFlowDemoView: View {
    @State private var text = ""
    @State private var showDeviceInfo = false
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Editor
            MindFlowEditor(text: $text)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            Divider()
            
            // Footer with status
            footer
        }
        .sheet(isPresented: $showDeviceInfo) {
            deviceInfoSheet
        }
    }
    
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("M I N D")
                        .fontWeight(.bold)
                    Text("⠶")
                        .foregroundColor(.accentColor)
                    Text("F L O W")
                        .fontWeight(.bold)
                }
                .font(.system(size: 14, design: .monospaced))
                
                Text("Type at the speed of thought")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button {
                showDeviceInfo = true
            } label: {
                Image(systemName: "info.circle")
            }
            .buttonStyle(.borderless)
        }
        .padding()
    }
    
    private var footer: some View {
        HStack {
            // Character/word count
            Text("\(text.count) chars · \(text.split(separator: " ").count) words")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Keyboard shortcut hint
            Text("⌥◀ to toggle")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.1), in: Capsule())
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
    
    private var deviceInfoSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Capabilities")
                .font(.headline)
            
            Text(DeviceInfo.current.summary)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.secondary)
            
            Divider()
            
            Text("Mind⠶Flow Guide")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                guideRow(symbol: "⠶", state: "Idle", description: "Ready, no activity")
                guideRow(symbol: "⠷", state: "Listening", description: "Typing detected")
                guideRow(symbol: "⠴", state: "Thinking", description: "Preparing corrections")
                guideRow(symbol: "⠖", state: "Sweeping", description: "Applying fixes")
                guideRow(symbol: "⠿", state: "Complete", description: "Corrections applied")
            }
            
            Spacer()
            
            Button("Done") {
                showDeviceInfo = false
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity)
        }
        .padding()
        .frame(minWidth: 300, minHeight: 400)
    }
    
    private func guideRow(symbol: String, state: String, description: String) -> some View {
        HStack {
            Text(symbol)
                .font(.system(size: 20, design: .monospaced))
                .frame(width: 30)
            
            VStack(alignment: .leading) {
                Text(state)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Micro-Scenes Demo

/// Demonstrates the micro-scenes from Mind⠶Flow guide
public struct MicroScenesDemo: View {
    @State private var currentScene = 0
    @State private var isAnimating = false
    
    private let scenes: [(title: String, before: String, after: String)] = [
        ("Trivial typo burst", "Teh quick borwn fx jumps", "The quick brown fox jumps"),
        ("Punctuation + spacing", "However  this isnt right is it", "However, this isn't right, is it"),
        ("Agreement + article", "It was a unusual event", "It was an unusual event"),
        ("Micro-reorder", "The team quickly, after review approved", "After review, the team quickly approved"),
        ("Tone-preserving", "That's kinda messy", "That's a bit messy"),
    ]
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 24) {
            Text("Mind⠶Flow Micro-Scenes")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(scenes[currentScene].title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading) {
                        Text("Before")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("⠶ \(scenes[currentScene].before)")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    Image(systemName: "arrow.right")
                        .foregroundColor(.accentColor)
                    
                    VStack(alignment: .leading) {
                        Text("After")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("⠿ \(scenes[currentScene].after)")
                            .font(.system(.body, design: .monospaced))
                    }
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            
            HStack {
                Button("Previous") {
                    withAnimation {
                        currentScene = (currentScene - 1 + scenes.count) % scenes.count
                    }
                }
                .disabled(currentScene == 0)
                
                Spacer()
                
                Text("\(currentScene + 1) / \(scenes.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("Next") {
                    withAnimation {
                        currentScene = (currentScene + 1) % scenes.count
                    }
                }
                .disabled(currentScene == scenes.count - 1)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#if DEBUG
struct MindFlowEditor_Previews: PreviewProvider {
    static var previews: some View {
        MindFlowDemoView()
            .frame(width: 600, height: 400)
    }
}
#endif

