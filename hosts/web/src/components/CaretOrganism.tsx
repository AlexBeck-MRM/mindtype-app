/*╔══════════════════════════════════════════════════════════════╗
  ║  ░  C A R E T   O R G A N I S M   V I S U A L  ░░░░░░░░░░░░░  ║
  ║                                                              ║
  ║   Animated braille marker showing Listening/Travelling/      ║
  ║   Applying states with active region overlay.                 ║
  ║                                                              ║
  ╚══════════════════════════════════════════════════════════════╝
  • WHAT ▸ Visual correction marker with stage animations
  • WHY  ▸ Show users the LM intelligence working
  • HOW  ▸ CSS animations + active region coordinates
*/

import { useEffect, useMemo, useRef, useState, type RefObject } from 'react';
import type { ActiveRegionState } from '../hooks/useMindtypePipeline';
import type { DiagEvent } from '../../../../src/pipeline/diagnosticsBus';
import './CaretOrganism.css';

export interface CaretOrganismProps {
  text: string;
  caret: number;
  activeRegion: ActiveRegionState | null;
  lmWireEvents: Array<DiagEvent & { channel: 'lm-wire' }>;
  swaps: Array<{ start: number; end: number; timestamp: number }>;
  textareaRef: RefObject<HTMLTextAreaElement | null>;
}

type MarkerMode = 'listening' | 'travelling' | 'applying' | 'idle';

const LISTENING_SEQUENCE = ['⠂', '⠄', '⠆', '⠠', '⠢', '⠤', '⠦', '⠰', '⠲', '⠴', '⠶'];
const TRAVELLING_PATTERNS = {
  noise: ['⠁', '⠂', '⠄', '⠈'],
  context: ['⠃', '⠆', '⠌'],
  tone: ['⠷', '⠿', '⠷'],
};

type OverlayRect = { left: number; top: number; width: number; height: number };

function createMirror(textarea: HTMLTextAreaElement): HTMLDivElement {
  const div = document.createElement('div');
  const style = window.getComputedStyle(textarea);
  const properties = [
    'boxSizing',
    'width',
    'height',
    'fontFamily',
    'fontSize',
    'fontWeight',
    'fontStyle',
    'letterSpacing',
    'textTransform',
    'textAlign',
    'lineHeight',
    'paddingTop',
    'paddingRight',
    'paddingBottom',
    'paddingLeft',
    'borderTopWidth',
    'borderRightWidth',
    'borderBottomWidth',
    'borderLeftWidth',
    'whiteSpace',
  ] as const;
  properties.forEach((prop) => {
    div.style[prop] = style[prop];
  });
  div.style.position = 'absolute';
  div.style.visibility = 'hidden';
  div.style.whiteSpace = textarea.wrap === 'off' ? 'pre' : 'pre-wrap';
  div.style.wordWrap = 'break-word';
  div.style.overflow = 'hidden';
  div.scrollTop = textarea.scrollTop;
  div.scrollLeft = textarea.scrollLeft;
  return div;
}

function getCaretPosition(
  textarea: HTMLTextAreaElement,
  selectionEnd: number,
): { left: number; top: number; height: number } {
  const mirror = createMirror(textarea);
  const value = textarea.value || '';
  const before = value.slice(0, selectionEnd);
  const after = value.slice(selectionEnd) || '.';

  mirror.textContent = before;
  if (before.endsWith('\n')) {
    mirror.textContent += '\u200b';
  }
  const markerSpan = document.createElement('span');
  markerSpan.textContent = after;
  mirror.appendChild(markerSpan);
  document.body.appendChild(mirror);
  const spanRect = markerSpan.getBoundingClientRect();
  const textRect = textarea.getBoundingClientRect();
  const borderLeft = parseFloat(window.getComputedStyle(textarea).borderLeftWidth || '0');
  const borderTop = parseFloat(window.getComputedStyle(textarea).borderTopWidth || '0');

  const position = {
    left: spanRect.left - textRect.left - borderLeft,
    top: spanRect.top - textRect.top - borderTop,
    height:
      parseFloat(window.getComputedStyle(textarea).lineHeight || '') ||
      parseFloat(window.getComputedStyle(textarea).fontSize || '16'),
  };
  document.body.removeChild(mirror);
  return position;
}

function getRegionRects(
  textarea: HTMLTextAreaElement,
  start: number,
  end: number,
): OverlayRect[] {
  if (start >= end) return [];
  const mirror = createMirror(textarea);
  const value = textarea.value || '';
  const before = document.createTextNode(value.slice(0, start));
  const highlight = document.createElement('span');
  highlight.textContent = value.slice(start, end) || ' ';
  const after = document.createTextNode(value.slice(end));
  mirror.append(before, highlight, after);
  document.body.appendChild(mirror);

  const textRect = textarea.getBoundingClientRect();
  const style = window.getComputedStyle(textarea);
  const borderLeft = parseFloat(style.borderLeftWidth || '0');
  const borderTop = parseFloat(style.borderTopWidth || '0');

  const rects = Array.from(highlight.getClientRects()).map((rect) => ({
    left: rect.left - textRect.left - borderLeft,
    top: rect.top - textRect.top - borderTop,
    width: rect.width,
    height: rect.height,
  }));

  document.body.removeChild(mirror);
  return rects;
}

export function CaretOrganism({
  text,
  caret,
  activeRegion,
  lmWireEvents,
  swaps,
  textareaRef,
}: CaretOrganismProps) {
  const [mode, setMode] = useState<MarkerMode>('idle');
  const [symbol, setSymbol] = useState('⠶');
  const sequenceRef = useRef(0);
  const [markerPosition, setMarkerPosition] = useState<{ left: number; top: number; height: number }>({
    left: 0,
    top: 0,
    height: 18,
  });
  const [regionRects, setRegionRects] = useState<OverlayRect[]>([]);
  const [wakeRects, setWakeRects] = useState<Array<OverlayRect & { opacity: number }>>([]);
  const reducedMotion = useMemo(
    () => typeof window !== 'undefined' && window.matchMedia?.('(prefers-reduced-motion: reduce)').matches,
    [],
  );

  // Determine mode from LM wire events
  useEffect(() => {
    const latest = lmWireEvents[lmWireEvents.length - 1];
    if (!latest) {
      setMode('idle');
      return;
    }

    if (latest.phase === 'stream_init' || latest.phase === 'msg_send') {
      setMode('travelling');
    } else if (latest.phase === 'chunk_recv' || latest.phase === 'chunk_yield') {
      setMode('applying');
    } else if (latest.phase === 'stream_done') {
      setMode('listening');
    } else {
      setMode('listening');
    }
  }, [lmWireEvents]);

  // Animate symbol based on mode
  useEffect(() => {
    if (reducedMotion) {
      setSymbol('⠶');
      return;
    }

    let interval: ReturnType<typeof setInterval> | null = null;

    if (mode === 'listening') {
      interval = setInterval(() => {
        sequenceRef.current = (sequenceRef.current + 1) % LISTENING_SEQUENCE.length;
        setSymbol(LISTENING_SEQUENCE[sequenceRef.current]);
      }, 200);
    } else if (mode === 'travelling') {
      const pattern = TRAVELLING_PATTERNS.context;
      interval = setInterval(() => {
        sequenceRef.current = (sequenceRef.current + 1) % pattern.length;
        setSymbol(pattern[sequenceRef.current]);
      }, 150);
    } else if (mode === 'applying') {
      const pattern = TRAVELLING_PATTERNS.noise;
      interval = setInterval(() => {
        sequenceRef.current = (sequenceRef.current + 1) % pattern.length;
        setSymbol(pattern[sequenceRef.current]);
      }, 50);
    } else {
      setSymbol('⠶');
    }

    return () => {
      if (interval) clearInterval(interval);
    };
  }, [mode, reducedMotion]);

  // Calculate marker + region overlay positions
  useEffect(() => {
    const textarea = textareaRef.current;
    if (!textarea) return;

    function updatePositions() {
      setMarkerPosition(getCaretPosition(textarea, caret));
      if (activeRegion && activeRegion.start < activeRegion.end) {
        setRegionRects(getRegionRects(textarea, activeRegion.start, activeRegion.end));
      } else {
        setRegionRects([]);
      }
      const recentSwaps = swaps.filter((s) => Date.now() - s.timestamp < 2000).slice(-3);
      const rects = recentSwaps.flatMap((swap, idx) =>
        getRegionRects(textarea, swap.start, swap.end).map((rect) => ({
          ...rect,
          opacity: 0.85 - idx * 0.2,
        })),
      );
      setWakeRects(rects);
    }

    updatePositions();
    window.addEventListener('resize', updatePositions);
    textarea.addEventListener('scroll', updatePositions);
    return () => {
      window.removeEventListener('resize', updatePositions);
      textarea.removeEventListener('scroll', updatePositions);
    };
  }, [textareaRef, caret, activeRegion, swaps, text]);

  // Recent swaps for wake trail
  if (!textareaRef.current) return null;

  return (
    <div className="caret-organism">
      {regionRects.map((rect, idx) => (
        <div
          key={`region-${idx}`}
          className="active-region-overlay"
          style={{
            transform: `translate(${rect.left}px, ${rect.top}px)`,
            width: `${rect.width}px`,
            height: `${rect.height}px`,
          }}
        />
      ))}
      {wakeRects.map((rect, idx) => (
        <div
          key={`wake-${idx}`}
          className="wake-trail"
          style={{
            transform: `translate(${rect.left}px, ${rect.top}px)`,
            width: `${rect.width}px`,
            height: `${rect.height}px`,
            opacity: rect.opacity,
          }}
        />
      ))}
      <div
        className={`marker marker-${mode}`}
        style={{
          transform: `translate(${markerPosition.left}px, ${markerPosition.top}px)`,
          lineHeight: `${markerPosition.height}px`,
        }}
        aria-label={`Correction marker: ${mode}`}
      >
        {symbol}
      </div>
      {mode !== 'idle' && (
        <div className={`stage-badge stage-${mode}`}>
          {mode === 'listening' && 'Listening'}
          {mode === 'travelling' && 'Travelling'}
          {mode === 'applying' && 'Applying'}
        </div>
      )}
    </div>
  );
}

