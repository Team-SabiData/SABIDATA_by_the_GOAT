import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminApi, type AdminUser, type AuditEntry, type Dispute, type Withdrawal } from '../api';
import { Card } from '../ui/Card';
import { KpiCard } from '../ui/KpiCard';
import { EmptyState } from '../ui/EmptyState';

export function Overview() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [pending, setPending] = useState<Withdrawal[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void Promise.all([
      adminApi.users(), adminApi.disputes(), adminApi.withdrawals('processing'), adminApi.auditLog(),
    ]).then(([u, d, w, a]) => {
      setUsers(u.users); setDisputes(d.disputes); setPending(w.withdrawals); setAudit(a.entries.slice(-5).reverse());
    }).catch((e) => setError((e as Error).message));
  }, []);

  const by = (s: string) => users.filter((u) => u.status === s).length;
  const fcfa = users.reduce((sum, u) => sum + (u.balanceFcfa ?? 0), 0);

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <h1 style={{ fontSize: 22, margin: 0 }}>Vue d'ensemble</h1>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
        <KpiCard label="Utilisateurs actifs" value={by('active')} tone="var(--green)" />
        <KpiCard label="Suspendus" value={by('suspended')} tone="var(--amber)" />
        <KpiCard label="Bannis" value={by('banned')} tone="var(--red)" />
        <KpiCard label="Litiges en attente" value={disputes.length} />
        <KpiCard label="Retraits à traiter" value={pending.length} tone="var(--accent)" />
        <KpiCard label="FCFA en circulation" value={fcfa.toLocaleString('fr-FR')} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <Card title="À traiter">
          {disputes.length === 0 && pending.length === 0
            ? <EmptyState title="Rien à traiter" message="La pair-review absorbe le volume." />
            : (
              <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 8 }}>
                {disputes.slice(0, 5).map((d) => (
                  <li key={d.id}><Link to="/disputes">Litige <code>{d.id.slice(0, 8)}</code> · {d.durationS}s · rareté {d.rarity}</Link></li>
                ))}
                {pending.slice(0, 5).map((w) => (
                  <li key={w.id}><Link to="/money">Retrait <span className="mono">{w.amountFcfa.toLocaleString('fr-FR')} FCFA</span> · {w.provider}</Link></li>
                ))}
              </ul>
            )}
        </Card>
        <Card title="Dernières actions">
          {audit.length === 0 ? <EmptyState title="Aucune action" /> : (
            <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 8, fontSize: 13 }}>
              {audit.map((e) => (
                <li key={e.id}>
                  <span className="mono" style={{ color: 'var(--text-sec)' }}>{new Date(e.createdAt).toLocaleString('fr-FR')}</span>
                  {' '}<strong style={{ color: 'var(--accent)' }}>{e.action}</strong>
                  {e.reason && <> — « {e.reason} »</>}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
