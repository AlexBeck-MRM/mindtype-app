/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C O R R E C T I O N   M A R K E R  ░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   The "Caret Organism" — intelligent visual worker that      ║
  ║   travels through text during correction sweeps.             ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ SwiftUI views for the Mind⠶Flow correction marker
  • WHY  ▸ Visual feedback for the "Burst-Pause-Correct" rhythm
  • HOW  ▸ Braille symbols + sweep animation + trail/wake effects
*/

import SwiftUI
import MindTypeCore

// MARK: - Correction Marker View

/// The visual correction marker — the "caret organism" per Mind⠶Flow guide.
///
/// State language:
/// - **Listening**: calm pulse loop (⠷)
/// - **Thinking**: faster alternation (⠴)
/// - **Cleaning**: sweep pattern with trail/wake (⠖)
public struct CorrectionMarkerView: View {
    @Binding var state: MarkerState
    @State private var brailleFrame = 0
    @State private var pulseScale: CGFloat = 1.0
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    
    // Braille animation sequences per state — middle 2x2 grid (dots 2,3,5,6)
    private let listeningSequence = ["⠤", "⠴", "⠤", "⠴"]
    private let thinkingSequence = ["⠦", "⠶", "⠦", "⠲", "⠦", "⠶"]
    private let sweepingSequence = ["⠶", "⠦", "⠴", "⠲"]
    
    public init(state: Binding<MarkerState>) {
        self._state = state
    }
    
    public var body: some View {
        ZStack {
            // Glow effect for active states
            if state.isAnimating && !reduceMotion {
                glowEffect
            }
            
            // Braille symbol
            symbolView
        }
        .frame(width: 24, height: 24)
        .onChange(of: state) { _, newState in
            updateAnimation(for: newState)
        }
        .onAppear {
            updateAnimation(for: state)
        }
        .accessibilityLabel(state.accessibilityDescription)
        .accessibilityAddTraits(.updatesFrequently)
    }
    
    // MARK: - Subviews
    
    private var glowEffect: some View {
        Circle()
            .fill(glowColor.opacity(0.25))
            .frame(width: 28, height: 28)
            .blur(radius: 6)
            .scaleEffect(pulseScale)
    }
    
    private var symbolView: some View {
        Text(currentSymbol)
            .font(.system(size: 18, weight: .semibold, design: .monospaced))
            .foregroundColor(symbolColor)
            .scaleEffect(reduceMotion ? 1.0 : pulseScale)
            .animation(
                reduceMotion ? nil : .easeInOut(duration: animationSpeed),
                value: brailleFrame
            )
    }
    
    // MARK: - Computed Properties
    
    private var currentSymbol: String {
        if reduceMotion {
            return state.brailleSymbol
        }
        
        switch state {
        case .dormant, .disabled:
            return ""
        case .idle:
            return "⠤"  // dots 3,6 — stable
        case .listening:
            return listeningSequence[brailleFrame % listeningSequence.count]
        case .thinking:
            return thinkingSequence[brailleFrame % thinkingSequence.count]
        case .sweeping:
            return sweepingSequence[brailleFrame % sweepingSequence.count]
        case .complete:
            return "⠲"  // dots 2,5,6 — satisfied
        case .error:
            return "⠆"  // dots 2,3 — interrupted
        }
    }
    
    private var symbolColor: Color {
        switch state {
        case .dormant, .disabled:
            return .clear
        case .idle:
            return .secondary
        case .listening:
            return .accentColor.opacity(0.7)
        case .thinking:
            return .orange
        case .sweeping:
            return .accentColor
        case .complete:
            return .green
        case .error:
            return .red
        }
    }
    
    private var glowColor: Color {
        switch state {
        case .listening: return .accentColor
        case .thinking: return .orange
        case .sweeping: return .accentColor
        case .complete: return .green
        default: return .clear
        }
    }
    
    private var animationSpeed: Double {
        switch state {
        case .listening: return 0.6
        case .thinking: return 0.15
        case .sweeping: return 0.1
        default: return 0.3
        }
    }
    
    // MARK: - Animation
    
    private func updateAnimation(for state: MarkerState) {
        guard !reduceMotion else {
            brailleFrame = 0
            pulseScale = 1.0
            return
        }
        
        switch state {
        case .dormant, .disabled, .idle, .error:
            brailleFrame = 0
            pulseScale = 1.0
            
        case .listening:
            startPulseAnimation(intensity: 0.05, speed: 0.8)
            startFrameAnimation(speed: 0.5)
            
        case .thinking:
            startPulseAnimation(intensity: 0.1, speed: 0.3)
            startFrameAnimation(speed: 0.12)
            
        case .sweeping:
            startPulseAnimation(intensity: 0.15, speed: 0.15)
            startFrameAnimation(speed: 0.08)
            
        case .complete:
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                pulseScale = 1.2
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                    pulseScale = 1.0
                }
            }
        }
    }
    
    private func startPulseAnimation(intensity: CGFloat, speed: Double) {
        withAnimation(.easeInOut(duration: speed).repeatForever(autoreverses: true)) {
            pulseScale = 1.0 + intensity
        }
    }
    
    private func startFrameAnimation(speed: Double) {
        Task { @MainActor in
            while state.isAnimating {
                try? await Task.sleep(nanoseconds: UInt64(speed * 1_000_000_000))
                if state.isAnimating {
                    brailleFrame += 1
                }
            }
        }
    }
}

// MARK: - Sweep Renderer

/// Renders the marker sweep animation with trail and wake effects.
///
/// Per Mind⠶Flow guide:
/// - Marker travels toward the caret
/// - Unveils fixes as it passes
/// - Trail: "whoosh" effect following the marker
/// - Wake: 85%→0% opacity fade behind the trail
public struct SweepRendererView: View {
    let sweep: SweepState
    let textBounds: CGRect
    let characterWidth: CGFloat
    let lineHeight: CGFloat
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        sweep: SweepState,
        textBounds: CGRect,
        characterWidth: CGFloat = 8.5,
        lineHeight: CGFloat = 22
    ) {
        self.sweep = sweep
        self.textBounds = textBounds
        self.characterWidth = characterWidth
        self.lineHeight = lineHeight
    }
    
    public var body: some View {
        ZStack {
            if !reduceMotion {
                // Wake effect (fading highlight behind the sweep)
                wakeEffect
                
                // Trail effect (line following marker)
                trailEffect
            }
            
            // Correction highlights (unveiled regions)
            correctionHighlights
            
            // Marker head at current position
            markerHead
        }
    }
    
    // MARK: - Subviews
    
    private var wakeEffect: some View {
        // Gradient from swept region to current position
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.0),
                        Color.accentColor.opacity(0.1 * (1 - sweep.progress))
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: wakeWidth, height: lineHeight)
            .position(wakePosition)
            .animation(.easeOut(duration: 0.1), value: sweep.progress)
    }
    
    private var trailEffect: some View {
        // "Whoosh" line trailing the marker
        Capsule()
            .fill(
                LinearGradient(
                    colors: [
                        Color.accentColor.opacity(0.85),
                        Color.accentColor.opacity(0.3),
                        Color.clear
                    ],
                    startPoint: .trailing,
                    endPoint: .leading
                )
            )
            .frame(width: trailWidth, height: 3)
            .position(trailPosition)
            .animation(.easeOut(duration: 0.05), value: sweep.progress)
    }
    
    private var correctionHighlights: some View {
        ForEach(Array(sweep.corrections.enumerated()), id: \.offset) { index, correction in
            if sweep.shouldUnveilCorrection(at: index) {
                CorrectionHighlightView(
                    correction: correction,
                    textBounds: textBounds,
                    characterWidth: characterWidth,
                    lineHeight: lineHeight
                )
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
    }
    
    private var markerHead: some View {
        CorrectionMarkerView(state: .constant(.sweeping(
            from: sweep.startPosition,
            to: sweep.endPosition,
            progress: sweep.progress
        )))
        .position(markerPosition)
        .animation(.easeOut(duration: 0.05), value: sweep.progress)
    }
    
    // MARK: - Position Calculations
    
    private var markerPosition: CGPoint {
        let x = textBounds.minX + CGFloat(sweep.currentPosition) * characterWidth
        let y = textBounds.midY
        return CGPoint(x: x, y: y)
    }
    
    private var trailWidth: CGFloat {
        min(60, CGFloat(sweep.currentPosition - sweep.startPosition) * characterWidth * 0.3)
    }
    
    private var trailPosition: CGPoint {
        let x = markerPosition.x - trailWidth / 2
        return CGPoint(x: x, y: markerPosition.y)
    }
    
    private var wakeWidth: CGFloat {
        CGFloat(sweep.currentPosition - sweep.startPosition) * characterWidth
    }
    
    private var wakePosition: CGPoint {
        let x = textBounds.minX + CGFloat(sweep.startPosition) * characterWidth + wakeWidth / 2
        return CGPoint(x: x, y: textBounds.midY)
    }
}

// MARK: - Correction Highlight

/// Highlights a single correction region during/after sweep
public struct CorrectionHighlightView: View {
    let correction: CorrectionDiff
    let textBounds: CGRect
    let characterWidth: CGFloat
    let lineHeight: CGFloat
    
    public var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(highlightColor.opacity(0.2))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(highlightColor.opacity(0.4), lineWidth: 1)
            )
            .frame(width: width, height: lineHeight)
            .position(position)
    }
    
    private var width: CGFloat {
        CGFloat(correction.text.count) * characterWidth
    }
    
    private var position: CGPoint {
        let x = textBounds.minX + CGFloat(correction.start) * characterWidth + width / 2
        return CGPoint(x: x, y: textBounds.midY)
    }
    
    private var highlightColor: Color {
        switch correction.stage {
        case .noise: return .orange
        case .context: return .blue
        case .tone: return .purple
        }
    }
}

// MARK: - Active Region Overlay

/// Subtle highlight showing the active correction region
public struct ActiveRegionOverlay: View {
    let region: TextRegion
    let textBounds: CGRect
    let characterWidth: CGFloat
    let lineHeight: CGFloat
    let isVisible: Bool
    
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    public init(
        region: TextRegion,
        textBounds: CGRect,
        characterWidth: CGFloat = 8.5,
        lineHeight: CGFloat = 22,
        isVisible: Bool = true
    ) {
        self.region = region
        self.textBounds = textBounds
        self.characterWidth = characterWidth
        self.lineHeight = lineHeight
        self.isVisible = isVisible
    }
    
    public var body: some View {
        if isVisible && !region.isEmpty {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.accentColor.opacity(reduceMotion ? 0.1 : 0.05))
                .frame(width: width, height: lineHeight + 4)
                .position(position)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: region)
        }
    }
    
    private var width: CGFloat {
        CGFloat(region.length) * characterWidth
    }
    
    private var position: CGPoint {
        let x = textBounds.minX + CGFloat(region.start) * characterWidth + width / 2
        return CGPoint(x: x, y: textBounds.midY)
    }
}

// MARK: - Correction Toast

/// Brief notification when corrections are applied
public struct CorrectionToast: View {
    let message: String
    let stages: [CorrectionStage]
    @Binding var isPresented: Bool
    
    public init(message: String, stages: [CorrectionStage], isPresented: Binding<Bool>) {
        self.message = message
        self.stages = stages
        self._isPresented = isPresented
    }
    
    public var body: some View {
        if isPresented {
            HStack(spacing: 8) {
                // Stage icons
                ForEach(stages, id: \.self) { stage in
                    Image(systemName: stage.iconName)
                        .foregroundColor(stage.color)
                        .font(.caption)
                }
                
                Text(message)
                    .font(.callout)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.1), radius: 4, y: 2)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation(.easeOut(duration: 0.2)) {
                        isPresented = false
                    }
                }
            }
            .accessibilityLabel("Corrections applied: \(message)")
        }
    }
}

// MARK: - Stage Extensions

extension CorrectionStage {
    var iconName: String {
        switch self {
        case .noise: return "sparkles"
        case .context: return "text.alignleft"
        case .tone: return "wand.and.stars"
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

// MARK: - Accessibility Announcement

/// Helper for screen reader announcements per Mind⠶Flow accessibility requirements
public struct AccessibilityAnnouncement {
    /// Announce corrections with single batch message (polite)
    /// Per guide: "text updated behind cursor" with cooldown
    public static func announceCorrections(count: Int, stages: [CorrectionStage]) {
        #if os(macOS)
        let message: String
        if count == 1 {
            message = "Text updated behind cursor"
        } else {
            let stageNames = stages.map(\.displayName).joined(separator: ", ")
            message = "\(count) corrections applied: \(stageNames)"
        }
        
        // Post as polite announcement (won't interrupt)
        NSAccessibility.post(element: NSApp as Any, notification: .announcementRequested, userInfo: [
            .announcement: message,
            .priority: NSAccessibilityPriorityLevel.medium
        ])
        #endif
    }
}

// MARK: - Preview

#if DEBUG
struct CorrectionMarker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 24) {
            Text("Marker States")
                .font(.headline)
            
            HStack(spacing: 20) {
                VStack {
                    CorrectionMarkerView(state: .constant(.idle(position: 0)))
                    Text("Idle").font(.caption)
                }
                VStack {
                    CorrectionMarkerView(state: .constant(.listening(position: 0)))
                    Text("Listening").font(.caption)
                }
                VStack {
                    CorrectionMarkerView(state: .constant(.thinking(position: 0)))
                    Text("Thinking").font(.caption)
                }
                VStack {
                    CorrectionMarkerView(state: .constant(.sweeping(from: 0, to: 100, progress: 0.5)))
                    Text("Sweeping").font(.caption)
                }
                VStack {
                    CorrectionMarkerView(state: .constant(.complete(position: 0)))
                    Text("Complete").font(.caption)
                }
            }
        }
        .padding()
    }
}
#endif
