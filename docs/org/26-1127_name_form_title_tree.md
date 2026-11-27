# Эскиз расширения `name_form`: дерево **самоназваний** (титульных формул)

**Статус:** seed applied на `maps_db` 2026-11-27 (`019_name_form_titles_brandenburg.sql`); VERIFY brandenburg 965…1947 OK.  
**SQL:** [`019_name_form_titles_brandenburg.sql`](../../scripts/sql/019_name_form_titles_brandenburg.sql).  
**Контур:** ярлыки официального **наименования**, не форма государственного устройства и не ЖЦ (`org_reor_*` / конституция).  
**Стык:** периоды на `org` — [26-1127_org_name.md](26-1127_org_name.md); канон туннелей v0 — [26-1102_presentation_sketch.md](26-1102_presentation_sketch.md) (ветка empire/reich **сохраняется**).  
**План:** [26-1124_01_org_lifecycle.md](../chat/plan/26-1124_01_org_lifecycle.md) (покрытие имён `brandenburg` и др.).

---

## 1. Принцип

| Да | Нет |
|----|-----|
| Как субъект **себя называет** в титуле (Marke, Kurfürstentum, Königreich, Freistaat…) | Отдельная модель «форма правления» / суверенитет / Reor |
| Агрегация по предкам DAG: «сколько княжеств на дату», в т.ч. по подвидам | Путать *Großfürstentum* и *Großherzogtum* |
| Курфюршество ⊂ княжество (*Kur* + *Fürst*) | Вешать марку под княжество |

Существующая ветка `state → empire → reich / kaisertum / …` остаётся для имперских самоназваний; ниже — **параллельные** ветки от `state` для княжеств, герцогств, марок, свободных государств.

Структурные номера (`1.1.1`) — только UI/эскиз, не PK.

---

## 2. Целевое смысловое дерево (эскиз)

```text
state                          государство / Staat / state
│
├─ empire …                    (уже в v0: empire / reich / kaisertum / kaiserreich / kingdom⋆)
│
├─ kingdom                     королевство (уже в v0; пути de/en как сейчас)
├─ republic                    республика (уже в v0)
├─ freistaat                   свободное государство / Freistaat / Free State
│
├─ mark                        марка / Marke / march·margraviate
│                              (Nordmark, Mark Brandenburg; НЕ под княжеством)
│
├─ principality                княжество / Fürstentum / principality
│   ├─ electorate              княжество электора / Kurfürstentum / electorate
│   ├─ grand_principality      великое княжество / Großfürstentum
│   └─ appanage_principality   удельное княжество / appanage principality
│
└─ duchy                       герцогство / Herzogtum / duchy
    └─ grand_duchy             великое герцогство / Großherzogtum / grand duchy
```

⋆ `kingdom` в v0 также достижим через `reich → kingdom` (de) и `state → kingdom` (en, ru) — не ломать.

Позже по прецедентам (не в этом эскизе): графства, ландграфства, военные division/panzer, муниципальные arrondissement…

---

## 3. Вершины: коды и ярлыки (ориентир seed)

| code | assignable | de | en | ru |
|------|------------|----|----|-----|
| `freistaat` | да | Freistaat | Free State | свободное государство |
| `mark` | да | Marke | march / margraviate | марка / маркграфство |
| `principality` | да | Fürstentum | principality | княжество |
| `electorate` | да | Kurfürstentum | electorate | курфюршество |
| `grand_principality` | да | Großfürstentum | grand principality | великое княжество |
| `appanage_principality` | да | Teilfürstentum | appanage principality | удельное княжество |
| `duchy` | да | Herzogtum | duchy | герцогство |
| `grand_duchy` | да | Großherzogtum | grand duchy | великое герцогство |

Уже есть и **не переименовываем:** `state`, `empire`, `reich`, `kaisertum`, `kaiserreich`, `kingdom`, `republic`.

---

## 4. Новые смысловые рёбра и метки языков

| parent → child | Явные метки (старт) | Замечание |
|----------------|---------------------|-----------|
| `state` → `freistaat` | de, en, ru | Сосед `republic`, не потомок |
| `state` → `mark` | de, en, ru | Маркграфский титул / пограничная марка |
| `state` → `principality` | de, en, ru | Корень «княжеств» для агрегации |
| `principality` → `electorate` | de, en, ru | *Kurfürst* ⊂ *Fürst* |
| `principality` → `grand_principality` | de, en, ru | Не путать с `grand_duchy` |
| `principality` → `appanage_principality` | de, en, ru | Удел как самоназвание |
| `state` → `duchy` | de, en, ru | Корень «герцогств» |
| `duchy` → `grand_duchy` | de, en, ru | Baden, Hessen, Luxemburg… |

Туннели: при отсутствии метки L обход идёт дальше; правила README §4 не меняем. Уточнение «нужна ли свёртка electorate под principality в en» — при seed UI.

---

## 5. Агрегация на дату

Смысловой DAG (не UI-туннель одного языка):

- периоды `org_name_form`, у которых дата D ∈ `[valid_from, effective_to)`;
- «княжества» = формула ∈ поддереве `principality` (включая `electorate`, `grand_principality`, `appanage_principality`);
- «герцогства» = поддерево `duchy` (включая `grand_duchy`);
- срезы по листьям — по разновидностям самоназвания.

ЖЦ и `part_of` в этот счёт **не** входят.

---

## 6. Покрытие `brandenburg` (после seed дерева)

| valid_from | name_form | full de (ориентир) |
|------------|-----------|-------------------|
| `0965-05-20` | `mark` | Nordmark |
| `1157-06-11` | `mark` | Mark Brandenburg |
| `1356-01-10` | `electorate` | Kurfürstentum Brandenburg |
| `1701-01-18` | `kingdom` | Königreich Preußen |
| `1918-11-09` | `freistaat` | Freistaat Preußen |

Внутри `kingdom` смена «in Preußen» / «von Preußen» — новые `org_name` при том же периоде формулы (или дробление периода — по желанию).  
`org_num` не требуется.

`prussia_duchy` (Кенигсберг): периоды на `duchy` (и при необходимости convert-имена провинции) — отдельным seed, не смешивать с берлинским `brandenburg`.

---

## 7. Порядок внедрения в БД

1. INSERT `name_form` + `name_form_label` (таблица §3).  
2. INSERT `name_form_edge` + `name_form_edge_label` (таблица §4).  
3. Seed `org_name_form` / `org_name` для `brandenburg` (§6).  
4. Позже: `prussia_duchy` на `duchy`; прочие прецеденты (уделы, великие княжества/герцогства).

Скрипт: **`019` applied**; legacy `sovereign_*` не трогали. de-ярлык удела: `Teilfürstentum`. Метки рёбер: de/en/ru явны.

---

## 8. Дальше

- `prussia_duchy` на `duchy` (+ имена провинции).  
- Нужен ли отдельный `margraviate` vs один `mark`.  
- Смена «König in/von Preußen» — доп. `org_name` внутри периода `kingdom`.
