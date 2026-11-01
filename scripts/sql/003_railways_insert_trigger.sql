-- 003_railways_insert_trigger.sql
-- QGIS/ArchaeoTrace в INSERT явно передаёт NULL — column DEFAULT не срабатывает.
-- Триггер подставляет атрибуты пилота Борdeaux (яч. -1_44) при NULL.

CREATE OR REPLACE FUNCTION public.railways_fill_defaults()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.rail_class IS NULL THEN
        NEW.rail_class := 'single';
    END IF;
    IF NEW.cell_id IS NULL THEN
        NEW.cell_id := '-1_44';
    END IF;
    IF NEW.sheet IS NULL THEN
        NEW.sheet := '44-12-01';
    END IF;
    IF NEW.source_date IS NULL THEN
        NEW.source_date := DATE '1944-12-01';
    END IF;
    IF NEW.method IS NULL THEN
        NEW.method := 'archaeotrace';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_railways_fill_defaults ON public.railways;

CREATE TRIGGER trg_railways_fill_defaults
    BEFORE INSERT ON public.railways
    FOR EACH ROW
    EXECUTE FUNCTION public.railways_fill_defaults();

COMMENT ON FUNCTION public.railways_fill_defaults() IS
    'Подстановка атрибутов при INSERT с NULL (QGIS, ArchaeoTrace); пилот -1_44';
