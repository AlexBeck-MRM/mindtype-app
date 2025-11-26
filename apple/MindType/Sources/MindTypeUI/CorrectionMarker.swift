/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C O R R E C T I O N   M A R K E R  ░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Visual indicator that shows correction activity.          ║
  ║   Braille-inspired animation during processing.             ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ SwiftUI view for the Correction Marker
  • WHY  ▸ Visual feedback for the "Burst-Pause-Correct" rhythm
  • HOW  ▸ Animated braille symbols with state transitions
*/

import SwiftUI
import MindTypeCore

// MARK: - Correction Marker View

/// The visual correction marker with braille animation
public struct CorrectionMarkerView: View {
    @Binding var state: MarkerState
    @State private var brailleIndex = 0
    @State private var isAnimating = false
    
    // Braille animation sequence (Unicode braille patterns)
    private let brailleSequence: [String] = [
        "⠂", "⠄", "⠆", "⠠", "⠢", "⠤", "⠦", "⠰", "⠲", "⠴", "⠶"
    ]
    
    public init(state: Binding<MarkerState>) {
        self._state = state
    }
    
    public var body: some View {
        ZStack {
            // Background glow when active
            if state == .correcting {
                Circle()
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .blur(radius: 8)
            }
            
            // Braille symbol
            Text(currentSymbol)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(symbolColor)
                .animation(.easeInOut(duration: 0.2), value: brailleIndex)
        }
        .frame(width: 24, height: 24)
        .onChange(of: state) { _, newState in
            updateAnimation(for: newState)
        }
        .onAppear {
            updateAnimation(for: state)
        }
    }
    
    private var currentSymbol: String {
        switch state {
        case .idle:
            return "⠶"
        case .listening:
            return brailleSequence[brailleIndex % brailleSequence.count]
        case .correcting:
            return brailleSequence[brailleIndex % brailleSequence.count]
        case .done:
            return "✓"
        case .error:
            return "⚠"
        }
    }
    
    private var symbolColor: Color {
        switch state {
        case .idle:
            return .secondary
        case .listening:
            return .accentColor.opacity(0.7)
        case .correcting:
            return .accentColor
        case .done:
            return .green
        case .error:
            return .orange
        }
    }
    
    private func updateAnimation(for state: MarkerState) {
        isAnimating = state == .listening || state == .correcting
        
        if isAnimating {
            startAnimation()
        }
    }
    
    private func startAnimation() {
        guard isAnimating else { return }
        
        let interval: TimeInterval = state == .correcting ? 0.1 : 0.2
        
        Task { @MainActor in
            while isAnimating {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                if isAnimating {
                    brailleIndex = (brailleIndex + 1) % brailleSequence.count
                }
            }
        }
    }
}

// MARK: - Marker State

/// State of the correction marker
public enum MarkerState: Equatable, Sendable {
    case idle
    case listening
    case correcting
    case done
    case error
}

// MARK: - Active Region Highlight

/// View that highlights the active region in a text view
public struct ActiveRegionHighlight: View {
    let region: TextRegion
    let textBounds: CGRect
    let lineHeight: CGFloat
    let characterWidth: CGFloat
    
    public init(
        region: TextRegion,
        textBounds: CGRect,
        lineHeight: CGFloat = 20,
        characterWidth: CGFloat = 8
    ) {
        self.region = region
        self.textBounds = textBounds
        self.lineHeight = lineHeight
        self.characterWidth = characterWidth
    }
    
    public var body: some View {
        // Simplified rectangle highlight
        // In a real implementation, this would calculate exact positions
        Rectangle()
            .fill(Color.accentColor.opacity(0.1))
            .frame(
                width: CGFloat(region.length) * characterWidth,
                height: lineHeight
            )
            .overlay(
                Rectangle()
                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Correction Toast

/// Toast notification for applied corrections
public struct CorrectionToast: View {
    let message: String
    let stage: CorrectionStage
    @Binding var isPresented: Bool
    
    public init(message: String, stage: CorrectionStage, isPresented: Binding<Bool>) {
        self.message = message
        self.stage = stage
        self._isPresented = isPresented
    }
    
    public var body: some View {
        if isPresented {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .foregroundColor(iconColor)
                
                Text(message)
                    .font(.callout)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .cornerRadius(8)
            .shadow(radius: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        isPresented = false
                    }
                }
            }
        }
    }
    
    private var iconName: String {
        switch stage {
        case .noise: return "sparkles"
        case .context: return "text.alignleft"
        case .tone: return "wand.and.stars"
        }
    }
    
    private var iconColor: Color {
        switch stage {
        case .noise: return .orange
        case .context: return .blue
        case .tone: return .purple
        }
    }
}

// MARK: - Preview (Xcode only)

#if DEBUG && canImport(PreviewProvider)
struct CorrectionMarkerView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ForEach([MarkerState.idle, .listening, .correcting, .done, .error], id: \.self) { state in
                HStack {
                    Text(String(describing: state))
                        .frame(width: 100, alignment: .leading)
                    CorrectionMarkerView(state: .constant(state))
                }
            }
        }
        .padding()
    }
}
#endif

