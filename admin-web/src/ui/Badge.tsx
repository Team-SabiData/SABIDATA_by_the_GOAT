import { type ReactNode } from 'react';

const tones = {
  green: 'var(--green)', red: 'var(--red)', amber: 'var(--amber)',
  blue: 'var(--blue)', neutral: 'var(--text-sec)',
} as const;

export function Badge({ tone, dot = false, children }: { tone: keyof typeof tones; dot?: boolean; children: ReactNode }) {
  const c = tones[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, padding: '3px 10px',
      borderRadius: 'var(--radius-pill)', border: `1px solid ${c}`, color: c, fontSize: 12, fontWeight: 600,
    }}>
      {dot && <span style={{ width: 7, height: 7, borderRadius: '50%', background: c }} />}
      {children}
    </span>
  );
}
