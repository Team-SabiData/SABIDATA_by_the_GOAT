# SabiData — Monorepo

Collecte crowdsourcée de données audio en langues nationales burkinabè
(mooré, dioula, fulfuldé, gulmancema). Backend partagé servant **deux clients
à privilèges asymétriques** : mobile (contribution) et admin web (gouvernance).

## Structure

```
SABIDATA/
├── sabiData_frontend/   # App mobile Flutter (Dart) — contributeurs
├── backend/             # API partagée (TypeScript / Fastify / Postgres)
│                        #   /api/* (mobile)  +  /admin/* (admin web)
├── admin-web/           # Console d'administration (React + Vite + TS)
└── docs/backend/        # Conception : schema.sql, api.md, delta-v2.*
```

## Démarrage rapide

### Backend (port 3000)
```bash
cd backend
npm install
DATABASE=pg RUN_SERVER=1 ./node_modules/.bin/tsx src/server.ts   # Postgres (PGlite)
# tests : node --test --import tsx src/*.test.ts
```
Le serveur écoute sur `0.0.0.0:3000` (accessible depuis un téléphone du LAN).
L'audio validé est stocké sur disque (`backend/var/audio/<clipId>.<ext>`, hors git) ;
upload mobile en `multipart/form-data` sur `POST /api/clips`.

> ⚠️ **Identifiants de dev uniquement** (à retirer avant toute mise en prod) :
> admin `admin@sabidata.bf` / `admin123` ; le **vrai code TOTP** (RFC 6238) est
> affiché au démarrage (`[dev] admin TOTP courant : ...`) — copier ce code
> (valide ~30 s) à l'étape 2FA ; OTP mobile figé à `0000` ; secret JWT par défaut
> `dev-secret-change-me`.

### Mobile (Flutter)
```bash
cd sabiData_frontend
flutter pub get
flutter run            # ou: flutter build apk --debug
```
URL backend configurée dans `lib/data/api/api_config.dart`
(`http://192.168.100.189:3000` pour un téléphone sur le même Wi-Fi).

### Admin web — console « Salle de contrôle »
```bash
cd admin-web
npm install
npm run dev            # proxy /api /admin → :3000
# tests : npx vitest run
```
Back-office sombre (thème distinct du mobile). Connexion mot de passe **puis**
TOTP. Couvre : vue d'ensemble (KPI), arbitrage des litiges avec écoute du clip,
**gestion des utilisateurs** (créer / suspendre / bannir / supprimer en douceur
anonymisé), **contrôle de l'argent** par utilisateur (portefeuille, ledger,
ajustements manuels append-only, décision des retraits) et **journal d'audit**
filtrable (toute écriture admin + connexions) exportable en CSV. Chaque action
d'écriture exige un motif journalisé ; garde-fous anti-lockout (pas d'action sur
soi-même, jamais le dernier admin).

## Architecture (décisions clés)
- **RBAC** : rôle (`contributor|validator|moderator|admin`) + `competence_level` ordinal.
- **Curation** : machine à états backend `pending→auto_checked→peer_review→validated|rejected|disputed`.
- **Auth asymétrique** : mobile OTP/email ; admin email+password+TOTP.
- **Tiers de qualité** : `std/phon` × votes × cohérence, juge final « colle à l'audio ».
- **Consentement** : licence immuable capturée à la contribution (décision RGPD/dataset).
- **Traçabilité admin** : journal d'audit immuable (append-only) — toute action de
  gouvernance et chaque connexion y sont consignées ; le ledger de points est
  lui aussi append-only (un ajustement/remboursement = nouvelle ligne, jamais d'édition).

Détails conception : `docs/backend/`. Specs & plans de mise en œuvre :
`docs/superpowers/specs/` et `docs/superpowers/plans/` (audio multipart, refonte
mobile « Griot », console admin « Salle de contrôle »).
