# Points/niveaux réels + corrections navigation — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remplacer les points/niveaux mock du mobile par des données réelles dérivées de la participation, verrouiller le retrait sous le niveau Argent, et rebrancher trois liens de navigation morts.

**Architecture:** Le backend calcule déjà les points via le ledger. On y ajoute un niveau (Bronze/Argent/Or) dérivé du nombre de contributions validées, exposé par `GET /api/me`, et une garde serveur sur le retrait. Le front consomme `/api/me`, affiche les vraies valeurs et verrouille le retrait en Bronze.

**Tech Stack:** Backend TypeScript + Fastify + node:test (via `tsx --test`). Front Flutter/Dart + go_router ; vérification par `flutter analyze` (pas de harnais de tests widget dans ce dépôt).

## Global Constraints

- Textes UI et messages d'erreur **en français** (suivre le style existant).
- Niveau = **nombre de contributions validées** : Bronze `<50`, Argent `50–199`, Or `200+`.
- « Contribution validée » = entrée ledger `state='confirmed'` de raison ∈ `{record, validate, transcribe, convert}`.
- Retrait débloqué **à partir d'Argent** (Bronze verrouillé).
- La garde de retrait est **côté serveur** (source de vérité) ; l'UI ne fait que refléter.
- Commits : convention `type(scope): description` en français (comme l'historique récent).

---

## Backend

### Task 1 : Domaine — helper de niveau + seuils config

**Files:**
- Create: `backend/src/domain/level.ts`
- Modify: `backend/src/config.ts` (bloc `CONFIG`, après `withdrawMinFcfa`)
- Test: `backend/src/level.test.ts`

**Interfaces:**
- Consumes: `CONFIG.levels`, `type LedgerEntry` de `./contribution`.
- Produces:
  - `type Level = 'bronze' | 'argent' | 'or'`
  - `levelFor(validatedCount: number): Level`
  - `meetsWithdrawLevel(level: Level): boolean`
  - `countValidatedContributions(ledger: LedgerEntry[]): number`

- [ ] **Step 1 : Ajouter les seuils dans `config.ts`**

Dans l'objet `CONFIG`, juste après la ligne `withdrawMinFcfa: 500,` :

```ts
  withdrawMinFcfa: 500,
  // Niveaux gamifiés — dérivés du nombre de contributions validées.
  levels: { argentAt: 50, orAt: 200 },
  withdrawMinLevel: 'argent' as const, // retrait verrouillé sous ce niveau
```

- [ ] **Step 2 : Écrire le test qui échoue**

Créer `backend/src/level.test.ts` :

```ts
import { test } from 'node:test';
import assert from 'node:assert';
import { levelFor, meetsWithdrawLevel, countValidatedContributions } from './domain/level';
import { type LedgerEntry } from './domain/contribution';

test('levelFor : frontières des paliers', () => {
  assert.equal(levelFor(0), 'bronze');
  assert.equal(levelFor(49), 'bronze');
  assert.equal(levelFor(50), 'argent');
  assert.equal(levelFor(199), 'argent');
  assert.equal(levelFor(200), 'or');
});

test('meetsWithdrawLevel : Bronze bloqué, Argent et Or autorisés', () => {
  assert.equal(meetsWithdrawLevel('bronze'), false);
  assert.equal(meetsWithdrawLevel('argent'), true);
  assert.equal(meetsWithdrawLevel('or'), true);
});

test('countValidatedContributions : ne compte que les entrées confirmées contributives', () => {
  const led = (reason: string, state: string): LedgerEntry =>
    ({ id: 'x', userId: 'u', delta: 10, reason: reason as never, state: state as never });
  const ledger = [
    led('record', 'confirmed'),      // +1
    led('validate', 'confirmed'),    // +1
    led('transcribe', 'confirmed'),  // +1
    led('record', 'provisional'),    // exclu (non confirmé)
    led('withdrawal', 'confirmed'),  // exclu (non contributif)
  ];
  assert.equal(countValidatedContributions(ledger), 3);
});
```

- [ ] **Step 3 : Lancer le test, vérifier l'échec**

Run: `cd backend && npx tsx --test src/level.test.ts`
Expected: FAIL (`Cannot find module './domain/level'`).

- [ ] **Step 4 : Implémenter `level.ts`**

Créer `backend/src/domain/level.ts` :

```ts
import { CONFIG } from '../config';
import { type LedgerEntry } from './contribution';

export type Level = 'bronze' | 'argent' | 'or';

const CONTRIBUTIVE = new Set(['record', 'validate', 'transcribe', 'convert']);

/** Nombre de contributions validées = entrées ledger confirmées et contributives. */
export function countValidatedContributions(ledger: LedgerEntry[]): number {
  return ledger.filter((e) => e.state === 'confirmed' && CONTRIBUTIVE.has(e.reason)).length;
}

/** Palier dérivé du nombre de contributions validées. */
export function levelFor(validatedCount: number): Level {
  if (validatedCount >= CONFIG.levels.orAt) return 'or';
  if (validatedCount >= CONFIG.levels.argentAt) return 'argent';
  return 'bronze';
}

/** Vrai si le niveau atteint le seuil de retrait (≥ Argent). */
export function meetsWithdrawLevel(level: Level): boolean {
  return level !== 'bronze';
}
```

- [ ] **Step 5 : Lancer le test, vérifier le succès**

Run: `cd backend && npx tsx --test src/level.test.ts`
Expected: PASS (3 tests).

- [ ] **Step 6 : Typecheck**

Run: `cd backend && npx tsc --noEmit`
Expected: exit 0.

- [ ] **Step 7 : Commit**

```bash
git add backend/src/domain/level.ts backend/src/config.ts backend/src/level.test.ts
git commit -m "feat(backend): helper de niveau (Bronze/Argent/Or) + seuils config"
```

---

### Task 2 : Portefeuille + `/api/me` exposent `contributionsValidated` et `level`

**Files:**
- Modify: `backend/src/services/walletService.ts` (méthode `getWallet`)
- Modify: `backend/src/server.ts:64-73` (handler `GET /me`)
- Test: `backend/src/level.test.ts` (ajout)

**Interfaces:**
- Consumes: `countValidatedContributions`, `levelFor` (Task 1).
- Produces: `getWallet` renvoie en plus `contributionsValidated: number` et `level: Level`.

- [ ] **Step 1 : Écrire le test qui échoue** (ajouter à `backend/src/level.test.ts`)

```ts
import { WalletService } from './services/walletService';
import { InMemoryRepo } from './ports/repo';

test('getWallet : renvoie contributionsValidated et level', async () => {
  const repo = new InMemoryRepo();
  const u = await repo.createUser({ name: 'Aïcha', role: 'contributor', competence: 1, status: 'active' } as never);
  for (let i = 0; i < 50; i++) {
    await repo.addLedger({ userId: u.id, delta: 10, reason: 'validate', state: 'confirmed' });
  }
  const w = await new WalletService(repo).getWallet(u.id);
  assert.equal(w.contributionsValidated, 50);
  assert.equal(w.level, 'argent');
});
```

> Note : vérifier la signature réelle de `repo.createUser` dans `backend/src/ports/repo.ts` et l'aligner (le champ exact peut différer ; suivre le patron de `seed()` dans `adminService.test.ts`).

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd backend && npx tsx --test src/level.test.ts`
Expected: FAIL (`w.contributionsValidated` = undefined).

- [ ] **Step 3 : Modifier `getWallet`**

Dans `walletService.ts`, ajouter l'import en tête :

```ts
import { countValidatedContributions, levelFor, type Level } from '../domain/level';
```

Étendre le type de retour et le corps de `getWallet` :

```ts
  async getWallet(userId: string): Promise<{
    pointsTotal: number;
    pointsPending: number;
    balanceFcfa: number;
    contributionsValidated: number;
    level: Level;
    min: number;
    providers: string[];
  }> {
    const ledger = await this.repo.ledgerFor(userId);
    const pointsTotal = ledger.filter((e) => e.state === 'confirmed').reduce((s, e) => s + e.delta, 0);
    const pointsPending = ledger.filter((e) => e.state === 'provisional').reduce((s, e) => s + e.delta, 0);
    const contributionsValidated = countValidatedContributions(ledger);
    return {
      pointsTotal,
      pointsPending,
      balanceFcfa: pointsTotal * CONFIG.pointToFcfa,
      contributionsValidated,
      level: levelFor(contributionsValidated),
      min: CONFIG.withdrawMinFcfa,
      providers: ['orange_money', 'moov_money', 'wave'],
    };
  }
```

- [ ] **Step 4 : Étendre `GET /me`** (`server.ts`, handler existant)

```ts
      i.get('/me', async (req) => {
        const uid = req.principal!.userId;
        const [user, w] = await Promise.all([repo.findUserById(uid), wallet.getWallet(uid)]);
        return {
          id:          uid,
          name:        user?.name        ?? 'Contributeur',
          role:        req.principal?.role,
          competence:  req.principal?.competence ?? 0,
          points:      w.pointsTotal,
          contributionsValidated: w.contributionsValidated,
          level:       w.level,
          phoneVerified: user?.phoneVerified ?? false,
        };
      });
```

- [ ] **Step 5 : Lancer le test + typecheck**

Run: `cd backend && npx tsx --test src/level.test.ts && npx tsc --noEmit`
Expected: PASS + exit 0.

- [ ] **Step 6 : Vérif manuelle `/me`** (backend lancé via `npm run dev`)

Run: `curl -s http://localhost:3000/api/me -H "Authorization: Bearer <token mobile>"`
Expected: le JSON contient `"contributionsValidated"` et `"level"`.

- [ ] **Step 7 : Commit**

```bash
git add backend/src/services/walletService.ts backend/src/server.ts backend/src/level.test.ts
git commit -m "feat(backend): /api/me expose contributionsValidated et level"
```

---

### Task 3 : Garde de niveau sur le retrait

**Files:**
- Modify: `backend/src/errors.ts` (ajout helper `forbidden`)
- Modify: `backend/src/services/walletService.ts` (méthode `requestWithdrawal`)
- Test: `backend/src/adminService.test.ts` (corriger le seed existant + nouveau cas)

**Interfaces:**
- Consumes: `countValidatedContributions`, `levelFor`, `meetsWithdrawLevel` (Task 1) ; `forbidden` (ce task).
- Produces: `requestWithdrawal` lève `HttpError(403, 'LEVEL_TOO_LOW')` si niveau < Argent.

- [ ] **Step 1 : Corriger le test existant + ajouter le cas Bronze** (`adminService.test.ts`)

Dans le test `'WalletService.requestWithdrawal : débite à la création…'`, **remplacer** la ligne de seed unique (`await repo.addLedger({ userId: u.id, delta: 500, reason: 'record', state: 'confirmed' });`) par une boucle de 50 contributions confirmées (utilisateur Argent, 500 pts) :

```ts
  // 50 contributions validées confirmées → niveau Argent, 500 pts (2500 FCFA)
  for (let i = 0; i < 50; i++) {
    await repo.addLedger({ userId: u.id, delta: 10, reason: 'validate', state: 'confirmed' });
  }
```

Ajouter ensuite un nouveau test dédié au verrouillage Bronze (après le test existant) :

```ts
test('WalletService.requestWithdrawal : refuse en Bronze (< 50 contributions)', async () => {
  const repo = new InMemoryRepo();
  const { u } = await seed(repo);
  const wallet = new WalletService(repo);
  // 1 seule contribution confirmée mais gros solde → Bronze, doit être bloqué
  await repo.addLedger({ userId: u.id, delta: 1000, reason: 'record', state: 'confirmed' });
  await assert.rejects(wallet.requestWithdrawal(u.id, 1000, 'orange_money'), /LEVEL_TOO_LOW/);
});
```

- [ ] **Step 2 : Lancer, vérifier l'échec**

Run: `cd backend && npx tsx --test src/adminService.test.ts`
Expected: FAIL — le nouveau test échoue (`requestWithdrawal` ne lève pas encore `LEVEL_TOO_LOW`).

- [ ] **Step 3 : Ajouter le helper `forbidden`** (`errors.ts`, après `badRequest`)

```ts
export const forbidden = (code: string) => new HttpError(403, code);
```

- [ ] **Step 4 : Ajouter la garde dans `requestWithdrawal`** (`walletService.ts`)

Mettre à jour l'import erreurs :

```ts
import { badRequest, conflict, forbidden } from '../errors';
```

Insérer la garde au tout début de `requestWithdrawal`, avant la vérification du montant :

```ts
  async requestWithdrawal(userId: string, amountFcfa: number, provider: string): Promise<Withdrawal> {
    const ledger = await this.repo.ledgerFor(userId);
    if (!meetsWithdrawLevel(levelFor(countValidatedContributions(ledger)))) throw forbidden('LEVEL_TOO_LOW');
    if (!Number.isInteger(amountFcfa) || amountFcfa < CONFIG.withdrawMinFcfa) throw badRequest('BAD_AMOUNT');
    const pointsTotal = ledger.filter((e) => e.state === 'confirmed').reduce((s, e) => s + e.delta, 0);
    const balanceFcfa = pointsTotal * CONFIG.pointToFcfa;
    if (amountFcfa > balanceFcfa) throw conflict('INSUFFICIENT_FUNDS');
    await this.repo.addLedger({
      userId,
      delta: -Math.round(amountFcfa / CONFIG.pointToFcfa),
      reason: 'withdrawal',
      state: 'confirmed',
    });
    return this.repo.createWithdrawal({ userId, amountFcfa, provider });
  }
```

Ajouter les imports niveau si absents (mutualisés avec Task 2) :

```ts
import { countValidatedContributions, levelFor, meetsWithdrawLevel, type Level } from '../domain/level';
```

- [ ] **Step 5 : Lancer toute la suite touchée**

Run: `cd backend && npx tsx --test src/adminService.test.ts src/level.test.ts && npx tsc --noEmit`
Expected: PASS (dont le test corrigé et le nouveau cas Bronze) + exit 0.

- [ ] **Step 6 : Commit**

```bash
git add backend/src/errors.ts backend/src/services/walletService.ts backend/src/adminService.test.ts
git commit -m "feat(backend): retrait verrouillé sous le niveau Argent (LEVEL_TOO_LOW)"
```

---

## Frontend

### Task 4 : `UserProfile` enrichi + `AuthApi.refreshMe()`

**Files:**
- Modify: `sabiData_frontend/lib/data/auth/auth_session.dart` (classe `UserProfile`)
- Modify: `sabiData_frontend/lib/data/api/auth_api.dart` (ajout `refreshMe`)

**Interfaces:**
- Produces: `UserProfile.points`, `.contributionsValidated`, `.level` (String) ; `AuthApi().refreshMe()` (fetch `/api/me` → `setProfile`).

- [ ] **Step 1 : Étendre `UserProfile`** (`auth_session.dart`)

Ajouter les champs et leur parsing :

```dart
class UserProfile {
  final String id;
  final String name;
  final String role;
  final int competence;
  final int points;
  final int contributionsValidated;
  final String level; // 'bronze' | 'argent' | 'or'
  const UserProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.competence,
    this.points = 0,
    this.contributionsValidated = 0,
    this.level = 'bronze',
  });

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) => UserProfile(
    id:          j['id']?.toString()          ?? '',
    name:        j['name']?.toString()        ?? 'Contributeur',
    role:        j['role']?.toString()        ?? 'contributor',
    competence:  (j['competence'] as num?)?.toInt() ?? 0,
    points:      (j['points'] as num?)?.toInt() ?? 0,
    contributionsValidated: (j['contributionsValidated'] as num?)?.toInt() ?? 0,
    level:       j['level']?.toString()       ?? 'bronze',
  );
}
```

- [ ] **Step 2 : Ajouter `refreshMe` à `AuthApi`** (`auth_api.dart`)

Ajouter la méthode (le client injecte déjà le token via `_headers()`) :

```dart
  /// Recharge le profil courant (points/niveau à jour) depuis GET /api/me.
  Future<void> refreshMe() async {
    final data = await _client.get('/api/me');
    AuthSession.instance.setProfile(Map<String, dynamic>.from(data as Map));
  }
```

- [ ] **Step 3 : Vérifier la compilation**

Run: `cd sabiData_frontend && flutter analyze lib/data/auth/auth_session.dart lib/data/api/auth_api.dart`
Expected: `No issues found` (ou uniquement des `info` préexistants).

- [ ] **Step 4 : Commit**

```bash
git add sabiData_frontend/lib/data/auth/auth_session.dart sabiData_frontend/lib/data/api/auth_api.dart
git commit -m "feat(mobile): UserProfile porte points/niveau + AuthApi.refreshMe"
```

---

### Task 5 : Helper de niveau côté front

**Files:**
- Create: `sabiData_frontend/lib/data/gamification/level.dart`

**Interfaces:**
- Consumes: `AppColors` (`../../theme/app_theme.dart`).
- Produces: `LevelInfo.of(String level, int count)` → `{ label, emoji, color, nextAt (int?), progress (double) }`.

- [ ] **Step 1 : Créer le helper** (miroir des seuils backend 50/200)

```dart
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

/// Paliers gamifiés — miroir front des seuils backend (Argent 50, Or 200).
class LevelInfo {
  final String label;
  final String emoji;
  final Color color;
  final int? nextAt;      // seuil du palier suivant (null si Or)
  final double progress;  // 0..1 vers le palier suivant

  const LevelInfo({
    required this.label,
    required this.emoji,
    required this.color,
    required this.nextAt,
    required this.progress,
  });

  static const int argentAt = 50;
  static const int orAt = 200;

  factory LevelInfo.of(String level, int validatedCount) {
    switch (level) {
      case 'or':
        return const LevelInfo(
          label: 'Gardien Or', emoji: '🥇', color: AppColors.gold,
          nextAt: null, progress: 1.0);
      case 'argent':
        return LevelInfo(
          label: 'Gardien Argent', emoji: '🥈', color: const Color(0xFF9BA3B5),
          nextAt: orAt,
          progress: ((validatedCount - argentAt) / (orAt - argentAt)).clamp(0.0, 1.0));
      default: // bronze
        return LevelInfo(
          label: 'Gardien Bronze', emoji: '🥉', color: AppColors.bronzeBadge,
          nextAt: argentAt,
          progress: (validatedCount / argentAt).clamp(0.0, 1.0));
    }
  }
}
```

- [ ] **Step 2 : Vérifier la compilation**

Run: `cd sabiData_frontend && flutter analyze lib/data/gamification/level.dart`
Expected: `No issues found`.

> Note : confirmer que `AppColors.gold` et `AppColors.bronzeBadge` existent (déjà utilisés ailleurs). Sinon, choisir la constante de couleur équivalente présente dans `app_theme.dart`.

- [ ] **Step 3 : Commit**

```bash
git add sabiData_frontend/lib/data/gamification/level.dart
git commit -m "feat(mobile): helper LevelInfo (paliers Bronze/Argent/Or)"
```

---

### Task 6 : Dashboard branché sur les vraies valeurs + fix « Parler »

**Files:**
- Modify: `sabiData_frontend/lib/screens/dashboard_screen.dart`

**Interfaces:**
- Consumes: `AuthSession.instance.user` (Task 4), `LevelInfo.of` (Task 5), `AuthApi().refreshMe()` (Task 4).

- [ ] **Step 1 : Recharger `/api/me` à l'ouverture** — dans `_loadStats()` ou `initState`, appeler le refresh (importer `../data/api/auth_api.dart`) :

```dart
  @override
  void initState() {
    super.initState();
    _loadStats();
    AuthApi().refreshMe().catchError((_) {}); // meilleure-effort : garde les valeurs connues
  }
```

- [ ] **Step 2 : Supprimer les mocks et lire le profil réel** — remplacer les lignes 51-52 :

```dart
    // (supprimer) const points = 1240; const nextLevelAt = 2000;
```

Envelopper la carte héros dans un `ValueListenableBuilder<UserProfile?>` sur `AuthSession.instance.user`, et dériver l'affichage :

```dart
    final profile = AuthSession.instance.user.value;
    final points = profile?.points ?? 0;
    final count = profile?.contributionsValidated ?? 0;
    final lvl = LevelInfo.of(profile?.level ?? 'bronze', count);
```

Dans la carte héros :
- `ProgressRing(value: lvl.progress, …)`
- Le badge de niveau : `Text(lvl.label.toUpperCase(), style: … color: lvl.color …)`
- La ligne d'objectif : `Text(lvl.nextAt == null ? 'Niveau maximum atteint' : 'Prochain palier à ${lvl.nextAt} contributions', …)`
- Le compteur : `Text('$count contributions validées', …)`
- Le centre du ProgressRing : `Text('$points', …)` (points réels)

> Suivre la structure existante lignes 96-131 ; ne changer que les valeurs, pas la mise en page (le fix overflow `childAspectRatio: 2.3` reste inchangé).

- [ ] **Step 3 : Corriger le bouton « Parler »** — ligne ~145 :

```dart
                        onTap: () => context.go('/recording'),
```

- [ ] **Step 4 : Vérifier la compilation**

Run: `cd sabiData_frontend && flutter analyze lib/screens/dashboard_screen.dart`
Expected: `No issues found` (hors `info` préexistants).

- [ ] **Step 5 : Test manuel** — hot restart (`R`), ouvrir le dashboard avec un compte neuf : **0 point, 0 contribution, Gardien Bronze, anneau vide** ; taper « Parler » → l'écran d'enregistrement s'ouvre.

- [ ] **Step 6 : Commit**

```bash
git add sabiData_frontend/lib/screens/dashboard_screen.dart
git commit -m "fix(mobile): dashboard sur données réelles (points/niveau) + Parler ouvre l'enregistrement"
```

---

### Task 7 : Écran Revenus — verrouillage retrait sous Argent

**Files:**
- Modify: `sabiData_frontend/lib/screens/revenue_screen.dart`

**Interfaces:**
- Consumes: `AuthSession.instance.user` (Task 4), `LevelInfo` (Task 5).

- [ ] **Step 1 : Dériver l'état de verrouillage** — dans `build`, lire le profil et calculer :

```dart
    final profile = AuthSession.instance.user.value;
    final count = profile?.contributionsValidated ?? 0;
    final locked = (profile?.level ?? 'bronze') == 'bronze';
    final remaining = (LevelInfo.argentAt - count).clamp(0, LevelInfo.argentAt);
```

- [ ] **Step 2 : Afficher l'état verrouillé** — si `locked`, remplacer le bouton/section de retrait par un bloc désactivé :

```dart
    if (locked) {
      // Bloc verrouillé : le retrait n'est pas disponible en Bronze.
      // Message : "Retrait débloqué au niveau Argent — encore $remaining contributions validées."
      // Bouton de retrait désactivé (onTap: null) + icône cadenas.
    }
```

Concrètement : conditionner le `PrimaryButton`/CTA de retrait existant sur `!locked` (sinon `onPressed: null`), et insérer au-dessus une `AppCard` d'information avec le texte ci-dessus (icône `Icons.lock_outline`, couleur `AppColors.textSecondary`).

- [ ] **Step 3 : Recharger le profil à l'ouverture** — dans `initState`, ajouter `AuthApi().refreshMe().catchError((_) {});` (import `../data/api/auth_api.dart`) pour que le niveau soit à jour.

- [ ] **Step 4 : Vérifier la compilation**

Run: `cd sabiData_frontend && flutter analyze lib/screens/revenue_screen.dart`
Expected: `No issues found` (hors `info` préexistants).

- [ ] **Step 5 : Test manuel** — compte Bronze : la section retrait est verrouillée avec le message « encore N contributions validées ».

- [ ] **Step 6 : Commit**

```bash
git add sabiData_frontend/lib/screens/revenue_screen.dart
git commit -m "feat(mobile): retrait verrouillé sous le niveau Argent côté UI"
```

---

### Task 8 : Écran Profil — rebrancher l'accès au formulaire langue/région

**Files:**
- Modify: `sabiData_frontend/lib/screens/profile_screen.dart:116,121,126`

**Interfaces:** aucune (correction de routes).

- [ ] **Step 1 : Rediriger les 3 boutons d'édition vers `/profile-setup`**

Remplacer :
- ligne 116 : `context.go('/language-select')` → `context.go('/profile-setup')`
- ligne 121 : `context.go('/dialect-region')` → `context.go('/profile-setup')`
- ligne 126 : `context.go('/skill-profile')` → `context.go('/profile-setup')`

> Vérifier le libellé de chaque bouton : si trois entrées distinctes pointent désormais toutes vers le même écran, fusionner en une seule entrée « Langue & région » et retirer les deux autres pour éviter la redondance.

- [ ] **Step 2 : Vérifier la compilation**

Run: `cd sabiData_frontend && flutter analyze lib/screens/profile_screen.dart`
Expected: `No issues found` (hors `info` préexistants).

- [ ] **Step 3 : Test manuel** — écran Profil → bouton « Langue & région » → le formulaire `/profile-setup` s'ouvre (3 étapes), plus de page 404.

- [ ] **Step 4 : Commit**

```bash
git add sabiData_frontend/lib/screens/profile_screen.dart
git commit -m "fix(mobile): l'écran Profil rouvre le formulaire langue/région (/profile-setup)"
```

---

## Vérification finale

- [ ] `cd backend && npm test` — toute la suite passe (10 fichiers).
- [ ] `cd sabiData_frontend && flutter analyze` — aucune nouvelle erreur.
- [ ] Test manuel bout-en-bout : nouveau compte → 0 pt / 0 contribution / Bronze / retrait verrouillé ; « Parler » et « Valider » s'ouvrent ; Profil rouvre le formulaire langue/région.

## Couverture de la spec (self-review)

- Bug « Parler » → Task 6 (step 3). ✅
- Bug formulaire langue/région → Task 8. ✅
- Bug crash profile-setup → déjà corrigé (hors plan). ✅
- Points réels → Tasks 2, 4, 6. ✅
- Niveau = contributions validées → Tasks 1, 2, 5, 6. ✅
- Retrait verrouillé sous Argent (serveur + UI) → Tasks 3, 7. ✅
- Nouvel utilisateur = 0/Bronze/verrouillé → conséquence de Tasks 2+6+7. ✅
- Hors périmètre (skill_profile orphelin, célébration de niveau) → non traité, conforme. ✅
