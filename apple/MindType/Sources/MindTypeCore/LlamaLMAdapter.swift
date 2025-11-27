/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  L L A M A   L M   A D A P T E R  ░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   On-device LLM inference using llama.cpp CLI with Metal.   ║
  ║   Implements LMAdapter protocol for the correction pipeline. ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ LM inference adapter using llama.cpp CLI
  • WHY  ▸ Fast, private, on-device text correction
  • HOW  ▸ GGUF model + llama-cli process execution
  
  Note: This uses the llama-cli binary. For production, consider
  integrating llama.cpp as a C library directly.
*/

import Foundation

// MARK: - Llama LM Adapter

/// LM adapter using llama.cpp CLI for on-device inference
/// Requires: `brew install llama.cpp` or manual build
public actor LlamaLMAdapter: LMAdapter {
    
    // MARK: - Properties
    
    private var modelPath: String?
    private var llamaCliPath: String?
    private var _status: LMStatus = .uninitialized
    private var _isReady: Bool = false
    private var config: LMConfiguration?
    
    // MARK: - LMAdapter Protocol
    
    public var isReady: Bool { _isReady }
    public var status: LMStatus { _status }
    
    public init() {}
    
    /// Initialize with a GGUF model file
    public func initialize(config: LMConfiguration) async throws {
        guard let path = config.modelPath else {
            _status = .error("No model path specified")
            throw MindTypeError.modelNotLoaded
        }
        
        _status = .loading
        self.config = config
        
        // Verify model file exists
        guard FileManager.default.fileExists(atPath: path) else {
            _status = .error("Model file not found")
            throw MindTypeError.modelLoadFailed("File not found: \(path)")
        }
        
        // Find llama-cli binary
        llamaCliPath = findLlamaCli()
        guard llamaCliPath != nil else {
            _status = .error("llama-cli not found")
            throw MindTypeError.modelLoadFailed("""
                llama-cli not found. Install with:
                  brew install llama.cpp
                Or build from source:
                  git clone https://github.com/ggerganov/llama.cpp && cd llama.cpp && make
                """)
        }
        
        modelPath = path
        _status = .ready
        _isReady = true
        
        print("✓ LlamaLMAdapter: Ready")
        print("  Model: \(path)")
        print("  CLI: \(llamaCliPath!)")
    }
    
    /// Generation timeout in seconds
    private let generationTimeout: TimeInterval = 30.0
    
    /// Generate text completion using llama-cli
    public func generate(prompt: String, maxTokens: Int) async throws -> String {
        guard _isReady, let model = modelPath, let cli = llamaCliPath else {
            throw MindTypeError.modelNotLoaded
        }
        
        let temp = config?.temperature ?? 0.1
        
        // Build command arguments
        let args = [
            "-m", model,
            "-p", prompt,
            "-n", String(maxTokens),
            "--temp", String(temp),
            "--top-p", "0.9",
            "--top-k", "40",
            "-ngl", "99",           // Use all GPU layers
            "--no-display-prompt",  // Don't echo the prompt
            "-e",                   // Process escape sequences
            "--no-conversation",    // Disable conversation mode (prevents stdin blocking)
        ]
        
        // Execute llama-cli with timeout
        let result = try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.runProcess(executable: cli, arguments: args)
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(self.generationTimeout * 1_000_000_000))
                throw MindTypeError.generationFailed("Generation timed out after \(Int(self.generationTimeout))s")
            }
            
            // Return first completed, cancel remaining
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
        
        // Clean up output (remove any trailing special tokens)
        var output = result.trimmingCharacters(in: .whitespacesAndNewlines)
        if let endRange = output.range(of: "<|im_end|>") {
            output = String(output[..<endRange.lowerBound])
        }
        
        return output
    }
    
    // MARK: - Private Helpers
    
    private func findLlamaCli() -> String? {
        let searchPaths = [
            "/opt/homebrew/bin/llama-cli",
            "/usr/local/bin/llama-cli",
            "/usr/bin/llama-cli",
            NSHomeDirectory() + "/llama.cpp/llama-cli",
            FileManager.default.currentDirectoryPath + "/llama-cli",
        ]
        
        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        // Try using `which`
        if let whichResult = try? Self.runProcessSync(executable: "/usr/bin/which", arguments: ["llama-cli"]),
           !whichResult.isEmpty {
            let path = whichResult.trimmingCharacters(in: .whitespacesAndNewlines)
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    private func runProcess(executable: String, arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        // Provide empty stdin to prevent waiting for input
        process.standardInput = FileHandle.nullDevice
        
        try process.run()
        
        // Wait for process with cancellation support
        while process.isRunning {
            try Task.checkCancellation()
            try await Task.sleep(nanoseconds: 50_000_000) // Check every 50ms
        }
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MindTypeError.generationFailed("Process exited with \(process.terminationStatus): \(errorOutput)")
        }
        
        return output
    }
    
    private static func runProcessSync(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        process.standardInput = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let errorOutput = String(data: errorData, encoding: .utf8) ?? "Unknown error"
            throw MindTypeError.generationFailed("Process exited with \(process.terminationStatus): \(errorOutput)")
        }
        
        return output
    }
}

// MARK: - Model Discovery

/// Utilities for finding and managing GGUF models
public enum ModelDiscovery {
    
    /// Supported models in order of preference (best first)
    public static let supportedModels = [
        "mindtype-finetuned-q4_k_m.gguf",   // Fine-tuned for MindType (best)
        "mindtype-finetuned.gguf",           // Fine-tuned alternate name
        "qwen2.5-3b-instruct-q4_k_m.gguf",   // Best base quality
        "qwen2.5-1.5b-instruct-q4_k_m.gguf", // Good balance
        "qwen2.5-0.5b-instruct-q4_k_m.gguf", // Fastest, lowest quality
    ]
    
    /// Default model filename (fallback to smallest)
    public static let defaultModelName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    
    /// Model size in bytes (approximate)
    public static let defaultModelSize: Int64 = 470_000_000
    
    /// Find the best available model
    public static func findModel(named filename: String? = nil) -> String? {
        // If specific filename requested, search for it
        if let specific = filename {
            return findModelFile(named: specific)
        }
        
        // Otherwise, find the best available model (prefer larger/better)
        for modelName in supportedModels {
            if let path = findModelFile(named: modelName) {
                return path
            }
        }
        
        return nil
    }
    
    private static func findModelFile(named filename: String) -> String? {
        let searchPaths: [String] = [
            // App bundle
            Bundle.main.bundlePath + "/Models/\(filename)",
            Bundle.main.resourcePath.map { $0 + "/\(filename)" } ?? "",
            
            // Project structure (development)
            FileManager.default.currentDirectoryPath + "/Models/\(filename)",
            FileManager.default.currentDirectoryPath + "/../Models/\(filename)",
            FileManager.default.currentDirectoryPath + "/../../apple/Models/\(filename)",
            
            // User home
            NSHomeDirectory() + "/.mindtype/models/\(filename)",
        ].filter { !$0.isEmpty }
        
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        return nil
    }
    
    /// Get the recommended model download URL (3B for quality)
    public static var downloadURL: URL {
        URL(string: "https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf")!
    }
    
    /// Get the target download path (creates directory if needed)
    public static var downloadPath: String {
        let modelsDir = NSHomeDirectory() + "/.mindtype/models"
        try? FileManager.default.createDirectory(atPath: modelsDir, withIntermediateDirectories: true)
        return modelsDir + "/\(defaultModelName)"
    }
    
    /// Check if the default model is available
    public static var isModelAvailable: Bool {
        findModel() != nil
    }
    
    /// Check if llama-cli is available
    public static var isLlamaCliAvailable: Bool {
        let paths = [
            "/opt/homebrew/bin/llama-cli",
            "/usr/local/bin/llama-cli",
        ]
        return paths.contains { FileManager.default.isExecutableFile(atPath: $0) }
    }
}
