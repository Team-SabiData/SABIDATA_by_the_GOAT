# Refonte panel admin « Salle de contrôle » — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Transformer l'admin-web en back-office complet (utilisateurs, argent, retraits, audit) avec les extensions backend nécessaires, chaque action motivée et journalisée.

**Architecture:** Backend d'abord (statut utilisateur + AdminService + routes argent/retraits + événements de connexion, sur le port `Repo` existant et l'`audit_log` immuable), puis frontend (react-router + coquille à barre latérale + bibliothèque `src/ui/` sur tokens CSS + 6 pages). Le ledger reste append-only ; toute écriture admin exige un motif.

**Tech Stack:** Backend Fastify/TS existant (node:test + app.inject). Frontend React 18/Vite + react-router-dom, @fontsource (Inter, JetBrains Mono), Vitest + Testing Library.

**Spec:** `docs/superpowers/specs/2026-07-05-admin-panel-redesign-design.md`

## Global Constraints

- Identité « Salle de contrôle » : sombre (`#0C1020` fond), accent orange `#F5A624`, statuts vert `#2BC49A` / rouge `#E84040` / bleu `#4A9EF5`, rouge = danger uniquement. Rayons : cartes 14, contrôles 10, pills 999. Typo : Inter (UI), JetBrains Mono tabulaire (argent, dates, ids). Aucun CDN (fonts via @fontsource).
- **Aucune écriture admin sans motif** : requis côté UI (Modal) ET backend (400 `REASON_REQUIRED` sinon).
- **Ledger append-only** : jamais d'update/delete de ligne ; un ajustement/refus de retrait = nouvelle ligne.
- **Garde-fous backend** : pas d'action de statut/suppression sur soi-même ; jamais supprimer/bannir/rétrograder le dernier admin actif.
- Suppression = douce anonymisée (`status='deleted'`, nom « Utilisateur supprimé », email/phone effacés, ledger/audit intacts).
- Statuts utilisateur : `'active' | 'suspended' | 'banned' | 'deleted'` — un non-actif ne peut pas se connecter (mobile ni admin).
- Toute connexion réussie écrit un événement `login` dans l'audit_log (metadata.channel `mobile|admin`).
- Textes UI en français. Pas de `window.prompt`/`alert`.
- Après chaque tâche backend : `cd backend && npx tsc --noEmit && node --test --import tsx src/*.test.ts` vert. Après chaque tâche frontend : `cd admin-web && npm run build` (tsc+vite) et `npx vitest run` verts.
- Chemins relatifs à `/home/r_ghost/Projets/data/SABIDATA`.

---

### Task 1: Commit de base de l'existant non versionné

**Files:** aucun changement de code — mise sous git de `admin-web/`, `backend/src/{auth,authz,curation,http,routes,db/pglite.ts,domain/roles.ts,errors.ts,services/*,tsconfig.json}`, tests backend, `docs/backend/`.

- [ ] **Step 1: Vérifier l'inventaire**

Run: `git status --short | grep '^??'`
Expected: `admin-web/`, `backend/src/...`, `docs/backend/` listés (pas de fichiers de build/node_modules — vérifier `.gitignore` les couvre).

- [ ] **Step 2: Vérifier que la suite backend passe avant de committer**

Run: `cd backend && npx tsc --noEmit && node --test --import tsx src/*.test.ts 2>&1 | tail -3`
Expected: compilation OK, tous les tests verts (~35).

- [ ] **Step 3: Commit**

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web backend/src backend/tsconfig.json docs/backend
git commit -m "chore: met sous git l'existant admin-web + backend (auth, authz, routes, tests, docs)"
```

Ne PAS ajouter `.claude/` ni les répertoires de build.

---

### Task 2: Statut utilisateur + extensions du port Repo (ledger, retraits)

**Files:**
- Modify: `backend/src/domain/contribution.ts` (LedgerReason étendu + type Withdrawal)
- Modify: `backend/src/ports/repo.ts` (UserRecord.status, updateUser étendu, retraits, listAudit.action)
- Modify: `backend/src/ports/pgRepo.ts` (mêmes extensions côté PGlite)
- Create: `backend/src/adminRepo.test.ts`

**Interfaces:**
- Consumes: types existants (`Role`, `LedgerEntry`, `AuditEntry`).
- Produces:
  - `type UserStatus = 'active' | 'suspended' | 'banned' | 'deleted'` (exporté de `ports/repo.ts`) ; `UserRecord.status?: UserStatus` (absent = `active`).
  - `LedgerReason` étendu : `'record' | 'validate' | 'transcribe' | 'convert' | 'admin_adjustment' | 'withdrawal_refund'`.
  - `interface Withdrawal { id: string; userId: string; amountFcfa: number; provider: string; status: 'processing' | 'paid' | 'failed'; createdAt: Date }` (dans `domain/contribution.ts`).
  - Repo : `updateUser(id, patch: { role?; competence?; status?: UserStatus; name?: string; email?: string | null; phone?: string | null; passwordHash?: string | null; totpSecret?: string | null })` ; `createWithdrawal(w: Omit<Withdrawal,'id'|'createdAt'|'status'>): Promise<Withdrawal>` ; `listWithdrawals(status?: Withdrawal['status']): Promise<Withdrawal[]>` ; `getWithdrawal(id): Promise<Withdrawal | null>` ; `setWithdrawalStatus(id, status: 'paid' | 'failed'): Promise<void>` ; `listAudit(filter?: { actorId?; entityId?; action?: string })`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `backend/src/adminRepo.test.ts`:

```ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { InMemoryRepo } from './ports/repo';

test('updateUser applique status et anonymisation', async () => {
  const repo = new InMemoryRepo();
  const u = await repo.createUser({
    name: 'Awa', role: 'contributor', competence: 0,
    phone: '70000001', phoneVerified: true,
  });
  await repo.updateUser(u.id, { status: 'suspended' });
  assert.equal((await repo.findUserById(u.id))?.status, 'suspended');

  await repo.updateUser(u.id, { status: 'deleted', name: 'Utilisateur supprimé', email: null, phone: null });
  const del = await repo.findUserById(u.id);
  assert.equal(del?.status, 'deleted');
  assert.equal(del?.name, 'Utilisateur supprimé');
  assert.equal(del?.phone, undefined);
});

test('retraits : create → list par statut → décision', async () => {
  const repo = new InMemoryRepo();
  const u = await repo.createUser({ name: 'Ali', role: 'contributor', competence: 0, phone: '70000002', phoneVerified: true });
  const w = await repo.createWithdrawal({ userId: u.id, amountFcfa: 1000, provider: 'orange_money' });
  assert.equal(w.status, 'processing');
  assert.equal((await repo.listWithdrawals('processing')).length, 1);
  await repo.setWithdrawalStatus(w.id, 'paid');
  assert.equal((await repo.getWithdrawal(w.id))?.status, 'paid');
  assert.equal((await repo.listWithdrawals('processing')).length, 0);
});

test('listAudit filtre par action', async () => {
  const repo = new InMemoryRepo();
  await repo.addAudit({ actorId: 'u1', action: 'login', entityType: 'user', entityId: 'u1', reason: '', metadata: { channel: 'mobile' } });
  await repo.addAudit({ actorId: 'u1', action: 'user.update', entityType: 'user', entityId: 'u2', reason: 'x' });
  assert.equal((await repo.listAudit({ action: 'login' })).length, 1);
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd backend && npx tsc --noEmit; node --test --import tsx src/adminRepo.test.ts`
Expected: FAIL — `status`/`createWithdrawal`/`action` inexistants.

- [ ] **Step 3: Étendre les types du domaine**

Dans `backend/src/domain/contribution.ts` :

```ts
export type LedgerReason = 'record' | 'validate' | 'transcribe' | 'convert' | 'admin_adjustment' | 'withdrawal_refund';
```

et ajouter en fin de fichier :

```ts
// Retrait de gains (D4). status suit l'enum SQL : processing → paid | failed.
export interface Withdrawal {
  id: string;
  userId: string;
  amountFcfa: number;
  provider: string;
  status: 'processing' | 'paid' | 'failed';
  createdAt: Date;
}
```

- [ ] **Step 4: Étendre le port + InMemoryRepo**

Dans `backend/src/ports/repo.ts` :

1. Import : ajouter `Withdrawal` à l'import depuis `../domain/contribution`.
2. Après les imports :

```ts
export type UserStatus = 'active' | 'suspended' | 'banned' | 'deleted';
```

3. Dans `UserRecord`, ajouter : `status?: UserStatus; // absent = 'active'`
4. Remplacer la signature `updateUser` de l'interface par :

```ts
  updateUser(
    id: string,
    patch: {
      role?: Role;
      competence?: CompetenceLevel;
      status?: UserStatus;
      name?: string;
      email?: string | null;
      phone?: string | null;
      passwordHash?: string | null;
      totpSecret?: string | null;
    },
  ): Promise<UserRecord | null>;
```

5. Dans l'interface, section admin, ajouter :

```ts
  // — retraits —
  createWithdrawal(w: Omit<Withdrawal, 'id' | 'createdAt' | 'status'>): Promise<Withdrawal>;
  listWithdrawals(status?: Withdrawal['status']): Promise<Withdrawal[]>;
  getWithdrawal(id: string): Promise<Withdrawal | null>;
  setWithdrawalStatus(id: string, status: 'paid' | 'failed'): Promise<void>;
```

6. Étendre la signature `listAudit` (interface) : `listAudit(filter?: { actorId?: string; entityId?: string; action?: string }): Promise<AuditEntry[]>;`
7. Dans `InMemoryRepo` : ajouter le champ `private withdrawals: Withdrawal[] = [];` puis remplacer `updateUser` par :

```ts
  async updateUser(
    id: string,
    patch: {
      role?: Role;
      competence?: CompetenceLevel;
      status?: UserStatus;
      name?: string;
      email?: string | null;
      phone?: string | null;
      passwordHash?: string | null;
      totpSecret?: string | null;
    },
  ) {
    const u = this.users.find((x) => x.id === id);
    if (!u) return null;
    if (patch.role) u.role = patch.role;
    if (patch.competence !== undefined) u.competence = patch.competence;
    if (patch.status) u.status = patch.status;
    if (patch.name !== undefined) u.name = patch.name;
    if (patch.email !== undefined) u.email = patch.email ?? undefined;
    if (patch.phone !== undefined) u.phone = patch.phone ?? undefined;
    if (patch.passwordHash !== undefined) u.passwordHash = patch.passwordHash ?? undefined;
    if (patch.totpSecret !== undefined) u.totpSecret = patch.totpSecret ?? undefined;
    return u;
  }
```

et ajouter les méthodes retraits + le filtre action :

```ts
  async createWithdrawal(w: Omit<Withdrawal, 'id' | 'createdAt' | 'status'>) {
    const wd: Withdrawal = { ...w, id: this.id('w'), status: 'processing', createdAt: new Date() };
    this.withdrawals.push(wd);
    return wd;
  }
  async listWithdrawals(status?: Withdrawal['status']) {
    return this.withdrawals.filter((w) => (status ? w.status === status : true));
  }
  async getWithdrawal(id: string) {
    return this.withdrawals.find((w) => w.id === id) ?? null;
  }
  async setWithdrawalStatus(id: string, status: 'paid' | 'failed') {
    const w = this.withdrawals.find((x) => x.id === id);
    if (w) w.status = status;
  }
```

```ts
  async listAudit(filter?: { actorId?: string; entityId?: string; action?: string }) {
    return this.audit
      .filter((e) => (filter?.actorId ? e.actorId === filter.actorId : true))
      .filter((e) => (filter?.entityId ? e.entityId === filter.entityId : true))
      .filter((e) => (filter?.action ? e.action === filter.action : true));
  }
```

(import `Withdrawal` et `UserStatus` déjà en scope.)

- [ ] **Step 5: Mêmes extensions dans PgRepo**

Lire `backend/src/ports/pgRepo.ts` et appliquer le même contrat : colonne `status` (TEXT default 'active') sur users si le CREATE TABLE embarqué l'exige, `updateUser` acceptant les nouveaux champs (SET dynamique), méthodes retraits sur la table `withdrawals` (la créer dans le bootstrap SQL de pgRepo si absente : `id TEXT PRIMARY KEY, user_id TEXT, amount_fcfa INT, provider TEXT, status TEXT DEFAULT 'processing', created_at TIMESTAMPTZ DEFAULT now()`), filtre `action` dans `listAudit`. Suivre les patterns SQL existants du fichier (paramètres `$1…`, mapping snake_case→camelCase).

- [ ] **Step 6: Vérifier**

Run: `cd backend && npx tsc --noEmit && node --test --import tsx src/adminRepo.test.ts && node --test --import tsx src/pg.test.ts`
Expected: PASS (le test pg existant valide que PgRepo compile/tourne toujours).

- [ ] **Step 7: Suite complète + commit**

Run: `cd backend && node --test --import tsx src/*.test.ts 2>&1 | tail -3`
Expected: tout vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/domain/contribution.ts backend/src/ports/repo.ts backend/src/ports/pgRepo.ts backend/src/adminRepo.test.ts
git commit -m "feat(backend): statut utilisateur + retraits + ajustements dans le port Repo"
```

---

### Task 3: AdminService — statut, création, suppression douce, garde-fous

**Files:**
- Create: `backend/src/services/adminService.ts`
- Create: `backend/src/adminService.test.ts`
- Modify: `backend/src/domain/roles.ts` (permissions `wallet.read`, `wallet.adjust`)

**Interfaces:**
- Consumes: `Repo`, `Principal`, `requirePermission` (authz/can), `hashPassword` (auth/crypto), erreurs `badRequest/notFound/conflict` (`errors.ts` — vérifier les helpers exacts existants ; si seuls `notFound`/`conflict` existent, ajouter `badRequest` sur le même modèle `HttpError`).
- Produces (classe `AdminService(repo)`) :
  - `setUserStatus(p: Principal, id: string, status: 'active'|'suspended'|'banned', reason: string)`
  - `createUser(p, input: { name: string; email?: string; phone?: string; role: Role; password?: string })`
  - `deleteUser(p, id: string, reason: string)`
  - `adjustBalance(p, id: string, delta: number, reason: string)` → `{ pointsTotal: number }`
  - `decideWithdrawal(p, id: string, decision: 'approved'|'rejected', reason: string)` → `{ status: 'paid'|'failed' }`
  - Erreurs : `REASON_REQUIRED` (400), `SELF_FORBIDDEN` (409), `LAST_ADMIN` (409), `NOT_FOUND` (404), `USER_DELETED` (409), `ALREADY_DECIDED` (409), `BAD_DELTA` (400).

- [ ] **Step 1: Écrire les tests qui échouent**

Create `backend/src/adminService.test.ts`:

```ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { InMemoryRepo } from './ports/repo';
import { AdminService } from './services/adminService';
import { type Principal } from './authz/can';

const admin = (id = 'adm'): Principal => ({ userId: id, role: 'admin', competence: 3, audience: 'admin' });

async function seed(repo: InMemoryRepo) {
  const a = await repo.createUser({ name: 'Root', role: 'admin', competence: 3, email: 'root@x.bf', phoneVerified: true });
  const u = await repo.createUser({ name: 'Awa', role: 'contributor', competence: 0, phone: '70000001', phoneVerified: true });
  return { a, u };
}

test('setUserStatus exige un motif et journalise', async () => {
  const repo = new InMemoryRepo();
  const { a, u } = await seed(repo);
  const svc = new AdminService(repo);
  await assert.rejects(svc.setUserStatus(admin(a.id), u.id, 'suspended', '  '), /REASON_REQUIRED/);
  await svc.setUserStatus(admin(a.id), u.id, 'banned', 'fraude avérée');
  assert.equal((await repo.findUserById(u.id))?.status, 'banned');
  const audit = await repo.listAudit({ action: 'user.status' });
  assert.equal(audit.length, 1);
  assert.equal(audit[0].reason, 'fraude avérée');
});

test('garde-fous : pas sur soi-même, jamais le dernier admin', async () => {
  const repo = new InMemoryRepo();
  const { a, u } = await seed(repo);
  const svc = new AdminService(repo);
  await assert.rejects(svc.setUserStatus(admin(a.id), a.id, 'banned', 'x'), /SELF_FORBIDDEN/);
  await assert.rejects(svc.deleteUser(admin(a.id), a.id, 'x'), /SELF_FORBIDDEN/);
  // a est le seul admin : un 2e admin le bannit ? Non — un seul admin restant est protégé
  const b = await repo.createUser({ name: 'Adm2', role: 'admin', competence: 3, email: 'b@x.bf', phoneVerified: true });
  await svc.setUserStatus(admin(b.id), a.id, 'banned', 'compromis'); // ok : il reste b
  await assert.rejects(svc.setUserStatus(admin(a.id), b.id, 'banned', 'x'), /LAST_ADMIN/);
  void u;
});

test('deleteUser anonymise mais garde le ledger', async () => {
  const repo = new InMemoryRepo();
  const { a, u } = await seed(repo);
  await repo.addLedger({ userId: u.id, delta: 100, reason: 'record', state: 'confirmed' });
  const svc = new AdminService(repo);
  await svc.deleteUser(admin(a.id), u.id, 'demande RGPD');
  const del = await repo.findUserById(u.id);
  assert.equal(del?.status, 'deleted');
  assert.equal(del?.name, 'Utilisateur supprimé');
  assert.equal(del?.phone, undefined);
  assert.equal((await repo.ledgerFor(u.id)).length, 1); // le ledger reste
});

test('adjustBalance : ligne append-only signée + refus sur supprimé', async () => {
  const repo = new InMemoryRepo();
  const { a, u } = await seed(repo);
  const svc = new AdminService(repo);
  await assert.rejects(svc.adjustBalance(admin(a.id), u.id, 0, 'x'), /BAD_DELTA/);
  const r = await svc.adjustBalance(admin(a.id), u.id, 500, 'bonus campagne');
  assert.equal(r.pointsTotal, 500);
  const lines = await repo.ledgerFor(u.id);
  assert.equal(lines.length, 1);
  assert.equal(lines[0].reason, 'admin_adjustment');
  assert.equal(lines[0].state, 'confirmed');
  await svc.deleteUser(admin(a.id), u.id, 'x');
  await assert.rejects(svc.adjustBalance(admin(a.id), u.id, 10, 'y'), /USER_DELETED/);
});

test('decideWithdrawal : rejet re-crédite, double décision refusée', async () => {
  const repo = new InMemoryRepo();
  const { a, u } = await seed(repo);
  const svc = new AdminService(repo);
  const w = await repo.createWithdrawal({ userId: u.id, amountFcfa: 1000, provider: 'orange_money' });
  const r = await svc.decideWithdrawal(admin(a.id), w.id, 'rejected', 'numéro invalide');
  assert.equal(r.status, 'failed');
  const lines = await repo.ledgerFor(u.id);
  assert.equal(lines[0].reason, 'withdrawal_refund');
  assert.equal(lines[0].delta, 200); // 1000 FCFA / 5 (pointToFcfa) = 200 pts
  await assert.rejects(svc.decideWithdrawal(admin(a.id), w.id, 'approved', 'x'), /ALREADY_DECIDED/);
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd backend && node --test --import tsx src/adminService.test.ts`
Expected: FAIL — module inexistant.

- [ ] **Step 3: Permissions + erreurs**

Dans `backend/src/domain/roles.ts`, étendre l'union `Permission` :

```ts
  | 'wallet.read'
  | 'wallet.adjust'
```

(admin a `'*'` — rien d'autre à faire.) Dans `backend/src/errors.ts`, vérifier qu'un helper `badRequest(code)` existe ; sinon l'ajouter sur le modèle des helpers existants (`HttpError` 400).

- [ ] **Step 4: Implémenter AdminService**

Create `backend/src/services/adminService.ts`:

```ts
import { type Principal, requirePermission } from '../authz/can';
import { type Repo, type UserStatus } from '../ports/repo';
import { type Role } from '../domain/roles';
import { hashPassword } from '../auth/crypto';
import { CONFIG } from '../config';
import { badRequest, conflict, notFound } from '../errors';

// Surface ADMIN — gestion des comptes et de l'argent. Chaque écriture exige
// un motif et laisse une trace immuable dans l'audit_log. Le ledger est
// append-only : on n'édite jamais une ligne, on en ajoute.
export class AdminService {
  constructor(private readonly repo: Repo) {}

  private needReason(reason: string): string {
    const r = reason?.trim();
    if (!r) throw badRequest('REASON_REQUIRED');
    return r;
  }

  private async guardTarget(p: Principal, targetId: string): Promise<void> {
    if (p.userId === targetId) throw conflict('SELF_FORBIDDEN');
    const target = await this.repo.findUserById(targetId);
    if (!target) throw notFound('user');
    if (target.role === 'admin') {
      const admins = (await this.repo.listUsers()).filter(
        (u) => u.role === 'admin' && (u.status ?? 'active') === 'active',
      );
      if (admins.length <= 1) throw conflict('LAST_ADMIN');
    }
  }

  async setUserStatus(p: Principal, id: string, status: Exclude<UserStatus, 'deleted'>, reason: string) {
    requirePermission(p, 'user.manage');
    const r = this.needReason(reason);
    await this.guardTarget(p, id);
    const updated = await this.repo.updateUser(id, { status });
    if (!updated) throw notFound('user');
    await this.repo.addAudit({
      actorId: p.userId, action: 'user.status', entityType: 'user', entityId: id,
      reason: r, metadata: { status },
    });
    return { id, status };
  }

  async createUser(p: Principal, input: { name: string; email?: string; phone?: string; role: Role; password?: string }) {
    requirePermission(p, 'user.manage');
    if (!input.name?.trim() || (!input.email && !input.phone)) throw badRequest('BAD_INPUT');
    const user = await this.repo.createUser({
      name: input.name.trim(),
      role: input.role,
      competence: 0,
      email: input.email,
      phone: input.phone,
      passwordHash: input.password ? hashPassword(input.password) : undefined,
      phoneVerified: false,
      status: 'active',
    });
    await this.repo.addAudit({
      actorId: p.userId, action: 'user.create', entityType: 'user', entityId: user.id,
      reason: '', metadata: { role: input.role },
    });
    return { id: user.id, name: user.name, role: user.role };
  }

  async deleteUser(p: Principal, id: string, reason: string) {
    requirePermission(p, 'user.manage');
    const r = this.needReason(reason);
    await this.guardTarget(p, id);
    const updated = await this.repo.updateUser(id, {
      status: 'deleted',
      name: 'Utilisateur supprimé',
      email: null,
      phone: null,
      passwordHash: null,
      totpSecret: null,
    });
    if (!updated) throw notFound('user');
    await this.repo.addAudit({
      actorId: p.userId, action: 'user.delete', entityType: 'user', entityId: id, reason: r,
    });
    return { id, status: 'deleted' as const };
  }

  async adjustBalance(p: Principal, id: string, delta: number, reason: string) {
    requirePermission(p, 'wallet.adjust');
    const r = this.needReason(reason);
    if (!Number.isInteger(delta) || delta === 0) throw badRequest('BAD_DELTA');
    const target = await this.repo.findUserById(id);
    if (!target) throw notFound('user');
    if ((target.status ?? 'active') === 'deleted') throw conflict('USER_DELETED');
    await this.repo.addLedger({ userId: id, delta, reason: 'admin_adjustment', state: 'confirmed' });
    await this.repo.addAudit({
      actorId: p.userId, action: 'wallet.adjust', entityType: 'user', entityId: id,
      reason: r, metadata: { delta },
    });
    const ledger = await this.repo.ledgerFor(id);
    const pointsTotal = ledger.filter((e) => e.state === 'confirmed').reduce((s, e) => s + e.delta, 0);
    return { pointsTotal };
  }

  async decideWithdrawal(p: Principal, id: string, decision: 'approved' | 'rejected', reason: string) {
    requirePermission(p, 'withdrawal.settle');
    const r = this.needReason(reason);
    const w = await this.repo.getWithdrawal(id);
    if (!w) throw notFound('withdrawal');
    if (w.status !== 'processing') throw conflict('ALREADY_DECIDED');
    const status = decision === 'approved' ? ('paid' as const) : ('failed' as const);
    await this.repo.setWithdrawalStatus(id, status);
    if (status === 'failed') {
      // Refus → re-crédit append-only (FCFA reconvertis en points).
      await this.repo.addLedger({
        userId: w.userId,
        delta: Math.round(w.amountFcfa / CONFIG.pointToFcfa),
        reason: 'withdrawal_refund',
        state: 'confirmed',
      });
    }
    await this.repo.addAudit({
      actorId: p.userId, action: 'withdrawal.decide', entityType: 'withdrawal', entityId: id,
      reason: r, metadata: { decision, amountFcfa: w.amountFcfa, userId: w.userId },
    });
    return { status };
  }
}
```

Note : `createUser` n'exige pas de motif (l'action est déjà journalisée `user.create`) ; `deleteUser`/`setUserStatus`/`adjustBalance`/`decideWithdrawal` l'exigent.

- [ ] **Step 5: Vérifier**

Run: `cd backend && npx tsc --noEmit && node --test --import tsx src/adminService.test.ts`
Expected: PASS (5 tests).

- [ ] **Step 6: Suite complète + commit**

Run: `cd backend && node --test --import tsx src/*.test.ts 2>&1 | tail -3`
Expected: vert.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/services/adminService.ts backend/src/adminService.test.ts backend/src/domain/roles.ts backend/src/errors.ts
git commit -m "feat(backend): AdminService — statut, création, suppression douce, ajustements, retraits"
```

---

### Task 4: Routes admin + refus de connexion des comptes non actifs + événements login

**Files:**
- Modify: `backend/src/server.ts` (nouvelles routes /admin)
- Modify: `backend/src/routes/authRoutes.ts` (statut + audit login mobile)
- Modify: `backend/src/routes/adminAuthRoutes.ts` (statut + audit login admin)
- Create: `backend/src/adminRoutes.test.ts`

**Interfaces:**
- Consumes: `AdminService` (Task 3), `WalletService` (existant), guards existants.
- Produces (HTTP) :
  - `PATCH /admin/users/:id` accepte en plus `{ status, reason }` (route existante étendue).
  - `POST /admin/users` `{ name, email?, phone?, role, password? }` → 201 `{ id, name, role }`.
  - `DELETE /admin/users/:id` `{ reason }` → `{ id, status: 'deleted' }`.
  - `GET /admin/users/:id/wallet` → wallet ; `GET /admin/users/:id/ledger` → `{ entries }` ; `GET /admin/users/:id/activity` → `{ entries }` (audit de/sur l'utilisateur).
  - `POST /admin/users/:id/adjustments` `{ delta, reason }` → `{ pointsTotal }`.
  - `GET /admin/withdrawals?status=` → `{ withdrawals }` ; `POST /admin/withdrawals/:id/decide` `{ decision, reason }` → `{ status }`.
  - `GET /admin/users` renvoie en plus `status` et `balanceFcfa` et `lastLoginAt` (dernier événement `login` de l'audit).
  - Login mobile/admin : compte `suspended|banned|deleted` → 403 `ACCOUNT_DISABLED` ; login réussi → audit `login` (metadata.channel).

- [ ] **Step 1: Écrire les tests qui échouent**

Create `backend/src/adminRoutes.test.ts`:

```ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { buildServer, DEV_TOTP_SECRET, seedDevAdmin } from './server';
import { InMemoryRepo } from './ports/repo';
import { currentTotp } from './auth/totp';

async function adminToken(app: ReturnType<typeof buildServer>) {
  const login = await app.inject({
    method: 'POST', url: '/admin/auth/login',
    payload: { email: 'admin@sabidata.bf', password: 'admin123' },
  });
  const { challenge } = login.json() as { challenge: string };
  const totp = await app.inject({
    method: 'POST', url: '/admin/auth/totp',
    payload: { challenge, code: currentTotp(DEV_TOTP_SECRET) },
  });
  return (totp.json() as { access: string }).access;
}

test('cycle complet : créer → créditer → suspendre → login refusé → supprimer', async () => {
  const repo = new InMemoryRepo();
  await seedDevAdmin(repo);
  const app = buildServer(repo);
  const tk = await adminToken(app);
  const H = { authorization: `Bearer ${tk}` };

  // créer
  const created = await app.inject({
    method: 'POST', url: '/admin/users', headers: H,
    payload: { name: 'Awa Test', phone: '70000009', role: 'contributor' },
  });
  assert.equal(created.statusCode, 201);
  const { id } = created.json() as { id: string };

  // créditer
  const adj = await app.inject({
    method: 'POST', url: `/admin/users/${id}/adjustments`, headers: H,
    payload: { delta: 500, reason: 'bonus de lancement' },
  });
  assert.equal(adj.statusCode, 200);
  assert.equal((adj.json() as { pointsTotal: number }).pointsTotal, 500);

  // wallet + ledger visibles
  const wallet = await app.inject({ method: 'GET', url: `/admin/users/${id}/wallet`, headers: H });
  assert.equal((wallet.json() as { pointsTotal: number }).pointsTotal, 500);
  const ledger = await app.inject({ method: 'GET', url: `/admin/users/${id}/ledger`, headers: H });
  assert.equal((ledger.json() as { entries: unknown[] }).entries.length, 1);

  // suspendre sans motif → 400 ; avec motif → ok
  const noReason = await app.inject({
    method: 'PATCH', url: `/admin/users/${id}`, headers: H, payload: { status: 'suspended' },
  });
  assert.equal(noReason.statusCode, 400);
  const susp = await app.inject({
    method: 'PATCH', url: `/admin/users/${id}`, headers: H,
    payload: { status: 'suspended', reason: 'vérification en cours' },
  });
  assert.equal(susp.statusCode, 200);

  // login mobile refusé (compte suspendu) — flux OTP
  const otpReq = await app.inject({ method: 'POST', url: '/api/auth/login', payload: { phone: '70000009' } });
  assert.equal(otpReq.statusCode, 403);
  assert.match(otpReq.body, /ACCOUNT_DISABLED/);

  // supprimer (motif requis)
  const del = await app.inject({
    method: 'DELETE', url: `/admin/users/${id}`, headers: H, payload: { reason: 'demande utilisateur' },
  });
  assert.equal(del.statusCode, 200);
  const users = await app.inject({ method: 'GET', url: '/admin/users', headers: H });
  const list = (users.json() as { users: { id: string; status: string; name: string }[] }).users;
  const deleted = list.find((u) => u.id === id);
  assert.equal(deleted?.status, 'deleted');
  assert.equal(deleted?.name, 'Utilisateur supprimé');
});

test('login admin réussi écrit un événement audit login', async () => {
  const repo = new InMemoryRepo();
  await seedDevAdmin(repo);
  const app = buildServer(repo);
  const tk = await adminToken(app);
  const audit = await app.inject({
    method: 'GET', url: '/admin/audit-log?action=login', headers: { authorization: `Bearer ${tk}` },
  });
  const entries = (audit.json() as { entries: { action: string; metadata?: { channel?: string } }[] }).entries;
  assert.ok(entries.length >= 1);
  assert.equal(entries[0].metadata?.channel, 'admin');
});

test('retraits : file + décision motivée', async () => {
  const repo = new InMemoryRepo();
  await seedDevAdmin(repo);
  const u = await repo.createUser({ name: 'Ali', role: 'contributor', competence: 0, phone: '70000010', phoneVerified: true });
  const w = await repo.createWithdrawal({ userId: u.id, amountFcfa: 1500, provider: 'wave' });
  const app = buildServer(repo);
  const tk = await adminToken(app);
  const H = { authorization: `Bearer ${tk}` };

  const list = await app.inject({ method: 'GET', url: '/admin/withdrawals?status=processing', headers: H });
  assert.equal((list.json() as { withdrawals: unknown[] }).withdrawals.length, 1);

  const decide = await app.inject({
    method: 'POST', url: `/admin/withdrawals/${w.id}/decide`, headers: H,
    payload: { decision: 'approved', reason: 'virement effectué réf 123' },
  });
  assert.equal(decide.statusCode, 200);
  assert.equal((decide.json() as { status: string }).status, 'paid');
});
```

- [ ] **Step 2: Vérifier l'échec**

Run: `cd backend && node --test --import tsx src/adminRoutes.test.ts`
Expected: FAIL — routes inexistantes / statut ignoré.

- [ ] **Step 3: Statut + audit dans les routes d'auth**

Lire `backend/src/routes/authRoutes.ts`. Au point où l'utilisateur est résolu avec succès (login par téléphone → envoi OTP, et vérification OTP → émission des tokens), insérer :

```ts
if (user && (user.status ?? 'active') !== 'active') {
  return reply.code(403).send({ error: { code: 'ACCOUNT_DISABLED', message: 'Compte suspendu ou désactivé. Contactez SabiData.' } });
}
```

(avant l'envoi d'OTP ET avant l'émission de token — les deux points d'entrée). Après l'émission de tokens réussie (login/OTP vérifié, et register) :

```ts
await repo.addAudit({
  actorId: user.id, action: 'login', entityType: 'user', entityId: user.id,
  reason: '', metadata: { channel: 'mobile' },
});
```

Dans `backend/src/routes/adminAuthRoutes.ts` : dans `/login`, après résolution de l'user, refuser si `(user.status ?? 'active') !== 'active'` (mêmes code/message, 403) ; dans `/totp`, après vérification réussie et AVANT le `reply.send({ access })` :

```ts
await repo.addAudit({
  actorId: user.id, action: 'login', entityType: 'user', entityId: user.id,
  reason: '', metadata: { channel: 'admin' },
});
```

- [ ] **Step 4: Routes admin dans server.ts**

Dans `backend/src/server.ts`, bloc `/admin` : instancier `const adminSvc = new AdminService(repo);` (import depuis `./services/adminService`). Ajouter un helper local de mapping d'erreurs (mêmes patterns que l'arbitrage) :

```ts
      const sendErr = (reply: FastifyReply, e: unknown) => {
        if (e instanceof ForbiddenError) return reply.code(403).send({ error: { code: 'FORBIDDEN', message: e.perm } });
        if (e instanceof HttpError) return reply.code(e.statusCode).send({ error: { code: e.code, message: e.code } });
        throw e;
      };
```

(import `type FastifyReply` de fastify.) Puis :

1. **Étendre `GET /admin/users`** (remplacer le handler existant) :

```ts
      i.get('/users', { preHandler: requirePerm('content.read_any') }, async () => {
        const users = await repo.listUsers();
        const logins = await repo.listAudit({ action: 'login' });
        const out = [];
        for (const u of users) {
          const ledger = await repo.ledgerFor(u.id);
          const points = ledger.filter((e) => e.state === 'confirmed').reduce((s, e) => s + e.delta, 0);
          const last = logins.filter((l) => l.actorId === u.id).at(-1);
          out.push({
            id: u.id, name: u.name, role: u.role, competence: u.competence,
            status: u.status ?? 'active',
            email: u.email ?? null, phone: u.phone ?? null,
            balanceFcfa: points * CONFIG.pointToFcfa,
            lastLoginAt: last ? last.createdAt : null,
          });
        }
        return { users: out };
      });
```

2. **Étendre `PATCH /admin/users/:id`** (remplacer le handler) — rôle/compétence comme avant, mais si `status` est présent, passer par le service (motif requis + garde-fous) :

```ts
      i.patch('/users/:id', { preHandler: requirePerm('user.manage') }, async (req, reply) => {
        const { id } = req.params as { id: string };
        const body = (req.body ?? {}) as { role?: string; competence?: number; status?: string; reason?: string };
        try {
          if (body.status) {
            if (body.status !== 'active' && body.status !== 'suspended' && body.status !== 'banned') {
              return reply.code(400).send({ error: { code: 'BAD_STATUS', message: 'status ∈ {active,suspended,banned}' } });
            }
            const r = await adminSvc.setUserStatus(req.principal!, id, body.status, body.reason ?? '');
            return reply.send(r);
          }
          const updated = await repo.updateUser(id, { role: body.role as never, competence: body.competence as never });
          if (!updated) return reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'user' } });
          await repo.addAudit({
            actorId: req.principal!.userId, action: 'user.update', entityType: 'user', entityId: id,
            reason: body.reason ?? '', metadata: { role: body.role, competence: body.competence },
          });
          return { id: updated.id, role: updated.role, competence: updated.competence };
        } catch (e) { return sendErr(reply, e); }
      });
```

3. **Nouvelles routes** (dans le même bloc) :

```ts
      i.post('/users', { preHandler: requirePerm('user.manage') }, async (req, reply) => {
        const body = (req.body ?? {}) as { name?: string; email?: string; phone?: string; role?: string; password?: string };
        try {
          const r = await adminSvc.createUser(req.principal!, {
            name: body.name ?? '', email: body.email, phone: body.phone,
            role: (body.role ?? 'contributor') as never, password: body.password,
          });
          return reply.code(201).send(r);
        } catch (e) { return sendErr(reply, e); }
      });

      i.delete('/users/:id', { preHandler: requirePerm('user.manage') }, async (req, reply) => {
        const { id } = req.params as { id: string };
        const body = (req.body ?? {}) as { reason?: string };
        try { return await adminSvc.deleteUser(req.principal!, id, body.reason ?? ''); }
        catch (e) { return sendErr(reply, e); }
      });

      i.get('/users/:id/wallet', { preHandler: requirePerm('wallet.read') }, async (req, reply) => {
        const { id } = req.params as { id: string };
        if (!(await repo.findUserById(id))) return reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'user' } });
        return wallet.getWallet(id);
      });

      i.get('/users/:id/ledger', { preHandler: requirePerm('wallet.read') }, async (req) => {
        const { id } = req.params as { id: string };
        return { entries: await repo.ledgerFor(id) };
      });

      i.get('/users/:id/activity', { preHandler: requirePerm('audit.read') }, async (req) => {
        const { id } = req.params as { id: string };
        const asActor = await repo.listAudit({ actorId: id });
        const asEntity = await repo.listAudit({ entityId: id });
        const seen = new Set<string>();
        const entries = [...asActor, ...asEntity]
          .filter((e) => (seen.has(e.id) ? false : (seen.add(e.id), true)))
          .sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
        return { entries };
      });

      i.post('/users/:id/adjustments', { preHandler: requirePerm('wallet.adjust') }, async (req, reply) => {
        const { id } = req.params as { id: string };
        const body = (req.body ?? {}) as { delta?: number; reason?: string };
        try { return await adminSvc.adjustBalance(req.principal!, id, body.delta ?? 0, body.reason ?? ''); }
        catch (e) { return sendErr(reply, e); }
      });

      i.get('/withdrawals', { preHandler: requirePerm('withdrawal.settle') }, async (req) => {
        const q = req.query as { status?: 'processing' | 'paid' | 'failed' };
        const withdrawals = await repo.listWithdrawals(q.status);
        return { withdrawals };
      });

      i.post('/withdrawals/:id/decide', { preHandler: requirePerm('withdrawal.settle') }, async (req, reply) => {
        const { id } = req.params as { id: string };
        const body = (req.body ?? {}) as { decision?: string; reason?: string };
        if (body.decision !== 'approved' && body.decision !== 'rejected') {
          return reply.code(400).send({ error: { code: 'BAD_DECISION', message: 'decision ∈ {approved,rejected}' } });
        }
        try { return await adminSvc.decideWithdrawal(req.principal!, id, body.decision, body.reason ?? ''); }
        catch (e) { return sendErr(reply, e); }
      });
```

4. Étendre `GET /audit-log` pour accepter `action` : `const q = req.query as { actor?: string; entity?: string; action?: string };` et passer `action: q.action` au service/repo (étendre la signature de `GovernanceService.listAudit` en conséquence).

- [ ] **Step 5: Vérifier**

Run: `cd backend && npx tsc --noEmit && node --test --import tsx src/adminRoutes.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6: Suite complète + commit**

Run: `cd backend && node --test --import tsx src/*.test.ts 2>&1 | tail -3`
Expected: tout vert (les tests existants d'auth/security ne doivent pas casser — les comptes de test sont `status` absent = active).

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/server.ts backend/src/routes/authRoutes.ts backend/src/routes/adminAuthRoutes.ts backend/src/services/governanceService.ts backend/src/adminRoutes.test.ts
git commit -m "feat(backend): routes admin complètes (users/argent/retraits/activité) + refus comptes désactivés + audit login"
```

---

### Task 5: Frontend — dépendances, tokens, primitives (Button, Card, Badge, Field, KpiCard, EmptyState)

**Files:**
- Modify: `admin-web/package.json`, `admin-web/vite.config.ts`
- Create: `admin-web/src/ui/tokens.css`, `admin-web/src/ui/Button.tsx`, `admin-web/src/ui/Card.tsx`, `admin-web/src/ui/Badge.tsx`, `admin-web/src/ui/Field.tsx`, `admin-web/src/ui/KpiCard.tsx`, `admin-web/src/ui/EmptyState.tsx`
- Create: `admin-web/src/test/setup.ts`, `admin-web/src/ui/ui.test.tsx`
- Modify: `admin-web/src/main.tsx` (imports fonts + tokens.css)

**Interfaces:**
- Produces:
  - Tokens CSS (`:root`) : `--bg:#0C1020; --surface:#131826; --surface-hi:#1C2235; --border:#1E2840; --accent:#F5A624; --green:#2BC49A; --red:#E84040; --blue:#4A9EF5; --amber:#D9A62E; --text:#F0EDE8; --text-sec:#6B7E9E; --radius-card:14px; --radius-ctl:10px; --radius-pill:999px; --font-mono:'JetBrains Mono',monospace;` + classes utilitaires `.mono` (chiffres tabulaires), `.card`.
  - `Button({children, onClick?, variant?: 'primary'|'outline'|'danger', loading?, disabled?, type?})`
  - `Card({children, title?, actions?})` ; `Badge({children, tone: 'green'|'red'|'amber'|'blue'|'neutral', dot?})`
  - `Field({label, error?, children})` (wrapper label+erreur autour d'un input fourni)
  - `KpiCard({label, value, tone?})` ; `EmptyState({title, message?})`

- [ ] **Step 1: Dépendances + config test**

```bash
cd admin-web
npm i react-router-dom@^6.28.0 @fontsource/inter @fontsource/jetbrains-mono
npm i -D vitest@^2 jsdom @testing-library/react @testing-library/user-event @testing-library/jest-dom
```

Dans `admin-web/package.json`, ajouter le script `"test": "vitest run"`. Dans `admin-web/vite.config.ts`, ajouter la clé test (et `/// <reference types="vitest/config" />` en tête) :

```ts
  test: {
    environment: 'jsdom',
    setupFiles: './src/test/setup.ts',
    globals: true,
  },
```

Create `admin-web/src/test/setup.ts`:

```ts
import '@testing-library/jest-dom/vitest';
```

- [ ] **Step 2: Écrire le test qui échoue**

Create `admin-web/src/ui/ui.test.tsx`:

```tsx
import { render, screen, fireEvent } from '@testing-library/react';
import { describe, expect, it, vi } from 'vitest';
import { Button } from './Button';
import { Badge } from './Badge';
import { KpiCard } from './KpiCard';

describe('primitives ui', () => {
  it('Button désactivé en loading, ne déclenche pas onClick', () => {
    const onClick = vi.fn();
    render(<Button loading onClick={onClick}>Enregistrer</Button>);
    fireEvent.click(screen.getByRole('button'));
    expect(onClick).not.toHaveBeenCalled();
  });
  it('Badge rend son contenu avec le bon ton', () => {
    render(<Badge tone="red">banni</Badge>);
    expect(screen.getByText('banni')).toBeInTheDocument();
  });
  it('KpiCard affiche label et valeur', () => {
    render(<KpiCard label="Retraits à traiter" value="3" />);
    expect(screen.getByText('Retraits à traiter')).toBeInTheDocument();
    expect(screen.getByText('3')).toBeInTheDocument();
  });
});
```

Run: `cd admin-web && npx vitest run` — Expected: FAIL (modules inexistants).

- [ ] **Step 3: tokens.css + main.tsx**

Create `admin-web/src/ui/tokens.css`:

```css
:root {
  --bg: #0C1020; --surface: #131826; --surface-hi: #1C2235; --border: #1E2840;
  --accent: #F5A624; --green: #2BC49A; --red: #E84040; --blue: #4A9EF5; --amber: #D9A62E;
  --text: #F0EDE8; --text-sec: #6B7E9E;
  --radius-card: 14px; --radius-ctl: 10px; --radius-pill: 999px;
  --font-mono: 'JetBrains Mono', ui-monospace, monospace;
}
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--text); font-family: 'Inter', system-ui, sans-serif; font-size: 14px; }
.mono { font-family: var(--font-mono); font-variant-numeric: tabular-nums; }
.card { background: var(--surface); border: 1px solid var(--border); border-radius: var(--radius-card); padding: 20px; }
input, textarea, select {
  width: 100%; padding: 10px 12px; border-radius: var(--radius-ctl);
  border: 1px solid var(--border); background: var(--surface-hi); color: var(--text); font: inherit;
}
input:focus, textarea:focus, select:focus { outline: 2px solid var(--accent); outline-offset: 0; }
button { font: inherit; cursor: pointer; }
table { width: 100%; border-collapse: collapse; }
th { text-align: left; color: var(--text-sec); font-weight: 600; padding: 8px 10px; }
td { padding: 10px; border-top: 1px solid var(--border); }
a { color: var(--accent); text-decoration: none; }
```

Dans `admin-web/src/main.tsx`, ajouter en tête :

```ts
import '@fontsource/inter/400.css';
import '@fontsource/inter/600.css';
import '@fontsource/inter/700.css';
import '@fontsource/jetbrains-mono/400.css';
import '@fontsource/jetbrains-mono/600.css';
import './ui/tokens.css';
```

- [ ] **Step 4: Primitives**

Create `admin-web/src/ui/Button.tsx`:

```tsx
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
```

Create `admin-web/src/ui/Card.tsx`:

```tsx
import { type ReactNode } from 'react';

export function Card({ title, actions, children }: { title?: string; actions?: ReactNode; children: ReactNode }) {
  return (
    <section className="card">
      {(title || actions) && (
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 14 }}>
          {title && <h2 style={{ fontSize: 15, margin: 0 }}>{title}</h2>}
          <div style={{ marginLeft: 'auto' }}>{actions}</div>
        </div>
      )}
      {children}
    </section>
  );
}
```

Create `admin-web/src/ui/Badge.tsx`:

```tsx
import { type ReactNode } from 'react';

const tones = {
  green: 'var(--green)', red: 'var(--red)', amber: 'var(--amber)',
  blue: 'var(--blue)', neutral: 'var(--text-sec)',
} as const;

export function Badge({ tone, dot = false, children }: { tone: keyof typeof tones; dot?: boolean; children: ReactNode }) {
  const c = tones[tone];
  return (
    <span style={{
      display: 'inline-flex', alignItems: 'center', gap: 6, padding: '3px 10px',
      borderRadius: 'var(--radius-pill)', border: `1px solid ${c}`, color: c, fontSize: 12, fontWeight: 600,
    }}>
      {dot && <span style={{ width: 7, height: 7, borderRadius: '50%', background: c }} />}
      {children}
    </span>
  );
}
```

Create `admin-web/src/ui/Field.tsx`:

```tsx
import { type ReactNode } from 'react';

export function Field({ label, error, children }: { label: string; error?: string | null; children: ReactNode }) {
  return (
    <label style={{ display: 'grid', gap: 6 }}>
      <span style={{ fontSize: 12, fontWeight: 600, color: 'var(--text-sec)' }}>{label}</span>
      {children}
      {error && <span style={{ fontSize: 12, color: 'var(--red)' }}>{error}</span>}
    </label>
  );
}
```

Create `admin-web/src/ui/KpiCard.tsx`:

```tsx
export function KpiCard({ label, value, tone = 'var(--text)' }: { label: string; value: string | number; tone?: string }) {
  return (
    <div className="card" style={{ padding: 16 }}>
      <div className="mono" style={{ fontSize: 26, fontWeight: 700, color: tone }}>{value}</div>
      <div style={{ fontSize: 12, color: 'var(--text-sec)', marginTop: 4 }}>{label}</div>
    </div>
  );
}
```

Create `admin-web/src/ui/EmptyState.tsx`:

```tsx
export function EmptyState({ title, message }: { title: string; message?: string }) {
  return (
    <div style={{ textAlign: 'center', padding: '32px 16px', color: 'var(--text-sec)' }}>
      <div style={{ fontWeight: 600, color: 'var(--text)' }}>{title}</div>
      {message && <div style={{ fontSize: 13, marginTop: 6 }}>{message}</div>}
    </div>
  );
}
```

- [ ] **Step 5: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: 3 tests verts, build OK.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/package.json admin-web/package-lock.json admin-web/vite.config.ts admin-web/src/ui admin-web/src/test admin-web/src/main.tsx
git commit -m "feat(admin-web): tokens salle de contrôle + primitives ui + harnais vitest"
```

---

### Task 6: Frontend — Modal (motif obligatoire), Drawer, Toast, DataTable

**Files:**
- Create: `admin-web/src/ui/Modal.tsx`, `admin-web/src/ui/Drawer.tsx`, `admin-web/src/ui/Toast.tsx`, `admin-web/src/ui/DataTable.tsx`
- Create: `admin-web/src/ui/overlays.test.tsx`

**Interfaces:**
- Consumes: primitives Task 5 (`Button`, `Field`).
- Produces:
  - `ReasonModal({open, title, description?, confirmLabel, danger?, requireText?, onConfirm: (reason: string) => Promise<void> | void, onClose})` — textarea motif **obligatoire** (bouton désactivé si vide) ; si `requireText` fourni (type-to-confirm), un input doit correspondre exactement pour activer la confirmation ; Échap/backdrop ferment.
  - `Drawer({open, title, onClose, children})` — panneau latéral droit.
  - `ToastProvider` + hook `useToast(): { push: (msg: string, tone?: 'ok'|'error') => void }` (auto-dismiss 4 s).
  - `DataTable<T>({columns: { key, label, render?, width? }[], rows: T[], rowKey: (r)=>string, onRowClick?})`.

- [ ] **Step 1: Écrire le test qui échoue**

Create `admin-web/src/ui/overlays.test.tsx`:

```tsx
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
});
```

Run: `cd admin-web && npx vitest run src/ui/overlays.test.tsx` — Expected: FAIL.

- [ ] **Step 2: Implémenter Modal**

Create `admin-web/src/ui/Modal.tsx`:

```tsx
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

  useEffect(() => {
    if (open) { setReason(''); setTyped(''); setBusy(false); }
  }, [open]);

  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);

  if (!open) return null;
  const ready = reason.trim().length > 0 && (!requireText || typed === requireText) && !busy;

  const confirm = async () => {
    setBusy(true);
    try { await onConfirm(reason.trim()); onClose(); }
    finally { setBusy(false); }
  };

  return (
    <div
      onClick={onClose}
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
```

- [ ] **Step 3: Drawer, Toast, DataTable**

Create `admin-web/src/ui/Drawer.tsx`:

```tsx
import { useEffect, type ReactNode } from 'react';

export function Drawer({ open, title, onClose, children }: {
  open: boolean; title: string; onClose: () => void; children: ReactNode;
}) {
  useEffect(() => {
    if (!open) return;
    const onKey = (e: KeyboardEvent) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [open, onClose]);
  if (!open) return null;
  return (
    <div onClick={onClose} style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.45)', zIndex: 90 }}>
      <aside
        onClick={(e) => e.stopPropagation()}
        style={{
          position: 'absolute', top: 0, right: 0, bottom: 0, width: 460, maxWidth: '92vw',
          background: 'var(--surface)', borderLeft: '1px solid var(--border)', padding: 24, overflowY: 'auto',
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', marginBottom: 16 }}>
          <h2 style={{ fontSize: 17, margin: 0 }}>{title}</h2>
          <button onClick={onClose} aria-label="Fermer"
            style={{ marginLeft: 'auto', background: 'none', border: 'none', color: 'var(--text-sec)', fontSize: 18 }}>✕</button>
        </div>
        {children}
      </aside>
    </div>
  );
}
```

Create `admin-web/src/ui/Toast.tsx`:

```tsx
import { createContext, useCallback, useContext, useState, type ReactNode } from 'react';

type Toast = { id: number; msg: string; tone: 'ok' | 'error' };
const Ctx = createContext<{ push: (msg: string, tone?: Toast['tone']) => void }>({ push: () => {} });
export const useToast = () => useContext(Ctx);

export function ToastProvider({ children }: { children: ReactNode }) {
  const [toasts, setToasts] = useState<Toast[]>([]);
  const push = useCallback((msg: string, tone: Toast['tone'] = 'ok') => {
    const id = Date.now() + Math.random();
    setToasts((t) => [...t, { id, msg, tone }]);
    setTimeout(() => setToasts((t) => t.filter((x) => x.id !== id)), 4000);
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
```

Create `admin-web/src/ui/DataTable.tsx`:

```tsx
import { type ReactNode } from 'react';
import { EmptyState } from './EmptyState';

export type Column<T> = { key: string; label: string; width?: number | string; render?: (row: T) => ReactNode };

export function DataTable<T>({ columns, rows, rowKey, onRowClick, emptyTitle = 'Aucune donnée' }: {
  columns: Column<T>[]; rows: T[]; rowKey: (r: T) => string;
  onRowClick?: (r: T) => void; emptyTitle?: string;
}) {
  if (rows.length === 0) return <EmptyState title={emptyTitle} />;
  return (
    <table>
      <thead>
        <tr>{columns.map((c) => <th key={c.key} style={{ width: c.width }}>{c.label}</th>)}</tr>
      </thead>
      <tbody>
        {rows.map((r) => (
          <tr key={rowKey(r)} onClick={onRowClick ? () => onRowClick(r) : undefined}
            style={onRowClick ? { cursor: 'pointer' } : undefined}>
            {columns.map((c) => (
              <td key={c.key}>{c.render ? c.render(r) : String((r as Record<string, unknown>)[c.key] ?? '—')}</td>
            ))}
          </tr>
        ))}
      </tbody>
    </table>
  );
}
```

- [ ] **Step 4: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: tests verts, build OK.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src/ui
git commit -m "feat(admin-web): ReasonModal motif obligatoire, Drawer, Toast, DataTable"
```

---

### Task 7: Frontend — client API étendu + session

**Files:**
- Modify: `admin-web/src/api.ts`
- Create: `admin-web/src/api.test.ts`

**Interfaces:**
- Consumes: routes backend (Tasks 4).
- Produces (en plus de l'existant) :
  - Session : `setToken` persiste dans `sessionStorage` (clé `sabidata.admin.token`) ; `getToken()` la relit au boot ; `onUnauthorized(cb)` enregistré par le router — tout 401 appelle `cb` et purge le token.
  - Types : `AdminUser` étendu (`status: string; balanceFcfa: number; lastLoginAt: string | null`) ; `Wallet { pointsTotal; pointsPending; balanceFcfa; min; providers }` ; `LedgerLine { id; delta; reason; state; refClipId? }` ; `Withdrawal { id; userId; amountFcfa; provider; status; createdAt }`.
  - Méthodes : `createUser(input)`, `deleteUser(id, reason)`, `setUserStatus(id, status, reason)` (PATCH), `userWallet(id)`, `userLedger(id)`, `userActivity(id)`, `adjust(id, delta, reason)`, `withdrawals(status?)`, `decideWithdrawal(id, decision, reason)`, `auditLog({actor?, entity?, action?})`, `clipAudioUrl(id)` → chemin `/api/clips/${id}/audio` (les litiges s'écoutent avec le token en query impossible — passer par fetch+blob : `fetchClipAudio(id): Promise<string>` qui renvoie un object URL).

- [ ] **Step 1: Écrire le test qui échoue**

Create `admin-web/src/api.test.ts`:

```ts
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { adminApi, setToken, getToken, onUnauthorized } from './api';

describe('client api', () => {
  beforeEach(() => {
    sessionStorage.clear();
    vi.restoreAllMocks();
  });

  it('persiste le token en sessionStorage', () => {
    setToken('abc');
    expect(getToken()).toBe('abc');
    expect(sessionStorage.getItem('sabidata.admin.token')).toBe('abc');
    setToken(null);
    expect(sessionStorage.getItem('sabidata.admin.token')).toBeNull();
  });

  it('401 purge le token et notifie', async () => {
    setToken('abc');
    const cb = vi.fn();
    onUnauthorized(cb);
    vi.stubGlobal('fetch', vi.fn().mockResolvedValue(
      new Response(JSON.stringify({ error: { message: 'token invalide' } }), { status: 401 }),
    ));
    await expect(adminApi.users()).rejects.toThrow();
    expect(cb).toHaveBeenCalled();
    expect(getToken()).toBeNull();
  });

  it('setUserStatus envoie status + reason en PATCH', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response(JSON.stringify({ id: 'u1', status: 'banned' }), { status: 200 }));
    vi.stubGlobal('fetch', fetchMock);
    await adminApi.setUserStatus('u1', 'banned', 'fraude');
    const [url, init] = fetchMock.mock.calls[0];
    expect(url).toBe('/admin/users/u1');
    expect(init.method).toBe('PATCH');
    expect(JSON.parse(init.body)).toEqual({ status: 'banned', reason: 'fraude' });
  });
});
```

Run: `cd admin-web && npx vitest run src/api.test.ts` — Expected: FAIL.

- [ ] **Step 2: Étendre api.ts**

Dans `admin-web/src/api.ts` — remplacer la gestion de token et `req` par :

```ts
const KEY = 'sabidata.admin.token';
let token: string | null = sessionStorage.getItem(KEY);
let unauthorizedCb: (() => void) | null = null;

export const setToken = (t: string | null) => {
  token = t;
  if (t) sessionStorage.setItem(KEY, t);
  else sessionStorage.removeItem(KEY);
};
export const getToken = () => token;
export const onUnauthorized = (cb: () => void) => { unauthorizedCb = cb; };

async function req<T>(path: string, init?: RequestInit): Promise<T> {
  const res = await fetch(path, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      ...(token ? { Authorization: `Bearer ${token}` } : {}),
      ...(init?.headers ?? {}),
    },
  });
  if (res.status === 401) {
    setToken(null);
    unauthorizedCb?.();
  }
  const data = res.status === 204 ? null : await res.json().catch(() => null);
  if (!res.ok) {
    const message = (data as { error?: { message?: string } } | null)?.error?.message ?? `Erreur ${res.status}`;
    throw new Error(message);
  }
  return data as T;
}
```

Étendre les types :

```ts
export interface AdminUser {
  id: string; name: string; role: string; competence: number;
  status: string; email: string | null; phone: string | null;
  balanceFcfa: number; lastLoginAt: string | null;
}
export interface Wallet { pointsTotal: number; pointsPending: number; balanceFcfa: number; min: number; providers: string[] }
export interface LedgerLine { id: string; delta: number; reason: string; state: string; refClipId?: string }
export interface Withdrawal { id: string; userId: string; amountFcfa: number; provider: string; status: string; createdAt: string }
```

Ajouter à `adminApi` (garder l'existant) :

```ts
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
  fetchClipAudio: async (id: string): Promise<string> => {
    const res = await fetch(`/api/clips/${id}/audio`, { headers: token ? { Authorization: `Bearer ${token}` } : {} });
    if (!res.ok) throw new Error(`Audio indisponible (${res.status})`);
    return URL.createObjectURL(await res.blob());
  },
```

et étendre `auditLog` pour accepter `action` dans son filtre (même mécanique URLSearchParams).

> Note CORS/audience : `/api/clips/:id/audio` exige l'audience `mobile` côté guard. Vérifier `contributionRoutes` — si la lecture audio est gardée `authenticate('mobile')`, ajouter côté backend (Task 4 si oublié, sinon petit correctif ici) une route admin `GET /admin/clips/:id/audio` protégée `content.read_any` qui sert le même flux. Ajuster `fetchClipAudio` vers `/admin/clips/${id}/audio` dans ce cas.

- [ ] **Step 3: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src/api.ts admin-web/src/api.test.ts backend/src/server.ts
git commit -m "feat(admin-web): client api complet (statut, argent, retraits, activité) + session sessionStorage"
```

---

### Task 8: Frontend — router, AppShell, Login refait (TOTP 6 cases)

**Files:**
- Modify: `admin-web/src/App.tsx` (réécriture), `admin-web/src/pages/Login.tsx` (réécriture visuelle)
- Create: `admin-web/src/AppShell.tsx`
- Create: `admin-web/src/pages/pages.test.tsx` (premier test : login + garde de route)

**Interfaces:**
- Consumes: `getToken/setToken/onUnauthorized` (Task 7), primitives ui.
- Produces: routes `/login`, et sous `AppShell` : `/` (Overview, Task 9), `/disputes` (Task 9), `/users` (Task 10), `/money` (Task 11), `/audit` (Task 12). Chaque page à venir est enregistrée ici avec un composant placeholder `EmptyState` remplacé par sa tâche. `AppShell` expose un contexte `useCounts()` (litiges + retraits en attente, rechargés à la navigation) pour les badges de la sidebar.

- [ ] **Step 1: Réécrire App.tsx**

```tsx
import { useEffect } from 'react';
import { BrowserRouter, Navigate, Route, Routes, useNavigate } from 'react-router-dom';
import { getToken, onUnauthorized } from './api';
import { ToastProvider } from './ui/Toast';
import { AppShell } from './AppShell';
import { Login } from './pages/Login';
import { Overview } from './pages/Overview';
import { Disputes } from './pages/Disputes';
import { Users } from './pages/Users';
import { Money } from './pages/Money';
import { Audit } from './pages/Audit';

function Guard({ children }: { children: React.ReactNode }) {
  const nav = useNavigate();
  useEffect(() => onUnauthorized(() => nav('/login')), [nav]);
  if (!getToken()) return <Navigate to="/login" replace />;
  return <>{children}</>;
}

export default function App() {
  return (
    <ToastProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route element={<Guard><AppShell /></Guard>}>
            <Route path="/" element={<Overview />} />
            <Route path="/disputes" element={<Disputes />} />
            <Route path="/users" element={<Users />} />
            <Route path="/money" element={<Money />} />
            <Route path="/audit" element={<Audit />} />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </ToastProvider>
  );
}
```

Pour compiler avant les Tasks 9–12, créer chaque page manquante comme placeholder minimal (remplacé ensuite), ex. `admin-web/src/pages/Overview.tsx` :

```tsx
import { EmptyState } from '../ui/EmptyState';
export function Overview() { return <EmptyState title="Vue d'ensemble" message="À venir." />; }
```

(idem `Disputes.tsx`, `Users.tsx`, `Money.tsx`, `Audit.tsx` — chacun sera réécrit par sa tâche.)

- [ ] **Step 2: AppShell**

Create `admin-web/src/AppShell.tsx`:

```tsx
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
```

- [ ] **Step 3: Login refait**

Réécrire `admin-web/src/pages/Login.tsx` — même logique 2 étapes (`adminApi.login` → `adminApi.totp`, `setToken`), mais : navigation `useNavigate()('/')` après succès (plus de prop `onAuthed`), primitives `Field`/`Button`, indicateur d'étape (« 1. Mot de passe → 2. Code TOTP »), et l'étape TOTP en **6 cases** : même pattern que le mobile — un `<input>` invisible (opacity 0, position absolute) `maxLength={6}` `inputMode="numeric"` qui pilote 6 cases dessinées (`div` 44×52, `.mono` 20px, bordure `var(--accent)` sur la case courante) ; auto-submit quand 6 chiffres ; mention sous les cases : « Code à 6 chiffres de votre application d'authentification (Google Authenticator, Aegis…) ». Erreurs en texte rouge sous le formulaire. Conserver l'email par défaut dev `admin@sabidata.bf`.

- [ ] **Step 4: Test de garde**

Create `admin-web/src/pages/pages.test.tsx`:

```tsx
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
```

- [ ] **Step 5: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src
git commit -m "feat(admin-web): router + AppShell salle de contrôle + login TOTP à 6 cases"
```

---

### Task 9: Pages Vue d'ensemble + Litiges

**Files:**
- Modify: `admin-web/src/pages/Overview.tsx`, `admin-web/src/pages/Disputes.tsx` (remplacent les placeholders)

**Interfaces:**
- Consumes: `adminApi.users/disputes/withdrawals/auditLog/arbitrate/fetchClipAudio`, `useCounts` (badge refresh), `KpiCard/Card/DataTable/ReasonModal/Badge/EmptyState/useToast`.
- Produces: pages complètes ; les autres tâches n'en dépendent pas.

- [ ] **Step 1: Overview**

Réécrire `admin-web/src/pages/Overview.tsx` :

```tsx
import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { adminApi, type AdminUser, type AuditEntry, type Dispute, type Withdrawal } from '../api';
import { Card } from '../ui/Card';
import { KpiCard } from '../ui/KpiCard';
import { EmptyState } from '../ui/EmptyState';

export function Overview() {
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [disputes, setDisputes] = useState<Dispute[]>([]);
  const [pending, setPending] = useState<Withdrawal[]>([]);
  const [audit, setAudit] = useState<AuditEntry[]>([]);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    void Promise.all([
      adminApi.users(), adminApi.disputes(), adminApi.withdrawals('processing'), adminApi.auditLog(),
    ]).then(([u, d, w, a]) => {
      setUsers(u.users); setDisputes(d.disputes); setPending(w.withdrawals); setAudit(a.entries.slice(-5).reverse());
    }).catch((e) => setError((e as Error).message));
  }, []);

  const by = (s: string) => users.filter((u) => u.status === s).length;
  const fcfa = users.reduce((sum, u) => sum + u.balanceFcfa, 0);

  return (
    <div style={{ display: 'grid', gap: 20 }}>
      <h1 style={{ fontSize: 22, margin: 0 }}>Vue d'ensemble</h1>
      {error && <p style={{ color: 'var(--red)' }}>{error}</p>}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(150px, 1fr))', gap: 12 }}>
        <KpiCard label="Utilisateurs actifs" value={by('active')} tone="var(--green)" />
        <KpiCard label="Suspendus" value={by('suspended')} tone="var(--amber)" />
        <KpiCard label="Bannis" value={by('banned')} tone="var(--red)" />
        <KpiCard label="Litiges en attente" value={disputes.length} />
        <KpiCard label="Retraits à traiter" value={pending.length} tone="var(--accent)" />
        <KpiCard label="FCFA en circulation" value={fcfa.toLocaleString('fr-FR')} />
      </div>
      <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 20 }}>
        <Card title="À traiter">
          {disputes.length === 0 && pending.length === 0
            ? <EmptyState title="Rien à traiter" message="La pair-review absorbe le volume." />
            : (
              <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 8 }}>
                {disputes.slice(0, 5).map((d) => (
                  <li key={d.id}><Link to="/disputes">Litige <code>{d.id.slice(0, 8)}</code> · {d.durationS}s · rareté {d.rarity}</Link></li>
                ))}
                {pending.slice(0, 5).map((w) => (
                  <li key={w.id}><Link to="/money">Retrait <span className="mono">{w.amountFcfa.toLocaleString('fr-FR')} FCFA</span> · {w.provider}</Link></li>
                ))}
              </ul>
            )}
        </Card>
        <Card title="Dernières actions">
          {audit.length === 0 ? <EmptyState title="Aucune action" /> : (
            <ul style={{ margin: 0, padding: 0, listStyle: 'none', display: 'grid', gap: 8, fontSize: 13 }}>
              {audit.map((e) => (
                <li key={e.id}>
                  <span className="mono" style={{ color: 'var(--text-sec)' }}>{new Date(e.createdAt).toLocaleString('fr-FR')}</span>
                  {' '}<strong style={{ color: 'var(--accent)' }}>{e.action}</strong>
                  {e.reason && <> — « {e.reason} »</>}
                </li>
              ))}
            </ul>
          )}
        </Card>
      </div>
    </div>
  );
}
```

- [ ] **Step 2: Disputes**

Réécrire `admin-web/src/pages/Disputes.tsx` : liste des litiges en `Card`, chaque ligne avec `code` id, durée, rareté, **bouton ▶ Écouter** (au clic : `const url = await adminApi.fetchClipAudio(d.id); new Audio(url).play();` — garder l'object URL dans un state pour `URL.revokeObjectURL` au changement), et boutons `Valider` (vert) / `Rejeter` (danger) ouvrant `ReasonModal` (title « Arbitrer le litige », confirmLabel selon verdict, danger pour rejet) qui appelle `adminApi.arbitrate(id, verdict, reason)` puis recharge la liste + `useCounts().reload()` + `useToast().push('Arbitrage enregistré')`. Erreurs → `push(msg, 'error')`. État vide : `EmptyState title="Aucun litige"`.

Composant complet à écrire dans ce style exact (mêmes patterns que Overview : useState/useEffect/load async, primitives ui, aucun style en dur hors tokens).

- [ ] **Step 3: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src/pages/Overview.tsx admin-web/src/pages/Disputes.tsx
git commit -m "feat(admin-web): vue d'ensemble KPI + litiges avec écoute et arbitrage motivé"
```

---

### Task 10: Page Utilisateurs + fiche (Drawer)

**Files:**
- Modify: `admin-web/src/pages/Users.tsx` (remplace le placeholder)
- Create: `admin-web/src/pages/UserDrawer.tsx`
- Create: `admin-web/src/pages/users.test.tsx`

**Interfaces:**
- Consumes: `adminApi.users/createUser/deleteUser/setUserStatus/updateUser/userWallet/userLedger/userActivity/adjust`, ui (DataTable, Badge, ReasonModal, Drawer, Field, Button, useToast).
- Produces: `Users` (liste + création) et `UserDrawer({user, onClose, onChanged})`.

- [ ] **Step 1: Test comportemental qui échoue**

Create `admin-web/src/pages/users.test.tsx`:

```tsx
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
```

Run: `cd admin-web && npx vitest run src/pages/users.test.tsx` — Expected: FAIL.

- [ ] **Step 2: Page Users**

Réécrire `admin-web/src/pages/Users.tsx` :
- État : `users`, `q` (recherche), `statusFilter` ('tous' par défaut), `roleFilter`, `selected: AdminUser | null`, `createOpen`.
- En-tête : titre + `Button` « + Créer un utilisateur ».
- Barre de filtres : `<input placeholder="Rechercher nom ou contact…">`, `<select aria-label="Filtrer par statut">` (tous/active/suspended/banned/deleted), `<select aria-label="Filtrer par rôle">`.
- `DataTable<AdminUser>` colonnes : Nom ; Rôle (`Badge` — admin: amber, moderator: blue, validator: green, contributor: neutral) ; Statut (`Badge dot` — active: green « actif », suspended: amber « suspendu », banned: red « banni », deleted: neutral « supprimé ») ; Solde (`<span className="mono">{u.balanceFcfa.toLocaleString('fr-FR')} F</span>`) ; Dernière connexion (`mono`, date locale ou « jamais ») ; Contact. `onRowClick={setSelected}`.
- Filtrage : `users.filter(u => (statusFilter==='tous'||u.status===statusFilter) && (roleFilter==='tous'||u.role===roleFilter) && (q==='' || u.name.toLowerCase().includes(q.toLowerCase()) || (u.email??'').includes(q) || (u.phone??'').includes(q)))`.
- Création : modale maison (réutiliser la structure de `ReasonModal` mais champs `Field` name/contact/rôle/mot de passe — pas de motif requis ici) OU formulaire dans un `Drawer` ; à la soumission `adminApi.createUser(...)` → toast + reload.
- `{selected && <UserDrawer user={selected} onClose={() => setSelected(null)} onChanged={load} />}`.

- [ ] **Step 3: UserDrawer**

Create `admin-web/src/pages/UserDrawer.tsx` — dans un `Drawer(title=user.name)` :
1. **Identité** : badges rôle+statut, contact, `id` en `code`, dernière connexion.
2. **Portefeuille** (chargé via `adminApi.userWallet(user.id)`) : 3 valeurs mono (points confirmés, en attente, FCFA).
3. **Ledger** (`adminApi.userLedger`) : liste mono compacte `+150 record confirmé` (delta coloré vert/rouge), scroll max-height 200.
4. **Activité** (`adminApi.userActivity`) : liste horodatée (action + motif).
5. **Actions** (grid de `Button`) — chaque action ouvre un `ReasonModal` :
   - Promouvoir validateur / Rétrograder (selon rôle) → `adminApi.updateUser(id, {role, competence})` (motif optionnel ici : appeler directement avec confirmation simple `ReasonModal` quand même, motif journalisé).
   - Ajuster le solde : modale avec en plus un `<input type="number">` delta (validation ≠ 0) → `adminApi.adjust`.
   - Suspendre / Réactiver (selon statut) → `setUserStatus('suspended'|'active')`.
   - Bannir (danger) → `setUserStatus('banned')`.
   - Supprimer (danger, `requireText={user.name}`) → `deleteUser`.
   Après chaque succès : `useToast().push(...)`, recharger wallet/ledger/activité, `onChanged()`.
   Si `user.status === 'deleted'` : aucune action affichée (lecture seule).

- [ ] **Step 4: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src/pages/Users.tsx admin-web/src/pages/UserDrawer.tsx admin-web/src/pages/users.test.tsx
git commit -m "feat(admin-web): page utilisateurs + fiche complète (portefeuille, ledger, activité, actions)"
```

---

### Task 11: Page Argent (retraits + ajustements)

**Files:**
- Modify: `admin-web/src/pages/Money.tsx` (remplace le placeholder)

**Interfaces:**
- Consumes: `adminApi.withdrawals/decideWithdrawal/auditLog/users`, ui, `useCounts`.

- [ ] **Step 1: Implémenter Money.tsx**

Structure :
- En tête, 3 `KpiCard` : « FCFA en circulation » (somme `balanceFcfa` de `adminApi.users()`), « En attente de retrait » (somme des `processing`), « Payés » (somme des `paid`).
- Onglets (boutons `outline`/`primary` selon actif) : **Retraits** | **Ajustements**.
- **Retraits** : `DataTable<Withdrawal>` (date mono, utilisateur — résolu par id depuis la liste users, montant mono, provider, statut `Badge`) filtrée par sous-filtre statut ; pour les `processing`, colonnes d'action « Approuver » / « Refuser » ouvrant `ReasonModal` → `decideWithdrawal` → toast + reload + `useCounts().reload()`.
- **Ajustements** : `adminApi.auditLog({ action: 'wallet.adjust' })` → `DataTable` (date, acteur résolu, utilisateur cible résolu, delta depuis `metadata.delta` mono coloré, motif). Lecture seule — c'est le contrôle mutuel entre admins.
- États vides : `EmptyState`.

Composant complet dans les mêmes patterns que les pages précédentes (useState/useEffect, primitives, tokens uniquement).

- [ ] **Step 2: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add admin-web/src/pages/Money.tsx
git commit -m "feat(admin-web): page argent — retraits (file + décision motivée) et ajustements"
```

---

### Task 12: Page Audit + suppression de theme.ts

**Files:**
- Modify: `admin-web/src/pages/Audit.tsx` (remplace le placeholder)
- Delete: `admin-web/src/theme.ts` (+ purge des derniers imports)

**Interfaces:**
- Consumes: `adminApi.auditLog/users`, ui.

- [ ] **Step 1: Implémenter Audit.tsx**

- Filtres en tête : `<select>` action (toutes + valeurs distinctes rencontrées : login, user.status, user.create, user.delete, user.update, wallet.adjust, withdrawal.decide, clip.arbitrate), `<select>` acteur (résolu en noms via `adminApi.users()`), `<input type="date">` début/fin (filtrage client sur `createdAt`).
- `DataTable<AuditEntry>` : Date (mono), Acteur (nom résolu ou id tronqué), Action (`Badge` — login: blue, wallet.adjust/withdrawal.decide: amber, user.delete/user.status: red, autres: neutral), Entité (`entityType:entityId8` — si `entityType==='user'`, lien vers `/users` — simple `Link`), Motif (texte complet).
- **Export CSV** : bouton en tête —

```tsx
const exportCsv = () => {
  const head = 'date;acteur;action;entite;motif';
  const lines = filtered.map((e) =>
    [new Date(e.createdAt).toISOString(), resolveName(e.actorId), e.action, `${e.entityType}:${e.entityId}`,
     `"${(e.reason ?? '').replaceAll('"', '""')}"`].join(';'));
  const blob = new Blob([`${head}\n${lines.join('\n')}`], { type: 'text/csv;charset=utf-8' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `audit-sabidata-${new Date().toISOString().slice(0, 10)}.csv`;
  a.click();
  URL.revokeObjectURL(a.href);
};
```

- [ ] **Step 2: Purger theme.ts**

Run: `grep -rn "theme'" admin-web/src/ || true` — réécrire tout import restant vers les primitives/tokens (au terme des Tasks 8–11 il ne doit plus y en avoir), puis `git rm admin-web/src/theme.ts`.

- [ ] **Step 3: Vérifier + commit**

Run: `cd admin-web && npx vitest run && npm run build`
Expected: verts (le build échoue si un import de theme.ts subsiste — c'est le filet).

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add -A admin-web/src
git commit -m "feat(admin-web): journal d'audit filtrable + export CSV ; suppression theme.ts"
```

---

### Task 13: Vérification manuelle bout-en-bout (navigateur)

**Files:** aucun (vérification).

- [ ] **Step 1: Lancer la stack**

```bash
cd backend && DATABASE=pg RUN_SERVER=1 ./node_modules/.bin/tsx src/server.ts
# dans un autre terminal :
cd admin-web && npm run dev   # vérifier que vite.config.ts proxy /admin et /api vers :3000
```

(Si le proxy Vite n'est pas configuré, l'ajouter dans `vite.config.ts` : `server: { proxy: { '/admin': 'http://localhost:3000', '/api': 'http://localhost:3000' } }`.)

- [ ] **Step 2: Parcours complet**

1. Login : mot de passe (`admin@sabidata.bf`/`admin123`) → code TOTP affiché au boot du serveur → 6 cases → arrivée sur la Vue d'ensemble.
2. Utilisateurs : créer « Awa Test » (téléphone) → la voir dans la table.
3. Fiche Awa : ajuster +500 pts (motif) → portefeuille passe à 2 500 FCFA ; le ledger montre `admin_adjustment`.
4. Suspendre Awa (motif) → badge suspendu ; tenter le login mobile (curl `POST /api/auth/login {phone}`) → 403 ACCOUNT_DISABLED.
5. Onglet Argent : vérifier le KPI ; page Audit : retrouver login admin, user.create, wallet.adjust, user.status avec motifs ; export CSV.
6. Supprimer Awa (type-to-confirm) → nom « Utilisateur supprimé », ledger toujours visible dans la fiche (lecture seule).
7. Se déconnecter → retour login ; rafraîchir une page interne sans token → redirection login.

---

## Self-Review

**Spec coverage :**
- Commit de base de l'existant → Task 1. ✅
- Statut utilisateur + refus login (§1.1) → Tasks 2 (port) + 4 (routes/auth). ✅
- Création/suppression douce + garde-fous (§1.2) → Tasks 3 + 4. ✅
- Wallet/ledger/ajustements admin (§1.3) → Tasks 3 + 4 ; UI Task 10. ✅
- Retraits (§1.4) → Tasks 2 + 3 + 4 ; UI Task 11. ✅
- Connexions dans l'audit + activité (§1.5) → Task 4 ; UI Tasks 10/12. ✅
- Permissions RBAC (§1.6 — `wallet.read`/`wallet.adjust` ajoutées, `user.manage`/`withdrawal.settle` réutilisées : simplification assumée vs les noms du spec) → Task 3. ✅
- Router/AppShell/tokens/composants/tests front (§2) → Tasks 5–8. ✅
- Pages (§3) : login TOTP 6 cases → T8 ; overview → T9 ; litiges+écoute → T9 ; users+fiche → T10 ; argent → T11 ; audit+CSV → T12. ✅
- Sécurité §4 (motif partout, append-only, anti-lockout, sessions courtes) → Tasks 3/4 (backend), 6 (Modal), vérif T13. ✅

**Placeholders :** les pages Disputes (T9 Step 2), Users/UserDrawer (T10 Steps 2–3), Money (T11) et Audit (T12) sont décrites par structure détaillée + patterns exacts établis dans Overview (code complet fourni) et les primitives (code complet fourni) — l'implémenteur a le modèle complet d'une page et la liste exhaustive des éléments de chacune. Les briefs restent auto-suffisants.

**Type consistency :** `UserStatus` (T2) consommé T3/T4/T7 ; `Withdrawal.status 'processing'|'paid'|'failed'` cohérent T2→T4→T7→T11 ; `adminApi.setUserStatus(id, status, reason)` (T7) = contrat PATCH (T4) ; `ReasonModal(onConfirm(reason))` (T6) consommé T9/T10/T11 ; erreurs `REASON_REQUIRED/SELF_FORBIDDEN/LAST_ADMIN/ALREADY_DECIDED/BAD_DELTA/USER_DELETED` définies T3, testées T3/T4 ; `useCounts()` (T8) consommé T9/T11.


