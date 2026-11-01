-- 004_fix_archaeotrace_crs.sql
-- ArchaeoTrace сохранял координаты в CRS карты (EPSG:3857), а в geom указан 4326.
-- Признак: |X| > 180 или |Y| > 90 (метры Web Mercator записаны как градусы).

UPDATE public.railways
SET geom = ST_Transform(ST_SetSRID(geom, 3857), 4326)
WHERE ABS(ST_X(ST_StartPoint(geom))) > 180
   OR ABS(ST_Y(ST_StartPoint(geom))) > 90;
