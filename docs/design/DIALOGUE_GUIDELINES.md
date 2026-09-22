# AFTER YOU — Dialogue Guidelines

Версия: 1.0 (Phase 0, креативный дизайн).

> Правила **написания** диалогов (все персонажи, echo, записки,
> UI-тексты). Канон: **никаких exposition dumps** — «даём загадки,
> одну идею за взаимодействие» (GDD §7; ТЗ). Каждый текст проходит
> **quality bar (3 вопроса)** (GDD §13): интересно? в тему? тянет
> узнать больше? — «нет» на все три → вырезать.

## 1. Универсальные правила (все тексты)

1. **1 идея за взаимодействие** (GDD §7): 1 диалог = 1 факт/1
   «дверь». Не «3 факта». (MYSTERY_REVEAL_MAP §4.3.)
2. **1–3 реплики** за взаимодействие (GDD §6.8: «2–4 диалоговых
   дерева» — дерева, не «простыни»). Исключение: Child (1 реплика).
3. **No exposition dumps** (GDD §7): никто не объясняет мир. Никто
   не говорит «в Veyra...», «цикл — это...», «Echo создаются...».
   Даётся **наблюдение** (видел/услышал/заметил), не «теория».
4. **Сухой юмор — ≤1 на 5 взаимодействий** (GDD §2/ТЗ): всегда «в
   характере» (Orren — самый частый; Child — 1 за всю игру).
   Юмор — не «relief», а «характер».
5. **Ambiguity-правило (GDD §7):** игра **никогда не отвечает**
   «запись или живой». Каждая реплика — «дверь», не «ответ».
6. **Коротко:** 1 реплика ≤ 12 слов (EN); ≤ 20 слов (исключение:
   The First pre-boss, Archivist — «монументальные»).
7. **Без «player-адресации»:** NPC не говорят «игрок», «вы, герой»,
   «вы, выбранный». Говорят «вы» (как «человеку», не «герою»).
8. **Без «meta»:** никто не говорит «забег», «смерть-респаун»,
   «roguelite». (Слово «Run» — только в UI («RUN 02»), не в
   диалогах: NPC говорят «в этот раз», «после того как», «опять».)
9. **EN primary** (GDD §11: «EN primary», RU — data-only post-MVP).
   Все тексты — data (`.tres`/`.json`), не «hardcoded» в сценах.
10. **Data-формат реплики** (DIALOGUE_DATA):
    ```
    line: { id: "mar_a01", char: "mara", text: "You've been walking
      a long time. Eat something.", tree: "mara_camp", node: 0,
      trust_req: 0, run_req: 1, flag_req: [], flag_set: [],
      cooldown_runs: 1, humor: false }
    ```
    - `id`: `char_серия_номер` (uniqueness, QA).
    - `run_req`: минимум RUN (1/2/3/5/...); `flag_req`: флаги
      (WORLD_STATE_DESIGN §2); `flag_set`: что ставит (0–1).
    - `cooldown_runs`: не повторять N забегов (anti-repetition).
    - `humor`: true — «юмор» (≤1/5, GDD §2).

## 2. «Как говорить» per персонаж (voice-профили)

### 2.1 Eli (игрок, одноречие)
- **Правило:** 5 слов или меньше (GDD §1.3); пул ~25 (DIALOGUE_DATA
  §6). Триггер-данные (event → line_id, cooldown).
- **Тон:** наблюдательный, «здесь и сейчас», иногда саркастичный.
- **Нельзя:** комментировать сюжет, цитировать лор, «meta» («я
  умираю снова» — **нет**; «again?» — **да**, 1 раз).
- **Пул (примеры, 25):** см. CHARACTER_BIBLE §1.3.

### 2.2 Mara (хаб, «дом»)
- **Тон:** тёплый, без наивности; «мелочи» (кетл, дрова, чай).
- **Глаголы:** готовить, чинить, оставлять (не «спрашивать»).
- **Секрет:** «знает больше» (RUN 03+: *«You look different this
  time.»*) — но **не объясняет**.
- **Смерть:** последняя реплика (от Nia): *«She's in the book now.
  Page four.»* (CHARACTER_BIBLE §2.)

### 2.3 Orren (watchtower, «счёт»)
- **Тон:** лаконичный, ироничный, **усталый**; самый частый сухой
  юмор (≤1/5).
- **Глаголы:** считать (следы, дни), смотреть, молчать.
- **Секрет:** знает о Run-ах (RUN 05+: *«The tall one in the mine.
  ...don't be kind to it. Be quick.»*).
- **Пост-boss:** уходит (башня пуста, записка: *«I'm going down. For
  once.»*).

### 2.4 Nia (деревня, «книги»)
- **Тон:** тихая, уклончивая, **внимательная**; задаёт вопросы,
  которые игрок не может ответить.
- **Глаголы:** писать, читать, «хранить» (не «спрашивать»).
- **Секрет:** ведёт книги о «тех, кого никто не помнит» (seed
  Archivist: «архив в миниатюре»).
- **Ключевой:** RUN 03 (K4): *«...I was worried you wouldn't find
  it. It's on the third shelf.»*

### 2.5 The Child (роуминг, «буквальный»)
- **Тон:** детски-**буквальный**; ни злой, ни добрый; говорит
  сложное простыми словами. **1 реплика** за encounter.
- **Глаголы:** считать (*«I counted.»*), замечать (*«You're slower
  than the others.»*).
- **Секрет:** «голос системы» (M3.4: «память, которая умеет
  говорить» — reveal Act IV, post-MVP).
- **Неуязвим** (CHARACTER_BIBLE §5): на удар — 1 реплика: *«It
  doesn't hurt anymore. I've been hit more times than that.»*
  (`child_hit` → реже spawn).

### 2.6 The Cartographer (мост, «данные»)
- **Тон:** увлечённый, точный, слегка одержимый; **единственный,
  кто называет вещи как есть** (*«This forest is a mistake that
  learned to draw itself.»*).
- **Глаголы:** рисовать, измерять, «помечать».
- **Секрет:** карты «из будущего» (*«I drew the city yesterday. I
  haven't been there yet. (pause) ...yet.»*).
- **Пост-boss:** исчезает (доска: *«The gate is a door. Doors open
  both ways. I'm going through. — C.»*).

### 2.7 The Archivist (антагонист; MVP — присутствие)
- **Тон:** «монументальный» (исключение ≤ 20 слов); **никогда не
  объясняет**; всегда «уже знала».
- **MVP-реплики (5, seedy)** (CHARACTER_BIBLE §7):
  1. *(шёпот, shrine)*: *«Nothing should ever truly disappear.»*
  2. *(шёпот, при первом Echo)*: *«He is kept. He is counted.»*
  3. *(отражение, RUN 05)*: *«You call it death because you cannot
     remember.»*
  4. *(за вратами, post-boss)*: *«Welcome back, two-one-seven. I
     saved your seat.»*
  5. *(шёпот, если игрок убивает NPC)*: *«Remembered. Kept. Always.»*
- **Поведение-правила:** никогда не атакует (MVP); никогда не
  объясняет; всегда «уже знала»; присутствие = audio-слой (reverb +
  distant voices) + цвет (monochrome + accent, WORLD_BIBLE §1.1).
- **Тема:** «память, которая не умеет отпускать» (не злодей).

### 2.8 The First (boss, «уставший вы»)
- **Тон:** не злой — **уставший и решительный**; «милосердие» (закон-
  чить цикл). 10 реплик (CHARACTER_BIBLE §8).
- **Глаголы:** учить (*«I taught you, in a way.»*), видеть (*«You
  fight like me.»*), просить (*«Tell her I said: let them go.»*).
- **Секрет:** думает, что он «мёртв и вернулся» (его ошибка =
  драматургия; reveal Act III, post-MVP).

### 2.9 Echo (Remnant/Passive/Memory/Forgotten/False)
- **Remnant:** 1–3 реплики (ECHO_SYSTEM_DESIGN §3); **копирует стиль
  игрока** (slayer → злее; runner → спокойнее; explorer →
  молчаливее). Первая (#1): *«You're early.»* — пауза — *«You usually
  take longer.»*
- **Passive:** 0 (не говорит).
- **Memory:** 1–2 («от мира», scripted).
- **Forgotten:** шёпот (ваши фразы, ENEMY_DESIGN §5.2) + *«...where
  ...?»*.
- **False:** 0 (mirror-ahead, не говорит).

## 3. Диалоговые деревья (структура, data)

- **2–4 дерева per NPC** (GDD §6.8):
  - `X_camp/village/tower/bridge` (база, 1 зона);
  - `X_trust1` (trust≥1, 3–5 узлов);
  - `X_trust2` (trust≥2, 2–3 узла, «дверь»);
  - `X_postboss` (post-boss, 1–2 узла).
- **Узел дерева:** 1 реплика (+ optional: 2 варианта ответа →
  different node; **не «выбор из 5»** — max 2).
- **Условия узла:** `trust_req`, `run_req`, `flag_req`,
  `cooldown_runs` (DIALOGUE_DATA §1.10).
- **Конец дерева:** «тишина» (NPC «отводит взгляд» — visual, 1 с) —
  не «[end]». (Ambiguity: «молчание = ответ».)

## 4. Записки (notes) — правила

- **1–3 предложения** (GDD §7: environmental storytelling).
- **Почерк:** «ваш» (Eli) — data: `note_author: "eli"` (визуал:
  тот же font, «нажим» (GDD: «you press harder» — Child-реплика)).
- **5-line pool (player notes):** WORLD_STATE_DESIGN §4 (no free
  text; 5 «дверей»).
- **World-placed (4):** FIRST_30_MINUTES §1 (A7, A14, A15, A17).
- **Подножие gate (3):** «предыдущие версии» (разные «почерка» —
  M4.1; data: `note_author: "eli_prev_N"`).
- **Правило:** записка = **«дверь»**, не «лор» (не объясняет;
  «предупреждает», «запоминает», «спрашивает»).

## 5. UI-тексты (кратко)

- **«Что изменилось»** (WORLD_STATE_DESIGN §9.2): 1 строка = 1
  flag; **no numbers**; «мировой» тон (не «системный»: не «Дверь
  открыта. [OK]» — «Дверь в лесу открылась.»).
- **Inheritance-карточки** (PROGRESSION_DESIGN §0): 1 строка,
  «что делает» (не «+15%»: *«Выпад бьёт глубже.»*).
- **RUN-счётчик:** «RUN 01» (EN, uppercase, letter-spacing) —
  «мир-шрифт» (не «игровой» (GDD §10: stylized)).

## 6. Data-формат (DIALOGUE_DATA)

- **Файлы:** `data/dialogue/*.tres` (per NPC) + `data/dialogue/
  lines_eli.tres` (пул) + `data/dialogue/echo_lines.tres` +
  `data/note_lines.tres`.
- **Schema** (DIALOGUE_DATA §1.10): `line { id, char, text, tree,
  node, trust_req, run_req, flag_req, flag_set, cooldown_runs,
  humor }`.
- **Уникальность:** `id` unique (QA-тест: 0 дубликатов, TEST_PLAN).
- **Локализация:** EN primary; RU — data-only (post-MVP, GDD §11:
  «EN primary»). (Data-driven: смена языка = смена data.)

## 7. Чек-лист на реплику (pre-commit)

1. ≤ 12 слов? (исключения: The First pre-boss, Archivist.)
2. 1 идея (не 3 факта)?
3. «Дверь» (вопрос/наблюдение), не «ответ» (объяснение)?
4. «В характере» (voice-профиль §2)?
5. Не «meta» (без «run», «roguelite», «игрок»)?
6. Ambiguity сохранена (не «запись/живой»)?
7. Quality bar: интересно / в тему / тянет узнать больше?
8. (Если юмор) ≤1/5 в дереве?
9. Data-формат (id, flags, cooldown) — заполнен?

**Ответ «нет» на 1–7 → переписать.** (GDD §13.)

## 8. Связи с системами
- **CHARACTER_BIBLE** — voice-профили, ключевые реплики (12 per NPC).
- **MYSTERY_REVEAL_MAP** — кто «носит» какой beat (§1–§2).
- **WORLD_STATE_DESIGN** — flags (`flag_req`, `flag_set`), notes.
- **ECHO_SYSTEM_DESIGN** — Echo-реплики (ambiguity).
- **TECHNICAL_DESIGN** — data-driven (Resources), no hardcoded.
- **TEST_PLAN** — QA-тесты (уникальность id, cooldown, flags).

## 9. Open questions (dialogue)
- Q-D1: «1–3 реплики» — не «слишком мало» (глубина)? (Митигция:
  «глубина» = trust-уровни (0–2) + post-boss (не «объём»). Решение:
  ок — «1 идея».)
- Q-D2: «EN primary» — не «исключает» RU? (Митигция: data-only RU
  (post-MVP) = «локализация без переписывания» (GDD §11). Решение:
  ок — «EN primary».)
- Q-D3: «Child — 1 реплика» — не «слишком пусто»? (Митигция:
  «буквальный» = «мало слов, много смысла» (CHARACTER_BIBLE §5).
  Решение: ок — «характер».)
