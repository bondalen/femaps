-- 014_org_precedents_kievan_line.sql
-- Прецеденты ЖЦ: kiev → vladimir (Separ) → moscow (Separ); Absorb ВКВ→Москва;
-- закрытие kiev упрощённо как Absorb→moscow (исторически divis+acqu; cutoff).
-- Календарь: вариант A — все DATE = григориан (пролептический); см. ER §4.2.
-- Источник обсуждения: docs/26-1125_google_org_chat.md
-- Применять после 013 на maps_db. Идемпотентность: ON CONFLICT / NOT EXISTS.
--
-- НЕ выполнен автоматически — прогнать вручную / через node+pg после ревью.

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. kiev — ствол frm=1.0 (имперская дата тысячелетия Руси)
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'kiev',
    'Линия ВКК→Киевское кн.→воеводство. Учётный frm = имперская дата 08.09.862 '
        || '(григорианская колонка, вариант A). 882 релокация, 1169/1240/1471/1667 — тот же id '
        || '(convert/статус/оккупация/Membership, не новый org). '
        || 'Источник: docs/26-1125_google_org_chat.md',
    '1.0',
    DATE '0862-09-08',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

-- ---------------------------------------------------------------------------
-- 2. vladimir — выделение из kiev (РСЗ/ВКВ), 01.07.988
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'vladimir',
    'РСЗ→ВКВ. frm=2.4 Separ из kiev; учётный якорь 01.07.988 (середина вероятного года '
        || 'посажения стола в Ростове; григорианская колонка, вариант A). '
        || '1157 суверенитет/штаб во Владимир — тот же id (convert).',
    '2.4',
    DATE '0988-07-01',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_reor_separ (separable_id, separated_id)
SELECT k.id, v.id
FROM org.org k
CROSS JOIN org.org v
WHERE k.code = 'kiev' AND v.code = 'vladimir'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_separ s
      WHERE s.separable_id = k.id AND s.separated_id = v.id
  );

-- ---------------------------------------------------------------------------
-- 3. moscow — выделение из vladimir (удел), 14.11.1263
-- ---------------------------------------------------------------------------
INSERT INTO org.org (code, note, frm_method, frm_date, trm_method, trm_date)
VALUES (
    'moscow',
    'УКМ→ВКМ→… стволовая линия. frm=2.4 Separ из vladimir; '
        || '14.11.1263 (смерть А. Невского / завещание Даниилу; число как в историографии, '
        || 'в колонке DATE как пролептический григориан, вариант A). Жив.',
    '2.4',
    DATE '1263-11-14',
    NULL,
    NULL
)
ON CONFLICT (code) DO NOTHING;

INSERT INTO org.org_reor_separ (separable_id, separated_id)
SELECT v.id, m.id
FROM org.org v
CROSS JOIN org.org m
WHERE v.code = 'vladimir' AND m.code = 'moscow'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_separ s
      WHERE s.separable_id = v.id AND s.separated_id = m.id
  );

-- ---------------------------------------------------------------------------
-- 4. Absorb: vladimir → moscow, 19.05.1389
-- ---------------------------------------------------------------------------
UPDATE org.org o
SET trm_method = '2.5.0',
    trm_date   = DATE '1389-05-19',
    note       = coalesce(o.note, '') || ' Закрыт Absorb→moscow 19.05.1389 (смерть Донского / сила завещания).'
WHERE o.code = 'vladimir'
  AND o.trm_method IS NULL;

INSERT INTO org.org_reor_acqui (acquired_id, acquiring_id)
SELECT v.id, m.id
FROM org.org v
CROSS JOIN org.org m
WHERE v.code = 'vladimir' AND m.code = 'moscow'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_acqui a WHERE a.acquired_id = v.id
  );

-- ---------------------------------------------------------------------------
-- 5. Закрытие kiev — УПРОЩЕНИЕ: Absorb→moscow (вместо divis+acqu 1793)
--    Исторически: разделение поветов с присоединением к КН и ИзГ; cutoff.
--    Дата в БД: 24.04.1793 григориан (= 13.04.1793 юлиан, указ о ликвидации центра).
-- ---------------------------------------------------------------------------
UPDATE org.org o
SET trm_method = '2.5.0',
    trm_date   = DATE '1793-04-24',
    note       = coalesce(o.note, '')
        || ' Закрытие УПРОЩЕНО: trm Absorb→moscow 24.04.1793 гр. (исходник 13.04.1793 юл., '
        || 'указ Екатерины II). Исторически ближе divis+acqu в КН и ИзГ; полная раскладка '
        || 'принимающих — вне текущего этапа.'
WHERE o.code = 'kiev'
  AND o.trm_method IS NULL;

INSERT INTO org.org_reor_acqui (acquired_id, acquiring_id)
SELECT k.id, m.id
FROM org.org k
CROSS JOIN org.org m
WHERE k.code = 'kiev' AND m.code = 'moscow'
  AND NOT EXISTS (
      SELECT 1 FROM org.org_reor_acqui a WHERE a.acquired_id = k.id
  );

COMMIT;

-- VERIFY:
-- SELECT code, frm_method, to_char(frm_date,'DD.MM.YYYY AD') frm,
--        trm_method, to_char(trm_date,'YYYY-MM-DD') trm
-- FROM org.org WHERE code IN ('kiev','vladimir','moscow','japan') ORDER BY frm_date;
--
-- SELECT 'separ' AS t, s.code AS parent, d.code AS child
-- FROM org.org_reor_separ r
-- JOIN org.org s ON s.id=r.separable_id JOIN org.org d ON d.id=r.separated_id
-- UNION ALL
-- SELECT 'acqui', a.code, g.code
-- FROM org.org_reor_acqui r
-- JOIN org.org a ON a.id=r.acquired_id JOIN org.org g ON g.id=r.acquiring_id
-- ORDER BY 1, 2;
