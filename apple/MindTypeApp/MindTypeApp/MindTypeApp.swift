/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   m a c O S   A P P  ░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Menu bar app with testing ground for typing corrections.  ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ macOS menu bar app for MindType v1.0
  • WHY  ▸ Apple-native typing intelligence
  • HOW  ▸ SwiftUI + native pipeline (no Rust/WASM)
*/

import SwiftUI

@main
struct MindTypeApp: App {
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // Menu bar presence
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Text("⠶")
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .accessibilityLabel("MindType")
        }
        .menuBarExtraStyle(.window)
        
        // Testing Ground window
        Window("MindType Testing Ground", id: "testing-ground") {
            TestingGroundView()
                .environmentObject(appState)
        }
        .defaultSize(width: 800, height: 600)
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

