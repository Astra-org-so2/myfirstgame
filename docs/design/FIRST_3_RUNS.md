# AFTER YOU — First 3 Runs (детальный план)

Версия: 1.1 (Phase 0, креативный дизайн).

> Первые 3 забега — «учебник мира» (без туториала). Каждый забег =
> 1 «акт понимания»: RUN 1 — «мир помнит», RUN 02 — «мир открыл
> дверь», RUN 03 — «мир знает моё имя». (NARRATIVE_STRUCTURE §1:
> Act I = RUN 1 → RUN 05+ → boss.)
>
> **Окно, не таймер** (GDD §8): все «времена» — ориентир, не
> скрипт. Игрок управляет темпом (player-driven триггеры).
> camp = sanctuary (GDD §8: respawn-зона, «дом»).
>
> ARC (GDD §8): Run 1 «обычное приключение» → Run 2 «something
> changed» → Run 3 «the game remembers me» → Run 4+ «I can
> manipulate the system» → позже «the system is manipulating me».

## 0. Сводка (3 забега, ~48–62 мин первого прохода)

| Забег | Длительность | Формула понимания | Новые системы | Signature (канон) | Mystery stages |
|---|---|---|---|---|---|
| RUN 1 | 18–22 мин | «Мир помнит. Я не первый.» | blade, notes, Mara, gate (запечатан) | #2, #3, K1, K2, K3 | M1.1, M2.1, M3 seed, M4 seed |
| RUN 02 | 15–20 мин | «Мир открыл дверь. Оружие ждало.» | cannon, staff, Combat Echo, gate (открыт) | #1, #3, #4 | M2.2, M3.2, M1.2 (seed) |
| RUN 03 | 15–20 мин | «Мир знает моё имя. И тело.» | Inheritance #2, Nia trust (K4), мумия (#5), Echo-решение (#6) | #5, #6, K4 | M1.3, M3.3, M4.1 |

**Итого: ~48–62 мин** (первый проход, до босса). Boss — RUN 04–07
(событийное условие, §4). Post-boss — K7 (врата светят) → RUN 08+
(MVP-конец).

## 1. RUN 1 — «Мир помнит» (18–22 мин)

> Детали якорей — FIRST_30_MINUTES §1 (A1–A19).

### 1.1 Что происходит (кратко)
1. **A1–A3 (0:00–0:45):** пробуждение → pillar (K3: «YOU HAVE BEEN
   HERE BEFORE.», A2) → blade (K1: «рука сама», A3).
2. **A4–A5 (1:00–1:30):** first steps → first Hollow (рывок с windup;
   убит → оставляет след, виден в RUN 02).
3. **A6–A9 (2:00–3:30):** camp (Mara) → note stand (#2: *«If you find
   this, don't trust the version of me that comes after.»*) → trust
   0→1 старт → выход.
4. **A10–A17 (4:00–9:00):** figure «как Eli» (A10, следы → деревня) →
   Nia (#3: *«You already asked me that.»*) → pyre + Watcher (A12,
   anchor) → serious combat → mine (cannon ждёт, note) → shrine
   (staff ждёт, шёпот) → sealed gate («YOU WILL OPEN THIS AFTER YOU
   DIE.», записки «предыдущих») → lake (note: «don't go to the lake
   before the mine»).
5. **A18 (12:00):** free exploration (8 зон; Mimic, Forgotten).
6. **A19 (~20 мин):** first death (K2: *«Again?»*) → 3 карточки
   Inheritance → выбор. (`last_death_pos` записан → #5 в RUN 03.)

### 1.2 Что игрок понимает (конец RUN 1)
- «Мир помнит» (столб, записки, «You already asked me that»).
- «Я не первый» (pillar, записки, sealed gate).
- «У меня есть дом» (camp, Mara, note stand).
- «Оружие ждёт» (cannon, staff — «не дать», а «оставить»).
- «Дверь ждёт смерти» (gate: «YOU WILL OPEN THIS AFTER YOU DIE.»).
- **Не понимает (seeds):** кто создаёт Echo, почему «сотни раз»,
  кто Eli (M1.2–M4).

### 1.3 WORLD_STATE (конец RUN 1)
```
flags: { blade_found: true, mine_note_read: true (опц.),
  village_pyre_seen: true (опц.), watcher_anchor_1: pos (опц.),
  run_02_door_open: true (после A19), last_death_pos: pos }
memory: { kills: 3–8, fled: 0–2, explored: 30–60%, notes_written: 1,
  deaths: 1, runs_completed: 1, dominant_style: (начальная) }
npcs: { mara: { trust: 1 (опц.), interactions: 2 } }
inheritances: { 1 (выбор из 3) }
```

## 2. RUN 02 — «Мир открыл дверь» (15–20 мин)

> Детали якорей B1–B6 — FIRST_30_MINUTES §2.

### 2.1 Что происходит (кратко)
1. **B1 (0:00):** respawn. Mara: *«You left a kettle last time. I
   washed it.»* (#3, 2-я ипостась: «мелочи»).
2. **B2 (1:00):** **gate открыт** (`run_02_door_open`). UI: «Что
   изменилось» (#4 «Изменившееся место»). Eli: *«That wasn't there.»*
3. **B3 (3:00):** cannon (pickup, `cannon_found`). Note уже «ваш»
   (прочитан в RUN 1 — world-scoped открытие, GDD §6.5).
4. **B4 (5:00):** **первый Echo (#1):** копия игрока (Remnant,
   mirror) «на вашем пути» (RUN 1 path). *«You're early.»* — пауза —
   *«You usually take longer.»* — **и уходит** (не бой). (GDD §8.)
5. **C1 (8:00):** **Passive Echo** (ghost replay «путь RUN 1»):
   «идёт по моему пути» (не говорит, не атакует). (M3.1: «запись
   или живой?»)
6. **C2 (10:00):** **gate — взгляд за врата** (city silhouette,
   faint, 2 с, не «вход» — «вид»). (WORLD_BIBLE §4.8: «город виден
   post-boss» — RUN 02: «faint glimpse» (seed K7).)
7. **C3 (12:00):** 2nd death (Hollow big / Forgotten): **тишина**
   (no *«Again?»* — K2: «однажды — и больше не повторять»).
   Inheritance #2 (1 из 3).

### 2.2 Что игрок понимает (конец RUN 02)
- «Мир открыл дверь» (gate: «после остановки»).
- «Оружие ждало» (cannon: «It's heavy. Use it once.»).
- «Копия говорит» (#1: *«You're early.»* — «он знает, что я
  прихожу»).
- «Тень идёт по моему пути» (Passive Echo: M3.1).
- «За вратами — город» (faint glimpse: K7 seed).
- **Не понимает:** почему копия говорит (M3.2–M3.4), что за город
  (M4.1–M4.4), кто Eli (M1.2–M1.4).

### 2.3 WORLD_STATE (конец RUN 02)
```
flags: { blade_found, cannon_found, staff_found (опц.),
  run_02_door_open, mine_note_read, village_pyre_seen (опц.),
  first_echo_seen: true, city_glimpse: true (2 с),
  last_death_pos: pos (обновлён) }
memory: { kills: 5–12, fled: 1–3, explored: 50–80%, notes_written: 2,
  deaths: 2, runs_completed: 2, dominant_style: (уточн.) }
npcs: { mara: { trust: 1, interactions: 3 } }
inheritances: { 2 }
echo: { passive: 1 (C1), combat: 1 (#1, B4) } (ECHO §8)
```

## 3. RUN 03 — «Мир знает моё имя. И тело.» (15–20 мин)

### 3.1 Что происходит (кратко)
1. **D1 (0:00):** respawn. Mara: *«You look different this time.»*
   (RUN 03+, CHARACTER_BIBLE §2, #4). (Первая «изменённость».)
2. **D2 (~3:00):** **#5 «Собственный труп»:** на месте `last_death_pos`
   (RUN 02 death) — **мумия Eli** (ваша, ваш пол, ваша одежда;
   «мумия», не «труп» — мир «сохранил»). Не бой — момент. Можно
   «рассмотреть» (1 с): в руке мумии — **ваша последняя записка**
   (та, что вы оставили до смерти: `notes[]` → last note, data —
   WORLD_STATE_DESIGN §4). (Mystery: «он умер там. Я — там. Это —
   я?».)
3. **D3 (~6:00):** **K4 «Свое имя в книге»:** Nia trust →
   *«...I was worried you wouldn't find it. It's on the third shelf.»*
   (CHARACTER_BIBLE §4, #4). Страница: *«Eli. Profession: —. Home: —.
   First seen: —.»* (M1.3: «жизнь до» — пусто: «не знаю».)
4. **D4 (~10:00):** **#6 «Echo принимает решение»:** Remnant (mirror)
   начинает бой — и **прерывает** (0.5 с «замирание»), идёт к note
   stand, **читает вашу записку** (2 с, head-look), говорит:
   *«...I forgot that.»* — и уходит (fade). (Мир «живой»: Echo
   «принимает решения», не «replay».) (M3.3: «он помнит моё
   решение».)
5. **D5 (~12:00):** **mine — deep** (ярус 2: полутьма, «следы»
   врагов; «большие следы» + «его фонарь» (seed The First, BOSS_DESIGN
   §2) — `first_traces_seen = true` (при ярусе 3)).
6. **D6 (~14:00):** **gate — notes** (подножие: 1 записка «новее»
   (RUN 02), 2 «старые» (RUN 1, «предыдущие»)). Игрок **сравнивает**
   (discovery: «почерк меняется» — M4.1: «не все — один человек»).
7. **D7 (~16:00):** 3rd death (Forgotten / Mimic): тишина.
   Inheritance #3 (1 из 3).

### 3.2 Что игрок понимает (конец RUN 03)
- «Мир знает моё имя» (K4: Nia's book: «Eli»).
- «У меня есть «жизнь до»» (M1.3: «Profession: —» (пусто)).
- «Я там был» (#5: мумия — «тело помнит» (тема GDD §14)).
- «Эхо принимает решения» (#6: «он помнит моё решение»).
- «Кто-то был в mine» (D5: «большие следы» + фонарь — seed The First).
- «Почерк меняется» (D6: gate notes — M4.1: «не все — один»).
- **Не понимает:** кто The First (M1.4, M3.4), что за город
  (M4.2–M4.4), почему «сотни раз» (M4.3–M4.4).

### 3.3 WORLD_STATE (конец RUN 03)
```
flags: { blade_found, cannon_found, staff_found (опц.),
  run_02_door_open, mine_note_read, village_pyre_seen (опц.),
  first_echo_seen, city_glimpse, corpse_seen: true,
  nia_name_seen: true (K4), echo_decision_seen: true (#6),
  gate_reflection_seen: false (RUN 05) }
memory: { kills: 8–18, fled: 2–5, explored: 60–90%, notes_written: 3,
  deaths: 3, runs_completed: 3, strange_actions: 1–3 }
npcs: { mara: { trust: 1–2, interactions: 4 }, nia: { trust: 1,
  interactions: 2, gifts_given: true (THE PAGE, опц.) } }
inheritances: { 3 }
echo: { passive: 2, combat: 2 } (ECHO §8)
```

## 4. RUN 04–07 — «К боссу» (кратко; детали — BOSS_DESIGN §2)

| Забег | Ключевое |
|---|---|
| RUN 04 | Orren (trust 1): *«Runners live longer. Slayers get remembered differently.»* (memory_stats: slayer/runner). Child (роуминг, 1 encounter): *«You died again. I watched. It was the third time.»* (опц.: если runner — *«You always run.»*). |
| RUN 05 | Mara: *«I'm not going to ask where you've been. Ask me what to do.»* (#5). **K5 (lake reflection):** в озере — **не отражение** (Archivist, 2 с): *«You call it death because you cannot remember.»* (`lake_reflection_seen = true`). Child: *«You're number two-one-seven. I counted. You're slower than the others.»* (M4.2) + *«Some of you stayed. They're quieter now. The trees like them best.»* (setup твиста 2, NARRATIVE_STRUCTURE §3). Cartographer (trust 1): *«I drew the city yesterday. I haven't been there yet. (pause) ...yet.»* (M4.3). **Mine — ярус 3:** The First (seed): «следы» + «его фонарь» (`first_traces_seen = true`, BOSS_DESIGN §2). |
| RUN 06+ | Boss-условие исполнено → **дверь Undercroft открывается** (следующий забег). |

**Boss-условие** (BOSS_DESIGN §2) — **событийное, не счёт забегов**
(«окно, не таймер», GDD §8):
1. `mine_level_3_explored = true` (игрок спустился в ярус 3 хотя бы раз);
2. `deaths >= 3` (мир «знает смерть игрока»);
3. `first_traces_seen = true` (RUN 05+: «следы + фонарь» The First).
→ В **следующем** забеге дверь Undercroft открывается (обычно RUN 05–07,
зависит от темпа игрока). (GDD §11: boss = «конец Act I».)

## 5. Post-boss — MVP-конец (RUN 08+)

- **K7 «Врата светят»** (первая большая трансформация, WORLD_STATE_
  DESIGN §6): туман редеет, врата светятся, город-силуэт, Echo «тише»
  (budget -2), следы «навсегда», NPC «спокойнее».
- **NPC post-boss-реплики** (CHARACTER_BIBLE §2–6): Mara
  (*«The fire is brighter. I don't like it.»*), Orren (башня пуста +
  записка *«I'm going down. For Once.»*), Nia (*«Page one. Again.
  (smiles) ...I'm glad.»*), Cartographer (доска: *«The gate is a door.
  Doors open both ways. I'm going through. — C.»*).
- **MVP-финал:** игрок стоит у врат (свет, город, тишина).
  (NARRATIVE_STRUCTURE §1: Act I завершён, Act II начинается —
  «врата открыты, город на горизонте», GDD §11.)

## 6. Правила (3 забега)

1. **Окно, не таймер** (GDD §8): все «времена» — ориентир.
2. **Camp = sanctuary** (GDD §8): respawn-зона, «дом».
3. **1 новая идея на 3–5 минут** (no exposition).
4. **Каждый забег = 1 «формула понимания»** (§0).
5. **Echo budget:** RUN 1: 0; RUN 02: 2 (#1 + Passive); RUN 03: 2
   (#6 + Passive). (ECHO §8: RUN 1: 0, RUN 02: 1+1, RUN 03+: full.)
6. **Inheritance: 1/забег** (при смерти, 1 из 3; UX ≤ 10 с).
   (PROGRESSION_DESIGN §0.)
7. **NPC trust: 0→1 (RUN 1–2), 1→2 (RUN 3+)** (PROGRESSION_DESIGN §4).
8. **Mystery stages: ~1–2/забег** (MYSTERY_REVEAL_MAP).

## 7. Связи с системами
- **FIRST_30_MINUTES** — якоря (A1–A19, B1–B6) — «детали».
- **WORLD_STATE_DESIGN** — flags, memory_stats, notes, npcs,
  inheritances (per run); «Что изменилось» (§9).
- **ECHO_SYSTEM_DESIGN** — budget per run (§8).
- **ENEMY_DESIGN** — Hollow, Watcher (anchor), Mimic, Forgotten.
- **WEAPON_DESIGN** — blade (RUN 1), cannon (RUN 02), staff (RUN 02–3).
- **PROGRESSION_DESIGN** — Inheritance (1/забег), trust (per run).
- **NARRATIVE_STRUCTURE** — #1–#7, K1–K7 (per run), M1–M4 (stages).
- **BOSS_DESIGN** — boss-условие, Undercroft.

## 8. Open questions (first 3 runs)
- Q-R1: RUN 02 «city glimpse» (C2) — не «слишком рано» (K7 —
  post-boss)? (Митигция: C2 = «faint glimpse» (2 с, seed), не «K7»
  (post-boss: «врата светят, город виден»). Data: `city_glimpse: 2 с
  (RUN 02); city_visible: true (post-boss)`. Решение: C2 = seed,
  K7 = «полный».)
- Q-R2: RUN 03 «K4 (имя в книге)» — не «слишком рано» (RUN 03)?
  (Митигция: RUN 03 = «мир знает моё имя» (формула); K4 = «пик»
  RUN 03. Data: `nia_name_min_run: 3`. Решение: RUN 03 — «пик».)
- Q-R3: #5 «мумия» — не «слишком тёмно» для RUN 03? (Митигция:
  «мумия», не «труп» (мир «сохранил» — не «разложил»); момент, не
  «хоррор» (GDD §2: «ужас — точечный»); тема «тело помнит» (GDD
  §14). Решение: RUN 03 — «пик».)
- Q-R4: Boss RUN 05–07 — не «слишком долго» (5–7 забегов)?
  (Митигция: события (не счёт): mine level 3 + deaths≥3 + traces.
  Быстрый игрок: RUN 05; осторожный: RUN 07. Data: event-based.
  Решение: окно RUN 05–07.)
