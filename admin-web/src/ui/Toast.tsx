import { createContext, useCallback, useContext, useEffect, useRef, useState, type ReactNode } from 'react';

type Toast = { id: number; msg: string; tone: 'ok' | 'error' };
const Ctx = createContext<{ push: (msg: string, tone?: Toast['tone']) => void }>({ push: () => {} });
export const useToast = () => useContext(Ctx);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const timers = useRef<Set<ReturnType<typeof setTimeout>>>(new Set());
  useEffect(() => {
    const pending = timers.current;
    return () => { pending.forEach(clearTimeout); pending.clear(); };
  }, []);
  const push = useCallback((msg: string, tone: Toast['tone'] = 'ok') => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, msg, tone }]);
    const timer = setTimeout(() => {
      timers.current.delete(timer);
      setToasts((t) => t.filter((x) => x.id !== id));
    }, 4000);
    timers.current.add(timer);
  }, []);
  return (
    <Ctx.Provider value={{ push }}>
      {children}
      <div aria-live="polite" style={{ position: 'fixed', bottom: 20, right: 20, display: 'grid', gap: 8, zIndex: 200 }}>
        {toasts.map((t) => (
          <div key={t.id} className="card" style={{
            padding: '10px 16px', borderColor: t.tone === 'error' ? 'var(--red)' : 'var(--green)',
            color: t.tone === 'error' ? 'var(--red)' : 'var(--text)', fontSize: 13,
          }}>
            {t.msg}
          </div>
        ))}
      </div>
    </Ctx.Provider>
  );
}
