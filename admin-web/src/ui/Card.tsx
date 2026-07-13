import { type ReactNode } from 'react';

export function Card({ title, actions, children }: { title?: string; actions?: ReactNode; children: ReactNode }) {
  return (
    <section className="card">
      {(title || actions) && (
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 14 }}>
          {title && <h2 style={{ fontSize: 15, margin: 0 }}>{title}</h2>}
          <div style={{ marginLeft: 'auto' }}>{actions}</div>
        </div>
      )}
      {children}
    </section>
  );
}
