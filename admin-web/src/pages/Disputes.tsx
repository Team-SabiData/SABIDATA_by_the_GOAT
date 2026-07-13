import { useCallback, useEffect, useState } from 'react';
import { adminApi, type Dispute } from '../api';
import { Card } from '../ui/Card';
import { Badge } from '../ui/Badge';
import { Button } from '../ui/Button';
import { DataTable, type Column } from '../ui/DataTable';
import { ReasonModal } from '../ui/Modal';
import { useToast } from '../ui/Toast';
import { useCounts } from '../AppShell';

type Verdict = 'validated' | 'rejected';

export function Disputes() {
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [playingId, setPlayingId] = useState<string | null>(null);
  const [audioUrl, setAudioUrl] = useState<string | null>(null);
  const [arbitrating, setArbitrating] = useState<{ id: string; verdict: Verdict } | null>(null);
  const { push } = useToast();
  const { reload: reloadCounts } = useCounts();

  const load = useCallback(() => {
    void adminApi.disputes().then((d) => setDisputes(d.disputes)).catch((e) => setError((e as Error).message));
  }, []);

  useEffect(() => { load(); }, [load]);

  // Révoque l'object URL précédent dès qu'on en obtient un nouveau, et au démontage.
  useEffect(() => () => {
    if (audioUrl) URL.revokeObjectURL(audioUrl);
  }, [audioUrl]);

  const listen = async (id: string) => {
    setPlayingId(id);
    try {
      const url = await adminApi.fetchClipAudio(id);
      setAudioUrl(url);
      new Audio(url).play();
    } catch (e) {
      push((e as Error).message, 'error');
    } finally {
      setPlayingId(null);
    }
  };

  const confirmArbitrate = async (reason: string) => {
    if (!arbitrating) return;
    await adminApi.arbitrate(arbitrating.id, arbitrating.verdict, reason);
    load();
    reloadCounts();
    push('Arbitrage enregistré');
  };

  const columns: Column<Dispute>[] = [
    { key: 'id', label: 'Litige', render: (d) => <code>{d.id.slice(0, 8)}</code> },
    { key: 'durationS', label: 'Durée', render: (d) => `${d.durationS}s` },
    { key: 'rarity', label: 'Rareté', render: (d) => <Badge tone="blue">{d.rarity}</Badge> },
    {
      key: 'listen',
      label: 'Audio',
      render: (d) => (
        <Button variant="outline" loading={playingId === d.id} onClick={() => listen(d.id)}>
          ▶ Écouter
        </Button>
      ),
    },
    {
      key: 'arbitrage',
      label: 'Arbitrage',
      render: (d) => (
        <div style={{ display: 'flex', gap: 8 }}>
          <Button
            variant="primary"
            style={{ background: 'var(--green)' }}
            onClick={() => setArbitrating({ id: d.id, verdict: 'validated' })}
          >
            Valider
          </Button>
          <Button variant="danger" onClick={() => setArbitrating({ id: d.id, verdict: 'rejected' })}>
            Rejeter
          </Button>
        </div>
      ),
    },
  ];

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <h1 style={{ fontSize: 22, margin: 0 }}>Litiges</h1>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <Card title="Litiges à arbitrer">
        <DataTable columns={columns} rows={disputes} rowKey={(d) => d.id} emptyTitle="Aucun litige" />
      </Card>
      <ReasonModal
        open={arbitrating !== null}
        title="Arbitrer le litige"
        description={
          arbitrating?.verdict === 'validated'
            ? 'Le clip sera validé malgré le litige.'
            : 'Le clip sera rejeté et retiré du corpus.'
        }
        confirmLabel={arbitrating?.verdict === 'validated' ? 'Valider' : 'Rejeter'}
        danger={arbitrating?.verdict === 'rejected'}
        onConfirm={confirmArbitrate}
        onClose={() => setArbitrating(null)}
      />
    </div>
  );
}
