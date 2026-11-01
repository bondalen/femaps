# Эскиз уровня представления (de / en)

**Исходник:** перенесено из `docs/26-1101.txt` (01.11.2026), ошибки эскиза исправлены, модель рёбер согласована с туннелями.  
**См. также:** [README.md](README.md) (алгоритм), [glossary.md](glossary.md).

Обозначения: `name_form@N` — основа имени; `sovereign@N` — суверен; `#k` — лист периода (`sovereign_name_form`). Даты — ориентиры для модели.

---

## 1. Желаемое дерево: `de`

```text
1. Staat                          name_form@1  state
├── 1.#1. Nihon-koku              sovereign@1  japan       1947-05-03 —
├── 1.1. Reich                    name_form@2  reich
│   ├── 1.1.#1. Großdeutsches Reich
│   │                             sovereign@2  germany     … — 1945-05-08
│   ├── 1.1.1. Kaiserreich        name_form@4  kaiserreich
│   │   ├── 1.1.1.#1. Dai-Nippon Teikoku
│   │   │                         sovereign@1  japan       1889-11-29 — 1947-05-02
│   │   └── 1.1.1.#2. Deutsches Kaiserreich / II. Reich
│   │                             sovereign@2  germany     1871-01-18 — 1918-11-09
│   └── 1.1.2. Königreich         name_form@5  kingdom
│       └── 1.1.2.#1. Regno d’Italia / Königreich Italien
│                                 sovereign@3  italy       … — 1946-06-18
└── 1.2. Republik                 name_form@6  republic
    ├── 1.2.#1. Deutsches Reich (Weimarer Republik)*
    │                             sovereign@2  germany     1919-02-11 — …
    └── 1.2.#2. République française (III→IV…)
                                  sovereign@4  france      …
```

\*Официальная формула часто оставалась *Deutsches Reich*; ярлык «Weimarer Republik» — привычное историографическое имя. Для seed решить: якорь `republic` vs `reich` на этот период (эскиз кладёт под `republic` для проверки ветки).

Узел `empire` в de **не показывается** (туннель на пути к `reich`).

---

## 2. Желаемое дерево: `en`

```text
1. state                          name_form@1  state
├── 1.#1. Nihon-koku              sovereign@1  japan       1947-05-03 —
├── 1.1. empire                   name_form@3  empire
│   ├── 1.1.#1. Dai-Nippon Teikoku
│   │                             sovereign@1  japan       1889-11-29 — 1947-05-02
│   ├── 1.1.#2. German Empire / Deutsches Kaiserreich
│   │                             sovereign@2  germany     1871-01-18 — 1918-11-09
│   └── 1.1.#3. Greater German Reich / Großdeutsches Reich
│                                 sovereign@2  germany     … — 1945-05-08
├── 1.2. kingdom                  name_form@5  kingdom
│   └── 1.2.#1. Kingdom of Italy  sovereign@3  italy       … — 1946-06-18
└── 1.3. republic                 name_form@6  republic
    ├── 1.3.#1. Weimar German Reich*
    │                             sovereign@2  germany     1919-02-11 — …
    └── 1.3.#2. French Republic (III→IV…)
                                  sovereign@4  france      …
```

**Исправление относительно исходного txt:** под `empire` был ошибочно повторён *Nihon-koku* (1947). Под `empire` — **Dai-Nippon Teikoku** (период империи); послевоенное *Nihon-koku* только под `state`.

Узлы `reich` / `kaiserreich` в en **не показываются**; их периоды поднимаются под `empire` (свёртка / туннели).

---

## 3. Смысловые рёбра и метки языков

Одно ребро между `name_form` — **один раз**. Языки — метки явного шага UI (`name_form_edge_label`). Ребро без метки L при обходе L — **туннель**.

| # | parent → child | Явные метки | Замечание |
|---|----------------|-------------|-----------|
| 1 | `state` → `empire` | en | Полка empire для en |
| 2 | `empire` → `reich` | de | `reich` уже `empire`; **без** отдельного `state → reich`. Для de даёт `Staat → Reich` через туннель `state→empire` |
| 3 | `reich` → `kaiserreich` | de | Немецкий этаж Kaiserreich |
| 4 | `reich` → `kingdom` | de | Königreich под Reich в de-UI |
| 5 | `state` → `kingdom` | en | Короткий путь для en (не через reich) |
| 6 | `state` → `republic` | en, de | Общая ветка республик |

Отдельного ребра `state → reich` **нет** — см. [README §4.3](README.md).

---

## 4. Обстоятельства (требования к UI)

1. Англичанам не вводить в дерево сущности `reich` / `kaiserreich`.  
2. Немцам сохранить привычную лестницу `Staat → Reich → Kaiserreich | Königreich`.  
3. На смысловом уровне `reich` уже, чем `empire` (ребро #2).

---

## 5. Свёртка и выбор пути (резюме алгоритма)

Исходный вопрос txt: *как свёртывать reich/kaiserreich в empire, не храня collapse на ребре?*

Ответ (зафиксирован в README):

1. Ребро создаётся один раз; к нему присоединяются языки-метки.  
2. Нет метки L на ребре → туннель: узел-потомок может не рисоваться, обход вниз продолжается (к детям и к периодам суверенов).  
3. Лист периода якорится к своему `name_form` и вешается на **ближайшего показанного предка** в L.  
4. Несколько путей (напр. к `kingdom`) → меньше туннелей, затем короче путь → для en рисуем `#5` (`state → kingdom`), не ветку через `reich`.

Пример для en по цепочке `state → empire → reich → kaiserreich` и периоду Dai-Nippon на `kaiserreich`: явен только вход в `empire` → Kaiserreich/Reich скрыты → лист под `empire`.

Пример для de по той же цепочке и периоду Großdeutsch на `reich`: `empire` скрыт туннелем, явен вход в `reich` → лист под `Reich`.

---

## 6. Якоря периодов (чтобы деревья выше сошлись)

| sovereign | name_form | зачем |
|-----------|-----------|--------|
| japan, до 1947-05-02 | `kaiserreich` | de: под Kaiserreich; en: свёртка под empire |
| japan, с 1947-05-03 | `state` | оба языка: лист под state/Staat |
| germany, 1871–1918 | `kaiserreich` | аналогично |
| germany, NS / Großdeutsch | `reich` | de: под Reich; en: под empire |
| germany, Weimar (если ветка republic) | `republic` | проверка ветки; иначе оставить `reich` |
| italy, королевство | `kingdom` | de: под Königreich; en: под kingdom |
| france | `republic` | оба языка |

Полные строки имён (Dai-Nippon Teikoku vs Nihon-koku) — атрибуты периода/суверена, не `name_form_label`.
