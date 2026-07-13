# Spec — Audio multipart bout-en-bout (POST /clips)

Date : 2026-07-01 · Statut : approuvé (design) · Décisions cadre : D4, D6 (partiel).

## Problème

Le cycle de collecte audio est rompu de bout en bout :

- **Mobile** — `recording_screen.dart` n'enregistre aucun son : c'est une waveform
  animée + un compteur de secondes. `contribution_api.dart` poste du **JSON**
  (metadata seule) via `ApiClient.post`. Aucun fichier n'est jamais transmis.
- **Backend** — `POST /api/clips` (`contributionRoutes.ts`) parse `ClipReq`
  (metadata) ; `@fastify/multipart` n'est pas enregistré ; `ContributionService`
  ne stocke aucun blob. La table `clips` n'a pas de colonne audio.

Conséquence : on crédite des points (ledger D4) pour un enregistrement **qui
n'existe pas**. C'est exactement le bug que la spec `docs/backend/api.md §4`
prétendait corriger (« remplace l'ancien `pop()` qui jetait l'audio »).

## Objectif

Faire circuler un vrai fichier audio sur tout le cycle :

```
record mic (mobile) → POST /api/clips (multipart) → stockage fichier (backend)
   → GET /api/clips/:id/audio → réécoute par le validateur (mobile)
```

Le validateur doit **réellement réécouter** le clip enregistré par un autre
contributeur avant de voter.

## Décisions figées (ce brainstorming)

1. **Périmètre** : cycle complet, réécoute validateur incluse.
2. **Stockage** : système de fichiers serveur, chemin persisté sur le clip
   (`clips.audio_path`). Interface `AudioStore` pour rester swappable (S3 = D6).
3. **Stocker seulement si l'autocheck passe** : un clip `rejected` ne conserve
   pas de fichier audio.
4. **Plafond de taille** : 10 Mo → au-delà `413 TOO_LARGE`.
5. **Formats acceptés** : conteneurs audio courants (`m4a`/`aac`, `mp3`, `wav`,
   `ogg`) ; sinon `415 BAD_FORMAT`.
6. **Waveform décorative** : pas d'amplitude live (hors périmètre).

## Hors périmètre (items roadmap distincts)

- Refresh token / relogin sur 401 (D2).
- File offline / sync (D5).
- Transcodage serveur, upload pré-signé (D6).
- Amplitude live de la waveform d'enregistrement.
- Transaction atomique `submitVote`/`submitClip` (P0 séparé).

## Architecture

### Flux
```
┌─ MOBILE ─────────────┐  POST /api/clips        ┌─ BACKEND ───────────────┐
│ recording_screen     │  (multipart:            │ @fastify/multipart      │
│   AudioRecorder →.m4a │   audio + champs) ─────▶│  parse file + meta      │
│ recording_review     │                         │  ClipReq (fields)       │
│   audioplayers play   │                         │  autocheck              │
│   submit → upload     │                         │   pass → AudioStore.save│
│                       │                         │   fail → discard        │
│ validation_screen     │  GET /clips/:id/audio   │  setClipAudio(path)     │
│   réécoute le clip    │◀─────────────────────── │  GET → openRead/sendFile│
└───────────────────────┘                         └─────────────────────────┘
```

### Unités backend

**`storage/audioStore.ts`** — nouvelle unité isolée.
- Interface `AudioStore` :
  - `save(clipId: string, buffer: Buffer, ext: string): Promise<string>` → chemin relatif stocké.
  - `openRead(clipId: string, ext: string): Promise<Readable | null>` (ou renvoie null si absent).
  - `pathFor(clipId: string, ext: string): string`.
- Implémentation `FsAudioStore` : écrit sous `CONFIG.audioDir` (défaut `var/audio/`).
  Nom de fichier = `<clipId>.<ext>`. Crée le dossier si absent.
- `CONFIG.audioDir` ajouté à `config.ts` (env `AUDIO_DIR`, défaut `var/audio`).
- `var/` ajouté au `.gitignore` du backend.
- Dépend uniquement de `fs`/`path` — testable en isolation avec un dossier temp.

**`POST /api/clips` (multipart)** — `contributionRoutes.ts` + `server.ts`.
- Enregistrer `@fastify/multipart` (limite fichier 10 Mo).
- Lire la part fichier `audio` (buffer + mimetype/filename → ext) et les champs
  meta. Meta transmise en champs form-data ; on parse en `ClipReq` :
  - `promptId` (string, opt), `rarity` (0|1|2), `durationS` (int),
    `consent.commercialUse` (bool), `consent.consentVersion` (string).
  - Les champs form-data sont des strings → coercition (`z.coerce`) avant `ClipReq.parse`.
- Validation media : mimetype ∈ {audio/mp4, audio/aac, audio/mpeg, audio/wav,
  audio/x-wav, audio/ogg} sinon `415 BAD_FORMAT` ; taille > 10 Mo → `413 TOO_LARGE`
  (via `req.file({ limits })` ou capture de l'erreur `FST_REQ_FILE_TOO_LARGE`).
- Passe `{ buffer, ext }` à `submitClip`.

**`ContributionService.submitClip`** — signature étendue.
- Nouveau param `audio: { buffer: Buffer; ext: string }`.
- Ordre : `createClip` (obtient l'id) → si `passed` : `audioStore.save(clip.id,
  audio.buffer, audio.ext)` → `repo.setClipAudio(clip.id, path)`. Si `!passed`
  (rejected) : ne rien stocker.
- Le service reçoit `AudioStore` par injection (constructeur), comme `Repo`.

**`GET /api/clips/:id/audio`** — nouvelle route, surface mobile (auth `mobile`).
- `getClip(id)` → 404 si introuvable ou `audioPath` nul.
- `audioStore.openRead` → `reply.type(mime).send(stream)`. 404 si le fichier manque.
- Autorisation : tout utilisateur mobile authentifié (les validateurs doivent
  pouvoir lire un clip qui n'est pas le leur). Pas de restriction propriétaire.

**`GET /validation/next`** enrichi.
- Ajoute `audioUrl: "/api/clips/<id>/audio"` à la réponse existante
  (`clipId`, `durationS`, `requiredCompetence`).

**Domaine & repo.**
- `domain/contribution.ts` : `Clip` gagne `audioPath?: string`.
- `Repo` : nouvelle méthode `setClipAudio(id: string, path: string): Promise<void>`.
  Implémentée dans `InMemoryRepo` (mut. objet) et `PgRepo` (`UPDATE clips SET audio_path`).
- SQL : migration `ALTER TABLE clips ADD COLUMN audio_path text;` (dans
  `docs/backend/delta-v2.sql` et le bootstrap PGlite `db/pglite.ts`).

### Unités mobile

**Dépendances** (`pubspec.yaml`) : `record`, `audioplayers`, `path_provider`,
`permission_handler`. Permissions natives :
- Android : `<uses-permission android:name="android.permission.RECORD_AUDIO"/>`
  dans `android/app/src/main/AndroidManifest.xml`.
- iOS : `NSMicrophoneUsageDescription` dans `ios/Runner/Info.plist`.

**`recording_screen.dart`** :
- `initState` : demander la permission micro puis `AudioRecorder().start(config,
  path)` vers un fichier temp (`path_provider`, ext `.m4a`, encoder AAC).
- Bouton stop : `stop()` → chemin réel → `context.go('/recording-review', extra:
  { 'audio_path', 'duration', 'commercial', 'consent_version' })`.
- La waveform reste animée (décorative). « Annuler » supprime le fichier.

**`recording_review_screen.dart`** :
- Reçoit `audioPath` en `extra`.
- Bouton play : `AudioPlayer().play(DeviceFileSource(audioPath))` au lieu du snackbar.
- `_submit` : appelle `ContributionApi.submitClip(audioPath: ..., ...)`.

**`ApiClient`** :
- Nouvelle méthode `postMultipart(String path, Map<String,String> fields,
  {required String filePath, String fileField = 'audio'})` via
  `http.MultipartRequest` (+ header Bearer, sans `Content-Type` JSON).
- Nouvelle méthode `getBytes(String path) → Uint8List` (pour la réécoute).
- Réutilise le mapping d'erreurs existant (`_send`) autant que possible.

**`ContributionApi.submitClip`** : param `required String audioPath` ; construit
les champs form-data (`rarity`, `durationS`, `consent.commercialUse`,
`consent.consentVersion`, `promptId?`) et délègue à `postMultipart`.

**`validation_screen.dart`** :
- À l'arrivée d'un clip (`GET /validation/next` → `audioUrl`), récupérer les
  octets via `ApiClient.getBytes(audioUrl)` (en-tête auth) puis jouer via
  `audioplayers` (`BytesSource`). Réécoute réelle avant vote.
- (Si l'écran est encore mock, on branche au minimum la lecture ; le reste du
  câblage validation est déjà partiellement en place.)

## Gestion d'erreurs

| Cas | Code | Où |
|---|---|---|
| Pas de token | 401 UNAUTHENTICATED | route (existant) |
| Champs meta invalides | 400 | `ClipReq.parse` |
| Mauvais format audio | 415 BAD_FORMAT | route multipart |
| Fichier > 10 Mo | 413 TOO_LARGE | limite multipart |
| Clip / audio introuvable | 404 | `GET /clips/:id/audio` |
| Serveur injoignable (mobile) | ApiException | `ApiClient` (existant) |

## Stratégie de test

**Backend — TDD (`app.inject`, nouveau `audio.test.ts` ou extension de
`contribution.test.ts`)** :
1. `POST /api/clips` multipart avec petit buffer audio → 201, `clipId`, `status`
   `peer_review`, fichier présent via `AudioStore`.
2. `GET /api/clips/:id/audio` → 200 + octets identiques.
3. `POST` avec mimetype non audio → 415.
4. `POST` avec fichier > 10 Mo → 413.
5. `POST` dont l'autocheck échoue (durée hors limites) → `rejected` **et** aucun
   fichier stocké.
6. `GET /validation/next` → réponse contient `audioUrl`.
7. `GET /api/clips/:id/audio` sur clip inexistant → 404.
- `AudioStore` testé en isolation avec un `AUDIO_DIR` temp (setup/teardown).
- Tests exécutés sur InMemory **et** PG (PGlite) via le harnais existant.

**Mobile** :
- `ApiClient.postMultipart` : test avec `http.Client` mocké (vérifie
  `MultipartRequest`, champs, header Bearer).
- Capture micro / lecture : vérification manuelle sur appareil (non unit-testable).

## Critères d'acceptation

- [ ] Un enregistrement réel part du mobile et arrive stocké côté serveur.
- [ ] Le validateur réécoute ce même fichier avant de voter.
- [ ] Un clip rejeté par l'autocheck ne laisse aucun fichier.
- [ ] 415 / 413 / 404 renvoyés dans les bons cas.
- [ ] Suite backend verte sur InMemory + PG ; `tsc --noEmit` OK.
- [ ] `flutter analyze` OK sur le mobile.
