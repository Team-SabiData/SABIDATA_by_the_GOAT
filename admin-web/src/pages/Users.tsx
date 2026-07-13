import { useCallback, useEffect, useState } from 'react';
import { adminApi, type AdminUser } from '../api';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { Field } from '../ui/Field';
import { DataTable, type Column } from '../ui/DataTable';
import { useToast } from '../ui/Toast';
import { UserDrawer } from './UserDrawer';

const roleTone = { admin: 'amber', moderator: 'blue', validator: 'green', contributor: 'neutral' } as const;
const statusTone = { active: 'green', suspended: 'amber', banned: 'red', deleted: 'neutral' } as const;
const statusLabel: Record<string, string> = { active: 'actif', suspended: 'suspendu', banned: 'banni', deleted: 'supprimé' };

function CreateUserModal({ open, onClose, onCreated }: { open: boolean; onClose: () => void; onCreated: () => void }) {
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [role, setRole] = useState('contributor');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const { push } = useToast();

  useEffect(() => {
    if (open) { setName(''); setEmail(''); setPhone(''); setRole('contributor'); setPassword(''); setBusy(false); setError(null); }
  }, [open]);

  if (!open) return null;
  const ready = name.trim().length > 0 && (email.trim().length > 0 || phone.trim().length > 0) && !busy;

  const submit = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await adminApi.createUser({
        name: name.trim(),
        email: email.trim() || undefined,
        phone: phone.trim() || undefined,
        role,
        password: password.trim() || undefined,
      });
      push('Utilisateur créé');
      onCreated();
      onClose();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Une erreur est survenue.');
    } finally {
      setBusy(false);
    }
  };

  return (
    <div
      onClick={() => { if (!busy) onClose(); }}
      style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.55)', display: 'grid', placeItems: 'center', zIndex: 100 }}
    >
      <div role="dialog" aria-modal="true" aria-label="Créer un utilisateur" className="card"
        onClick={(e) => e.stopPropagation()} style={{ width: 420 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 6px' }}>Créer un utilisateur</h2>
        <div style={{ display: 'grid', gap: 12, marginTop: 12 }}>
          <Field label="Nom">
            <input value={name} onChange={(e) => setName(e.target.value)} placeholder="Nom complet" />
          </Field>
          <Field label="Email">
            <input value={email} onChange={(e) => setEmail(e.target.value)} placeholder="email@exemple.com" />
          </Field>
          <Field label="Téléphone">
            <input value={phone} onChange={(e) => setPhone(e.target.value)} placeholder="70000000" />
          </Field>
          <Field label="Rôle">
            <select value={role} onChange={(e) => setRole(e.target.value)}>
              <option value="contributor">Contributeur</option>
              <option value="validator">Validateur</option>
              <option value="moderator">Modérateur</option>
              <option value="admin">Admin</option>
            </select>
          </Field>
          <Field label="Mot de passe (optionnel si email)">
            <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} placeholder="•••••••••" />
          </Field>
          {error && <p style={{ color: 'var(--red)', fontSize: 13, margin: 0 }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <Button variant="outline" onClick={onClose}>Annuler</Button>
            <Button variant="primary" disabled={!ready} loading={busy} onClick={submit}>Créer</Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function Users() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [q, setQ] = useState('');
  const [statusFilter, setStatusFilter] = useState('tous');
  const [roleFilter, setRoleFilter] = useState('tous');
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const [createOpen, setCreateOpen] = useState(false);

  const load = useCallback(() => {
    void adminApi.users().then((d) => setUsers(d.users)).catch((e) => setError((e as Error).message));
  }, []);

  useEffect(() => { load(); }, [load]);

  const filtered = users.filter((u) =>
    (statusFilter === 'tous' || u.status === statusFilter)
    && (roleFilter === 'tous' || u.role === roleFilter)
    && (q === '' || u.name.toLowerCase().includes(q.toLowerCase()) || (u.email ?? '').includes(q) || (u.phone ?? '').includes(q)),
  );

  const columns: Column<AdminUser>[] = [
    { key: 'name', label: 'Nom' },
    {
      key: 'role',
      label: 'Rôle',
      render: (u) => <Badge tone={roleTone[u.role as keyof typeof roleTone] ?? 'neutral'}>{u.role}</Badge>,
    },
    {
      key: 'status',
      label: 'Statut',
      render: (u) => (
        <Badge dot tone={statusTone[u.status as keyof typeof statusTone] ?? 'neutral'}>
          {statusLabel[u.status] ?? u.status}
        </Badge>
      ),
    },
    {
      key: 'balanceFcfa',
      label: 'Solde',
      render: (u) => <span className="mono">{u.balanceFcfa == null ? '—' : `${u.balanceFcfa.toLocaleString('fr-FR')} F`}</span>,
    },
    {
      key: 'lastLoginAt',
      label: 'Dernière connexion',
      render: (u) => <span className="mono">{u.lastLoginAt ? new Date(u.lastLoginAt).toLocaleString('fr-FR') : 'jamais'}</span>,
    },
    { key: 'contact', label: 'Contact', render: (u) => u.email ?? u.phone ?? '—' },
  ];

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center' }}>
        <h1 style={{ fontSize: 22, margin: 0 }}>Utilisateurs</h1>
        <div style={{ marginLeft: 'auto' }}>
          <Button onClick={() => setCreateOpen(true)}>+ Créer un utilisateur</Button>
        </div>
      </div>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <div style={{ display: 'flex', gap: 12, alignItems: 'flex-end' }}>
        <input
          placeholder="Rechercher nom ou contact…"
          value={q}
          onChange={(e) => setQ(e.target.value)}
          style={{ flex: 1 }}
        />
        <select aria-label="Filtrer par statut" value={statusFilter} onChange={(e) => setStatusFilter(e.target.value)}>
          <option value="tous">Tous les statuts</option>
          <option value="active">Actif</option>
          <option value="suspended">Suspendu</option>
          <option value="banned">Banni</option>
          <option value="deleted">Supprimé</option>
        </select>
        <select aria-label="Filtrer par rôle" value={roleFilter} onChange={(e) => setRoleFilter(e.target.value)}>
          <option value="tous">Tous les rôles</option>
          <option value="contributor">Contributeur</option>
          <option value="validator">Validateur</option>
          <option value="moderator">Modérateur</option>
          <option value="admin">Admin</option>
        </select>
      </div>
      <Card title="Utilisateurs">
        <DataTable columns={columns} rows={filtered} rowKey={(u) => u.id} onRowClick={setSelected} emptyTitle="Aucun utilisateur" />
      </Card>
      <CreateUserModal open={createOpen} onClose={() => setCreateOpen(false)} onCreated={load} />
      {selected && <UserDrawer user={selected} onClose={() => setSelected(null)} onChanged={load} />}
    </div>
  );
}
