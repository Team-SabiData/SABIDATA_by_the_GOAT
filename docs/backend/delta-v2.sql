-- =============================================================================
-- SabiData — DELTA v2 : réconciliation 2 clients (mobile + admin web)
-- Applique les décisions utilisateur 1-4. À lire APRÈS schema.sql (v1, dérivé
-- sous client unique — jamais déployé, donc on redéfinit librement).
--
-- Tags : [DÉCIDÉ] règle utilisateur · [RÉVISÉ]/[NOUVEAU]/[CONSERVÉ] vs v1
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- DÉCISION 1 — RBAC : enum rôle (grossier) + competence_level ordinal (fin)
-- ─────────────────────────────────────────────────────────────────────────────
-- [RÉVISÉ] reviewer/expert (v1) -> 'validator' ; + moderator, admin.
DROP TYPE IF EXISTS user_role CASCADE;                          -- design-only (jamais en prod)
CREATE TYPE user_role AS ENUM ('contributor','validator','moderator','admin');

ALTER TABLE users
  ADD COLUMN competence_level smallint NOT NULL DEFAULT 0       -- [NOUVEAU][DÉCIDÉ] dimension orthogonale
    CHECK (competence_level BETWEEN 0 AND 3),                   --   0=aucune .. 3=expert
  ADD COLUMN status text NOT NULL DEFAULT 'active'              -- [NOUVEAU] active|suspended|banned
    CHECK (status IN ('active','suspended','banned')),
  ADD COLUMN updated_at timestamptz NOT NULL DEFAULT now();     -- [NOUVEAU] audit

-- [NOUVEAU][DÉCIDÉ] table rôle->droits CENTRALISÉE (un seul endroit, pas de
-- guards éparpillés). competence_level n'y est PAS : c'est de la donnée de
-- routage de contenu (décision 2), pas un droit d'accès.
CREATE TABLE role_permissions (
  role        user_role NOT NULL,
  permission  text NOT NULL,        -- 'contribute','validate','content.read_any',
  PRIMARY KEY (role, permission)    -- 'content.moderate','dispute.arbitrate','user.manage','export.run'
);
INSERT INTO role_permissions(role, permission) VALUES
  ('contributor','contribute'),
  ('validator','contribute'), ('validator','validate'),
  ('moderator','validate'), ('moderator','content.read_any'),
  ('moderator','content.moderate'), ('moderator','dispute.arbitrate'),
  ('admin','*');   -- l'admin a tout (vérifié par '*' dans le guard central)

-- ─────────────────────────────────────────────────────────────────────────────
-- DÉCISION 2 — Curation : machine à états possédée par le BACKEND
--   pending -> auto_checked -> peer_review -> validated | rejected | disputed
--   (jamais d'état de validation dans un client)
-- ─────────────────────────────────────────────────────────────────────────────
-- [RÉVISÉ] clip_status (v1: pending/validated/rejected/escalated)
DROP TYPE IF EXISTS clip_status CASCADE;
CREATE TYPE clip_status AS ENUM
  ('pending','auto_checked','peer_review','validated','rejected','disputed');

CREATE TYPE moderation_status AS ENUM ('visible','flagged','hidden','removed'); -- [NOUVEAU]

ALTER TABLE clips
  ADD COLUMN required_competence smallint NOT NULL DEFAULT 1,   -- [NOUVEAU][DÉCIDÉ 1] routage pair-review
  ADD COLUMN autocheck jsonb,                                   -- [NOUVEAU][DÉCIDÉ 2] rapport format/durée/silence
  ADD COLUMN moderation moderation_status NOT NULL DEFAULT 'visible', -- [NOUVEAU]
  ADD COLUMN moderated_by uuid REFERENCES users(id);            -- [NOUVEAU] override admin/modo

-- Idem pour les transcriptions (même pipeline qualité).
ALTER TABLE transcriptions
  ADD COLUMN moderation moderation_status NOT NULL DEFAULT 'visible',
  ADD COLUMN moderated_by uuid REFERENCES users(id);

-- [RÉVISÉ] le vote porte le niveau de compétence (snapshot), remplace reviewer_is_std
ALTER TABLE validations
  DROP COLUMN reviewer_is_std,
  ADD COLUMN reviewer_competence smallint NOT NULL DEFAULT 0;   -- [DÉCIDÉ 1]

-- Constantes de pipeline
DELETE FROM app_config WHERE key = 'std_reviews_for_gold';
INSERT INTO app_config(key, value, note) VALUES
  ('reviews_for_gold',      2, '[DÉCIDÉ 1] validateurs concordants pour Or'),
  ('competence_for_gold',   2, '[DÉCIDÉ 1] niveau mini d''un validateur pour Or'),
  ('autocheck_min_seconds', 1, '[DÉCIDÉ 2] durée mini'),
  ('autocheck_max_seconds', 30,'[DÉCIDÉ 2] durée maxi');

-- Auto-check (format/durée/silence). Le calcul média réel = job backend (D6) ;
-- ici on modélise la TRANSITION d'état seulement.
CREATE OR REPLACE FUNCTION fn_apply_autocheck(p_clip uuid, p_passed boolean, p_report jsonb)
RETURNS void LANGUAGE plpgsql AS $$
BEGIN
  IF p_passed THEN
    UPDATE clips SET status='peer_review', autocheck=p_report WHERE id=p_clip AND status='pending';
  ELSE
    UPDATE clips SET status='rejected', autocheck=p_report WHERE id=p_clip AND status='pending';
    UPDATE points_ledger SET state='reversed' WHERE ref_clip_id=p_clip AND state='provisional';
  END IF;
END $$;

-- [RÉVISÉ] consensus pair-review -> validated/rejected/disputed (ex-"escalated")
CREATE OR REPLACE FUNCTION fn_recompute_clip_status(p_clip uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_correct int; v_problem int; v_total int; v_net int; v_cur clip_status;
BEGIN
  SELECT status INTO v_cur FROM clips WHERE id=p_clip;
  IF v_cur <> 'peer_review' THEN RETURN; END IF;   -- ne vote que pendant la pair-review

  SELECT COUNT(*) FILTER (WHERE verdict='correct'),
         COUNT(*) FILTER (WHERE verdict='problem'), COUNT(*)
    INTO v_correct, v_problem, v_total
  FROM validations WHERE clip_id=p_clip;

  v_net := v_correct - v_problem;
  IF    v_net >=  cfg('net_validate') THEN UPDATE clips SET status='validated' WHERE id=p_clip;
  ELSIF v_net <= -cfg('net_reject')  THEN UPDATE clips SET status='rejected'  WHERE id=p_clip;
  ELSIF v_total >= cfg('votes_cap')  THEN UPDATE clips SET status='disputed'  WHERE id=p_clip; -- -> file admin
  END IF;  -- sinon reste peer_review
END $$;

-- [RÉVISÉ] tier : "relecteur standard" -> validateur de competence suffisante
CREATE OR REPLACE FUNCTION fn_compute_tier(p_tr uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE r record; v_correct int; v_problem int; v_qualified int;
        v_matches boolean; v_tier quality_tier;
BEGIN
  SELECT * INTO r FROM transcriptions WHERE id=p_tr;
  SELECT COUNT(*) FILTER (WHERE verdict='correct'),
         COUNT(*) FILTER (WHERE verdict='problem'),
         COUNT(*) FILTER (WHERE verdict='correct'
                          AND reviewer_competence >= cfg('competence_for_gold'))
    INTO v_correct, v_problem, v_qualified
  FROM validations WHERE transcription_id=p_tr;

  IF v_problem >= 1 AND v_correct < cfg('quorum_audio') THEN v_matches:=false;
  ELSIF v_correct >= cfg('quorum_audio')               THEN v_matches:=true;
  ELSE                                                       v_matches:=NULL; END IF;

  IF v_matches IS NOT TRUE THEN v_tier:='raw';
  ELSIF r.writing_system='std' THEN
    IF v_qualified >= cfg('reviews_for_gold') THEN v_tier:='gold';
    ELSIF v_correct >= cfg('quorum_audio')    THEN v_tier:='silver';
    ELSE  v_tier:='raw'; END IF;
  ELSE
    IF r.consistency_score >= cfg('consistency_high') AND v_correct >= cfg('quorum_audio')
         THEN v_tier:='silver';
    ELSIF r.consistency_score >= cfg('consistency_ok') THEN v_tier:='bronze';
    ELSE  v_tier:='raw'; END IF;
  END IF;

  UPDATE transcriptions SET matches_audio=v_matches, tier=v_tier WHERE id=p_tr;
  IF v_tier='bronze' THEN
    INSERT INTO conversion_tasks(source_transcription_id) VALUES (p_tr)
      ON CONFLICT (source_transcription_id) DO NOTHING;
  END IF;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- DÉCISION 3 — Auth admin asymétrique (TOTP, sessions courtes, audit immuable)
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE admin_totp (                                       -- [NOUVEAU][DÉCIDÉ 3]
  user_id     uuid PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  secret      text NOT NULL,
  confirmed_at timestamptz
);
CREATE TABLE admin_recovery_codes (                             -- [NOUVEAU][DÉCIDÉ 3]
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id   uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  code_hash text NOT NULL,
  used_at   timestamptz
);
CREATE TABLE admin_sessions (                                   -- [NOUVEAU][DÉCIDÉ 3] TTL court
  token      text PRIMARY KEY,
  user_id    uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_ip inet,
  expires_at timestamptz NOT NULL                               -- [DÉCIDÉ] ~30 min
);

-- Journal d'audit IMMUABLE de toute action admin (export, mutation, suppression…)
CREATE TABLE admin_audit_log (                                  -- [NOUVEAU][DÉCIDÉ 3]
  id        uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_id  uuid NOT NULL REFERENCES users(id),
  action    text NOT NULL,        -- 'user.update','clip.moderate','withdrawal.settle','export.run'
  entity    text, entity_id uuid,
  before    jsonb, after jsonb,
  ip        inet,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE RULE audit_no_update AS ON UPDATE TO admin_audit_log DO INSTEAD NOTHING; -- append-only
CREATE RULE audit_no_delete AS ON DELETE TO admin_audit_log DO INSTEAD NOTHING;

-- Cycle de vie du retrait : acteur back-office (manquait en v1)
ALTER TABLE withdrawals
  ADD COLUMN processed_by   uuid REFERENCES users(id),          -- [NOUVEAU]
  ADD COLUMN processed_at   timestamptz,                        -- [NOUVEAU]
  ADD COLUMN failure_reason text;                               -- [NOUVEAU]

-- ─────────────────────────────────────────────────────────────────────────────
-- DÉCISION 4 — Exports : chaîne de CONSENTEMENT maintenant, format BLOQUÉ
-- ─────────────────────────────────────────────────────────────────────────────
-- (a) Conception export (format/licence/livraison) = BLOQUÉE-SUR-ACHETEUR :
--     AUCUNE table d'export n'est créée tant que l'acheteur nommé + sa spec
--     écrite n'existent pas. (§8.6 reste "bloquée", pas "dessinée".)
-- (b) Ce qu'on construit MAINTENANT : capture immuable du consentement et de la
--     licence sur le chemin de contribution, invariant légal qui circule
--     jusqu'à l'export.
ALTER TABLE clips
  ADD COLUMN commercial_use boolean NOT NULL DEFAULT false,     -- [NOUVEAU][DÉCIDÉ 4] usage commercial OK ?
  ADD COLUMN consent_version text NOT NULL DEFAULT 'v1',        -- [NOUVEAU][DÉCIDÉ 4] version du texte accepté
  ADD COLUMN license_tag text NOT NULL DEFAULT 'unlicensed',    -- [NOUVEAU][DÉCIDÉ 4] tag immuable
  ADD COLUMN provenance jsonb;                                  -- [NOUVEAU][DÉCIDÉ 4] qui/quand/appareil/langue

-- Immuabilité de la chaîne de consentement (write-once à la création).
CREATE OR REPLACE FUNCTION trg_consent_immutable()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.commercial_use  IS DISTINCT FROM OLD.commercial_use
   OR NEW.consent_version IS DISTINCT FROM OLD.consent_version
   OR NEW.license_tag     IS DISTINCT FROM OLD.license_tag
   OR NEW.provenance      IS DISTINCT FROM OLD.provenance THEN
    RAISE EXCEPTION 'consentement/licence immuable après création (décision 4)';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER consent_immutable BEFORE UPDATE ON clips
  FOR EACH ROW EXECUTE FUNCTION trg_consent_immutable();
-- =============================================================================
