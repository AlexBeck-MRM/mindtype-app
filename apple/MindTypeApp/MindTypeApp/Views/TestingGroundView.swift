/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  T E S T I N G   G R O U N D   V I E W  ░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Interactive demo for testing the correction pipeline.     ║
  ║   Type text with typos to see real-time corrections.        ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import SwiftUI
import MindTypeCore

struct TestingGroundView: View {
    @EnvironmentObject var appState: AppState
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var isProcessing = false
    @State private var appliedDiffs: [AppCorrectionDiff] = []
    @State private var stagesApplied: [AppCorrectionStage] = []
    @State private var lastLatency: Double = 0
    @State private var showDiffDetail = false
    
    private let presets: [(name: String, text: String)] = [
        ("Typos", "I was writting a letter to my freind becuase I beleive its neccessary to stay in touch. Tommorow I will definately send it."),
        ("Grammar", "Me and him went to the store yesterday. There was alot of people their. I seen many things that was interesting."),
        ("Mixed", "Teh quick brown fox jumps over teh lazy dog. Its a wierd sentance but it contains every letter in teh alphabet."),
        ("Professional", "hey can u send me that report asap? its kinda urgent and i need it for the meeting tmrw thx"),
    ]
    
    var body: some View {
        HSplitView {
            // Main content
            VStack(spacing: 0) {
                // Toolbar
                toolbar
                
                Divider()
                
                // Input/Output split
                VSplitView {
                    inputSection
                    outputSection
                }
            }
            .frame(minWidth: 400)
            
            // Side panel
            if showDiffDetail {
                diffDetailPanel
                    .frame(width: 280)
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }
    
    // MARK: - Toolbar
    
    private var toolbar: some View {
        HStack(spacing: 12) {
            // Run button
            Button {
                runCorrection()
            } label: {
                Label("Run Correction", systemImage: "play.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.isEmpty || isProcessing)
            .keyboardShortcut(.return, modifiers: .command)
            
            // Status
            if isProcessing {
                ProgressView()
                    .scaleEffect(0.7)
            } else if lastLatency > 0 {
                Text(String(format: "%.0f ms", lastLatency))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Presets menu
            Menu {
                ForEach(presets, id: \.name) { preset in
                    Button(preset.name) {
                        inputText = preset.text
                        outputText = ""
                        appliedDiffs = []
                        stagesApplied = []
                    }
                }
            } label: {
                Label("Presets", systemImage: "text.badge.plus")
            }
            
            // Toggle diff panel
            Toggle(isOn: $showDiffDetail) {
                Image(systemName: "sidebar.right")
            }
            .toggleStyle(.button)
            .help("Show diff details")
            
            // Clear button
            Button {
                inputText = ""
                outputText = ""
                appliedDiffs = []
                stagesApplied = []
                lastLatency = 0
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .disabled(inputText.isEmpty && outputText.isEmpty)
        }
        .padding()
    }
    
    // MARK: - Input Section
    
    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Input", systemImage: "character.cursor.ibeam")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("\(inputText.count) chars")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            TextEditor(text: $inputText)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color(nsColor: .textBackgroundColor))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .frame(minHeight: 150)
    }
    
    // MARK: - Output Section
    
    private var outputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Output", systemImage: "checkmark.circle")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                if !stagesApplied.isEmpty {
                    Text(stagesApplied.map(\.displayName).joined(separator: " → "))
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)
            
            ScrollView {
                if outputText.isEmpty {
                    Text("Run correction to see output...")
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                } else {
                    highlightedOutputText
                        .padding()
                }
            }
            .background(Color(nsColor: .textBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        .frame(minHeight: 150)
    }
    
    // MARK: - Highlighted Output
    
    private var highlightedOutputText: some View {
        Text(outputText)
            .font(.system(.body, design: .monospaced))
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Diff Detail Panel
    
    private var diffDetailPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Corrections")
                .font(.headline)
                .padding(.horizontal)
                .padding(.top)
            
            if stagesApplied.isEmpty {
                VStack {
                    Image(systemName: "checkmark.circle")
                        .font(.largeTitle)
                        .foregroundStyle(.tertiary)
                    Text("No corrections")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    // Show stages that were applied
                    HStack(spacing: 4) {
                        ForEach(stagesApplied, id: \.self) { stage in
                            Text(stage.displayName)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(stage.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(stage.color.opacity(0.15))
                                .cornerRadius(4)
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                    
                    // Show diffs if available
                    if !appliedDiffs.isEmpty {
                        List(appliedDiffs.indices, id: \.self) { index in
                            let diff = appliedDiffs[index]
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(diff.stage.displayName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(diff.stage.color)
                                    
                                    Spacer()
                                    
                                    Text("[\(diff.start):\(diff.end)]")
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                }
                                
                                Text("→ \"\(diff.text)\"")
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                    .lineLimit(3)
                            }
                            .padding(.vertical, 4)
                        }
                        .listStyle(.plain)
                    } else {
                        Text("Stages applied changes directly")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Actions
    
    private func runCorrection() {
        guard !inputText.isEmpty else { return }
        
        isProcessing = true
        
        Task {
            let result = await appState.runCorrection(
                text: inputText,
                caret: inputText.count
            )
            
            await MainActor.run {
                outputText = result.correctedText
                appliedDiffs = result.diffs
                stagesApplied = result.stagesApplied
                lastLatency = result.latencyMs
                isProcessing = false
                
                if result.hasChanges {
                    showDiffDetail = true
                }
            }
        }
    }
}

#Preview {
    TestingGroundView()
        .environmentObject(AppState())
        .frame(width: 800, height: 600)
}

