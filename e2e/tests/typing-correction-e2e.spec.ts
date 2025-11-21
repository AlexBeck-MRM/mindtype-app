/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  T Y P I N G   C O R R E C T I O N   E 2 E   T E S T  ░░░  ║
  ║                                                              ║
  ║   Verifies that text corrections are applied after typing   ║
  ║   with typos, as per MindType documentation.                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
*/

import { test, expect } from '@playwright/test';

test.describe('Typing Correction E2E', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/');
    // Wait for app to initialize
    await page.waitForSelector('textarea', { timeout: 10000 });
    // Wait for LM to be ready (check for "LM: READY" status)
    await page.waitForFunction(
      () => {
        const buttons = Array.from(document.querySelectorAll('button'));
        return buttons.some((btn) => btn.textContent?.includes('LM: READY'));
      },
      { timeout: 30000 },
    );
  });

  test('should correct typos after typing pause', async ({ page }) => {
    const textarea = page.locator('textarea').first();
    const typoText = 'heya ha ve you hgeard there was a n icre cream trk outside';

    // Clear existing text
    await textarea.click();
    await textarea.fill('');
    await page.waitForTimeout(500);

    // Type text with typos
    await textarea.type(typoText, { delay: 50 });
    await page.waitForTimeout(2000); // Wait for pause-triggered correction

    // Wait for correction event (mechanicalSwap)
    const correctionApplied = await page.evaluate(() => {
      return new Promise<boolean>((resolve) => {
        const timeout = setTimeout(() => resolve(false), 10000);
        const handler = (event: Event) => {
          const detail = (event as CustomEvent).detail;
          if (detail?.start !== undefined && detail?.end !== undefined) {
            clearTimeout(timeout);
            window.removeEventListener('mindtype:mechanicalSwap', handler);
            resolve(true);
          }
        };
        window.addEventListener('mindtype:mechanicalSwap', handler);
      });
    });

    expect(correctionApplied).toBe(true);

    // Verify text was corrected (should have fewer typos)
    const finalText = await textarea.inputValue();
    expect(finalText).not.toBe(typoText);
    // Check for common corrections
    expect(finalText.toLowerCase()).toContain('have');
    expect(finalText.toLowerCase()).toContain('heard');
    expect(finalText.toLowerCase()).toContain('ice cream');
  });

  test('should apply corrections via Run corrections button', async ({ page }) => {
    const textarea = page.locator('textarea').first();
    const runButton = page.getByRole('button', { name: /run corrections/i });

    const typoText = 'heya ha ve you hgeard there was a n icre cream trk outside';

    // Set text with typos
    await textarea.click();
    await textarea.fill(typoText);
    await page.waitForTimeout(500);

    // Click Run corrections button
    await runButton.click();

    // Wait for correction to be applied
    await page.waitForTimeout(3000);

    // Verify text was corrected
    const finalText = await textarea.inputValue();
    expect(finalText).not.toBe(typoText);
    expect(finalText.length).toBeGreaterThan(0);
  });

  test('should handle LM initialization and test mode', async ({ page }) => {
    // Check that LM Test Mode is available
    const lmTestSection = page.locator('text=LM Test Mode').first();
    await expect(lmTestSection).toBeVisible({ timeout: 5000 });

    // Find and click Run check button
    const runCheckButton = page.getByRole('button', { name: /run check/i });
    if (await runCheckButton.isVisible()) {
      await runCheckButton.click();
      // Wait for LM test to complete
      await page.waitForTimeout(5000);

      // Check that response is not empty (or error is shown)
      const responseText = await page.locator('text=Response').locator('..').textContent();
      // Either we get a response or an error message
      expect(responseText).toBeTruthy();
    }
  });

  test('should show metrics panel with pipeline activity', async ({ page }) => {
    const metricsPanel = page.locator('text=Pipeline Activity').first();
    await expect(metricsPanel).toBeVisible({ timeout: 5000 });

    // Type some text to trigger pipeline activity
    const textarea = page.locator('textarea').first();
    await textarea.type('test text', { delay: 50 });
    await page.waitForTimeout(1000);

    // Verify metrics are visible
    const frontier = page.locator('text=Frontier').first();
    await expect(frontier).toBeVisible();
  });
});

