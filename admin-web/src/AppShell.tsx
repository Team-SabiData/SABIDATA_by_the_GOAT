import { createContext, useCallback, useContext, useEffect, useState } from 'react';
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom';
import { adminApi, setToken } from './api';

const CountsCtx = createContext<{ disputes: number; withdrawals: number; reload: () => void }>({
  disputes: 0, withdrawals: 0, reload: () => {},
});
export const useCounts = () => useContext(CountsCtx);

const links = [
  { to: '/', label: 'Vue d’ensemble' },
  { to: '/disputes', label: 'Litiges', badge: 'disputes' as const },
  { to: '/users', label: 'Utilisateurs' },
  { to: '/money', label: 'Argent', badge: 'withdrawals' as const },
  { to: '/audit', label: 'Audit' },
];

export function AppShell() {
  const [counts, setCounts] = useState({ disputes: 0, withdrawals: 0 });
  const nav = useNavigate();
  const loc = useLocation();

  const reload = useCallback(() => {
    void Promise.all([adminApi.disputes(), adminApi.withdrawals('processing')])
      .then(([d, w]) => setCounts({ disputes: d.disputes.length, withdrawals: w.withdrawals.length }))
      .catch(() => {});
  }, []);
  useEffect(reload, [reload, loc.pathname]);

  return (
    <CountsCtx.Provider value={{ ...counts, reload }}>
      <div style={{ display: 'grid', gridTemplateColumns: '220px 1fr', minHeight: '100vh' }}>
        <nav style={{
          background: 'var(--surface)', borderRight: '1px solid var(--border)',
          padding: '20px 12px', display: 'flex', flexDirection: 'column', gap: 4,
        }}>
          <div style={{ padding: '4px 12px 18px', fontWeight: 700, letterSpacing: 0.4 }}>
            Sabi<span style={{ color: 'var(--accent)' }}>Data</span>
            <span style={{ display: 'block', fontSize: 11, color: 'var(--text-sec)', fontWeight: 600 }}>SALLE DE CONTRÔLE</span>
          </div>
          {links.map((l) => (
            <NavLink key={l.to} to={l.to} end={l.to === '/'}
              style={({ isActive }) => ({
                display: 'flex', alignItems: 'center', padding: '9px 12px',
                borderRadius: 'var(--radius-ctl)', color: isActive ? 'var(--accent)' : 'var(--text)',
                background: isActive ? 'var(--surface-hi)' : 'transparent',
                borderLeft: isActive ? '3px solid var(--accent)' : '3px solid transparent', fontWeight: 600,
              })}>
              {l.label}
              {l.badge && counts[l.badge] > 0 && (
                <span className="mono" style={{
                  marginLeft: 'auto', fontSize: 11, background: 'var(--accent)', color: '#0C1020',
                  borderRadius: 'var(--radius-pill)', padding: '1px 8px', fontWeight: 700,
                }}>{counts[l.badge]}</span>
              )}
            </NavLink>
          ))}
          <button
            onClick={() => { setToken(null); nav('/login'); }}
            style={{
              marginTop: 'auto', background: 'none', border: '1px solid var(--border)',
              color: 'var(--text-sec)', borderRadius: 'var(--radius-ctl)', padding: '8px 12px',
            }}>
            Se déconnecter
          </button>
        </nav>
        <main style={{ padding: '28px 32px', maxWidth: 1120 }}>
          <Outlet />
        </main>
      </div>
    </CountsCtx.Provider>
  );
}
