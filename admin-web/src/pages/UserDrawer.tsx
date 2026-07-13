import { useCallback, useEffect, useState } from 'react';
import { adminApi, type AdminUser, type AuditEntry, type LedgerLine, type Wallet } from '../api';
import { Drawer } from '../ui/Drawer';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { Field } from '../ui/Field';
import { ReasonModal } from '../ui/Modal';
import { EmptyState } from '../ui/EmptyState';
import { useToast } from '../ui/Toast';

const roleTone = { admin: 'amber', moderator: 'blue', validator: 'green', contributor: 'neutral' } as const;
const statusTone = { active: 'green', suspended: 'amber', banned: 'red', deleted: 'neutral' } as const;
const statusLabel: Record<string, string> = { active: 'actif', suspended: 'suspendu', banned: 'banni', deleted: 'supprimé' };

type ActionKind = 'promote' | 'demote' | 'suspend' | 'reactivate' | 'ban' | 'delete';

// Modale maison pour l'ajustement de solde : même squelette que ReasonModal
// (backdrop, card, garde busy, erreur affichée) + un champ delta numérique.
function AdjustBalanceModal({ open, onClose, onConfirm }: {
  open: boolean; onClose: () => void; onConfirm: (delta: number, reason: string) => Promise<void>;
}) {
  const [delta, setDelta] = useState('0');
  const [reason, setReason] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) { setDelta('0'); setReason(''); setBusy(false); setError(null); }
  }, [open]);

  if (!open) return null;
  const n = Number(delta);
  const ready = Number.isFinite(n) && n !== 0 && reason.trim().length > 0 && !busy;

  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await onConfirm(n, reason.trim());
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
      <div role="dialog" aria-modal="true" aria-label="Ajuster le solde" className="card"
        onClick={(e) => e.stopPropagation()} style={{ width: 420 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 6px' }}>Ajuster le solde</h2>
        <div style={{ display: 'grid', gap: 12, marginTop: 12 }}>
          <Field label="Delta (points, positif ou négatif)">
            <input type="number" value={delta} onChange={(e) => setDelta(e.target.value)} />
          </Field>
          <Field label="Motif (obligatoire, journalisé)">
            <textarea rows={3} placeholder="Motif de l'ajustement…" value={reason} onChange={(e) => setReason(e.target.value)} />
          </Field>
          {error && <p style={{ color: 'var(--red)', fontSize: 13, margin: 0 }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <Button variant="outline" onClick={onClose}>Annuler</Button>
            <Button variant="primary" disabled={!ready} loading={busy} onClick={confirm}>Ajuster</Button>
          </div>
        </div>
      </div>
    </div>
  );
}

export function UserDrawer({ user, onClose, onChanged }: {
  user: AdminUser; onClose: () => void; onChanged: () => void;
}) {
  const [wallet, setWallet] = useState<Wallet | null>(null);
  const [ledger, setLedger] = useState<LedgerLine[]>([]);
  const [activity, setActivity] = useState<AuditEntry[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [action, setAction] = useState<ActionKind | null>(null);
  const [adjustOpen, setAdjustOpen] = useState(false);
  const { push } = useToast();

  const loadDetails = useCallback(() => {
    void adminApi.userWallet(user.id).then(setWallet).catch((e) => setError((e as Error).message));
    void adminApi.userLedger(user.id).then((d) => setLedger(d.entries)).catch((e) => setError((e as Error).message));
    void adminApi.userActivity(user.id).then((d) => setActivity(d.entries)).catch((e) => setError((e as Error).message));
  }, [user.id]);

  useEffect(() => { loadDetails(); }, [loadDetails]);

  const readOnly = user.status === 'deleted';

  // Ces actions changent l'identité (rôle/statut) affichée dans la fiche : on
  // recharge la liste parente puis on referme, la fiche rouverte reflète l'état à jour.
  const finishIdentityAction = (msg: string) => {
    push(msg);
    onChanged();
    onClose();
  };

  const runAction = async (reason: string) => {
    if (!action) return;
    switch (action) {
      case 'promote':
        await adminApi.updateUser(user.id, { role: 'validator', competence: Math.max(user.competence, 1) }, reason);
        finishIdentityAction('Utilisateur promu validateur');
        break;
      case 'demote':
        await adminApi.updateUser(user.id, { role: 'contributor', competence: 0 }, reason);
        finishIdentityAction('Utilisateur rétrogradé contributeur');
        break;
      case 'suspend':
        await adminApi.setUserStatus(user.id, 'suspended', reason);
        finishIdentityAction('Utilisateur suspendu');
        break;
      case 'reactivate':
        await adminApi.setUserStatus(user.id, 'active', reason);
        finishIdentityAction('Utilisateur réactivé');
        break;
      case 'ban':
        await adminApi.setUserStatus(user.id, 'banned', reason);
        finishIdentityAction('Utilisateur banni');
        break;
      case 'delete':
        await adminApi.deleteUser(user.id, reason);
        finishIdentityAction('Utilisateur supprimé');
        break;
    }
  };

  const adjust = async (delta: number, reason: string) => {
    await adminApi.adjust(user.id, delta, reason);
    push('Solde ajusté');
    loadDetails();
    onChanged();
  };

  const actionConfig: Record<ActionKind, { title: string; confirmLabel: string; danger?: boolean; requireText?: string }> = {
    promote: { title: 'Promouvoir validateur', confirmLabel: 'Promouvoir' },
    demote: { title: 'Rétrograder contributeur', confirmLabel: 'Rétrograder' },
    suspend: { title: "Suspendre l'utilisateur", confirmLabel: 'Suspendre' },
    reactivate: { title: "Réactiver l'utilisateur", confirmLabel: 'Réactiver' },
    ban: { title: "Bannir l'utilisateur", confirmLabel: 'Bannir', danger: true },
    delete: { title: "Supprimer l'utilisateur", confirmLabel: 'Supprimer', danger: true, requireText: user.name },
  };

  return (
    <Drawer open title={user.name} onClose={onClose}>
      <div style={{ display: 'grid', gap: 20 }}>
        {error && <p style={{ color: 'var(--red)' }}>{error}</p>}

        <section style={{ display: 'grid', gap: 8 }}>
          <div style={{ display: 'flex', gap: 8 }}>
            <Badge tone={roleTone[user.role as keyof typeof roleTone] ?? 'neutral'}>{user.role}</Badge>
            <Badge dot tone={statusTone[user.status as keyof typeof statusTone] ?? 'neutral'}>
              {statusLabel[user.status] ?? user.status}
            </Badge>
          </div>
          <div style={{ fontSize: 13, color: 'var(--text-sec)' }}>{user.email ?? user.phone ?? '—'}</div>
          <div style={{ fontSize: 13, color: 'var(--text-sec)' }}>ID <code>{user.id}</code></div>
          <div style={{ fontSize: 13, color: 'var(--text-sec)' }}>
            Dernière connexion : <span className="mono">{user.lastLoginAt ? new Date(user.lastLoginAt).toLocaleString('fr-FR') : 'jamais'}</span>
          </div>
        </section>

        <section>
          <h3 style={{ fontSize: 14, margin: '0 0 8px' }}>Portefeuille</h3>
          {wallet ? (
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 8 }}>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-sec)' }}>Points confirmés</div>
                <div className="mono" style={{ fontSize: 16 }}>{wallet.pointsTotal}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-sec)' }}>En attente</div>
                <div className="mono" style={{ fontSize: 16 }}>{wallet.pointsPending}</div>
              </div>
              <div>
                <div style={{ fontSize: 11, color: 'var(--text-sec)' }}>FCFA</div>
                <div className="mono" style={{ fontSize: 16 }}>{wallet.balanceFcfa.toLocaleString('fr-FR')}</div>
              </div>
            </div>
          ) : <EmptyState title="Chargement…" />}
        </section>

        <section>
          <h3 style={{ fontSize: 14, margin: '0 0 8px' }}>Historique du solde</h3>
          {ledger.length === 0 ? <EmptyState title="Aucun mouvement" /> : (
            <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 4, maxHeight: 200, overflowY: 'auto' }}>
              {ledger.map((l) => (
                <li key={l.id} className="mono" style={{ fontSize: 12, color: l.delta >= 0 ? 'var(--green)' : 'var(--red)' }}>
                  {l.delta >= 0 ? '+' : ''}{l.delta} {l.reason}
                </li>
              ))}
            </ul>
          )}
        </section>

        <section>
          <h3 style={{ fontSize: 14, margin: '0 0 8px' }}>Activité</h3>
          {activity.length === 0 ? <EmptyState title="Aucune activité" /> : (
            <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 6, fontSize: 13 }}>
              {activity.map((e) => (
                <li key={e.id}>
                  <span className="mono" style={{ color: 'var(--text-sec)' }}>{new Date(e.createdAt).toLocaleString('fr-FR')}</span>
                  {' '}<strong>{e.action}</strong>
                  {e.reason && <> — « {e.reason} »</>}
                </li>
              ))}
            </ul>
          )}
        </section>

        {!readOnly && (
          <section>
            <h3 style={{ fontSize: 14, margin: '0 0 8px' }}>Actions</h3>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
              {user.role === 'contributor' && (
                <Button variant="outline" onClick={() => setAction('promote')}>Promouvoir validateur</Button>
              )}
              {user.role === 'validator' && (
                <Button variant="outline" onClick={() => setAction('demote')}>Rétrograder contributeur</Button>
              )}
              <Button variant="outline" onClick={() => setAdjustOpen(true)}>Ajuster le solde</Button>
              {user.status === 'active'
                ? <Button variant="outline" onClick={() => setAction('suspend')}>Suspendre</Button>
                : <Button variant="outline" onClick={() => setAction('reactivate')}>Réactiver</Button>}
              {user.status !== 'banned' && (
                <Button variant="danger" onClick={() => setAction('ban')}>Bannir</Button>
              )}
              <Button variant="danger" onClick={() => setAction('delete')}>Supprimer</Button>
            </div>
          </section>
        )}
      </div>

      <ReasonModal
        open={action !== null}
        title={action ? actionConfig[action].title : ''}
        confirmLabel={action ? actionConfig[action].confirmLabel : ''}
        danger={action ? actionConfig[action].danger : false}
        requireText={action ? actionConfig[action].requireText : undefined}
        onConfirm={runAction}
        onClose={() => setAction(null)}
      />
      <AdjustBalanceModal open={adjustOpen} onClose={() => setAdjustOpen(false)} onConfirm={adjust} />
    </Drawer>
  );
}
