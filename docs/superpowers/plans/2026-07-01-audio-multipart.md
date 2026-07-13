# Audio Multipart Bout-en-Bout — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Faire circuler un vrai fichier audio de la capture micro mobile jusqu'à la réécoute par le validateur, en passant par un upload multipart et un stockage fichier côté serveur.

**Architecture:** Le mobile capture le micro (`record`), joue le fichier (`audioplayers`) et l'envoie en `multipart/form-data`. Le backend Fastify parse le fichier via `@fastify/multipart`, le stocke sur disque via une interface `AudioStore` (impl. filesystem), persiste le chemin sur `clips.audio_path`, et le ressert via `GET /api/clips/:id/audio`. Un clip rejeté par l'auto-check ne conserve aucun fichier.

**Tech Stack:** Backend TS/Fastify 5 + `@fastify/multipart`, PGlite/InMemory repo, zod. Mobile Flutter + `record` + `audioplayers` + `path_provider` + `permission_handler` + `http`.

## Global Constraints

- Plafond fichier audio : **10 Mo** (`10 * 1024 * 1024`) → dépassement = `413 TOO_LARGE`.
- Formats acceptés (mimetype) : `audio/mp4`, `audio/aac`, `audio/mpeg`, `audio/wav`, `audio/x-wav`, `audio/ogg` → sinon `415 BAD_FORMAT`.
- Stockage = filesystem sous `CONFIG.audioDir` (env `AUDIO_DIR`, défaut `var/audio`), nom `<clipId>.<ext>`.
- **Stocker l'audio uniquement si l'auto-check passe** (statut `peer_review`) ; un clip `rejected` ne laisse aucun fichier.
- Format d'erreur backend : `{ "error": { "code": "...", "message": "..." } }`.
- Répertoire de travail backend : `/home/r_ghost/Projets/data/SABIDATA/backend`. Mobile : `/home/r_ghost/Projets/data/SABIDATA/sabiData_frontend`.
- Commandes backend : tests `./node_modules/.bin/tsx --test src/*.test.ts` · typecheck `./node_modules/.bin/tsc --noEmit`.

---

### Task 1: `AudioStore` (filesystem) + config + gitignore

**Files:**
- Create: `backend/src/storage/audioStore.ts`
- Create: `backend/src/storage/audioStore.test.ts`
- Modify: `backend/src/config.ts` (ajouter `audioDir`)
- Modify: `backend/.gitignore` (ignorer `var/`)

**Interfaces:**
- Produces:
  - `interface AudioStore { save(clipId: string, buffer: Buffer, ext: string): Promise<string>; openRead(storedPath: string): Promise<Readable | null>; }`
  - `class FsAudioStore implements AudioStore` (constructeur `(dir: string)`)
  - `class InMemoryAudioStore implements AudioStore` (pour les tests)
  - `extFromMime(mime: string): string | null`
  - `mimeFromExt(ext: string): string`
  - `CONFIG.audioDir: string`

- [ ] **Step 1: Write the failing test**

Create `backend/src/storage/audioStore.test.ts`:

```ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { FsAudioStore, InMemoryAudioStore, extFromMime, mimeFromExt } from './audioStore';

async function readAll(store: { openRead(p: string): Promise<NodeJS.ReadableStream | null> }, p: string) {
  const s = await store.openRead(p);
  if (!s) return null;
  const chunks: Buffer[] = [];
  for await (const c of s) chunks.push(Buffer.from(c));
  return Buffer.concat(chunks);
}

test('FsAudioStore — save écrit le fichier et openRead le relit', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'sabi-audio-'));
  try {
    const store = new FsAudioStore(dir);
    const buf = Buffer.from('AUDIODATA');
    const path = await store.save('clip1', buf, 'm4a');
    assert.equal(path, 'clip1.m4a');
    assert.deepEqual(await readAll(store, path), buf);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('FsAudioStore — openRead renvoie null si absent', async () => {
  const dir = mkdtempSync(join(tmpdir(), 'sabi-audio-'));
  try {
    assert.equal(await new FsAudioStore(dir).openRead('missing.m4a'), null);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});

test('InMemoryAudioStore — round-trip', async () => {
  const store = new InMemoryAudioStore();
  const buf = Buffer.from('X');
  const path = await store.save('c', buf, 'wav');
  assert.deepEqual(await readAll(store, path), buf);
});

test('mime helpers — mapping connu et rejet inconnu', () => {
  assert.equal(extFromMime('audio/mpeg'), 'mp3');
  assert.equal(extFromMime('image/png'), null);
  assert.equal(mimeFromExt('m4a'), 'audio/mp4');
  assert.equal(mimeFromExt('zzz'), 'application/octet-stream');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./node_modules/.bin/tsx --test src/storage/audioStore.test.ts`
Expected: FAIL — module `./audioStore` introuvable.

- [ ] **Step 3: Write the implementation**

Create `backend/src/storage/audioStore.ts`:

```ts
import { createReadStream, existsSync } from 'node:fs';
import { mkdir, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { type Readable } from 'node:stream';

// Stockage de blob audio, abstrait pour rester swappable (S3/pré-signé = D6).
export interface AudioStore {
  // Persiste le buffer et renvoie un chemin relatif à stocker sur le clip.
  save(clipId: string, buffer: Buffer, ext: string): Promise<string>;
  // Ouvre le blob en lecture ; null si absent.
  openRead(storedPath: string): Promise<Readable | null>;
}

// Formats audio acceptés (mimetype → extension).
const AUDIO_MIME_EXT: Record<string, string> = {
  'audio/mp4': 'm4a',
  'audio/aac': 'aac',
  'audio/mpeg': 'mp3',
  'audio/wav': 'wav',
  'audio/x-wav': 'wav',
  'audio/ogg': 'ogg',
};

export function extFromMime(mime: string): string | null {
  return AUDIO_MIME_EXT[mime] ?? null;
}

export function mimeFromExt(ext: string): string {
  const found = Object.entries(AUDIO_MIME_EXT).find(([, e]) => e === ext);
  return found ? found[0] : 'application/octet-stream';
}

// Implémentation filesystem : <dir>/<clipId>.<ext>.
export class FsAudioStore implements AudioStore {
  constructor(private readonly dir: string) {}

  async save(clipId: string, buffer: Buffer, ext: string): Promise<string> {
    await mkdir(this.dir, { recursive: true });
    const rel = `${clipId}.${ext}`;
    await writeFile(join(this.dir, rel), buffer);
    return rel;
  }

  async openRead(storedPath: string): Promise<Readable | null> {
    const full = join(this.dir, storedPath);
    if (!existsSync(full)) return null;
    return createReadStream(full);
  }
}

// Implémentation mémoire pour les tests (pas de disque).
export class InMemoryAudioStore implements AudioStore {
  private readonly blobs = new Map<string, Buffer>();

  async save(clipId: string, buffer: Buffer, ext: string): Promise<string> {
    const rel = `${clipId}.${ext}`;
    this.blobs.set(rel, buffer);
    return rel;
  }

  async openRead(storedPath: string): Promise<Readable | null> {
    const buf = this.blobs.get(storedPath);
    if (!buf) return null;
    const { Readable } = await import('node:stream');
    return Readable.from(buf);
  }
}
```

Add to `backend/src/config.ts` inside the `CONFIG` object (before the closing `} as const;`), after the `autocheck` line:

```ts
  // Stockage audio (D6 partiel) — filesystem par défaut.
  audioDir: process.env.AUDIO_DIR ?? 'var/audio',
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd backend && ./node_modules/.bin/tsx --test src/storage/audioStore.test.ts`
Expected: PASS (4 tests).

- [ ] **Step 5: Ignore `var/` in git**

Append to `backend/.gitignore`:

```
# Blobs audio stockés localement (dev)
var/
```

- [ ] **Step 6: Typecheck + commit**

Run: `cd backend && ./node_modules/.bin/tsc --noEmit`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/storage/audioStore.ts backend/src/storage/audioStore.test.ts backend/src/config.ts backend/.gitignore
git commit -m "feat(backend): AudioStore filesystem + config audioDir"
```

---

### Task 2: `Clip.audioPath` + `Repo.setClipAudio`

**Files:**
- Modify: `backend/src/domain/contribution.ts` (champ `audioPath?`)
- Modify: `backend/src/ports/repo.ts` (interface `Repo` + `InMemoryRepo`)
- Modify: `backend/src/ports/pgRepo.ts` (`setClipAudio` + `mapClip` + `ClipRow`)
- Modify: `backend/src/db/schema.sql` (colonne `audio_path`)
- Modify: `backend/src/contribution.test.ts` (nouveau test `setClipAudio`)

**Interfaces:**
- Consumes: `Clip` (Task existant), `InMemoryRepo` (existant).
- Produces: `Repo.setClipAudio(id: string, audioPath: string): Promise<void>` ; `Clip.audioPath?: string`.

- [ ] **Step 1: Write the failing test**

Append to `backend/src/contribution.test.ts`:

```ts
test('repo — setClipAudio persiste audioPath sur le clip', async () => {
  const repo = new InMemoryRepo();
  const svc = new ContributionService(repo);
  const { clipId } = await svc.submitClip('alice', { rarity: 1, durationS: 4, ...consent });
  await repo.setClipAudio(clipId, `${clipId}.m4a`);
  const clip = await repo.getClip(clipId);
  assert.equal(clip?.audioPath, `${clipId}.m4a`);
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd backend && ./node_modules/.bin/tsx --test src/contribution.test.ts`
Expected: FAIL — `repo.setClipAudio is not a function`.

- [ ] **Step 3: Add `audioPath` to the domain**

In `backend/src/domain/contribution.ts`, inside `interface Clip`, add after `autocheck?: Record<string, unknown>;`:

```ts
  audioPath?: string; // chemin relatif du blob audio (null tant que non stocké)
```

- [ ] **Step 4: Add `setClipAudio` to the `Repo` interface + InMemoryRepo**

In `backend/src/ports/repo.ts`, add to the `Repo` interface near the other clip methods (after `setClipStatus(...)`):

```ts
  setClipAudio(id: string, audioPath: string): Promise<void>;
```

In `InMemoryRepo`, add after the `setClipStatus` method:

```ts
  async setClipAudio(id: string, audioPath: string) {
    const c = this.clips.find((x) => x.id === id);
    if (c) c.audioPath = audioPath;
  }
```

- [ ] **Step 5: Implement `setClipAudio` in PgRepo + map the column**

In `backend/src/ports/pgRepo.ts`, add after `setClipStatus`:

```ts
  async setClipAudio(id: string, audioPath: string) {
    await this.db.query('UPDATE clips SET audio_path = $2 WHERE id = $1', [id, audioPath]);
  }
```

In the `ClipRow` type (near the top of the file where row types are declared), add:

```ts
  audio_path: string | null;
```

In `mapClip`, add `audioPath` to the returned object (after `autocheck: r.autocheck ?? undefined,`):

```ts
      audioPath: r.audio_path ?? undefined,
```

- [ ] **Step 6: Add the SQL column**

In `backend/src/db/schema.sql`, inside `CREATE TABLE clips (...)`, add after the `autocheck jsonb,` line:

```sql
  audio_path          text,
```

- [ ] **Step 7: Run tests (InMemory + PG) to verify they pass**

Run: `cd backend && ./node_modules/.bin/tsx --test src/contribution.test.ts src/pg.test.ts`
Expected: PASS (existing + new `setClipAudio` test). If `pg.test.ts` asserts clip round-trips, `audio_path` must be nullable — it is.

- [ ] **Step 8: Typecheck + commit**

Run: `cd backend && ./node_modules/.bin/tsc --noEmit`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/domain/contribution.ts backend/src/ports/repo.ts backend/src/ports/pgRepo.ts backend/src/db/schema.sql backend/src/contribution.test.ts
git commit -m "feat(backend): clips.audio_path + Repo.setClipAudio"
```

---

### Task 3: `submitClip` stocke l'audio quand l'auto-check passe

**Files:**
- Modify: `backend/src/services/contributionService.ts` (constructeur + `submitClip`)
- Modify: `backend/src/contribution.test.ts` (2 tests audio)

**Interfaces:**
- Consumes: `AudioStore`, `InMemoryAudioStore` (Task 1) ; `Repo.setClipAudio` (Task 2).
- Produces: `ContributionService` constructeur `(repo: Repo, audioStore?: AudioStore)` ; `submitClip(contributorId, input, audio?: { buffer: Buffer; ext: string })`.

- [ ] **Step 1: Write the failing tests**

Append to `backend/src/contribution.test.ts` (add the import at the top with the others: `import { InMemoryAudioStore } from './storage/audioStore';`):

```ts
test('flux — clip valide stocke l\'audio et renseigne audioPath', async () => {
  const repo = new InMemoryRepo();
  const store = new InMemoryAudioStore();
  const svc = new ContributionService(repo, store);
  const { clipId } = await svc.submitClip(
    'alice',
    { rarity: 1, durationS: 4, ...consent },
    { buffer: Buffer.from('AUDIO'), ext: 'm4a' },
  );
  const clip = await repo.getClip(clipId);
  assert.equal(clip?.audioPath, `${clipId}.m4a`);
  assert.notEqual(await store.openRead(`${clipId}.m4a`), null);
});

test('flux — clip rejeté (0s) ne stocke AUCUN audio', async () => {
  const repo = new InMemoryRepo();
  const store = new InMemoryAudioStore();
  const svc = new ContributionService(repo, store);
  const { clipId } = await svc.submitClip(
    'alice',
    { rarity: 0, durationS: 0, ...consent },
    { buffer: Buffer.from('AUDIO'), ext: 'm4a' },
  );
  const clip = await repo.getClip(clipId);
  assert.equal(clip?.audioPath, undefined);
  assert.equal(await store.openRead(`${clipId}.m4a`), null);
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && ./node_modules/.bin/tsx --test src/contribution.test.ts`
Expected: FAIL — `submitClip` n'accepte pas de 3ᵉ argument / audioPath reste undefined.

- [ ] **Step 3: Wire `AudioStore` into the service**

In `backend/src/services/contributionService.ts`:

Add the import at the top:

```ts
import { type AudioStore, InMemoryAudioStore } from '../storage/audioStore';
```

Change the constructor (default store keeps existing no-audio tests compiling):

```ts
  constructor(
    private readonly repo: Repo,
    private readonly audioStore: AudioStore = new InMemoryAudioStore(),
  ) {}
```

Change the `submitClip` signature to accept optional audio (add the 3rd param):

```ts
  async submitClip(
    contributorId: string,
    input: { promptId?: string; rarity: Rarity; durationS: number; commercialUse: boolean; consentVersion: string },
    audio?: { buffer: Buffer; ext: string },
  ): Promise<{ clipId: string; status: ClipState; reward: number; licenseTag: string }> {
```

Inside `submitClip`, after the `createClip` call and before computing `reward`, add the storage step (only when the auto-check passed AND audio is present):

```ts
    if (passed && audio) {
      const path = await this.audioStore.save(clip.id, audio.buffer, audio.ext);
      await this.repo.setClipAudio(clip.id, path);
    }
```

- [ ] **Step 4: Run the full backend suite to verify it passes**

Run: `cd backend && ./node_modules/.bin/tsx --test src/*.test.ts`
Expected: PASS (all existing tests still green; the 2 new audio tests pass).

- [ ] **Step 5: Typecheck + commit**

Run: `cd backend && ./node_modules/.bin/tsc --noEmit`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/services/contributionService.ts backend/src/contribution.test.ts
git commit -m "feat(backend): submitClip stocke l'audio si auto-check passe"
```

---

### Task 4: `POST /api/clips` en multipart (415/413/400)

**Files:**
- Modify: `backend/package.json` (dépendance `@fastify/multipart`)
- Modify: `backend/src/contribution/schemas.ts` (schéma `ClipMultipartReq`)
- Modify: `backend/src/routes/contributionRoutes.ts` (route multipart)
- Modify: `backend/src/server.ts` (register plugin + injecter `AudioStore`)
- Create: `backend/src/audio.test.ts` (tests app.inject)

**Interfaces:**
- Consumes: `ContributionService` (Task 3), `extFromMime` (Task 1), `FsAudioStore` (Task 1).
- Produces: `ClipMultipartReq` (zod) ; route `POST /api/clips` acceptant `multipart/form-data`.

- [ ] **Step 1: Install `@fastify/multipart`**

Run: `cd backend && npm install @fastify/multipart@^9`
Expected: ajoute la dépendance ; `node_modules` mis à jour.

- [ ] **Step 2: Write the failing test**

Create `backend/src/audio.test.ts`:

```ts
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { InMemoryRepo } from './ports/repo';
import { FsAudioStore } from './storage/audioStore';
import { buildServer } from './server';

// Construit un corps multipart/form-data minimal (sans dépendance externe).
function multipart(
  fields: Record<string, string>,
  file: { field: string; filename: string; contentType: string; data: Buffer },
) {
  const boundary = '----sabidata' + Math.random().toString(16).slice(2);
  const parts: Buffer[] = [];
  for (const [k, v] of Object.entries(fields)) {
    parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
  }
  parts.push(
    Buffer.from(
      `--${boundary}\r\nContent-Disposition: form-data; name="${file.field}"; filename="${file.filename}"\r\n` +
        `Content-Type: ${file.contentType}\r\n\r\n`,
    ),
  );
  parts.push(file.data, Buffer.from(`\r\n--${boundary}--\r\n`));
  return { body: Buffer.concat(parts), contentType: `multipart/form-data; boundary=${boundary}` };
}

// Inscrit un utilisateur mobile et renvoie {app, token, repo, store}.
async function setup() {
  const dir = mkdtempSync(join(tmpdir(), 'sabi-audio-'));
  const repo = new InMemoryRepo();
  const store = new FsAudioStore(dir);
  const app = buildServer(repo, store);
  await app.ready();
  const reg = await app.inject({
    method: 'POST',
    url: '/api/auth/register',
    payload: { name: 'Alice', email: `a${Math.random()}@x.bf`, password: 'secret1' },
  });
  const token = JSON.parse(reg.body).access as string;
  return { app, token, repo, store, dir };
}

const goodFields = { rarity: '1', durationS: '4', commercialUse: 'true', consentVersion: 'v1' };

test('POST /api/clips multipart — 201, stocke l\'audio, audioPath renseigné', async () => {
  const { app, token, repo, dir } = await setup();
  try {
    const mp = multipart(goodFields, { field: 'audio', filename: 'c.m4a', contentType: 'audio/mp4', data: Buffer.from('AUDIODATA') });
    const res = await app.inject({
      method: 'POST',
      url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': mp.contentType },
      payload: mp.body,
    });
    assert.equal(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.equal(body.status, 'peer_review');
    const clip = await repo.getClip(body.clipId);
    assert.equal(clip?.audioPath, `${body.clipId}.m4a`);
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('POST /api/clips multipart — mimetype non audio → 415', async () => {
  const { app, token, dir } = await setup();
  try {
    const mp = multipart(goodFields, { field: 'audio', filename: 'c.png', contentType: 'image/png', data: Buffer.from('X') });
    const res = await app.inject({
      method: 'POST',
      url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': mp.contentType },
      payload: mp.body,
    });
    assert.equal(res.statusCode, 415);
    assert.equal(JSON.parse(res.body).error.code, 'BAD_FORMAT');
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('POST /api/clips multipart — fichier > 10 Mo → 413', async () => {
  const { app, token, dir } = await setup();
  try {
    const big = Buffer.alloc(10 * 1024 * 1024 + 1024, 1);
    const mp = multipart(goodFields, { field: 'audio', filename: 'big.m4a', contentType: 'audio/mp4', data: big });
    const res = await app.inject({
      method: 'POST',
      url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': mp.contentType },
      payload: mp.body,
    });
    assert.equal(res.statusCode, 413);
    assert.equal(JSON.parse(res.body).error.code, 'TOO_LARGE');
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('POST /api/clips multipart — sans fichier audio → 400', async () => {
  const { app, token, dir } = await setup();
  try {
    const boundary = '----sabidataNoFile';
    const parts: Buffer[] = [];
    for (const [k, v] of Object.entries(goodFields)) {
      parts.push(Buffer.from(`--${boundary}\r\nContent-Disposition: form-data; name="${k}"\r\n\r\n${v}\r\n`));
    }
    parts.push(Buffer.from(`--${boundary}--\r\n`));
    const res = await app.inject({
      method: 'POST',
      url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': `multipart/form-data; boundary=${boundary}` },
      payload: Buffer.concat(parts),
    });
    assert.equal(res.statusCode, 400);
    assert.equal(JSON.parse(res.body).error.code, 'NO_AUDIO');
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});
```

> Note: if `buildServer` doesn't yet accept a 2nd `AudioStore` argument, Steps 5–6 add it. If `POST /api/auth/register` returns a different token field, align `reg.body` parsing with `authRoutes.ts` (the field is `access`).

- [ ] **Step 3: Run test to verify it fails**

Run: `cd backend && ./node_modules/.bin/tsx --test src/audio.test.ts`
Expected: FAIL — `buildServer` n'accepte pas de store, ou la route renvoie encore du JSON (415/413 non gérés).

- [ ] **Step 4: Add the multipart request schema**

In `backend/src/contribution/schemas.ts`, add after the existing `ClipReq` export:

```ts
// Variante multipart : les champs form-data arrivent en strings → coercition.
export const ClipMultipartReq = z.object({
  promptId: z.string().optional(),
  rarity: z.coerce.number().int().refine((v) => v === 0 || v === 1 || v === 2, 'rarity ∈ {0,1,2}'),
  durationS: z.coerce.number().int().nonnegative(),
  commercialUse: z.enum(['true', 'false']).transform((v) => v === 'true'),
  consentVersion: z.string().min(1),
});
export type ClipMultipartReq = z.infer<typeof ClipMultipartReq>;
```

- [ ] **Step 5: Register the plugin and inject the store in `server.ts`**

In `backend/src/server.ts`:

Add imports at the top:

```ts
import multipart from '@fastify/multipart';
import { type AudioStore, FsAudioStore } from './storage/audioStore';
import { CONFIG } from './config';
```

Change `buildServer` to accept the store and register the plugin (register BEFORE routes so `req.parts()` is available):

```ts
export function buildServer(repo: Repo = new InMemoryRepo(), audioStore: AudioStore = new FsAudioStore(CONFIG.audioDir)) {
  const app = Fastify({ logger: false });
  app.register(multipart, { limits: { fileSize: 10 * 1024 * 1024 } });
```

Change the `ContributionService` construction to pass the store:

```ts
  const contributions = new ContributionService(repo, audioStore);
```

- [ ] **Step 6: Rewrite the `POST /clips` route as multipart**

In `backend/src/routes/contributionRoutes.ts`:

Update imports:

```ts
import { ClipMultipartReq, VoteReq, TranscriptionReq } from '../contribution/schemas';
import { extFromMime } from '../storage/audioStore';
```

Replace the entire `app.post('/clips', ...)` handler with:

```ts
  app.post('/clips', async (req, reply) => {
    const p = req.principal;
    if (!p) return reply.code(401).send({ error: { code: 'UNAUTHENTICATED', message: 'token requis' } });

    const fields: Record<string, string> = {};
    let audioBuffer: Buffer | null = null;
    let audioExt = '';
    try {
      for await (const part of req.parts()) {
        if (part.type === 'file') {
          if (part.fieldname !== 'audio') {
            part.file.resume(); // draine les fichiers inattendus
            continue;
          }
          const ext = extFromMime(part.mimetype);
          if (!ext) {
            return reply.code(415).send({ error: { code: 'BAD_FORMAT', message: part.mimetype } });
          }
          audioExt = ext;
          audioBuffer = await part.toBuffer(); // lève si > limite (10 Mo)
        } else {
          fields[part.fieldname] = String(part.value);
        }
      }
    } catch (e) {
      if (e instanceof Error && (e as { code?: string }).code === 'FST_REQ_FILE_TOO_LARGE') {
        return reply.code(413).send({ error: { code: 'TOO_LARGE', message: 'audio > 10 Mo' } });
      }
      throw e;
    }

    if (!audioBuffer) {
      return reply.code(400).send({ error: { code: 'NO_AUDIO', message: 'fichier audio requis' } });
    }

    const body = ClipMultipartReq.parse(fields);
    const r = await svc.submitClip(
      p.userId,
      {
        promptId: body.promptId,
        rarity: body.rarity as 0 | 1 | 2,
        durationS: body.durationS,
        commercialUse: body.commercialUse,
        consentVersion: body.consentVersion,
      },
      { buffer: audioBuffer, ext: audioExt },
    );
    return reply.code(201).send(r);
  });
```

- [ ] **Step 7: Run tests to verify they pass**

Run: `cd backend && ./node_modules/.bin/tsx --test src/audio.test.ts`
Expected: PASS (4 tests: 201 / 415 / 413 / 400).

- [ ] **Step 8: Run the whole suite + typecheck + commit**

Run: `cd backend && ./node_modules/.bin/tsx --test src/*.test.ts && ./node_modules/.bin/tsc --noEmit`
Expected: all green, no type errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/package.json backend/package-lock.json backend/src/contribution/schemas.ts backend/src/routes/contributionRoutes.ts backend/src/server.ts backend/src/audio.test.ts
git commit -m "feat(backend): POST /clips multipart + validation 415/413/400"
```

---

### Task 5: `GET /api/clips/:id/audio` + `audioUrl` dans `/validation/next`

**Files:**
- Modify: `backend/src/routes/contributionRoutes.ts` (route GET audio + `audioUrl`)
- Modify: `backend/src/audio.test.ts` (2 tests)

**Interfaces:**
- Consumes: `mimeFromExt` (Task 1), `Repo.getClip` (existant), `AudioStore.openRead` (Task 1).
- Produces: route `GET /api/clips/:id/audio` ; `GET /api/validation/next` renvoie `audioUrl`.
- Note d'implémentation : `contributionRoutes` doit pouvoir lire l'`AudioStore`. On passe le store en 3ᵉ argument de `contributionRoutes(app, svc, audioStore)` depuis `server.ts`.

- [ ] **Step 1: Write the failing tests**

Append to `backend/src/audio.test.ts`:

```ts
test('GET /api/clips/:id/audio — renvoie les octets stockés', async () => {
  const { app, token, dir } = await setup();
  try {
    const mp = multipart(goodFields, { field: 'audio', filename: 'c.m4a', contentType: 'audio/mp4', data: Buffer.from('AUDIODATA') });
    const post = await app.inject({
      method: 'POST', url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': mp.contentType },
      payload: mp.body,
    });
    const clipId = JSON.parse(post.body).clipId as string;
    const res = await app.inject({
      method: 'GET', url: `/api/clips/${clipId}/audio`,
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(res.statusCode, 200);
    assert.equal(res.rawPayload.toString(), 'AUDIODATA');
    assert.match(res.headers['content-type'] as string, /audio\/mp4/);
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('GET /api/clips/:id/audio — clip inexistant → 404', async () => {
  const { app, token, dir } = await setup();
  try {
    const res = await app.inject({
      method: 'GET', url: '/api/clips/nope/audio',
      headers: { authorization: `Bearer ${token}` },
    });
    assert.equal(res.statusCode, 404);
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});

test('GET /api/validation/next — inclut audioUrl pour un clip en peer_review', async () => {
  const { app, token, dir } = await setup();
  try {
    // Alice soumet ; Bob (2e user) reçoit le clip à valider.
    const mp = multipart(goodFields, { field: 'audio', filename: 'c.m4a', contentType: 'audio/mp4', data: Buffer.from('AUDIODATA') });
    await app.inject({
      method: 'POST', url: '/api/clips',
      headers: { authorization: `Bearer ${token}`, 'content-type': mp.contentType },
      payload: mp.body,
    });
    const reg = await app.inject({
      method: 'POST', url: '/api/auth/register',
      payload: { name: 'Bob', email: `b${Math.random()}@x.bf`, password: 'secret1' },
    });
    const bob = JSON.parse(reg.body).access as string;
    const res = await app.inject({
      method: 'GET', url: '/api/validation/next',
      headers: { authorization: `Bearer ${bob}` },
    });
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.audioUrl, `/api/clips/${body.clipId}/audio`);
  } finally {
    await app.close();
    rmSync(dir, { recursive: true, force: true });
  }
});
```

> Note: the `audioUrl` test assumes a freshly-registered user has enough competence to receive a rarity-1 clip (`requiredCompetence` 1). If the default registered role has competence < 1, lower the fixture to `rarity: '0'` in `goodFields` for this test, or promote Bob via the repo. Verify against `nextForValidation` competence routing.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd backend && ./node_modules/.bin/tsx --test src/audio.test.ts`
Expected: FAIL — route audio absente (404 générique / pas de handler) et `audioUrl` absent.

- [ ] **Step 3: Thread the store into `contributionRoutes`**

In `backend/src/server.ts`, change the call inside the `/api` scope:

```ts
      await contributionRoutes(i, contributions, audioStore);
```

In `backend/src/routes/contributionRoutes.ts`, update the function signature and imports:

```ts
import { extFromMime, mimeFromExt, type AudioStore } from '../storage/audioStore';
```

```ts
export async function contributionRoutes(
  app: FastifyInstance,
  svc: ContributionService,
  audioStore: AudioStore,
): Promise<void> {
```

- [ ] **Step 4: Add `audioUrl` to `/validation/next`**

In the `app.get('/validation/next', ...)` handler, change the success return to include `audioUrl`:

```ts
      return reply.send({
        clipId: clip.id,
        durationS: clip.durationS,
        requiredCompetence: clip.requiredCompetence,
        audioUrl: `/api/clips/${clip.id}/audio`,
      });
```

- [ ] **Step 5: Add the `GET /clips/:id/audio` route**

In `backend/src/routes/contributionRoutes.ts`, add this handler (e.g. right after `POST /clips`):

```ts
  app.get('/clips/:id/audio', async (req, reply) => {
    const p = req.principal;
    if (!p) return reply.code(401).send({ error: { code: 'UNAUTHENTICATED', message: 'token requis' } });
    const { id } = req.params as { id: string };
    const clip = await svc['repo']?.getClip ? await svc['repo'].getClip(id) : null;
    if (!clip || !clip.audioPath) return reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'audio' } });
    const stream = await audioStore.openRead(clip.audioPath);
    if (!stream) return reply.code(404).send({ error: { code: 'NOT_FOUND', message: 'audio' } });
    const ext = clip.audioPath.split('.').pop() ?? '';
    return reply.type(mimeFromExt(ext)).send(stream);
  });
```

> The `svc['repo']` access is a smell. Prefer exposing a read method on the service instead. Add to `ContributionService` (in `contributionService.ts`):
> ```ts
>   getClip(id: string) { return this.repo.getClip(id); }
> ```
> then use `const clip = await svc.getClip(id);` in the route. Do this — it keeps the repo private.

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd backend && ./node_modules/.bin/tsx --test src/audio.test.ts`
Expected: PASS (all 7 tests in the file).

- [ ] **Step 7: Full suite + typecheck + commit**

Run: `cd backend && ./node_modules/.bin/tsx --test src/*.test.ts && ./node_modules/.bin/tsc --noEmit`
Expected: all green.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add backend/src/routes/contributionRoutes.ts backend/src/services/contributionService.ts backend/src/server.ts backend/src/audio.test.ts
git commit -m "feat(backend): GET /clips/:id/audio + audioUrl dans /validation/next"
```

---

### Task 6: Dépendances audio mobiles + permissions micro

**Files:**
- Modify: `sabiData_frontend/pubspec.yaml`
- Modify: `sabiData_frontend/android/app/src/main/AndroidManifest.xml`
- Modify: `sabiData_frontend/ios/Runner/Info.plist`

**Interfaces:**
- Produces: paquets `record`, `audioplayers`, `path_provider`, `permission_handler` disponibles ; permission micro déclarée.

- [ ] **Step 1: Add the packages**

In `sabiData_frontend/pubspec.yaml`, under `dependencies:` (after `http: ^1.2.2`):

```yaml
  record: ^5.1.2
  audioplayers: ^6.1.0
  path_provider: ^2.1.4
  permission_handler: ^11.3.1
```

Run: `cd sabiData_frontend && flutter pub get`
Expected: resolves and downloads the packages.

- [ ] **Step 2: Declare Android mic permission**

In `sabiData_frontend/android/app/src/main/AndroidManifest.xml`, add inside `<manifest>` (before `<application>`):

```xml
    <uses-permission android:name="android.permission.RECORD_AUDIO"/>
    <uses-permission android:name="android.permission.INTERNET"/>
```

- [ ] **Step 3: Declare iOS mic usage**

In `sabiData_frontend/ios/Runner/Info.plist`, add inside the top-level `<dict>`:

```xml
	<key>NSMicrophoneUsageDescription</key>
	<string>SabiData a besoin du micro pour enregistrer vos contributions vocales.</string>
```

- [ ] **Step 4: Verify analyze + commit**

Run: `cd sabiData_frontend && flutter analyze`
Expected: no new errors (packages resolve).

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/pubspec.yaml sabiData_frontend/pubspec.lock sabiData_frontend/android/app/src/main/AndroidManifest.xml sabiData_frontend/ios/Runner/Info.plist
git commit -m "chore(mobile): deps audio (record/audioplayers) + permission micro"
```

---

### Task 7: `ApiClient.postMultipart` + `getBytes`

**Files:**
- Modify: `sabiData_frontend/lib/data/api/api_client.dart`
- Create: `sabiData_frontend/test/api_client_multipart_test.dart`

**Interfaces:**
- Consumes: `AuthSession`, `ApiConfig`, `ApiException` (existants).
- Produces:
  - `Future<dynamic> postMultipart(String path, Map<String,String> fields, {required String filePath, String fileField = 'audio', String contentType = 'audio/mp4'})`
  - `Future<Uint8List> getBytes(String path)`

- [ ] **Step 1: Write the failing test**

Create `sabiData_frontend/test/api_client_multipart_test.dart`:

```dart
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabidata_app/data/api/api_client.dart';

void main() {
  test('postMultipart envoie un MultipartRequest avec champs + fichier', () async {
    late http.BaseRequest captured;
    final mock = MockClient((req) async {
      captured = req;
      return http.Response(jsonEncode({'clipId': 'c1', 'status': 'peer_review'}), 201);
    });
    // Note: MockClient ne capture pas directement MultipartRequest.send ;
    // on vérifie via une sous-classe MockClient qui gère send(). Voir impl. ci-dessous.
    final client = ApiClient(mock);
    final res = await client.postMultipart(
      '/api/clips',
      {'rarity': '1', 'durationS': '4'},
      filePath: _tempAudioFile(),
    );
    expect(res['clipId'], 'c1');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/clips');
  });
}

String _tempAudioFile() {
  // crée un petit fichier temporaire
  final f = File('${Directory.systemTemp.path}/sabi_test.m4a')..writeAsBytesSync([1, 2, 3]);
  return f.path;
}
```

> Note: `package:http`'s `MockClient` intercepts `send()` for all request types including `MultipartRequest`, exposing a `http.Request` copy with the finalized body. If asserting multipart body fields proves flaky in the test env, keep the test minimal (status mapping + method + path) and rely on manual device verification for the actual upload. Add `import 'dart:io';` at the top.

- [ ] **Step 2: Run test to verify it fails**

Run: `cd sabiData_frontend && flutter test test/api_client_multipart_test.dart`
Expected: FAIL — `postMultipart` n'existe pas.

- [ ] **Step 3: Implement `postMultipart` + `getBytes`**

In `sabiData_frontend/lib/data/api/api_client.dart`, add `import 'dart:typed_data';` at the top, and add these methods inside the `ApiClient` class:

```dart
  Future<dynamic> postMultipart(
    String path,
    Map<String, String> fields, {
    required String filePath,
    String fileField = 'audio',
    String contentType = 'audio/mp4',
  }) async {
    final token = AuthSession.instance.token.value;
    final req = http.MultipartRequest('POST', Uri.parse('${ApiConfig.baseUrl}$path'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.fields.addAll(fields);
    req.files.add(await http.MultipartFile.fromPath(
      fileField,
      filePath,
      contentType: MediaType.parse(contentType),
    ));
    http.Response res;
    try {
      final streamed = await _http.send(req);
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
    }
    return _decode(res);
  }

  Future<Uint8List> getBytes(String path) async {
    http.Response res;
    try {
      res = await _http.get(Uri.parse('${ApiConfig.baseUrl}$path'), headers: _headers());
    } catch (_) {
      throw ApiException('Serveur injoignable. Vérifiez votre connexion.');
    }
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException('Erreur ${res.statusCode}', statusCode: res.statusCode);
    }
    return res.bodyBytes;
  }
```

Refactor the response handling so `_send` and `postMultipart` share it. Extract the body-parsing/error-mapping tail of `_send` into a private `_decode(http.Response res)` method that returns the decoded data or throws `ApiException`, then have `_send` call `_decode(res)`. Add `import 'package:http_parser/http_parser.dart';` for `MediaType` (transitively available via `http`; if not resolved, add `http_parser: ^4.0.2` to `pubspec.yaml`).

- [ ] **Step 4: Run test to verify it passes**

Run: `cd sabiData_frontend && flutter test test/api_client_multipart_test.dart`
Expected: PASS.

- [ ] **Step 5: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze`
Expected: no new errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/data/api/api_client.dart sabiData_frontend/test/api_client_multipart_test.dart sabiData_frontend/pubspec.yaml sabiData_frontend/pubspec.lock
git commit -m "feat(mobile): ApiClient.postMultipart + getBytes"
```

---

### Task 8: `ContributionApi.submitClip` en multipart

**Files:**
- Modify: `sabiData_frontend/lib/data/api/contribution_api.dart`

**Interfaces:**
- Consumes: `ApiClient.postMultipart` (Task 7).
- Produces: `submitClip({required int rarity, required int durationS, required bool commercialUse, required String consentVersion, required String audioPath, String? promptId})`.

- [ ] **Step 1: Rewrite `submitClip` to send multipart**

Replace the body of `ContributionApi.submitClip` in `sabiData_frontend/lib/data/api/contribution_api.dart`:

```dart
  Future<Map<String, dynamic>> submitClip({
    required int rarity,
    required int durationS,
    required bool commercialUse,
    required String consentVersion,
    required String audioPath,
    String? promptId,
  }) async {
    final fields = <String, String>{
      'rarity': rarity.toString(),
      'durationS': durationS.toString(),
      'commercialUse': commercialUse.toString(),
      'consentVersion': consentVersion,
      if (promptId != null) 'promptId': promptId,
    };
    final data = await _client.postMultipart('/api/clips', fields, filePath: audioPath);
    return Map<String, dynamic>.from(data as Map);
  }
```

- [ ] **Step 2: Analyze**

Run: `cd sabiData_frontend && flutter analyze lib/data/api/contribution_api.dart`
Expected: no errors (callers updated in Task 10; a temporary analyze error about the missing `audioPath` arg at the call site is expected until Task 10).

- [ ] **Step 3: Commit**

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/data/api/contribution_api.dart
git commit -m "feat(mobile): ContributionApi.submitClip envoie l'audio en multipart"
```

---

### Task 9: Capture micro réelle dans `recording_screen`

**Files:**
- Modify: `sabiData_frontend/lib/screens/recording_screen.dart`

**Interfaces:**
- Consumes: `record`, `path_provider`, `permission_handler` (Task 6).
- Produces: navigation `/recording-review` avec `extra['audio_path']` = chemin du fichier `.m4a` réel.

- [ ] **Step 1: Add recorder state + imports**

At the top of `sabiData_frontend/lib/screens/recording_screen.dart`, add:

```dart
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
```

In `_RecordingScreenState`, add a field:

```dart
  final AudioRecorder _recorder = AudioRecorder();
  String? _audioPath;
```

- [ ] **Step 2: Start recording in `initState`**

Replace the `_startTimer();` call in `initState` with a real start, and add the method:

```dart
  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      await Permission.microphone.request();
    }
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/clip_${DateTime.now().millisecondsSinceEpoch}.m4a';
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: path);
    _audioPath = path;
    _startTimer();
  }
```

Call it from `initState` (after the animation controllers are set up): `_startRecording();`

- [ ] **Step 3: Stop recording on the stop button + pass the path**

In the stop-button `onTap`, replace the body with:

```dart
                    onTap: () async {
                      setState(() => _isRecording = false);
                      final path = await _recorder.stop();
                      if (!context.mounted) return;
                      context.go('/recording-review', extra: {
                        'audio_path': path ?? _audioPath,
                        'duration': _time,
                        'commercial': widget.commercialUse,
                        'consent_version': widget.consentVersion,
                      });
                    },
```

- [ ] **Step 4: Clean up recorder in `dispose` and on cancel**

In `dispose`, add before `super.dispose();`:

```dart
    _recorder.dispose();
```

In the "Annuler sans pénalité" `onTap`, stop+discard first:

```dart
                onTap: () async {
                  await _recorder.stop();
                  if (context.mounted) context.pop();
                },
```

- [ ] **Step 5: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze lib/screens/recording_screen.dart`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/recording_screen.dart
git commit -m "feat(mobile): recording_screen capture réellement le micro"
```

---

### Task 10: Réécoute + soumission avec fichier dans `recording_review`

**Files:**
- Modify: `sabiData_frontend/lib/screens/recording_review_screen.dart`
- Modify: `sabiData_frontend/lib/router.dart` (passer `audio_path` au widget)

**Interfaces:**
- Consumes: `extra['audio_path']` (Task 9), `ContributionApi.submitClip(audioPath: ...)` (Task 8), `audioplayers` (Task 6).
- Produces: écran qui joue le fichier réel et le soumet.

- [ ] **Step 1: Accept `audioPath` in the widget + router**

In `sabiData_frontend/lib/screens/recording_review_screen.dart`, add a field and constructor param:

```dart
  final String? audioPath;
```
```dart
  const RecordingReviewScreen({super.key, this.duration, this.commercialUse = true, this.audioPath});
```

In `sabiData_frontend/lib/router.dart`, find the `/recording-review` route and pass `audioPath` from `extra`:

```dart
        final extra = state.extra as Map<String, dynamic>?;
        return RecordingReviewScreen(
          duration: extra?['duration'] as String?,
          commercialUse: extra?['commercial'] as bool? ?? true,
          audioPath: extra?['audio_path'] as String?,
        );
```

> Verify the exact existing `/recording-review` builder in `router.dart` and merge these fields into it (don't duplicate the route).

- [ ] **Step 2: Play the real file on the play button**

Add imports:

```dart
import 'package:audioplayers/audioplayers.dart';
```

Add a player field to `_RecordingReviewScreenState`:

```dart
  final AudioPlayer _player = AudioPlayer();
```

Add `dispose`:

```dart
  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }
```

Replace the playback `GestureDetector` `onTap` (currently `showAppSnack(...)`) with:

```dart
                            onTap: () async {
                              final path = widget.audioPath;
                              if (path == null) {
                                showAppSnack(context, 'Aucun enregistrement à lire.');
                                return;
                              }
                              await _player.play(DeviceFileSource(path));
                            },
```

- [ ] **Step 3: Pass the file path on submit**

In `_submit`, update the `ContributionApi().submitClip(...)` call to pass the path (guard against null):

```dart
      final path = widget.audioPath;
      if (path == null) {
        showAppSnack(context, 'Enregistrement introuvable, refaites la prise.');
        setState(() => _submitting = false);
        return;
      }
      final res = await ContributionApi().submitClip(
        rarity: 2,
        durationS: _durationSeconds,
        commercialUse: widget.commercialUse,
        consentVersion: 'v1',
        audioPath: path,
      );
```

- [ ] **Step 4: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze lib/screens/recording_review_screen.dart lib/router.dart`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/recording_review_screen.dart sabiData_frontend/lib/router.dart
git commit -m "feat(mobile): review joue le fichier réel et le soumet en multipart"
```

---

### Task 11: Réécoute du clip par le validateur dans `validation_screen`

**Files:**
- Modify: `sabiData_frontend/lib/screens/validation_screen.dart`
- Modify: `sabiData_frontend/lib/data/api/validation_api.dart` (exposer `audioUrl`)

**Interfaces:**
- Consumes: `GET /api/validation/next` → `audioUrl` (Task 5), `ApiClient.getBytes` (Task 7), `audioplayers`.
- Produces: bouton de lecture qui joue le clip à valider (via bytes).

- [ ] **Step 1: Surface `audioUrl` from the validation API**

In `sabiData_frontend/lib/data/api/validation_api.dart`, ensure the `next()` result exposes `audioUrl` (the endpoint now returns it). If the method returns the raw map, no change is needed; if it maps to a typed object, add an `audioUrl` field. Inspect the file and add:

```dart
  // dans le modèle/typed result de /validation/next
  final String? audioUrl;
```
and populate it from `json['audioUrl'] as String?`.

- [ ] **Step 2: Play the clip via bytes in `validation_screen`**

In `sabiData_frontend/lib/screens/validation_screen.dart`, add imports:

```dart
import 'package:audioplayers/audioplayers.dart';
import '../data/api/api_client.dart';
```

Add a player field and dispose (mirroring Task 10). Wire the existing "play" control's `onTap` to:

```dart
              onTap: () async {
                final url = _currentAudioUrl; // le audioUrl du clip courant chargé depuis /validation/next
                if (url == null) {
                  showAppSnack(context, 'Aucun audio pour ce clip.');
                  return;
                }
                final bytes = await ApiClient().getBytes(url);
                await _player.play(BytesSource(bytes));
              },
```

> Wire `_currentAudioUrl` from wherever the screen stores the current clip loaded from `/validation/next`. If `validation_screen` is still mock (no live fetch), the minimal deliverable is: fetch `/validation/next`, store `audioUrl`, and make the play button call `getBytes` + `BytesSource`. Keep the rest of the validation UI as-is.

- [ ] **Step 3: Analyze + commit**

Run: `cd sabiData_frontend && flutter analyze lib/screens/validation_screen.dart lib/data/api/validation_api.dart`
Expected: no errors.

```bash
cd /home/r_ghost/Projets/data/SABIDATA
git add sabiData_frontend/lib/screens/validation_screen.dart sabiData_frontend/lib/data/api/validation_api.dart
git commit -m "feat(mobile): le validateur réécoute réellement le clip (getBytes+BytesSource)"
```

---

### Task 12: Vérification manuelle bout-en-bout (device/LAN)

**Files:** aucun (vérification).

- [ ] **Step 1: Lancer le backend Postgres**

Run: `cd backend && DATABASE=pg RUN_SERVER=1 ./node_modules/.bin/tsx src/server.ts`
Expected: `SabiData API on 0.0.0.0:3000 (repo: postgres)`.

- [ ] **Step 2: Lancer l'app sur un appareil réel**

Run: `cd sabiData_frontend && flutter run` (device physique avec micro ; `ApiConfig.baseUrl` pointant sur l'IP LAN du backend).

- [ ] **Step 3: Cycle complet**

1. S'inscrire / se connecter.
2. Enregistrer un clip (≥ 2 s), accorder la permission micro.
3. Sur l'écran de revue : appuyer sur play → **on entend sa propre voix**.
4. Soumettre → succès `+points`.
5. Avec un 2ᵉ compte, aller en validation → play → **on entend le clip du 1er compte**.

- [ ] **Step 4: Vérifier le stockage serveur**

Run: `ls backend/var/audio/`
Expected: un fichier `<clipId>.m4a` par clip accepté ; aucun fichier pour un clip rejeté (trop court).

---

## Self-Review

**Spec coverage :**
- AudioStore fs + config + gitignore → Task 1. ✅
- `clips.audio_path` + `setClipAudio` → Task 2. ✅
- Stockage seulement si auto-check passe → Task 3 (test dédié). ✅
- POST multipart + 415/413/400 → Task 4. ✅
- GET audio + `audioUrl` dans `/validation/next` → Task 5. ✅
- Deps + permissions mobiles → Task 6. ✅
- `postMultipart`/`getBytes` → Task 7. ✅
- `ContributionApi` multipart → Task 8. ✅
- Capture micro réelle → Task 9. ✅
- Réécoute + submit review → Task 10. ✅
- Réécoute validateur → Task 11. ✅
- Critères d'acceptation (vérif device) → Task 12. ✅

**Placeholders :** les « Note » signalent des points à vérifier contre le code existant (builder de route `router.dart`, champ token de `register`, compétence par défaut) — ce sont des vérifications ciblées, pas des trous ; le code à écrire est fourni.

**Type consistency :** `AudioStore.save/openRead`, `setClipAudio(id, audioPath)`, `submitClip(..., audio?)`, `postMultipart(path, fields, {filePath})` sont utilisés de façon cohérente entre tasks. `ClipMultipartReq` (backend) ↔ champs form-data (mobile Task 8) alignés : `rarity`, `durationS`, `commercialUse`, `consentVersion`, `promptId`.
