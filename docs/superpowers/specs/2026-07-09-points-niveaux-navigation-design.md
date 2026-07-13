# Points/niveaux réels + corrections navigation — Design

Date : 2026-07-09
Branche : feat/admin-console

## Problème

Trois régressions de navigation et un système de points/niveaux entièrement
statique (mock) côté mobile.

1. **« Parler » ne s'ouvre pas** — le bouton du dashboard navigue vers `/consent`,
   route inexistante (le consentement est passé dans l'étape 3 du profile-setup)
   → page 404.
2. **Formulaire langue/région inaccessible** — l'écran Profil renvoie vers
   `/language-select`, `/dialect-region`, `/skill-profile`, routes supprimées → 404.
3. **Points/niveaux statiques** — `dashboard_screen.dart` affiche `const points = 1240`
   et `nextLevelAt = 2000` codés en dur, plus « GARDIEN BRONZE » / « 67 contributions
   validées » en texte fixe. Un nouvel utilisateur voit donc 1240 points sans avoir
   rien fait. Le backend, lui, calcule déjà des points réels (0 au départ) via le
   ledger, mais le front ne les consomme pas.

## Objectif

- Rebrancher les liens de navigation morts.
- Remplacer les points/niveaux mock par des données réelles dérivées de la
  participation.
- Introduire un niveau (palier) gagné par la participation, et verrouiller le
  retrait tant qu'un niveau minimum n'est pas atteint.

## Décisions

- **Niveau = nombre de contributions validées** : 🥉 Bronze `<50`, 🥈 Argent
  `50–199`, 🥇 Or `200+`.
- **« Contribution validée » = toute entrée de ledger `confirmed`** dont la raison
  représente un acte de contribution : `record`, `validate`, `transcribe`,
  `convert`. (Un `record` ne devient `confirmed` qu'une fois le clip validé par les
  pairs ; les `withdrawal`/`withdrawal_refund`/bonus sont exclus.)
- **Paiement débloqué à partir d'Argent** — retrait verrouillé en Bronze.
- La `competence` backend (0–3, assignée par l'admin) reste distincte : elle route
  la validation par pair, elle n'est PAS le « niveau » gamifié.

## Architecture

### Backend

**`config.ts`** — nouveaux seuils :
```ts
levels: { argentAt: 50, orAt: 200 },   // nb de contributions validées
withdrawMinLevel: 'argent',
```

**Helper de niveau partagé** (`src/domain/level.ts`, nouveau) :
```ts
export type Level = 'bronze' | 'argent' | 'or';
export function levelFor(validatedCount: number): Level { … }   // seuils depuis CONFIG
export function meetsWithdrawLevel(level: Level): boolean { … } // level ≠ 'bronze'
```

**Comptage** — le ledger est déjà chargé par `WalletService`. Ajouter le compteur
au calcul existant plutôt qu'une requête séparée :
- `WalletService.getWallet` renvoie aussi `contributionsValidated` (count des
  entrées `confirmed` de raison contributive) et `level`.
- Alternative écartée : requête SQL `COUNT` dédiée — inutile, le ledger est déjà en
  mémoire à cet endroit.

**`GET /api/me`** (server.ts) — ajoute `contributionsValidated` et `level` à la
réponse existante (`points` déjà présent).

**`WalletService.requestWithdrawal`** — garde de niveau AVANT le débit :
```ts
if (!meetsWithdrawLevel(levelFor(contributionsValidated))) throw forbidden('LEVEL_TOO_LOW');
```
Garde serveur = source de vérité (c'est de l'argent) ; l'UI ne fait que refléter.

### Frontend

**`UserProfile` (auth_session.dart)** — ajoute `points`, `contributionsValidated`,
`level` (parsés depuis `/api/me`). `AuthSession` recharge `/api/me` après
authentification et expose le profil via `ValueListenable`.

**Helper de niveau front** (`lib/data/gamification/level.dart`, nouveau) — miroir
des seuils backend : `Level.of(count)` → label, emoji, couleur, seuil suivant,
progression. Une seule source de seuils documentée des deux côtés.

**`dashboard_screen.dart`** — supprime les `const` mock ; la carte héros lit points
réels, palier réel (label + emoji), compteur réel, et la progression vers le palier
suivant (`count / prochainSeuil`).

**Revenus / retrait** — si niveau < Argent, état verrouillé : « Débloqué au niveau
Argent — 50 contributions validées, il t'en reste N ». Le bouton de retrait est
désactivé.

**Navigation** — corrections :
- `dashboard_screen.dart:145` : `/consent` → `/recording`
- `profile_screen.dart:116/121/126` : → `/profile-setup`

## Flux de données

```
auth OK → AuthSession.refreshMe() → GET /api/me
         → UserProfile{points, contributionsValidated, level}
         → dashboard / profil / revenus (ValueListenableBuilder)
```

Nouvel utilisateur : ledger vide → 0 point, 0 contribution, Bronze, retrait
verrouillé.

## Gestion des erreurs

- Retrait sous le niveau requis → backend `403 LEVEL_TOO_LOW` → snackbar côté front.
- `/api/me` en échec → le dashboard conserve les dernières valeurs connues (ou 0),
  pas de crash.

## Tests

- **Backend (unit)** : `levelFor` aux frontières (49→bronze, 50→argent, 199→argent,
  200→or) ; `requestWithdrawal` rejette en Bronze (`LEVEL_TOO_LOW`) et accepte en
  Argent ; `getWallet` renvoie le bon `contributionsValidated`.
- **Front** : `flutter analyze` propre ; re-test manuel (nouveau compte = 0/Bronze/
  verrouillé ; Parler ouvre l'enregistrement ; Profil rouvre le formulaire).

## Hors périmètre

- Refonte de l'écran `skill_profile` (orphelin, non routé) — laissé tel quel.
- Notifications de passage de niveau (célébration) — itération ultérieure.
