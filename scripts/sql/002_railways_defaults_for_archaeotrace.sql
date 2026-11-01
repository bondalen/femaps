-- 002_railways_defaults_for_archaeotrace.sql
-- ArchaeoTrace пишет в PostGIS только geom, без атрибутов.
-- DEFAULT на время пилота Борdeaux (ячейка -1_44); смените перед другой ячейкой.
-- QGIS передаёт явные NULL — для INSERT нужен также 003_railways_insert_trigger.sql.

-- Удалить неудачные черновики (опционально)
DELETE FROM public.railways
WHERE rail_class IS NULL
   OR method IS NULL
   OR method NOT IN ('manual', 'archaeotrace', 'geoosam');

ALTER TABLE public.railways
    ALTER COLUMN rail_class SET DEFAULT 'single',
    ALTER COLUMN cell_id SET DEFAULT '-1_44',
    ALTER COLUMN sheet SET DEFAULT '44-12-01',
    ALTER COLUMN source_date SET DEFAULT DATE '1944-12-01',
    ALTER COLUMN method SET DEFAULT 'archaeotrace';

COMMENT ON COLUMN public.railways.rail_class IS
    'DEFAULT для ArchaeoTrace-пилота; править в DBeaver при смене ячейки';
