# SabiData — Documentation complète

> Plateforme de collecte crowdsourcée de données audio en langues nationales
> burkinabè (**mooré, dioula, fulfuldé, gulmancema**). Conçue *offline-first*,
> accessible aux utilisateurs peu alphabétisés, optimisée pour les connexions
> lentes. Les contributeurs enregistrent, valident et transcrivent des clips ;
> les points gagnés se convertissent en argent réel via Mobile Money.

Dernière mise à jour : 2026-07-12 · Branche : `feat/admin-console`

---

## Table des matières

1. [Vue d'ensemble & architecture](#1-vue-densemble--architecture)
2. [Stack technique](#2-stack-technique)
3. [Modèle de domaine](#3-modèle-de-domaine)
4. [Backend — API REST](#4-backend--api-rest)
5. [Application mobile (Flutter)](#5-application-mobile-flutter)
6. [Console d'administration (React)](#6-console-dadministration-react)
7. [Stockage & données](#7-stockage--données)
8. [Sécurité](#8-sécurité)
9. [Configuration & déploiement](#9-configuration--déploiement)
10. [Tests](#10-tests)
11. [Limites connues & feuille de route](#11-limites-connues--feuille-de-route)

---

## 1. Vue d'ensemble & architecture

SabiData est un **monorepo** de trois composants autour d'un backend unique qui
sert **deux clients à privilèges asymétriques** :

```
SABIDATA/
├── sabiData_frontend/   App mobile Flutter (Dart) — contributeurs
├── backend/             API partagée (TypeScript / Fastify / Postgres)
│                          /api/*   → surface MOBILE (contribution)
│                          /admin/* → surface ADMIN  (gouvernance, 2FA)
├── admin-web/           Console d'administration (React + Vite + TS)
└── docs/                Conception : schema.sql, api.md, specs, ce document
```

```
   ┌─────────────┐         ┌──────────────┐        ┌─────────────────┐
   │  Mobile     │  /api   │              │  SQL   │  Neon Postgres  │
   │  (Flutter)  │────────▶│   Backend    │───────▶│  (users, clips, │
   └─────────────┘         │   Fastify    │        │   ledger, …)    │
   ┌─────────────┐ /admin  │  (TS/Node)   │  S3    ├─────────────────┤
   │  Admin web  │────────▶│              │───────▶│  Cloudflare R2  │
   │  (React)    │         └──────────────┘        │  (blobs audio)  │
   └─────────────┘                                 └─────────────────┘
```

**Principe d'architecture** : la logique métier (auto-check, consensus, calcul
de tier, ledger à deux phases) vit dans le service TypeScript, entièrement
testée. La base de données ne porte que **tables + contraintes + idempotence**.
Le stockage (audio) et la persistance (Postgres) sont derrière des interfaces
(`AudioStore`, `SqlDb`/`Repo`) permettant de permuter dev ↔ prod sans toucher au
métier.

---

## 2. Stack technique

### Backend (`backend/`)
| Élément | Choix |
|---|---|
| Runtime | Node.js 22, TypeScript (ESM, `type: module`) |
| Framework HTTP | **Fastify 5** |
| Upload | `@fastify/multipart` (limite 10 Mo/fichier) |
| Base de données | **Postgres** — `pg` (Neon en prod) ou `@electric-sql/pglite` (WASM, dev/tests) |
| Validation | **Zod 4** |
| Auth | `jsonwebtoken` (JWT), `otpauth` (TOTP 2FA admin) |
| Crypto mots de passe | `@noble/hashes` (argon2id + `timingSafeEqual`) |
| SMS OTP | `@vonage/server-sdk` (Nexmo) |
| Stockage audio | `@aws-sdk/client-s3` (Cloudflare R2 / S3) ou filesystem |
| Tests | `node:test` + `tsx` (natif, pas de framework) |

### Application mobile (`sabiData_frontend/`)
| Élément | Choix |
|---|---|
| Framework | **Flutter** (Dart), cible Android + iOS |
| Navigation | `go_router` |
| État | `provider` |
| HTTP | `http` + `http_parser` (multipart) |
| Audio | `record` (enregistrement AAC/M4A) + `audioplayers` (lecture) |
| Permissions / stockage | `permission_handler`, `path_provider`, `shared_preferences` |
| Réseau / offline | `connectivity_plus` (détection + resync auto) |
| Typographie | `google_fonts` (Plus Jakarta Sans, cache disque offline) |

### Console d'administration (`admin-web/`)
| Élément | Choix |
|---|---|
| Framework | **React 18** + **Vite 6** + TypeScript |
| Routing | `react-router-dom` 6 |
| Typographie | `@fontsource/inter`, `@fontsource/jetbrains-mono` |
| Design | Composants maison (`ui/`) + design tokens CSS (`ui/tokens.css`) |
| Tests | **Vitest** + Testing Library + jsdom |

---

## 3. Modèle de domaine

### 3.1 Rôles (RBAC) et permissions

Quatre rôles, source unique dans `backend/src/domain/roles.ts` (miroir de la
table `role_permissions`) :

| Rôle | Permissions |
|---|---|
| `contributor` | `contribute`, `validate` |
| `validator` | `contribute`, `validate` |
| `moderator` | `validate`, `content.read_any`, `content.moderate`, `dispute.arbitrate` |
| `admin` | `*` (toutes) |

Permissions granulaires disponibles : `contribute`, `validate`,
`content.read_any`, `content.moderate`, `dispute.arbitrate`, `reference.manage`,
`user.manage`, `wallet.read`, `wallet.adjust`, `withdrawal.settle`, `audit.read`,
`export.run`. Le garde central `can(principal, permission)` (`authz/can.ts`) est
le **seul** point de décision d'accès.

### 3.2 Niveau de compétence

Orthogonal au rôle : `CompetenceLevel` ordinal **0–3**. Ce n'est pas un droit
d'accès mais une donnée de **routage de contenu** — un validateur de compétence
faible ne se voit pas proposer les clips rares (réservés aux validateurs plus
qualifiés). Utilisé aussi pour le calcul du tier (`competenceForGold = 2`).

### 3.3 Cycle de vie d'un clip (machine à états)

`backend/src/curation/stateMachine.ts` — transitions autorisées uniquement :

```
pending ──▶ auto_checked ──▶ peer_review ──▶ validated
   │             │                │      └──▶ rejected
   └──▶ rejected └──▶ rejected    └──▶ disputed ──▶ validated | rejected
                                        (arbitrage admin)
```

- **auto-check** (D2) : durée dans `[minSeconds=1, maxSeconds=30]` s, sinon rejet.
- **consensus** (D3) : `net = correct − problem`. `net ≥ 2` → validé ; `net ≤ −2`
  → rejeté ; si le plafond de votes (`votesCap = 5`) est atteint sans consensus
  → `disputed` (litige arbitré par un modérateur/admin).

### 3.4 Qualité de transcription — tiers (D1)

`quality_tier` ∈ `gold | silver | bronze | raw`, calculé par `curation/tier.ts`
à partir du système d'écriture (`std`/`phon`), de la cohérence orthographique,
du nombre de votes `correct`/`problem`, et du juge final « colle à l'audio »
(`quorumAudio = 2`).

### 3.5 Économie (points → FCFA)

Constantes gelées dans `backend/src/config.ts` :

| Paramètre | Valeur |
|---|---|
| 1 point | **5 FCFA** |
| Récompense enregistrement | 50 pts (× multiplicateur de rareté) |
| Récompense validation | 20 pts |
| Récompense transcription | 80 pts |
| Récompense conversion (Bronze→Or) | 120 pts |
| Bonus tâche quotidienne | 250 pts |
| Multiplicateur de rareté | ×1 (commun), ×2 (rare), ×3 (très rare) |
| Retrait minimum | 500 FCFA |
| Niveaux gamifiés | Argent à 50 contributions validées, Or à 200 |
| Retrait verrouillé sous | niveau « Argent » |

**Ledger à deux phases** (`points_ledger`, états `provisional → confirmed →
reversed`) : une récompense est d'abord provisoire (clip en revue), confirmée à
la validation, ou annulée au rejet. C'est le cœur anti-fraude de l'économie.

---

## 4. Backend — API REST

Base : `/api` (mobile) et `/admin` (console). JSON partout sauf l'upload audio
(`multipart/form-data`). Auth : `Authorization: Bearer <access_jwt>`
(access TTL 1h, refresh 30j côté mobile). Erreurs :
`{ "error": { "code": "...", "message": "..." } }`.

### 4.1 Authentification mobile — `/api/auth/*`

| Méthode | Route | Description |
|---|---|---|
| POST | `/register` | Création par email + mot de passe (`name` ≥ 2, `password` ≥ 6). → `{ access, refresh, user }` |
| POST | `/login` | email+password (compte inscrit) **ou** `phone` seul (déclenche le flux OTP) |
| POST | `/otp` | Envoi d'un code SMS (ancre d'identité = numéro). Réponse constante (anti-énumération) |
| POST | `/verify` | Vérifie le code OTP, crée/connecte le compte |
| POST | `/refresh` | `{ refresh }` → nouvel `access`. Exclu du refresh-sur-401 |
| POST | `/logout` | Révoque le refresh (déconnexion réelle) |

### 4.2 Surface mobile protégée — `/api/*` (`authenticate('mobile')`)

| Méthode | Route | Description |
|---|---|---|
| GET | `/me` | Profil enrichi (nom, rôle, compétence, points, niveau, langue/dialecte/région, complétude) |
| POST | `/me/profile` | Met à jour langue, dialecte, région, consentement commercial |
| GET | `/me/wallet` | Portefeuille (points, solde FCFA, contributions validées, niveau) |
| GET | `/me/ledger` | Historique personnel des gains (antéchronologique) |
| GET | `/prompts/next` | Phrase suivante à enregistrer, **filtrée par `?lang=`** (insensible aux accents) |
| GET | `/leaderboard` | Top 10 national par points + position de l'utilisateur |
| POST | `/clips` | **Upload d'un clip** (`multipart` : `audio` + `promptId`, `rarity`, `durationS`, `commercialUse`, `consentVersion`, `language`, `dialect`, `region`) |
| GET | `/clips/:id/audio` | Flux audio d'un clip |
| GET | `/validation/next` | Clip suivant à valider (routé par compétence) |
| POST | `/clips/:id/validations` | Vote de validation (`correct`/`problem`/`unsure`) |
| GET | `/transcriptions/next` | Clip validé à transcrire (filtré langue/dialecte) |
| POST | `/transcriptions` | Soumet une transcription (RTB ou conversion Bronze→Or) |
| GET | `/classrooms/mine` | Groupes de collecte de l'utilisateur |
| POST | `/classrooms` | Crée un classroom |
| POST | `/classrooms/join` | Rejoint via un code (rate-limité, anti-énumération) |
| POST | `/classrooms/leave` | Quitte un classroom |

### 4.3 Public

| Méthode | Route | Description |
|---|---|---|
| GET | `/api/regions` | Couverture régionale agrégée (aucune PII) — alimente la carte des dialectes |

### 4.4 Authentification admin — `/admin/auth/*` (2FA)

| Méthode | Route | Description |
|---|---|---|
| POST | `/login` | email + mot de passe → défi TOTP |
| POST | `/totp` | Code TOTP (RFC 6238) → token admin (`aud: 'admin'`, TTL court 30 min) |

### 4.5 Surface admin — `/admin/*` (`authenticate('admin')` + `requirePerm`)

| Méthode | Route | Permission requise |
|---|---|---|
| GET | `/disputes` | `dispute.arbitrate` |
| POST | `/clips/:id/arbitrate` | `dispute.arbitrate` |
| GET | `/clips/:id/audio` | `content.read_any` |
| GET | `/audit-log` | `audit.read` |
| GET | `/users` | `content.read_any` (PII/solde masqués sans `wallet.read`) |
| POST | `/users` | `user.manage` |
| PATCH | `/users/:id` | `user.manage` (rôle, compétence, statut) |
| DELETE | `/users/:id` | `user.manage` |
| GET | `/users/:id/wallet` · `/ledger` | `wallet.read` |
| GET | `/users/:id/activity` | `audit.read` |
| POST | `/users/:id/adjustments` | `wallet.adjust` (ajustement manuel de solde) |
| GET | `/withdrawals` | `withdrawal.settle` |
| POST | `/withdrawals/:id/decide` | `withdrawal.settle` (approuver/rejeter) |

Toutes les mutations admin sont journalisées dans `audit_log` (immuable, lecture seule).

---

## 5. Application mobile (Flutter)

### 5.1 Parcours & écrans

**Démarrage / onboarding**
- `splash_screen` — révèle la marque sur motif textile, redirige selon l'état
  (authentifié → dashboard/profil ; sinon → onboarding/preview).
- `onboarding_screen` — 3 pages (mission culturelle, rareté des dialectes,
  récompenses réelles) sur motifs africains.
- `app_preview_screen` (`/preview`) — aperçu avant inscription.

**Authentification**
- `login_screen`, `register_screen` — email + mot de passe.
- `phone_login_screen`, `otp_screen` — connexion par téléphone + code SMS.
- `consent_screen` — acceptation de la politique (une seule fois).
- `profile_setup_screen` — langue(s) + dialecte + région (filtre les régions
  selon la langue principale).
- `skill_profile_screen` — niveau d'écriture (compétence linguistique).

**Contribution**
- `dashboard_screen` — accueil : dialecte actif, rareté, accès aux tâches.
- `recording_screen` — **enregistrement** : waveform temps réel, timer, phrase
  dynamique via `/prompts/next?lang=` (badge « Enregistrez en {langue} »).
- `recording_review_screen` — réécoute + envoi (`POST /clips`) ou mise en file
  offline.
- `validation_screen` — écoute un clip d'un pair et vote (correct/problème/incertain).
- `transcription_screen` — transcrit un clip validé (orthographe std/phon).
- `conversion_screen` — **conversion Bronze → Or** : réécrit une transcription
  bronze en orthographe standard (+120 pts).
- `expert_screen` (« Espace Linguiste ») — qualité du dataset par langue.
- `classroom_screen` — groupes de collecte (créer / rejoindre par code).

**Gamification & gains**
- `leaderboard_screen` — classement national.
- `dialect_map_screen` — **carte des dialectes** : halos de densité dimensionnés
  par les vrais volumes (`/api/regions`), pin « Vous » sur la région du profil,
  détail de la zone la plus sous-représentée avec bonus de rareté.
- `revenue_screen` — revenus.
- `profile_screen` — profil, historique, déconnexion.
- `withdraw_screen` — **retrait** Mobile Money (min 500 FCFA, niveau Argent requis).

### 5.2 Offline-first

- **Outbox** (`data/outbox/outbox_service.dart`) : un enregistrement fait
  hors-ligne est mis en file (blob copié dans `outbox/`, métadonnées dans
  `shared_preferences`). `connectivity_plus` déclenche une **synchronisation
  automatique** au retour du réseau.
- **Persistance du profil** (`DialectPrefs`) : langue, dialecte, région,
  onboarding/consentement/profil complétés survivent aux redémarrages — cold
  start correct hors-ligne.
- **Session** (`AuthSession`) : tokens restaurés au lancement, l'utilisateur
  reste connecté entre deux sessions ; refresh-sur-401 (sauf routes d'auth).
- **Classroom** distingue « échec de chargement » et « absence de groupe ».

### 5.3 Couche API mobile

`data/api/` : `api_client` (base + auth + refresh), `auth_api`,
`contribution_api`, `validation_api`, `transcription_api`, `wallet_api`,
`ledger_api`, `regions_api`, `classroom_api`. URL de base configurée dans
`api_config.dart` (IP LAN du backend, port 3000).

---

## 6. Console d'administration (React)

Application SPA protégée par 2FA. Session en `sessionStorage`
(`sabidata.admin.token`) : survit à un refresh de page, pas à la fermeture de
l'onglet ; **tout 401 purge le token** et renvoie au login.

### Pages (`admin-web/src/pages/`)

| Route | Page | Fonction |
|---|---|---|
| `/login` | `Login` | email + mot de passe + code TOTP |
| `/` | `Overview` | Tableau de bord (KPI) |
| `/disputes` | `Disputes` | File des litiges (clips `disputed`) → arbitrage validé/rejeté, écoute de l'audio |
| `/users` | `Users` + `UserDrawer` | Liste des utilisateurs ; tiroir de détail : rôle, compétence, statut (actif/suspendu/banni), portefeuille, activité, ajustement de solde, création/suppression |
| `/money` | `Money` | Retraits Mobile Money à régler (approuver/rejeter) |
| `/audit` | `Audit` | Journal d'audit immuable (filtres acteur/entité/action) |

Composants UI maison : `Badge`, `Button`, `Card`, `DataTable`, `Drawer`,
`EmptyState`, `Field`, `KpiCard`, `Modal`, `Toast` — pilotés par des design
tokens CSS.

---

## 7. Stockage & données

### 7.1 Où vivent les données

| Donnée | Service |
|---|---|
| **Utilisateurs** (profils, hash mot de passe, rôle, compétence, langue/dialecte/région) | **Neon Postgres** (table `users`) |
| Clips (métadonnées + `audio_path`), transcriptions, votes, ledger, retraits, audit | **Neon Postgres** |
| **Blobs audio bruts** (`clips/<uuid>.m4a`) | **Cloudflare R2** (bucket `sabi-audio`) |

La table `clips` ne stocke que le chemin relatif (`audio_path`) ; le fichier réel
est dans R2. En dev, PGlite (Postgres en mémoire) + filesystem (`var/audio/`)
remplacent Neon + R2 sans changement de code.

### 7.2 Tables (`backend/src/db/schema.sql`)

`users`, `classrooms`, `otp_codes`, `clips`, `transcriptions`, `votes`,
`points_ledger`, `withdrawals`, `audit_log` — plus les types énumérés
(`user_role`, `clip_status`, `verdict_type`, `ledger_state`, `ledger_reason`,
`writing_system`, `quality_tier`). Le schéma s'applique automatiquement au
premier démarrage (`ensureSchema`, idempotent).

### 7.3 Pourquoi Neon + R2

- **Neon** : Postgres serverless, offre gratuite (0,5 Go), driver `pg` standard,
  `schema.sql` s'applique tel quel.
- **Cloudflare R2** : 10 Go gratuits, **egress gratuit** (décisif : chaque clip
  est réécouté par validateurs et transcripteurs), API 100 % compatible S3.

### 7.4 Abstractions de stockage

- `AudioStore` (`storage/audioStore.ts`) : `FsAudioStore` (disque),
  `S3AudioStore` (R2/S3, client injectable), `InMemoryAudioStore` (tests). Toutes
  gardées contre le path traversal (`assertSafeSegment`).
- `Repo` / `SqlDb` : `PgRepo` (sur PGlite ou Pool `pg`), `InMemoryRepo` (tests).
  Requêtes 100 % paramétrées (`$1, $2…`) — pas d'injection SQL.

---

## 8. Sécurité

### 8.1 Authentification & autorisation
- **JWT à audience distincte** : `aud: 'mobile'` vs `aud: 'admin'` — un token
  mobile est refusé sur `/admin` et inversement.
- **Mobile** : access court (1h) + refresh long (30j), rôle/compétence relus en
  base au refresh.
- **Admin** : mot de passe + **TOTP 2FA** (RFC 6238), token à TTL court (30 min).
- **Mots de passe** : argon2id (paramètres OWASP) + sel aléatoire +
  `timingSafeEqual`.
- **OTP mobile** : généré par `crypto.randomInt` (CSPRNG).
- **Garde central** : chaque route admin passe par `requirePerm(...)`.

### 8.2 Fail-fast de production (`config/prodGuard.ts`)

Quand `NODE_ENV=production`, `assertProdSecurity()` **refuse de démarrer** si :
- `JWT_SECRET` est absent ou vaut le placeholder de dev (`dev-secret-change-me`)
  — sinon les tokens seraient forgeables ;
- `SMS_ENABLED ≠ true` — sinon `generateOtp()` renverrait « 0000 ».

De plus, le **seed admin de dev** (`admin@sabidata.bf` / `admin123` + secret TOTP
public) et l'affichage du TOTP courant sont **sautés** dès que `isProduction()`.
Vérifié : prod sans secrets → refus de boot ; prod configuré → login dev → 401 ;
dev → inchangé.

### 8.3 Anti-abus
- Rate-limit sur `/classrooms/join` (anti-énumération des codes).
- Réponses constantes sur l'envoi d'OTP (anti-énumération des numéros).
- Ledger à deux phases (provisoire → confirmé/annulé) contre la fraude aux points.

### 8.4 Points d'attention avant prod publique
- Provisionner un **vrai compte admin** (le seed n'existe plus en prod).
- **Rate-limiter la vérification OTP** (recommandé avant `SMS_ENABLED=true`).
- Envisager un OTP à 6 chiffres (espace de recherche ×100).

---

## 9. Configuration & déploiement

### 9.1 Variables d'environnement (`backend/.env`)

| Variable | Rôle |
|---|---|
| `JWT_SECRET` | Secret de signature JWT (obligatoire en prod) |
| `DATABASE_URL` | Postgres managé (Neon) — prioritaire |
| `DATABASE=pg` | Sinon PGlite (dev) |
| `AUDIO_DIR` | Répertoire audio filesystem (dev, défaut `var/audio`) |
| `S3_BUCKET`, `S3_ENDPOINT`, `S3_ACCESS_KEY_ID`, `S3_SECRET_ACCESS_KEY`, `S3_REGION`, `S3_PREFIX` | Stockage R2/S3 |
| `VONAGE_API_KEY`, `VONAGE_API_SECRET`, `VONAGE_FROM`, `SMS_ENABLED` | SMS OTP |
| `NODE_ENV` | `production` active le fail-fast |

Sélection au démarrage (log : `repo: … , audio: …`) :
- **Base** : `DATABASE_URL` (Neon) > `DATABASE=pg` (PGlite) > mémoire.
- **Audio** : `S3_BUCKET` (R2) > filesystem.

### 9.2 Lancer en local

```bash
# Backend (port 3000, accessible depuis un téléphone du LAN)
cd backend && npm install && npm run dev      # charge .env automatiquement

# Mobile
cd sabiData_frontend && flutter pub get && flutter run

# Admin web
cd admin-web && npm install && npm run dev
```

### 9.3 Vérifier les services de prod

```bash
cd backend
npx tsx --env-file=.env scripts/test-prod-services.ts
```
Teste la connexion Neon + R2 puis rejoue le flux API complet (inscription →
upload clip → relecture audio octet à octet).

---

## 10. Tests

| Composant | Commande | Couverture |
|---|---|---|
| Backend | `npm test` (dans `backend/`) | 112 tests `node:test` — logique métier, auth, stockage, repo, garde prod |
| Mobile | `flutter test` (dans `sabiData_frontend/`) | 33 tests widget/unit |
| Admin web | `npm test` (dans `admin-web/`) | Vitest + Testing Library |

Le projet suit le **TDD** (test rouge avant implémentation) et un **garde de
vérification** avant complétion.

---

## 11. Limites connues & feuille de route

- **Prompts** : catalogue codé en dur dans `server.ts` (20 phrases,
  mooré/dioula/fulfulde). Pas encore de prompts **gulmancema** ; à déplacer en
  table DB. Un profil dans une langue sans prompt reçoit un pool toutes langues
  confondues (fallback volontaire).
- **Carte des dialectes** : la couverture n'est pas filtrée par langue côté
  backend (le titre l'indique honnêtement).
- **Sécurité** : rate-limit OTP et OTP 6 chiffres restent à faire avant ouverture
  publique.
- **Retraits Mobile Money** : le flux d'arbitrage existe côté admin ; l'intégration
  d'un agrégateur de paiement réel reste à brancher.
- Les spécifications de conception détaillées vivent dans
  `docs/superpowers/specs/` et `docs/backend/` (api.md, schema.sql, delta-v2).

---

*Document généré à partir du code de la branche `feat/admin-console`. Pour toute
divergence, le code fait foi.*
              
---
---
---


#                         BY ABOULAYE OUEDRAOGO THE FUTUR BILLIONAIRE