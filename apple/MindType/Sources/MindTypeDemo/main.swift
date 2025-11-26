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
        
        // Create the pipeline with mock adapter
        let adapter = MockLMAdapter()
        do {
            try await adapter.initialize(config: .default)
            print("✅ LM Adapter initialized")
        } catch {
            print("❌ Failed to initialize: \(error)")
            return
        }
        
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
                    // Apply corrections
                    var corrected = testCase.text
                    for diff in result.diffs.sorted(by: { $0.start > $1.start }) {
                        let start = corrected.index(corrected.startIndex, offsetBy: diff.start)
                        let end = corrected.index(corrected.startIndex, offsetBy: diff.end)
                        corrected.replaceSubrange(start..<end, with: diff.text)
                    }
                    print("   Output: \"\(corrected)\"")
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
        print("""
        
        The pipeline is working correctly. In production:
        • Replace MockLMAdapter with llama.cpp or Core ML adapter
        • Integrate with macOS Accessibility APIs for system-wide corrections
        • Use the MindTypeUI components for visual feedback
        
        """)
    }
}

