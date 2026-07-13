import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useNavigate } from 'react-router-dom';
import { adminApi, setToken } from '../api';
import { Field } from '../ui/Field';
import { Button } from '../ui/Button';

const DIGITS = 6;

// Auth admin asymétrique (décision 3) : mot de passe PUIS TOTP.
export function Login() {
  const nav = useNavigate();
  const [step, setStep] = useState<'password' | 'totp'>('password');
  const [email, setEmail] = useState('admin@sabidata.bf');
  const [password, setPassword] = useState('');
  const [challenge, setChallenge] = useState('');
  const [code, setCode] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const codeInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    if (step === 'totp') codeInputRef.current?.focus();
  }, [step]);

  const submitPassword = async (e: FormEvent) => {
    e.preventDefault();
    setError(null);
    setBusy(true);
    try {
      const r = await adminApi.login(email, password);
      setChallenge(r.challenge);
      setCode('');
      setStep('totp');
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setBusy(false);
    }
  };

  const verifyTotp = async (value: string) => {
    if (busy || value.length !== DIGITS) return;
    setError(null);
    setBusy(true);
    try {
      const r = await adminApi.totp(challenge, value);
      setToken(r.access);
      nav('/');
    } catch (err) {
      setError((err as Error).message);
      setCode('');
    } finally {
      setBusy(false);
    }
  };

  const submitTotp = (e: FormEvent) => {
    e.preventDefault();
    void verifyTotp(code);
  };

  const onCodeChange = (raw: string) => {
    const digits = raw.replace(/\D/g, '').slice(0, DIGITS);
    setCode(digits);
    if (digits.length === DIGITS) void verifyTotp(digits);
  };

  return (
    <div style={{ minHeight: '100vh', display: 'grid', placeItems: 'center', background: 'var(--bg)' }}>
      <div className="card" style={{ width: 380 }}>
        <h1 style={{ fontSize: 22, margin: '0 0 4px' }}>
          Sabi<span style={{ color: 'var(--accent)' }}>Data</span> Admin
        </h1>
        <p style={{ color: 'var(--text-sec)', fontSize: 13, margin: '0 0 18px', display: 'flex', gap: 6 }}>
          <span style={{ color: step === 'password' ? 'var(--accent)' : 'var(--text-sec)', fontWeight: step === 'password' ? 700 : 400 }}>
            1. Identifiants
          </span>
          <span>→</span>
          <span style={{ color: step === 'totp' ? 'var(--accent)' : 'var(--text-sec)', fontWeight: step === 'totp' ? 700 : 400 }}>
            2. Code TOTP
          </span>
        </p>

        {step === 'password' ? (
          <form onSubmit={submitPassword} style={{ display: 'grid', gap: 14 }}>
            <Field label="Email">
              <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} autoFocus />
            </Field>
            <Field label="Mot de passe">
              <input type="password" value={password} onChange={(e) => setPassword(e.target.value)} />
            </Field>
            <Button type="submit" loading={busy} disabled={!email || !password}>Continuer</Button>
          </form>
        ) : (
          <form onSubmit={submitTotp} style={{ display: 'grid', gap: 10 }}>
            <div style={{ position: 'relative', display: 'flex', gap: 8, justifyContent: 'center' }}>
              <input
                ref={codeInputRef}
                value={code}
                onChange={(e) => onCodeChange(e.target.value)}
                onPaste={(e) => {
                  e.preventDefault();
                  onCodeChange(e.clipboardData.getData('text'));
                }}
                inputMode="numeric"
                maxLength={DIGITS}
                autoFocus
                aria-label="Code à 6 chiffres"
                style={{
                  position: 'absolute', inset: 0, width: '100%', height: '100%',
                  opacity: 0, padding: 0, margin: 0, border: 'none',
                }}
              />
              {Array.from({ length: DIGITS }).map((_, i) => {
                const current = i === Math.min(code.length, DIGITS - 1);
                return (
                  <div
                    key={i}
                    className="mono"
                    style={{
                      width: 44, height: 52, display: 'grid', placeItems: 'center', fontSize: 20,
                      borderRadius: 'var(--radius-ctl)', background: 'var(--surface-hi)',
                      border: `1px solid ${current ? 'var(--accent)' : 'var(--border)'}`,
                    }}
                  >
                    {code[i] ?? ''}
                  </div>
                );
              })}
            </div>
            <p style={{ color: 'var(--text-sec)', fontSize: 12, textAlign: 'center', margin: 0 }}>
              Code à 6 chiffres de votre application d'authentification (Google Authenticator, Aegis…)
            </p>
            <Button type="submit" loading={busy} disabled={code.length !== DIGITS}>Vérifier</Button>
          </form>
        )}

        {error && <p style={{ color: 'var(--red)', fontSize: 13, marginTop: 12, marginBottom: 0 }}>{error}</p>}
      </div>
    </div>
  );
}
