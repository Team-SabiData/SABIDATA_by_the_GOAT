export function KpiCard({ label, value, tone = 'var(--text)' }: { label: string; value: string | number; tone?: string }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <div className="mono" style={{ fontSize: 26, fontWeight: 700, color: tone }}>{value}</div>
      <div style={{ fontSize: 12, color: 'var(--text-sec)', marginTop: 4 }}>{label}</div>
    </div>
  );
}
