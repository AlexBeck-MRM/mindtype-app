/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M I N D T Y P E   T E S T I N G   G R O U N D  ░░░░░░░░  ║
  ║                                                              ║
  ║   Focused playground for monitoring all processes, testing  ║
  ║   type correction in real-time, and seeing caret organism   ║
  ║   animations.                                                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Modern testing ground for MindType pipeline
  • WHY  ▸ Simple, performant, stylized demo experience
  • HOW  ▸ React hook + caret organism + metrics panel
*/

import React, { useCallback, useEffect, useRef, useState } from 'react';
import './App.css';
import { useMindtypePipeline } from './hooks/useMindtypePipeline';
import { CaretOrganism } from './components/CaretOrganism';
import { MetricsPanel } from './components/MetricsPanel';
import { DEMO_PRESETS, DEFAULT_PRESET } from './demo-presets';
import { replaceRange } from '../../../src/safety/diff';

const SAMPLE_TEXT =
  'The keyboard evolved from telegraph experiments. Typing became a dialogue between intent and correction.';

export default function App() {
  const textareaRef = useRef<HTMLTextAreaElement>(null);
  const caretRef = useRef<number>(DEFAULT_PRESET.text.length);

  const [text, setText] = useState(DEFAULT_PRESET.text);
  const [presetName, setPresetName] = useState(DEFAULT_PRESET.name);
  const [panelOpen, setPanelOpen] = useState(true);
  const [autoTyping, setAutoTyping] = useState(false);
  const [scenarioOpen, setScenarioOpen] = useState(false);
  const autoTypingTimerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const autoIndexRef = useRef(0);

  const pipeline = useMindtypePipeline();
  const {
    state,
    activeRegion,
    swaps,
    diagnostics,
    lmTest,
    ingest,
    initWithRemote,
    retryAssets,
    runLMTest,
  } = pipeline;

  const handleTextChange = useCallback(
    (event: React.ChangeEvent<HTMLTextAreaElement>) => {
      const value = event.target.value;
      const caret = event.target.selectionStart ?? value.length;
      caretRef.current = caret;
      setText(value);
      ingest(value, caret);
    },
    [ingest],
  );

  const handlePresetChange = useCallback(
    (name: string) => {
      const preset = DEMO_PRESETS.find((p) => p.name === name);
      if (!preset) return;
      setPresetName(name);
      setText(preset.text);
      caretRef.current = preset.text.length;
      if (textareaRef.current) {
        textareaRef.current.selectionStart = preset.text.length;
        textareaRef.current.selectionEnd = preset.text.length;
      }
      ingest(preset.text, preset.text.length);
    },
    [ingest],
  );

  const applyExternalDiff = useCallback(
    (detail: { start: number; end: number; text: string }) => {
      setText((prev) => {
        const next = replaceRange(prev, detail.start, detail.end, detail.text, caretRef.current);
        caretRef.current = detail.start + detail.text.length;
        if (textareaRef.current) {
          textareaRef.current.selectionStart = caretRef.current;
          textareaRef.current.selectionEnd = caretRef.current;
        }
        ingest(next, caretRef.current);
        return next;
      });
    },
    [ingest],
  );

  // Listen for mechanical swap events
  const handleMechanicalSwap = useCallback(
    (event: Event) => {
      const detail = (event as CustomEvent<{
        start: number;
        end: number;
        text: string;
        originalText?: string;
      }>).detail;
      if (detail) {
        applyExternalDiff(detail);
      }
    },
    [applyExternalDiff],
  );

  // Setup DOM event listeners
  useEffect(() => {
    window.addEventListener('mindtype:mechanicalSwap', handleMechanicalSwap);
    return () => {
      window.removeEventListener('mindtype:mechanicalSwap', handleMechanicalSwap);
    };
  }, [handleMechanicalSwap]);

  // Auto-typing effect
  useEffect(() => {
    if (!autoTyping) {
      if (autoTypingTimerRef.current) {
        clearTimeout(autoTypingTimerRef.current);
        autoTypingTimerRef.current = null;
      }
      autoIndexRef.current = 0;
      return;
    }

    const tick = () => {
      if (autoIndexRef.current >= SAMPLE_TEXT.length) {
        setAutoTyping(false);
        return;
      }

      const nextChar = SAMPLE_TEXT[autoIndexRef.current];
      setText((prev) => {
        const nextText = prev + nextChar;
        const nextCaret = nextText.length;
        caretRef.current = nextCaret;
        if (textareaRef.current) {
          textareaRef.current.selectionStart = nextCaret;
          textareaRef.current.selectionEnd = nextCaret;
        }
        ingest(nextText, nextCaret);
        return nextText;
      });

      autoIndexRef.current += 1;

      if (autoIndexRef.current < SAMPLE_TEXT.length) {
        autoTypingTimerRef.current = setTimeout(tick, 120);
      }
    };

    autoTypingTimerRef.current = setTimeout(tick, 120);

    return () => {
      if (autoTypingTimerRef.current) {
        clearTimeout(autoTypingTimerRef.current);
        autoTypingTimerRef.current = null;
      }
    };
  }, [autoTyping, ingest]);

  const currentCaret = textareaRef.current?.selectionStart ?? text.length;

  return (
    <div className="App">
      {state.errorMessage && state.assetStatus === 'missing' && (
        <div className="status-tray">
          <p>{state.errorMessage}</p>
          <div className="status-actions">
            {state.canUseRemote && (
              <button className="ghost-button" onClick={initWithRemote}>
                Use remote tier
              </button>
            )}
            <button className="ghost-button" onClick={retryAssets}>
              Retry assets
            </button>
          </div>
        </div>
      )}

      <header className="app-header">
        <div>
          <h1>Mind⠶Type · Testing Ground</h1>
          <p>Thought-speed typing with caret-safe LM corrections.</p>
        </div>
        <div className="status-pills">
          <select
            className="preset-select"
            value={presetName}
            onChange={(e) => handlePresetChange(e.target.value)}
          >
            {DEMO_PRESETS.map((preset) => (
              <option key={preset.name} value={preset.name}>
                {preset.name}
              </option>
            ))}
          </select>
          <span className={`pill ${state.assetStatus === 'ready' ? 'ready' : state.assetStatus === 'missing' ? 'error' : 'loading'}`}>
            Assets: {state.assetStatus}
          </span>
          <span className={`pill ${state.lmStatus === 'ready' ? 'ready' : state.lmStatus === 'error' ? 'error' : 'loading'}`}>
            LM: {state.lmStatus}
          </span>
          <button onClick={() => setPanelOpen((v) => !v)} className="toggle-button">
            {panelOpen ? 'Hide' : 'Show'} Metrics
          </button>
        </div>
      </header>

      <div className="editor-layout">
        <section className="editor-section">
          <div className="editor-wrapper">
            <textarea
              ref={textareaRef}
              value={text}
              onChange={handleTextChange}
              onSelect={(e) => {
                const target = e.target as HTMLTextAreaElement;
                caretRef.current = target.selectionStart ?? text.length;
              }}
              placeholder="Start typing to see corrections..."
              className="editor-textarea"
            />
            <CaretOrganism
              text={text}
              caret={currentCaret}
              activeRegion={activeRegion}
              lmWireEvents={diagnostics.lmWireEvents}
              swaps={swaps}
              textareaRef={textareaRef}
            />
          </div>
          <div className="editor-actions">
            <button onClick={() => ingest(text, currentCaret)} className="action-button">
              Run corrections
            </button>
            <label className="action-label">
              <input
                type="checkbox"
                checked={autoTyping}
                onChange={(e) => {
                  setAutoTyping(e.target.checked);
                  autoIndexRef.current = 0;
                }}
              />
              Autotype sample
            </label>
            <button
              onClick={() => setScenarioOpen((v) => !v)}
              className="action-button action-button-secondary"
            >
              {scenarioOpen ? 'Hide' : 'Show'} Scenarios
            </button>
          </div>
        </section>

        {panelOpen && (
          <aside className="metrics-section">
            <MetricsPanel
              diagnostics={diagnostics}
              swaps={swaps}
              activeRegion={activeRegion}
              caret={currentCaret}
              lmTest={lmTest}
              runLMTest={runLMTest}
            />
          </aside>
        )}
      </div>

      {scenarioOpen && (
        <div className="scenario-drawer">
          <h3>Scenarios</h3>
          <div className="scenario-list">
            {DEMO_PRESETS.map((preset) => (
              <button
                key={preset.name}
                onClick={() => handlePresetChange(preset.name)}
                className={`scenario-button ${presetName === preset.name ? 'active' : ''}`}
              >
                <div className="scenario-name">{preset.name}</div>
                <div className="scenario-desc">{preset.description}</div>
              </button>
            ))}
          </div>
        </div>
      )}
    </div>
  );
}
