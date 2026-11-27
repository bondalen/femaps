-- 019_name_form_titles_brandenburg.sql
-- Расширение DAG самоназваний (княз./герц./марка/Freistaat) + имена brandenburg.
-- Канон: docs/org/26-1127_name_form_title_tree.md
-- После 010–012, 018. Legacy sovereign_* не трогаем. Идемпотентно.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Новые name_form
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form (code, assignable, note) VALUES
    ('freistaat',              TRUE, 'Свободное государство (самоназвание); сосед republic'),
    ('mark',                   TRUE, 'Марка / маркграфство; не под княжеством'),
    ('principality',           TRUE, 'Княжество / Fürstentum — корень агрегации княжеств'),
    ('electorate',             TRUE, 'Курфюршество; Kurfürst ⊂ Fürst'),
    ('grand_principality',     TRUE, 'Великое княжество / Großfürstentum; ≠ grand_duchy'),
    ('appanage_principality',  TRUE, 'Удельное княжество'),
    ('duchy',                  TRUE, 'Герцогство / Herzogtum — корень агрегации герцогств'),
    ('grand_duchy',            TRUE, 'Великое герцогство / Großherzogtum')
ON CONFLICT (code) DO UPDATE
SET assignable = EXCLUDED.assignable,
    note       = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- 2. Ярлыки de / en / ru
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form_label (name_form_id, language_code, label)
SELECT nf.id, v.lang, v.label
FROM org.name_form nf
JOIN (VALUES
    ('freistaat',             'de', 'Freistaat'),
    ('freistaat',             'en', 'Free State'),
    ('freistaat',             'ru', 'свободное государство'),
    ('mark',                  'de', 'Marke'),
    ('mark',                  'en', 'margraviate'),
    ('mark',                  'ru', 'марка'),
    ('principality',          'de', 'Fürstentum'),
    ('principality',          'en', 'principality'),
    ('principality',          'ru', 'княжество'),
    ('electorate',            'de', 'Kurfürstentum'),
    ('electorate',            'en', 'electorate'),
    ('electorate',            'ru', 'курфюршество'),
    ('grand_principality',    'de', 'Großfürstentum'),
    ('grand_principality',    'en', 'grand principality'),
    ('grand_principality',    'ru', 'великое княжество'),
    ('appanage_principality', 'de', 'Teilfürstentum'),
    ('appanage_principality', 'en', 'appanage principality'),
    ('appanage_principality', 'ru', 'удельное княжество'),
    ('duchy',                 'de', 'Herzogtum'),
    ('duchy',                 'en', 'duchy'),
    ('duchy',                 'ru', 'герцогство'),
    ('grand_duchy',           'de', 'Großherzogtum'),
    ('grand_duchy',           'en', 'grand duchy'),
    ('grand_duchy',           'ru', 'великое герцогство')
) AS v(code, lang, label) ON nf.code = v.code
ON CONFLICT (name_form_id, language_code) DO UPDATE
SET label = EXCLUDED.label;

-- ---------------------------------------------------------------------------
-- 3. Рёбра + метки языков (все de/en/ru явны на старте)
-- ---------------------------------------------------------------------------
INSERT INTO org.name_form_edge (parent_id, child_id, sort_order)
SELECT p.id, c.id, v.sort_order
FROM (VALUES
    ('state',        'freistaat',             80),
    ('state',        'mark',                  90),
    ('state',        'principality',         100),
    ('principality', 'electorate',           110),
    ('principality', 'grand_principality',   120),
    ('principality', 'appanage_principality',130),
    ('state',        'duchy',                140),
    ('duchy',        'grand_duchy',          150)
) AS v(parent_code, child_code, sort_order)
JOIN org.name_form p ON p.code = v.parent_code
JOIN org.name_form c ON c.code = v.child_code
ON CONFLICT (parent_id, child_id) DO UPDATE
SET sort_order = EXCLUDED.sort_order;

INSERT INTO org.name_form_edge_label (edge_id, language_code)
SELECT e.id, v.lang
FROM (VALUES
    ('state',        'freistaat',              'de'),
    ('state',        'freistaat',              'en'),
    ('state',        'freistaat',              'ru'),
    ('state',        'mark',                   'de'),
    ('state',        'mark',                   'en'),
    ('state',        'mark',                   'ru'),
    ('state',        'principality',           'de'),
    ('state',        'principality',           'en'),
    ('state',        'principality',           'ru'),
    ('principality', 'electorate',             'de'),
    ('principality', 'electorate',             'en'),
    ('principality', 'electorate',             'ru'),
    ('principality', 'grand_principality',     'de'),
    ('principality', 'grand_principality',     'en'),
    ('principality', 'grand_principality',     'ru'),
    ('principality', 'appanage_principality',  'de'),
    ('principality', 'appanage_principality',  'en'),
    ('principality', 'appanage_principality',  'ru'),
    ('state',        'duchy',                  'de'),
    ('state',        'duchy',                  'en'),
    ('state',        'duchy',                  'ru'),
    ('duchy',        'grand_duchy',            'de'),
    ('duchy',        'grand_duchy',            'en'),
    ('duchy',        'grand_duchy',            'ru')
) AS v(parent_code, child_code, lang)
JOIN org.name_form p ON p.code = v.parent_code
JOIN org.name_form c ON c.code = v.child_code
JOIN org.name_form_edge e ON e.parent_id = p.id AND e.child_id = c.id
ON CONFLICT (edge_id, language_code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 4. Периоды формулы brandenburg
-- ---------------------------------------------------------------------------
INSERT INTO org.org_name_form (org_id, name_form_id, valid_from, note)
SELECT o.id, nf.id, v.valid_from::date, v.note
FROM (VALUES
    ('brandenburg', 'mark',       '0965-05-20', 'Nordmark; frm org'),
    ('brandenburg', 'mark',       '1157-06-11', 'Mark Brandenburg (ребрендинг)'),
    ('brandenburg', 'electorate', '1356-01-10', 'Kurfürstentum; Золотая булла'),
    ('brandenburg', 'kingdom',    '1701-01-18', 'Königreich Preußen (бренд; тот же org)'),
    ('brandenburg', 'freistaat',  '1918-11-09', 'Freistaat Preußen → trm 1947-02-25')
) AS v(org_code, form_code, valid_from, note)
JOIN org.org o ON o.code = v.org_code
JOIN org.name_form nf ON nf.code = v.form_code
ON CONFLICT (org_id, valid_from) DO UPDATE
SET name_form_id = EXCLUDED.name_form_id,
    note         = EXCLUDED.note;

-- ---------------------------------------------------------------------------
-- 5. Полные имена (de / en / ru)
-- ---------------------------------------------------------------------------
INSERT INTO org.org_name (org_name_form_id, language_code, kind_code, valid_from, name)
SELECT f.id, v.lang, 'full', f.valid_from, v.name
FROM org.org_name_form_effective f
JOIN (VALUES
    ('brandenburg', '0965-05-20', 'de', 'Nordmark'),
    ('brandenburg', '0965-05-20', 'en', 'Northern March'),
    ('brandenburg', '0965-05-20', 'ru', 'Северная марка'),
    ('brandenburg', '1157-06-11', 'de', 'Mark Brandenburg'),
    ('brandenburg', '1157-06-11', 'en', 'Margraviate of Brandenburg'),
    ('brandenburg', '1157-06-11', 'ru', 'Марка Бранденбург'),
    ('brandenburg', '1356-01-10', 'de', 'Kurfürstentum Brandenburg'),
    ('brandenburg', '1356-01-10', 'en', 'Electorate of Brandenburg'),
    ('brandenburg', '1356-01-10', 'ru', 'Курфюршество Бранденбург'),
    ('brandenburg', '1701-01-18', 'de', 'Königreich Preußen'),
    ('brandenburg', '1701-01-18', 'en', 'Kingdom of Prussia'),
    ('brandenburg', '1701-01-18', 'ru', 'Королевство Пруссия'),
    ('brandenburg', '1918-11-09', 'de', 'Freistaat Preußen'),
    ('brandenburg', '1918-11-09', 'en', 'Free State of Prussia'),
    ('brandenburg', '1918-11-09', 'ru', 'Свободное государство Пруссия')
) AS v(org_code, from_d, lang, name)
  ON f.org_code = v.org_code AND f.valid_from = v.from_d::date
ON CONFLICT (org_name_form_id, language_code, kind_code, valid_from) DO UPDATE
SET name = EXCLUDED.name;

-- short (опционально): бренд после 1701
INSERT INTO org.org_name (org_name_form_id, language_code, kind_code, valid_from, name)
SELECT f.id, v.lang, 'short', f.valid_from, v.name
FROM org.org_name_form_effective f
JOIN (VALUES
    ('brandenburg', '1157-06-11', 'de', 'Brandenburg'),
    ('brandenburg', '1157-06-11', 'en', 'Brandenburg'),
    ('brandenburg', '1157-06-11', 'ru', 'Бранденбург'),
    ('brandenburg', '1356-01-10', 'de', 'Brandenburg'),
    ('brandenburg', '1356-01-10', 'en', 'Brandenburg'),
    ('brandenburg', '1356-01-10', 'ru', 'Бранденбург'),
    ('brandenburg', '1701-01-18', 'de', 'Preußen'),
    ('brandenburg', '1701-01-18', 'en', 'Prussia'),
    ('brandenburg', '1701-01-18', 'ru', 'Пруссия'),
    ('brandenburg', '1918-11-09', 'de', 'Preußen'),
    ('brandenburg', '1918-11-09', 'en', 'Prussia'),
    ('brandenburg', '1918-11-09', 'ru', 'Пруссия')
) AS v(org_code, from_d, lang, name)
  ON f.org_code = v.org_code AND f.valid_from = v.from_d::date
ON CONFLICT (org_name_form_id, language_code, kind_code, valid_from) DO UPDATE
SET name = EXCLUDED.name;

COMMIT;

-- VERIFY:
-- SELECT code FROM org.name_form
-- WHERE code IN ('freistaat','mark','principality','electorate','duchy','grand_duchy')
-- ORDER BY 1;
--
-- SELECT p.code parent, c.code child,
--        string_agg(el.language_code, ',' ORDER BY el.language_code) langs
-- FROM org.name_form_edge e
-- JOIN org.name_form p ON p.id=e.parent_id JOIN org.name_form c ON c.id=e.child_id
-- LEFT JOIN org.name_form_edge_label el ON el.edge_id=e.id
-- WHERE c.code IN ('freistaat','mark','principality','electorate','grand_principality',
--                  'appanage_principality','duchy','grand_duchy')
-- GROUP BY 1,2 ORDER BY 1,2;
--
-- SELECT name_form_code, to_char(valid_from,'YYYY-MM-DD') vf,
--        to_char(effective_to,'YYYY-MM-DD') et
-- FROM org.org_name_form_effective WHERE org_code='brandenburg' ORDER BY valid_from;
