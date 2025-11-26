/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M E N U   B A R   V I E W  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Menu bar dropdown UI for MindType status and controls.    ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) var openWindow
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("Mind⠶Type")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("v1.0")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                statusIndicator
            }
            
            Divider()
            
            // Main toggle
            Toggle("Enable Corrections", isOn: $appState.isEnabled)
                .toggleStyle(.switch)
            
            // Error display
            if case .error(let message) = appState.lmStatus {
                errorBanner(message: message)
            }
            
            Divider()
            
            // Stats
            if appState.correctionsApplied > 0 {
                HStack {
                    Label("\(appState.correctionsApplied) corrections", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    if appState.lastLatencyMs > 0 {
                        Text(String(format: "%.0f ms", appState.lastLatencyMs))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            // Actions
            VStack(alignment: .leading, spacing: 4) {
                Button {
                    openWindow(id: "testing-ground")
                } label: {
                    Label("Testing Ground...", systemImage: "flask")
                }
                .buttonStyle(.borderless)
                
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Label("Settings...", systemImage: "gear")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut(",", modifiers: .command)
            }
            
            Divider()
            
            Button("Quit MindType") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.borderless)
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding()
        .frame(width: 260)
    }
    
    // MARK: - Components
    
    private var statusIndicator: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private var statusColor: Color {
        if !appState.isEnabled { return .gray }
        
        switch appState.lmStatus {
        case .ready: return .green
        case .error: return .red
        case .loading, .initializing: return .orange
        }
    }
    
    private var statusText: String {
        if !appState.isEnabled { return "Disabled" }
        
        switch appState.lmStatus {
        case .ready: return "Ready"
        case .error: return "Error"
        case .loading, .initializing: return "Loading..."
        }
    }
    
    private func errorBanner(message: String) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            
            Text("LM Error")
                .font(.caption)
            
            Spacer()
            
            Button("Restart") {
                appState.restart()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(8)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(6)
    }
}

#Preview {
    MenuBarView()
        .environmentObject(AppState())
        .frame(width: 280)
}

