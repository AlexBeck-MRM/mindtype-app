/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  T Y P I N G   M O N I T O R  ░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Burst-Pause-Correct rhythm detection per Mind⠶Flow guide.  ║
  ║   Triggers correction waves on natural typing pauses.        ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Monitors keystroke timing to detect burst-pause rhythm
  • WHY  ▸ Aligns edits to natural pauses (~500ms) for flow preservation
  • HOW  ▸ Timer-based pause detection with configurable threshold
*/

import Foundation

// MARK: - Typing Monitor

/// Monitors typing rhythm and triggers correction waves on natural pauses.
///
/// The Burst-Pause-Correct cycle per Mind⠶Flow guide:
/// 1. **BURST** — User types rapidly, trusting the system
/// 2. **PAUSE** — Natural breathing moment (≥500ms trigger)
/// 3. **CORRECT** — Marker travels through text, applying fixes
/// 4. **RESUME** — Seamless continuation with enhanced confidence
@MainActor
public final class TypingMonitor: ObservableObject {
    
    // MARK: - Published State
    
    /// Current rhythm state
    @Published public private(set) var rhythm: TypingRhythm = .idle
    
    /// Current marker state
    @Published public private(set) var markerState: MarkerState = .dormant
    
    /// Text buffer accumulated during burst
    @Published public private(set) var buffer: String = ""
    
    /// Current caret position
    @Published public private(set) var caretPosition: Int = 0
    
    /// Whether the monitor is enabled (can be toggled with ⌥◀)
    @Published public var isEnabled: Bool = true
    
    // MARK: - Configuration
    
    /// Milliseconds of pause before triggering correction
    public var pauseThresholdMs: Int = 500
    
    /// Minimum characters before attempting correction
    public var minCharacters: Int = 10
    
    /// Minimum words before attempting correction
    public var minWords: Int = 3
    
    // MARK: - Callbacks
    
    /// Called when a pause is detected and correction should begin
    public var onPauseDetected: ((String, Int) async -> CorrectionWaveResult?)?
    
    /// Called when a sweep should begin
    public var onSweepStart: ((SweepState) -> Void)?
    
    /// Called when a sweep completes
    public var onSweepComplete: ((CorrectionWaveResult) -> Void)?
    
    /// Called when corrections are applied (for undo grouping)
    public var onCorrectionsApplied: ((String, String, TextRegion) -> Void)?
    
    // MARK: - Private State
    
    private var lastKeystrokeTime: Date = .distantPast
    private var pauseTimer: Timer?
    private var currentSweep: SweepState?
    private var sweepDisplayLink: CADisplayLink?
    
    // MARK: - Initialization
    
    public init(pauseThresholdMs: Int = 500) {
        self.pauseThresholdMs = pauseThresholdMs
    }
    
    deinit {
        pauseTimer?.invalidate()
        sweepDisplayLink?.invalidate()
    }
    
    // MARK: - Public API
    
    /// Call when the user focuses an editable field
    public func onFocus(text: String, caret: Int) {
        guard isEnabled else {
            markerState = .disabled
            return
        }
        
        buffer = text
        caretPosition = caret
        rhythm = .idle
        markerState = .idle(position: caret)
    }
    
    /// Call when the user leaves an editable field
    public func onBlur() {
        pauseTimer?.invalidate()
        pauseTimer = nil
        rhythm = .idle
        markerState = .dormant
        buffer = ""
        caretPosition = 0
        
        // Re-enable if was disabled (per guide: resets on blur)
        isEnabled = true
    }
    
    /// Call on each keystroke
    public func handleKeystroke(_ character: String, at position: Int) {
        guard isEnabled else { return }
        
        lastKeystrokeTime = Date()
        caretPosition = position
        
        // Update buffer
        if character == "\u{7F}" { // Backspace
            if !buffer.isEmpty && position < buffer.count {
                let index = buffer.index(buffer.startIndex, offsetBy: position)
                buffer.remove(at: index)
            }
        } else if character.count == 1 && !character.first!.isNewline {
            if position <= buffer.count {
                let index = buffer.index(buffer.startIndex, offsetBy: position)
                buffer.insert(contentsOf: character, at: index)
            } else {
                buffer += character
            }
        }
        
        // Transition to bursting
        if case .correcting = rhythm {
            // Don't interrupt an active correction
            return
        }
        
        rhythm = .bursting(since: lastKeystrokeTime)
        markerState = .listening(position: caretPosition)
        
        // Reset pause timer
        schedulePauseDetection()
    }
    
    /// Call when text changes externally (paste, etc.)
    public func handleTextChange(newText: String, caret: Int) {
        guard isEnabled else { return }
        
        buffer = newText
        caretPosition = caret
        lastKeystrokeTime = Date()
        
        rhythm = .bursting(since: lastKeystrokeTime)
        markerState = .listening(position: caretPosition)
        
        schedulePauseDetection()
    }
    
    /// Toggle enabled state (⌥◀ handler)
    public func toggle() {
        isEnabled.toggle()
        
        if isEnabled {
            markerState = .idle(position: caretPosition)
        } else {
            pauseTimer?.invalidate()
            markerState = .disabled
            rhythm = .idle
        }
    }
    
    /// Force a correction now (Enter key or explicit request)
    public func forceCorrection() async {
        guard isEnabled, !buffer.isEmpty else { return }
        await triggerCorrection()
    }
    
    // MARK: - Private Methods
    
    private func schedulePauseDetection() {
        pauseTimer?.invalidate()
        
        let threshold = TimeInterval(pauseThresholdMs) / 1000.0
        pauseTimer = Timer.scheduledTimer(withTimeInterval: threshold, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.onPauseTimerFired()
            }
        }
    }
    
    private func onPauseTimerFired() async {
        // Verify we're still in bursting state and enough time has passed
        guard case .bursting = rhythm else { return }
        
        let elapsed = Date().timeIntervalSince(lastKeystrokeTime) * 1000
        guard elapsed >= Double(pauseThresholdMs) else {
            // User started typing again, reschedule
            schedulePauseDetection()
            return
        }
        
        // Transition to paused
        rhythm = .paused(since: Date())
        markerState = .thinking(position: caretPosition)
        
        // Brief delay to show "thinking" state, then trigger correction
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        
        await triggerCorrection()
    }
    
    private func triggerCorrection() async {
        // Validate minimum requirements
        let wordCount = buffer.split(separator: " ").count
        guard buffer.count >= minCharacters, wordCount >= minWords else {
            // Not enough content, return to idle
            rhythm = .idle
            markerState = .idle(position: caretPosition)
            return
        }
        
        rhythm = .correcting
        
        // Request correction from pipeline
        guard let result = await onPauseDetected?(buffer, caretPosition) else {
            // No correction needed or error
            rhythm = .idle
            markerState = .idle(position: caretPosition)
            return
        }
        
        // If corrections were made, start sweep animation
        if !result.diffs.isEmpty, let correctedText = result.correctedText {
            await startSweep(result: result, correctedText: correctedText)
        } else {
            // No changes
            markerState = .complete(position: caretPosition)
            
            // Brief pause then return to idle
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
            rhythm = .idle
            markerState = .idle(position: caretPosition)
        }
    }
    
    private func startSweep(result: CorrectionWaveResult, correctedText: String) async {
        let sweep = SweepState(
            startPosition: result.activeRegion.start,
            endPosition: caretPosition,
            progress: 0.0,
            corrections: result.diffs,
            duration: 0.3 // Will be adjusted by device tier
        )
        
        currentSweep = sweep
        onSweepStart?(sweep)
        
        // Animate the sweep
        await animateSweep(sweep: sweep, result: result, correctedText: correctedText)
    }
    
    private func animateSweep(sweep: SweepState, result: CorrectionWaveResult, correctedText: String) async {
        let startTime = Date()
        let duration = sweep.duration
        
        while true {
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(1.0, elapsed / duration)
            
            let updatedSweep = SweepState(
                startPosition: sweep.startPosition,
                endPosition: sweep.endPosition,
                progress: progress,
                corrections: sweep.corrections,
                duration: sweep.duration
            )
            
            currentSweep = updatedSweep
            markerState = .sweeping(
                from: sweep.startPosition,
                to: sweep.endPosition,
                progress: progress
            )
            
            if progress >= 1.0 {
                break
            }
            
            // ~60 FPS
            try? await Task.sleep(nanoseconds: 16_666_667)
        }
        
        // Sweep complete — apply corrections
        let originalText = buffer
        buffer = correctedText
        
        // Notify for undo grouping
        onCorrectionsApplied?(originalText, correctedText, result.activeRegion)
        onSweepComplete?(result)
        
        // Show completion state
        markerState = .complete(position: caretPosition)
        
        // Brief pause then return to idle
        try? await Task.sleep(nanoseconds: 400_000_000) // 400ms
        
        currentSweep = nil
        rhythm = .idle
        markerState = .idle(position: caretPosition)
    }
}

// MARK: - CADisplayLink (macOS)

#if os(macOS)
import AppKit

/// CADisplayLink equivalent for macOS
public class CADisplayLink {
    private var displayLink: CVDisplayLink?
    private var callback: (() -> Void)?
    
    public init(callback: @escaping () -> Void) {
        self.callback = callback
    }
    
    public func invalidate() {
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }
        displayLink = nil
        callback = nil
    }
}
#endif

