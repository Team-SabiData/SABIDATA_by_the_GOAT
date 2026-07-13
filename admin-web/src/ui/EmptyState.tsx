export function EmptyState({ title, message }: { title: string; message?: string }) {
  return (
    <div style={{ textAlign: 'center', padding: '32px 16px', color: 'var(--text-sec)' }}>
      <div style={{ fontWeight: 600, color: 'var(--text)' }}>{title}</div>
      {message && <div style={{ fontSize: 13, marginTop: 6 }}>{message}</div>}
    </div>
  );
}
