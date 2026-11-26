-- 016_org_ussr_moscow_rel.sql
-- СССР как отдельный id; moscow ⊂ ussr (part_of); даты связи NULL → effective из ЖЦ.
-- Календарь A. После 013–015.
--
-- ussr: frm 1922-12-30, trm 1991-12-26 (0.0.0 — роспуск без правопреемника-Reor).
-- Связь: valid_from/to NULL → eff_from=max(frm), eff_to=ussr.trm.

BEGIN;

INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'ussr',
    'Союз ССР — отдельное лицо (надстройка), не convert ствола moscow/РСФСР/РФ. '
        || 'frm = договор 30.12.1922; trm = 26.12.1991 (роспуск). '
        || 'Членство России: org_rel part_of moscow⊂ussr (даты на ребре NULL).',
    '1.0',
    DATE '1922-12-30',
    '0.0.0',
    DATE '1991-12-26'
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_rel (part_id, whole_id, rel_type, valid_from, valid_to, note)
SELECT p.id, w.id, 'part_of', NULL, NULL,
       'РСФСР/ствол moscow в составе СССР; границы effective из frm/trm лиц (без дубля на ребре).'
FROM org.org p
CROSS JOIN org.org w
WHERE p.code = 'moscow' AND w.code = 'ussr'
ON CONFLICT (part_id, whole_id, rel_type) DO NOTHING;

COMMIT;

-- VERIFY:
-- SELECT code, frm_method, to_char(frm_date,'YYYY-MM-DD') frm,
--        trm_method, to_char(trm_date,'YYYY-MM-DD') trm
-- FROM org.org WHERE code IN ('moscow','ussr');
-- SELECT part_code, whole_code, to_char(eff_from,'YYYY-MM-DD') eff_from,
--        to_char(eff_to,'YYYY-MM-DD') eff_to
-- FROM org.org_rel_effective WHERE whole_code = 'ussr' OR part_code = 'ussr';
