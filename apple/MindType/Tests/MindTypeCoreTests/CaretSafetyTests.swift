/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C A R E T   S A F E T Y   T E S T S  ░░░░░░░░░░░░░░░░░  ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import XCTest
@testable import MindTypeCore

final class CaretSafetyTests: XCTestCase {
    
    func testIsCaretSafe_regionBeforeCaret_returnsTrue() {
        XCTAssertTrue(isCaretSafe(start: 0, end: 5, caret: 10))
        XCTAssertTrue(isCaretSafe(start: 5, end: 10, caret: 10))
    }
    
    func testIsCaretSafe_regionAtCaret_returnsFalse() {
        XCTAssertFalse(isCaretSafe(start: 5, end: 15, caret: 10))
        XCTAssertFalse(isCaretSafe(start: 10, end: 15, caret: 10))
    }
    
    func testIsCaretSafe_regionAfterCaret_returnsFalse() {
        XCTAssertFalse(isCaretSafe(start: 15, end: 20, caret: 10))
    }
    
    func testIsCaretSafe_emptyRegion_returnsFalse() {
        XCTAssertFalse(isCaretSafe(start: 5, end: 5, caret: 10))
    }
    
    func testSafeReplace_validReplacement_succeeds() {
        let text = "Hello world"
        let result = safeReplace(text: text, start: 0, end: 5, replacement: "Hi", caret: 11)
        XCTAssertEqual(result, "Hi world")
    }
    
    func testSafeReplace_unsafeReplacement_returnsNil() {
        let text = "Hello world"
        let result = safeReplace(text: text, start: 0, end: 8, replacement: "Hi", caret: 5)
        XCTAssertNil(result)
    }
    
    func testApplyDiffs_multipleValidDiffs_appliesAll() {
        let text = "teh cat adn teh dog"
        let diffs = [
            CorrectionDiff(start: 0, end: 3, text: "the", stage: .noise),
            CorrectionDiff(start: 8, end: 11, text: "and", stage: .noise),
            CorrectionDiff(start: 12, end: 15, text: "the", stage: .noise)
        ]
        
        let result = applyDiffs(text: text, diffs: diffs, caret: 19)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.text, "the cat and the dog")
    }
}

