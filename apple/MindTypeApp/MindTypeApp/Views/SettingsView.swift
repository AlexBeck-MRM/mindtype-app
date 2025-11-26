/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  S E T T I N G S   V I E W  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Configuration panel for MindType pipeline settings.       ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import SwiftUI
import MindTypeCore

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView {
            generalSettings
                .tabItem {
                    Label("General", systemImage: "gear")
                }
            
            correctionSettings
                .tabItem {
                    Label("Corrections", systemImage: "wand.and.stars")
                }
            
            advancedSettings
                .tabItem {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                }
        }
        .frame(width: 450, height: 300)
    }
    
    // MARK: - General Settings
    
    private var generalSettings: some View {
        Form {
            Section {
                Toggle("Enable MindType", isOn: $appState.isEnabled)
                
                LabeledContent("Status") {
                    HStack {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                        Text(statusText)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if case .error = appState.lmStatus {
                    Button("Restart Engine") {
                        appState.restart()
                    }
                }
            } header: {
                Text("Engine")
            }
            
            Section {
                LabeledContent("Corrections Applied") {
                    Text("\(appState.correctionsApplied)")
                        .foregroundStyle(.secondary)
                }
                
                if appState.lastLatencyMs > 0 {
                    LabeledContent("Last Latency") {
                        Text(String(format: "%.0f ms", appState.lastLatencyMs))
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Statistics")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Correction Settings
    
    private var correctionSettings: some View {
        Form {
            Section {
                Picker("Tone Target", selection: $appState.toneTarget) {
                    ForEach(MindTypeCore.ToneTarget.allCases, id: \.self) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                
                Text("When set, the tone stage will adjust writing style.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Tone")
            }
            
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Confidence Threshold")
                        Spacer()
                        Text(String(format: "%.0f%%", appState.confidenceThreshold * 100))
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $appState.confidenceThreshold, in: 0.5...0.95, step: 0.05)
                }
                
                Text("Higher values require more certainty before applying corrections.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Confidence")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Advanced Settings
    
    private var advancedSettings: some View {
        Form {
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Active Region Size")
                        Spacer()
                        Text("\(appState.activeRegionWords) words")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(appState.activeRegionWords) },
                            set: { appState.activeRegionWords = Int($0) }
                        ),
                        in: 5...50,
                        step: 5
                    )
                }
                
                Text("How many words before cursor to analyze. More words = more context but slower.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Active Region")
            }
            
            Section {
                VStack(alignment: .leading) {
                    HStack {
                        Text("LLM Temperature")
                        Spacer()
                        Text(String(format: "%.2f", appState.temperature))
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    
                    Slider(
                        value: Binding(
                            get: { Double(appState.temperature) },
                            set: { appState.temperature = Float($0) }
                        ),
                        in: 0.0...0.5,
                        step: 0.05
                    )
                }
                
                Text("Lower = more consistent corrections. Higher = more creative but may hallucinate.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Language Model")
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    // MARK: - Helpers
    
    private var statusColor: Color {
        switch appState.lmStatus {
        case .ready: return .green
        case .error: return .red
        case .loading, .initializing: return .orange
        }
    }
    
    private var statusText: String {
        switch appState.lmStatus {
        case .ready: return "Ready"
        case .error(let msg): return "Error: \(msg)"
        case .loading, .initializing: return "Loading..."
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState())
}

