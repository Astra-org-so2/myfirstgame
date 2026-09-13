# AFTER YOU — Technical Design (data model, форматы, алгоритмы)

Версия: 0.1 (Phase 0). Связанные: ARCHITECTURE.md, DECISIONS.md.

---

## 1. Data-driven ресурсы (GameData)

Все — Godot `Resource`-классы, хранятся в `data/`, регистрируются в
`GameDataRegistry` (статический каталог по пути, кэш по uid; валидация по
load-time, ошибка регистрации = push_error + skip, не crash).

### WeaponData
```
id: StringName            # "weapon_sword"
display_name: String
damage: int               # базовый урон
attack_speed: float       # сек/удар (cooldown базовой атаки)
combo_count: int          # 2–3
range: float              # метры hitbox
arc: float                # угловой сектор hitbox (deg)
knockback: Vector2        # сила / время
stamina_cost: int
type: enum {melee, ranged}
ranged: {ammo: int, projectile_speed: float, projectile_scene: PackedScene}
vfx: {swing: PackedScene, hit: PackedScene}
audio: {swing: AudioStream, hit: AudioStream}
model_scene: PackedScene  # визуал оружия (mount)
color_tint: Color
```

### EnemyData
```
id: StringName            # "stalker"
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
model_scene: PackedScene
death: {vfx, audio, drops: LootTableRef, score_value: int}
```

### ItemData
```
id, display_name, type: enum {consumable, material, relic, note},
stack_max: int,
effect: ItemEffectRef (лечит X / +stamina / осколки / narrative),
icon: Texture2D, model_scene: PackedScene|null,
can_drop_in_world: bool   # true → при смерти/броске остаётся в мире (memory!)
```

### UpgradeData (legacy, meta)
```
id, display_name, description, tier_cost: [int, int, int]  # 3 уровня
effect: UpgradeEffectRef {stat, op(+ / * / set), value}
  # stat: max_hp, dodge_cd, damage_mult, stamina, detect_noise, loot_weight...
unique: bool
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
  t: int16        # время от старта забега, децисекунды (0.1s), max 3259 с
  type: uint8     # enum RunEventType (ниже)
  room: uint8     # index RoomData в AreaGraph (≤255)
  x: int16; y: int16; z: int16   # room-local, см (0.01m), clamp ±327m
  ry: uint8       # rotation Y, град 0–359
  target: uint16  # entity id (enemy/chest/npc id в run-локациях) или 0
  data: uint8     # тип-специфичное поле (weapon idx / item idx / dir idx)
}  # 12 байт на событие (в JSON-save — компактный массив [t,type,room,x,y,z,ry,target,data])
```

RunEventType (enum):
```
ENTER_ROOM, ATTACK, ATTACK_HIT, ENEMY_KILLED, CHEST_OPENED, ITEM_PICKED,
ITEM_DROPPED, NPC_TALKED, NPC_KILLED, EVENT_COMPLETED, CHOICE_MADE,
PLAYER_DIED, PLAYER_SPAWNED, GHOST_WATCHED (для mystery M4)
```

**Лимиты и политика:**
- ≤ 4096 событий на забег; переполнение → «sampling»: события ATTACK
  дуплицируются → каждая 2-я (флаг в RunHeader); остальное — truncation
  с log (ghost воспроизводит до конца лога, дальше — stand).
- Полные логи сохраняются для **последних 3 забегов**; остальные —
  `RunSummary` (seed, duration, death_cause, kills, rooms_visited,
  major_events: ≤16 самых значимых, legacy_earned, weapon_used,
  mystery_flags) — для Echo-врага, M1/M2, «Что изменилось».
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
  "player": { legacy: {id: tier}, shards: 120, memories: 3,
              total_deaths: 7, best_run: {...} },
  "runs": { "full": [ RunRecord x3 ], "summaries": [RunSummary xN≤64] },
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
  world_id: "forgotten_forest_v1",     # стабильный id мира
  run_count: int,
  discovered: [StringName],
  killed_npcs: [StringName],
  completed_events: [StringName],
  choices: {choice_id: int},
  opened_shortcuts: [StringName],
  unlocked_rooms: [StringName],
  dropped_items: [{item_id, room, pos, run}],   # ≤64, старые — «рассеиваются»
  ghosts: {last_run_ref, markers: [{room, pos, run}]},
  mystery_progress: {mystery_id: int_stage}
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

## 5. Ghost replay (алгоритм)

Вход: `RunRecord` (последний full-лог) + текущий AreaGraph (seed текущего
забега).

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
`attack`, `ranged_attack`, `interact`, `inventory`, `pause`, `ui_*`
(navigation), `debug_*` (release-off). Gamepad: стандартные бинды
(A=interact/attack по контексту? нет: A=interact, X=attack? — финальные
бинды в Phase 2/13; архитектура: один набор actions, два device-layout'а).
Touch (future): виртуальные кнопки = те же actions.

## 8. Audio

- Buses: `Master → (Music, SFX, Voice)`. Master-компрессор (Limiter) +
  (Reverb-эффект на SFX, лёгкий).
- AudioManager: `play_sfx(name, pos=null, bus="SFX")` (pooled: ≤16
  одновременных SFX, prioritized), `play_music(track, crossfade)`,
  `play_ambience(area_id)`.
- Наборы (MVP): footsteps (4 surfaces), weapon swing/hit (per weapon),
  enemy attack/death (per archetype), UI (6), ambient (3 areas), music
  (2: exploration, combat) + 1 stinger (mystery).
- Форматы: OGG (music/ambience), WAV (SFX short, 44.1k stereo).

## 9. VFX (MVP-набор, все — пул)

swing trail (weapon, 1-2 кадры), hit impact (спарки, 10–30 частиц),
death burst (40–60), dodge dust, leaf ambient (environment, 20–40,
Multimesh-альтернатива на Low), ember (костры), ghost shimmer (shader),
mystery glow (emissive pulse), boss telegraph (ground decal + particles).

## 10. UI screens (список + states)

HUD (health bar, stamina bar, weapon icon, interact prompt, ghost marker
«след впереди»), Inventory (12 grid + equipment 3 slots), Dialogue
(portrait, text, choices), Pause (resume/settings/quit-to-hub), Settings
(video: quality preset, resolution, vsync; audio: 3 vols + mute; controls
remap `?`), DeathScreen («вы умерли. Мир запомнил.» + что изменилось
(≤3 строки) + continue → 1 нажатие), RunSummary (статистика забега +
выбор legacy upgrade 1/3), Journal («Памяти» — mystery-записки).

## 11. Debug tools (F1–F8, release-off)

F1 overlay (fps, ms frame, draw calls, node count, phys bodies, ai budget
ms, seed, run state, ghost state, world-state summary);
F2 spawn enemy (цикл архетипов, курсором перед игроком);
F3 give weapon (цикл 3); F4 teleport (цикл локаций); F5 kill player;
F6 advance world state (simulated death: +run_count, ghost from current
run); F7 replay previous run (spawn ghost now); F8 clear temp run state.
Все — через `DebugTools` autoload, feature-tag `Release` убирает autoload.

## 12. Performance budget (цели; фактические замеры — Phase 16)

| Метрика | Бюджет (High, 1080p) | Как меряем |
|---|---|---|
| Frame time | ≤ 16.6 ms (60fps), P95 ≤ 22 ms | F1 overlay + `--benchmark` режим (tools) |
| Draw calls (хаб, полный) | ≤ 300 (env ≤150, chars ≤50, vfx ≤100) | F1 overlay (render-info из RenderingServer) + profiler |
| AI budget | ≤ 4 ms/frame суммарно (staggered) | замер в AI-тиках (debug) |
| Physics bodies (локация) | ≤ 40 | overlay |
| Particles живых | ≤ 300 (на экране) | overlay |
| Nodes (локация) | ≤ 2500 | overlay |
| Texture memory | ≤ 512 MB (High) | overlay (VideoMode?) / `get_render_info` |
| Load: cold start → title | ≤ 5 c (SSD, ПК-класс) | ручной замер (Phase 16) |
| Death → respawn | ≤ 2 c (hard target; ≤10 c UX-цель с UI) | замер в RunManager |
| Save write | ≤ 50 ms | замер в SaveManager (debug) |
| Save size | ≤ 5 MB | assert в тестах |
| Память процесса | ≤ 1.5 GB (High) | overlay/мониторинг |

Low preset: shadows off, fog simple, particles 50%, no post, textures 512 →
цель 30 fps floor (интеграционный GPU-класс), node count те же.

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
