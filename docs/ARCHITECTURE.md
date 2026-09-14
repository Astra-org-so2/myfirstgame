# AFTER YOU — Technical Architecture

Версия: 0.1 (Phase 0)
Связанные: TECHNICAL_DESIGN.md (data model, форматы), DECISIONS.md (ADR)

---

## 1. Принципы

1. **Модульность.** Каждая система — отдельный набор классов/сцен с одной
   ответственностью. Нет God-классов, нет giant-скриптов (правило: скрипт >
   400 строк — рефакторинг).
2. **Data-driven.** Поведение и баланс — в Godot Resources (`.tres`), логика —
   в классах. Новый враг/оружие/апгрейд = новый `.tres` (+ при необходимости
   класс-расширение), без переписывания систем.
3. **Минимум глобального.** Autoload'ы только для систем, которым нужна
   процесс-wide доступность (список в §6). Всё остальное — composition.
4. **Логика отделена от визуала** (headless-testability): вся игровая логика
   должна работать без рендера и (в пределах ограничений, ADR-002) без
   3D-физики — через порты.
5. **Детерминизм там, где нужно:** RNG с seed (RNG Streams), воспроизводимые
   забеги по seed, воспроизводимые ghost-replay'ы.
6. **Не фиксировать недоработанное.** Любая заявленная фича — полная
   реализация или явно помеченный статус (TODO-политика: TODO допустимы только
   в docs и в коментариях с issue-ссылкой; «placeholder logic» в production-
   путях — запрещён).

## 2. Структура проекта

```
myfirstgame/
├── project.godot
├── assets/                 # исходные ассеты (до импорта)
│   ├── models/  textures/  audio/  fonts/  vfx/  ui/
│   └── inbox/              # свежие скачанные пакеты до лицензии/проверки
├── scenes/
│   ├── player/             # Player.tscn + части (CameraRig, WeaponMount...)
│   ├── enemies/            # по сцене на архетип (Hollow/Remnant/Watcher/
│   │                       #  Mimic/Forgotten .tscn; 5 архетипов v2)
│   ├── boss/
│   ├── world/              # AreaHub.tscn, Area*.tscn (локации)
│   ├── rooms/              # hand-authored room-варианты (Room_Camp_A.tscn...)
│   ├── interactables/      # Chest, Door, Shrine, Note, Fire, Corpse...
│   ├── ui/                 # HUD, Inventory, Dialogue, Pause, Settings,
│   │                       # DeathScreen (Inheritance 1/3), RunSummary,
│   │                       #  WhatChanged, Journal (Notes)
│   ├── ghost/              # Echo.tscn (Passive/Memory/False: визуал +
│   │                       #  replay-контроллер; Combat = Remnant, enemies/)
│   └── systems/            # WorldEnvironment, LightRig, AudioRig
├── scripts/
│   ├── core/               # EventBus, Log, QualityManager, DebugTools
│   ├── gameplay/           # combat/, damage/, interact/
│   ├── player/             # PlayerController, MovementPhysicsPort, ...
│   ├── enemies/            # EnemyController (FSM base) + archetypes
│   ├── boss/
│   ├── world/              # AreaGraph, WorldDirector, WorldState,
│   │                       # RoomVariants, PersistentObject spawner
│   ├── progression/        # InheritancePicker, InheritanceResolver,
│   │                       #  TrustSystem (NPC-gate)
│   ├── run/                # RunManager, RunRecorder, RunEvent, RunHistory
│   ├── ghost/              # GhostDirector, GhostReplay, GhostController
│   ├── persistence/        # SaveManager, SaveData, SaveMigration
│   ├── ui/                 # UIManager + screens
│   ├── audio/              # AudioManager
│   └── utilities/          # math helpers, pool, timer, rng
├── data/                   # ВСЕ game-data ресурсы (.tres)
│   ├── weapons/  enemies/  items/  upgrades/  loot/
│   ├── rooms/    areas/    mysteries/  dialogues/  world/
├── shaders/
├── tests/                  # автотесты (в основном проекте) + QA-чеклисты
│   ├── runner.tscn / runner.gd   # test-runner (main scene при test-прогоне)
│   ├── unit/  integration/       # тест-классы (GDScript)
│   └── qa/                 # manual checklists (markdown)
├── tools/
│   ├── godot-node/         # headless Godot 4.7.2 rig (см. TEST_PLAN)
│   └── utils/              # gen-скрипты (ctex-генератор, wav→strm, ...)
├── docs/
└── export/                 # export presets + скрипты сборки
```

Обоснование отличий от «канонической» структуры: `data/` вынесен наверх
(видимость data-driven); `tests/` — в основном проекте (test-прогон
переключает main scene на время запуска, см. TEST_PLAN §2; в release
tests/ исключается из экспорта); `tools/godot-node/` — toolchain.

## 3. Ядро

### 3.1 EventBus (autoload)

Единая точка значимых событий (не для frame-логики!):
`player_died`, `player_spawned`, `room_entered`, `enemy_killed`,
`item_picked/dropped`, `chest_opened`, `npc_talked`, `npc_killed`,
`event_completed`, `choice_made`, `run_started`, `run_ended`,
`world_state_changed`.

Почему: RunRecorder, WorldDirector, AudioManager, UI — все подписчики,
никаких прямых зависимостей между ними. События — типизированные (Resource-
обёртки с полями), не «строки+dict».

### 3.2 DamageResolver (gameplay/combat)

Вход: `DamageRequest` (source, target, amount, type, knockback, position,
weapon_data, flags). Выход: `DamageResult` (applied, blocked, status effects,
kill). Единая точка: урон/леч/статусы/aggro/логирование-в-run/связи с
world-state (killed_npcs). Никакой «target.take_damage(...)» наугад.

### 3.3 FSM-база для врагов (enemies/EnemyController)

Состояния (Resource `EnemyStateData`: duration, speed multiplier, attack
data): `idle / detect / chase / attack / hurt / recovery / death` +
архетипные (например, `Watcher.reload`). Механика: `can_transition(to)`
таблица + `on_enter/on_tick/on_exit`. Данные поведения — в `EnemyData`
(health, detect radius, speeds, state data refs). Навигация — через
`NavigationServer3D` (A*, pathfinding в 5 Hz, не каждый кадр).

### 3.4 Movement + Physics Port (player/, ADR-002)

`PlayerController` (вход, тайминги, stamina, state: idle/walk/run/dodge/
hurt) **не знает** про CharacterBody3D напрямую — работает через
`MovementPort` (API: `move(velocity)`, `apply_gravity(delta)`,
`integrate(delta)`, `is_on_ground()`, `is_on_wall()`, `get/set_position()`,
`get_velocity()`).

Один класс, два бэкенда (подрезано ADR-022 — в wasm-риге нет кросс-файл
наследования скриптов):
- **ENGINE** (`_init(body: CharacterBody3D, ...)`): реальные CharacterBody3D
  вызовы (`velocity` + `move_and_slide`), `integrate()` — no-op;
- **MOCK** (`_init(null, ...)`): чистая математика (гравитация, плоский пол
  `floor_y`, AABB-стены с push-out по минимальной оси проникновения) —
  только в headless-тестах (в риге нет 3D-физики, ADR-002).

Состояние движения (`idle/walk/run/dodge/hurt`) — общий enum в
`player_state.gd` (dependency-free файл: логика, контроллер, визуал и тесты
читают его через preload-константу).

Почему: wasm-тест-риг не имеет 3D-физики (ADR-002); логика движения
(ускорение, dodge-окна, stamina-косты) тестируется в песочнице, физическое
«ощущение» — на референс-устройстве (Android, ADR-021) + на ПК (dev-QA).

## 4. Ключевые системы (кратко; детали — TECHNICAL_DESIGN)

- **RunManager** (autoload): states `Active/Dead/Summary`; создаёт RunState
  (seed, start pos, inventory, weapon), подписан на EventBus.
- **RunRecorder** (autoload, внутри RunManager): EventBus → compact
  `RunEvent[]` (см. schema) → flush в RunHistory (последние 3 full-лога +
  summary всех).
- **WorldDirector** (autoload): на старт забега применяет WorldState к миру
  (persistent objects: opened doors, dead NPCs, dropped items, unlocked
  rooms); валидация world-state (missing room/invalid id → safe default +
  log, не crash).
- **GhostDirector** (autoload): из последнего full-run-лога строит
  GhostReplay (таймлайн keyframes), спавнит ghost в хабе/посещённых
  локациях, управляет «следом» (старые runs → markes).
- **AreaGraph + RoomVariants** (world/): DAG локаций; каждая локация =
  набор hand-authored room-вариантов с **общими doorway-якорями** (ADR-003);
  seed выбирает варианты + связи + спавны + лут.
- **SaveManager** (autoload): versioned JSON, atomic write (temp+rename),
  CRC32 checksum, `SaveMigration` (v1→vN chain), safe defaults + recovery.
- **UIManager** (autoload): stack экранов, screen states
  (HUD/Inventory/Dialogue/Pause/Settings/Death/RunSummary/UpgradeSelection),
  input-routing (клавиатура/геймпад, touch-ready), не «куча CanvasLayer'ов».
- **AudioManager** (autoload): buses Master/Music/SFX/Voice, SFX pool,
  one-shot vs loop, settings (volumes, mute) → в save.
- **QualityManager** (autoload): Low/Med/High/Ultra → shadow, fog, particles,
  post (bloom/DoF/grain on/off), texture scale; сохранение в settings.
- **DebugTools** (autoload, `!Release` feature): F1 overlay (FPS, draw calls,
  node count, run state, seed), F2 spawn enemy, F3 weapon, F4 teleport,
  F5 kill, F6 world-state advance, F7 replay previous run, F8 clear temp run.
  В release-экспорте autoload отсутствует (feature tag).

## 5. Physics layers (фиксированная карта)

| Layer | Name | Кто |
|---|---|---|
| 1 | world | статика мира (пол/стены/руины) |
| 2 | player | CharacterBody3D игрока |
| 3 | player_hitbox | melee hitbox (Area3D, включается на кадр удара) |
| 4 | player_projectile | ranged снаряды игрока |
| 5 | enemy | враги |
| 6 | enemy_hitbox | melee hitbox врагов |
| 7 | enemy_projectile | снаряды врагов |
| 8 | interactable | предметы/двери/сундуки (Area3D trigger) |
| 9 | ghost | ghost (не collides с миром/игроком; только visibility) |
| 10 | trigger | зональные триггеры (encounter, mystery) |

Collision matrix: player↔world/enemy/ghost(no); hitbox'ы — только на
свои слои. Детали матрицы — в TECHNICAL_DESIGN.

## 6. Autoload'ы (полный список, 9 шт.)

`EventBus`, `SaveManager`, `RunManager`(вкл. RunRecorder), `WorldDirector`,
`GhostDirector`, `UIManager`, `AudioManager`, `QualityManager`,
`DebugTools` (release-off).

Правило: новый autoload = новое ADR + обоснование. Всё остальное — scene-
composition (сцена-локация содержит своих контроллеров, world-системы —
через signals к EventBus'у).

## 7. Зависимости (правила)

- `utilities` ← всё.
- `core` ← gameplay/world/progression/run/ghost (через EventBus signals).
- `persistence` ← только данные (SaveData-структуры) + SaveManager-вызовы;
  не знает про run-логи (берёт сериализуемый snapshot-объект).
- `ghost` ← `run` (читает RunEvent[]), `world` (локации/якоря). Не знает про
  `player` напрямую (replay = данные, не живой игрок).
- `ui` ← signals всех систем (только чтение состояния через запросы/сигналы;
  не мутирует игровое состояние, кроме UI-объектов).
- `enemies`/`player`/`boss` ↔ только через `gameplay/combat` (DamageResolver)
  и EventBus.
- Циклические зависимости — запрещены; реестр межмодульных зависимостей
  ведётся в этом документе, ручная проверка на каждом PR (автопроверка
  зависимостей — post-MVP инструмент).

## 8. Godot-конвенции

- GDScript 2.0, типизация везде (строгая, `typed arrays`), `@export` только
  для data-настроек сцен, не для «всего подряд».
- `class_name` для публичных классов; private-префикс `_` для внутреннего.
- Сигналы: `signal_x_y`? нет — snake_case, `player_died(pos: Vector3)`.
- Сцены: один корневой контроллер + узлы-«части»; логика не в узлах без
  причины (Mesh-узел с 400-строчным скриптом = smell).
- `.tres` ресурсы — immutable по духу (мутация = bug); данные забега — в
  RunState, не в ресурсах.
- Имена: классы и сцены — `PascalCase` (`Hollow.tscn`, `Hollow.gd`),
  файлы данных — `snake_case` (`hollow_data.tres`), действия/сигналы/
  переменные — `snake_case`.
- Error handling: `push_error`/`push_warning` + assertions в тестах; `null`
  не игнорировать (fail-fast в dev, graceful fallback + log в release).
- No `pass` как «обработал» (пустые обработчики — только с комментарием why).

## 9. Производительность (бюджеты — см. TECHNICAL_DESIGN §12; здесь принципы)

- AI: staggered updates (каждый враг обновляется в своём слоте; бюджет 4ms/
  frame на все AI), distance culling (idle за 40m — не тикает), state-based
  (hurt/death — минимальный tick).
- Particles: пул GPUParticles (≤8 активных эмиттеров, ≤100 живых частиц/
  эмиттер), `one_shot` + пул-рециклинг, `process_material` без шейдерных
  чудес.
- Draw calls: Multimesh/instancing для леса (деревья/кусты/камни — 4-6
  Multimesh-слоёв, не 300 MeshInstance), LOD у крупных объектов.
- Физика: ≤12 активных тел в локации; ghost — без физики (layer 9,
  `collision_layer = 0, mask = 0`); снаряды — pooled, `move_and_slide` →
  `raycast` где возможно.
- Память: текстуры ≤1024px (High) / ≤512 (Low), VQ-компрессия (VRBC/ETC2
  для мобильных — future), общий target texture memory ≤ 512MB (High).
- `_process` — только у активных участников (игрок, активные враги, UI-
  анимации); всё остальное — `_physics_process`/signals/таймеры.

## 10. Мобильная готовность (архитектурно)

- Input: все действия — через InputMap (actions, не клавиши); virtual
  touch-controls = отдельная UI-сцена, биндящая те же actions (добавление =
  сцена + данные, не код).
- Quality settings (Low/Med/High/Ultra) покрывают мобильный Low.
- Без editor-only фич; без тяжёлых шейдеров по умолчанию (Forward+/Vulkan
  mobile-first, ADR-021; mobile renderer = опция для слабых устройств,
  архитектура не зависит от renderer-выбора — фиксация замерами Phase 16).
- Файлы: scene-размер ≤ ~500 узлов/локация; текстуры — quality-scaled (отдельные
  `.import`-настройки per quality — tooling в tools/utils).

## 11. Что здесь НЕ решение (см. ADR / design-доки)

- Выбор конкретного rigged-персонажа (Phase 2, ASSET_GUIDE).
- (Решено в design-фазе: 3 weapon-архетипа BLADE/HAND CANNON/ECHO STAFF —
  WEAPON_DESIGN; платформа = **Android first** — ADR-021; имя = Eli —
  CHARACTER_BIBLE; The Child = invulnerable — CHARACTER_BIBLE §5.)
