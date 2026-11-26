# План: жизненный цикл `org` и правопреемство (от `rgTax`)

**Чат:** 26-1124_01_org_lifecycle  
**Дата создания:** 2026-11-24  
**Последнее обновление:** 2026-11-25  
**Версия плана:** 0.4.2  
**Статус:** 🔶 in-progress — ★ **2.4** class sync (после ✅ 2.3 apply `014`)  

**Стек:** PostgreSQL 16 / PostGIS — `maps_db`, schema **`org`**, порт **5434** (геометрия не используется).  
**Источник каркаса:** MS SQL `FishEye` / `FishEye_prod_noM6`, `ags.rgTax*` / `rgTaxReor*` (Cursor DBHub).  
**Канон решений:** [docs/org/26-1124_org_lifecycle_iteration0.md](../../org/26-1124_org_lifecycle_iteration0.md)  
**ER Postgres:** [docs/org/26-1124_org_lifecycle_er.md](../../org/26-1124_org_lifecycle_er.md)  
**DDL:** [scripts/sql/013_org_lifecycle.sql](../../../scripts/sql/013_org_lifecycle.sql)  
**Предыстория форм:** [sovereign_transformation.md](../../org/sovereign_transformation.md) · [sovereign_class_diagram.md](../../org/sovereign_class_diagram.md)  
**Соседний контур имён:** [26-1029_01_states_orgs.md](26-1029_01_states_orgs.md) (фаза A `name_form` — не блокирует)

Остальные разделы (§1, §3–§5) — **детализация** дерева §2. Правки **порядка и состава** сначала в §2.

---

## 0. Цель

Построить в schema `org` **реляционный жизненный цикл организации** (государство, позже соединения ВС и др.) по образцу `rgTax` / `rgTaxReor*`, с минимальной адаптацией:

- лицо `org` + способы создания/прекращения;  
- таблицы **правопреемства** (`org_reor_*`) как основа основ;  
- **преобразование не меняет id**;  
- **двусторонняя** целостность method↔Reor (вариант A);  
- расширение итерациями: ЖЦ+Reor → прецеденты → длящиеся связи → оккупация.

### Критерий закрытия итерации 0

1. DDL лица, справочников и `org_reor_*` **применён** в `maps_db.org`. ✅  
2. Convert = same id зафиксирован в доке и схеме (нет `org_reor_trans`). ✅  
3. На данных: Австрия → Германия через `org_reor_acqui` (не только дата на лице). ✅  
4. Нет Membership / occupation / налоговых полей в этом DDL. ✅  

### Вне scope

| Область | Почему |
|---------|--------|
| Геопривязка, Martin | другой контур |
| VIEW `name_form` (26-1029) | соседний план |
| OWL как хранилище фактов | словарь позже; факты — SQL |
| ИНН/ИФНС/`rgTaxInd` | налоговый шум |
| `org.sovereign` | устаревшая; не трогать |

---

## 1. Стенд и доступ (детализация §2 / 1.9.1)

| Что | Где | Статус (2026-11-25) |
|-----|-----|---------------------|
| PostGIS | `10.7.0.3:5434` / `maps_db` / `maps_user` | ✅ TCP+auth OK (WG `vps-vpn`) |
| Localhost `:5434` | эта машина | ❌ нет контейнера |
| Schema `org` после apply | `org`, `org_*_method`, `org_reor_*` + прежние | ✅ 013 + seed JP |
| FishEye (образец) | `10.7.0.3:1433` / DBHub | ✅; переключение `./scripts/setup-cursor-mcp.sh fisheye` |
| DBHub → maps_db | `.cursor/mcp.json` remote | ✅ `setup-cursor-mcp.sh maps-db-remote` |
| `psql` на хосте | — | ❌; apply/seed через `node`+`pg` или DBeaver (nb-win) |

DSN remote: `postgresql://maps_user:maps_pass@10.7.0.3:5434/maps_db`.

---

## 2. Дерево работ

Легенда: ☐ не начато · 🔶 в работе · ✅ готово · ⏸ пауза.  
`★` — узел критического пути. `‖` — допустимо параллельно с соседним.

```text
1. Жизненный цикл org + правопреемство                         🔶
│
├─ 0. Решения и документы                                      ✅ 2026-11-24…25
│  ├─ 0.1 Канон итерации 0 (26-1124_org_lifecycle_iteration0)  ✅
│  ├─ 0.2 План чата (этот файл)                                ✅
│  ├─ 0.3 Извлечение rgTax* / Reor* через DBHub                ✅
│  ├─ 0.4 Связь с sovereign_* / эскизом org / 26-1106          ✅
│  ├─ 0.5 ER Postgres (26-1124_org_lifecycle_er)               ✅
│  ├─ 0.6 Именование: лицо `org`, спутники `org_*`             ✅ 2026-11-25
│  └─ 0.7 Целостность method↔Reor = вариант A                  ✅ 2026-11-25
│        · FK+DEFAULT как rgTax; deferred triggers лицо→ребро
│        · вариант B отклонён; API-функции — позже
│
├─ 1. Итерация 0 — DDL и apply                                 ✅ 2026-11-25
│  │   скрипт: scripts/sql/013_org_lifecycle.sql
│  ├─ 1.1 Справочники org_frm_method / org_trm_method          ✅
│  ├─ 1.2 Таблица org.org (frm/trm + даты + UK id+method)       ✅
│  ├─ 1.3 org_reor_acqui / merge / divis / separ               ✅
│  ├─ 1.4 Каркас сочетаний (*_acqu / *_merg)                   ✅
│  ├─ 1.5 Convert = same id (без Trans)                        ✅
│  ├─ 1.6 Deferred triggers assert_org_reor_consistency        ✅
│  ├─ 1.7 Seed AT→DE в 013 (1938-03-13, reor_acqui)            ✅
│  ├─ 1.8 Имена под id (rgTaxName*)                            ⏸ → 0.5
│  ├─ 1.9 Apply 013 на maps_db + VERIFY                        ✅ 2026-11-25
│  │  ├─ 1.9.1 TCP/auth maps_db @ 10.7.0.3:5434                ✅
│  │  ├─ 1.9.2 node/pg apply 013_org_lifecycle.sql             ✅
│  │  ├─ 1.9.3 VERIFY: austria trm=2.5.0 + acqui→germany       ✅
│  │  └─ 1.9.4 Негатив: сирота method без ребра → ошибка       ✅
│  └─ 1.10 Документы после apply (план/ER/канон)               ✅ 2026-11-25
│
├─ 2. Прецеденты на каркасе 0                                  🔶 next=2.4
│  ├─ 2.1 Absorb AT→DE                                         ✅ 2026-11-25
│  ├─ 2.2 Convert: Япония — ЖЦ id                              ✅ 2026-11-25
│  │      · org.org japan frm=1.0, frm_date=0660-02-11 BC
│  ├─ 2.3 Линия kiev→vladimir→moscow                           ✅ 2026-11-26
│  │      · apply 014 OK; separ×2; acqui kiev/vladimir→moscow
│  │      · assert PASS; календарь A; kiev close упрощён
│  └─ 2.4 Синхронизация sovereign_class_diagram ↔ DDL          ☐ ★
│
├─ 3. Итерация 2 — длящиеся связи                              ⏸
│  │   Membership / org_rel (часть–целое); ≠ Reor
│  ├─ 3.1 ER/DDL part_of (Пруссия ⊂ Германия)                  ☐
│  └─ 3.2 Анти-смешение absorb ≠ membership                    ☐
│
└─ 4. Оккупация / вертикаль контроля                           ⏸
   └─ 4.1 После 2–3; см. 26-1106                               ☐
```

**Критическая цепочка:**

```text
0 ✅  →  1 ✅  →  2.1 ✅  →  2.2 ✅  →  2.3 ✅  →  2.4 class sync  →  3…
```

**Сейчас ★:** **`2.4`** (sync class-диаграммы с DDL).

---

## 3. Принципы (кратко)

1. **Правопреемство ≠ состав.** `org_reor_acqui` — прекращение-присоединение; `part_of` — пока оба живы.  
2. **Основа — Reor* + method на лице**; kind без ребра для absorb/merge/… недостаточен.  
3. **Двусторонняя целостность** — вариант A (ER §4.1).  
4. **`org` шире суверена**; `org_type` — позже.  
5. **convert = same id.**  
6. **`name_form`** — соседний контур, не кодирует absorb.  
7. **Горизонт:** `frm=1.0` обрезает регресс предков; Separ — когда нужны два живых id.  
8. **Календарь A:** `frm_date`/`trm_date` только григориан (пролептический); исходник в `note`.  
9. Правки порядка — сначала дерево §2.

---

## 4. Артефакты

| Путь | Роль |
|------|------|
| [26-1124_org_lifecycle_iteration0.md](../../org/26-1124_org_lifecycle_iteration0.md) | канон итерации 0 (закрыта) |
| [26-1124_org_lifecycle_er.md](../../org/26-1124_org_lifecycle_er.md) | ER + матрица + прецеденты |
| [013_org_lifecycle.sql](../../../scripts/sql/013_org_lifecycle.sql) | DDL + triggers + seed AT/DE/JP |
| [014_org_precedents_kievan_line.sql](../../../scripts/sql/014_org_precedents_kievan_line.sql) | seed kiev/vladimir/moscow + Reor |
| [26-1125_google_org_chat.md](../../26-1125_google_org_chat.md) | обсуждение непрерывности JP/Русь |
| [sovereign_transformation.md](../../org/sovereign_transformation.md) | перечень форм |
| [sovereign_class_diagram.md](../../org/sovereign_class_diagram.md) | классы сегментов 1–3 |
| [26-1106_sovereign_relation_discussion.md](../../org/26-1106_sovereign_relation_discussion.md) | Membership/оккупация (после 0) |

---

## 5. Следующий конкретный шаг

★ **2.4** — синхронизация `sovereign_class_diagram` с реляцией (`013`/`014`, прецеденты JP + Киевская линия).

---

## 6. Журнал

| Дата | Событие |
|------|---------|
| 2026-11-24 | Итерации; Reor* в 0; convert = same id; план 0.1.0 + канон; DBHub. |
| 2026-11-24 | ER-черновик; `sovereign` устаревший; план 0.1.1. |
| 2026-11-25 | Имена `org_*`; целостность A; DDL `013` + seed AT→DE; план 0.2.0. |
| 2026-11-25 | Postgres @ 10.7.0.3:5434 доступен; apply `013` OK; VERIFY AT→DE. |
| 2026-11-25 | §2 **Дерево работ** как в femsq; план 0.3.2. |
| 2026-11-25 | DBHub → maps_db; seed `japan` (660-02-11 BC); горизонт/Separ; итерация 0 закрыта; план 0.4.0. |
| 2026-11-26 | Календарь A; SQL `014` kiev/vladimir/moscow (kiev close упрощён); план 0.4.1. |
| 2026-11-26 | Apply `014` OK; VERIFY separ/acqui/assert; план 0.4.2; ★ → 2.4. |
