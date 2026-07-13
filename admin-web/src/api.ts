// Client API admin. Le jeton (audience 'admin') est persisté en sessionStorage
// (clé sabidata.admin.token) : survit à un refresh de page, pas à la fermeture
// de l'onglet. Tout 401 purge le token et notifie le router via onUnauthorized.
const KEY = 'sabidata.admin.token';
let token: string | null = sessionStorage.getItem(KEY);
let unauthorizedCb: (() => void) | null = null;

export const setToken = (t: string | null) => {
  token = t;
  if (t) sessionStorage.setItem(KEY, t);
  else sessionStorage.removeItem(KEY);
};
export const getToken = () => token;
export const onUnauthorized = (cb: () => void) => {
  unauthorizedCb = cb;
};

// Contrat de session : TOUT 401 purge le token puis notifie le router.
function handleUnauthorized(res: Response): void {
  if (res.status === 401) {
    setToken(null);
    unauthorizedCb?.();
  }
}

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init?.headers ?? {}),
    },
  });
  handleUnauthorized(res);
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const message = (data as { error?: { message?: string } } | null)?.error?.message ?? `Erreur ${res.status}`;
    throw new Error(message);
  }
  return data as T;
}

export interface AdminUser {
  id: string;
  name: string;
  role: string;
  competence: number;
  status: string;
  email: string | null;
  phone: string | null;
  balanceFcfa: number | null;
  lastLoginAt: string | null;
}
export interface Dispute {
  id: string;
  durationS: number;
  rarity: number;
}
export interface AuditEntry {
  id: string;
  actorId: string;
  action: string;
  entityType: string;
  entityId: string;
  reason?: string;
  metadata?: Record<string, unknown>;
  createdAt: string;
}
export interface Wallet {
  pointsTotal: number;
  pointsPending: number;
  balanceFcfa: number;
  min: number;
  providers: string[];
}
export interface LedgerLine {
  id: string;
  delta: number;
  reason: string;
  state: string;
  refClipId?: string;
}
export interface Withdrawal {
  id: string;
  userId: string;
  amountFcfa: number;
  provider: string;
  status: string;
  createdAt: string;
}

export const adminApi = {
  login: (email: string, password: string) =>
    req<{ challenge: string }>('/admin/auth/login', {
      method: 'POST',
      body: JSON.stringify({ email, password }),
    }),
  totp: (challenge: string, code: string) =>
    req<{ access: string }>('/admin/auth/totp', {
      method: 'POST',
      body: JSON.stringify({ challenge, code }),
    }),
  users: () => req<{ users: AdminUser[] }>('/admin/users'),
  disputes: () => req<{ disputes: Dispute[] }>('/admin/disputes'),
  updateUser: (id: string, patch: { role?: string; competence?: number }, reason: string) =>
    req<{ id: string; role: string; competence: number }>(`/admin/users/${id}`, {
      method: 'PATCH',
      body: JSON.stringify({ ...patch, reason }),
    }),
  createUser: (input: { name: string; email?: string; phone?: string; role: string; password?: string }) =>
    req<{ id: string; name: string; role: string }>('/admin/users', { method: 'POST', body: JSON.stringify(input) }),
  deleteUser: (id: string, reason: string) =>
    req<{ id: string; status: string }>(`/admin/users/${id}`, { method: 'DELETE', body: JSON.stringify({ reason }) }),
  setUserStatus: (id: string, status: 'active' | 'suspended' | 'banned', reason: string) =>
    req<{ id: string; status: string }>(`/admin/users/${id}`, { method: 'PATCH', body: JSON.stringify({ status, reason }) }),
  userWallet: (id: string) => req<Wallet>(`/admin/users/${id}/wallet`),
  userLedger: (id: string) => req<{ entries: LedgerLine[] }>(`/admin/users/${id}/ledger`),
  userActivity: (id: string) => req<{ entries: AuditEntry[] }>(`/admin/users/${id}/activity`),
  adjust: (id: string, delta: number, reason: string) =>
    req<{ pointsTotal: number }>(`/admin/users/${id}/adjustments`, { method: 'POST', body: JSON.stringify({ delta, reason }) }),
  withdrawals: (status?: string) =>
    req<{ withdrawals: Withdrawal[] }>(`/admin/withdrawals${status ? `?status=${status}` : ''}`),
  decideWithdrawal: (id: string, decision: 'approved' | 'rejected', reason: string) =>
    req<{ status: string }>(`/admin/withdrawals/${id}/decide`, { method: 'POST', body: JSON.stringify({ decision, reason }) }),
  arbitrate: (id: string, result: 'validated' | 'rejected', reason: string) =>
    req<{ status: string; reason: string }>(`/admin/clips/${id}/arbitrate`, {
      method: 'POST',
      body: JSON.stringify({ result, reason }),
    }),
  // Audience 'mobile' requise par /api/clips/:id/audio → route admin dédiée
  // (garde content.read_any) qui rejoue le même flux audio pour les litiges.
  fetchClipAudio: async (id: string): Promise<string> => {
    const res = await fetch(`/admin/clips/${id}/audio`, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
    handleUnauthorized(res);
    if (!res.ok) throw new Error(`Audio indisponible (${res.status})`);
    return URL.createObjectURL(await res.blob());
  },
  auditLog: (filter?: { actor?: string; entity?: string; action?: string }) => {
    const qs = new URLSearchParams(
      Object.entries(filter ?? {}).filter(([, v]) => v) as [string, string][],
    ).toString();
    return req<{ entries: AuditEntry[] }>(`/admin/audit-log${qs ? `?${qs}` : ''}`);
  },
};
