# SabiData — DELTA v2 : réconciliation 2 clients (mobile + admin web)

Applique les décisions **1 RBAC**, **2 Curation**, **3 Auth admin**, **4 Exports/consentement**.
À lire après `api.md` (v1, dérivé sous client unique).
Tags : `[DÉCIDÉ]` utilisateur · `[RÉVISÉ]/[NOUVEAU]/[CONSERVÉ]` vs v1 · `[INFÉRÉ]`.

---

## 1. RBAC — rôle + niveau de compétence `[DÉCIDÉ]`

- `role` (enum grossier) : **contributor | validator | moderator | admin** — gère **l'accès**.
- `competence_level` (ordinal 0-3, séparé) : route **quel contenu** un validateur peut traiter (niveau 1 ≠ niveau 3). **Donnée, pas moteur de permissions.**
- Table `role_permissions` = **source unique** rôle→droits (pas de guards éparpillés).
- Garde central : `can(role, permission)` lit `role_permissions` (`admin='*'`). `requireCompetence(n)` lit `users.competence_level` pour le routage de contenu.

## 2. Curation — machine à états backend `[DÉCIDÉ]`

```
pending ──auto-check(format/durée/silence)──▶ auto_checked ──▶ peer_review
   │                                                   (routée par competence_level)
   └─échec──▶ rejected                                         │
                                  consensus N concordants ─────┼──▶ validated
                                                               ├──▶ rejected
                                  litige / cap atteint ────────┴──▶ disputed ──▶ admin-web (arbitrage)
```
- **Verrou** : l'état de validation vit **uniquement dans le backend**, jamais dans un client. `[DÉCIDÉ]`
- Le **volume** part aux validateurs mobiles (scale). L'**admin-web** ne touche que `disputed` + la gouvernance des validateurs (pas de goulot).
- `escalated` (v1) → **`disputed`** (v2). Auto-check = transition modélisée ; le calcul média réel est un job (D6).

## 3. Auth — asymétrie franche `[DÉCIDÉ]`

| | Mobile (user) | Admin (web) |
|---|---|---|
| Namespace | `/api/auth/*` | `/admin/auth/*` (séparé) |
| Méthode | OTP téléphone **ou** email (friction mini) | email + password **+ TOTP 2FA obligatoire** |
| Session | access 1h / refresh 30j | **courte (~30 min)** + recovery codes |
| Audit | non | **journal immuable** de chaque action |
| SSO/SAML | — | **reporté** (enterprise) |

Nouveaux endpoints admin auth :
- `POST /admin/auth/login` {email,password} → `200 {challenge:"totp"}` (jamais de token sans 2FA) · `401`.
- `POST /admin/auth/totp` {challenge,code} → `200 {access}` (session courte) · `401`/`429`.
- `POST /admin/auth/recovery` {email,recovery_code} → `200` · `401`.
- `POST /admin/auth/logout` → `204`.

## 4. Exports — consentement maintenant, format bloqué `[DÉCIDÉ]`

- **§8.6 reste BLOQUÉE-SUR-ACHETEUR** : pas de table ni d'endpoint d'export tant qu'un acheteur nommé + spec écrite n'existent pas. On ne la dessine pas.
- **Construit maintenant** (invariant légal, immuable, circule jusqu'à l'export) : à `POST /clips`, capture **consentement explicite**, **usage commercial**, **provenance** (qui/quand/appareil/langue), **tag de licence** — write-once.

---

## 5. Contrats RÉCONCILIÉS (chaque contrat v1 re-dérivé)

| Contrat v1 | Classe | Rôle / compétence | Delta |
|---|---|---|---|
| `/api/auth/*` | user | public | + claim `role` & `competence_level` dans le JWT |
| `/admin/auth/*` | **admin** | public→admin | **NOUVEAU** (2FA, session courte) |
| `GET /me`, `PUT /me/*` | user | contributor (self) | **CONSERVÉ** |
| `POST /clips` | user | contributor | **RÉVISÉ** : body + `consent{commercial_use, version}`, `provenance` ; réponse + `license_tag` (immuable). Statut initial `pending`→auto-check |
| `GET /validation/next` | user | validator | **RÉVISÉ** : filtré `required_competence ≤ caller.competence_level` (routage décision 1/2) |
| `POST /clips/{id}/validations` | user | validator | **RÉVISÉ** : snapshot `reviewer_competence` ; pilote la machine à états (peer_review→validated/rejected/disputed) |
| `POST /transcriptions` | user | validator (`parent_id` ⇒ competence ≥ seuil) | **RÉVISÉ** : gating par compétence, plus par "expert" |
| `GET /dataset/tiers` | **admin/validator** | competence ≥ seuil **ou** moderator | **RÉVISÉ** : curation = admin/haute compétence |
| `GET /conversion-tasks` | user | validator (competence ≥ seuil) | **RÉVISÉ** |
| `POST /withdrawals` | user | contributor (phone_verified) | **CONSERVÉ** ; cycle `paid/failed` retiré du périmètre user |
| `GET /leaderboard`, `/me/*` éco | user | contributor | **CONSERVÉ** |
| `GET /languages`, `/regions` | partagé (lecture) | public | mutation → admin (NOUVEAU) |

## 6. Contrats NOUVEAUX (admin)

- `GET /admin/users?query=&page=` — moderator+ → liste complète + PII · 200/403.
- `PATCH /admin/users/{id}` — admin → `{role?, competence_level?, status?}` → 200, **journalisé** · 422.
- `GET /admin/disputes` — moderator → file des clips/transcriptions `disputed` · 200.
- `POST /admin/clips/{id}/arbitrate` — moderator → `{result: validated|rejected, reason}` → 200, journalisé.
- `POST /admin/clips/{id}/moderate` — moderator → `{action: flag|hide|remove|restore, reason}` → 200, journalisé.
- `POST /admin/withdrawals/{id}/settle` — admin → `{result: paid|failed, ref}` → 200, idempotent, journalisé · 409.
- `POST /admin/languages` · `PUT /admin/regions/{id}` · `POST /admin/prompts` — admin → CRUD référentiel.
- `GET /admin/audit-log?actor=&entity=` — admin → journal (lecture seule, immuable).
- `GET /admin/validators` / `PATCH /admin/validators/{id}` — admin → **gouvernance des validateurs** (ajuste `competence_level`) — décision 2.

---

## 7. Matrice d'authz (rôle × opération)

| Opération | contributor | validator | moderator | admin |
|---|---|---|---|---|
| Contribuer (clip/transcription) | ✅ | ✅ | — | — |
| Valider (peer_review) | — | ✅ (≤ son niveau) | ✅ | ✅ |
| Convertir bronze→or | — | ✅ (competence ≥ seuil) | ✅ | ✅ |
| Lire données d'autrui | — | — | ✅ | ✅ |
| Modérer / arbitrer `disputed` | — | — | ✅ | ✅ |
| CRUD référentiel | — | — | ➖ (décision) | ✅ |
| Régler un retrait | — | — | — | ✅ |
| Gérer users / rôles / compétence | — | — | — | ✅ |
| Exporter le dataset | — | — | — | 🔒 **bloqué (acheteur)** |

---

## 8. Impacts MOBILE (à ne pas oublier — front Dart existant)

- **NOUVEL écran/étape de consentement** sur le chemin d'enregistrement (`/recording`) : case usage commercial + texte de licence versionné, **avant** `POST /clips`. `[DÉCIDÉ 4]` (sinon l'invariant légal n'est jamais capturé).
- **File de validation routée** : `/validation/next` ne renvoie que du contenu `required_competence ≤ competence_level`. `[DÉCIDÉ 1/2]`
- L'écran `/expert` actuel devient gouverné par `competence_level` (pas un rôle "expert" figé).
- Le statut de validation **disparaît** de tout état client (il était mock) : le mobile lit l'état, ne le possède pas. `[DÉCIDÉ 2]`

## 9. Manques restants (inchangés, repriorisés)
🔴 authz runtime · transactions atomiques (vote↔statut↔ledger) · auto-check média (D6, job)
🟠 idempotence · pagination curseur · états admin (vide/erreur)
🟡 offline/sync · notifications · i18n · **export (bloqué acheteur)** · B2B (D10)

## 10. Plan de migration (coût croissant ; ce qui casse)
1. `delta-v2.sql` sur le schéma (rien en prod → sans risque).
2. Déplacer Flutter → `mobile/` (casse les chemins, mécanique).
3. Coder le **garde central** `role_permissions` + JWT claims **avant** tout endpoint.
4. Implémenter la machine à états curation (backend) + auto-check (job média).
5. Auth admin (2FA) + audit immuable.
6. **Ajouter l'écran de consentement mobile** + brancher `POST /clips` réel.
7. Construire `admin-web` (disputes, modération, users, référentiel, settle retraits).
8. Export : **ne rien faire** tant qu'acheteur + spec absents.
