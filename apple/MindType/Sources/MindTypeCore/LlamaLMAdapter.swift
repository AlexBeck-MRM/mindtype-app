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
        ]
        
        // Execute llama-cli
        let result = try await runProcess(executable: cli, arguments: args)
        
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
        // Run process on background thread to avoid blocking
        let exec = executable
        let args = arguments
        
        return try await Task.detached {
            try Self.runProcessSync(executable: exec, arguments: args)
        }.value
    }
    
    private static func runProcessSync(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        
        let pipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errorPipe
        
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
    
    /// Default model filename (Qwen 0.5B is ~470MB quantized)
    public static let defaultModelName = "qwen2.5-0.5b-instruct-q4_k_m.gguf"
    
    /// Model size in bytes (approximate)
    public static let defaultModelSize: Int64 = 470_000_000
    
    /// Find model in common locations
    public static func findModel(named filename: String = defaultModelName) -> String? {
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
    
    /// Get the recommended model download URL
    public static var downloadURL: URL {
        URL(string: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf")!
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
