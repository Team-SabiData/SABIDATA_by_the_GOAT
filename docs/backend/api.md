# SabiData — Spécification API (REST)

Reconstruite depuis le frontend Flutter (mocks) + recherche (README, doc tiers).
Intègre les décisions gelées **D1** (tiers), **D2** (auth multi-méthode),
**D3** (quorum validation), **D4** (points/FCFA 2 phases).

**Tags** : `[OBS]` lu dans le code · `[RECH]` recherche · `[INF]` déduit · `[DÉC]` décision gelée.

## Conventions
- Base : `/api/v1` (cible). **Implémenté actuellement : `/api` sans version** (mobile) et `/admin` (console). JSON sauf upload audio (`multipart/form-data`).
- Auth : `Authorization: Bearer <access_jwt>` (TTL 1h) ; refresh 30j. `[DÉC] D2`
- Idempotence des écritures sensibles via header `Idempotency-Key` **ou** champ `client_uuid`. `[DÉC] D7`
- Erreurs : `{ "error": { "code": "...", "message": "..." } }`.
- Codes transverses : `400` payload, `401` non authentifié, `403` rôle insuffisant, `404` introuvable, `409` conflit/idempotence, `422` règle métier, `429` rate-limit, `503` indisponible (→ file offline côté client).

---

## 1. Authentification `[OBS] D2`

### POST /auth/register
Crée un compte par identifiants. → vérification téléphone requise avant retrait.
- Auth : non. Req : `{ "name", "email", "password" }` (`password` ≥ 6 `[OBS]`).
- 201 : `{ "access", "refresh", "user" }`
- Erreurs : `409 EMAIL_TAKEN`, `422 WEAK_PASSWORD`.

### POST /auth/login
- Auth : non. Req : `{ "email", "password" }`.
- 200 : `{ "access", "refresh", "user" }` · `401 INVALID_CREDENTIALS` · `429`.

### POST /auth/otp
Envoie un code SMS (ancre d'identité = MSISDN). `[RECH]`
- Auth : non. Req : `{ "phone": "+226..." }`.
- 202 (toujours, anti-énumération) · `429 TOO_MANY_REQUESTS`.

### POST /auth/verify
Vérifie le code ; crée le `user`+`auth_identity(phone)` si nouveau, sinon **lie/connecte**. `[DÉC] D2`
- Auth : non. Req : `{ "phone", "code" }`.
- 200 : `{ "access", "refresh", "user" }` · `401 BAD_CODE` · `410 CODE_EXPIRED`.

### POST /auth/refresh · POST /auth/logout
- `refresh` : Req `{ "refresh" }` → 200 `{ "access" }` · `401`.
- `logout` : Bearer → 204 (révoque le refresh).

---

## 2. Profil & préférences `[OBS]`

### GET /me
- Auth : oui. 200 :
```json
{ "id","name","phone","email","role","commune","region",
  "points_total": 1240, "balance_fcfa": 2750, "validated_count": 67,
  "badge_tier": "bronze", "notif_enabled": true,
  "languages": ["moore","dioula"], "dialect": {"region":"Yatenga","zone":"Nord"} }
```
> `points_total`, `balance_fcfa`, `validated_count`, `badge_tier` sont **dérivés** (vues `v_user_*`). `[INF]`

### PUT /me/preferences · /me/languages · /me/skills · /me/dialect
- Auth : oui. Req resp. `{ "notif_enabled" }` · `{ "codes": [] }` · `{ "language","can_speak","can_read","write_level" }` · `{ "region","commune" }`.
- 200 `{ "user" }` · `400` · `422`.

---

## 3. Référentiel (lecture) `[OBS]`

| Endpoint | Réponse | Notes |
|---|---|---|
| `GET /languages` | `[Language]` | 4 items, sans pagination |
| `GET /regions?language=` | `[{id,name,zone,rarity_tier,clips_count,coverage_pct}]` | clips/pct **dérivés** (`v_region_coverage`) |
| `GET /coverage?language=` · `/coverage/me` | choroplèthe + empreinte | écran carte |
| `GET /prompts/next?language=` | `Prompt` ou `204` | file d'enregistrement |

---

## 4. Collecte : enregistrement `[OBS]`

### POST /clips  (multipart)
Soumet un enregistrement (remplace l'ancien `pop()` qui jetait l'audio).
- Auth : oui. Body : `audio` (fichier), `promptId`, `rarity` (0–2), `durationS`, `commercialUse`, `consentVersion`, et la classification issue du profil : `language`, `dialect`, `region`. Ces trois derniers sont persistés sur le clip → regroupement des audios par langue/dialecte en BD.
- 201 : `{ "clip_id", "status": "pending", "reward": 150 }`
  - `reward` = `reward_record × rarity_mult` (D4 : ×3 si dialecte très rare). Crédit **provisoire**. `[DÉC]`
- Erreurs : `409 DUPLICATE` (client_uuid), `413 TOO_LARGE`, `415 BAD_FORMAT` (D6).

### GET /validation/next
- Auth : oui. 200 : `{ clip_id, audio_url, prompt, position, total }` · `204` (file vide → état vide UI).

### POST /clips/{id}/validations  `[OBS] D3`
Enregistre un verdict ; recalcule `clip.status` (quorum) et le tier si pertinent.
- Auth : oui. Req : `{ "verdict": "correct|problem|unsure" }`.
- 201 : `{ "status": "pending|validated|rejected|escalated", "reward": 20 }`
  - Validation créditée **confirmée** immédiatement (l'acte = contribution). `[DÉC] D4`
- Erreurs : `409 ALREADY_VOTED` (unique cible+validateur), `404`.
- Règle D3 : ≥2 votes, net ≥ +2 validé / ≤ −2 rejeté, 5 votes sans consensus → `escalated`.

---

## 5. Transcription & qualité `[OBS] [RECH]`

### GET /transcription/next
- Auth : oui. 200 : `{ archive: {title,year,language}, audio_url, prefill?, position, total }`.

### POST /transcriptions  `[RECH] D1`
Crée une transcription (RTB) **ou** une conversion (avec `parent_id`).
- Auth : oui (rôle `standard_reviewer`/`expert` requis si `parent_id` présent — D11). `[DÉC]`
- Req : `{ "target_id", "target_type": "archive|clip", "text", "writing_system": "std|phon", "parent_id"? }`.
- 201 : `{ "id", "tier": null, "reward": 80 }` (ou `120` si conversion).
  - `tier`/`matches_audio` restent `null` jusqu'au quorum de relecture (calculés par trigger). `[RECH]`
- Erreurs : `403 ROLE_REQUIRED`, `404`.

### GET /dataset/tiers?language=  `[OBS]`
- Auth : oui (`standard_reviewer`/`expert`). 200 : `[{ "tier": "gold|silver|bronze|raw", "count": 312 }]` (vue `v_dataset_tiers`).

### GET /conversion-tasks?status=open&page=  ·  GET /conversion-tasks/{id}
File des bronze→or (écran Expert). `[RECH]`
- Auth : oui (`standard_reviewer`/`expert`). 200 : `[{ id, language, dialect, snippet, duration }]` / détail `{ audio_url, phonetic_text }`.
- La soumission de la conversion = `POST /transcriptions` avec `parent_id` → la donnée peut atteindre **Or**.

---

## 6. Économie `[OBS] D4`

### GET /me/wallet
- Auth : oui. 200 : `{ "balance_fcfa": 2750, "min": 500, "providers": ["orange_money","moov_money","wave"], "phone_verified": true }`.

### POST /withdrawals
- Auth : oui. **Pré-requis : téléphone vérifié** (D2). Req : `{ "amount", "provider", "client_uuid" }`.
- 202 : `{ "id", "status": "processing", "eta_hours": 24 }`
- Erreurs : `403 PHONE_NOT_VERIFIED`, `400 BELOW_MIN` (<500), `409 INSUFFICIENT_BALANCE` (solde **confirmé** uniquement), `409 DUPLICATE`.

### GET /me/earnings?month=&page=  ·  GET /me/activity?limit=  ·  GET /me/daily-task
- Auth : oui. Historique FCFA / feed (`v_activity`) / tâche du jour (`progress` dérivé). Pagination par curseur. `[DÉC] D8`

---

## 7. Communauté `[OBS]`

### GET /leaderboard?scope=commune|region|national&page=  ·  GET /me/rank
- Auth : oui. 200 : `[{ rank, name, points }]` (vue `v_leaderboard`, filtrée par `commune`/`region` de l'utilisateur).

---

## 8. B2B Classroom — différé (D10) `[OBS] [DÉC]`
Schéma posé, **économie non figée**. Endpoints prévus :
- `GET /classroom/challenge` · `GET /classroom/leaderboard` · `POST /classroom/join { code }` → `200` / `404 BAD_CODE`.
> Bloqué par D10 (modèle de licence/usage/récompense B2B).

---

## 8bis. Surface Admin `/admin/*` `[OBS]` — implémentée (console « Salle de contrôle »)

Surface **séparée** du mobile : base `/admin` (sans `/v1`), audience JWT `admin`.
Auth en deux temps (D3) : mot de passe **puis** TOTP ; aucun token sans 2FA.
Toute **écriture** est gardée par une permission (garde central `can()`) et
consignée au **journal d'audit immuable** avec un **motif obligatoire**
(`400 REASON_REQUIRED` sinon). Garde-fous anti-lockout : `409 SELF_FORBIDDEN`
(action sur soi-même), `409 LAST_ADMIN` (retirer le dernier admin actif).
Un compte `suspended|banned|deleted` est refusé à la connexion (`403 ACCOUNT_DISABLED`),
y compris dans la fenêtre entre les deux étapes admin.

### Authentification admin
- `POST /admin/auth/login { email, password }` → `{ challenge }` (aucun token) | `401 INVALID_CREDENTIALS` | `403 ACCOUNT_DISABLED`.
- `POST /admin/auth/totp { challenge, code }` → `{ access }` (session courte) | `401 BAD_TOTP` | `403 ACCOUNT_DISABLED`. Chaque succès écrit un audit `login` (`metadata.channel = 'admin'` ; le login mobile écrit `'mobile'`).

### Utilisateurs & gouvernance
| Route | Perm | Corps → Réponse |
|---|---|---|
| `GET /admin/users` | `content.read_any` | `{ users:[{id,name,role,competence,status,email,phone,balanceFcfa,lastLoginAt}] }` — `email/phone/balanceFcfa/lastLoginAt` **nuls** sans `wallet.read` (modérateur) |
| `POST /admin/users` | `user.manage` | `{ name, email?|phone?, role, password? }` → `201 { id,name,role }` |
| `PATCH /admin/users/:id` | `user.manage` | `{ status, reason }` (suspend/ban/réactive) **ou** `{ role?, competence?, reason }` (changement de rôle gardé) → `{ id,status }` \| `{ id,role,competence }` |
| `DELETE /admin/users/:id` | `user.manage` | `{ reason }` → `{ id, status:'deleted' }` — **suppression douce anonymisée** (nom→« Utilisateur supprimé », email/phone effacés ; ledger & audit conservés) |
| `GET /admin/disputes` | `dispute.arbitrate` | `{ disputes:[{id,durationS,rarity}] }` |
| `POST /admin/clips/:id/arbitrate` | `dispute.arbitrate` | `{ result:'validated'|'rejected', reason }` → `{ status, reason }` |
| `GET /admin/clips/:id/audio` | `content.read_any` | flux audio (`audio/*`) du clip en litige (le pendant mobile exige l'audience `mobile`) |

### Argent & retraits `D4`
| Route | Perm | Corps → Réponse |
|---|---|---|
| `GET /admin/users/:id/wallet` | `wallet.read` | `{ pointsTotal, pointsPending, balanceFcfa, min, providers }` |
| `GET /admin/users/:id/ledger` | `wallet.read` | `{ entries:[LedgerEntry] }` (append-only) |
| `POST /admin/users/:id/adjustments` | `wallet.adjust` | `{ delta (±, ≠0), reason }` → `{ pointsTotal }` — **nouvelle** ligne ledger `admin_adjustment` (jamais d'édition) |
| `GET /admin/withdrawals?status=` | `withdrawal.settle` | `{ withdrawals:[Withdrawal] }` |
| `POST /admin/withdrawals/:id/decide` | `withdrawal.settle` | `{ decision:'approved'|'rejected', reason }` → `{ status:'paid'|'failed' }` — refus = re-crédit `withdrawal_refund` |

> Cohérence money : le **débit** des points a lieu à la **création** du retrait
> (`WalletService.requestWithdrawal`, réf. mobile `POST /withdrawals` §6, ligne
> ledger `withdrawal`) ; l'approbation le laisse débité, le refus re-crédite —
> net nul. La route mobile de création n'est pas encore branchée (`[INF]`).

### Traçabilité
| Route | Perm | Réponse |
|---|---|---|
| `GET /admin/audit-log?actor=&entity=&action=` | `audit.read` | `{ entries:[AuditEntry] }` — journal immuable, filtrable ; actions : `login`, `user.create/update/status/delete`, `wallet.adjust`, `withdrawal.decide`, `clip.arbitrate` |
| `GET /admin/users/:id/activity` | `audit.read` | `{ entries:[AuditEntry] }` — connexions + actions de/sur l'utilisateur |

**Permissions** (miroir `domain/roles.ts`) : `content.read_any`, `dispute.arbitrate`,
`user.manage`, `wallet.read`, `wallet.adjust`, `withdrawal.settle`, `audit.read` —
l'admin les a toutes (`*`) ; le modérateur a `content.read_any`/`dispute.arbitrate`
mais **ni** l'argent **ni** la gestion des comptes.

---

## 9. Règles transverses (rappel décisions)
- **D1** Tier = `writing_system` × votes × cohérence ; juge final « colle à l'audio » ; bronze→tâche de conversion. Calculé par triggers, jamais écrit à la main.
- **D2** Une identité `User`, plusieurs `auth_identity` (phone=ancre) ; téléphone vérifié requis avant retrait.
- **D3** Statut clip par consensus net (≥2 votes, ±2, escalade à 5).
- **D4** Points en 2 phases (provisoire à la soumission → confirmé à la validation, reversé si rejet) ; 1 pt = 5 FCFA ; rareté ×1/×2/×3 sur l'enregistrement.

## 10. Reste ouvert (non bloquant pour démarrer)
- **D5** offline/sync (queue, conflits) · **D6** médias (codec, upload pré-signé, transcodage) · **D8** pagination (curseur) · **D9** déclencheurs d'états vides/erreur par endpoint · **D10–D14** B2B, rôles fins, paiements CinetPay/FedaPay, push, i18n.
