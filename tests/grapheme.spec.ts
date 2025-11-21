/*╔══════════════════════════════════════════════════════╗
  ║  ░  G R A P H E M E   S A F E T Y   T E S T S  ░░░░░  ║
  ║                                                      ║
  ║                                                      ║
  ║                                                      ║
  ║                                                      ║
  ║           ╌╌  P L A C E H O L D E R  ╌╌              ║
  ║                                                      ║
  ║                                                      ║
  ║                                                      ║
  ║                                                      ║
  ╚══════════════════════════════════════════════════════╝
  • WHAT ▸ Test Unicode grapheme cluster safety utilities
  • WHY  ▸ Prevent text corruption with emoji, ZWJ, combining marks
  • HOW  ▸ Test boundary detection and range alignment
*/

import { describe, it, expect } from 'vitest';
import {
  isGraphemeBoundary,
  alignToGraphemeBoundaries,
  isCaretSafe,
} from '../src/safety/grapheme';

describe('Grapheme Safety', () => {
  describe('isGraphemeBoundary', () => {
    it('handles basic ASCII text', () => {
      const text = 'Hello world';
      expect(isGraphemeBoundary(text, 0)).toBe(true);
      expect(isGraphemeBoundary(text, 5)).toBe(true); // Space
      expect(isGraphemeBoundary(text, text.length)).toBe(true);
    });

    it('detects emoji sequence boundaries', () => {
      const text = 'Hi 👋🏽 there';
      expect(isGraphemeBoundary(text, 3)).toBe(true); // Before emoji
      expect(isGraphemeBoundary(text, 4)).toBe(false); // Inside emoji sequence
      expect(isGraphemeBoundary(text, 7)).toBe(true); // After emoji
    });

    it('handles ZWJ family sequences', () => {
      const text = 'Family 👨‍👩‍👧‍👦 photo';
      expect(isGraphemeBoundary(text, 7)).toBe(true); // Before family
      expect(isGraphemeBoundary(text, 8)).toBe(false); // Inside ZWJ sequence
      expect(isGraphemeBoundary(text, 18)).toBe(true); // After family
    });

    it('handles combining characters', () => {
      const text = 'café naïve résumé';
      // Each accented character should be treated as single grapheme
      expect(isGraphemeBoundary(text, 0)).toBe(true);
      expect(isGraphemeBoundary(text, 4)).toBe(true); // After é
      expect(isGraphemeBoundary(text, 5)).toBe(true); // Space
    });

    it('handles edge cases', () => {
      const text = 'test';
      expect(isGraphemeBoundary(text, -1)).toBe(true); // Before start
      expect(isGraphemeBoundary(text, text.length + 1)).toBe(true); // After end
      expect(isGraphemeBoundary('', 0)).toBe(true); // Empty string
    });
  });

  describe('alignToGraphemeBoundaries', () => {
    it('adjusts ranges to safe boundaries', () => {
      const text = 'Test 👨‍💻 code';
      const { start, end } = alignToGraphemeBoundaries(text, 6, 9); // Inside emoji

      expect(isGraphemeBoundary(text, start)).toBe(true);
      expect(isGraphemeBoundary(text, end)).toBe(true);
      expect(start).toBeLessThanOrEqual(6);
      expect(end).toBeGreaterThanOrEqual(9);
    });

    it('preserves valid ranges', () => {
      const text = 'Valid range';
      const { start, end } = alignToGraphemeBoundaries(text, 0, 5);

      expect(start).toBe(0);
      expect(end).toBe(5);
    });

    it('handles skin tone modifiers', () => {
      const text = 'Wave 👋🏽 hello';
      const { start, end } = alignToGraphemeBoundaries(text, 5, 8); // Inside emoji

      expect(isGraphemeBoundary(text, start)).toBe(true);
      expect(isGraphemeBoundary(text, end)).toBe(true);
    });
  });

  describe('isCaretSafe', () => {
    it('validates caret safety', () => {
      expect(isCaretSafe(0, 5, 10)).toBe(true); // Before caret
      expect(isCaretSafe(0, 10, 10)).toBe(true); // At caret (boundary)
      expect(isCaretSafe(0, 15, 10)).toBe(false); // After caret
    });

    it('handles edge cases', () => {
      expect(isCaretSafe(0, 0, 0)).toBe(true); // Empty range at caret
      expect(isCaretSafe(5, 5, 5)).toBe(true); // Empty range at caret
    });
  });
});
