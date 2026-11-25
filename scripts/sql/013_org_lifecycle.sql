-- 013_org_lifecycle.sql
-- Итерация 0: лицо org + frm/trm + org_reor_* + двусторонняя целостность (вариант A).
-- Канон: docs/org/26-1124_org_lifecycle_er.md §4–§6
-- БД: maps_db, schema org. Legacy org.sovereign не трогаем.
--
-- Целостность:
--   1) UNIQUE (id, frm_method|trm_method) + составные FK ребро→лицо + DEFAULT method;
--   2) CONSTRAINT TRIGGER DEFERRABLE INITIALLY DEFERRED: method на лице ↔ наличие ребра.
-- Повторный запуск: не полностью идемпотентен (CREATE TABLE IF NOT EXISTS;
--   функции/триггеры — CREATE OR REPLACE / DROP IF EXISTS).

BEGIN;

CREATE SCHEMA IF NOT EXISTS org;

-- ---------------------------------------------------------------------------
-- Справочники
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_frm_method (
    code  TEXT PRIMARY KEY,
    name  TEXT NOT NULL,
    note  TEXT
);

CREATE TABLE IF NOT EXISTS org.org_trm_method (
    code  TEXT PRIMARY KEY,
    name  TEXT NOT NULL,
    note  TEXT
);

COMMENT ON TABLE org.org_frm_method IS 'Способ создания org (коды по аналогии с ФНС / rgTaxLgEntFrmMtd)';
COMMENT ON TABLE org.org_trm_method IS 'Способ прекращения org (коды по аналогии с rgTaxLgEntTrmMtd)';

INSERT INTO org.org_frm_method (code, name, note) VALUES
    ('1.0', 'Создание с нуля', NULL),
    ('2.1', 'Создание путём преобразования', 'у нас convert = same id; код зарезервирован, ребра Trans нет'),
    ('2.2', 'Создание путём слияния', NULL),
    ('2.3', 'Создание путём разделения', NULL),
    ('2.4', 'Создание путём выделения', NULL),
    ('2.6', 'Создание: разделение + присоединение (промежуточный)', NULL),
    ('2.7', 'Создание: выделение + присоединение (промежуточный)', NULL),
    ('2.8', 'Создание: разделение + слияние (промежуточный)', NULL),
    ('2.9', 'Создание: выделение + слияние (промежуточный)', NULL)
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_trm_method (code, name, note) VALUES
    ('0.0.0', 'Ликвидация без правопреемника', NULL),
    ('2.1.0', 'Прекращение путём преобразования', 'у нас convert = same id; ребра Trans нет'),
    ('2.2.0', 'Прекращение путём слияния', NULL),
    ('2.3.0', 'Прекращение путём разделения', NULL),
    ('2.5.0', 'Прекращение путём присоединения', NULL),
    ('2.6.1', 'Разделение + прекращение промежуточного присоединением', NULL),
    ('2.6.2', 'Прекращение промежуточного, созданного разделением+присоединением', NULL),
    ('2.7.0', 'Прекращение промежуточного (выделение+присоединение)', NULL),
    ('2.8.1', 'Разделение + прекращение промежуточного слиянием', NULL),
    ('2.8.2', 'Прекращение промежуточного, созданного разделением+слиянием', NULL),
    ('2.9.0', 'Прекращение промежуточного (выделение+слияние)', NULL)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- Лицо
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org (
    id          BIGSERIAL PRIMARY KEY,
    code        TEXT NOT NULL UNIQUE,
    note        TEXT,
    frm_method  TEXT NOT NULL REFERENCES org.org_frm_method (code),
    frm_date    DATE NOT NULL,
    trm_method  TEXT REFERENCES org.org_trm_method (code),
    trm_date    DATE,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT org_trm_pair_chk CHECK (
        (trm_method IS NULL AND trm_date IS NULL)
        OR (trm_method IS NOT NULL AND trm_date IS NOT NULL)
    )
);

COMMENT ON TABLE org.org IS
    'Организация учёта (государство, позже соединения и др.). ЖЦ: frm/trm + org_reor_*.';

CREATE UNIQUE INDEX IF NOT EXISTS ux_org_id_frm
    ON org.org (id, frm_method);
CREATE UNIQUE INDEX IF NOT EXISTS ux_org_id_trm
    ON org.org (id, trm_method);

-- ---------------------------------------------------------------------------
-- Базовые Reor*
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_reor_acqui (
    acquired_id   BIGINT NOT NULL,
    acquired_trm  TEXT NOT NULL DEFAULT '2.5.0',
    acquiring_id  BIGINT NOT NULL REFERENCES org.org (id),
    PRIMARY KEY (acquired_id),
    CONSTRAINT org_reor_acqui_acquired_fk
        FOREIGN KEY (acquired_id, acquired_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_acqui_trm_chk CHECK (acquired_trm = '2.5.0'),
    CONSTRAINT org_reor_acqui_neq CHECK (acquired_id <> acquiring_id)
);

CREATE TABLE IF NOT EXISTS org.org_reor_merge (
    mergerable_id  BIGINT NOT NULL,
    mergerable_trm TEXT NOT NULL DEFAULT '2.2.0',
    merged_id      BIGINT NOT NULL,
    PRIMARY KEY (mergerable_id),
    CONSTRAINT org_reor_merge_src_fk
        FOREIGN KEY (mergerable_id, mergerable_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_merge_dst_fk
        FOREIGN KEY (merged_id)
        REFERENCES org.org (id),
    CONSTRAINT org_reor_merge_trm_chk CHECK (mergerable_trm = '2.2.0'),
    CONSTRAINT org_reor_merge_neq CHECK (mergerable_id <> merged_id)
);

CREATE TABLE IF NOT EXISTS org.org_reor_divis (
    divisible_id  BIGINT NOT NULL,
    divisible_trm TEXT NOT NULL DEFAULT '2.3.0',
    divided_id    BIGINT NOT NULL,
    divided_frm   TEXT NOT NULL DEFAULT '2.3',
    PRIMARY KEY (divisible_id, divided_id),
    CONSTRAINT org_reor_divis_old_fk
        FOREIGN KEY (divisible_id, divisible_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_divis_new_fk
        FOREIGN KEY (divided_id, divided_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_divis_codes_chk CHECK (
        divisible_trm = '2.3.0' AND divided_frm = '2.3'
    ),
    CONSTRAINT org_reor_divis_neq CHECK (divisible_id <> divided_id)
);

CREATE TABLE IF NOT EXISTS org.org_reor_separ (
    separable_id  BIGINT NOT NULL REFERENCES org.org (id),
    separated_id  BIGINT NOT NULL,
    separated_frm TEXT NOT NULL DEFAULT '2.4',
    PRIMARY KEY (separable_id, separated_id),
    CONSTRAINT org_reor_separ_new_fk
        FOREIGN KEY (separated_id, separated_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_separ_frm_chk CHECK (separated_frm = '2.4'),
    CONSTRAINT org_reor_separ_neq CHECK (separable_id <> separated_id)
);

-- ---------------------------------------------------------------------------
-- Сочетания (пустой каркас)
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS org.org_reor_divis_acqu (
    divisible_id      BIGINT NOT NULL,
    divisible_trm     TEXT NOT NULL DEFAULT '2.6.1',
    divided_acqu_id   BIGINT NOT NULL,
    divided_acqu_frm  TEXT NOT NULL DEFAULT '2.6',
    divided_acqu_trm  TEXT NOT NULL DEFAULT '2.6.2',
    acquiring_id      BIGINT NOT NULL REFERENCES org.org (id),
    PRIMARY KEY (divisible_id, divided_acqu_id),
    CONSTRAINT org_reor_divis_acqu_div_fk
        FOREIGN KEY (divisible_id, divisible_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_divis_acqu_mid_frm_fk
        FOREIGN KEY (divided_acqu_id, divided_acqu_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_divis_acqu_mid_trm_fk
        FOREIGN KEY (divided_acqu_id, divided_acqu_trm)
        REFERENCES org.org (id, trm_method)
);

CREATE TABLE IF NOT EXISTS org.org_reor_separ_acqu (
    separable_id       BIGINT NOT NULL REFERENCES org.org (id),
    separated_acqu_id  BIGINT NOT NULL,
    separated_acqu_frm TEXT NOT NULL DEFAULT '2.7',
    separated_acqu_trm TEXT NOT NULL DEFAULT '2.7.0',
    acquiring_id       BIGINT NOT NULL REFERENCES org.org (id),
    PRIMARY KEY (separable_id, separated_acqu_id),
    CONSTRAINT org_reor_separ_acqu_mid_frm_fk
        FOREIGN KEY (separated_acqu_id, separated_acqu_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_separ_acqu_mid_trm_fk
        FOREIGN KEY (separated_acqu_id, separated_acqu_trm)
        REFERENCES org.org (id, trm_method)
);

CREATE TABLE IF NOT EXISTS org.org_reor_divis_merg (
    divisible_id     BIGINT NOT NULL,
    divisible_trm    TEXT NOT NULL DEFAULT '2.8.1',
    divided_merg_id  BIGINT NOT NULL,
    divided_merg_frm TEXT NOT NULL DEFAULT '2.8',
    divided_merg_trm TEXT NOT NULL DEFAULT '2.8.2',
    merged_id        BIGINT NOT NULL,
    merged_frm       TEXT NOT NULL DEFAULT '2.2',
    PRIMARY KEY (divisible_id, divided_merg_id),
    CONSTRAINT org_reor_divis_merg_div_fk
        FOREIGN KEY (divisible_id, divisible_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_divis_merg_mid_frm_fk
        FOREIGN KEY (divided_merg_id, divided_merg_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_divis_merg_mid_trm_fk
        FOREIGN KEY (divided_merg_id, divided_merg_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_divis_merg_dst_fk
        FOREIGN KEY (merged_id, merged_frm)
        REFERENCES org.org (id, frm_method)
);

CREATE TABLE IF NOT EXISTS org.org_reor_separ_merg (
    separable_id      BIGINT NOT NULL REFERENCES org.org (id),
    separated_merg_id BIGINT NOT NULL,
    separated_merg_frm TEXT NOT NULL DEFAULT '2.9',
    separated_merg_trm TEXT NOT NULL DEFAULT '2.9.0',
    merged_id         BIGINT NOT NULL,
    merged_frm        TEXT NOT NULL DEFAULT '2.2',
    PRIMARY KEY (separable_id, separated_merg_id),
    CONSTRAINT org_reor_separ_merg_mid_frm_fk
        FOREIGN KEY (separated_merg_id, separated_merg_frm)
        REFERENCES org.org (id, frm_method),
    CONSTRAINT org_reor_separ_merg_mid_trm_fk
        FOREIGN KEY (separated_merg_id, separated_merg_trm)
        REFERENCES org.org (id, trm_method),
    CONSTRAINT org_reor_separ_merg_dst_fk
        FOREIGN KEY (merged_id, merged_frm)
        REFERENCES org.org (id, frm_method)
);

-- ---------------------------------------------------------------------------
-- Двусторонняя целостность: лицо → ребро (deferred)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION org.assert_org_reor_consistency(p_id BIGINT)
RETURNS void
LANGUAGE plpgsql
AS $$
DECLARE
    v_frm TEXT;
    v_trm TEXT;
BEGIN
    SELECT frm_method, trm_method INTO v_frm, v_trm
    FROM org.org WHERE id = p_id;
    IF NOT FOUND THEN
        RETURN;
    END IF;

    IF v_frm = '2.2' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_merge WHERE merged_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.2 requires org_reor_merge as merged', p_id;
    END IF;
    IF v_frm = '2.3' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis WHERE divided_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.3 requires org_reor_divis as divided', p_id;
    END IF;
    IF v_frm = '2.4' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_separ WHERE separated_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.4 requires org_reor_separ as separated', p_id;
    END IF;
    IF v_frm = '2.6' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_acqu WHERE divided_acqu_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.6 requires org_reor_divis_acqu as divided_acqu', p_id;
    END IF;
    IF v_frm = '2.7' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_separ_acqu WHERE separated_acqu_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.7 requires org_reor_separ_acqu as separated_acqu', p_id;
    END IF;
    IF v_frm = '2.8' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_merg WHERE divided_merg_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.8 requires org_reor_divis_merg as divided_merg', p_id;
    END IF;
    IF v_frm = '2.9' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_separ_merg WHERE separated_merg_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% frm_method=2.9 requires org_reor_separ_merg as separated_merg', p_id;
    END IF;

    IF v_trm = '2.2.0' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_merge WHERE mergerable_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.2.0 requires org_reor_merge as mergerable', p_id;
    END IF;
    IF v_trm = '2.3.0' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis WHERE divisible_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.3.0 requires org_reor_divis as divisible', p_id;
    END IF;
    IF v_trm = '2.5.0' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_acqui WHERE acquired_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.5.0 requires org_reor_acqui as acquired', p_id;
    END IF;
    IF v_trm = '2.6.1' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_acqu WHERE divisible_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.6.1 requires org_reor_divis_acqu as divisible', p_id;
    END IF;
    IF v_trm = '2.6.2' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_acqu WHERE divided_acqu_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.6.2 requires org_reor_divis_acqu as divided_acqu', p_id;
    END IF;
    IF v_trm = '2.7.0' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_separ_acqu WHERE separated_acqu_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.7.0 requires org_reor_separ_acqu as separated_acqu', p_id;
    END IF;
    IF v_trm = '2.8.1' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_merg WHERE divisible_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.8.1 requires org_reor_divis_merg as divisible', p_id;
    END IF;
    IF v_trm = '2.8.2' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_divis_merg WHERE divided_merg_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.8.2 requires org_reor_divis_merg as divided_merg', p_id;
    END IF;
    IF v_trm = '2.9.0' AND NOT EXISTS (
        SELECT 1 FROM org.org_reor_separ_merg WHERE separated_merg_id = p_id
    ) THEN
        RAISE EXCEPTION 'org.id=% trm_method=2.9.0 requires org_reor_separ_merg as separated_merg', p_id;
    END IF;

    -- Ребро ⇒ ожидаемый method на роли без составного FK в источнике
    IF EXISTS (SELECT 1 FROM org.org_reor_merge WHERE merged_id = p_id)
       AND v_frm IS DISTINCT FROM '2.2' THEN
        RAISE EXCEPTION 'org.id=% is merged but frm_method is %, expected 2.2', p_id, v_frm;
    END IF;
END;
$$;

CREATE OR REPLACE FUNCTION org.trg_assert_org_row()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
    PERFORM org.assert_org_reor_consistency(NEW.id);
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION org.trg_assert_reor_touch()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
    ids BIGINT[] := ARRAY[]::BIGINT[];
BEGIN
    -- Только колонки текущей таблицы (иначе ERROR на NEW/OLD).
    IF TG_TABLE_NAME = 'org_reor_acqui' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.acquired_id, NEW.acquiring_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.acquired_id, OLD.acquiring_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_merge' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.mergerable_id, NEW.merged_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.mergerable_id, OLD.merged_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_divis' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.divisible_id, NEW.divided_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.divisible_id, OLD.divided_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_separ' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.separable_id, NEW.separated_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.separable_id, OLD.separated_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_divis_acqu' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.divisible_id, NEW.divided_acqu_id, NEW.acquiring_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.divisible_id, OLD.divided_acqu_id, OLD.acquiring_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_separ_acqu' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.separable_id, NEW.separated_acqu_id, NEW.acquiring_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.separable_id, OLD.separated_acqu_id, OLD.acquiring_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_divis_merg' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.divisible_id, NEW.divided_merg_id, NEW.merged_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.divisible_id, OLD.divided_merg_id, OLD.merged_id];
        END IF;
    ELSIF TG_TABLE_NAME = 'org_reor_separ_merg' THEN
        IF TG_OP <> 'DELETE' THEN
            ids := ids || ARRAY[NEW.separable_id, NEW.separated_merg_id, NEW.merged_id];
        END IF;
        IF TG_OP <> 'INSERT' THEN
            ids := ids || ARRAY[OLD.separable_id, OLD.separated_merg_id, OLD.merged_id];
        END IF;
    END IF;

    ids := ARRAY(SELECT DISTINCT x FROM unnest(ids) AS x WHERE x IS NOT NULL);
    PERFORM org.assert_org_reor_consistency(x) FROM unnest(ids) AS x;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS ct_org_reor_sync ON org.org;
CREATE CONSTRAINT TRIGGER ct_org_reor_sync
    AFTER INSERT OR UPDATE OF frm_method, trm_method ON org.org
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_org_row();

DROP TRIGGER IF EXISTS ct_reor_acqui_sync ON org.org_reor_acqui;
CREATE CONSTRAINT TRIGGER ct_reor_acqui_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_acqui
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_merge_sync ON org.org_reor_merge;
CREATE CONSTRAINT TRIGGER ct_reor_merge_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_merge
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_divis_sync ON org.org_reor_divis;
CREATE CONSTRAINT TRIGGER ct_reor_divis_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_divis
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_separ_sync ON org.org_reor_separ;
CREATE CONSTRAINT TRIGGER ct_reor_separ_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_separ
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_divis_acqu_sync ON org.org_reor_divis_acqu;
CREATE CONSTRAINT TRIGGER ct_reor_divis_acqu_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_divis_acqu
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_separ_acqu_sync ON org.org_reor_separ_acqu;
CREATE CONSTRAINT TRIGGER ct_reor_separ_acqu_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_separ_acqu
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_divis_merg_sync ON org.org_reor_divis_merg;
CREATE CONSTRAINT TRIGGER ct_reor_divis_merg_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_divis_merg
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

DROP TRIGGER IF EXISTS ct_reor_separ_merg_sync ON org.org_reor_separ_merg;
CREATE CONSTRAINT TRIGGER ct_reor_separ_merg_sync
    AFTER INSERT OR UPDATE OR DELETE ON org.org_reor_separ_merg
    DEFERRABLE INITIALLY DEFERRED
    FOR EACH ROW
    EXECUTE FUNCTION org.trg_assert_reor_touch();

-- ---------------------------------------------------------------------------
-- Seed: Германия + Австрия + присоединение 1938-03-13
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES
    ('germany', 'Германия (рабочий id линии DE)', '1.0', DATE '1871-01-18', NULL, NULL),
    ('austria', 'Австрия; прекращение присоединением к Германии', '1.0', DATE '1918-11-12', '2.5.0', DATE '1938-03-13')
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_reor_acqui (acquired_id, acquiring_id)
SELECT a.id, g.id
FROM org.org a
CROSS JOIN org.org g
WHERE a.code = 'austria' AND g.code = 'germany'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_acqui x WHERE x.acquired_id = a.id
  );

-- ---------------------------------------------------------------------------
-- Seed: Япония — один id; учётный frm = легендарное основание (не научная дата).
-- Мэйдзи / 1947 — тот же id (convert / смена облика); Reor не нужен.
-- Периоды name_form (Teikoku→state) — соседний контур, не этот INSERT.
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'japan',
    'Япония; учётный frm = легендарное основание (Дзимму / National Foundation Day). '
        || 'Не научная дата. Мэйдзи и 1947 — тот же id (convert / смена облика), не новый frm.',
    '1.0',
    DATE '0660-02-11 BC',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

COMMIT;

-- VERIFY (ручной контроль после apply):
-- SELECT o.code, o.frm_method, o.trm_method, to_char(o.frm_date,'DD.MM.YYYY BC') AS frm,
--        to_char(o.trm_date,'YYYY-MM-DD') AS trm,
--        g.code AS acquiring_code
-- FROM org.org o
-- LEFT JOIN org.org_reor_acqui r ON r.acquired_id = o.id
-- LEFT JOIN org.org g ON g.id = r.acquiring_id
-- WHERE o.code IN ('austria','germany','japan');
