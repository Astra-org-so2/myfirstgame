# AFTER YOU — World State Design

Версия: 1.0 (Phase 0, креативный дизайн).

> **WorldState** — единственный «память»-слой мира. Хранит ВСЁ,
> что переживает забег (GDD §6: persistent WorldState). Технически —
> TECHNICAL_DESIGN.md (JSON + CRC32 + atomic write + migrations,
> versioned format). Документ описывает **данные** (что хранится),
> **правила** (как меняется) и **последствия** (что игрок видит).

## 0. Архитектура (ссылка на TECHNICAL_DESIGN)

- **Файл:** `user://save/worldstate.json` (атомарный write: tmp →
  rename, CRC32, versioned format, migrations, safe defaults).
- **Autoload:** `WorldState` (1 из 9, ADR-009). Singleton-доступ.
- **Структура:** `WorldState { version, runs[], flags{}, memory{},
  notes[], npcs{}, inheritances{}, weapons{}, echo_budget{},
  transform{} }`. (Детали — §1–7.)
- **Правило:** мир «помнит» через WorldState. Никаких «скрытых»
  систем памяти (GDD §7: no hidden systems). Всё в WorldState.

## 1. Runs (забегания, `runs[]`)

> Каждый забег = 1 entry. Хранит run data (RunEvent) + summary.

```
run_entry: {
  run_id: int (1, 2, 3, ...),
  start_t: int (ms, wall-clock),
  end_t: int (ms),
  alive: bool (died or completed),
  events: RunEvent[] (≤4096, 14 bytes each — TECHNICAL_DESIGN),
  summary: { kills: int, fled: int, notes_written: int,
             items_picked: int, deaths: int, playtime_ms: int }
}
```

- **Запись:** event-based (move, attack, hit, death, pickup, note,
  interact, echo_trigger). Не per-frame (GDD §7: «compact event
  fields, not per-frame video»).
- **Хранение:** ВСЕ runs (не «только последние N» — мир «помнит
  всех»). (MVP: ~10–15 runs, ~150 КБ (data), ок.)
- **Использование:** Passive Echo (replay: last run), Combat Echo
  (spawn: «где был»), Remnant (стиль: player_style), memory_stats
  (агрегация), NPC dialogue («сколько раз ты умер»).

## 2. Flags (мировые флаги, `flags{}`)

> Перманентные булевы/интовые флаги. «Что уже случилось».

| Флаг | Тип | Ставится (когда) | Последствие (что игрок видит) |
|---|---|---|---|
| `blade_found` | bool | RUN 1, 0:45 (K1) | blade в инвентаре (навсегда) |
| `cannon_found` | bool | Mine, ярус 1 (RUN 02+) | cannon доступен |
| `staff_found` | bool | Shrine, ниша (RUN 02–3) | staff доступен |
| `first_blade_taken` | bool | Undercroft, pre-boss | FIRST BLADE взят / не взят (BOSS_DESIGN) |
| `run_02_door_open` | bool | RUN 1 death (K2) | gate открывается (RUN 02, #4) |
| `first_echo_seen` | bool | RUN 02, #1 | Remnant-реплики «старше» (*«You usually take longer.»*) |
| `city_glimpse` | bool | RUN 02, C2 (2 с) | seed K7 (город за вратами, faint) |
| `corpse_seen` | bool | RUN 03, #5 | M1 seed (мумия: «я там был») |
| `nia_name_seen` | bool | RUN 03, K4 | M1.3 (имя в книге) |
| `echo_decision_seen` | bool | RUN 03, #6 | M3.3 (echo «принимает решение») |
| `lake_reflection_seen` | bool | Lake, RUN 05, K5 | Archivist «видел» (NPC-реплики меняются) |
| `mine_level_3_explored` | bool | Mine, ярус 3 | boss-условие (BOSS_DESIGN §2) |
| `first_traces_seen` | bool | Mine, ярус 3 (RUN 05+) | boss-условие (следы + фонарь The First) |
| `boss_defeated` | bool | The First death | **transformation** (§6, K7) |
| `npc_mara_dead` | bool | Mara death | лагерь гаснет, respawn → «мёртвое» поле |
| `npc_orren_dead` | bool | Orren death | башня пуста, следы не исчезают |
| `npc_nia_dead` | bool | Nia death | книга открыта на вашей странице |
| `npc_cartographer_dead` | bool | Cartographer death | карта указывает на несуществующее |
| `child_hit` | bool | Child hit (неуязвим — hit = data) | Child появляется реже (soft-penalty) |
| `mine_note_read` | bool | Mine, note (#2-линия) | M2 seed (dialogue) |
| `shrine_echo_seen` | bool | Shrine, memory echo | M3 seed |
| `village_pyre_seen` | bool | Village, пепелище | Mystery seed (что сгорело?) |

> `last_death_pos` (pos3) — не флаг, а data (→ мумия #5 в RUN 03,
> Passive Echo path). (WORLD_STATE_DESIGN §1.)

- **Правило:** каждый флаг = **1 видимое последствие** (no hidden
  flags). (GDD §7: no hidden systems.)
- **Data:** `data/world_flags.tres` (flag_id, type, set_trigger,
  consequence_id).

## 3. Memory Stats (скрытые счётчики, `memory{}`)

> **Player-behavior-as-story** (GDD §14, NARRATIVE_STRUCTURE §7).
> Скрытые счётчики (игрок НЕ видит). Влияют на: NPC dialogue,
> Mimic behavior, Echo aggression, discoveries, epilogues.

| Стат | Тип | Считается (когда) | Влияет на (что) |
|---|---|---|---|
| `kills` | int | каждое убийство | Echo aggression (slayer), NPC (Orren: «slayers») |
| `fled` | int | каждое бегство | Echo aggression (runner), Watcher spawn, NPC (Child: «you always run»), RUNNER (post-MVP) |
| `explored` | int (0–100%) | каждая новая зона/комната | discoveries (секретные комнаты по порогам), NPC (Cartographer: «routes are the same») |
| `notes_written` | int | каждая записка | NPC trust (Mara: `notes_written > 2`), #2-линия (записки «от себя») |
| `dominant_style` | enum (melee/ranged/dodge) | агрегат за N забегов (dodge_count, ranged_hits, melee_hits) | **Mimic** (зеркало привычки, ENEMY_DESIGN §4), **False Echo** (mirror-ahead) |
| `npc_killed` | int | каждое убийство NPC | **permanently** (NPC-gated Inheritance), Archivist-шёпот |
| `child_hit` | int | каждый «удар» Child | Child spawn (реже), Child-реплики (мягче) |
| `strange_actions` | int | каждое «странное» (hit Child, «слом»-объект, ...) | NPC (Nia: «strange»), discoveries (secrets) |
| `deaths` | int | каждая смерть | Child («217»), NPC (Mara: «you look different»), M4, boss-условие |
| `runs_completed` | int | каждый RUN | Child («217»), M4, epilogues |

- **Правило:** счётчики **скрытые** (игрок не видит числа). Но
  **последствия видны** (NPC-реплики, Mimic spawn, Echo aggression).
  (GDD §14: «player behavior must feed story».)
- **Thresholds:** `data/memory_stats_thresholds.tres` (slayer:
  `kills > 20`, runner: `fled > 10`, curious: `explored > 50%` +
  `strange_actions > 5`, ...). (PROGRESSION_DESIGN §1, ENEMY_DESIGN §7.)
- **MVP:** считаются ВСЕ (9 счётчиков). Влияют: NPC dialogue (4 NPC),
  Mimic spawn, Echo aggression. (Post-MVP: RUNNER Inheritance,
  epilogues.)

## 4. Notes (записки игрока, `notes[]`)

> **Player note system** (GDD §9): note stands, 5-line pool (no
> free text), stored in WorldState, readable next run.

```
note_entry: {
  note_id: int,
  run_id: int (какой забег),
  stand_id: string (camp/village/shrine/undercroft),
  line_id: string (1 из 5-line pool, data),
  t: int (ms, когда написано)
}
```

- **Note stands:** 4 (camp, village, shrine, undercroft-stand).
  (WORLD_BIBLE §4: «note stand».)
- **5-line pool (no free text):** 5 строк (data: `data/note_lines.tres`).
  Игрок выбирает 1 из 5 (не «свободный текст»). Примеры:
  1. *«I remember the mine. Don't go alone.»*
  2. *«The door opens after you stop.»*
  3. *«She's in the lake. Don't look too long.»*
  4. *«The blade was mine. Use it quickly.»*
  5. *«I'm not the first. I won't be the last.»*
  (Все 5 = «двери» (riddles), не «лор».)
- **Чтение:** записка **читается в следующем забеге** (RUN N+1,
  note stand). (WORLD_STATE: `notes[]` → RUN N+1: «прочитать».)
- **Echo читает:** Remnant (Combat Echo) «читает» записки (#6:
  Remnant прерывает бой и идёт читать вашу записку,
  *«...I forgot that.»* — FIRST_3_RUNS §3, D4). (ECHO_SYSTEM_DESIGN §3.)
- **Записки «от себя» (world-placed, #2 «Своя записка»):** 4
  scripted (FIRST_30_MINUTES):
  - camp (RUN 1, A7): *«If you find this, don't trust the version of
    me that comes after.»* (GDD §8, канон #2.)
  - mine (RUN 1, A14): *«It's heavy. Use it once. — E.»*
  - shrine (RUN 02, B5): *«It sees what you left. Use it gently. — E.»*
  - lake (RUN 1, A17): *«Don't go to the lake before the mine. — E.»*
  (Все = «двери», не «лор».)
- **Игрок-агентность:** игрок **пишет** записки (5-line pool) —
  «говорит с собой» (memory). (Player-behavior-as-story: `notes_written`.)
- **Limit:** 4 записки игрока (4 note stands: camp, village, shrine,
  undercroft; 1 per stand, «перезапись» (новая заменяет старую)).
  (Data: `notes_max: 4`.) (Записки «подножия gate» — world-placed
  «предыдущих версий» (read-only, не player notes).)

## 5. NPCs (NPC-состояние, `npcs{}`)

> Per-NPC: trust, death, «что сделано». (CHARACTER_BIBLE §2–6.)

```
npc_entry: {
  npc_id: string (mara/orren/nia/cartographer/child),
  alive: bool,
  trust: int (0–2),
  interactions: int (счётчик взаимодействий),
  gifts_given: bool (Inheritance, 1 раз),
  epilogue_seen: bool (post-MVP)
}
```

- **Trust:** 0–2 (PROGRESSION_DESIGN §4). (Условие: interactions +
  «помощь» (scripted) + memory_stats (NPC-специфичное).)
- **Death:** `alive = false` → **permanently** (NPC-gated Inheritance
  недоступно, consequence видимо (CHARACTER_BIBLE)). (GDD §9: «NPC
  death = permanent meta cost».)
- **Child:** `alive` всегда `true` (неуязвим, CHARACTER_BIBLE §5).
  `child_hit` (memory_stats) → spawn реже (soft-penalty).
- **Data:** `data/npc_state.tres` (npc_id, trust_thresholds,
  gift_id, consequence_id).

## 6. Transformation (пост-босс трансформация мира, `transform{}`)

> **Первая большая трансформация** (GDD §11, K7): boss_defeated →
> мир «теплее». (WORLD_BIBLE §1: «после босса мир «теплее»: туман
> редеет, появляется дальний свет города».)

| Изменение | До (pre-boss) | После (post-boss) | Data |
|---|---|---|---|
| Туман | плотный (80%) | редкий (30%) | `fog_density: 0.8 → 0.3` |
| Свет | «сумерки» (холодный) | «теплее» (тёплый акцент) | `light_temp: 4000K → 5500K` |
| Gate | «замок» (тёмный) | **светится** (K7) | `gate_glow: false → true` |
| Город | не виден | **виден** (silhouette, за вратами) | `city_visible: false → true` |
| Echo | full budget | **«тише»** (budget -2, «спокойнее») | `echo_budget: 5 → 3` |
| Следы | «исчезают» (N runs) | **«остаются навсегда»** | `footprint_permanent: false → true` |
| NPC | «живые» | **«спокойнее»** (реплики меняются) | `npc_calm: false → true` |

- **Триггер:** `boss_defeated = true` → **world_transform** (WORLD_
  STATE: `transform{}`). (1 раз, permanently.)
- **Визуал:** «мир теплеет» (lighting, fog, gate glow). (WORLD_BIBLE
  §1: «тёплые цвета = «дом/жизнь»».)
- **NPC-реплики:** Mara: *«The fire is brighter. I don't like it.»*
  Orren: (башня пуста, записка: *«I'm going down. For once.»*)
  Nia: *«Page one. Again. (smiles) ...I'm glad.»*
  Cartographer: (доска: *«The gate is a door. Doors open both ways.
  I'm going through. — C.»*)
  (CHARACTER_BIBLE §2–6, post-boss.)
- **MVP-конец:** K7 (врата светят, город виден, «ты стоишь»).
  (NARRATIVE_STRUCTURE §1: Act I завершён, Act II начинается.)

## 7. Inheritances и Weapons (перманентные, `inheritances{}`, `weapons{}`)

> (PROGRESSION_DESIGN §1, WEAPON_DESIGN §5.)

```
inheritances: { sharp: bool, flow: bool, slow_burn: bool, quiet_step:
  bool, deep_sight: bool, gentle_hand: bool, echo_step: bool,
  second_chance: bool, ember: bool, track: bool, page: bool,
  compass: bool }  # 12 MVP-pool
inheritances_post: { breaker: bool, paradox: bool, runner: bool }
weapons: { blade: bool, cannon: bool, staff: bool, first_blade:
  bool (taken) }
```

- **Inheritances:** 15 (MVP-pool: 8 базовых + 4 NPC-gated;
  post-MVP: breaker, paradox, runner). (PROGRESSION_DESIGN §1.)
- **Weapons:** 3 (blade, cannon, staff) + first blade (taken/leave).
  (WEAPON_DESIGN §5.)
- **Правило:** permanently (не «сбрасывается» при смерти). (GDD §9:
  «no currency» — «progress = память мира».)

## 8. Правила (все)

1. **WorldState = единственный «память»-слой.** (GDD §7: no hidden
   systems.)
2. **Каждый flag = 1 видимое последствие.** (No hidden flags.)
3. **Memory stats = скрытые, но последствия видны.** (GDD §14.)
4. **Notes = 5-line pool, no free text.** (WORLD_STATE §4.)
5. **NPC death = permanently.** (GDD §9.)
6. **Transformation = 1 раз, permanently.** (boss_defeated → world.)
7. **Data-driven.** (Все flags, memory_stats, notes, NPCs,
   inheritances — Resources.)

## 9. UX: «Что изменилось» + shimmer (GDD §6.7)

> **Всякая перемена видна за 1 секунду** (GDD §6.7): шиммер
> «мемориальных» объектов + сводка «Что изменилось».

### 9.1 Shimmer (визуал)
- Каждый объект, состояние которого изменилось (flag set), получает
  **pale glow shimmer** (1 с, layer «Memory» — WORLD_BIBLE §1.1):
  gate (открыт), note stand (новая записка), костёр (EMBER), мумия
  (#5), фонарь The First, врата (K7).
- Shimmer = «мир помнит изменение» — игрок видит «где изменилось»,
  не «что» (ambiguity: подходи — узнай).

### 9.2 «Что изменилось» (UI-сводка)
- **Когда:** на respawn (после смерти) + на major trigger (flag set):
  1 список (≤5 строк), 3 с, fade. Пример (RUN 02 respawn):
  - «Дверь в лесу открылась.» (gate)
  - «Оружие ждёт в шахте.» (cannon)
  - «Кто-то оставил кетл. (Mara.)» (npc_mara)
- **Правила:**
  - 1 строка = 1 flag (data: `consequence_text`, per flag —
    WORLD_BIBLE: «1 флаг = 1 видимое последствие»).
  - **No numbers** (не «+2 HP» — «дверь открылась»).
  - **Можно пропустить** (1 с — «окно, не таймер»): игрок, не
    глядя, — «пропустит» (но shimmer остаётся — «мир подсказывает»).
- **MVP-обязательно** (GDD §12: «Что изменилось» замечено без
  подсказки ≥70% тест-сессий — QA Phase 17).

## 10. Связи с системами
- **TECHNICAL_DESIGN** — save format (JSON, CRC32, atomic, migrations),
  RunEvent (14 bytes), WorldState autoload (ADR-009).
- **ECHO_SYSTEM_DESIGN** — run_data (RunEvent), budget, spawn-правила.
- **PROGRESSION_DESIGN** — Inheritances, trust, memory_stats thresholds.
- **ENEMY_DESIGN** — memory_stats → aggression (slayer/runner/explorer).
- **CHARACTER_BIBLE** — NPC state, trust, death-consequences.
- **NARRATIVE_STRUCTURE** — memory_stats → epilogues (post-MVP).

## 11. Open questions (world state)
- Q-WD1: «ВСЕ runs хранятся» — не «слишком много» ли (disk)?
  (Митигция: ~10–15 runs, ~150 КБ. Data: `runs_max: 50` (post-MVP
  «старые» runs «сжимаются» (summary only).) MVP: все.)
- Q-WD2: «5-line pool» — не «слишком ограничено» ли (no free text)?
  (Митигция: «5 строк = 5 «дверей»» (riddles). Free text = «no
  quality bar» (GDD §13). Решение: 5-line pool, data-driven, легко
  «+5» (post-MVP).)
- Q-WD3: «Transformation = 1 раз» — не «слишком резко» ли (world
  changes)? (Митигция: «post-boss = «act end»» (NARRATIVE §1).
  Резко = «сильный beat» (K7). Решение: да, резко — «act end».)
