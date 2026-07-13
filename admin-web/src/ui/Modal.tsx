import { useEffect, useState } from 'react';
import { Button } from './Button';
import { Field } from './Field';

// Toute action d'écriture admin passe ici : motif OBLIGATOIRE (tracé dans
// l'audit backend), et « type-to-confirm » pour les actions destructrices.
export function ReasonModal({
  open, title, description, confirmLabel, danger = false, requireText, onConfirm, onClose,
}: {
  open: boolean; title: string; description?: string; confirmLabel: string;
  danger?: boolean; requireText?: string;
  onConfirm: (reason: string) => Promise<void> | void; onClose: () => void;
}) {
  const [reason, setReason] = useState('');
  const [typed, setTyped] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (open) { setReason(''); setTyped(''); setBusy(false); setError(null); }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape' && !busy) onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, busy, onClose]);

  if (!open) return null;
  const ready = reason.trim().length > 0 && (!requireText || typed === requireText) && !busy;

  const confirm = async () => {
    if (busy) return;
    setBusy(true);
    setError(null);
    try {
      await onConfirm(reason.trim());
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
      <div role="dialog" aria-modal="true" aria-label={title} className="card"
        onClick={(e) => e.stopPropagation()} style={{ width: 420 }}>
        <h2 style={{ fontSize: 16, margin: '0 0 6px', color: danger ? 'var(--red)' : 'var(--text)' }}>{title}</h2>
        {description && <p style={{ color: 'var(--text-sec)', fontSize: 13, marginTop: 0 }}>{description}</p>}
        <div style={{ display: 'grid', gap: 12, marginTop: 12 }}>
          <Field label="Motif (obligatoire, journalisé)">
            <textarea rows={3} placeholder="Motif de l'action…" value={reason} onChange={(e) => setReason(e.target.value)} />
          </Field>
          {requireText && (
            <Field label={`Tapez « ${requireText} » pour confirmer`}>
              <input placeholder={requireText} value={typed} onChange={(e) => setTyped(e.target.value)} />
            </Field>
          )}
          {error && <p style={{ color: 'var(--red)', fontSize: 13, margin: 0 }}>{error}</p>}
          <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
            <Button variant="outline" onClick={onClose}>Annuler</Button>
            <Button variant={danger ? 'danger' : 'primary'} disabled={!ready} loading={busy} onClick={confirm}>
              {confirmLabel}
            </Button>
          </div>
        </div>
      </div>
    </div>
  );
}
