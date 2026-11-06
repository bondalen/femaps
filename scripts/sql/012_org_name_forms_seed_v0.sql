-- 012_org_name_forms_seed_v0.sql
-- Seed v0 по docs/org/26-1102_presentation_sketch.md
-- Требует: 010 + 011 (edge без language_code + edge_label).
-- Повторный запуск: ON CONFLICT / идемпотентные INSERT.

BEGIN;

-- ---------------------------------------------------------------------------
-- name_form
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form (code, assignable, note) VALUES
    ('state',       TRUE,  'Корень представления; нейтральная формула'),
    ('empire',      FALSE, 'Полка empire/империя; в de скрыта туннелем; не назначаем суверену в v0'),
    ('kaisertum',   TRUE,  'Офиц. австрийское Kaisertum (не Kaiserreich)'),
    ('reich',       TRUE,  'Офиц. немецкая формула …Reich'),
    ('kaiserreich', TRUE,  'Употребимая de-полка для JP/RU (император); не для AT/DE в v0'),
    ('kingdom',     TRUE,  'Королевство'),
    ('republic',    TRUE,  'Республика')
ON CONFLICT (code) DO UPDATE
SET assignable = EXCLUDED.assignable,
    note       = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- name_form_label (de / en / ru) — только где вершина ветка в UI
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form_label (name_form_id, language_code, label)
SELECT nf.id, v.lang, v.label
FROM org.name_form nf
JOIN (VALUES
    ('state',       'de', 'Staat'),
    ('state',       'en', 'state'),
    ('state',       'ru', 'государство'),
    ('empire',      'en', 'empire'),
    ('empire',      'ru', 'империя'),
    -- empire: без de — не ветка в de
    ('kaisertum',   'de', 'Kaisertum'),
    ('reich',       'de', 'Reich'),
    ('kaiserreich', 'de', 'Kaiserreich'),
    ('kingdom',     'de', 'Königreich'),
    ('kingdom',     'en', 'kingdom'),
    ('kingdom',     'ru', 'королевство'),
    ('republic',    'de', 'Republik'),
    ('republic',    'en', 'republic'),
    ('republic',    'ru', 'республика')
) AS v(code, lang, label) ON nf.code = v.code
ON CONFLICT (name_form_id, language_code) DO UPDATE
SET label = EXCLUDED.label;

-- ---------------------------------------------------------------------------
-- рёбра + метки (канон 1102 §1)
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form_edge (parent_id, child_id, sort_order)
SELECT p.id, c.id, v.sort_order
FROM (VALUES
    ('state',  'empire',      10),
    ('empire', 'reich',       20),
    ('empire', 'kaisertum',   30),
    ('reich',  'kaiserreich', 40),
    ('reich',  'kingdom',     50),
    ('state',  'kingdom',     60),
    ('state',  'republic',    70)
) AS v(parent_code, child_code, sort_order)
JOIN org.name_form p ON p.code = v.parent_code
JOIN org.name_form c ON c.code = v.child_code
ON CONFLICT (parent_id, child_id) DO UPDATE
SET sort_order = EXCLUDED.sort_order;

INSERT INTO org.name_form_edge_label (edge_id, language_code)
SELECT e.id, v.lang
FROM (VALUES
    ('state',  'empire',      'en'),
    ('state',  'empire',      'ru'),
    ('empire', 'reich',       'de'),
    ('empire', 'kaisertum',   'de'),
    ('reich',  'kaiserreich', 'de'),
    ('reich',  'kingdom',     'de'),
    ('state',  'kingdom',     'en'),
    ('state',  'kingdom',     'ru'),
    ('state',  'republic',    'en'),
    ('state',  'republic',    'de'),
    ('state',  'republic',    'ru')
) AS v(parent_code, child_code, lang)
JOIN org.name_form p ON p.code = v.parent_code
JOIN org.name_form c ON c.code = v.child_code
JOIN org.name_form_edge e ON e.parent_id = p.id AND e.child_id = c.id
ON CONFLICT (edge_id, language_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- sovereign
-- ---------------------------------------------------------------------------
INSERT INTO org.sovereign (code, note) VALUES
    ('japan',   'Япония'),
    ('austria', 'Австрия / Habsburg Kaisertum'),
    ('russia',  'Россия'),
    ('germany', 'Германия'),
    ('italy',   'Италия'),
    ('france',  'Франция')
ON CONFLICT (code) DO UPDATE SET note = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- sovereign_name_form (периоды; полное имя в note до таблицы sovereign_name)
-- ---------------------------------------------------------------------------
-- Идемпотентность: удалить периоды этих суверенов и вставить заново
DELETE FROM org.sovereign_name_form sn
USING org.sovereign s
WHERE sn.sovereign_id = s.id
  AND s.code IN ('japan', 'austria', 'russia', 'germany', 'italy', 'france');

INSERT INTO org.sovereign_name_form (
    sovereign_id, name_form_id, valid_from, valid_to, is_primary, note
)
SELECT s.id, nf.id, v.valid_from::date, v.valid_to::date, TRUE, v.note
FROM (VALUES
    ('japan',   'kaiserreich', '1889-11-29', '1947-05-02',
        'Dai-Nippon Teikoku / 大日本帝国'),
    ('japan',   'state',       '1947-05-03', NULL,
        'Nihon-koku / 日本国'),
    ('austria', 'kaisertum',   '1804-08-11', '1867-06-08',
        'Kaisertum Österreich (Kaiserthum Oesterreich)'),
    ('russia',  'kaiserreich', '1721-10-22', '1917-09-14',
        'Российская империя'),
    ('germany', 'reich',       '1871-01-18', '1943-06-25',
        'Deutsches Reich'),
    ('germany', 'reich',       '1943-06-26', '1945-06-04',
        'Großdeutsches Reich'),
    ('italy',   'kingdom',     '1861-03-17', '1946-06-18',
        'Regno d’Italia'),
    ('france',  'republic',    '1870-09-04', NULL,
        'République française (III→…; упрощённый период v0)')
) AS v(sov_code, form_code, valid_from, valid_to, note)
JOIN org.sovereign s ON s.code = v.sov_code
JOIN org.name_form nf ON nf.code = v.form_code;

COMMIT;

-- ---------------------------------------------------------------------------
-- Проверки
-- ---------------------------------------------------------------------------
SELECT code, assignable FROM org.name_form ORDER BY code;

SELECT nf.code, l.language_code, l.label
FROM org.name_form_label l
JOIN org.name_form nf ON nf.id = l.name_form_id
ORDER BY nf.code, l.language_code;

SELECT p.code AS parent, c.code AS child,
       string_agg(el.language_code, ',' ORDER BY el.language_code) AS langs
FROM org.name_form_edge e
JOIN org.name_form p ON p.id = e.parent_id
JOIN org.name_form c ON c.id = e.child_id
LEFT JOIN org.name_form_edge_label el ON el.edge_id = e.id
GROUP BY p.code, c.code, e.sort_order
ORDER BY e.sort_order;

SELECT s.code, nf.code AS name_form, sn.valid_from, sn.valid_to, sn.note
FROM org.sovereign_name_form sn
JOIN org.sovereign s ON s.id = sn.sovereign_id
JOIN org.name_form nf ON nf.id = sn.name_form_id
ORDER BY s.code, sn.valid_from;
