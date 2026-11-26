-- 017_org_brandenburg_line.sql
-- Прецеденты: Саксонская Восточная марка → Бранденбург/Пруссия; Герцогство Пруссия;
-- part_of Кенигсберг⊂Бранденбург; DivisAcqu севера ВП → СССР (Польша позже).
-- Источник: docs/26-1126_google_org_chat.md
-- Календарь A (григориан пролептический). После 013–016. Идемпотентность: ON CONFLICT / NOT EXISTS.
--
-- Решения (2026-11-26):
--   code ствола = brandenburg; part_of с 1701-01-18; конец герцогства = DivisAcqu→ussr 1945-08-02;
--   saxon_east.frm = 0929-07-01 (Legatio Зигфрида, середина самого раннего года).

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. saxon_east — Legatio/Marca Geronis → Лаузиц → Нижняя Лужица
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'saxon_east',
    'Саксонская Восточная марка (Marca Geronis) → Марка Лаузиц / Нижняя Лужица. '
        || 'Учётный frm = 01.07.0929 (середина ~929 — Legatio Зигфрида, Мерзебург; тот же аппарат). '
        || '937 Геро, 965 Separ Северной марки (мать жива), 1367 Богемия, 1635 Саксония — convert/part_of, не новый id. '
        || 'trm Absorb→brandenburg 30.04.1816 (роспуск Oberamtsregierung в Люббене). '
        || 'Источник: docs/26-1126_google_org_chat.md',
    '1.0',
    DATE '0929-07-01',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. brandenburg — Nordmark → Brandenburg → Kingdom/Freistaat Preußen
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'brandenburg',
    'Северная марка → Марка/Курфюршество Бранденбург → Королевство/Freistaat Пруссия (берлинское ядро). '
        || 'frm=2.4 Separ из saxon_east 20.05.0965. 1157/1356/1701/1918 — convert (тот же id); бренд «Пруссия» с 1701. '
        || 'trm 0.0.0 25.02.1947 (Kontrollratsgesetz Nr. 46), без правопреемника. '
        || 'Поглощает суверенитет Кенигсберга в холдинг (part_of), не Acqui аппарата.',
    '2.4',
    DATE '0965-05-20',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_reor_separ (separable_id, separated_id)
SELECT s.id, b.id
FROM org.org s
CROSS JOIN org.org b
WHERE s.code = 'saxon_east' AND b.code = 'brandenburg'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_separ r
      WHERE r.separable_id = s.id AND r.separated_id = b.id
  );

UPDATE org.org o
SET trm_method = '0.0.0',
    trm_date   = DATE '1947-02-25'
WHERE o.code = 'brandenburg'
  AND o.trm_method IS NULL;

-- ---------------------------------------------------------------------------
-- 3. Закрытие saxon_east — Absorb → brandenburg, 30.04.1816
-- ---------------------------------------------------------------------------
UPDATE org.org o
SET trm_method = '2.5.0',
    trm_date   = DATE '1816-04-30',
    note       = coalesce(o.note, '')
WHERE o.code = 'saxon_east'
  AND o.trm_method IS NULL;

INSERT INTO org.org_reor_acqui (acquired_id, acquiring_id)
SELECT s.id, b.id
FROM org.org s
CROSS JOIN org.org b
WHERE s.code = 'saxon_east' AND b.code = 'brandenburg'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_acqui a WHERE a.acquired_id = s.id
  );

-- ---------------------------------------------------------------------------
-- 4. prussia_duchy — Орден / Герцогство / провинция Восточная Пруссия
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'prussia_duchy',
    'Прусское ландмейстерство / Орденштаат → Герцогство Пруссия → провинция Пруссия/Восточная Пруссия (Кенигсберг). '
        || 'frm=1.0 26.03.1226 (Золотая булла Римини). 1525 секуляризация, провинциальный статус — convert. '
        || '1618 личная уния с Берлином; с 18.01.1701 part_of brandenburg (понижение, не Acqui). '
        || 'trm DivisAcqu (север→СССР) 02.08.1945; польская доля — позже.',
    '1.0',
    DATE '1226-03-26',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 5. east_prussia_ussr — промежуточный DivisAcqu → ussr (Потсдам)
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'east_prussia_ussr',
    'Промежуточное лицо: северная доля Восточной Пруссии при разделении с присоединением к СССР. '
        || 'frm=2.6 / trm=2.6.2, дата 02.08.1945 (Потсдам). Acquiring = ussr. '
        || 'Южная доля → Польша — отдельный divided_acqu позже.',
    '2.6',
    DATE '1945-08-02',
    '2.6.2',
    DATE '1945-08-02'
)
ON CONFLICT (code) DO NOTHING;

UPDATE org.org o
SET trm_method = '2.6.1',
    trm_date   = DATE '1945-08-02'
WHERE o.code = 'prussia_duchy'
  AND o.trm_method IS NULL;

INSERT INTO org.org_reor_divis_acqu (
    divisible_id, divided_acqu_id, acquiring_id
)
SELECT d.id, m.id, u.id
FROM org.org d
CROSS JOIN org.org m
CROSS JOIN org.org u
WHERE d.code = 'prussia_duchy'
  AND m.code = 'east_prussia_ussr'
  AND u.code = 'ussr'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_divis_acqu r
      WHERE r.divisible_id = d.id AND r.divided_acqu_id = m.id
  );

-- ---------------------------------------------------------------------------
-- 6. org_rel: prussia_duchy ⊂ brandenburg с 18.01.1701
-- ---------------------------------------------------------------------------
INSERT INTO org.org_rel (part_id, whole_id, rel_type, valid_from, valid_to, note)
SELECT p.id, w.id, 'part_of', DATE '1701-01-18', NULL,
       'Инкорпорация Кенигсберга в холдинг Берлина (коронация 18.01.1701); '
           || 'аппарат провинции жив до DivisAcqu 1945. Не Absorb.'
FROM org.org p
CROSS JOIN org.org w
WHERE p.code = 'prussia_duchy' AND w.code = 'brandenburg'
ON CONFLICT (part_id, whole_id, rel_type) DO NOTHING;

COMMIT;

-- VERIFY:
-- SELECT code, frm_method, to_char(frm_date,'YYYY-MM-DD') frm,
--        trm_method, to_char(trm_date,'YYYY-MM-DD') trm
-- FROM org.org
-- WHERE code IN ('saxon_east','brandenburg','prussia_duchy','east_prussia_ussr','ussr')
-- ORDER BY frm_date;
--
-- SELECT 'separ' t, s.code parent, d.code child FROM org.org_reor_separ r
-- JOIN org.org s ON s.id=r.separable_id JOIN org.org d ON d.id=r.separated_id
-- WHERE s.code='saxon_east' OR d.code='brandenburg'
-- UNION ALL
-- SELECT 'acqui', a.code, g.code FROM org.org_reor_acqui r
-- JOIN org.org a ON a.id=r.acquired_id JOIN org.org g ON g.id=r.acquiring_id
-- WHERE a.code='saxon_east'
-- UNION ALL
-- SELECT 'divis_acqu', d.code, m.code||'→'||u.code FROM org.org_reor_divis_acqu r
-- JOIN org.org d ON d.id=r.divisible_id JOIN org.org m ON m.id=r.divided_acqu_id
-- JOIN org.org u ON u.id=r.acquiring_id
-- WHERE d.code='prussia_duchy';
--
-- SELECT part_code, whole_code, to_char(valid_from,'YYYY-MM-DD') vf,
--        to_char(eff_from,'YYYY-MM-DD') eff_from, to_char(eff_to,'YYYY-MM-DD') eff_to
-- FROM org.org_rel_effective
-- WHERE part_code='prussia_duchy' AND whole_code='brandenburg';
