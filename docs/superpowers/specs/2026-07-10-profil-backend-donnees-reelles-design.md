# Profil backend + données réelles (historique, carte, classement) — Design

Date : 2026-07-10
Branche : feat/admin-console

## Problème

Le profil linguistique (langue/dialecte/région/consentement) n'est stocké qu'en
local (SharedPreferences), device-global, et jamais réinitialisé par compte —
`DialectPrefs.clearUser()` n'est appelé nulle part. Conséquences observées :

1. **Formulaire de profil « toujours absent »** : dès qu'un compte a rempli le
   formulaire une fois sur l'appareil, `profile_setup_done=true` persiste pour
   tous les comptes suivants → le formulaire ne réapparaît jamais.
2. **« Valider » introuvable** : route d'activité bloquée par un gating basé sur
   cet état local incohérent.
3. **Impossible de classer les utilisateurs par langue/dialecte** : la table
   `users` n'a aucune de ces colonnes.
4. **Historique des gains statique** : aucun endpoint mobile n'expose le ledger
   personnel (`revenue_screen._history` est un mock).
5. **Carte des dialectes statique** : aucune route `/regions` (`dialect_map._coverage`
   est un mock).

## Objectif

Déplacer l'état du profil côté backend (source de vérité par compte), exposer les
données réelles nécessaires, et câbler le front — ce qui corrige le formulaire, le
gating, l'historique, la carte, et permet de classer les utilisateurs.

## Décisions (validées)

- **Activités gated** : enregistrer/valider/transcrire exigent `profileComplete`
  (langue + dialecte + région renseignés) **ET** `commercialConsent = true`. Skip
  ou refus du consentement → navigation en lecture seule.
- **Couverture régions** : calculée depuis les vrais `clips.region`, fusionnée avec
  un **catalogue statique des régions du BF** (pour afficher aussi les régions à 0
  clip). `coveragePct = clips / CONFIG.regionTargetClips`, plafonné à 1.
- **Classement utilisateurs** : périmètre léger — le leaderboard existant porte
  `language`/`dialect` par entrée (pas d'écran dédié).

## Architecture

### Backend

**`schema.sql` — `users`** : ajout de
```sql
language           text,
dialect            text,
region             text,
commercial_consent boolean NOT NULL DEFAULT false,
```

**Domaine `User`** : champs `language?`, `dialect?`, `region?`, `commercialConsent`
ajoutés au type et à `mapUser`.

**Repo `updateUser`** : accepte `language`, `dialect`, `region`, `commercialConsent`
(patch partiel, comme les champs existants).

**Endpoints mobiles** (`/api/*`, `authenticate('mobile')`) :
- `POST /me/profile` `{language, dialect, region, commercialConsent}` →
  `updateUser` → renvoie le profil à jour. Validation zod.
- `GET /me` enrichi : ajoute `language`, `dialect`, `region`,
  `commercialConsent`, et `profileComplete` (= les trois champs non nuls).
- `GET /me/ledger` → `{ entries: [{reason, delta, state, createdAt, refClipId?}] }`
  pour l'utilisateur courant (tri antéchronologique).
- `GET /regions` → `[{region, zone, clips, coveragePct}]`, calculé depuis les clips
  regroupés par région, fusionné avec le catalogue statique `CONFIG.regions`.

**`config.ts`** : `regionTargetClips: 1000` et `regions: [{name, zone}, …]`
(catalogue statique des régions/zones du BF, repris de la liste du profil).

**`leaderboard`** (`GET /leaderboard`) : chaque entrée porte `language`/`dialect`
(depuis le user) en plus de `points`.

**Repo — nouvelles lectures** : `countClipsByRegion()` (agrégat pour `/regions`).
`ledgerFor` existe déjà (réutilisé pour `/me/ledger`).

### Frontend

**`profile_setup_screen`** : `_completeSetup` POST vers `/api/me/profile`
(langue/dialecte/région/consent) en plus de `DialectPrefs.save` local. En cas
d'échec réseau, garde le local (best-effort) mais le gating fiable vient du backend.

**`UserProfile` (auth_session)** : ajoute `profileComplete` (bool),
`commercialConsent` (bool), `language`/`dialect`/`region` (String?) parsés de
`/api/me`.

**Gating (`router.dart` + `splash_screen`)** : lisent `profileComplete` et
`commercialConsent` du profil backend (chargé via `refreshMe`/`/api/me`) plutôt que
le seul flag local. Les routes d'activité exigent `profileComplete && commercialConsent`.

**`AuthApi`** : `clearUser()` (DialectPrefs) appelé au login pour repartir de
l'état backend du compte connecté.

**`revenue_screen`** : `_history` mock remplacé par `GET /api/me/ledger` (libellé
par raison, +/− points, date, état provisoire/confirmé).

**`dialect_map_screen`** : `_coverage` mock remplacé par `GET /api/regions`.

## Flux de données

```
login → clearUser() → refreshMe() (GET /me) → profileComplete?
  non → /profile-setup → POST /me/profile → refreshMe → profileComplete=true
  oui → /dashboard
activités : router exige profileComplete && commercialConsent (source /me)
revenus  : GET /me/ledger → historique réel
carte    : GET /regions → couverture réelle (clips.region + catalogue)
```

## Gestion des erreurs

- `POST /me/profile` : 400 (zod) si champs invalides ; le front affiche un snack et
  ne marque pas le profil complet.
- `GET /me/ledger` / `GET /regions` : en cas d'échec, écrans gardent un état vide/
  « — » sans crash.
- Backend : `profileComplete` calculé, jamais écrit à la main.

## Tests

- **Backend (unit)** : `updateUser` persiste les 4 champs ; `GET /me` renvoie
  `profileComplete` correct (false si un champ manque) ; `POST /me/profile` valide et
  enregistre ; `/me/ledger` renvoie les entrées du bon user ; `/regions` agrège les
  clips par région + fusionne le catalogue (région à 0 clip présente).
- **Front** : `flutter analyze` propre ; test device (nouveau compte → formulaire
  s'affiche, gating bloque les activités, Valider s'ouvre après remplissage,
  historique et carte affichent des données réelles).

## Hors périmètre

- Écran/endpoint dédié « utilisateurs par dialecte » (le leaderboard porte les
  champs, suffisant pour l'instant).
- Persistance sécurisée du token (AuthSession reste en mémoire, re-login par session).
- Backfill des utilisateurs existants (champs NULL → profil à recompléter, acceptable
  en WIP).
