import { type ButtonHTMLAttributes } from 'react';

const styles = {
  primary: { background: 'var(--accent)', color: '#0C1020', border: 'none' },
  outline: { background: 'transparent', color: 'var(--text)', border: '1px solid var(--border)' },
  danger: { background: 'transparent', color: 'var(--red)', border: '1px solid var(--red)' },
} as const;

export function Button({
  variant = 'primary', loading = false, disabled, children, style, ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & { variant?: keyof typeof styles; loading?: boolean }) {
  const off = disabled || loading;
  return (
    <button
      {...rest}
      disabled={off}
      style={{
        ...styles[variant], padding: '9px 16px', borderRadius: 'var(--radius-ctl)',
        fontWeight: 700, opacity: off ? 0.55 : 1, ...style,
      }}
    >
      {loading ? '…' : children}
    </button>
  );
}
