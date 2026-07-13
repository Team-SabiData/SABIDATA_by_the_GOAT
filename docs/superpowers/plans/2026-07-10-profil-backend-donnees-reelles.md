# Profil backend + données réelles — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stocker le profil linguistique (langue/dialecte/région/consentement) sur le compte backend comme source de vérité, exposer historique et couverture régions en données réelles, et câbler le front — corrigeant le formulaire absent, le gating de « Valider », et permettant de classer les utilisateurs.

**Architecture:** Backend d'abord (colonnes `users` + endpoints `POST /me/profile`, `GET /me` enrichi, `GET /me/ledger`, `GET /regions`), puis front (profile-setup POST, gating sur `profileComplete`/`commercialConsent` du backend, revenue history + dialect map câblés).

**Tech Stack:** Backend TypeScript + Fastify + zod + node:test (`npx tsx --test`). Front Flutter/Dart + go_router ; vérification `flutter analyze`.

## Global Constraints

- Activités (record/validate/transcribe) exigent `profileComplete` (langue+dialecte+région non nuls) **ET** `commercialConsent === true`. Skip/refus → lecture seule.
- `profileComplete` est **calculé** côté serveur, jamais écrit à la main.
- Couverture régions : `coveragePct = min(1, clips / CONFIG.regionTargetClips)` (`regionTargetClips = 1000`), régions issues des vrais `clips.region` fusionnées avec le catalogue statique `CONFIG.regions`.
- Classement utilisateurs : le leaderboard porte `language`/`dialect` (pas d'écran dédié).
- Textes/messages UI en français. Commits `type(scope): description` en français.
- `git add` chemins explicites uniquement (l'arbre contient d'autres fichiers non commités hors périmètre).

---

## Backend

### Task 1 : Colonnes profil sur `users` (schema + domaine + repo)

**Files:**
- Modify: `backend/src/db/schema.sql` (table `users`)
- Modify: `backend/src/ports/repo.ts` (interface `UserRecord`, `updateUser` port, InMemoryRepo `updateUser`)
- Modify: `backend/src/ports/pgRepo.ts` (`updateUser` patch, `mapUser`, `interface UserRow`)
- Test: `backend/src/profile.test.ts` (nouveau)

**Interfaces:**
- Produces: `UserRecord.language?`, `.dialect?`, `.region?`, `.commercialConsent: boolean` ; `updateUser` accepte ces 4 champs.

- [ ] **Step 1 : Colonnes SQL** — dans `schema.sql`, table `users`, avant `created_at` :

```sql
  language           text,
  dialect            text,
  region             text,
  commercial_consent boolean NOT NULL DEFAULT false,
```

- [ ] **Step 2 : Test qui échoue** — créer `backend/src/profile.test.ts` :

```ts
import { test } from 'node:test';
import assert from 'node:assert';
import { InMemoryRepo } from './ports/repo';

test('updateUser : persiste language/dialect/region/commercialConsent', async () => {
  const repo = new InMemoryRepo();
  const u = await repo.createUser({ name: 'Awa', role: 'contributor', competence: 1, phoneVerified: true, status: 'active' });
  await repo.updateUser(u.id, { language: 'Mooré', dialect: 'Yatenga', region: 'Nord', commercialConsent: true });
  const got = await repo.findUserById(u.id);
  assert.equal(got?.language, 'Mooré');
  assert.equal(got?.dialect, 'Yatenga');
  assert.equal(got?.region, 'Nord');
  assert.equal(got?.commercialConsent, true);
});
```

> Confirmer la signature réelle de `createUser` (voir `seed()` dans `adminService.test.ts`) et l'aligner.

- [ ] **Step 3 : Vérifier l'échec** — `cd backend && npx tsx --test src/profile.test.ts` → FAIL (champs undefined).

- [ ] **Step 4 : Domaine `UserRecord`** (`repo.ts`) — ajouter au type (tous optionnels pour ne PAS casser les appels `createUser` existants ; `mapUser` fournira toujours `commercialConsent` depuis la BD) :

```ts
  language?: string;
  dialect?: string;
  region?: string;
  commercialConsent?: boolean;
```

- [ ] **Step 5 : Port `updateUser`** (`repo.ts`, interface) — ajouter au type du patch : `language?: string; dialect?: string; region?: string; commercialConsent?: boolean;`.

- [ ] **Step 6 : InMemoryRepo** (`repo.ts`) — dans `createUser`, initialiser `commercialConsent: c.commercialConsent ?? false` sur l'objet stocké ; dans `updateUser`, appliquer les 4 champs quand `!== undefined` (suivre le patron des champs existants). Si `createUser` fait un spread `{...c}`, s'assurer que `commercialConsent` a une valeur par défaut `false`.

- [ ] **Step 7 : pgRepo** — `interface UserRow` (`pgRepo.ts:312`) ajouter :

```ts
  language: string | null; dialect: string | null; region: string | null; commercial_consent: boolean;
```
`mapUser` — ajouter :
```ts
      language: r.language ?? undefined, dialect: r.dialect ?? undefined,
      region: r.region ?? undefined, commercialConsent: r.commercial_consent,
```
`updateUser` — après les `set(...)` existants :
```ts
    if (patch.language !== undefined) set('language', patch.language);
    if (patch.dialect !== undefined) set('dialect', patch.dialect);
    if (patch.region !== undefined) set('region', patch.region);
    if (patch.commercialConsent !== undefined) set('commercial_consent', patch.commercialConsent);
```

- [ ] **Step 8 : Vérifier le succès + typecheck** — `npx tsx --test src/profile.test.ts && npx tsc --noEmit` → PASS + exit 0. (Les champs étant optionnels, aucun appel `createUser` existant ne doit casser ; si `tsc` signale malgré tout un site, l'aligner.)

- [ ] **Step 9 : Commit**

```bash
git add backend/src/db/schema.sql backend/src/ports/repo.ts backend/src/ports/pgRepo.ts backend/src/profile.test.ts
git commit -m "feat(backend): profil linguistique (langue/dialecte/région/consentement) sur users"
```

---

### Task 2 : `POST /me/profile` + `GET /me` enrichi (profileComplete)

**Files:**
- Modify: `backend/src/server.ts` (bloc mobile : handler `/me`, nouveau `POST /me/profile`)
- Create: `backend/src/mobile/profileSchema.ts` (zod)
- Test: `backend/src/profile.test.ts` (ajout)

**Interfaces:**
- Consumes: `updateUser` (Task 1).
- Produces: helper `isProfileComplete(user)` (exporté depuis `profileSchema.ts` ou un petit module) ; `GET /me` renvoie `language,dialect,region,commercialConsent,profileComplete`.

- [ ] **Step 1 : Schéma zod** — créer `backend/src/mobile/profileSchema.ts` :

```ts
import { z } from 'zod';

export const ProfileReq = z.object({
  language: z.string().min(1),
  dialect: z.string().min(1),
  region: z.string().min(1),
  commercialConsent: z.boolean(),
});
export type ProfileReq = z.infer<typeof ProfileReq>;

/** profileComplete = langue+dialecte+région renseignés (consentement séparé). */
export function isProfileComplete(u: { language?: string; dialect?: string; region?: string }): boolean {
  return !!(u.language && u.dialect && u.region);
}
```

- [ ] **Step 2 : Test qui échoue** (ajouter à `profile.test.ts`) :

```ts
import { isProfileComplete } from './mobile/profileSchema';

test('isProfileComplete : vrai seulement si les 3 champs sont présents', () => {
  assert.equal(isProfileComplete({ language: 'Mooré', dialect: 'Yatenga', region: 'Nord' }), true);
  assert.equal(isProfileComplete({ language: 'Mooré', dialect: 'Yatenga' }), false);
  assert.equal(isProfileComplete({}), false);
});
```

- [ ] **Step 3 : Vérifier l'échec** — `npx tsx --test src/profile.test.ts` → FAIL (module absent).

- [ ] **Step 4 : Enrichir `GET /me`** (`server.ts`, handler existant) — après avoir chargé `user`, ajouter au retour :

```ts
          language:     user?.language,
          dialect:      user?.dialect,
          region:       user?.region,
          commercialConsent: user?.commercialConsent ?? false,
          profileComplete: isProfileComplete(user ?? {}),
```
(importer `isProfileComplete` depuis `./mobile/profileSchema`.)

- [ ] **Step 5 : `POST /me/profile`** (`server.ts`, dans le bloc mobile, à côté de `/me`) :

```ts
      i.post('/me/profile', async (req, reply) => {
        const body = ProfileReq.parse(req.body);
        const updated = await repo.updateUser(req.principal!.userId, body);
        return reply.code(200).send({
          language: updated?.language,
          dialect: updated?.dialect,
          region: updated?.region,
          commercialConsent: updated?.commercialConsent ?? false,
          profileComplete: isProfileComplete(updated ?? {}),
        });
      });
```
(importer `ProfileReq`.)

- [ ] **Step 6 : Vérifier succès + typecheck** — `npx tsx --test src/profile.test.ts && npx tsc --noEmit` → PASS + exit 0.

- [ ] **Step 7 : Vérif manuelle** — backend `npm run dev` ; `curl -s -XPOST localhost:3000/api/me/profile -H "Authorization: Bearer <token>" -H "Content-Type: application/json" -d '{"language":"Mooré","dialect":"Yatenga","region":"Nord","commercialConsent":true}'` → renvoie `profileComplete:true`. Puis `GET /me` reflète les champs.

- [ ] **Step 8 : Commit**

```bash
git add backend/src/mobile/profileSchema.ts backend/src/server.ts backend/src/profile.test.ts
git commit -m "feat(backend): POST /me/profile + /me expose profileComplete/consentement"
```

---

### Task 3 : `GET /me/ledger` (historique perso) + leaderboard langue/dialecte

**Files:**
- Modify: `backend/src/ports/repo.ts` (port + InMemoryRepo : `ledgerHistoryFor`)
- Modify: `backend/src/ports/pgRepo.ts` (`ledgerHistoryFor`)
- Modify: `backend/src/server.ts` (`GET /me/ledger` ; leaderboard entries + language/dialect)
- Test: `backend/src/profile.test.ts` (ajout)

**Interfaces:**
- Produces: `Repo.ledgerHistoryFor(userId): Promise<Array<{ reason: string; delta: number; state: string; createdAt: Date; refClipId?: string }>>` (tri antéchronologique).

- [ ] **Step 1 : Test qui échoue** (ajouter à `profile.test.ts`) :

```ts
test('ledgerHistoryFor : entrées du user, ordre antéchronologique', async () => {
  const repo = new InMemoryRepo();
  const u = await repo.createUser({ name: 'Ben', role: 'contributor', competence: 1, phoneVerified: true, status: 'active' });
  await repo.addLedger({ userId: u.id, delta: 50, reason: 'record', state: 'confirmed' });
  await repo.addLedger({ userId: u.id, delta: 20, reason: 'validate', state: 'confirmed' });
  const hist = await repo.ledgerHistoryFor(u.id);
  assert.equal(hist.length, 2);
  assert.equal(typeof hist[0].createdAt.getTime(), 'number');
  assert.ok(hist.every((e) => ['record', 'validate'].includes(e.reason)));
});
```

- [ ] **Step 2 : Vérifier l'échec** — `npx tsx --test src/profile.test.ts` → FAIL (`ledgerHistoryFor` absent).

- [ ] **Step 3 : Port + InMemoryRepo** (`repo.ts`) — ajouter à l'interface `Repo` : `ledgerHistoryFor(userId: string): Promise<Array<{ reason: string; delta: number; state: string; createdAt: Date; refClipId?: string }>>;`. InMemoryRepo : filtrer les entrées mémoire du user, mapper `{reason, delta, state, createdAt, refClipId}` (si les entrées mémoire n'ont pas de `createdAt`, l'ajouter à l'insertion `addLedger` de l'InMemoryRepo — un `new Date()` stocké), trier desc.

> Note : les scripts de workflow interdisent `new Date()` — mais ceci est du code applicatif backend exécuté normalement, `new Date()` y est autorisé.

- [ ] **Step 4 : pgRepo** (`pgRepo.ts`) — implémenter :

```ts
  async ledgerHistoryFor(userId: string) {
    const rows = await this.many<LedgerRow & { created_at: string }>(
      `SELECT reason, delta, state, ref_clip_id, created_at
       FROM points_ledger WHERE user_id = $1 ORDER BY created_at DESC`,
      [userId],
    );
    return rows.map((r) => ({
      reason: r.reason, delta: r.delta, state: r.state,
      createdAt: new Date(r.created_at), refClipId: r.ref_clip_id ?? undefined,
    }));
  }
```

- [ ] **Step 5 : Endpoint `GET /me/ledger`** (`server.ts`, bloc mobile) :

```ts
      i.get('/me/ledger', async (req) => ({ entries: await repo.ledgerHistoryFor(req.principal!.userId) }));
```

- [ ] **Step 6 : Leaderboard langue/dialecte** (`server.ts`, handler `/leaderboard`) — dans le `map`, renvoyer aussi la langue/dialecte du user :

```ts
          users.map(async (u) => {
            const w = await wallet.getWallet(u.id);
            return { id: u.id, name: u.name, points: w.pointsTotal, language: u.language, dialect: u.dialect };
          }),
```

- [ ] **Step 7 : Vérifier succès + typecheck** — `npx tsx --test src/profile.test.ts && npx tsc --noEmit` → PASS + exit 0.

- [ ] **Step 8 : Commit**

```bash
git add backend/src/ports/repo.ts backend/src/ports/pgRepo.ts backend/src/server.ts backend/src/profile.test.ts
git commit -m "feat(backend): GET /me/ledger (historique perso) + leaderboard langue/dialecte"
```

---

### Task 4 : `GET /regions` (couverture réelle depuis les clips)

**Files:**
- Modify: `backend/src/config.ts` (`regionTargetClips`, `regions` catalogue)
- Modify: `backend/src/ports/repo.ts` (port + InMemoryRepo : `countClipsByRegion`)
- Modify: `backend/src/ports/pgRepo.ts` (`countClipsByRegion`)
- Modify: `backend/src/server.ts` (`GET /regions`)
- Test: `backend/src/profile.test.ts` (ajout)

**Interfaces:**
- Produces: `Repo.countClipsByRegion(): Promise<Array<{ region: string; clips: number }>>` ; `GET /regions` → `[{region, zone, clips, coveragePct}]`.

- [ ] **Step 1 : Config** (`config.ts`) — dans `CONFIG`, ajouter :

```ts
  regionTargetClips: 1000,
  regions: [
    { name: 'Ouagadougou', zone: 'Centre' },
    { name: 'Koudougou', zone: 'Plateau Central' },
    { name: 'Ouahigouya', zone: 'Nord' },
    { name: 'Yatenga', zone: 'Nord' },
    { name: 'Bobo-Dioulasso', zone: 'Hauts-Bassins' },
    { name: 'Dédougou', zone: 'Boucle du Mouhoun' },
    { name: 'Dori', zone: 'Sahel' },
    { name: "Fada N'Gourma", zone: 'Est' },
  ],
```

- [ ] **Step 2 : Test qui échoue** (ajouter à `profile.test.ts`) :

```ts
import { buildRegionCoverage } from './mobile/regionCoverage';

test('buildRegionCoverage : fusionne comptes clips et catalogue, pct plafonné', () => {
  const counts = [{ region: 'Ouagadougou', clips: 500 }, { region: 'Yatenga', clips: 2000 }];
  const cov = buildRegionCoverage(counts);
  const ouaga = cov.find((r) => r.region === 'Ouagadougou')!;
  const yat = cov.find((r) => r.region === 'Yatenga')!;
  const dori = cov.find((r) => r.region === 'Dori')!; // 0 clip → présent via catalogue
  assert.equal(ouaga.coveragePct, 0.5);
  assert.equal(yat.coveragePct, 1);    // 2000/1000 plafonné à 1
  assert.equal(dori.clips, 0);
  assert.equal(dori.zone, 'Sahel');
});
```

- [ ] **Step 3 : Vérifier l'échec** — `npx tsx --test src/profile.test.ts` → FAIL (module absent).

- [ ] **Step 4 : Helper pur** — créer `backend/src/mobile/regionCoverage.ts` :

```ts
import { CONFIG } from '../config';

export function buildRegionCoverage(
  counts: Array<{ region: string; clips: number }>,
): Array<{ region: string; zone: string; clips: number; coveragePct: number }> {
  const byRegion = new Map(counts.map((c) => [c.region, c.clips]));
  return CONFIG.regions.map((r) => {
    const clips = byRegion.get(r.name) ?? 0;
    return { region: r.name, zone: r.zone, clips, coveragePct: Math.min(1, clips / CONFIG.regionTargetClips) };
  });
}
```

- [ ] **Step 5 : Repo `countClipsByRegion`** — port (`repo.ts`) : `countClipsByRegion(): Promise<Array<{ region: string; clips: number }>>;`. InMemoryRepo : agréger `this.clips` par `region` (ignorer les clips sans région). pgRepo :

```ts
  async countClipsByRegion() {
    const rows = await this.many<{ region: string | null; n: string }>(
      `SELECT region, COUNT(*)::text AS n FROM clips WHERE region IS NOT NULL GROUP BY region`,
    );
    return rows.map((r) => ({ region: r.region as string, clips: Number(r.n) }));
  }
```

- [ ] **Step 6 : Endpoint `GET /regions`** (`server.ts`, bloc mobile) :

```ts
      i.get('/regions', async () => buildRegionCoverage(await repo.countClipsByRegion()));
```
(importer `buildRegionCoverage`.)

- [ ] **Step 7 : Vérifier succès + typecheck** — `npx tsx --test src/profile.test.ts && npx tsc --noEmit` → PASS + exit 0.

- [ ] **Step 8 : Commit**

```bash
git add backend/src/config.ts backend/src/mobile/regionCoverage.ts backend/src/ports/repo.ts backend/src/ports/pgRepo.ts backend/src/server.ts backend/src/profile.test.ts
git commit -m "feat(backend): GET /regions (couverture réelle depuis clips + catalogue)"
```

---

## Frontend

### Task 5 : `UserProfile` profil complet + `AuthApi.saveProfile`/reset au login

**Files:**
- Modify: `sabiData_frontend/lib/data/auth/auth_session.dart` (UserProfile)
- Modify: `sabiData_frontend/lib/data/api/auth_api.dart` (saveProfile, clearUser au login)

**Interfaces:**
- Produces: `UserProfile.profileComplete` (bool), `.commercialConsent` (bool), `.language/.dialect/.region` (String?) ; `AuthApi().saveProfile({...})` → POST `/api/me/profile` puis `refreshMe`.

- [ ] **Step 1 : UserProfile** — ajouter champs + parsing dans `fromJson` :

```dart
  final bool profileComplete;
  final bool commercialConsent;
  final String? language;
  final String? dialect;
  final String? region;
```
Constructeur : `this.profileComplete = false, this.commercialConsent = false, this.language, this.dialect, this.region,`.
`fromJson` : `profileComplete: j['profileComplete'] == true, commercialConsent: j['commercialConsent'] == true, language: j['language']?.toString(), dialect: j['dialect']?.toString(), region: j['region']?.toString(),`.

- [ ] **Step 2 : AuthApi.saveProfile** (`auth_api.dart`) :

```dart
  /// Enregistre le profil linguistique côté serveur puis rafraîchit /me.
  Future<void> saveProfile({
    required String language,
    required String dialect,
    required String region,
    required bool commercialConsent,
  }) async {
    await _client.post('/api/me/profile', {
      'language': language, 'dialect': dialect, 'region': region,
      'commercialConsent': commercialConsent,
    });
    await refreshMe();
  }
```

- [ ] **Step 3 : Reset au login** — dans les méthodes `login`/`register`/`verifyOtp` de `AuthApi`, juste après `setToken(...)`, appeler `await DialectPrefs.clearUser();` (import `../prefs/dialect_prefs.dart`) puis `await refreshMe();` pour charger l'état backend du compte. (Garder l'appel `setProfile(map['user'])` s'il existe ; `refreshMe` le complètera avec profileComplete.)

- [ ] **Step 4 : Vérifier** — `cd sabiData_frontend && flutter analyze lib/data/auth/auth_session.dart lib/data/api/auth_api.dart` → pas d'erreur nouvelle.

- [ ] **Step 5 : Commit**

```bash
git add sabiData_frontend/lib/data/auth/auth_session.dart sabiData_frontend/lib/data/api/auth_api.dart
git commit -m "feat(mobile): UserProfile profil complet + saveProfile + reset local au login"
```

---

### Task 6 : `profile_setup_screen` enregistre côté serveur

**Files:**
- Modify: `sabiData_frontend/lib/screens/profile_setup_screen.dart` (`_completeSetup`)

**Interfaces:**
- Consumes: `AuthApi().saveProfile(...)` (Task 5).

- [ ] **Step 1 : POST au serveur** — dans `_completeSetup`, après le `DialectPrefs.save(...)` local, appeler le backend (best-effort mais on attend le résultat pour le gating). Remplacer la logique de fin par :

```dart
  Future<void> _completeSetup({bool accepted = true}) async {
    final lang = _langs.isNotEmpty ? _langs.first : 'Mooré';
    final dialect = _dialect.isNotEmpty ? _dialect : 'Yatenga';
    final region = _region.isNotEmpty ? _region : 'Nord';
    await DialectPrefs.save(
      langs: _langs.toList(), lang: lang, dialect: dialect, region: region,
      rare: _rare, profileSetupDone: true, consentAccepted: accepted,
    );
    try {
      await AuthApi().saveProfile(
        language: lang, dialect: dialect, region: region, commercialConsent: accepted,
      );
    } catch (_) { /* garde le local ; le gating retentera au prochain /me */ }
    if (mounted) context.go('/dashboard');
  }
```
(import `../data/api/auth_api.dart`.)

- [ ] **Step 2 : Vérifier** — `flutter analyze lib/screens/profile_setup_screen.dart` → pas d'erreur nouvelle.

- [ ] **Step 3 : Commit**

```bash
git add sabiData_frontend/lib/screens/profile_setup_screen.dart
git commit -m "feat(mobile): profile-setup enregistre le profil côté serveur"
```

---

### Task 7 : Gating sur l'état backend (router + splash)

**Files:**
- Modify: `sabiData_frontend/lib/router.dart` (redirect)
- Modify: `sabiData_frontend/lib/screens/splash_screen.dart`
- Modify: `sabiData_frontend/lib/data/api/auth_api.dart` (`nextRoute`)

**Interfaces:**
- Consumes: `AuthSession.instance.user.value` (profileComplete/commercialConsent), `AuthApi().refreshMe()`.

- [ ] **Step 1 : Helper d'état** — le gating doit lire le profil backend. Ajouter dans `AuthSession` un getter pratique :

```dart
  bool get canDoActivities {
    final u = user.value;
    return u != null && u.profileComplete && u.commercialConsent;
  }
  bool get profileComplete => user.value?.profileComplete ?? false;
```

- [ ] **Step 2 : Router** — remplacer, dans le redirect, l'usage de `DialectPrefs.profileSetupDone/consentAccepted` par l'état backend :

```dart
    final canActivities = AuthSession.instance.canDoActivities;
    ...
    if (_activityRoutes.contains(path)) {
      if (!isAuthenticated) return '/preview';
      if (!canActivities) return '/profile-setup';
      return null;
    }
```
(supprimer les variables `profileDone`/`consentDone` locales si elles ne servent plus.)

- [ ] **Step 3 : Splash** — après `AuthSession` restauré, si authentifié : `await AuthApi().refreshMe()` (best-effort) puis router sur `AuthSession.instance.profileComplete ? '/dashboard' : '/profile-setup'`. Remplacer la lecture de `DialectPrefs.profileSetupDone` par `AuthSession.instance.profileComplete`.

- [ ] **Step 4 : nextRoute** (`auth_api.dart`) — baser sur le backend :

```dart
  static String nextRoute() =>
      AuthSession.instance.profileComplete ? '/dashboard' : '/profile-setup';
```

- [ ] **Step 5 : Vérifier** — `flutter analyze lib/router.dart lib/screens/splash_screen.dart lib/data/api/auth_api.dart` → pas d'erreur nouvelle.

- [ ] **Step 6 : Commit**

```bash
git add sabiData_frontend/lib/router.dart sabiData_frontend/lib/screens/splash_screen.dart sabiData_frontend/lib/data/api/auth_api.dart
git commit -m "fix(mobile): gating profil basé sur l'état backend (formulaire fiable, Valider débloqué)"
```

---

### Task 8 : Historique des gains réel (`revenue_screen`)

**Files:**
- Create: `sabiData_frontend/lib/data/api/ledger_api.dart`
- Modify: `sabiData_frontend/lib/screens/revenue_screen.dart`

**Interfaces:**
- Produces: `LedgerApi().history()` → `List<Map<String,dynamic>>` (entries de `/api/me/ledger`).

- [ ] **Step 1 : Client API** — créer `ledger_api.dart` :

```dart
import 'api_client.dart';

/// Historique des gains de l'utilisateur (GET /api/me/ledger).
class LedgerApi {
  final ApiClient _client;
  LedgerApi([ApiClient? client]) : _client = client ?? ApiClient();

  Future<List<Map<String, dynamic>>> history() async {
    final data = await _client.get('/api/me/ledger');
    final entries = (data as Map)['entries'] as List? ?? [];
    return entries.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
```

- [ ] **Step 2 : Câbler `revenue_screen`** — remplacer le `static const _history` par un chargement d'état. Dans `initState`, charger via `LedgerApi().history()` dans une variable d'état `List<Map<String,dynamic>> _history = []` (avec `mounted` guard). Adapter le rendu (`..._history.map(...)`) pour lire `h['reason']`, `h['delta']`, `h['state']`, `h['createdAt']` — libellé FR par raison (record→« Enregistrement », validate→« Validation », transcribe→« Transcription », convert→« Conversion », withdrawal→« Retrait »), signe selon `delta`, date formatée courte. Afficher un état vide « Aucun gain pour l'instant » si la liste est vide.

> Lire la structure de rendu existante de `_history` avant d'éditer pour conserver le style visuel des lignes.

- [ ] **Step 3 : Vérifier** — `flutter analyze lib/screens/revenue_screen.dart lib/data/api/ledger_api.dart` → pas d'erreur nouvelle.

- [ ] **Step 4 : Commit**

```bash
git add sabiData_frontend/lib/data/api/ledger_api.dart sabiData_frontend/lib/screens/revenue_screen.dart
git commit -m "feat(mobile): historique des gains réel via GET /api/me/ledger"
```

---

### Task 9 : Carte des dialectes réelle (`dialect_map_screen`)

**Files:**
- Create: `sabiData_frontend/lib/data/api/regions_api.dart`
- Modify: `sabiData_frontend/lib/screens/dialect_map_screen.dart`

**Interfaces:**
- Produces: `RegionsApi().coverage()` → `List<Map<String,dynamic>>` (`/api/regions`).

- [ ] **Step 1 : Client API** — créer `regions_api.dart` :

```dart
import 'api_client.dart';

/// Couverture linguistique par région (GET /api/regions).
class RegionsApi {
  final ApiClient _client;
  RegionsApi([ApiClient? client]) : _client = client ?? ApiClient();

  Future<List<Map<String, dynamic>>> coverage() async {
    final data = await _client.get('/api/regions');
    return (data as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
```

- [ ] **Step 2 : Câbler `dialect_map_screen`** — remplacer `static const _coverage` par un chargement d'état (`List<Map<String,dynamic>> _coverage = []`) dans `initState` via `RegionsApi().coverage()` (avec `mounted` guard + état de chargement). Adapter le rendu pour lire `r['region']`, `r['zone']`, `r['clips']`, `r['coveragePct']` (double). Conserver la mise en page (barres/pourcentages) ; afficher « — » ou un skeleton pendant le chargement.

> Lire la structure de `_coverage` et son rendu avant d'éditer pour préserver le style.

- [ ] **Step 3 : Vérifier** — `flutter analyze lib/screens/dialect_map_screen.dart lib/data/api/regions_api.dart` → pas d'erreur nouvelle.

- [ ] **Step 4 : Commit**

```bash
git add sabiData_frontend/lib/data/api/regions_api.dart sabiData_frontend/lib/screens/dialect_map_screen.dart
git commit -m "feat(mobile): carte des dialectes réelle via GET /api/regions"
```

---

## Vérification finale

- [ ] `cd backend && npm test` — toute la suite passe (incl. `profile.test.ts`).
- [ ] `cd sabiData_frontend && flutter analyze` — aucune nouvelle erreur.
- [ ] Test device bout-en-bout : nouveau compte (ou après logout) → **le formulaire s'affiche** ; tant qu'il n'est pas rempli+consenti, **les activités sont bloquées** ; après remplissage, **« Valider » s'ouvre** ; l'**historique des gains** et la **carte des dialectes** affichent des données réelles ; un second compte sur le même appareil **revoit le formulaire** (plus de fuite).

## Couverture de la spec (self-review)

- Colonnes profil sur users → Task 1. ✅
- POST /me/profile + profileComplete → Task 2. ✅
- Gating fiable par compte + formulaire réapparaît → Tasks 2,5,6,7. ✅
- Valider débloqué → conséquence Task 7. ✅
- Classer utilisateurs par langue/dialecte → Tasks 1,3 (leaderboard porte les champs). ✅
- Historique des gains réel → Tasks 3,8. ✅
- Carte des dialectes réelle → Tasks 4,9. ✅
- Consentement requis pour activités → Tasks 2,7 (`canDoActivities`). ✅
- Couverture depuis clips + catalogue → Task 4. ✅
