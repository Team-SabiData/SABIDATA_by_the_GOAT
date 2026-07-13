# Refonte panel admin SabiData — « Salle de contrôle »

**Date :** 2026-07-05
**Périmètre :** `admin-web/` (React/Vite) + extensions backend (`backend/`) nécessaires aux fonctionnalités d'administration.
**Hors périmètre :** modération de contenu des clips, CRUD référentiel (langues/régions/prompts), transaction atomique `withTransaction` (P0 backend connu, chantier séparé, non aggravé ici), app mobile.

## Intention

Transformer la console d'administration embryonnaire (2 pages, styles inline, `window.prompt`) en un back-office complet de supervision et de rémunération : **tout ce qui bouge dans le système — utilisateurs, argent, connexions, actions — est visible et retraçable depuis le panel**, et l'admin dispose des contrôles complets (bannir, suspendre, créer, supprimer, ajuster les soldes, traiter les retraits), chaque action laissant une trace immuable motivée.

## Décisions actées (brainstorming)

1. Périmètre : refonte visuelle + structuration + fonctionnalités d'administration (option 1 élargie par l'utilisateur).
2. 2FA : **TOTP conservé** (RFC 6238 déjà implémenté backend) — UX du login refaite.
3. Argent : contrôle complet — voir portefeuille + ledger par utilisateur, **ajustements manuels ±** avec motif, **gestion des retraits** (approuver/refuser).
4. Suppression d'utilisateur : **douce et anonymisée** — données personnelles effacées, lignes de ledger et d'audit conservées (« utilisateur supprimé »).
5. Identité visuelle : **A — Salle de contrôle** — sombre professionnel, accent orange opérationnel `#F5A624` (distinct du mobile, voulu), rouge réservé au danger/destructif, chiffres tabulaires pour l'argent.

## État de départ (constaté)

- `admin-web/` : 2 pages (Login 2 étapes fonctionnel, Dashboard empilant litiges/utilisateurs/audit), `theme.ts` inline, pas de routing, pas de tests, **non commité dans git** → un commit de base précède tout travail.
- Backend existant : auth admin TOTP (`/admin/auth/login` + `/admin/auth/totp`), `GET/PATCH /admin/users` (sans `status`), `GET /admin/disputes`, `POST /admin/clips/:id/arbitrate`, `GET /admin/audit-log` (table immuable), `WalletService.getWallet(userId)`, table `withdrawals` sans routes, RBAC central `domain/roles.ts`, tests `app.inject`.

---

## 1. Backend — extensions

### 1.1 Statut utilisateur
- Champ `status: 'active' | 'suspended' | 'banned' | 'deleted'` sur users (défaut `active`).
- `PATCH /admin/users/:id` accepte `{ status, reason }` — **motif obligatoire** (400 sinon).
- Le login mobile (et OTP) refuse `suspended`/`banned`/`deleted` avec un message explicite (« Compte suspendu, contactez SabiData »). Suspendu = réversible ; banni = seul un admin peut repasser à `active`.

### 1.2 Création / suppression
- `POST /admin/users` : `{ name, email? | phone?, role, password? }` (mot de passe provisoire si email). Journalisé.
- `DELETE /admin/users/:id` : suppression douce — `status='deleted'`, nom → « Utilisateur supprimé », email/phone → null/anonymisés, identifiants d'auth révoqués. Ledger et audit conservent leurs lignes.
- **Garde-fous backend** (pas seulement UI) : un admin ne peut pas se suspendre/bannir/supprimer lui-même ; impossible de supprimer/rétrograder/bannir le **dernier admin actif**.

### 1.3 Argent par utilisateur
- `GET /admin/users/:id/wallet` → réutilise `WalletService.getWallet` (pointsTotal, pointsPending, balanceFcfa).
- `GET /admin/users/:id/ledger` → historique complet paginé (source, delta, état, date, référence).
- `POST /admin/users/:id/adjustments` : `{ delta (±, entier ≠ 0), reason }` → **nouvelle ligne de ledger** source `admin_adjustment`, état `confirmed`, auteur = admin. Le ledger reste append-only : jamais de modification/suppression de ligne. Refusé sur compte `deleted`.

### 1.4 Retraits
- `GET /admin/withdrawals?status=` → file (en attente, approuvés/payés, refusés).
- `POST /admin/withdrawals/:id/decide` : `{ decision: 'approved' | 'rejected', reason }` — un refus **re-crédite** par ligne de ledger compensatoire (append-only).

### 1.5 Heures de connexion & activité
- Chaque login réussi (mobile `/auth/*` et admin `/admin/auth/totp`) écrit un événement `login` dans l'`audit_log` existant (acteur, canal `mobile|admin`, date). Pas de nouvelle table ; pas d'historique rétroactif.
- `GET /admin/users/:id/activity` → connexions + actions de/sur l'utilisateur (extraites de l'audit_log, paginées).

### 1.6 Traçabilité & RBAC
- Toute écriture admin (statut, création, suppression, ajustement, décision de retrait, arbitrage, promotion/rétrogradation) écrit dans l'audit_log immuable avec motif.
- Nouvelles permissions dans `domain/roles.ts` : `users.write`, `wallet.read`, `wallet.adjust`, `withdrawals.decide` — rôle admin uniquement, contrôlées par les guards existants.

---

## 2. Frontend — architecture

- **Routing** : `react-router` (seule dépendance runtime ajoutée). `/login`, puis coquille authentifiée : `/` (vue d'ensemble), `/disputes`, `/users`, `/users/:id`, `/money`, `/audit`. Token en mémoire + `sessionStorage` ; tout 401 → retour login.
- **`AppShell`** : barre latérale fixe (logo, navigation avec état actif orange, badges compteurs Litiges/Retraits en attente, identité admin + déconnexion en bas) ; zone de contenu avec en-tête de page standardisé.
- **Tokens `src/ui/tokens.css`** (CSS variables ; `theme.ts` supprimé à la fin) : fonds `#0C1020`/surfaces existantes, accent `#F5A624`, statuts (vert `#2BC49A`, ambre, rouge `#E84040`, bleu `#4A9EF5`), rayons cartes 14 / contrôles 10 / pills 999, espacements 4/8, typo **Inter** (UI) + **JetBrains Mono** tabulaire (argent, dates, ids) via `@fontsource` — aucun CDN.
- **Composants `src/ui/`** (un fichier = une responsabilité, stylés par tokens, pas de framework CSS) : `Button` (primaire/contour/danger, chargement), `Card`, `DataTable` (tri, ligne cliquable), `Badge`, `Modal` (focus trap, Échap, **motif obligatoire** en textarea), `Drawer`, `KpiCard`, `Field`, `Toast`, `EmptyState`.
- **API `src/api.ts`** : mêmes conventions (fetch + Bearer), nouveaux endpoints typés, erreurs en `Toast` rouge (aucun `alert`/`window.prompt`).
- **Confirmations dangereuses** : bannir/supprimer/débiter → `Modal` avec motif obligatoire ; suppression → « type-to-confirm » (ressaisir le nom).
- **Tests front** : Vitest + Testing Library (dev deps) — composants critiques + pages avec API mockée.

---

## 3. Pages

- **Login** : 2 étapes conservées (mot de passe → TOTP), carte centrée, étape TOTP en 6 cases auto-submit avec collage, mention « code à 6 chiffres de votre application d'authentification », erreurs inline.
- **Vue d'ensemble `/`** : `KpiCard` (utilisateurs actifs/suspendus/bannis, litiges en attente, retraits à traiter, points distribués, FCFA payés) + colonnes « À traiter » (litiges + retraits les plus anciens, cliquables) et « Dernières actions » (5 lignes d'audit).
- **Litiges `/disputes`** : file de travail — durée, rareté, **écoute du clip** (`GET /clips/:id/audio` existant), verdicts via Modal motif.
- **Utilisateurs `/users`** : `DataTable` (nom, rôle badge, statut ●/⏸/⛔, niveau, solde FCFA mono, dernière connexion, contact), recherche nom/contact, filtres rôle/statut, « + Créer un utilisateur ». Ligne → **fiche `/users/:id`** en `Drawer` : identité, portefeuille, ledger complet, activité (connexions + actions), actions : Promouvoir/Rétrograder, Ajuster (± + motif), Suspendre, Bannir, Supprimer (type-to-confirm).
- **Argent `/money`** : totaux en tête (FCFA en circulation, en attente de retrait, payés) ; onglet **Retraits** (file en attente → approuver/refuser motif ; historique) ; onglet **Ajustements** (tous les ajustements manuels : qui/combien/pourquoi — contrôle mutuel entre admins).
- **Audit `/audit`** : filtres (action, acteur, type d'entité, période), acteur résolu en nom, entité cliquable vers sa fiche, motif complet, **export CSV côté client**.
- **États** : vide/erreur/chargement (squelettes) sur chaque page ; aucune donnée mockée.

---

## 4. Sécurité & vérification

- Aucune écriture sans motif (UI **et** backend). Ledger append-only, solde toujours dérivé. Garde-fous anti-lockout côté backend. JWT admin TTL court conservé, pas de « se souvenir de moi ». Comptes supprimés lisibles dans ledger/audit comme « utilisateur supprimé ».
- **Tests backend** (`app.inject`) par route : nominal + refus (sans motif, sans permission, auto-ban, dernier admin, login d'un banni, ajustement sur supprimé, décision sur retrait déjà traité).
- **Tests front** : Modal refuse motif vide ; type-to-confirm bloque ; DataTable filtre/trie ; pages rendent les états vide/erreur.
- **Vérification manuelle finale** (navigateur + backend PGlite) : créer un user → créditer +500 → vérifier wallet/ledger → suspendre (login mobile refusé) → consulter l'activité → supprimer → vérifier anonymisation + ledger intact + audit complet.

## Prérequis git

`admin-web/` et plusieurs sources backend (`src/auth`, `src/authz`, `src/curation`, `src/http`, `src/routes/*`, tests, `docs/backend/`) sont **non commités**. La première tâche du plan est un commit de base de l'existant, avant toute modification.

## Risques & limites

- Heures de connexion : pas d'historique rétroactif (démarre à la mise en service).
- Export CSV côté client — suffisant à cette échelle.
- L'absence de `withTransaction` (P0 connu) s'applique aussi aux ajustements/retraits : risque accepté à cette échelle, chantier séparé prioritaire ensuite.
- `admin_sessions`/`admin_recovery_codes` du delta-v2 : non requis ici (le TTL JWT court suffit) — pas implémentés dans ce cycle.
