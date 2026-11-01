-- 010_org_name_forms.sql
-- Schema org: основы официальных имён государств (абстрактные вершины +
-- языковые деревья рёбер; union рёбер = DAG). Без геометрии.
-- БД: maps_db @ localhost:5434, пользователь maps_user
--
-- Повторный запуск: безопасен для schema/таблиц (IF NOT EXISTS);
-- seed языков — ON CONFLICT DO NOTHING.

CREATE SCHEMA IF NOT EXISTS org;

COMMENT ON SCHEMA org IS
    'Учёт суверенов и основ наименований; позже — структуры ВС/коалиций. Без гео.';

-- ---------------------------------------------------------------------------
-- Языки
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.language (
    code        TEXT PRIMARY KEY,           -- ISO 639-1, напр. en, de, ru
    name_en     TEXT NOT NULL,
    name_native TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE org.language IS 'Языки ярлыков и языковых деревьев name_form';

-- ---------------------------------------------------------------------------
-- Абстрактные основы имени (вершины; без единого безъязыкового дерева)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.name_form (
    id          BIGSERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,       -- state, reich, empire, kingdom…
    assignable  BOOLEAN NOT NULL DEFAULT TRUE,
        -- FALSE: только группировка в каком-то языке (если понадобится)
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE org.name_form IS
    'Абстрактная основа официального имени (не государство). Иерархия — только через name_form_edge + language';
COMMENT ON COLUMN org.name_form.assignable IS
    'TRUE — можно назначать суверену в sovereign_name_form';

-- ---------------------------------------------------------------------------
-- Ярлыки вершины по языкам
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.name_form_label (
    name_form_id BIGINT NOT NULL REFERENCES org.name_form (id) ON DELETE CASCADE,
    language_code TEXT NOT NULL REFERENCES org.language (code) ON DELETE CASCADE,
    label         TEXT NOT NULL,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (name_form_id, language_code)
);

COMMENT ON TABLE org.name_form_label IS 'Подпись name_form в языке (Staat, empire, рейх…)';

CREATE INDEX IF NOT EXISTS idx_name_form_label_lang
    ON org.name_form_label (language_code);

-- ---------------------------------------------------------------------------
-- Рёбра иерархии в контексте языка (в языке — дерево; union — DAG)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.name_form_edge (
    id            BIGSERIAL PRIMARY KEY,
    parent_id     BIGINT NOT NULL REFERENCES org.name_form (id) ON DELETE CASCADE,
    child_id      BIGINT NOT NULL REFERENCES org.name_form (id) ON DELETE CASCADE,
    language_code TEXT NOT NULL REFERENCES org.language (code) ON DELETE CASCADE,
    sort_order    INT NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT name_form_edge_no_self CHECK (parent_id <> child_id),
    CONSTRAINT name_form_edge_one_parent_per_lang UNIQUE (child_id, language_code)
);

COMMENT ON TABLE org.name_form_edge IS
    'Родитель→потомок основы имени в одном языке. UNIQUE(child, language) → дерево на язык; разные языки → DAG на union';

CREATE INDEX IF NOT EXISTS idx_name_form_edge_parent_lang
    ON org.name_form_edge (language_code, parent_id);

CREATE INDEX IF NOT EXISTS idx_name_form_edge_lang
    ON org.name_form_edge (language_code);

-- ---------------------------------------------------------------------------
-- Государства (суверены) — экземпляры, не типы имени
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.sovereign (
    id          BIGSERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,       -- japan, germany, france…
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

COMMENT ON TABLE org.sovereign IS
    'Суверен / государство как сущность учёта (стабильный узел; смена формулы имени — в sovereign_name_form)';

-- ---------------------------------------------------------------------------
-- Государство ↔ основа имени (по времени)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.sovereign_name_form (
    id            BIGSERIAL PRIMARY KEY,
    sovereign_id  BIGINT NOT NULL REFERENCES org.sovereign (id) ON DELETE CASCADE,
    name_form_id  BIGINT NOT NULL REFERENCES org.name_form (id) ON DELETE RESTRICT,
    valid_from    DATE NOT NULL,
    valid_to      DATE,                     -- NULL = открытый интервал
    is_primary    BOOLEAN NOT NULL DEFAULT TRUE,
    note          TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT sovereign_name_form_interval CHECK (
        valid_to IS NULL OR valid_to >= valid_from
    )
);

COMMENT ON TABLE org.sovereign_name_form IS
    'Какая основа имени (name_form) действовала у суверена на интервале дат';
COMMENT ON COLUMN org.sovereign_name_form.is_primary IS
    'Основная формула на интервале (запас под параллельные/спорные ярлыки)';

CREATE INDEX IF NOT EXISTS idx_sovereign_name_form_sov
    ON org.sovereign_name_form (sovereign_id);

CREATE INDEX IF NOT EXISTS idx_sovereign_name_form_dates
    ON org.sovereign_name_form (valid_from, valid_to);

CREATE INDEX IF NOT EXISTS idx_sovereign_name_form_form
    ON org.sovereign_name_form (name_form_id);

-- Нельзя назначить не-assignable форму как primary (мягкая защита)
CREATE OR REPLACE FUNCTION org.trg_sovereign_name_form_assignable()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.is_primary AND EXISTS (
        SELECT 1 FROM org.name_form nf
        WHERE nf.id = NEW.name_form_id AND nf.assignable IS FALSE
    ) THEN
        RAISE EXCEPTION
            'name_form id=% is not assignable; cannot set as primary sovereign_name_form',
            NEW.name_form_id;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sovereign_name_form_assignable
    ON org.sovereign_name_form;
CREATE TRIGGER trg_sovereign_name_form_assignable
    BEFORE INSERT OR UPDATE OF name_form_id, is_primary
    ON org.sovereign_name_form
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_sovereign_name_form_assignable();

-- ---------------------------------------------------------------------------
-- Минимальный seed языков (инфраструктура ярлыков)
-- ---------------------------------------------------------------------------
INSERT INTO org.language (code, name_en, name_native) VALUES
    ('de', 'German',    'Deutsch'),
    ('en', 'English',   'English'),
    ('ru', 'Russian',   'Русский'),
    ('fr', 'French',    'Français'),
    ('ja', 'Japanese',  '日本語')
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Проверки
-- ---------------------------------------------------------------------------
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'org'
ORDER BY table_name;

SELECT code, name_en FROM org.language ORDER BY code;
