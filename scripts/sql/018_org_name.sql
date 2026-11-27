-- 018_org_name.sql
-- Имена под org.org: периоды формулы, опц. строки, опц. целочисленный номер.
-- Канон: docs/org/26-1127_org_name.md
-- Только valid_from; конец — VIEW (half-open). Legacy sovereign_* не трогаем.
-- Seed v0: germany / austria / japan (из sovereign_name_form.note → org_name).
-- После 010–017. Идемпотентность: IF NOT EXISTS / ON CONFLICT.

BEGIN;

-- ---------------------------------------------------------------------------
-- Справочник ролей имени
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_name_kind (
    code  TEXT PRIMARY KEY,
    name  TEXT NOT NULL,
    note  TEXT
);

COMMENT ON TABLE org.org_name_kind IS
    'Роль строки org_name: full, short, …';

INSERT INTO org.org_name_kind (code, name, note) VALUES
    ('full',  'Полное / официальное имя', 'Несводимый титул на языке L'),
    ('short', 'Краткое имя',              'Опционально; не композит полка+num')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Период формулы на org
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_name_form (
    id            BIGSERIAL PRIMARY KEY,
    org_id        BIGINT NOT NULL REFERENCES org.org (id),
    name_form_id  BIGINT NOT NULL REFERENCES org.name_form (id),
    valid_from    DATE NOT NULL,
    note          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT org_name_form_org_from_uk UNIQUE (org_id, valid_from)
);

COMMENT ON TABLE org.org_name_form IS
    'Период: org сидит на name_form с valid_from; конец вычисляемый (LEAD / trm org).';
COMMENT ON COLUMN org.org_name_form.valid_from IS
    'Начало периода (half-open). Календарь A — григориан.';

CREATE INDEX IF NOT EXISTS ix_org_name_form_org
    ON org.org_name_form (org_id);

CREATE INDEX IF NOT EXISTS ix_org_name_form_nf
    ON org.org_name_form (name_form_id);

-- assignable: как у sovereign_name_form
CREATE OR REPLACE FUNCTION org.trg_org_name_form_assignable()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    v_ok BOOLEAN;
BEGIN
    SELECT assignable INTO v_ok FROM org.name_form WHERE id = NEW.name_form_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'name_form id=% not found', NEW.name_form_id;
    END IF;
    IF NOT v_ok THEN
        RAISE EXCEPTION 'name_form id=% is not assignable', NEW.name_form_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS ct_org_name_form_assignable ON org.org_name_form;
CREATE TRIGGER ct_org_name_form_assignable
    BEFORE INSERT OR UPDATE OF name_form_id ON org.org_name_form
    FOR EACH ROW EXECUTE FUNCTION org.trg_org_name_form_assignable();

-- ---------------------------------------------------------------------------
-- Строки имён (опционально)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_name (
    id                BIGSERIAL PRIMARY KEY,
    org_name_form_id  BIGINT NOT NULL REFERENCES org.org_name_form (id) ON DELETE CASCADE,
    language_code     TEXT NOT NULL REFERENCES org.language (code),
    kind_code         TEXT NOT NULL REFERENCES org.org_name_kind (code),
    valid_from        DATE NOT NULL,
    name              TEXT NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT org_name_uk UNIQUE (org_name_form_id, language_code, kind_code, valid_from)
);

COMMENT ON TABLE org.org_name IS
    'Несводимая строка имени на языке L в пределах периода формулы. Не обязательна, если хватает полки+num.';

CREATE INDEX IF NOT EXISTS ix_org_name_form_id
    ON org.org_name (org_name_form_id);

-- ---------------------------------------------------------------------------
-- Номер (опционально; INT; ВС, школы, округа, …)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_num (
    id                BIGSERIAL PRIMARY KEY,
    org_name_form_id  BIGINT NOT NULL REFERENCES org.org_name_form (id) ON DELETE CASCADE,
    valid_from        DATE NOT NULL,
    value             INT NOT NULL,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT org_num_uk UNIQUE (org_name_form_id, valid_from)
);

COMMENT ON TABLE org.org_num IS
    'Целочисленный номер в периоде формулы. Оформление 5./5th — правило языка при склейке.';
COMMENT ON COLUMN org.org_num.value IS
    'Целое; не хранить суффиксы языка.';

CREATE INDEX IF NOT EXISTS ix_org_num_form_id
    ON org.org_num (org_name_form_id);

-- ---------------------------------------------------------------------------
-- Effective VIEW (half-open [valid_from, effective_to))
-- ---------------------------------------------------------------------------
CREATE OR REPLACE VIEW org.org_name_form_effective AS
SELECT
    f.id,
    f.org_id,
    o.code AS org_code,
    f.name_form_id,
    nf.code AS name_form_code,
    f.valid_from,
    COALESCE(
        LEAD(f.valid_from) OVER (PARTITION BY f.org_id ORDER BY f.valid_from),
        o.trm_date
    ) AS effective_to,
    f.note
FROM org.org_name_form f
JOIN org.org o ON o.id = f.org_id
JOIN org.name_form nf ON nf.id = f.name_form_id;

COMMENT ON VIEW org.org_name_form_effective IS
    'org_name_form + effective_to = next form valid_from or org.trm_date (half-open)';

CREATE OR REPLACE VIEW org.org_name_effective AS
SELECT
    n.id,
    n.org_name_form_id,
    fe.org_id,
    fe.org_code,
    fe.name_form_code,
    n.language_code,
    n.kind_code,
    n.valid_from,
    n.name,
    COALESCE(
        LEAD(n.valid_from) OVER (
            PARTITION BY n.org_name_form_id, n.language_code, n.kind_code
            ORDER BY n.valid_from
        ),
        fe.effective_to
    ) AS effective_to
FROM org.org_name n
JOIN org.org_name_form_effective fe ON fe.id = n.org_name_form_id;

COMMENT ON VIEW org.org_name_effective IS
    'org_name + effective_to = next same kind/lang or parent form effective_to';

CREATE OR REPLACE VIEW org.org_num_effective AS
SELECT
    u.id,
    u.org_name_form_id,
    fe.org_id,
    fe.org_code,
    fe.name_form_code,
    u.valid_from,
    u.value,
    COALESCE(
        LEAD(u.valid_from) OVER (
            PARTITION BY u.org_name_form_id ORDER BY u.valid_from
        ),
        fe.effective_to
    ) AS effective_to
FROM org.org_num u
JOIN org.org_name_form_effective fe ON fe.id = u.org_name_form_id;

COMMENT ON VIEW org.org_num_effective IS
    'org_num + effective_to = next num or parent form effective_to';

-- ---------------------------------------------------------------------------
-- Seed: периоды + full-имена DE / AT / JP
-- ---------------------------------------------------------------------------
INSERT INTO org.org_name_form (org_id, name_form_id, valid_from, note)
SELECT o.id, nf.id, v.valid_from::date, v.note
FROM (VALUES
    ('germany', 'reich',       '1871-01-18', 'Период Deutsches Reich (зеркало sovereign_name_form)'),
    ('germany', 'reich',       '1943-06-26', 'Период Großdeutsches Reich'),
    ('austria', 'kaisertum',   '1804-08-11', 'Kaisertum Österreich'),
    ('japan',   'kaiserreich', '1889-11-29', 'Dai-Nippon Teikoku'),
    ('japan',   'state',       '1947-05-03', 'Nihon-koku')
) AS v(org_code, form_code, valid_from, note)
JOIN org.org o ON o.code = v.org_code
JOIN org.name_form nf ON nf.code = v.form_code
ON CONFLICT (org_id, valid_from) DO UPDATE
SET name_form_id = EXCLUDED.name_form_id,
    note         = EXCLUDED.note;

-- germany: Deutsches Reich / Großdeutsches Reich
INSERT INTO org.org_name (org_name_form_id, language_code, kind_code, valid_from, name)
SELECT f.id, v.lang, 'full', f.valid_from, v.name
FROM org.org_name_form_effective f
JOIN (VALUES
    ('germany', '1871-01-18', 'de', 'Deutsches Reich'),
    ('germany', '1871-01-18', 'en', 'German Reich'),
    ('germany', '1871-01-18', 'ru', 'Германский рейх'),
    ('germany', '1943-06-26', 'de', 'Großdeutsches Reich'),
    ('germany', '1943-06-26', 'en', 'Greater German Reich'),
    ('germany', '1943-06-26', 'ru', 'Великогерманский рейх')
) AS v(org_code, from_d, lang, name)
  ON f.org_code = v.org_code AND f.valid_from = v.from_d::date
ON CONFLICT (org_name_form_id, language_code, kind_code, valid_from) DO UPDATE
SET name = EXCLUDED.name;

-- austria
INSERT INTO org.org_name (org_name_form_id, language_code, kind_code, valid_from, name)
SELECT f.id, v.lang, 'full', f.valid_from, v.name
FROM org.org_name_form_effective f
JOIN (VALUES
    ('austria', '1804-08-11', 'de', 'Kaisertum Österreich'),
    ('austria', '1804-08-11', 'en', 'Austrian Empire'),
    ('austria', '1804-08-11', 'ru', 'Австрийская империя')
) AS v(org_code, from_d, lang, name)
  ON f.org_code = v.org_code AND f.valid_from = v.from_d::date
ON CONFLICT (org_name_form_id, language_code, kind_code, valid_from) DO UPDATE
SET name = EXCLUDED.name;

-- japan
INSERT INTO org.org_name (org_name_form_id, language_code, kind_code, valid_from, name)
SELECT f.id, v.lang, 'full', f.valid_from, v.name
FROM org.org_name_form_effective f
JOIN (VALUES
    ('japan', '1889-11-29', 'ja', '大日本帝国'),
    ('japan', '1889-11-29', 'en', 'Empire of Japan'),
    ('japan', '1889-11-29', 'ru', 'Японская империя'),
    ('japan', '1889-11-29', 'de', 'Kaiserreich Japan'),
    ('japan', '1947-05-03', 'ja', '日本国'),
    ('japan', '1947-05-03', 'en', 'Japan'),
    ('japan', '1947-05-03', 'ru', 'Япония'),
    ('japan', '1947-05-03', 'de', 'Japan')
) AS v(org_code, from_d, lang, name)
  ON f.org_code = v.org_code AND f.valid_from = v.from_d::date
ON CONFLICT (org_name_form_id, language_code, kind_code, valid_from) DO UPDATE
SET name = EXCLUDED.name;

COMMIT;

-- VERIFY:
-- SELECT org_code, name_form_code, to_char(valid_from,'YYYY-MM-DD') vf,
--        to_char(effective_to,'YYYY-MM-DD') et
-- FROM org.org_name_form_effective
-- WHERE org_code IN ('germany','austria','japan')
-- ORDER BY org_code, valid_from;
--
-- SELECT org_code, name_form_code, language_code, kind_code, name,
--        to_char(valid_from,'YYYY-MM-DD') vf, to_char(effective_to,'YYYY-MM-DD') et
-- FROM org.org_name_effective
-- WHERE org_code IN ('germany','austria','japan')
-- ORDER BY org_code, valid_from, language_code;
