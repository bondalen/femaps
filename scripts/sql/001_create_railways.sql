-- 001_create_railways.sql
-- PostGIS: таблица железных дорог Lage West (все 4 класса в одной таблице)
-- БД: maps_db @ localhost:5434, пользователь maps_user
--
-- Выполнить в DBeaver или psql. Повторный запуск безопасен (IF NOT EXISTS).

CREATE TABLE IF NOT EXISTS public.railways (
    id           SERIAL PRIMARY KEY,
    rail_class   TEXT NOT NULL
                 CHECK (rail_class IN ('fd_express', 'multi', 'single', 'narrow')),
    cell_id      TEXT,          -- ячейка 1°×1°, напр. '-1_44' (Бордо)
    sheet        TEXT,          -- напр. '44-12-01'
    source_date  DATE,          -- напр. '1944-12-01'
    method       TEXT
                 CHECK (method IS NULL OR method IN ('manual', 'archaeotrace', 'geoosam')),
    name         TEXT,
    geom         geometry(LineString, 4326) NOT NULL,
    created_at   TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS sidx_railways_geom
    ON public.railways USING GIST (geom);

CREATE INDEX IF NOT EXISTS idx_railways_class
    ON public.railways (rail_class);

CREATE INDEX IF NOT EXISTS idx_railways_cell
    ON public.railways (cell_id);

COMMENT ON TABLE public.railways IS
    'Железные дороги Lage West; классы: fd_express, multi, single, narrow';
COMMENT ON COLUMN public.railways.rail_class IS
    'fd_express — FD/Express; multi — mehrgleisig; single — eingleisig; narrow — Schmalspur';

-- Проверка (DBeaver: выполнить отдельно; \d — только в psql, не в DBeaver)
SELECT f_table_name, f_geometry_column, type, srid
FROM geometry_columns
WHERE f_table_schema = 'public' AND f_table_name = 'railways';

SELECT column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'railways'
ORDER BY ordinal_position;
