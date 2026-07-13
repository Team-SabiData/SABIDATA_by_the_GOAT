import { useCallback, useEffect, useState } from 'react';
import { adminApi, type AdminUser, type AuditEntry, type Withdrawal } from '../api';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { KpiCard } from '../ui/KpiCard';
import { DataTable, type Column } from '../ui/DataTable';
import { ReasonModal } from '../ui/Modal';
import { useToast } from '../ui/Toast';
import { useCounts } from '../AppShell';

type Tab = 'withdrawals' | 'adjustments';
type Decision = { id: string; kind: 'approved' | 'rejected' };

const statusTone = { processing: 'amber', paid: 'green', failed: 'red' } as const;
const statusLabel: Record<string, string> = { processing: 'en cours', paid: 'payé', failed: 'échoué' };

export function Money() {
  const [tab, setTab] = useState<Tab>('withdrawals');
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [withdrawals, setWithdrawals] = useState<Withdrawal[]>([]);
  const [adjustments, setAdjustments] = useState<AuditEntry[]>([]);
  const [statusFilter, setStatusFilter] = useState('tous');
  const [deciding, setDeciding] = useState<Decision | null>(null);
  const [error, setError] = useState<string | null>(null);
  const { push } = useToast();
  const { reload: reloadCounts } = useCounts();

  const load = useCallback(() => {
    void Promise.all([adminApi.users(), adminApi.withdrawals(), adminApi.auditLog({ action: 'wallet.adjust' })])
      .then(([u, w, a]) => { setUsers(u.users); setWithdrawals(w.withdrawals); setAdjustments(a.entries); })
      .catch((e) => setError((e as Error).message));
  }, []);

  useEffect(() => { load(); }, [load]);

  const userName = (id: string) => users.find((u) => u.id === id)?.name ?? id.slice(0, 8);

  const circulating = users.reduce((sum, u) => sum + (u.balanceFcfa ?? 0), 0);
  const pendingFcfa = withdrawals.filter((w) => w.status === 'processing').reduce((sum, w) => sum + w.amountFcfa, 0);
  const paidFcfa = withdrawals.filter((w) => w.status === 'paid').reduce((sum, w) => sum + w.amountFcfa, 0);

  const filteredWithdrawals = withdrawals.filter((w) => statusFilter === 'tous' || w.status === statusFilter);

  const confirmDecision = async (reason: string) => {
    if (!deciding) return;
    await adminApi.decideWithdrawal(deciding.id, deciding.kind, reason);
    load();
    reloadCounts();
    push(deciding.kind === 'approved' ? 'Retrait approuvé' : 'Retrait refusé');
  };

  const withdrawalColumns: Column<Withdrawal>[] = [
    { key: 'createdAt', label: 'Date', render: (w) => <span className="mono">{new Date(w.createdAt).toLocaleString('fr-FR')}</span> },
    { key: 'userId', label: 'Utilisateur', render: (w) => userName(w.userId) },
    { key: 'amountFcfa', label: 'Montant', render: (w) => <span className="mono">{w.amountFcfa.toLocaleString('fr-FR')} FCFA</span> },
    { key: 'provider', label: 'Provider' },
    {
      key: 'status',
      label: 'Statut',
      render: (w) => (
        <Badge dot tone={statusTone[w.status as keyof typeof statusTone] ?? 'neutral'}>
          {statusLabel[w.status] ?? w.status}
        </Badge>
      ),
    },
    {
      key: 'actions',
      label: 'Actions',
      render: (w) => w.status !== 'processing' ? null : (
        <div style={{ display: 'flex', gap: 8 }}>
          <Button
            variant="primary"
            style={{ background: 'var(--green)' }}
            onClick={() => setDeciding({ id: w.id, kind: 'approved' })}
          >
            Approuver
          </Button>
          <Button variant="danger" onClick={() => setDeciding({ id: w.id, kind: 'rejected' })}>
            Refuser
          </Button>
        </div>
      ),
    },
  ];

  const adjustmentColumns: Column<AuditEntry>[] = [
    { key: 'createdAt', label: 'Date', render: (e) => <span className="mono">{new Date(e.createdAt).toLocaleString('fr-FR')}</span> },
    { key: 'actorId', label: 'Acteur', render: (e) => userName(e.actorId) },
    { key: 'entityId', label: 'Cible', render: (e) => userName(e.entityId) },
    {
      key: 'delta',
      label: 'Delta',
      render: (e) => {
        const delta = Number((e.metadata as { delta?: number } | undefined)?.delta ?? 0);
        return (
          <span className="mono" style={{ color: delta >= 0 ? 'var(--green)' : 'var(--red)' }}>
            {delta >= 0 ? '+' : ''}{delta.toLocaleString('fr-FR')}
          </span>
        );
      },
    },
    { key: 'reason', label: 'Motif', render: (e) => e.reason ?? '—' },
  ];

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <h1 style={{ fontSize: 22, margin: 0 }}>Argent</h1>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 12 }}>
        <KpiCard label="FCFA en circulation" value={circulating.toLocaleString('fr-FR')} />
        <KpiCard label="En attente de retrait" value={pendingFcfa.toLocaleString('fr-FR')} tone="var(--amber)" />
        <KpiCard label="Payés" value={paidFcfa.toLocaleString('fr-FR')} tone="var(--green)" />
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <Button variant={tab === 'withdrawals' ? 'primary' : 'outline'} onClick={() => setTab('withdrawals')}>
          Retraits
        </Button>
        <Button variant={tab === 'adjustments' ? 'primary' : 'outline'} onClick={() => setTab('adjustments')}>
          Ajustements
        </Button>
      </div>
      {tab === 'withdrawals' ? (
        <Card
          title="Retraits"
          actions={
            <select aria-label="Filtrer par statut" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
              <option value="tous">Tous les statuts</option>
              <option value="processing">En cours</option>
              <option value="paid">Payé</option>
              <option value="failed">Échoué</option>
            </select>
          }
        >
          <DataTable
            columns={withdrawalColumns}
            rows={filteredWithdrawals}
            rowKey={(w) => w.id}
            emptyTitle={withdrawals.length === 0 ? 'Aucun retrait' : 'Aucun retrait pour ce statut'}
          />
        </Card>
      ) : (
        <Card title="Ajustements">
          <DataTable columns={adjustmentColumns} rows={adjustments} rowKey={(e) => e.id} emptyTitle="Aucun ajustement" />
        </Card>
      )}
      <ReasonModal
        open={deciding !== null}
        title={deciding?.kind === 'approved' ? 'Approuver le retrait' : 'Refuser le retrait'}
        description={
          deciding?.kind === 'approved'
            ? 'Le retrait sera marqué payé.'
            : 'Le retrait sera refusé et le solde restitué.'
        }
        confirmLabel={deciding?.kind === 'approved' ? 'Approuver' : 'Refuser'}
        danger={deciding?.kind === 'rejected'}
        onConfirm={confirmDecision}
        onClose={() => setDeciding(null)}
      />
    </div>
  );
}
