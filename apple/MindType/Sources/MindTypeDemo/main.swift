/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   D E M O  ░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Command-line demo of the correction pipeline.             ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import Foundation
import MindTypeCore

@main
struct MindTypeDemo {
    static func main() async {
        print("""
        ╔══════════════════════════════════════════════════════════════╗
        ║           M I N D ⠶ T Y P E   D E M O   v 1 . 0              ║
        ╚══════════════════════════════════════════════════════════════╝
        
        Testing the three-stage correction pipeline:
        • Noise  → Fix typos
        • Context → Improve grammar  
        • Tone   → Adjust style
        
        """)
        
        // Try to use real LLM if model available, otherwise fall back to mock
        let adapter: any LMAdapter
        let usingRealLM: Bool
        
        if let modelPath = ModelDiscovery.findModel() {
            print("🧠 Found model: \(modelPath)")
            let llamaAdapter = LlamaLMAdapter()
            do {
                try await llamaAdapter.initialize(config: .gguf(modelPath))
                adapter = llamaAdapter
                usingRealLM = true
                print("✅ Llama adapter initialized (Metal-accelerated)")
            } catch {
                print("⚠️  Failed to load model: \(error.localizedDescription)")
                print("   Falling back to mock adapter...")
                adapter = MockLMAdapter()
                usingRealLM = false
                try? await (adapter as! MockLMAdapter).initialize(config: .default)
            }
        } else {
            print("ℹ️  No GGUF model found. Using mock adapter.")
            print("   To use real LLM, download model to: ~/.mindtype/models/")
            print("   curl -L -o ~/.mindtype/models/\(ModelDiscovery.defaultModelName) \\")
            print("     \(ModelDiscovery.downloadURL)")
            print("")
            let mockAdapter = MockLMAdapter()
            try? await mockAdapter.initialize(config: .default)
            adapter = mockAdapter
            usingRealLM = false
        }
        
        print("")
        print("─────────────────────────────────────────────────────────────────")
        print("  Mode: \(usingRealLM ? "🚀 Real LLM (Qwen 0.5B)" : "🎭 Mock (pattern matching)")")
        print("─────────────────────────────────────────────────────────────────")
        
        let pipeline = CorrectionPipeline(lmAdapter: adapter)
        
        // Test cases
        let testCases: [(text: String, description: String)] = [
            ("I was writting a letter to my freind becuase I beleive its neccessary.", "Multiple typos"),
            ("Teh quick brown fox jumps over teh lazy dog.", "Common transpositions"),
            ("This is definately wierd but I cant help it.", "Mixed typos"),
            ("I recieved teh message tommorow.", "Various corrections"),
        ]
        
        print("─────────────────────────────────────────────────────────────────")
        
        for (index, testCase) in testCases.enumerated() {
            print("\n📝 Test \(index + 1): \(testCase.description)")
            print("   Input:  \"\(testCase.text)\"")
            
            do {
                let result = try await pipeline.runCorrectionWave(
                    text: testCase.text,
                    caret: testCase.text.count
                )
                
                if result.diffs.isEmpty {
                    print("   Output: (no changes)")
                } else {
                    // Apply corrections safely using applyDiffs
                    if let applied = applyDiffs(
                        text: testCase.text,
                        diffs: result.diffs,
                        caret: testCase.text.count
                    ) {
                        print("   Output: \"\(applied.text)\"")
                    } else {
                        print("   Output: (diffs failed to apply)")
                    }
                    print("   ⏱️  Latency: \(String(format: "%.1f", result.durationMs)) ms")
                    print("   📊 Corrections: \(result.diffs.count)")
                    for diff in result.diffs {
                        print("      • [\(diff.stage.displayName)] [\(diff.start):\(diff.end)] → \"\(diff.text)\"")
                    }
                }
            } catch {
                print("   ❌ Error: \(error)")
            }
        }
        
        print("\n─────────────────────────────────────────────────────────────────")
        print("\n✅ Demo complete!")
        
        if usingRealLM {
            print("""
            
            🎉 Running with real on-device LLM!
            
            The Qwen 0.5B model is providing intelligent corrections via Metal.
            Next steps:
            • Integrate with macOS Accessibility APIs for system-wide corrections
            • Use the MindTypeUI components for visual feedback
            • Fine-tune temperature/prompts for your use case
            
            """)
        } else {
            print("""
            
            The mock adapter demonstrates the pipeline architecture.
            To enable real LLM inference:
            
            1. Download the model (~394MB):
               curl -L -o ~/.mindtype/models/\(ModelDiscovery.defaultModelName) \\
                 '\(ModelDiscovery.downloadURL)'
            
            2. Re-run the demo:
               swift run MindTypeDemo
            
            """)
        }
    }
}

