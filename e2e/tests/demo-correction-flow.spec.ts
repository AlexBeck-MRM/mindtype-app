/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  D E M O   C O R R E C T I O N   F L O W  ░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Playwright regression ensuring LM corrections emit        ║
  ║   mechanicalSwap events and update the textarea.            ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝ */

import { test, expect } from '@playwright/test';

const DEMO_URL = process.env.DEMO_URL || 'http://localhost:5173';

test.describe('Demo correction flow', () => {
  test('applies LM correction behind caret', async ({ page }) => {
    await page.goto(DEMO_URL);
    await page.waitForLoadState('domcontentloaded');

    // Wait for LM ready pill
    await page.waitForSelector('text=LM: ready', { timeout: 30000 });

    // Listen for mechanical swap events
    await page.exposeFunction('resolveSwap', (detail: unknown) => detail);
    await page.evaluate(() => {
      window.__mtSwapPromise = new Promise((resolve) => {
        window.addEventListener(
          'mindtype:mechanicalSwap',
          (event) => {
            // @ts-ignore
            window.__lastSwap = event.detail;
            resolve(event.detail);
          },
          { once: true },
        );
      });
    });

    const textarea = page.locator('textarea').first();
    await textarea.fill('');
    await textarea.type('heya ha ve you hgeard ther was a n icre cream trk outside', {
      delay: 30,
    });

    await page.locator('button', { hasText: 'Run corrections' }).click();

    // Wait for swap event
    const swapDetail = await page.evaluate(() => window.__mtSwapPromise);
    expect(swapDetail).toBeTruthy();

    const value = await textarea.inputValue();
    expect(value.toLowerCase()).toContain('have you heard');
    expect(value.toLowerCase()).toContain('ice cream truck');
  });
});


