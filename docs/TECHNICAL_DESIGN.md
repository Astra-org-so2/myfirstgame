# AFTER YOU — Technical Design (data model, форматы, алгоритмы)

Версия: 0.2 (Phase 0, GDD v2.0). Связанные: ARCHITECTURE.md, DECISIONS.md,
docs/design/*.

---

## 1. Data-driven ресурсы (GameData)

Все — Godot `Resource`-классы, хранятся в `data/`, регистрируются в
`GameDataRegistry` (статический каталог по пути, кэш по uid; валидация по
load-time, ошибка регистрации = push_error + skip, не crash).

### WeaponData
```
id: StringName            # "weapon_blade" | "weapon_hand_cannon" |
                           #  "weapon_echo_staff" | "weapon_first_blade"
display_name: String
damage: int               # базовый урон
attack_speed: float       # сек/удар (cooldown базовой атаки)
combo_count: int          # 2–3
range: float              # метры hitbox
arc: float                # угловой сектор hitbox (deg)
knockback: Vector2        # сила / время
stamina_cost: int
type: enum {melee, ranged, staff}
ranged: {ammo: int, reload_count: int, projectile_speed: float,
         projectile_scene: PackedScene, noise: int}
  # HAND CANNON: ammo 5/забег, reload_count 1 (WEAPON_DESIGN §2.2)
staff: {actions: {name: StringName, cooldown: float, range: float,
                  target: enum{self, enemy, echo}, effect: StaffEffectRef}}
  # ECHO STAFF: read/disrupt/soothe/shatter (WEAPON_DESIGN §3.2)
special: {name: StringName, cooldown: float, window: float}
  # BLADE: riposte (0.5 s window); FIRST BLADE: core_hit (boss-only)
core_hit: bool            # true только для FIRST BLADE (BOSS_DESIGN §3.3)
vfx: {swing: PackedScene, hit: PackedScene}
audio: {swing: AudioStream, hit: AudioStream}
model_scene: PackedScene  # визуал оружия (mount)
color_tint: Color
```

### InheritanceData (meta; заменяет UpgradeData v0.1)
```
id: StringName            # "sharp", "flow", "ember", ...
display_name: String
description: String       # 1 строка, «что делает» (без чисел, DIALOGUE §5)
gate: enum {none, npc, behavior}
npc_id: StringName|null   # npc-gate: EMBER=Mara, TRACK=Orren, PAGE=Nia,
                          #        COMPASS=Cartographer (PROGRESSION §1)
behavior: {stat: StringName, op, value}  # behavior-gate (RUNNER: fled>10)
effect: InheritanceEffectRef  # gameplay-эффект (не «+5%»: WEAPON_DESIGN
                              #   upgrade-таблица; PROGRESSION_DESIGN §1)
mvp_pool: bool            # 12 в MVP-pool / 3 post-MVP
```


### EnemyData
```
id: StringName            # "hollow" | "remnant" | "watcher" |
                           #  "mimic" | "forgotten" (ENEMY_DESIGN)
display_name: String
health: int
move_speed: float / detect_speed: float
detect: {sight_range: float, hearing_range: float, aggro_radius: float}
states: Dictionary[StringName, EnemyStateData]
   # EnemyStateData: {duration, speed_mult, attack: AttackData|null,
   #                  can_be_interrupted, on_enter_vfx/audio}
attack: AttackData {windup: float, active: float, recovery: float,
                   damage, knockback, range, arc|aoe_radius,
                   projectile: RangedData|null, vfx, audio}
ai: {update_hz: float, path_update_hz: float, idle_radius: float}
memory: {anchor_set: bool,           # Watcher: наблюдение → memory anchor
         mirror_style: bool,         # Mimic: зеркало dominant_style
         whisper_pool: StringName,   # Forgotten: pool фраз (история игрока)
         mirror_ahead: float}        # False Echo: 0.5 s (ECHO §5)
  # агрессивность — от memory_stats (ENEMY_DESIGN §7: slayer/runner/
  # explorer/consistent-style) — data: data/memory_stats_thresholds.tres
model_scene: PackedScene
death: {vfx, audio, drops: LootTableRef, score_value: int,
        footprint: bool}             # true → след остаётся (WORLD_STATE)
```

### ItemData
```
id, display_name, type: enum {consumable, material, relic, note},
stack_max: int,
effect: ItemEffectRef (лечит X / +stamina / осколки / narrative),
icon: Texture2D, model_scene: PackedScene|null,
can_drop_in_world: bool   # true → при смерти/броске остаётся в мире (memory!)
```

### RoomData
```
id: StringName            # "room_camp_a"
area: StringName          # "camp"
size: Vector2             # логический размер (м)
doorways: Array[DoorwayDef]   # {anchor: StringName, local_pos: Vector3,
                              #  facing: Vector3, target_anchor: StringName}
  # doorway-якоря ИДЕНТИЧНЫ во всех вариантах одной комнаты (ADR-003)
spawn_points: Array[Vector3]
loot_spots: Array[Vector3]
event_spots: Array[Vector3]   # для scripted/mystery объектов
ambient: {fog_density, light_rig_scene, audio_ambience}
model_scene: PackedScene
```

### AreaData (локация-агрегат)
```
id, name, rooms: Array[RoomData], room_weights: Array[float]
# процедурный выбор: 1–3 комнаты из набора по весам + seed
connections: Array[{to: StringName, door: StringName, condition: WorldStateCond|null}]
  # condition = условие world-state (opened_shortcut, choice...)
ambience, boss_arena: bool
```

### MysteryEventData
```
id, area/room, trigger: {type: enum{enter, interact, ghost_complete,
             run_count, choice}, ...},
payload: {scene: PackedScene, dialogue: DialogueDataRef, journal_entry: String,
          world_effect: WorldStateChangeRef, reward: ItemDataRef|null}
discovery_order: int, depends_on: Array[StringName]
```

### DialogueData
```
id, lines: Array[DialogueLine {speaker, text: String, portrait: Texture2D|null,
    condition: WorldStateCond|null, choice: [Choice {text, effect, next}]}]
```

## 2. RunEvent (запись забега) — компактная schema

Event-based recording (не video, ADR-004). Событие = фиксированные поля:

```
struct RunEvent {
  t: int32        # время от старта забега, децисекунды (0.1s), cap ~68 h
  type: uint8     # enum RunEventType (ниже)
  room: uint8     # index RoomData в AreaGraph (≤255)
  x: int16; y: int16; z: int16   # room-local, см (0.01m), clamp ±327m
  ry: uint8       # rotation Y, град 0–359
  target: uint16  # entity id (enemy/chest/npc id в run-локациях) или 0
  data: uint8     # тип-специфичное поле (weapon idx / item idx / dir idx)
}  # 14 байт на событие (в JSON-save — компактный массив [t,type,room,x,y,z,ry,target,data])
```

RunEventType (enum):
```
ENTER_ROOM, ATTACK, ATTACK_HIT, ENEMY_KILLED, CHEST_OPENED, ITEM_PICKED,
ITEM_DROPPED, NPC_TALKED, NPC_KILLED, EVENT_COMPLETED, CHOICE_MADE,
PLAYER_DIED, PLAYER_SPAWNED, GHOST_WATCHED (M3-seed),
NOTE_WRITTEN, ANCHOR_SET (Watcher → Memory Echo), ECHO_TRIGGER,
ECHO_NOTE_READ (#6), MUMMY_EXAMINED (#5)
```

**Лимиты и политика:**
- ≤ 4096 событий на забег; переполнение → «sampling»: события ATTACK
  дуплицируются → каждая 2-я (флаг в RunHeader); остальное — truncation
  с log (ghost воспроизводит до конца лога, дальше — stand).
- Полные логи сохраняются для **всех забегов** (MVP: ~10–15 runs,
  ~150 КБ; ADR-004-правка); старые (post-MVP, `runs_max: 50`) —
  `RunSummary` (seed, duration, death_cause, kills, rooms_visited,
  major_events: ≤16 самых значимых, inheritance_earned, weapon_used,
  mystery_flags, dominant_style) — для Remnant («лучший забег» =
  best run: max playtime+kills), M1/M2, «Что изменилось».
- Запись: только по событиям EventBus (никаких per-frame записей).
  Движение ghost восстанавливается интерполяцией между keyframes
  (ENTER_ROOM/ATTACK/ITEM_*...), см. §5.

## 3. Save format

Файл: `user://save/ay_save.json` (одна слот-файл, v1).

```json
{
  "format": "ay_save",
  "version": 1,
  "saved_at_unix": 1757760000,
  "engine_version": "4.7.2",
  "world": { ...WorldState... },
  "player": { inheritances: [StringName], trust: {npc: int},
              total_deaths: 7, best_run: {...} },
  "runs": { "full": [ RunRecord xN (все, MVP) ],
              "summaries": [RunSummary xN≤64] },
  "settings": { quality: "high", master: 0.8, music: 0.7, sfx: 0.9,
                muted: false, video: {...} },
  "stats": {...},
  "crc32": "<hex>"
}
```

**Механика SaveManager:**
1. Serialize → JSON (стабильный порядок ключей, `to_json_string` pretty-off).
2. CRC32 над body → записать в поле.
3. Atomic-ish: запись в `save.json.tmp` → `FileAccess.flush` → close →
   `DirAccess.rename` (атомарно на POSIX/NTFS-файлах; на crash между
   шагами остаётся либо старый, либо новый файл, не битый).
4. Load: read → parse → version check:
   - `version < SAVE_VERSION` → `SaveMigration.migrate_vN_to_vN+1` chain
     (каждый шаг = чистая функция; неизвестный gap = recovery);
   - `version > SAVE_VERSION` → «save от более новой версии»: не трогать,
     показать сообщение, играть со «свежим» world (без потери meta-
     прогрессии — meta-секция восстанавливается по safe defaults из
     backup-копии).
   - parse error / crc mismatch → `save.json.bak` (если валиден) →
     восстановление; иначе — fresh save + log + UI-сообщение
     («сохранение повреждено, создан новый; данные: <path>»).
5. Auto-save: при выходе в хаб-безопасную зону, на паузе, при выборе
   upgrade, при `os::NOTIFICATION_WM_CLOSE_REQUEST`.
6. Максимальный размер save: 5MB (hard cap; переполнение runs → отброс
   самых старых summaries с log).

**WorldState (в save.world):**
```
{
  version: 1,
  world_id: "forgotten_forest_v1",     # стабильный id мира (The Forgotten Forest)
  run_count: int,
  flags: {flag_id: bool},                # WORLD_STATE_DESIGN §2 (20+ flags)
  discovered: [StringName],
  npcs: {npc_id: {alive, trust, interactions, gifts_given}},  # §5
  completed_events: [StringName],
  choices: {choice_id: int},             # take/leave FIRST BLADE, ...
  opened_shortcuts: [StringName],
  unlocked_rooms: [StringName],
  dropped_items: [{item_id, room, pos, run}],   # ≤64, старые — «рассеиваются»
  notes: [{note_id, run_id, stand_id, line_id, t}],  # §4 (4 stands, 5-line pool)
  last_death_pos: {room, pos}|null,      # → мумия #5
  anchors: [{room, pos, run}],           # Watcher → Memory Echo (≤2/run)
  ghosts: {last_run_ref, markers: [{room, pos, run}]},
  memory: {kills, fled, explored, notes_written, dominant_style,
           npc_killed, child_hit, strange_actions, deaths, runs_completed},
  # memory_stats — скрытые счётчики (WORLD_STATE_DESIGN §3)
  inheritances: [StringName],            # §7 (15: 12 MVP + 3 post-MVP)
  weapons: {blade, cannon, staff, first_blade_taken},  # §7
  transform: {boss_defeated, fog_density, light_temp, gate_glow,
              city_visible, echo_budget, footprint_permanent, npc_calm},
  # K7 transformation (WORLD_STATE_DESIGN §6)
  mystery_progress: {mystery_id: int_stage}   # M1–M4 (MYSTERY_REVEAL_MAP)
}
```
Мутации WorldState — только через `WorldDirector.apply_change(change, source)`:
валидация (id существует, нет дублей) → запись → EventBus.world_state_changed.

## 4. World memory: применение к миру

На старт забега (после загрузки AreaGraph-сид-конфига):
1. `WorldDirector.prepare_world(seed)`:
   - для каждого persistent-объекта world-state: spawn/конфигурация
     (door: opened/closed/destroyed; npc: alive/dead; chest: opened/
     looted; dropped item: mesh + interactable).
   - валидация: объект/room, упомянутый в world-state, но отсутствующий в
     текущем world_id → push_warning + skip (graceful, не crash).
2. Динамика забега: события EventBus → WorldDirector → черновик изменений
   (run-scoped); при смерти/выживании → commit в WorldState (что
   перманентно, а что run-scoped — свойство типа события: например,
   `opened_shortcut` = перманентно, `npc_killed` = перманентно,
   `item_picked` = run-scoped, если не can_drop_in_world).

## 5. Ghost replay (алгоритм) — Passive Echo

Вход: `RunRecord` (последний full-лог) + текущий AreaGraph (seed текущего
забега). (Budget per ADR-014: 1 Passive + 1 Combat (Remnant — enemy,
Phase 5) + 1 «специальный» (Memory|Forgotten|False) = max 3/run (MVP);
RUN 1: 0, RUN 02: 2, RUN 03: 2, RUN 04+: до 3; post-boss: -2.)

1. **Таймлайн:** события лога → keyframes `K[i] = (t, room, pos_local, ry,
   action)`. Позиция в room-local (записывается таковой — ADR-003).
2. **Карта в текущий мир:** `room_id(лога) → RoomData(текущий seed)`.
   - Комната совпадает по id → позиции совместимы (якоря дверей
     идентичны, room-local координаты в пределах общих границ) → ghost
     бегает там.
   - Комната в текущем seed отсутствует (вариант другой) → ghost
     «перематывается» к ближайшему совместимому ключу (кратчайший по t),
     визуально: dissolve-посвет на границе комнаты (легитимно
     нарративно: «не всё помнится»).
3. **Интерполяция:** между keyframes — Catmull-Rom по позициям (slerp по
   ry), скорость ≤ max_ghost_speed (защита от артефактов); внутри комнаты —
   navmesh-проекция на каждый 0.25s (защита от «летания сквозь стену» при
   различии room-вариантов).
4. **Действия:** на keyframe action → анимация (attack: swing без урона;
   chest_opened: ghost лишь имитирует движение (реальный
   сундук не открывается/закрывается — ghost не мутирует мир; исключение —
   scripted mystery-моменты, у которых явный world_effect).
5. **Видимость/стиль:** shader (dissolve + cool tint + rim), `process_mode`
   наследует паузу; ghost не имеет физики (layer 9 mask 0), collision с
   миром — через navmesh-проекцию (п.3).
6. **Стоимость:** 1 ghost = 1 character mesh + 1 shader + интерполяция
   (O(1)/frame). Маркеры старых runs — 3–5 GPUParticles-маркеров (пул).

## 6. Процедурные комнаты

- Graph: DAG `хаб → ... → boss_arena`; рёбра = doorway-якоря;
  `AreaData.connections.condition` позволяет world-state менять граф
  (opened shortcut = новое ребро; choice = замкнутая ветка).
- Генерация забега (seed):
  1. BFS-проход по графу с жёсткими правилами: нет изолятов, каждый
     комната-назначение (loot room, combat room, mystery room) достигима,
     boss-арена — единственный sink.
  2. В каждой локации: выбор 1–3 room-вариантов (weights, без повтора
     room_id в пределах локации).
  3. Спавны: encounter-table (враги по difficulty-curve), loot по
     LootTable (seeded), события (mystery-триггеры — по condition).
  4. **Валидация (обязательна, до старта забега):**
     - достижимость всех обязательных точек (граф-проверка);
     - нет «спавна в стене» (collision probe на каждом spawn point);
     - нет «дверь без назначения» (каждый doorway → target exists);
     - difficulty-монотонность (boss-арена не раньше X забегов-времени);
     - fail → реген с seed+1 (≤8 попыток) → при исчерпании: fallback
       на reference-раскладку (hand-picked валидная) + log.
  5. Детерминизм: тот же seed + тот же world_id → идентичная раскладка
     (интеграционный тест: seed A, B, A' → A==A').
- Deterministic RNG: `RNG Streams` (ARCHITECTURE §1): `RngWorld` (раскладка),
  `RngEncounter`, `RngLoot`, `RngEvent` — независимые `RandomNumberGenerator`
  от master seed (splitmix64).

## 7. Input

Actions (InputMap): `move_up/down/left/right`, `sprint`, `dodge`,
`attack`, `ranged_attack`, `interact`, `inventory`, `pause`, `camera_*`,
`ui_*` (navigation), `debug_*` (release-off).
- **Touch (PRIMARY, Android first — ADR-021):** виртуальный джойстик
  (левый нижний квадрант: move/sprint — по амплитуде) + кнопки (правый
  нижний квадрант: attack — крупная, dodge, interact — контекстная,
  inventory) + **drag-камера** (тач по свободной зоне справа). Layout —
  data (`data/ui/touch_layout.tres`: позиции per aspect + safe area),
  не хардкод. Финальная эргономика — Phase 2/13 (touch-тест на
  устройстве).
- **Keyboard/mouse + gamepad (dev/QA):** те же actions, отдельные
  device-layout'ы (ARCHITECTURE §7: один набор actions, N layouts).

## 8. Audio

- Buses: `Master → (Music, SFX, Voice)`. Master-компрессор (Limiter) +
  (Reverb-эффект на SFX, лёгкий).
- AudioManager: `play_sfx(name, pos=null, bus="SFX")` (pooled: ≤16
  одновременных SFX, prioritized), `play_music(track, crossfade)`,
  `play_ambience(area_id)`.
- Наборы (MVP): footsteps (4 surfaces), weapon swing/hit (per weapon),
  enemy attack/death (per archetype), UI (6), ambient (3 areas),
  music: **одна мелодия «The Wound» ×5 вариаций** (Normal/Memory/Echo/
  Archivist/Ending, GDD v2.0 §7) + ambient-слои + 1 stinger (boss reveal);
  звуковой язык слоёв (WORLD_BIBLE §1.1: distortion/reversed/whispers/reverb).
- Форматы: OGG (music/ambience), WAV (SFX short, 44.1k stereo).

## 9. VFX (MVP-набор, все — пул)

swing trail (weapon, 1-2 кадры), hit impact (спарки, 10–30 частиц),
death burst (40–60), dodge dust, leaf ambient (environment, 20–40,
Multimesh-альтернатива на Low), ember (костры), ghost shimmer (shader),
mystery glow (emissive pulse), boss telegraph (ground decal + particles).

## 10. UI screens (список + states)

HUD (health bar, stamina bar, weapon icon, interact prompt, echo marker
«след впереди»), Inventory (12 grid + equipment 3 slots), Dialogue
(portrait, text, choices max 2), Pause (resume/settings/quit-to-hub),
Settings (video: quality preset (Low/Med/High/Ultra — мобильные),
render scale (0.75/1.0), vsync; audio: 3 vols + mute; controls remap
`?` (keyboard/gamepad)), DeathScreen («вы умерли. Мир запомнил.» +
Inheritance-карточки 1/3 (UX ≤10 s) + «Что изменилось» (≤5 строк) +
continue → 1 нажатие), RunSummary (статистика забега + выбор
Inheritance 1/3), Journal («Записки» — player notes (5-line pool) +
найдённые world-notes), «Что изменилось» panel (WORLD_STATE_DESIGN §9.2).
**Мобильная вёрстка (ADR-021):** landscape; aspect 16:9–20:9 + safe area
(notch/punch-hole — safe-margin); UI scale по разрешению; touch-зоны в
«thumb-зоне» (нижние углы); HUD не перекрывает критичную центр-зону боя.

## 11. Debug tools (F1–F8, release-off)

F1 overlay (fps, ms frame, draw calls, node count, phys bodies, ai budget
ms, seed, run state, ghost state, world-state summary);
F2 spawn enemy (цикл архетипов, курсором перед игроком);
F3 give weapon (цикл 3); F4 teleport (цикл локаций); F5 kill player;
F6 advance world state (simulated death: +run_count, +deaths, ghost from
current run, door-open check); F7 replay previous run (spawn passive echo
now); F8 clear temp run state; (F9, dev-only: set memory_stats —
tune-инструмент, release-off).
Все — через `DebugTools` autoload, feature-tag `Release` убирает autoload.

## 12. Performance budget (mobile-first; замеры — Phase 16, на устройстве)

**Референс-железо (ADR-021):** mid-range Android (Snapdragon 7-класс,
8 GB, 1080×2400 — смартфон владельца) = целевой; low-end (SD 6xx-класс,
4 GB, 720×1600) = floor. Замеры — ADB + F1 overlay (сбор в файл).

| Метрика | Бюджет (High, 1080p, mid-range) | Бюджет (Low, 720p, low-end) | Как меряем |
|---|---|---|---|
| Frame time | ≤ 16.6 ms (60 fps), P95 ≤ 22 ms | ≤ 33.3 ms (30 fps), P95 ≤ 45 ms | F1 overlay + `--benchmark` (сбор в файл, Phase 16) |
| Draw calls (локация, полная) | ≤ 150 (env ≤90, chars ≤30, vfx ≤30) | ≤ 120 | overlay (`get_render_info`) |
| AI budget | ≤ 4 ms/frame (staggered) | ≤ 5 ms | замер в AI-тиках |
| Physics bodies (локация) | ≤ 40 | ≤ 40 | overlay |
| Particles живых | ≤ 200 (на экране) | ≤ 100 | overlay |
| Nodes (локация) | ≤ 2000 | ≤ 2000 | overlay |
| Texture memory | ≤ 256 MB (ASTC) | ≤ 192 MB | overlay |
| RAM процесса | ≤ 1.2 GB | ≤ 1.0 GB | overlay / `dumpsys` |
| Load: cold start → playable | ≤ 8 c (на устройстве) | ≤ 10 c | ручной замер (Phase 16) |
| Death → respawn | ≤ 2 c (hard); ≤10 c UX (UI) | то же | замер в RunManager |
| Save write | ≤ 50 ms | ≤ 80 ms | SaveManager (debug) |
| Save size | ≤ 5 MB | ≤ 5 MB | assert в тестах |
| Thermal (30-мин сессия) | без drop ниже 60 fps (High) / 55 fps (Med) | без drop ниже 30 fps | сессия на устройстве (Phase 16) |

**Preset'ы (мобильные, data-driven `data/quality/*.tres`):**
- **Low** (low-end): 720p, shadows off, fog simple, particles 50%,
  no post, textures 512 ASTC, 3 local lights.
- **Medium** (mid-range base): 1080p, shadows 1024, particles 75%,
  textures 1024 ASTC, 4 local lights.
- **High** (mid/high): 1080p, shadows 2048, particles 100%, MSAA 2×,
  6 local lights, render scale 1.0.
- **Ultra** (flagship): High + soft shadows + VFX 125% (опц.).
- Render scale 0.75 — «performance mode» (Low/Med) при просадках.
- **Тепло/батарея (ADR-021):** без sustained-100% нагрузки (VFX/AI-
  бюджеты; idle-состояния мира «тихие»); auto-quality-drop — post-MVP
  (MVP: preset по выбору + рекомендация по классу устройства на
  старте: GPU-name → preset, data).

## 13. Headless-тест-риг (toolchain; подробно в TEST_PLAN)

- Движок в песочнице: **Godot 4.7.2 wasm-build** (npm `@ringozz/godot`
  4.7.2-626) на Node 22 — `tools/godot-node/` (bootstrap + harness).
- Что может: scenes/GDScript/resources/signals/timers/process-тики (60Гц) /
  math / File I/O (MEMFS) / quit+exit code.
- Что НЕ может (проверено): 3D-физика (Dummy server), навигация (частично
  недоступна), рендер, аудио-вывод → покрывается: PhysicsPort-mocks
  (ARCHITECTURE §3.4) + ручное QA на ПК + (опционально) запуск рига на
  машине пользователя с той же версией (тот же wasm-билд — физика всё
  равно dummy, поэтому physics-feel только native).
- Команда: `./tools/run_tests.sh` (bootstrap idempotent; stage-прогон unit+
  integration; exit code = число падений).

## 14. v2-системы (GDD 2.0): boss-данные, ending-state

### 14.1 BossData (The First; BOSS_DESIGN §5)
```
id: StringName            # "boss_the_first"
hp: int                   # 600 (tune Phase 12)
phases: [BossPhaseData]   # phase 1: Wandering, phase 2: Workshop
  # BossPhaseData: {hp_from, hp_to, speed, patterns: [PatternData],
  #                 minion: {enemy_id, run_ref: "best"}|null,
  #                 arena_variant: StringName}
patterns: [PatternData]   # PatternData: {name, telegraph, damage,
                          #  range, core_window: float|null}
pattern_memory: {threshold: int, parry_window: float, reset_moves: int}
  # паттерн-память (BOSS_DESIGN §3.2): data, не хардкод
core: {window_base: float, window_first_blade: float, damage,
       damage_no_blade: float}
enter_condition: WorldStateCond   # ADR-019: mine_level_3_explored AND
                                  #  deaths>=3 AND first_traces_seen
death: {vfx, audio, lines: [StringName], world_effect: WorldStateChangeRef}
  # K6 + K7 transformation (WORLD_STATE_DESIGN §6)
```

### 14.2 EndingState (post-MVP; архитектура готова, контент — Act V)
```
endings: {A, B, C}        # A/B/C (NARRATIVE_STRUCTURE §6; C = true,
                          #  игрок становится новой Archivist — GDD §6.11)
ending_choice: StringName|null   # ставится в Act V (post-MVP)
epilogue_seen: [StringName]
postgame: {mode: enum{none, archive, quiet, living}}
  # A → archive (мир «архивный»), B → quiet (мир «пустой»),
  # C → living (мир «живой», New Game+ — «живой мир»)
ambiguity_frame: bool      # final-frame ambiguity (NARRATIVE §6)
```
- Миграция: `ending_choice`/`postgame` — nullable с safe defaults
  (save v1 → v2: absent = null = «не выбран»).
- MVP: только `ending_choice: null` + подготовка (K6-seed, boss
  death); Act V/VI — post-MVP (GDD v2.0 §11: «архитектура готова,
  контент — post-MVP»).
## 15. Android-платформа (первичная цель; ADR-021)

> **Android first** (GDD §11/§15): мобильная платформа — первичная цель
> релиза. iOS — вторичная (если архитектура/бюджет позволяют). ПК —
> только dev/QA-удобство. Все технические решения проверяются вопросом
> «сможет ли это нормально работать на Android-смартфоне?».

### 15.1 Рендерер и графика
- **Renderer: Forward+ (Vulkan).** Не Mobile renderer для финального
  качества (Mobile renderer — fallback/опция для очень слабых устройств;
  Forward+ даёт нужные локальные источники света). Решение по
  «Forward+ vs Mobile» фиксируется замерами Phase 16 на референс-железе.
- **Формат текстур: ASTC** (стандарт для всех современных GPU Android);
  BC7/DXT — не используются в релизе.
- **Разрешение рендера** — от quality preset (720p/1080p) + render scale
  (0.75/1.0). Не привязывать к нативному разрешению экрана «в лоб».
- **Ориентация: landscape** (портрет — не поддерживается в MVP).

### 15.2 Минимальная конфигурация (MVP)
- **Android:** minSdk **API 26 (Android 8.0)**; target — актуальный.
- **GPU:** Adreno 6xx / Mali G72+ / PowerVR (современные). Реальный
  список — по результатам Phase 16 (GPU-name → preset).
- **RAM:** 3 GB (низшая граница для Mid preset).
- **Хранилище:** APK + данные ≤ ~2 GB (цель; ассеты — по ADR-017).

### 15.3 Экспорт и CI (ADR-012 — Android)
- Export preset `export/android/release` (debug — для ADB-QA).
- **Signing:** keystore НЕ в git; секреты — env vars CI (Godot export
  via `--export-release` CLI).
- **CI:** headless-тесты (ADR-012) + **Android build (gradle)** как
  отдельный job (нужен Android SDK; в песочнице — опционально, см. §15.5).
- **Реальная ADB-QA** (запуск на устройстве, сбор логов/метрик) — на
  устройстве владельца, не в CI.

### 15.4 Сохранения и данные (мобильные особенности)
- Save в `user://` (внутреннее хранилище; не external — права/доступ).
- Атомарный write (tmp → rename) — обязателен на мобильном
  (прерывание записи при сбое питания/low-memory).
- Low-memory: OS может убить процесс — save пишется часто (автосейв) и
  устойчив к повреждению (CRC, см. §11).

### 15.5 Инструменты в песочнице (честные ограничения)
- **Godot editor + headless-тесты** — работают (Linux).
- **Android export (gradle/AAPT2)** — требует Android SDK + JDK; в
  песочнице **не гарантирован**. Стратегия: export-конфиг и CI job
  создаём и держим рабочими на уровне конфигурации; фактический сбор
  APK и ADB-QA — на машине/устройстве владельца (документировано, не
  притворяемся, что «собрали APK в песочнице»).
- **Пересечение с ADR-003 (sandbox-ограничения):** Android-тулчейн —
  расширение ограничений; фазы, где нужен реальный Android, помечены
  «на устройстве» в ROADMAP.
