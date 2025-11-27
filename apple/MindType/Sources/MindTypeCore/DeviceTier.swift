/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  D E V I C E   T I E R   D E T E C T I O N  ░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Detects hardware capabilities and adapts processing.      ║
  ║   Per Mind⠶Flow guide: WebGPU/WASM/CPU tier adaptation.     ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Hardware capability detection for adaptive processing
  • WHY  ▸ Optimal performance across device spectrum
  • HOW  ▸ Metal/GPU detection with fallback tiers
*/

import Foundation

#if os(macOS) || os(iOS)
import Metal
#endif

// MARK: - Device Tier Detection

/// Detect the current device's capability tier
public func detectDeviceTier() -> DeviceTier {
    #if os(macOS) || os(iOS)
    guard let device = MTLCreateSystemDefaultDevice() else {
        return .graceful
    }
    
    // Check GPU family and memory
    let hasUnifiedMemory = device.hasUnifiedMemory
    let recommendedMemory = device.recommendedMaxWorkingSetSize
    let memoryGB = Double(recommendedMemory) / (1024 * 1024 * 1024)
    
    // Apple Silicon detection
    #if os(macOS)
    let isAppleSilicon = device.supportsFamily(.apple7) || device.supportsFamily(.apple8)
    #else
    let isAppleSilicon = true // iOS is always Apple Silicon
    #endif
    
    // High tier: Apple Silicon with ≥8GB unified memory
    if isAppleSilicon && hasUnifiedMemory && memoryGB >= 8 {
        return .high
    }
    
    // Balanced tier: Apple Silicon with ≥4GB or any Metal GPU with good memory
    if (isAppleSilicon && memoryGB >= 4) || memoryGB >= 6 {
        return .balanced
    }
    
    // Graceful tier: everything else
    return .graceful
    #else
    return .graceful
    #endif
}

// MARK: - Adaptive Configuration

/// Generates pipeline configuration adapted to device capabilities
public struct AdaptiveConfiguration {
    
    /// Create a pipeline configuration optimized for the current device
    public static func forCurrentDevice() -> PipelineConfiguration {
        let tier = detectDeviceTier()
        return forTier(tier)
    }
    
    /// Create a pipeline configuration for a specific tier
    public static func forTier(_ tier: DeviceTier) -> PipelineConfiguration {
        switch tier {
        case .high:
            return PipelineConfiguration(
                activeRegionWords: 35,      // Larger context window
                confidenceThreshold: 0.75,  // Slightly more lenient
                toneTarget: .none,
                temperature: 0.1
            )
            
        case .balanced:
            return PipelineConfiguration(
                activeRegionWords: 20,      // Standard context
                confidenceThreshold: 0.80,  // Standard threshold
                toneTarget: .none,
                temperature: 0.1
            )
            
        case .graceful:
            return PipelineConfiguration(
                activeRegionWords: 12,      // Smaller context for speed
                confidenceThreshold: 0.85,  // More conservative
                toneTarget: .none,
                temperature: 0.05           // More deterministic
            )
        }
    }
    
    /// Create an LM configuration optimized for the current device
    public static func lmConfigForCurrentDevice(modelPath: String? = nil) -> LMConfiguration {
        let tier = detectDeviceTier()
        return lmConfigForTier(tier, modelPath: modelPath)
    }
    
    /// Create an LM configuration for a specific tier
    public static func lmConfigForTier(_ tier: DeviceTier, modelPath: String? = nil) -> LMConfiguration {
        switch tier {
        case .high:
            return LMConfiguration(
                modelPath: modelPath,
                maxTokens: tier.tokenWindow,
                temperature: 0.1,
                contextSize: 4096,
                gpuLayers: -1  // Use all GPU layers
            )
            
        case .balanced:
            return LMConfiguration(
                modelPath: modelPath,
                maxTokens: tier.tokenWindow,
                temperature: 0.1,
                contextSize: 2048,
                gpuLayers: -1
            )
            
        case .graceful:
            return LMConfiguration(
                modelPath: modelPath,
                maxTokens: tier.tokenWindow,
                temperature: 0.05,
                contextSize: 1024,
                gpuLayers: 0  // CPU only for stability
            )
        }
    }
}

// MARK: - Performance Monitoring

/// Tracks actual performance vs tier expectations
public actor PerformanceMonitor {
    private var latencySamples: [TimeInterval] = []
    private var currentTier: DeviceTier
    private let maxSamples = 50
    
    public init(tier: DeviceTier? = nil) {
        self.currentTier = tier ?? detectDeviceTier()
    }
    
    /// Record a correction latency sample
    public func recordLatency(_ latencyMs: Double) {
        latencySamples.append(latencyMs)
        if latencySamples.count > maxSamples {
            latencySamples.removeFirst()
        }
    }
    
    /// Get the p95 latency from recent samples
    public func p95Latency() -> Double? {
        guard latencySamples.count >= 10 else { return nil }
        let sorted = latencySamples.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }
    
    /// Check if we should consider tier adjustment
    public func shouldAdjustTier() -> TierAdjustment? {
        guard let p95 = p95Latency() else { return nil }
        let target = Double(currentTier.targetLatencyMs)
        
        // If consistently exceeding target by >50%, suggest downgrade
        if p95 > target * 1.5 && currentTier != .graceful {
            return .downgrade
        }
        
        // If consistently under target by >40%, suggest upgrade
        if p95 < target * 0.6 && currentTier != .high {
            return .upgrade
        }
        
        return nil
    }
    
    public enum TierAdjustment {
        case upgrade
        case downgrade
    }
}

// MARK: - Device Info

/// Human-readable device capability information
public struct DeviceInfo: Sendable {
    public let tier: DeviceTier
    public let gpuName: String
    public let memoryGB: Double
    public let isAppleSilicon: Bool
    
    public static var current: DeviceInfo {
        #if os(macOS) || os(iOS)
        if let device = MTLCreateSystemDefaultDevice() {
            let memoryGB = Double(device.recommendedMaxWorkingSetSize) / (1024 * 1024 * 1024)
            #if os(macOS)
            let isAppleSilicon = device.supportsFamily(.apple7) || device.supportsFamily(.apple8)
            #else
            let isAppleSilicon = true
            #endif
            
            return DeviceInfo(
                tier: detectDeviceTier(),
                gpuName: device.name,
                memoryGB: memoryGB,
                isAppleSilicon: isAppleSilicon
            )
        }
        #endif
        
        return DeviceInfo(
            tier: .graceful,
            gpuName: "Unknown",
            memoryGB: 0,
            isAppleSilicon: false
        )
    }
    
    public var summary: String {
        """
        Device Tier: \(tier.rawValue)
        GPU: \(gpuName)
        Memory: \(String(format: "%.1f", memoryGB)) GB
        Apple Silicon: \(isAppleSilicon ? "Yes" : "No")
        Token Window: \(tier.tokenWindow)
        Target Latency: \(tier.targetLatencyMs)ms
        Marker FPS: \(tier.markerFPS)
        """
    }
}

