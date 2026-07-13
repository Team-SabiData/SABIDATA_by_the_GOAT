-- =============================================================================
-- SabiData — Schéma de base de données (PostgreSQL 15+)
-- Reconstruit depuis le frontend Flutter (mocks) + recherche (README, doc tiers).
--
-- Tags :  [OBS] lu dans le code/mock · [RECH] recherche métier
--         [INF] déduit · [DÉC] décision gelée (défaut, modifiable)
--
-- Décisions intégrées : D1 (tiers), D2 (auth multi-méthode), D3 (quorum),
-- D4 (points/FCFA en 2 phases). Constantes regroupées dans `app_config`.
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;   -- gen_random_uuid()

-- ----------------------------------------------------------------------------
-- 0. ENUMS
-- ----------------------------------------------------------------------------
CREATE TYPE user_role        AS ENUM ('contributor', 'standard_reviewer', 'expert');         -- [DÉC] D11
CREATE TYPE identity_type    AS ENUM ('phone', 'email');                                      -- [OBS] D2
CREATE TYPE write_level      AS ENUM ('none', 'phonetic', 'standard');                        -- [OBS] skill_profile
CREATE TYPE writing_system   AS ENUM ('std', 'phon');                                         -- [RECH] D1
CREATE TYPE quality_tier     AS ENUM ('gold', 'silver', 'bronze', 'raw');                     -- [RECH] Or/Argent/Bronze/Brut
CREATE TYPE clip_status      AS ENUM ('pending', 'validated', 'rejected', 'escalated');       -- [INF] D3
CREATE TYPE verdict_type     AS ENUM ('correct', 'problem', 'unsure');                        -- [OBS] validation
CREATE TYPE ledger_state     AS ENUM ('provisional', 'confirmed', 'reversed');                -- [DÉC] D4
CREATE TYPE ledger_reason    AS ENUM ('record', 'validate', 'transcribe', 'convert', 'daily_task',
                                      'admin_adjustment', 'withdrawal', 'withdrawal_refund');   -- [OBS] +ajustements admin & retraits
CREATE TYPE user_status      AS ENUM ('active', 'suspended', 'banned', 'deleted');             -- [OBS] modération admin
CREATE TYPE withdrawal_status AS ENUM ('processing', 'paid', 'failed');                       -- [INF]
CREATE TYPE mm_provider      AS ENUM ('orange_money', 'moov_money', 'wave');                  -- [OBS] revenue
CREATE TYPE conversion_status AS ENUM ('open', 'done');                                       -- [INF]

-- ----------------------------------------------------------------------------
-- 1. CONFIG — constantes gelées D1..D4 (modifiables sans redéploiement)
-- ----------------------------------------------------------------------------
CREATE TABLE app_config (
  key   text PRIMARY KEY,
  value numeric NOT NULL,
  note  text
);
INSERT INTO app_config (key, value, note) VALUES
  ('point_to_fcfa',        5,   '[OBS] 1 pt = 5 FCFA (2750/550)'),          -- D4
  ('reward_record',        50,  '[OBS]'),
  ('reward_validate',      20,  '[OBS]'),
  ('reward_transcribe',    80,  '[OBS]'),
  ('reward_convert',       120, '[OBS]'),
  ('daily_task_bonus',     250, '[OBS]'),
  ('withdraw_min_fcfa',    500, '[OBS]'),
  ('votes_min',            2,   '[DÉC] D3'),
  ('votes_cap',            5,   '[DÉC] D3 escalade'),
  ('net_validate',         2,   '[DÉC] D3'),
  ('net_reject',           2,   '[DÉC] D3 (valeur absolue)'),
  ('quorum_audio',         2,   '[RECH] D1'),
  ('std_reviews_for_gold', 2,   '[RECH] D1'),
  ('consistency_high',     0.85,'[DÉC] D1'),
  ('consistency_ok',       0.60,'[DÉC] D1');

CREATE OR REPLACE FUNCTION cfg(p_key text) RETURNS numeric
LANGUAGE sql STABLE AS $$ SELECT value FROM app_config WHERE key = p_key $$;

-- ----------------------------------------------------------------------------
-- 2. IDENTITÉ & AUTH  (D2 : un User, plusieurs identités ; téléphone = ancre)
-- ----------------------------------------------------------------------------
CREATE TABLE users (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name            text NOT NULL,                              -- [OBS] register
  role            user_role NOT NULL DEFAULT 'contributor',   -- [DÉC] D11
  status          user_status NOT NULL DEFAULT 'active',       -- [OBS] modération admin (suspend/ban/soft-delete anonymisé)
  commune         text,                                       -- [OBS] dialect_region
  region          text,                                       -- [OBS]
  current_language_id uuid,                                   -- [INF] langue de session (FK plus bas)
  notif_enabled   boolean NOT NULL DEFAULT true,              -- [OBS] profile
  created_at      timestamptz NOT NULL DEFAULT now()
);

-- D2 : une ligne par méthode de connexion ; lie email + phone au même user.
CREATE TABLE auth_identity (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  type         identity_type NOT NULL,                        -- [OBS] phone | email
  value        text NOT NULL,                                 -- MSISDN ou email
  secret_hash  text,                                          -- [DÉC] argon2id (email) ; null pour phone
  verified_at  timestamptz,                                   -- [OBS] OTP / vérif email
  created_at   timestamptz NOT NULL DEFAULT now(),
  UNIQUE (type, value)                                        -- [DÉC] D7 idempotence identité
);
CREATE INDEX idx_auth_identity_user ON auth_identity(user_id);

-- OTP éphémère (D2). Tout code accepté côté mock ; ici vrai cycle de vie.
CREATE TABLE otp_codes (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       text NOT NULL,
  code_hash   text NOT NULL,
  expires_at  timestamptz NOT NULL,                           -- [DÉC] 5 min
  consumed_at timestamptz
);
CREATE INDEX idx_otp_phone ON otp_codes(phone);

CREATE TABLE refresh_tokens (
  token       text PRIMARY KEY,                               -- [DÉC] D2 refresh 30j
  user_id     uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz
);

-- ----------------------------------------------------------------------------
-- 3. RÉFÉRENTIEL LINGUISTIQUE
-- ----------------------------------------------------------------------------
CREATE TABLE languages (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  code          text UNIQUE NOT NULL,                         -- [INF] 'moore','dioula',…
  name          text NOT NULL,                                -- [OBS]
  emoji         text,                                         -- [OBS]
  region_label  text,                                         -- [OBS]
  speakers_est  integer                                       -- [OBS] "~5M"
);

ALTER TABLE users
  ADD CONSTRAINT fk_users_current_language
  FOREIGN KEY (current_language_id) REFERENCES languages(id);

-- Dialecte/zone. clips_count / coverage_pct / rarity sont DÉRIVÉS (voir vues).
CREATE TABLE regions (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  language_id   uuid NOT NULL REFERENCES languages(id),
  name          text NOT NULL,                                -- [OBS] Ouagadougou, Yatenga…
  zone          text,                                         -- [OBS] Centre, Nord…
  rarity_tier   smallint NOT NULL DEFAULT 0                   -- [OBS] 0/1/2  [DÉC] dérivable des clips
                  CHECK (rarity_tier BETWEEN 0 AND 2),
  UNIQUE (language_id, name)
);

CREATE TABLE user_language_skills (
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  language_id  uuid NOT NULL REFERENCES languages(id),
  can_speak    boolean NOT NULL DEFAULT false,                -- [OBS]
  can_read     boolean NOT NULL DEFAULT false,                -- [OBS]
  write_lvl    write_level NOT NULL DEFAULT 'none',           -- [OBS]
  PRIMARY KEY (user_id, language_id)
);

-- Phrases-source à enregistrer (corpus serveur). [INF]
CREATE TABLE prompts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  text_fr         text NOT NULL,                              -- [OBS] "Le marché se tient…"
  target_language_id uuid NOT NULL REFERENCES languages(id),
  active          boolean NOT NULL DEFAULT true
);

-- Archives radio RTB à transcrire. [OBS]
CREATE TABLE archive_audios (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL,                                 -- [OBS] "Journal en Dioula"
  source       text NOT NULL DEFAULT 'RTB',                   -- [OBS]
  year         integer,                                       -- [OBS] 1988
  language_id  uuid NOT NULL REFERENCES languages(id),
  duration_s   integer,                                       -- [OBS]
  audio_url    text NOT NULL                                  -- [INF] D6
);

-- ----------------------------------------------------------------------------
-- 4. COLLECTE : clips + validations
-- ----------------------------------------------------------------------------
CREATE TABLE clips (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  contributor_id uuid NOT NULL REFERENCES users(id),
  prompt_id     uuid REFERENCES prompts(id),
  language_id   uuid NOT NULL REFERENCES languages(id),
  region_id     uuid REFERENCES regions(id),
  audio_url     text NOT NULL,                                -- [INF] D6 (upload pré-signé)
  duration_s    integer,                                      -- [OBS] review
  status        clip_status NOT NULL DEFAULT 'pending',       -- [INF] dérivé des votes (D3)
  client_uuid   text,                                         -- [DÉC] D5/D7 dédup offline
  created_at    timestamptz NOT NULL DEFAULT now(),
  UNIQUE (contributor_id, client_uuid)                        -- [DÉC] idempotence upload
);
CREATE INDEX idx_clips_status ON clips(status);
CREATE INDEX idx_clips_contributor ON clips(contributor_id);

CREATE TABLE validations (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  validator_id   uuid NOT NULL REFERENCES users(id),
  clip_id        uuid REFERENCES clips(id) ON DELETE CASCADE,
  transcription_id uuid,                                      -- FK ajoutée plus bas (cible alt.)
  verdict        verdict_type NOT NULL,                       -- [OBS]
  reviewer_is_std boolean NOT NULL DEFAULT false,             -- [RECH] D1 snapshot du rôle
  created_at     timestamptz NOT NULL DEFAULT now(),
  -- Exactement une cible (clip OU transcription)
  CHECK ( (clip_id IS NOT NULL)::int + (transcription_id IS NOT NULL)::int = 1 ),
  -- D7 : un seul vote par (cible, validateur)
  UNIQUE (clip_id, validator_id),
  UNIQUE (transcription_id, validator_id)
);

-- ----------------------------------------------------------------------------
-- 5. QUALITÉ : transcriptions (D1) + tâches de conversion
-- ----------------------------------------------------------------------------
CREATE TABLE transcriptions (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id         uuid NOT NULL REFERENCES users(id),
  clip_id           uuid REFERENCES clips(id),                -- cible : un clip…
  archive_id        uuid REFERENCES archive_audios(id),       -- …ou une archive RTB
  text              text NOT NULL,                            -- [OBS]
  writing_system    writing_system NOT NULL,                  -- [RECH] D1
  consistency_score numeric NOT NULL DEFAULT 0.60,            -- [RECH] D1 (MVP heuristique)
  matches_audio     boolean,                                  -- [RECH] dérivé (null=en attente)
  tier              quality_tier,                             -- [RECH] dérivé (D1)
  parent_id         uuid REFERENCES transcriptions(id),       -- [RECH] conversion bronze→or
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK ( (clip_id IS NOT NULL)::int + (archive_id IS NOT NULL)::int = 1 )
);
CREATE INDEX idx_transc_tier ON transcriptions(tier);

ALTER TABLE validations
  ADD CONSTRAINT fk_val_transcription
  FOREIGN KEY (transcription_id) REFERENCES transcriptions(id) ON DELETE CASCADE;

-- File des conversions bronze→or (engendrée par trigger sur tier='bronze'). [RECH]
CREATE TABLE conversion_tasks (
  id                     uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  source_transcription_id uuid NOT NULL UNIQUE REFERENCES transcriptions(id) ON DELETE CASCADE,
  status                 conversion_status NOT NULL DEFAULT 'open',
  claimed_by             uuid REFERENCES users(id),           -- [DÉC] D11 std_reviewer/expert
  created_at             timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_conv_status ON conversion_tasks(status);

-- ----------------------------------------------------------------------------
-- 6. ÉCONOMIE : ledger (2 phases, D4) + retraits
-- ----------------------------------------------------------------------------
CREATE TABLE points_ledger (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  delta       integer NOT NULL,                               -- points (peut être négatif si reversal)
  reason      ledger_reason NOT NULL,                         -- [OBS]
  state       ledger_state NOT NULL DEFAULT 'confirmed',      -- [DÉC] D4 provisional→confirmed
  ref_clip_id uuid REFERENCES clips(id),
  ref_transcription_id uuid REFERENCES transcriptions(id),
  created_at  timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_ledger_user ON points_ledger(user_id, state);

CREATE TABLE withdrawals (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  amount_fcfa integer NOT NULL CHECK (amount_fcfa >= 500),    -- [OBS] D4 min 500
  provider    mm_provider NOT NULL,                           -- [OBS]
  status      withdrawal_status NOT NULL DEFAULT 'processing',-- [INF]
  client_uuid text,                                           -- [DÉC] D7 idempotence
  created_at  timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, client_uuid)
);

-- ----------------------------------------------------------------------------
-- 7. ENGAGEMENT : tâche du jour
-- ----------------------------------------------------------------------------
CREATE TABLE daily_tasks (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid NOT NULL REFERENCES users(id),
  day         date NOT NULL DEFAULT current_date,
  type        ledger_reason NOT NULL DEFAULT 'record',        -- [OBS] "Enregistre 5 phrases"
  target      integer NOT NULL,                               -- [OBS] 5
  reward      integer NOT NULL,                               -- [OBS] 250
  UNIQUE (user_id, day)
);

-- ----------------------------------------------------------------------------
-- 8. B2B (différé — D10). Schéma posé, économie non figée.
-- ----------------------------------------------------------------------------
CREATE TABLE classrooms (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name        text NOT NULL,                                  -- [OBS] "Lycée Bogodogo · 6èA"
  join_code   text UNIQUE NOT NULL                            -- [OBS] rejoindre par code
);
CREATE TABLE class_memberships (
  classroom_id uuid NOT NULL REFERENCES classrooms(id) ON DELETE CASCADE,
  user_id      uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  PRIMARY KEY (classroom_id, user_id)
);
CREATE TABLE class_challenges (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title        text NOT NULL,                                 -- [OBS] "Préservez le Mooré…"
  target_clips integer NOT NULL,                              -- [OBS] 2000
  reward       text,                                          -- [OBS] "matériel scolaire"
  period_start date, period_end date
);

-- =============================================================================
-- 9. VUES — champs DÉRIVÉS (logique, pas stockage)
-- =============================================================================

-- D4 : points confirmés par utilisateur. [INF]
CREATE VIEW v_user_points AS
  SELECT user_id, COALESCE(SUM(delta) FILTER (WHERE state='confirmed'), 0) AS points_total
  FROM points_ledger GROUP BY user_id;

-- D4 : solde FCFA = points confirmés × taux − retraits non échoués. [INF]
CREATE VIEW v_user_balance AS
  SELECT u.id AS user_id,
         (COALESCE(p.points_total,0) * cfg('point_to_fcfa'))::int
         - COALESCE((SELECT SUM(amount_fcfa) FROM withdrawals w
                     WHERE w.user_id=u.id AND w.status <> 'failed'), 0) AS balance_fcfa
  FROM users u LEFT JOIN v_user_points p ON p.user_id = u.id;

-- Badge dérivé du nombre de contributions validées. [INF] (≠ points)
CREATE VIEW v_user_validated AS
  SELECT contributor_id AS user_id, COUNT(*) AS validated_count
  FROM clips WHERE status='validated' GROUP BY contributor_id;

-- Couverture par dialecte (clips_count, pct). [OBS dérivé]
CREATE VIEW v_region_coverage AS
  SELECT r.id AS region_id, r.name, r.language_id,
         COUNT(c.id) AS clips_count,
         ROUND(COUNT(c.id)::numeric / NULLIF(MAX(COUNT(c.id)) OVER (PARTITION BY r.language_id),0), 2) AS coverage_pct
  FROM regions r LEFT JOIN clips c ON c.region_id = r.id
  GROUP BY r.id, r.name, r.language_id;

-- Répartition des tiers du dataset (écran Expert). [OBS dérivé]
CREATE VIEW v_dataset_tiers AS
  SELECT COALESCE(c.language_id, a.language_id) AS language_id, t.tier, COUNT(*) AS count
  FROM transcriptions t
  LEFT JOIN clips c ON c.id = t.clip_id
  LEFT JOIN archive_audios a ON a.id = t.archive_id
  WHERE t.tier IS NOT NULL
  GROUP BY 1, t.tier;

-- Classement national (commune/région : filtrer sur users.region/commune). [OBS dérivé]
CREATE VIEW v_leaderboard AS
  SELECT u.id AS user_id, u.name, u.commune, u.region,
         COALESCE(p.points_total,0) AS points,
         RANK() OVER (ORDER BY COALESCE(p.points_total,0) DESC) AS rank_national
  FROM users u LEFT JOIN v_user_points p ON p.user_id = u.id;

-- Flux d'activité (feed dashboard) = ledger + statut clip. [OBS dérivé]
CREATE VIEW v_activity AS
  SELECT l.user_id, l.reason, l.delta AS reward, l.created_at,
         c.status AS clip_status
  FROM points_ledger l LEFT JOIN clips c ON c.id = l.ref_clip_id
  ORDER BY l.created_at DESC;

-- =============================================================================
-- 10. LOGIQUE — fonctions & triggers (D1, D3, D4)
-- =============================================================================

-- D3 : recalcul du statut d'un clip après chaque vote.
CREATE OR REPLACE FUNCTION fn_recompute_clip_status(p_clip uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE v_correct int; v_problem int; v_total int; v_net int; v_new clip_status;
BEGIN
  SELECT COUNT(*) FILTER (WHERE verdict='correct'),
         COUNT(*) FILTER (WHERE verdict='problem'),
         COUNT(*)
    INTO v_correct, v_problem, v_total
  FROM validations WHERE clip_id = p_clip;

  v_net := v_correct - v_problem;
  IF v_total < cfg('votes_min') THEN              v_new := 'pending';
  ELSIF v_net >=  cfg('net_validate') THEN        v_new := 'validated';
  ELSIF v_net <= -cfg('net_reject')  THEN         v_new := 'rejected';
  ELSIF v_total >= cfg('votes_cap')  THEN         v_new := 'escalated';
  ELSE                                            v_new := 'pending';
  END IF;

  UPDATE clips SET status = v_new WHERE id = p_clip AND status <> v_new;
END $$;

-- D1 : calcul du tier d'une transcription.
CREATE OR REPLACE FUNCTION fn_compute_tier(p_tr uuid)
RETURNS void LANGUAGE plpgsql AS $$
DECLARE r record; v_correct int; v_problem int; v_std int;
        v_matches boolean; v_tier quality_tier;
BEGIN
  SELECT * INTO r FROM transcriptions WHERE id = p_tr;

  SELECT COUNT(*) FILTER (WHERE verdict='correct'),
         COUNT(*) FILTER (WHERE verdict='problem'),
         COUNT(*) FILTER (WHERE verdict='correct' AND reviewer_is_std)
    INTO v_correct, v_problem, v_std
  FROM validations WHERE transcription_id = p_tr;

  -- Juge final : colle à l'audio ? [RECH]
  IF v_problem >= 1 AND v_correct < cfg('quorum_audio') THEN v_matches := false;
  ELSIF v_correct >= cfg('quorum_audio') THEN               v_matches := true;
  ELSE                                                       v_matches := NULL;
  END IF;

  -- Attribution du tier [RECH]
  IF v_matches IS NOT TRUE THEN
    v_tier := 'raw';
  ELSIF r.writing_system = 'std' THEN
    IF v_std >= cfg('std_reviews_for_gold') THEN v_tier := 'gold';
    ELSIF v_correct >= cfg('quorum_audio')  THEN v_tier := 'silver';
    ELSE                                          v_tier := 'raw'; END IF;
  ELSE  -- phon
    IF r.consistency_score >= cfg('consistency_high') AND v_correct >= cfg('quorum_audio')
         THEN v_tier := 'silver';
    ELSIF r.consistency_score >= cfg('consistency_ok')
         THEN v_tier := 'bronze';
    ELSE      v_tier := 'raw'; END IF;
  END IF;

  UPDATE transcriptions SET matches_audio = v_matches, tier = v_tier WHERE id = p_tr;

  -- Effet de bord : bronze -> tâche de conversion (réutilise le travail) [RECH]
  IF v_tier = 'bronze' THEN
    INSERT INTO conversion_tasks (source_transcription_id)
    VALUES (p_tr) ON CONFLICT (source_transcription_id) DO NOTHING;
  END IF;
END $$;

-- Dispatch après insertion d'un vote (clip ou transcription).
CREATE OR REPLACE FUNCTION trg_after_validation()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.clip_id IS NOT NULL THEN
    PERFORM fn_recompute_clip_status(NEW.clip_id);
  ELSE
    PERFORM fn_compute_tier(NEW.transcription_id);
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER after_validation AFTER INSERT ON validations
  FOR EACH ROW EXECUTE FUNCTION trg_after_validation();

-- D4 : crédit provisoire à la soumission d'un clip (×rareté sur l'enregistrement).
CREATE OR REPLACE FUNCTION trg_clip_insert_ledger()
RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE v_mult int;
BEGIN
  SELECT CASE COALESCE(r.rarity_tier,0) WHEN 2 THEN 3 WHEN 1 THEN 2 ELSE 1 END
    INTO v_mult FROM regions r WHERE r.id = NEW.region_id;
  v_mult := COALESCE(v_mult, 1);

  INSERT INTO points_ledger (user_id, delta, reason, state, ref_clip_id)
  VALUES (NEW.contributor_id, (cfg('reward_record')*v_mult)::int, 'record', 'provisional', NEW.id);
  RETURN NEW;
END $$;
CREATE TRIGGER clip_insert_ledger AFTER INSERT ON clips
  FOR EACH ROW EXECUTE FUNCTION trg_clip_insert_ledger();

-- D4 : confirmation / annulation des points quand le clip change de statut.
CREATE OR REPLACE FUNCTION trg_clip_status_ledger()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.status = 'validated' AND OLD.status <> 'validated' THEN
    UPDATE points_ledger SET state='confirmed'
      WHERE ref_clip_id = NEW.id AND state='provisional';
  ELSIF NEW.status = 'rejected' AND OLD.status <> 'rejected' THEN
    UPDATE points_ledger SET state='reversed'
      WHERE ref_clip_id = NEW.id AND state='provisional';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER clip_status_ledger AFTER UPDATE OF status ON clips
  FOR EACH ROW EXECUTE FUNCTION trg_clip_status_ledger();

-- NB. validate(+20) et convert(+120) sont crédités 'confirmed' directement par
-- l'application au moment du POST (l'acte de valider/convertir EST la contribution).
-- =============================================================================
