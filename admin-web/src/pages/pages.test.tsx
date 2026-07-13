import { render, screen } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import App from '../App';
import { setToken } from '../api';

describe('garde de route', () => {
  it('sans token, redirige vers /login', () => {
    setToken(null);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(new Response('{}', { status: 200 })));
    render(<App />);
    expect(screen.getByText(/mot de passe/i)).toBeInTheDocument();
  });
});
