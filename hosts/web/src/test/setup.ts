import '@testing-library/jest-dom';

// Polyfill ResizeObserver for jsdom environment
type GlobalWithResizeObserver = typeof globalThis & {
  ResizeObserver?: typeof ResizeObserver;
};

const globalWithRO = globalThis as GlobalWithResizeObserver;

if (typeof globalWithRO.ResizeObserver === 'undefined') {
  class StubResizeObserver implements ResizeObserver {
    constructor(_callback: ResizeObserverCallback) {}

    observe(): void {}
    unobserve(): void {}
    disconnect(): void {}
    takeRecords(): ResizeObserverEntry[] {
      return [];
    }
  }

  globalWithRO.ResizeObserver = StubResizeObserver as typeof ResizeObserver;
}
