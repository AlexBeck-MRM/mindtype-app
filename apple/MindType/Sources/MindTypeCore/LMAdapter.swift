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
/// Optimized for small LLMs (0.5B-3B parameters) with concise, direct instructions
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
        
        // Build minimal, focused prompts for small LLMs
        let (system, user) = buildStagePrompt(
            stage: stage, 
            snippet: snippet, 
            context: contextBefore,
            toneTarget: toneTarget
        )
        
        return formatChatPrompt(system: system, user: user)
    }
    
    // MARK: - Private
    
    private static func buildStagePrompt(
        stage: CorrectionStage,
        snippet: String,
        context: String?,
        toneTarget: ToneTarget?
    ) -> (system: String, user: String) {
        switch stage {
        case .noise:
            // Noise stage: INTERPRET INTENT from rapid/garbled typing
            // Uses phonetic similarity, keyboard adjacency, and context
            let system = """
            You decode garbled speed-typing into clear English. 
            Consider: phonetic similarity (sounds like), keyboard adjacency (nearby keys), common patterns.
            Return ONLY the corrected text, nothing else.
            """
            
            // Few-shot examples with increasingly complex errors
            let user = """
            teh quick brwon fox<|im_end|>
            <|im_start|>assistant
            the quick brown fox<|im_end|>
            <|im_start|>user
            definately wierd becuase<|im_end|>
            <|im_start|>assistant
            definitely weird because<|im_end|>
            <|im_start|>user
            Im not shure if thsi wokrs<|im_end|>
            <|im_start|>assistant
            I'm not sure if this works<|im_end|>
            <|im_start|>user
            ikidna cool but scaratg<|im_end|>
            <|im_start|>assistant
            kinda cool but scary<|im_end|>
            <|im_start|>user
            technmolgoty is amzaing<|im_end|>
            <|im_start|>assistant
            technology is amazing<|im_end|>
            <|im_start|>user
            \(escape(snippet))
            """
            
            return (system, user)
            
        case .context:
            // Context stage: coherence and grammar while preserving voice
            let system = "Improve grammar and clarity while preserving the author's voice. Return ONLY the improved text."
            
            let user = """
            me and him went store<|im_end|>
            <|im_start|>assistant
            He and I went to the store<|im_end|>
            <|im_start|>user
            the data shows that results is good<|im_end|>
            <|im_start|>assistant
            The data shows that results are good<|im_end|>
            <|im_start|>user
            \(escape(snippet))
            """
            
            return (system, user)
            
        case .tone:
            // Tone stage: adjust formality with examples
            let target = toneTarget ?? .none
            
            if target == .casual {
                let system = "Make this text more casual and friendly. Return ONLY the rewritten text."
                let user = """
                I would like to inform you that the meeting has been rescheduled.<|im_end|>
                <|im_start|>assistant
                Hey, just letting you know the meeting got moved!<|im_end|>
                <|im_start|>user
                \(escape(snippet))
                """
                return (system, user)
            } else if target == .professional {
                let system = "Make this text more professional and formal. Return ONLY the rewritten text."
                let user = """
                Hey can u check this out when u get a chance?<|im_end|>
                <|im_start|>assistant
                Could you please review this at your earliest convenience?<|im_end|>
                <|im_start|>user
                \(escape(snippet))
                """
                return (system, user)
            } else {
                // No tone change - just return original
                let system = "Return the text exactly as given."
                let user = escape(snippet)
                return (system, user)
            }
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
/// Supports both plain text responses and JSON format
public struct ResponseParser {
    
    /// Extract the replacement text from an LM response
    public static func extractReplacement(from response: String) -> String? {
        var cleaned = response.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove common LLM stop tokens/markers
        let stopMarkers = ["[end of text]", "<|im_end|>", "<|endoftext|>", "</s>", "[END]"]
        for marker in stopMarkers {
            if let range = cleaned.range(of: marker, options: .caseInsensitive) {
                cleaned = String(cleaned[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        
        // Try to extract from JSON format first (backwards compatibility)
        if let json = extractFromJSON(cleaned) {
            return json
        }
        
        // Otherwise, return the cleaned plain text
        guard !cleaned.isEmpty else { return nil }
        return cleaned
    }
    
    private static func extractFromJSON(_ text: String) -> String? {
        // Try to find JSON object with "replacement" key
        let patterns = [
            #"\{[^}]*"replacement"\s*:\s*"([^"\\]*(\\.[^"\\]*)*)""#,
            #"\"replacement\"\s*:\s*\"([^\"\\]*(\\.[^\"\\]*)*)\""#
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: text, options: [], range: NSRange(text.startIndex..., in: text)),
               let range = Range(match.range(at: 1), in: text) {
                let extracted = String(text[range])
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

/// Mock LM adapter that provides deterministic intent interpretation for testing
/// This is NOT autocorrect - it interprets abbreviated/shorthand/garbled input
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
        
        // Extract the text from the prompt (support both <input> and <text> tags)
        let tagPatterns = [
            #"(?<=<input>).*(?=</input>)"#,
            #"(?<=<text>).*(?=</text>)"#
        ]
        
        for pattern in tagPatterns {
            if let range = prompt.range(of: pattern, options: .regularExpression) {
                let inputText = String(prompt[range])
                let corrected = applyMockCorrections(to: inputText)
                // Escape quotes in output for valid JSON
                let escaped = corrected.replacingOccurrences(of: "\"", with: "\\\"")
                return "{\"replacement\":\"\(escaped)\"}"
            }
        }
        
        return "{\"replacement\":\"\"}"
    }
    
    private func applyMockCorrections(to text: String) -> String {
        var result = text
        
        // Intent interpretation mappings from Seven Scenarios
        // This expands abbreviations, decodes shorthand, and fixes garbled speed-typing
        let interpretations: [String: String] = [
            // === Scenario 1: Maya (Academic) - Scientific terminology ===
            "resarch": "research", "analsis": "analysis", "hypotheis": "hypothesis",
            "experiement": "experiment", "laborotory": "laboratory",
            "enviromental": "environmental", "sustainabile": "sustainable",
            
            // === Scenario 2: Carlos (Multilingual) - Business terms ===
            "finacial": "financial", "analisys": "analysis", "managment": "management",
            "developement": "development", "straegy": "strategy", "busines": "business",
            
            // === Scenario 6: Marcus (Speed) - Legal shorthand (VELOCITY MODE) ===
            "defdnt": "defendant", "clamd": "claimed", "contrct": "contract",
            "invld": "invalid", "evdnce": "evidence", "testmny": "testimony",
            "innocnce": "innocence", "crt": "court", "jdge": "judge",
            "plntff": "plaintiff", "vrdict": "verdict", "sttmnt": "statement",
            
            // === Scenario 7: Priya (Data) - Tech/Finance shorthand ===
            "rvn": "revenue", "grwth": "growth", "stk": "stock", "stks": "stocks",
            "invstmt": "investment", "invstmnt": "investment", "rtrns": "returns",
            "algrthm": "algorithm", "tch": "tech", "hgh": "high", "stng": "strong",
            
            // === Velocity mode: abbreviated words ===
            "th": "the", "qck": "quick", "brwn": "brown", "jmps": "jumps",
            "ovr": "over", "dg": "dog", "wth": "with", "frm": "from",
            
            // === Common transpositions ===
            "teh": "the", "hte": "the", "adn": "and", "taht": "that",
            "wiht": "with", "waht": "what", "becuase": "because",
            "freind": "friend", "beleive": "believe", "wierd": "weird",
            "recieve": "receive", "recieved": "received", "lettr": "letter",
            
            // === Missing apostrophes ===
            "dont": "don't", "cant": "can't", "wont": "won't",
            "isnt": "isn't", "wasnt": "wasn't", "didnt": "didn't",
            "its": "it's",  // contextual, but common in corrections
            
            // === Common misspellings ===
            "thier": "their", "occured": "occurred", "occurence": "occurrence",
            "seperate": "separate", "definately": "definitely",
            "accomodate": "accommodate", "enviroment": "environment",
            "goverment": "government", "independant": "independent",
            "neccessary": "necessary", "concious": "conscious",
            "noticable": "noticeable", "priviledge": "privilege",
            "succesful": "successful", "tommorow": "tomorrow",
            "untill": "until", "wich": "which", "writting": "writing",
            "campain": "campaign", "adress": "address", "begining": "beginning",
            
            // === Test/demo words ===
            "helo": "hello", "wrld": "world", "tpying": "typing",
            "corection": "correction", "inteligence": "intelligence",
        ]
        
        for (input, interpreted) in interpretations {
            // Case-insensitive replacement preserving case
            let pattern = "\\b\(NSRegularExpression.escapedPattern(for: input))\\b"
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(result.startIndex..., in: result)
                result = regex.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: interpreted)
            }
        }
        
        return result
    }
}

