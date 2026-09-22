# AFTER YOU — Echo System Design

Версия: 1.0 (Phase 0, креативный дизайн).

> Ядро игры (GDD §6): **мир помнит предыдущие забеги игрока**.
> Echo — не «видео», а **событийная реконструкция** (TECHNICAL_
> DESIGN.md: RunEvent, 14 bytes, int32 t, ≤4096/run). 5 типов
> Echo: Passive / Combat / Memory / Corrupted / False.
>
> **Ambiguity-правило (главное):** игра **никогда не говорит**,
> «запись это или живой» (GDD §7, NARRATIVE_STRUCTURE §3 твист 1).
> Игрок сам решает. (Это — основа твиста 1: «все — настоящие».)

## 0. Технические основы (TECHNICAL_DESIGN.md)

- **RunEvent:** 14 bytes: `t (int32, ms)`, `id (u16)`, `type (u8)`,
  `x/y/z (float × 3)`, `action (u8)`, `pad (u8)`. (RunEvent t
  int16→int32 — commit, 60-мин exploration runs.)
- **Запись:** event-based (не per-frame video). События: move,
  attack, hit, death, pickup, note, interact, echo_trigger. (≤4096/run.)
- **Хранение:** `WorldState.runs[]` (WORLD_STATE_DESIGN §2): каждый
  run = 1 entry (run_id, start_t, end_t, events[], summary).
- **Reconstruction:** echo-сущность = «проигрыватель» RunEvent
  (ECHO §1: Passive) / «интерпретатор» (ECHO §3: Combat). (Не
  full world simulation — ADR-002, GDD §7.)
- **Budget (MVP):** 1 Passive + 1 Combat + 1 «специальный»
  (Memory|Forgotten|False) = max 3 per run (GDD §15 Q5: «не каждый
  Run создаёт полный Echo»). (Data-driven.)

## 1. PASSIVE ECHO (ghost replay, «тень»)

### 1.1 Концепт
«Тень» — **replay** предыдущего забега игрока. Не «живой» (не
реагирует на игрока, не говорит, не атакует). «Проигрывает» свой
путь (RunEvent reconstruction). **Видимый** (50% opacity, «дымчатый»).

### 1.2 Механика
- **Spawn:** «путь игрока» (RunEvent: last run's path). Spawn:
  «где игрок был» (positions). **1 per run** (budget).
- **Behavior:** replay (не «AI» — «проигрывание»). Не атакует,
  не говорит. Если игрок «пересекает» → «просвечивает» (no
  interaction, no damage).
- **Visual:** 50% opacity, «дымчатый» (серо-голубой). **Следы**
  (footprints, «прошедшие»).
- **Audio:** тихие шаги (replay), «шёпот» (distant).
- **Death:** нет (не «умирает» — «рассеивается» (fade, 3 с),
  если игрок «догоняет» (distance > 20 м) или «завершает» replay
  (run-end).

### 1.3 Связь с mystery
- «след» (после первого Hollow — A5): виден в RUN 02. (Mystery 2, stage 1.)
- M3: «кто создаёт Echo» — seed: «он идёт по моему пути».

### 1.4 Data
```
passive_echo: { opacity: 0.5, replay: true, attack: false,
  speech: 0, fade_dist: 20m, fade_time: 3s, budget: 1/run }
```

## 2. MEMORY ECHO (scripted reconstruction, «память места»)

### 2.1 Концепт
**Scripted** (не «из run data» — «нарративный»). «Память места»
(зона «помнит» событие). 1 per run (budget). **Видимый** (80%
opacity, «ярче» Passive). **Говорит** (1–2 реплики, «от мира»).

### 2.2 Механика
- **Spawn:** scripted (WORLD_STATE: `memory_echo_X_triggered`).
  1 per run (budget). (Местоположения: shrine (зеркальный круг),
  lake (reflection), undercroft (pre-boss).)
- **Behavior:** replay (scripted, «нарративный»). Не атакует.
  Говорит (1–2 реплики).
- **Visual:** 80% opacity, «ярче» (холодный белый).
- **Audio:** «шёпот» + 1–2 реплики (NARRATIVE).
- **Death:** fade (3 с), после replay (run-end или «завершение»
  script).

### 2.3 Связь с mystery
- K5: «отражение» (lake, RUN 05: Archivist). (Mystery 3, stage 3.)
- Shrine: «зеркальный круг» (scripted memory echo). (M3.)

### 2.4 Data
```
memory_echo: { opacity: 0.8, replay: true (scripted), attack: false,
  speech: 1-2, fade_time: 3s, budget: 1/run, scripted_locations:
  [shrine_mirror, lake_reflection, undercroft_preboss] }
```

## 3. COMBAT ECHO — REMNANT (из run data, «версия»)

### 3.1 Концепт
**Combat Echo** = **Remnant** (ENEMY_DESIGN §2). «Собранный» из
данных забега (run data). **Живой** (реагирует, атакует, говорит).
**Видимый** (100% opacity, «тот же», что игрок, но «выцветший»).

### 3.2 Механика
- **Spawn:** «где игрок был» (WORLD_STATE: run_data, last N
  positions). **1 per run (MVP)** (budget; post-MVP: ≤2). (Не
  «случайный» — «там, где ты был».)
- **Behavior:** **копирует стиль игрока** (memory_stats: slayer →
  «бьёт как игрок»; runner → «уходит и бьёт издалека»). (ENEMY_
  DESIGN §2: mirror/false.)
- **Combat:** использует **оружие игрока** (WEAPON_DESIGN: mirror).
  Dmg 20 (base).
- **Speech:** 1–3 реплики (первая: *«You're early.»* / *«You usually
  take longer.»* — #1).
- **Death:** dissolve + **записка** (note: 1 строка, «от Remnant»).
  (Mystery: «он знал, что я приду».)

### 3.3 Агрессия и memory_stats
- **Slayer:** Remnant «злее» (speed +10%, «бьёт как игрок»).
- **Runner:** Remnant «спокойнее» (speed -10%, «уходит»).
- **Explorer:** Remnant «молчаливее» (speech 0, «не говорит»).
  (ENEMY_DESIGN §7, WORLD_STATE_DESIGN §4.)

### 3.4 Связь с mystery
- #1: первый Echo («You're early.» — и уходит). (Mystery 3, stage 2.)
- M1: «он — я» (seed: «копия стиля»).

### 3.5 Data
```
remnant_mirror: { opacity: 1.0, style: player_style, weapon:
  player_weapon, speech: 1-3, note_on_death: true, budget: 1/run (MVP) }
remnant_false:  { opacity: 1.0, style: random, weapon: random,
  speech: 0, note_on_death: false, budget: ≤1/run («специальный») }
```

## 4. CORRUPTED ECHO — FORGOTTEN («забытый»)

### 4.1 Концепт
**Corrupted Echo** = **Forgotten** (ENEMY_DESIGN §5). «Бывший игрок»
(прошлая версия Eli), но «забыл себя». **Живой** (реагирует, бьёт,
«не понимает»). **Видимый** (100% opacity, «белый», «треснувший»).

### 4.2 Механика
- **Spawn:** «старые» зоны (village, shrine, lake, mine, undercroft).
  **≤1 per run («специальный»)**. (WORLD_STATE:
  `forgotten_X_spawn`.)
- **Behavior:** wander (random path), «бьёт» (если рядом). 1 реплика:
  *«...where...?»* (ENEMY_DESIGN §5).
- **Combat:** «мах» (1 с telegraph, 35 dmg, 3 с CD). (Элитный.)
- **Death:** dissolve (3 с) + **fragment** (mystery fragment, 1 строка).
  (Mystery: «он был мной?»)

### 4.3 Связь с mystery
- M1: «он был мной?» (seed).
- M4: «забытые — «остатки»» (seed: Act III, «оставшиеся»).

### 4.4 Data
```
forgotten: { opacity: 1.0, wander: true, attack: true (35 dmg, 3s),
  speech: 1, fragment_on_death: true, budget: ≤1/run («специальный») }
```

## 5. FALSE ECHO (mirror fight, «ложное зеркало» — GDD §6.6)

### 5.1 Концепт
**False Echo** = «ложное зеркало» (GDD §6.6: «похож на вас, ведёт
себя иначе — зеркальный бой»). Не «копия прошлого» (это Remnant),
а **«копия будущего»**: он **повторяет ваше движение на 1 beat
раньше** (0.5 с): вы «думаете» про уворот — он **уже в увороте**;
вы «разгоняетесь» про удар — его **telegraph уже виден** (ваш
будущий удар, «показанный заранее»). **Зеркальный бой-головоломка**:
вы **должны сбиться с паттерна** (сделать «не ваш» ход), чтобы
«сломать» его предсказание. Не говорит. Не «слабый» — «непред-
сказуемый для вас» (15 dmg, 60% speed, но **читает ваш паттерн**).

### 5.2 Механика
- **Spawn:** «старые» зоны (village, bridge). **≤1 per run
  («специальный»)**. (WORLD_STATE: `false_echo_X_spawn`.)
- **Behavior:** **mirror-ahead** (0.5 с): **за 0.5 с «показывает»
  телеграф вашего самого вероятного следующего движения** (прогноз
  от dominant_style + последние 3 хода, data: `false_predict: 3` —
  **не читает ум, читает привычку** — как Mimic, ENEMY_DESIGN §4).
  Weapon: ваше (mirror). Speech: 0.
- **Combat:** 15 dmg, 60% speed. **Слом:** 3 «не-ваших» хода
  подряд (отличный от dominant_style) → False Echo **«ломается»**
  (stun 2 с, уязвимость: +50% dmg). (Геймплей: «сбей свой паттерн».)
- **Death:** dissolve (no note, no fragment).

### 5.3 Связь с mystery
- **Ambiguity:** «запись» vs «живой» (не говорит, но «знает» ваш
  следующий ход — «запись будущего?»). (GDD §7: игра не говорит.)
- M3: «кто создаёт Echo» — seed: «он знает, что я **сделаю**»
  (не «что я делал» — Remnant) — «запись будущего?».

### 5.4 Data
```
false_echo: { opacity: 1.0, style: player_dominant (mirror-ahead 0.5s),
  weapon: player_weapon, speech: 0, note_on_death: false,
  break_window: 3 (не-ваших хода), stun: 2.0s, dmg_bonus: 0.5,
  budget: ≤1/run («специальный») }
```

## 6. Ambiguity-правило (главное, GDD §7)

> Игра **никогда не говорит**, «запись это или живой».

- **Passive:** «не говорит, не атакует» → «запись?» (но «следы» —
  «живой?»).
- **Memory:** «говорит» → «живой?» (но «scripted» — «запись?»).
- **Combat (Remnant):** «говорит, атакует, «знает»» → «живой?» (но
  «копия стиля» — «запись?»).
- **Corrupted (Forgotten):** «бьёт, «не понимает»» → «живой?» (но
  «забытый» — «запись?»).
- **False:** «не говорит, но «знает» ваш следующий ход» → «запись
  будущего?» (но «бьёт» — «живой?»).
- **Правило:** каждая реплика/действие — **1 «дверь»** (riddle),
  не «ответ». (NARRATIVE_STRUCTURE §7.)
- **Твист 1:** «все — настоящие» (Act II, Archivist). (NARRATIVE_
  STRUCTURE §3.)

## 7. Budget (per run, GDD §15 Q5)

| Тип | Budget (per run, MVP) | Spawn-правило |
|---|---|---|
| Passive | 1 | «путь игрока» (last run) |
| Combat (Remnant mirror) | 1 | «где игрок был» (run_data) |
| Memory | ≤1 («специальный») | scripted (shrine/lake/undercroft) **или** Watcher anchor |
| Corrupted (Forgotten) | ≤1 («специальный») | «старые» зоны |
| False | ≤1 («специальный») | «старые» зоны |

**Итого MVP: 1 Passive + 1 Combat + 1 «специальный» (Memory|Forgotten|
False) = max 3 per run** (GDD §15 Q5: «не каждый Run создаёт полный
Echo»; Q-EC2: MVP — 3, post-MVP — 5). Data-driven
(`data/echo_budget.tres`).

## 8. «Не каждый Run создаёт полный Echo» (GDD §15 Q5)

- **RUN 1:** 0 Echo (первый забег, «нет прошлого»). (Scripted:
  A1–A19, no Echo.)
- **RUN 02:** 1 Combat (#1: «You're early.» — и уходит) + 1 Passive
  (path replay, C1). (2 Echo.)
- **RUN 04+:** MVP budget (max 3: Passive + Combat + 1 «специальный»). (Data: `echo_budget.tres`.)
- **Post-boss:** Echo «тише» (WORLD_STATE_DESIGN §6: transform).
  (Passive 0, Memory 0, Remnant 1, Forgotten 1. Budget -2.)

## 9. Связи с системами
- **WORLD_STATE_DESIGN** — run_data (RunEvent), budget, spawn-правила,
  transform (post-boss).
- **ENEMY_DESIGN** — Remnant (Combat), Forgotten (Corrupted),
  Watcher (Passive seed).
- **WEAPON_DESIGN** — Remnant (оружие игрока), Echo Staff (Read/
  Disrupt/Soothe/Shatter vs Echo).
- **NARRATIVE_STRUCTURE** — ambiguity-правило, твист 1, #1/K5.
- **MYSTERY_REVEAL_MAP** — M3 (кто создаёт Echo).

## 10. Open questions (echo)
- Q-EC1: «Ambiguity-правило» — не «слишком сложно» ли для игрока?
  (Митигция: «1 дверь на взаимодействие» (NARRATIVE §7). Игрок не
  «должен понять» — «должен почувствовать». Решение: да, сложно —
  это «ядро».)
- Q-EC2: Budget «1+2+1+1» — не «слишком много» ли Echo per run?
  (Митигция: «не каждый» — RUN 1: 0, RUN 2: 2. Data-driven, легко
  «уменьшить» (MVP: 1+1+1 = 3). Решение: MVP — 3, post-MVP — 5.)
- Q-EC3: Passive «не говорит» — не «пусто» ли? (Митигция: «следы» +
  «шёпот» (audio) = «atmosphere». ENV_STORYTELLING §3.)
