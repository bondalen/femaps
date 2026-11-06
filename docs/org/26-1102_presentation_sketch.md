# Эскиз UI: деревья представления `de` / `en` / `ru` (v0 после уточнений 2026-11-02)

**Чат / план:** [26-1029_01_states_orgs.md](../chat/plan/26-1029_01_states_orgs.md) (узел **1.1.1**, фаза A)  
**Алгоритм:** [README.md](README.md) §4 (явное ребро / туннель / ближайший показанный предок)  
**Предшественник:** [26-1101_presentation_sketch.md](26-1101_presentation_sketch.md)  

Обозначения: ветка = `name_form`; `#n` = лист периода (`sovereign_name_form` + полное официальное имя).

**Принцип имён:** самоназвание задаёт полный титул на листе; `name_form` для de-полок учитывает и **наиболее употребимую немецкую основу**, где самоназвание + наличие императора иначе схлопнулись бы в голый Staat (*Teikoku* / *империя* → в de обычно *Kaiserreich*).

---

## 0. Решения (актуально)

| Тема | Решение |
|------|---------|
| Германия | два периода на **`reich`**: *Deutsches Reich*, *Großdeutsches Reich* |
| Австрия | **`kaisertum`**, ребро **`empire → kaisertum` (de)** — *не* под `reich` (офиц. избегали *Kaiserreich*) |
| Россия, Япония (имп.) | **`kaiserreich`**, ребро **`reich → kaiserreich` (de)** — под **Reich** |
| Япония после 1947 | **`state`** (*Nihon-koku*) — под Staat; император в конституции не требует полки Kaiserreich |
| Weimar / DE→`kaiserreich` | не сеем |
| en / ru | `kaisertum` / `kaiserreich` / `reich` свёртка под empire / империю |

Даты — модель; конец Großdeutsch: **1945-06-04** (решение владельца).

---

## 1. Смысловые рёбра и метки языков (канон для 1.1.1.1)

| # | parent → child | Явные метки | Замечание |
|---|----------------|-------------|-----------|
| 1 | `state` → `empire` | **en, ru** | Полка empire / империя; в **de** туннель |
| 2 | `empire` → `reich` | **de** | *Reich* уже empire; **без** `state → reich` |
| 3 | `empire` → `kaisertum` | **de** | Австрийское *Kaisertum*; **не** под `reich` |
| 4 | `reich` → `kaiserreich` | **de** | Употребимая de-полка для JP/RU (император + *Kaiserreich …*) |
| 5 | `reich` → `kingdom` | **de** | Königreich под Reich |
| 6 | `state` → `kingdom` | **en, ru** | Короткий путь |
| 7 | `state` → `republic` | **en, de, ru** | Республики |

Ярлыки вершин (ориентир seed):

| code | de | en | ru |
|------|----|----|-----|
| `state` | Staat | state | государство |
| `empire` | *(не ветка)* | empire | империя |
| `kaisertum` | Kaisertum | *(не ветка)* | *(свёртка в империю)* |
| `reich` | Reich | *(не ветка)* | *(свёртка в империю)* |
| `kaiserreich` | Kaiserreich | *(не ветка)* | *(свёртка в империю)* |
| `kingdom` | Königreich | kingdom | королевство |
| `republic` | Republik | republic | республика |

---

## 2. Якоря периодов

| sovereign | valid_from | valid_to | name_form | Полное имя на листе (official / привычное) |
|-----------|------------|----------|-----------|---------------------------------------------|
| `japan` | 1889-11-29 | 1947-05-02 | **`kaiserreich`** | 大日本帝国 / Dai-Nippon Teikoku |
| `japan` | 1947-05-03 | — | `state` | 日本国 / Nihon-koku |
| `austria` | 1804-08-11 | 1867-06-08 | `kaisertum` | Kaisertum Österreich |
| `russia` | 1721-10-22 | 1917-09-14 | **`kaiserreich`** | Российская империя |
| `germany` | 1871-01-18 | 1943-06-25 | `reich` | Deutsches Reich |
| `germany` | 1943-06-26 | 1945-06-04 | `reich` | Großdeutsches Reich |
| `italy` | … | 1946-06-18 | `kingdom` | Regno d’Italia |
| `france` | … | … | `republic` | République française |

Почему JP/RU → `kaiserreich`, а не `empire`: в de голый якорь `empire` скрыт туннелем → лист под Staat, что противоречит самоназванию-как-империя и наличию императора; *Kaiserreich* — наиболее употребимая немецкая основа для этих polity.  
Полные офиц. строки (*Российская империя*, *Dai-Nippon Teikoku*) остаются на листе; de-варианты *Russisches Kaiserreich* / *Japanisches Kaiserreich* — опционально в `sovereign_name` (historiographic).

Неофициальные строки (не двигают `name_form`):

| Текст | role |
|-------|------|
| Kaiserreich Österreich, Österreichischer Kaiserstaat | cartographic / historiographic (`de`) — AT **не** якорим на `kaiserreich` |
| Russisches Kaiserreich, Japanisches Kaiserreich | historiographic (`de`) |
| Rußland (RGBl) | short / diplomatic (`de`) |
| Austrian / Russian / German Empire или Reich (en) | exonym |

---

## 3. Желаемое дерево: `de`

```text
1. Staat                                    name_form  state
├── 1.#1. Nihon-koku                        japan      1947-05-03 —
├── 1.1. Kaisertum                          name_form  kaisertum
│   └── 1.1.#1. Kaisertum Österreich        austria    1804-08-11 — 1867-06-08
├── 1.2. Reich                              name_form  reich
│   ├── 1.2.#1. Deutsches Reich             germany    1871-01-18 — 1943-06-25
│   ├── 1.2.#2. Großdeutsches Reich         germany    1943-06-26 — 1945-06-04
│   ├── 1.2.1. Kaiserreich                  name_form  kaiserreich
│   │   ├── 1.2.1.#1. Dai-Nippon Teikoku    japan      1889-11-29 — 1947-05-02
│   │   └── 1.2.1.#2. Российская империя    russia     1721 — 1917
│   └── 1.2.2. Königreich                   name_form  kingdom
│       └── 1.2.2.#1. Regno d’Italia /
│           Königreich Italien              italy      … — 1946-06-18
└── 1.3. Republik                           name_form  republic
    └── 1.3.#1. République française        france     …
```

`empire` в de не ветка.  
AT: `state → empire → kaisertum` → Kaisertum под Staat.  
JP/RU: `state → empire → reich → kaiserreich` → Kaiserreich **под Reich**.

---

## 4. Желаемое дерево: `en`

```text
1. state                                    name_form  state
├── 1.#1. Nihon-koku                        japan      1947-05-03 —
├── 1.1. empire                             name_form  empire
│   ├── 1.1.#1. Dai-Nippon Teikoku          japan      1889-11-29 — 1947-05-02
│   ├── 1.1.#2. Kaisertum Österreich /
│   │   Austrian Empire                     austria    1804-08-11 — 1867-06-08
│   ├── 1.1.#3. Российская империя /
│   │   Russian Empire                      russia     1721 — 1917
│   ├── 1.1.#4. Deutsches Reich /
│   │   German Reich                        germany    1871-01-18 — 1943-06-25
│   └── 1.1.#5. Großdeutsches Reich /
│       Greater German Reich                germany    1943-06-26 — 1945-06-04
├── 1.2. kingdom                            name_form  kingdom
│   └── 1.2.#1. Kingdom of Italy            italy      … — 1946-06-18
└── 1.3. republic                           name_form  republic
    └── 1.3.#1. French Republic             france     …
```

`reich` / `kaisertum` / `kaiserreich` в en не показываются (туннели к empire).

---

## 5. Желаемое дерево: `ru`

```text
1. государство                              name_form  state
├── 1.#1. Нихон-коку / Nihon-koku           japan      1947-05-03 —
├── 1.1. империя                            name_form  empire
│   ├── 1.1.#1. Дай-Ниппон Тэйкоку          japan      1889-11-29 — 1947-05-02
│   ├── 1.1.#2. Кайзертум Австрия /
│   │   Австрийская империя                 austria    1804-08-11 — 1867-06-08
│   ├── 1.1.#3. Российская империя          russia     1721 — 1917
│   ├── 1.1.#4. Германский рейх /
│   │   Deutsches Reich                     germany    1871-01-18 — 1943-06-25
│   └── 1.1.#5. Великогерманский рейх /
│       Großdeutsches Reich                 germany    1943-06-26 — 1945-06-04
├── 1.2. королевство                        name_form  kingdom
│   └── 1.2.#1. Королевство Италия          italy      … — 1946-06-18
└── 1.3. республика                         name_form  republic
    └── 1.3.#1. Французская республика      france     …
```

Отдельных веток «рейх» / «кайзеррейх» / «кайзертум» в ru нет.

---

## 6. Сводка эффекта туннелей

| name_form периода | de | en | ru |
|-------------------|----|----|----|
| `state` | Staat | state | государство |
| `kaisertum` | **Kaisertum** (под Staat) | empire | империя |
| `reich` | **Reich** | empire | империя |
| `kaiserreich` | **Kaiserreich** (под Reich) | empire | империя |
| `kingdom` | Königreich (под Reich) | kingdom | королевство |
| `republic` | Republik | republic | республика |

---

## 7. Различения (чтобы не смешать полки)

| Полка de | Кого кладём | Кого не кладём |
|----------|-------------|----------------|
| **Kaisertum** | AT 1804–1867 (офиц. самоназвание) | JP, RU, DE |
| **Kaiserreich** | JP Teikoku, RU империя (употребимое de + император) | AT (официально не *Kaiserreich*), DE (*…Reich* без Kaiserreich как основы) |
| **Reich** | DE *Deutsches* / *Großdeutsches Reich*; родитель для Kaiserreich и Königreich | — |
| **Staat** (лист) | Nihon-koku и др. нейтральные `state` | имперские JP/RU |

---

## 8. Вне скетча

- Австро-Венгрия после 1867 и далее  
- Weimar как `republic`  
- `de-DE` / `de-AT` вместо ролей полного имени  
- Фаза B (ВС / коалиции)

---

## 9. Связь с планом

| Узел | Использование |
|------|----------------|
| **1.1.1.1** | Таблица рёбер §1 |
| **1.1.2** | Якоря §2 |
| **1.1.3.2** | Приёмка ≅ §3–§5 |
