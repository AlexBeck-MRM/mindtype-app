/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  L M   A D A P T E R  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Protocol and implementations for language model inference ║
  ║   on Apple Silicon using Metal acceleration.                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ LM abstraction for on-device inference
  • WHY  ▸ Decouple pipeline from specific LM implementation
  • HOW  ▸ Protocol with llama.cpp and mock implementations
*/

import Foundation

// MARK: - LM Adapter Protocol

/// Protocol for language model adapters
public protocol LMAdapter: Actor {
    /// Initialize the model
    func initialize(config: LMConfiguration) async throws
    
    /// Generate text completion
    func generate(prompt: String, maxTokens: Int) async throws -> String
    
    /// Check if model is loaded
    var isReady: Bool { get }
    
    /// Get model status
    var status: LMStatus { get }
}

/// Status of the language model
public enum LMStatus: Sendable, Equatable {
    case uninitialized
    case loading
    case ready
    case error(String)
}

// MARK: - Prompt Builder

/// Builds prompts for the three-stage pipeline
public struct PromptBuilder: Sendable {
    
    /// Build a correction prompt for the given stage
    public static func build(
        stage: CorrectionStage,
        text: String,
        region: TextRegion,
        contextBefore: String? = nil,
        contextAfter: String? = nil,
        toneTarget: ToneTarget? = nil
    ) -> String {
        let snippet = extractSnippet(from: text, region: region)
        let config = stageConfig(for: stage)
        
        var systemParts: [String] = [
            "You are a \(config.title).",
            config.scope
        ]
        
        if let tone = toneTarget, tone != .none, stage == .tone {
            systemParts.append("Target tone: \(tone.rawValue)")
        }
        
        systemParts.append("")
        systemParts.append("Rules:")
        systemParts.append(contentsOf: config.rules.map { "- \($0)" })
        systemParts.append("- Never change meaning or introduce new information.")
        systemParts.append("- Output ONLY a JSON object with the corrected text.")
        
        let userParts: [String] = [
            "Correct the text inside <input> tags. Return the full corrected text in JSON format.",
            "If no corrections needed, return the original text unchanged.",
            "",
            "<input>\(escape(snippet))</input>",
            "",
            "Respond with ONLY: {\"replacement\":\"YOUR CORRECTED TEXT HERE\"}"
        ]
        
        return formatChatPrompt(
            system: systemParts.joined(separator: "\n"),
            user: userParts.joined(separator: "\n")
        )
    }
    
    // MARK: - Private
    
    private struct StageConfig {
        let title: String
        let scope: String
        let rules: [String]
    }
    
    private static func stageConfig(for stage: CorrectionStage) -> StageConfig {
        switch stage {
        case .noise:
            return StageConfig(
                title: "typo correction assistant",
                scope: "Fix obvious typos, transpositions, and keyboard slip errors.",
                rules: [
                    "Fix single-character typos (missing, extra, swapped letters)",
                    "Correct common keyboard adjacency errors",
                    "Fix repeated characters",
                    "Preserve original capitalization pattern",
                    "Do not change word choice or phrasing"
                ]
            )
        case .context:
            return StageConfig(
                title: "grammar and coherence assistant",
                scope: "Improve grammar, punctuation, and sentence flow.",
                rules: [
                    "Fix subject-verb agreement",
                    "Correct punctuation errors",
                    "Fix article usage (a/an/the)",
                    "Improve sentence structure if clearly broken",
                    "Preserve the author's voice and style"
                ]
            )
        case .tone:
            return StageConfig(
                title: "tone adjustment assistant",
                scope: "Adjust writing tone while preserving meaning.",
                rules: [
                    "Adjust formality level as specified",
                    "Preserve the core message",
                    "Maintain appropriate word choice for the target tone",
                    "Keep similar sentence length"
                ]
            )
        }
    }
    
    private static func extractSnippet(from text: String, region: TextRegion) -> String {
        guard region.start >= 0, region.end <= text.count, region.start < region.end else {
            return ""
        }
        let start = text.index(text.startIndex, offsetBy: region.start)
        let end = text.index(text.startIndex, offsetBy: region.end)
        return String(text[start..<end])
    }
    
    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    private static func formatChatPrompt(system: String, user: String) -> String {
        """
        <|im_start|>system
        \(system.trimmingCharacters(in: .whitespacesAndNewlines))
        <|im_end|>
        <|im_start|>user
        \(user.trimmingCharacters(in: .whitespacesAndNewlines))
        <|im_end|>
        <|im_start|>assistant
        
        """
    }
}

// MARK: - Response Parser

/// Parses LM responses to extract replacement text
public struct ResponseParser {
    
    /// Extract the replacement text from an LM response
    public static func extractReplacement(from response: String) -> String? {
        // Try to find JSON object with "replacement" key
        let patterns = [
            #"\{[^}]*"replacement"\s*:\s*"([^"\\]*(\\.[^"\\]*)*)""#,
            #"\"replacement\"\s*:\s*\"([^\"\\]*(\\.[^\"\\]*)*)\""#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: response, options: [], range: NSRange(response.startIndex..., in: response)),
               let range = Range(match.range(at: 1), in: response) {
                let extracted = String(response[range])
                return unescapeJSON(extracted)
            }
        }
        
        return nil
    }
    
    private static func unescapeJSON(_ text: String) -> String {
        text.replacingOccurrences(of: "\\\"", with: "\"")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\t", with: "\t")
    }
}

// MARK: - Mock LM Adapter (for testing and development)

/// Mock LM adapter that provides deterministic corrections for testing
public actor MockLMAdapter: LMAdapter {
    private var _status: LMStatus = .uninitialized
    private var _isReady: Bool = false
    
    public init() {}
    
    public var isReady: Bool { _isReady }
    public var status: LMStatus { _status }
    
    public func initialize(config: LMConfiguration) async throws {
        _status = .loading
        // Simulate loading delay
        try await Task.sleep(nanoseconds: 500_000_000)
        _status = .ready
        _isReady = true
    }
    
    public func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard _isReady else {
            throw MindTypeError.modelNotLoaded
        }
        
        // Simulate inference delay
        try await Task.sleep(nanoseconds: 100_000_000)
        
        // Extract the text from the prompt and apply simple corrections
        if prompt.range(of: #"<text>(.*?)</text>"#, options: .regularExpression) != nil,
           let innerRange = prompt.range(of: #"(?<=<text>).*(?=</text>)"#, options: .regularExpression) {
            let inputText = String(prompt[innerRange])
            let corrected = applyMockCorrections(to: inputText)
            return "{\"replacement\":\"\(corrected)\"}"
        }
        
        return "{\"replacement\":\"\"}"
    }
    
    private func applyMockCorrections(to text: String) -> String {
        var result = text
        
        // Common typo corrections (expanded list)
        let corrections: [String: String] = [
            // Common transpositions
            "teh": "the", "hte": "the", "adn": "and", "taht": "that",
            "wiht": "with", "waht": "what", "becuase": "because",
            "freind": "friend", "beleive": "believe", "wierd": "weird",
            "recieve": "receive", "recieved": "received",
            // Missing apostrophes
            "dont": "don't", "cant": "can't", "wont": "won't",
            "isnt": "isn't", "wasnt": "wasn't", "didnt": "didn't",
            // Common misspellings
            "thier": "their", "occured": "occurred", "occurence": "occurrence",
            "seperate": "separate", "definately": "definitely",
            "accomodate": "accommodate", "enviroment": "environment",
            "goverment": "government", "independant": "independent",
            "neccessary": "necessary", "concious": "conscious",
            "noticable": "noticeable", "priviledge": "privilege",
            "succesful": "successful", "tommorow": "tomorrow",
            "untill": "until", "wich": "which", "writting": "writing",
            // Test words
            "helo": "hello", "wrld": "world", "tpying": "typing",
            "corection": "correction", "inteligence": "intelligence",
        ]
        
        for (typo, correction) in corrections {
            // Case-insensitive replacement preserving case
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: typo))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: correction)
            }
        }
        
        return result
    }
}

