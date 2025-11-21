/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  M E T R I C S   P A N E L  ░░░░░░░░░░░░░░░░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Live metrics cards for LM timeline, diffusion buffer,     ║
  ║   stage gates, and event log.                                ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Structured diagnostics display
  • WHY  ▸ Visibility into pipeline processes
  • HOW  ▸ Cards driven by hook diagnostics state
*/

import { useMemo } from 'react';
import type {
  DiagnosticsState,
  SwapEvent,
  LmTestState,
} from '../hooks/useMindtypePipeline';
import type { DiagEvent } from '../../../../src/pipeline/diagnosticsBus';
import './MetricsPanel.css';

export interface MetricsPanelProps {
  diagnostics: DiagnosticsState;
  swaps: SwapEvent[];
  activeRegion: { start: number; end: number } | null;
  caret: number;
  lmTest: LmTestState;
  runLMTest: (trigger?: 'warmup' | 'manual') => Promise<void>;
}

interface LMRequest {
  requestId: string;
  startTime: number;
  endTime: number | null;
  phases: Array<{ phase: string; time: number; detail?: unknown }>;
  confidence?: number;
  toneTarget?: string;
}

export function MetricsPanel({
  diagnostics,
  swaps,
  activeRegion,
  caret,
  lmTest,
  runLMTest,
}: MetricsPanelProps) {
  // Build LM timeline from wire events
  const lmTimeline = useMemo(() => {
    const requests = new Map<string, LMRequest>();

    for (const event of diagnostics.lmWireEvents) {
      const id = event.requestId || 'unknown';
      if (!requests.has(id)) {
        requests.set(id, {
          requestId: id,
          startTime: event.time,
          endTime: null,
          phases: [],
        });
      }

      const req = requests.get(id)!;
      req.phases.push({ phase: event.phase, time: event.time, detail: event.detail });

      if (event.phase === 'stream_init') {
        req.startTime = event.time;
      } else if (event.phase === 'stream_done' || event.phase === 'stream_error') {
        req.endTime = event.time;
      }
    }

    return Array.from(requests.values())
      .sort((a, b) => b.startTime - a.startTime)
      .slice(0, 10);
  }, [diagnostics.lmWireEvents]);

  // Diffusion buffer metrics
  const bufferMetrics = useMemo(() => {
    const frontier = activeRegion?.end ?? caret;
    const pendingWords = activeRegion
      ? Math.ceil((activeRegion.end - activeRegion.start) / 5)
      : 0;
    return { frontier, pendingWords };
  }, [activeRegion, caret]);

  // Stage gate decisions
  const stageGates = useMemo(() => {
    const noise = diagnostics.noiseEvents[diagnostics.noiseEvents.length - 1];
    const context = diagnostics.contextWindowEvents[diagnostics.contextWindowEvents.length - 1];
    return {
      noise: noise
        ? {
            decision: noise.decision,
            rule: noise.rule,
            window: noise.window,
          }
        : null,
      context: context
        ? {
            bandStart: context.bandStart,
            bandEnd: context.bandEnd,
            spanPreview: context.spanPreview,
          }
        : null,
    };
  }, [diagnostics.noiseEvents, diagnostics.contextWindowEvents]);

  // Event log (chunked by severity)
  const eventLog = useMemo(() => {
    const all: Array<{ ts: number; level: string; message: string; data?: unknown }> = [];
    for (const log of diagnostics.logs) {
      all.push({ ts: log.ts, level: log.level, message: log.message, data: log.data });
    }
    return all.slice(-100);
  }, [diagnostics.logs]);

  const lmTestSummary = useMemo(() => {
    const statusLabel =
      lmTest.status === 'running'
        ? 'Testing...'
        : lmTest.status === 'success'
          ? 'Healthy'
          : lmTest.status === 'error'
            ? 'Error'
            : 'Idle';
    return {
      statusLabel,
      responseSnippet: lmTest.response ? lmTest.response.slice(0, 160) : '—',
    };
  }, [lmTest]);

  return (
    <div className="metrics-panel">
      <div className="metrics-grid">
        <div className="metric-card">
          <div className="metric-card-header">
            <h3>LM Test Mode</h3>
            <button
              className="mini-button"
              onClick={() => runLMTest('manual')}
              disabled={lmTest.status === 'running'}
            >
              {lmTest.status === 'running' ? 'Testing…' : 'Run check'}
            </button>
          </div>
          <div className={`lm-test-status status-${lmTest.status}`}>
            <div className="status-dot" />
            <div>
              <div className="status-label">{lmTestSummary.statusLabel}</div>
              {lmTest.lastRun && (
                <div className="status-meta">
                  {new Date(lmTest.lastRun).toLocaleTimeString()} ·{' '}
                  {lmTest.durationMs ? `${Math.round(lmTest.durationMs)}ms` : '—'} ·{' '}
                  {lmTest.chunkCount ?? 0} chunks
                </div>
              )}
              {lmTest.status === 'error' && (
                <div className="status-error">{lmTest.errorMessage}</div>
              )}
            </div>
          </div>
          <div className="metric-content lm-test-details">
            <div>
              <span className="metric-label">Prompt:</span>
              <p>{lmTest.prompt}</p>
            </div>
            <div>
              <span className="metric-label">Response:</span>
              <p>{lmTestSummary.responseSnippet}</p>
            </div>
          </div>
        </div>

        <div className="metric-card">
          <h3>Pipeline Activity</h3>
          <div className="metric-content">
            <div className="metric-row">
              <span className="metric-label">Frontier</span>
              <span className="metric-value">{bufferMetrics.frontier}</span>
            </div>
            <div className="metric-row">
              <span className="metric-label">Pending words</span>
              <span className="metric-value">{bufferMetrics.pendingWords}</span>
            </div>
            {activeRegion ? (
              <div className="metric-row">
                <span className="metric-label">Active region</span>
                <span className="metric-value">
                  {activeRegion.start} → {activeRegion.end}
                </span>
              </div>
            ) : (
              <div className="metric-empty">Active region idle</div>
            )}
            <div className="gate-section">
              <div className="gate-label">Noise</div>
              {stageGates.noise ? (
                <>
                  <div className={`gate-decision gate-${stageGates.noise.decision}`}>
                    {stageGates.noise.decision}
                  </div>
                  <div className="gate-detail">{stageGates.noise.rule}</div>
                </>
              ) : (
                <div className="metric-empty">Waiting for pulse</div>
              )}
            </div>
            <div className="gate-section">
              <div className="gate-label">Context Window</div>
              {stageGates.context ? (
                <>
                  <div className="gate-detail">
                    [{stageGates.context.bandStart}, {stageGates.context.bandEnd}]
                  </div>
                  <div className="gate-preview">{stageGates.context.spanPreview}</div>
                </>
              ) : (
                <div className="metric-empty">No context request yet</div>
              )}
            </div>
          </div>
        </div>

        <div className="metric-card">
          <h3>LM Timeline</h3>
          <div className="metric-content">
            {lmTimeline.length === 0 ? (
              <div className="metric-empty">No LM traffic yet. Type or run the LM check.</div>
            ) : (
              <div className="timeline-list">
                {lmTimeline.map((req) => (
                  <div key={req.requestId} className="timeline-item">
                    <div className="timeline-header">
                      <span className="timeline-id">{req.requestId.slice(-6)}</span>
                      {req.endTime && (
                        <span className="timeline-duration">
                          {req.endTime - req.startTime}ms
                        </span>
                      )}
                    </div>
                    <div className="timeline-phases">
                      {req.phases.map((p, idx) => (
                        <span key={idx} className={`phase phase-${p.phase}`}>
                          {p.phase}
                        </span>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        <div className="metric-card metric-card-full">
          <h3>Event Log</h3>
          <div className="metric-content">
            <div className="event-log">
              {eventLog.length === 0
                ? (
                  <div className="metric-empty">No events yet</div>
                ) : (
                  eventLog.slice(-15).map((log, idx) => (
                    <div key={idx} className={`event-item event-${log.level}`}>
                      <span className="event-time">
                        {new Date(log.ts).toLocaleTimeString()}
                      </span>
                      <span className="event-level">{log.level}</span>
                      <span className="event-message">{log.message}</span>
                      {log.data && (
                        <span className="event-data">
                          {JSON.stringify(log.data).slice(0, 120)}
                        </span>
                      )}
                    </div>
                  ))
                )}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

