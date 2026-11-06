-- 011_org_name_form_edge_label.sql
-- Миграция org.name_form_edge: language_code на ребре →
--   смысловое ребро (один раз) + org.name_form_edge_label (явность в UI).
-- Канон: docs/org/26-1102_presentation_sketch.md
-- БД: maps_db @ :5434
--
-- Повторный запуск: безопасен (IF EXISTS / IF NOT EXISTS).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Снять модель «язык на ребре» (010)
-- ---------------------------------------------------------------------------
ALTER TABLE org.name_form_edge
    DROP CONSTRAINT IF EXISTS name_form_edge_one_parent_per_lang;

ALTER TABLE org.name_form_edge
    DROP CONSTRAINT IF EXISTS name_form_edge_language_code_fkey;

DROP INDEX IF EXISTS org.idx_name_form_edge_parent_lang;
DROP INDEX IF EXISTS org.idx_name_form_edge_lang;

-- Если на старых рёбрах были данные с language_code — сначала собрать
-- уникальные (parent, child); метки восстановить ниже нельзя без колонки.
-- В maps_db на момент миграции рёбер не было.

ALTER TABLE org.name_form_edge
    DROP COLUMN IF EXISTS language_code;

-- Одно смысловое ребро parent→child
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'name_form_edge_unique_pair'
          AND conrelid = 'org.name_form_edge'::regclass
    ) THEN
        ALTER TABLE org.name_form_edge
            ADD CONSTRAINT name_form_edge_unique_pair UNIQUE (parent_id, child_id);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_name_form_edge_parent
    ON org.name_form_edge (parent_id);

CREATE INDEX IF NOT EXISTS idx_name_form_edge_child
    ON org.name_form_edge (child_id);

COMMENT ON TABLE org.name_form_edge IS
    'Смысловое ребро parent→child основы имени (один раз). Явность в UI — name_form_edge_label.';

-- ---------------------------------------------------------------------------
-- 2. Метки языков на ребре (явный шаг UI)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.name_form_edge_label (
    edge_id       BIGINT NOT NULL REFERENCES org.name_form_edge (id) ON DELETE CASCADE,
    language_code TEXT   NOT NULL REFERENCES org.language (code) ON DELETE CASCADE,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (edge_id, language_code)
);

COMMENT ON TABLE org.name_form_edge_label IS
    'Языки, для которых ребро явное в UI; отсутствие метки L при обходе L = туннель.';

CREATE INDEX IF NOT EXISTS idx_name_form_edge_label_lang
    ON org.name_form_edge_label (language_code);

COMMIT;

-- Проверка
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'org' AND table_name = 'name_form_edge'
ORDER BY ordinal_position;

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'org'
ORDER BY table_name;
