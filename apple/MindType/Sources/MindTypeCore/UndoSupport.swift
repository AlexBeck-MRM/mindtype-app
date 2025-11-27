/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  A T O M I C   U N D O   S U P P O R T  ░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Groups all corrections from a sweep into single undo.     ║
  ║   Per Mind⠶Flow guide: "one sweep = one undo"               ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Undo grouping for correction sweeps
  • WHY  ▸ Reduces error anxiety, builds trust in invisible corrections
  • HOW  ▸ UndoManager grouping with sweep metadata
*/

import Foundation

#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

// MARK: - Sweep Undo Manager

/// Manages undo/redo for correction sweeps with atomic grouping
@MainActor
public final class SweepUndoManager: ObservableObject {
    
    /// The underlying undo manager
    public let undoManager: UndoManager
    
    /// Stack of sweep operations for debugging/display
    @Published public private(set) var sweepHistory: [SweepUndoRecord] = []
    
    /// Maximum history entries to retain
    public var maxHistory: Int = 50
    
    public init(undoManager: UndoManager? = nil) {
        self.undoManager = undoManager ?? UndoManager()
        self.undoManager.groupsByEvent = false // We control grouping explicitly
    }
    
    // MARK: - Record Sweep
    
    /// Register a correction sweep as a single undoable action
    /// - Parameters:
    ///   - originalText: Text before corrections
    ///   - correctedText: Text after corrections
    ///   - region: The active region that was corrected
    ///   - diffs: Individual corrections applied
    ///   - handler: Closure to apply text changes (called with original text on undo)
    public func registerSweep(
        originalText: String,
        correctedText: String,
        region: TextRegion,
        diffs: [CorrectionDiff],
        handler: @escaping (String) -> Void
    ) {
        // Don't register if no actual change
        guard originalText != correctedText else { return }
        
        // Create record
        let record = SweepUndoRecord(
            id: UUID(),
            timestamp: Date(),
            originalText: originalText,
            correctedText: correctedText,
            region: region,
            diffsApplied: diffs.count,
            stages: Set(diffs.map(\.stage))
        )
        
        // Group all changes as single undo
        undoManager.beginUndoGrouping()
        
        undoManager.registerUndo(withTarget: self) { [weak self] target in
            // On undo: restore original text
            handler(originalText)
            
            // Re-register for redo
            target.registerRedo(
                originalText: originalText,
                correctedText: correctedText,
                handler: handler
            )
            
            // Update history
            Task { @MainActor in
                self?.markUndone(record)
            }
        }
        
        undoManager.setActionName(sweepActionName(for: diffs))
        undoManager.endUndoGrouping()
        
        // Add to history
        addToHistory(record)
    }
    
    private func registerRedo(
        originalText: String,
        correctedText: String,
        handler: @escaping (String) -> Void
    ) {
        undoManager.registerUndo(withTarget: self) { target in
            // On redo: re-apply corrected text
            handler(correctedText)
            
            // Re-register for undo again
            target.registerSweep(
                originalText: originalText,
                correctedText: correctedText,
                region: TextRegion(start: 0, end: 0), // Simplified for redo
                diffs: [],
                handler: handler
            )
        }
        undoManager.setActionName("Redo Correction Sweep")
    }
    
    // MARK: - History Management
    
    private func addToHistory(_ record: SweepUndoRecord) {
        sweepHistory.insert(record, at: 0)
        if sweepHistory.count > maxHistory {
            sweepHistory.removeLast()
        }
    }
    
    private func markUndone(_ record: SweepUndoRecord) {
        if let index = sweepHistory.firstIndex(where: { $0.id == record.id }) {
            sweepHistory[index] = SweepUndoRecord(
                id: record.id,
                timestamp: record.timestamp,
                originalText: record.originalText,
                correctedText: record.correctedText,
                region: record.region,
                diffsApplied: record.diffsApplied,
                stages: record.stages,
                wasUndone: true
            )
        }
    }
    
    // MARK: - Action Names
    
    private func sweepActionName(for diffs: [CorrectionDiff]) -> String {
        let stages = Set(diffs.map(\.stage))
        
        if stages.count == 1, let stage = stages.first {
            return "Undo \(stage.displayName)"
        }
        
        if stages.contains(.noise) && stages.count == 1 {
            return "Undo Typo Fixes"
        }
        
        return "Undo Correction Sweep"
    }
    
    // MARK: - Convenience
    
    public var canUndo: Bool { undoManager.canUndo }
    public var canRedo: Bool { undoManager.canRedo }
    
    public func undo() {
        undoManager.undo()
    }
    
    public func redo() {
        undoManager.redo()
    }
}

// MARK: - Sweep Undo Record

/// Record of a correction sweep for history/debugging
public struct SweepUndoRecord: Identifiable, Sendable {
    public let id: UUID
    public let timestamp: Date
    public let originalText: String
    public let correctedText: String
    public let region: TextRegion
    public let diffsApplied: Int
    public let stages: Set<CorrectionStage>
    public var wasUndone: Bool = false
    
    public var summary: String {
        let stageNames = stages.map(\.displayName).sorted().joined(separator: ", ")
        let action = wasUndone ? "Undone" : "Applied"
        return "\(action): \(diffsApplied) corrections (\(stageNames))"
    }
    
    public var changePreview: String {
        // Show a brief preview of what changed
        let maxLen = 50
        let original = originalText.prefix(maxLen)
        let corrected = correctedText.prefix(maxLen)
        
        if original == corrected {
            return String(original)
        }
        
        return "\(original)... → \(corrected)..."
    }
}

// MARK: - UndoManager Extension

extension UndoManager {
    /// Convenience for registering a simple text change
    public func registerTextChange(
        from original: String,
        to corrected: String,
        actionName: String = "Text Correction",
        handler: @escaping (String) -> Void
    ) {
        beginUndoGrouping()
        registerUndo(withTarget: self) { manager in
            handler(original)
            manager.registerTextChange(
                from: corrected,
                to: original,
                actionName: "Redo \(actionName)",
                handler: handler
            )
        }
        setActionName(actionName)
        endUndoGrouping()
    }
}

