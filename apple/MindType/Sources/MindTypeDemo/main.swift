/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   D E M O  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Type at the speed of thought. MindType interprets your    ║
  ║   intent from rapid, abbreviated, or garbled input.         ║
  ║   This is NOT autocorrect.                                  ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import Foundation
import MindTypeCore

@main
struct MindTypeDemo {
    
    // MARK: - Seven Scenarios Test Cases
    
    static let scenarioTests: [(scenario: String, text: String, description: String)] = [
        // Scenario 1: Maya (Academic - Dyslexia)
        ("Maya 📚", 
         "The resarch shows that enviromental sustainabile practices are neccessary for the experiemental hypotheis.",
         "Academic writing with scientific terminology"),
        
        // Scenario 2: Carlos (Multilingual Business)
        ("Carlos 🌍", 
         "The finacial analisys shows strong managment and developement straegy for our busines.",
         "Business terminology corrections"),
        
        // Scenario 4: James (Creative Writer)
        ("James ✍️", 
         "I was writting a letter to my freind becuase I beleive its neccessary to express my feelings.",
         "Creative writing flow preservation"),
        
        // Scenario 5: Emma (Working Parent)
        ("Emma 💼", 
         "The campain results are definately wierd but I cant help noticing the adress is wrong.",
         "Quick professional email fixes"),
        
        // Scenario 6: Marcus (Speed Demon - Legal)
        ("Marcus ⚡", 
         "The defdnt clamd the contrct was invld and the evdnce supports this.",
         "Legal shorthand expansion"),
        
        // Scenario 7: Priya (Data Analyst)
        ("Priya 📊", 
         "High rvn grwth in teh tech stk sector with strong invstmt returns.",
         "Data/finance abbreviation expansion"),
    ]
    
    // Quick tests demonstrating INTENT interpretation (not just autocorrect)
    static let quickTests: [(text: String, description: String)] = [
        ("Th qck brwn fox jmps ovr th lazy dg.", "Velocity mode: abbreviated typing"),
        ("defdnt clmd innocnce in crt tday", "Legal shorthand expansion"),
        ("hgh rvn grwth stng invstmnt rtrns", "Finance abbreviation expansion"),
        ("definately wierd but I cant help it", "Common misspellings (simple case)"),
    ]
    
    // MARK: - Main Entry Point
    
    static func main() async {
        let args = CommandLine.arguments
        
        // Parse command line arguments
        if args.contains("--help") || args.contains("-h") {
            printHelp()
            return
        }
        
        let interactiveMode = args.contains("--interactive") || args.contains("-i")
        let scenariosMode = args.contains("--scenarios") || args.contains("-s")
        let quickMode = args.contains("--quick") || args.contains("-q")
        
        // Print header
        printHeader()
        
        // Initialize adapter
        let (adapter, usingRealLM, modelPath) = await initializeAdapter()
        let pipeline = CorrectionPipeline(lmAdapter: adapter)
        
        printModeInfo(usingRealLM: usingRealLM, modelPath: modelPath)
        
        // Run the appropriate mode
        if interactiveMode {
            await runInteractiveMode(pipeline: pipeline)
        } else if scenariosMode {
            await runScenarioTests(pipeline: pipeline)
        } else if quickMode {
            await runQuickTests(pipeline: pipeline)
        } else {
            // Default: run scenarios then offer interactive
            await runScenarioTests(pipeline: pipeline)
            print("\n💡 Tip: Run with --interactive (-i) for live typing mode")
            print("        Run with --help for all options\n")
        }
    }
    
    // MARK: - Interactive Mode
    
    static func runInteractiveMode(pipeline: CorrectionPipeline) async {
        print("""
        
        ┌─────────────────────────────────────────────────────────────────┐
        │  I N T E R A C T I V E   M O D E                                │
        │                                                                 │
        │  Type at thought-speed → MindType interprets your intent       │
        │  Try: abbreviations, shorthand, garbled speed-typing           │
        │  Commands: :quit, :help, :tone casual, :tone professional      │
        └─────────────────────────────────────────────────────────────────┘
        
        """)
        
        var toneTarget: ToneTarget = .none
        
        while true {
            print("⠶ ", terminator: "")
            fflush(stdout)
            
            guard let input = readLine(), !input.isEmpty else {
                continue
            }
            
            // Handle commands
            if input.hasPrefix(":") {
                let command = input.lowercased()
                
                if command == ":quit" || command == ":q" {
                    print("\n👋 Goodbye!\n")
                    break
                } else if command == ":help" || command == ":h" {
                    printInteractiveHelp()
                    continue
                } else if command == ":tone casual" {
                    toneTarget = .casual
                    print("   → Tone set to: Casual\n")
                    continue
                } else if command == ":tone professional" || command == ":tone pro" {
                    toneTarget = .professional
                    print("   → Tone set to: Professional\n")
                    continue
                } else if command == ":tone none" || command == ":tone off" {
                    toneTarget = .none
                    print("   → Tone adjustment: Off\n")
                    continue
                } else {
                    print("   ⚠️  Unknown command. Type :help for options.\n")
                    continue
                }
            }
            
            // Process text - show user we're working
            print("   ⏳ Interpreting...")
            await processText(input, pipeline: pipeline, toneTarget: toneTarget, showDetails: true)
            print("")
        }
    }
    
    // MARK: - Scenario Tests
    
    static func runScenarioTests(pipeline: CorrectionPipeline) async {
        print("""
        
        ┌─────────────────────────────────────────────────────────────────┐
        │  S E V E N   S C E N A R I O S   T E S T                        │
        │                                                                 │
        │  Testing corrections for each user persona from the PRD        │
        └─────────────────────────────────────────────────────────────────┘
        
        """)
        
        for (index, test) in scenarioTests.enumerated() {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(" \(test.scenario)  \(test.description)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("")
            
            await processText(test.text, pipeline: pipeline, toneTarget: .none, showDetails: true)
            
            if index < scenarioTests.count - 1 {
                print("\n")
            }
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(" ✅ All scenario tests complete!")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
    }
    
    // MARK: - Quick Tests
    
    static func runQuickTests(pipeline: CorrectionPipeline) async {
        print("""
        
        ┌─────────────────────────────────────────────────────────────────┐
        │  Q U I C K   T E S T                                            │
        └─────────────────────────────────────────────────────────────────┘
        
        """)
        
        for (index, test) in quickTests.enumerated() {
            print("📝 Test \(index + 1): \(test.description)")
            await processText(test.text, pipeline: pipeline, toneTarget: .none, showDetails: false)
            print("")
        }
        
        print("✅ Quick tests complete!\n")
    }
    
    // MARK: - Text Processing
    
    static func processText(
        _ text: String,
        pipeline: CorrectionPipeline,
        toneTarget: ToneTarget,
        showDetails: Bool
    ) async {
        print("   Input:  \"\(text)\"")
        
        do {
            let result = try await pipeline.runCorrectionWave(
                text: text,
                caret: text.count,
                toneTarget: toneTarget
            )
            
            // Use the new correctedText property for clean output
            if let corrected = result.correctedText {
                print("   Output: \"\(corrected)\"")
                
                if showDetails {
                    let stages = result.stagesApplied.map(\.displayName).joined(separator: " → ")
                    print("   ⏱️  \(String(format: "%.0f", result.durationMs))ms │ Stages: \(stages)")
                }
            } else {
                print("   Output: \"\(text)\" (no changes)")
            }
        } catch {
            print("   ❌ Error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Initialization
    
    static func initializeAdapter() async -> (any LMAdapter, Bool, String?) {
        if let modelPath = ModelDiscovery.findModel() {
            print("🧠 Found model: \(modelPath.split(separator: "/").last ?? "")")
            let llamaAdapter = LlamaLMAdapter()
            do {
                try await llamaAdapter.initialize(config: .gguf(modelPath))
                print("✅ Llama adapter ready (Metal-accelerated)\n")
                return (llamaAdapter, true, modelPath)
            } catch {
                print("⚠️  Model load failed: \(error.localizedDescription)")
                print("   Falling back to mock adapter...\n")
            }
        } else {
            print("ℹ️  No model found. Using mock adapter.")
            print("   Download: curl -L -o ~/.mindtype/models/\(ModelDiscovery.defaultModelName) \\")
            print("     '\(ModelDiscovery.downloadURL)'\n")
        }
        
        let mockAdapter = MockLMAdapter()
        try? await mockAdapter.initialize(config: .default)
        return (mockAdapter, false, nil)
    }
    
    // MARK: - UI Helpers
    
    static func printHeader() {
        print("""
        
        ╔══════════════════════════════════════════════════════════════╗
        ║           M I N D ⠶ T Y P E   D E M O   v 0 . 9              ║
        ║                                                              ║
        ║   Three-stage on-device typing intelligence                  ║
        ║   Noise → Context → Tone                                     ║
        ╚══════════════════════════════════════════════════════════════╝
        
        """)
    }
    
    static func printModeInfo(usingRealLM: Bool, modelPath: String? = nil) {
        let modelName: String
        if let path = modelPath {
            let filename = path.split(separator: "/").last ?? "unknown"
            if filename.contains("3b") {
                modelName = "Qwen 3B"
            } else if filename.contains("1.5b") {
                modelName = "Qwen 1.5B"
            } else if filename.contains("0.5b") {
                modelName = "Qwen 0.5B"
            } else {
                modelName = String(filename)
            }
        } else {
            modelName = "Unknown"
        }
        
        let mode = usingRealLM ? "🚀 Real LLM (\(modelName), Metal)" : "🎭 Mock (pattern matching)"
        print("─────────────────────────────────────────────────────────────────")
        print("  Mode: \(mode)")
        print("─────────────────────────────────────────────────────────────────")
    }
    
    static func printHelp() {
        print("""
        
        Mind⠶Type Demo - Type at the speed of thought
        
        NOT AUTOCORRECT: MindType interprets your intent from rapid,
        abbreviated, or garbled typing. It expands shorthand and decodes
        what you meant to say.
        
        USAGE:
            swift run MindTypeDemo [OPTIONS]
        
        OPTIONS:
            -i, --interactive    Interactive REPL mode (type your own text)
            -s, --scenarios      Run Seven Scenarios tests
            -q, --quick          Run quick test suite
            -h, --help           Show this help message
        
        EXAMPLES:
            swift run MindTypeDemo              # Run scenarios + tips
            swift run MindTypeDemo -i           # Interactive mode
            swift run MindTypeDemo --scenarios  # Full scenario tests
        
        """)
    }
    
    static func printInteractiveHelp() {
        print("""
        
        Commands:
            :quit, :q              Exit interactive mode
            :help, :h              Show this help
            :tone casual           Enable casual tone adjustment
            :tone professional     Enable professional tone
            :tone off              Disable tone adjustment
        
        Type at the speed of thought. Try:
            • Abbreviations: "hgh rvn grwth" → "high revenue growth"
            • Shorthand: "th defdnt clamd" → "the defendant claimed"
            • Rapid typing: "definately wierd" → "definitely weird"
        
        MindType interprets what you MEANT, not just fixes what you typed.
        
        """)
    }
    
    static func stageEmoji(_ stage: CorrectionStage) -> String {
        switch stage {
        case .noise: return "🔧"
        case .context: return "📖"
        case .tone: return "🎨"
        }
    }
}
