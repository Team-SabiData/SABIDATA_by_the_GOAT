import { render, screen, fireEvent } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { ReasonModal } from './Modal';

describe('ReasonModal', () => {
  it('refuse de confirmer sans motif', async () => {
    const onConfirm = vi.fn();
    render(<ReasonModal open title="Suspendre Awa" confirmLabel="Suspendre" onConfirm={onConfirm} onClose={() => {}} />);
    expect(screen.getByRole('button', { name: 'Suspendre' })).toBeDisabled();
    await userEvent.type(screen.getByRole('textbox'), 'vérification en cours');
    expect(screen.getByRole('button', { name: 'Suspendre' })).toBeEnabled();
    fireEvent.click(screen.getByRole('button', { name: 'Suspendre' }));
    expect(onConfirm).toHaveBeenCalledWith('vérification en cours');
  });

  it('type-to-confirm bloque tant que le texte ne correspond pas', async () => {
    const onConfirm = vi.fn();
    render(
      <ReasonModal open title="Supprimer" confirmLabel="Supprimer" danger requireText="Awa Test"
        onConfirm={onConfirm} onClose={() => {}} />,
    );
    await userEvent.type(screen.getByPlaceholderText(/motif/i), 'demande RGPD');
    expect(screen.getByRole('button', { name: 'Supprimer' })).toBeDisabled();
    await userEvent.type(screen.getByPlaceholderText('Awa Test'), 'Awa Test');
    expect(screen.getByRole('button', { name: 'Supprimer' })).toBeEnabled();
  });

  it('onConfirm en échec : modale ouverte, erreur affichée, retry possible', async () => {
    const onClose = vi.fn();
    const onConfirm = vi
      .fn()
      .mockRejectedValueOnce(new Error('Réseau indisponible'))
      .mockResolvedValueOnce(undefined);
    render(<ReasonModal open title="Suspendre" confirmLabel="Suspendre" onConfirm={onConfirm} onClose={onClose} />);
    await userEvent.type(screen.getByRole('textbox'), 'fraude suspectée');

    await userEvent.click(screen.getByRole('button', { name: 'Suspendre' }));
    expect(onConfirm).toHaveBeenCalledTimes(1);
    expect(onClose).not.toHaveBeenCalled();
    expect(await screen.findByText('Réseau indisponible')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Suspendre' })).toBeEnabled();

    await userEvent.click(screen.getByRole('button', { name: 'Suspendre' }));
    expect(onConfirm).toHaveBeenCalledTimes(2);
    expect(onClose).toHaveBeenCalledTimes(1);
  });
});
