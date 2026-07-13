import { useCallback, useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminApi, type AdminUser, type AuditEntry } from '../api';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { DataTable, type Column } from '../ui/DataTable';

const ACTIONS = [
  'login',
  'user.status',
  'user.create',
  'user.delete',
  'user.update',
  'wallet.adjust',
  'withdrawal.decide',
  'clip.arbitrate',
] as const;

// Échappe TOUT champ CSV : quotes doublées + entourage systématique de
// guillemets (protège aussi les valeurs contenant le séparateur ';' ou un
// retour à la ligne), et neutralise l'injection de formule (Excel/Sheets
// exécutent une valeur commençant par = + - @ à l'ouverture) en préfixant
// d'une apostrophe.
export function csvField(value: string): string {
  const guarded = /^[=+\-@]/.test(value) ? `'${value}` : value;
  return `"${guarded.replaceAll('"', '""')}"`;
}

const actionTone = (action: string) => {
  if (action === 'login') return 'blue' as const;
  if (action === 'wallet.adjust' || action === 'withdrawal.decide') return 'amber' as const;
  if (action === 'user.delete' || action === 'user.status') return 'red' as const;
  return 'neutral' as const;
};

export function Audit() {
  const [entries, setEntries] = useState<AuditEntry[]>([]);
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [actionFilter, setActionFilter] = useState('toutes');
  const [actorFilter, setActorFilter] = useState('tous');
  const [dateStart, setDateStart] = useState('');
  const [dateEnd, setDateEnd] = useState('');

  const load = useCallback(() => {
    void Promise.all([adminApi.auditLog(), adminApi.users()])
      .then(([a, u]) => { setEntries(a.entries); setUsers(u.users); })
      .catch((e) => setError((e as Error).message));
  }, []);

  useEffect(() => { load(); }, [load]);

  const resolveName = (id: string) => users.find((u) => u.id === id)?.name ?? id.slice(0, 8);

  const filtered = entries.filter((e) => {
    if (actionFilter !== 'toutes' && e.action !== actionFilter) return false;
    if (actorFilter !== 'tous' && e.actorId !== actorFilter) return false;
    const created = new Date(e.createdAt);
    if (dateStart && created < new Date(dateStart)) return false;
    if (dateEnd) {
      const end = new Date(dateEnd);
      end.setHours(23, 59, 59, 999);
      if (created > end) return false;
    }
    return true;
  });

  const exportCsv = () => {
    const head = 'date;acteur;action;entite;motif';
    const lines = filtered.map((e) =>
      [
        csvField(new Date(e.createdAt).toISOString()),
        csvField(resolveName(e.actorId)),
        csvField(e.action),
        csvField(`${e.entityType}:${e.entityId}`),
        csvField(e.reason ?? ''),
      ].join(';'));
    const blob = new Blob([`${head}\n${lines.join('\n')}`], { type: 'text/csv;charset=utf-8' });
    const a = document.createElement('a');
    a.href = URL.createObjectURL(blob);
    a.download = `audit-sabidata-${new Date().toISOString().slice(0, 10)}.csv`;
    a.click();
    URL.revokeObjectURL(a.href);
  };

  const columns: Column<AuditEntry>[] = [
    { key: 'createdAt', label: 'Date', render: (e) => <span className="mono">{new Date(e.createdAt).toLocaleString('fr-FR')}</span> },
    { key: 'actorId', label: 'Acteur', render: (e) => resolveName(e.actorId) },
    { key: 'action', label: 'Action', render: (e) => <Badge tone={actionTone(e.action)}>{e.action}</Badge> },
    {
      key: 'entity',
      label: 'Entité',
      render: (e) => {
        const label = <code>{e.entityType}:{e.entityId.slice(0, 8)}</code>;
        return e.entityType === 'user' ? <Link to="/users">{label}</Link> : label;
      },
    },
    { key: 'reason', label: 'Motif', render: (e) => e.reason ?? '—' },
  ];

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <h1 style={{ fontSize: 22, margin: 0 }}>Audit</h1>
        <div style={{ marginLeft: 'auto' }}>
          <Button variant="outline" onClick={exportCsv}>Exporter CSV</Button>
        </div>
      </div>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <select aria-label="Filtrer par action" value={actionFilter} onChange={(e) => setActionFilter(e.target.value)}>
          <option value="toutes">Toutes les actions</option>
          {ACTIONS.map((a) => <option key={a} value={a}>{a}</option>)}
        </select>
        <select aria-label="Filtrer par acteur" value={actorFilter} onChange={(e) => setActorFilter(e.target.value)}>
          <option value="tous">Tous les acteurs</option>
          {users.map((u) => <option key={u.id} value={u.id}>{u.name}</option>)}
        </select>
        <label style={{ display: 'flex', flexDirection: 'column', fontSize: 12, color: 'var(--text-sec)', gap: 4 }}>
          Début
          <input aria-label="Date de début" type="date" value={dateStart} onChange={(e) => setDateStart(e.target.value)} />
        </label>
        <label style={{ display: 'flex', flexDirection: 'column', fontSize: 12, color: 'var(--text-sec)', gap: 4 }}>
          Fin
          <input aria-label="Date de fin" type="date" value={dateEnd} onChange={(e) => setDateEnd(e.target.value)} />
        </label>
      </div>
      <Card title="Journal d'audit">
        <DataTable
          columns={columns}
          rows={filtered}
          rowKey={(e) => e.id}
          emptyTitle={entries.length === 0 ? 'Aucune action enregistrée' : 'Aucune action pour ces filtres'}
        />
      </Card>
    </div>
  );
}
