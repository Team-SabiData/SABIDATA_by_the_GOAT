import { type ReactNode } from 'react';

export function Field({ label, error, children }: { label: string; error?: string | null; children: ReactNode }) {
  return (
    <label style={{ display: 'grid', gap: 6 }}>
      <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-sec)' }}>{label}</span>
      {children}
      {error && <span style={{ fontSize: 12, color: 'var(--red)' }}>{error}</span>}
    </label>
  );
}
