import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it, vi } from 'vitest';
import { Users } from './Users';
import { ToastProvider } from '../ui/Toast';

const usersPayload = {
  users: [
    { id: 'u1', name: 'Awa', role: 'contributor', competence: 0, status: 'active', email: null, phone: '70000001', balanceFcfa: 2500, lastLoginAt: null },
    { id: 'u2', name: 'Ali', role: 'validator', competence: 2, status: 'banned', email: null, phone: '70000002', balanceFcfa: 0, lastLoginAt: null },
  ],
};

function mockFetch() {
  return vi.fn(async (url: RequestInfo | URL) => {
    if (String(url).startsWith('/admin/users')) return new Response(JSON.stringify(usersPayload), { status: 200 });
    return new Response('{}', { status: 200 });
  });
}

describe('page Utilisateurs', () => {
  it('liste, filtre par statut et par recherche', async () => {
    vi.stubGlobal('fetch', mockFetch());
    render(<ToastProvider><MemoryRouter><Users /></MemoryRouter></ToastProvider>);
    await waitFor(() => expect(screen.getByText('Awa')).toBeInTheDocument());
    expect(screen.getByText('Ali')).toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText(/statut/i), 'banned');
    expect(screen.queryByText('Awa')).not.toBeInTheDocument();
    await userEvent.selectOptions(screen.getByLabelText(/statut/i), 'tous');
    await userEvent.type(screen.getByPlaceholderText(/rechercher/i), 'awa');
    expect(screen.getByText('Awa')).toBeInTheDocument();
    expect(screen.queryByText('Ali')).not.toBeInTheDocument();
  });
});
