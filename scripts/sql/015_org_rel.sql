-- 015_org_rel.sql
-- Длящиеся связи Membership / part_of (итерация связей v0).
-- Канон: docs/org/26-1126_org_rel.md
-- Календарь A: DATE = григориан. ЖЦ org не меняем.
-- Seed: moscow ⊂ vladimir (valid_from/to NULL → effective из frm/trm).

BEGIN;

CREATE TABLE IF NOT EXISTS org.org_rel (
    id          BIGSERIAL PRIMARY KEY,
    part_id     BIGINT NOT NULL REFERENCES org.org (id),
    whole_id    BIGINT NOT NULL REFERENCES org.org (id),
    rel_type    TEXT NOT NULL DEFAULT 'part_of',
    valid_from  DATE,
    valid_to    DATE,
    note        TEXT,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT org_rel_neq CHECK (part_id <> whole_id),
    CONSTRAINT org_rel_interval_chk CHECK (
        valid_to IS NULL OR valid_from IS NULL OR valid_to >= valid_from
    ),
    CONSTRAINT org_rel_pair_type_uk UNIQUE (part_id, whole_id, rel_type)
);

COMMENT ON TABLE org.org_rel IS
    'Длящиеся связи между org (v0: part_of). Не правопреемство (см. org_reor_*).';
COMMENT ON COLUMN org.org_rel.valid_from IS
    'NULL = effective start = greatest(part.frm_date, whole.frm_date)';
COMMENT ON COLUMN org.org_rel.valid_to IS
    'NULL = effective end = least(non-null trm) of endpoints, or open if both living';

CREATE INDEX IF NOT EXISTS ix_org_rel_part ON org.org_rel (part_id);
CREATE INDEX IF NOT EXISTS ix_org_rel_whole ON org.org_rel (whole_id);

CREATE OR REPLACE VIEW org.org_rel_effective AS
SELECT
    r.id,
    r.part_id,
    p.code AS part_code,
    r.whole_id,
    w.code AS whole_code,
    r.rel_type,
    r.valid_from,
    r.valid_to,
    CASE
        WHEN r.valid_from IS NOT NULL THEN r.valid_from
        ELSE GREATEST(p.frm_date, w.frm_date)
    END AS eff_from,
    CASE
        WHEN r.valid_to IS NOT NULL THEN r.valid_to
        WHEN p.trm_date IS NULL AND w.trm_date IS NULL THEN NULL
        WHEN p.trm_date IS NULL THEN w.trm_date
        WHEN w.trm_date IS NULL THEN p.trm_date
        ELSE LEAST(p.trm_date, w.trm_date)
    END AS eff_to,
    r.note
FROM org.org_rel r
JOIN org.org p ON p.id = r.part_id
JOIN org.org w ON w.id = r.whole_id;

COMMENT ON VIEW org.org_rel_effective IS
    'org_rel + eff_from/eff_to по правилу NULL→границы ЖЦ участников';

-- Seed: московский удел в составе ВКВ (границы из ЖЦ)
INSERT INTO org.org_rel (part_id, whole_id, rel_type, valid_from, valid_to, note)
SELECT p.id, w.id, 'part_of', NULL, NULL,
       'Удел Москвы в составе Владимирского вел. кн.; границы effective из frm/trm. '
           || 'Конец совпадает с Absorb vladimir→moscow (1389). Не путать с Reor.'
FROM org.org p
CROSS JOIN org.org w
WHERE p.code = 'moscow' AND w.code = 'vladimir'
ON CONFLICT (part_id, whole_id, rel_type) DO NOTHING;

COMMIT;

-- VERIFY:
-- SELECT part_code, whole_code, rel_type,
--        to_char(eff_from,'YYYY-MM-DD') eff_from,
--        to_char(eff_to,'YYYY-MM-DD') eff_to
-- FROM org.org_rel_effective;
