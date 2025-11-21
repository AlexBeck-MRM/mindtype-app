import { useState, useEffect } from 'react';
import SystemMap from './SystemMap';
import './App.css';

interface SystemMapData {
  version: string;
  name: string;
  description: string;
  nodes: Array<{
    id: string;
    type: string;
    label: string;
    description: string;
    module?: string;
    connections?: string[];
    config?: Record<string, unknown>;
  }>;
  hosts: Array<{
    id: string;
    label: string;
    path: string;
    description: string;
  }>;
  metadata: {
    updated: string;
    architecture: string;
    principles: string[];
  };
}

type RelayPacket = {
  ts: number;
  event: {
    channel: string;
    [key: string]: unknown;
  };
};

const CHANNEL_TO_NODE: Record<string, string> = {
  noise: 'stage-noise',
  'context-window': 'stage-context',
  'lm-wire': 'lm-adapter',
};

const DIAG_STREAM_URL =
  import.meta.env.VITE_DIAG_STREAM_URL ?? 'http://localhost:5173/diag-stream';

export default function App() {
  const [systemMap, setSystemMap] = useState<SystemMapData | null>(null);
  const [loading, setLoading] = useState(true);
  const [liveEvents, setLiveEvents] = useState<RelayPacket[]>([]);
  const [liveActivity, setLiveActivity] = useState<Record<string, number>>({});
  const [streamStatus, setStreamStatus] = useState<
    'disabled' | 'idle' | 'connecting' | 'connected' | 'error'
  >(import.meta.env.DEV ? 'idle' : 'disabled');

  useEffect(() => {
    fetch('/system-map.json')
      .then((res) => res.json())
      .then((data) => {
        setSystemMap(data);
        setLoading(false);
      })
      .catch((err) => {
        console.error('Failed to load system map:', err);
        setLoading(false);
      });
  }, []);

  useEffect(() => {
    if (!import.meta.env.DEV) return;
    setStreamStatus('connecting');
    const source = new EventSource(DIAG_STREAM_URL, { withCredentials: false });

    source.onopen = () => setStreamStatus('connected');
    source.onerror = () => setStreamStatus((prev) => (prev === 'connected' ? 'error' : prev));
    source.onmessage = (evt) => {
      try {
        const packet = JSON.parse(evt.data) as RelayPacket;
        setLiveEvents((prev) => [...prev.slice(-99), packet]);
        const nodeId = CHANNEL_TO_NODE[packet.event.channel];
        if (nodeId) {
          setLiveActivity((prev) => ({
            ...prev,
            [nodeId]: packet.ts,
          }));
        }
      } catch {
        // ignore malformed payloads
      }
    };

    return () => {
      source.close();
      setStreamStatus('idle');
    };
  }, []);

  const telemetryLabel =
    streamStatus === 'disabled'
      ? 'Telemetry: offline (prod build)'
      : streamStatus === 'connected'
        ? 'Telemetry: live'
        : streamStatus === 'connecting'
          ? 'Telemetry: connecting…'
          : streamStatus === 'error'
            ? 'Telemetry: error'
            : 'Telemetry: idle';

  if (loading) {
    return (
      <div className="loading">
        <div className="spinner"></div>
        <p>Loading Mind⠶Flow Monitor...</p>
      </div>
    );
  }

  if (!systemMap) {
    return (
      <div className="error">
        <p>❌ Failed to load system map</p>
        <p>Check that system-map.json exists in public/</p>
      </div>
    );
  }

  return (
    <div className="app">
      <header className="header">
        <div className="header-left">
          <h1>Mind⠶Flow Monitor</h1>
          <span className="version">v{systemMap.version}</span>
        </div>
        <div className="header-right">
          <span className="status">● LIVE</span>
        </div>
      </header>

      <main className="main">
        <SystemMap data={systemMap} liveActivity={liveActivity} />
        {import.meta.env.DEV && (
          <aside className="telemetry-panel">
            <div className={`telemetry-pill ${streamStatus}`}>{telemetryLabel}</div>
            <div className="event-log">
              {liveEvents.length === 0 && <span className="event-log-empty">Waiting for events…</span>}
              {liveEvents
                .slice(-12)
                .reverse()
                .map((evt, idx) => (
                  <div key={`${evt.ts}-${idx}`} className="event-log-row">
                    <span className="event-log-time">
                      {new Date(evt.ts).toLocaleTimeString(undefined, {
                        hour: '2-digit',
                        minute: '2-digit',
                        second: '2-digit',
                      })}
                    </span>
                    <span className="event-log-channel">{evt.event.channel}</span>
                    <span className="event-log-detail">
                      {evt.event.channel === 'lm-wire'
                        ? (evt.event as { phase?: string; requestId?: string }).phase ?? ''
                        : evt.event.channel === 'noise'
                          ? (evt.event as { decision?: string; rule?: string }).rule ?? ''
                          : 'context window'}
                    </span>
                  </div>
                ))}
            </div>
          </aside>
        )}
      </main>

      <footer className="footer">
        <div className="footer-left">
          <span>Architecture: {systemMap.metadata.architecture}</span>
        </div>
        <div className="footer-right">
          <span>Last updated: {systemMap.metadata.updated}</span>
        </div>
      </footer>
    </div>
  );
}
