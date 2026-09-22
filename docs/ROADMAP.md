# AFTER YOU — Roadmap (фазы, вехи, exit-criteria)

Версия: 1.5 (Phase 15 закрыта, GDD v2.0). Формат статуса фазы
(обязателен при закрытии):
`STATUS / IMPLEMENTED / TESTED / KNOWN ISSUES / NEXT`.

## Вехи (milestones)

- **M1 — «Движется и бьёт»** (Phases 1–4): запуск, игрок, окружение, бой.
- **M2 — «Цикл работает»** (Phases 5–8): враги, лут/прогрессия, комнаты,
  run-система.
- **M3 — «Идентичность»** (Phases 9–12): ghost, world memory, mysteries,
  boss.
- **M4 — «Полиш»** (Phases 13–16): визуал, аудио, save/load/recovery,
  performance.
- **M5 — «Релиз»** (Phases 17–19): QA, release build, final review.

---

## PHASE 0 — Pre-production
Scope: GDD, Architecture, Technical Design, Asset Guide, Test Plan,
Roadmap, Decisions + self-review.
Exit: документы согласованы; открытые вопросы (GDD §15) — на решении
владельца; инструментальный вопрос (движок в песочнице) решён (ADR-002).
STATUS: DOCS COMPLETE (15/15, GDD v2.0 + docs/design/*); вопросы GDD
§15 Q1–Q4 — **решены владельцем** (платформа = Android first → ADR-021;
локализация = EN-only MVP → ADR-013; имя = Eli; The Child = invulnerable;
см. GDD §15).

## PHASE 1 — Empty runnable project
Scope: project.godot (4.7.2, **renderer Forward+ (mobile-first, ADR-021)**,
**screen: landscape + stretch (aspect/safe area)**, input map (touch +
kb/m + gamepad actions), layers, rendering defaults, fog),
main scene (пустой хаб-заглушка с камерой), структура папок;
`tools/run_tests.sh` + `tests/runner.tscn|gd` + 1 smoke-тест (runner
стартует, печатает, quit(0)); harness-режим `--tests` (main-scene swap).
Autoload'ы НЕ создаются заранее — каждый появляется с фазой своей
системы (ADR-009).
Exit: проект стартует в редакторе (владелец) И в риге (песочница) без
ошибок; input map полный (touch + dev); landscape/stretch на месте;
структура по ARCHITECTURE.
Risks: — (инфраструктура проверена в Phase 0 spike).
STATUS: COMPLETE (риг-часть) — см. отчёт ниже.
IMPLEMENTED: project.godot (4.7.2, Forward+, landscape + canvas_items
stretch/aspect expand, ETC2/ASTC import, locale en, полный input map:
30 actions — move/sprint/dodge/attack/ranged/interact/inventory/pause/
camera_*/ui_*/debug_f1-f9 с kb/m + gamepad-биндами), scenes/main.tscn
(hub-заглушка: WorldEnvironment с height-fog, DirectionalLight3D,
Ground, HubMarker, Camera3D), структура папок по ARCHITECTURE §2
(46 каталогов), tests/runner.tscn|gd (39 smoke-тестов + filter-режим
all/unit/integration), harness: watchdog (124) + filter-канал.
TESTED: риг — 39/39 PASS (1 boot + 30 input-map + 1 load + 5
main-scene-структура + 2 mobile-config); негативные пути: fail → rc=1
(скрач-проект с удалённым action), hang → rc=124 (watchdog 12 s).
KNOWN ISSUES: запуск в Godot-редакторе на ПК владельца НЕ проверен
(песочница без GPU/редактора) — первый запуск в редакторе = чек-лист
Phase 1 (см. ниже); render-качество Forward+ — по определению не
видимо headless (замер Phase 16).
NEXT: чек-лист редактора владельцу (5 мин), затем Phase 2 (Player).
**Чек-лист Phase 1 для владельца (редактор, 5 мин):** (1) открыть
проект в Godot 4.7.2 → 0 ошибок в Output; (2) F5 → виден hub (туман,
свет, квадрат, земля) с камеры; (3) Project Settings → Input Map:
actions на месте; (4) Display: landscape, stretch canvas_items/expand;
(5) Rendering: Forward+; ETC2/ASTC включён.

## PHASE 2 — Player
Scope: PlayerController + camera rig (orbit, collision, distance FOV,
**drag-камера (touch)**), movement (run/sprint/dodge со stamina,
MockMovementPort + EngineMovementPort), CharacterBody3D, animation state
machine (idle/walk/run/dodge/hurt), **touch controls (вирт. джойстик +
кнопки + drag-камера; layout `data/ui/touch_layout.tres` — ADR-021)**,
placeholder-персонаж (примитивы, ADR-005) или rigged-CC0 (если найден —
ASSET_GUIDE §4).
Unit: movement logic (ускорение/затухание, dodge-окна, stamina-косты),
camera math, touch-layout (позиции per aspect). Integration:
respawn-позиция.
Manual: qa_phase2_movement.md (+ touch-чек-лист на устройстве).
Exit: движение «приятное» (чек-лист), dodge i-frames работают
(замер окна), 60fps в риге-тиках, touch-контролы играбельны (на
устройстве, ADR-021), 0 ошибок.
STATUS: COMPLETE (риг-часть) — см. отчёт ниже.
IMPLEMENTED: PlayerController (CharacterBody3D: ввод→logic→port,
сигналы state/dodge/stamina, take_hit/respawn, held-edge dodge),
PlayerMovementLogic (чистая state-machine: idle/walk/run/dodge/hurt,
stamina+exhaustion, i-frames [0.05, 0.25] c из dodge 0.35 c, cooldown
0.4 c, hitstun + knockback с экспон. затуханием), MovementPort (один
класс, ENGINE/MOCK-бэкенды — ADR-002/ADR-022), CameraRig (орбита
yaw/pitch с лимитами, wall-clip RayCast3D + FOV-компенсация, MMB-drag +
gamepad stick/dpad, touch-drag), PlaceholderVisualAnim (процедурный
placeholder, ADR-005: bob/lean/lurch/hurt-flash через albedo),
touch-слой (Joystick + 4 кнопки + CameraZone, layout
`data/ui/touch_layout.tres`, safe-area clamp, JoystickProvider push-\
seam), PlayerData-ресурс (data-driven, validate()), main.tscn
(hub + Player + 4 стены + SpawnPoint + TouchControls). АРХИТЕКТУРА:
весь проект переведён на контракт ADR-022 (preload-константы, без
кросс-файл class_name/наследования — ограничение wasm-сборки рига).
TESTED: риг — 120/120 PASS (42 smoke + player_data 16 +
movement_logic 29 + camera_rig 14 + touch_layout 4 + player_scene
15: движение вперёд/стоп, dodge с i-frames (замер окна), hitstun→
рекавери, respawn-сброс — через mock-порт, детерминированный ручной
clock), 0 script-ошибок в прогоне; 60 Hz физ-тик в риге подтверждён
счётчиком кадров (после `GodotInstance.resume()` — harness);
негативные пути: fail → rc=1, фильтры unit/integration — корректны.
Риг выявил и пойман баг production: аргументы `Input.get_vector`
(оси y были перепутаны — игрок бы ходил «назад»).
KNOWN ISSUES: риг без 3D-физики/рендера (ADR-002/ADR-022):
«ощущение» движения, wall-clip камеры, 60 fps на GPU, touch-эргоника
— только редактор/устройство (ADR-021); take_hit = hitstun+knockback
(damage/HP — Phase 4); числа движения — baseline (тюнинг Phase 4/16).
NEXT: чек-лист qa_phase2_movement.md владельцу (ПК + Android),
затем Phase 3 (First environment).
**Чек-лист Phase 2 для владельца:** ПК-редактор — см. раздел A
tests/qa/qa_phase2_movement.md (запуск без ошибок, движение/
спринт/dodge/камера, respawn из debugger); Android-устройство —
раздел B (touch-слой, джойстик, drag-камера, aspect 20:9, 60 fps);
feel — раздел C (закрепить в PERF_REPORT в Phase 16).

## PHASE 3 — First environment (The Forgotten Forest)
Scope: camp-hub (WORLD_BIBLE §4.1): floor, paths, 8–12 деревьев
(Multimesh), костёр (warm-акцент), 3 палатки, note stand (заглушка),
туман (80%, layer normal) + sky (генеративный/CC0), DirectionalLight
(4000K), landmark: watchtower-силуэт + gate-силуэт; pillar
(A2/K3: «YOU HAVE BEEN HERE BEFORE.»); NPC-заглушка (Mara, camp);
interact-заглушка (подход → prompt). 8 зон — silhouette-маркеры
(локация-заглушки, не геометрия — Phase 7).
Unit: room/area data-валидация.
Manual: qa_phase3_world.md (визуал, FPS, load, палитра/слои).
Exit: «выглядит красиво» за 30 c (скриншоты-референсы), FPS по
бюджету; палитра/слои по WORLD_BIBLE §1/§1.1.
STATUS: COMPLETE (риг-часть) — см. отчёт ниже.
IMPLEMENTED: data-driven лагерь: `CampLayout`
(`data/world/camp_layout.tres`: 10 деревьев, 3 палатки, 8 зон с
углами, тропа, спавн, landmarks, validate() с 12 правилами),
`CampWorld` (собирает сцену из данных: MultiMesh-деревья (3 draw
calls), тропа-сегменты, костёр + тёплый OmniLight (единственный
тёплый свет), 3 палатки (повёрнуты к огню, per-tent-материал),
4 интерактивных предмета, пассивный стол с кружками, 8
zone-monoliths (silhouette, Phase 7 заменит), landmarks
watchtower/gate), `Interactable` (poll расстояния, radius 2.4 m,
Label3D-промпт, held-edge «interact», сигнал `interacted(Node3D)`,
0.5 s pulse — без Area3D: rig-safe), 10 template-сцен
(`scenes/world/*.tscn` — примитивы по палитре WORLD_BIBLE §1,
axis-aligned: вращения — в коде), `player.get_body_position()`
(duck-typed позиция для Interactable, mock-safe). main.tscn:
CampWorld вместо hub-заглушки, туман 0.02/18, sun (1, 0.85, 0.72)
4000K, стены — collision-only.
TESTED: риг — 150/150 PASS (43 smoke (+CampWorld) + player_data
16 + movement_logic 29 + camera_rig 14 + touch_layout 4 +
camp_layout 15: .tres-валидация, 8–12 деревьев, 3 палатки, 8 зон,
наративные якоря (Mara у огня <2.5 m, чайник ≤2.0 m, столб на
подходе), 7 negative-путей + player_scene 15 + camp_scene 14:
сборка из данных (10 деревьев, 8 zone-gates на данных углах, 3
палатки, FireLight, спавн из данных), interactable-прототип
(промпт рядом, edge-сигнал ровно 1 раз при удержании, скрытие
при уходе) — через mock-порт, детерминированный ручной clock).
Риг выявил и пойман production-баги: MultiMesh TRANSFORM_2D по
умолчанию (деревья были бы в origin), double add_child в _place.
ADR-022 дополнен пунктами 12–15 (ConeMesh/Basis-конструкторы/
PackedVector3Array/find_children — частичная регистрация).
KNOWN ISSUES: риг без рендера (ADR-002/ADR-022): «красота» 30 c,
туман/свет/палитра, FPS на GPU, палитровые артефакты — только
редактор/устройство (ADR-021); интеракты — прототипы (эффект —
Phase 4/10/11); 8 зон — silhouette (Phase 7); деревья/предметы —
примитивы (art-pass — Phase 13); draw calls ~60 оценочно
(формальный замер — Phase 16).
NEXT: чек-лист qa_phase3_world.md владельцу (ПК-редактор +
Android + дизайн-чек), затем Phase 4 (Combat).
**Чек-лист Phase 3 для владельца:** tests/qa/qa_phase3_world.md —
раздел A (редактор: запуск без ошибок, лагерь читается, огонь —
единственный тёплый свет, интеракты-прототипы, landmarks в тумане),
раздел B (Android: смена/туман без артефактов, USE-интеракты,
60 fps, thermal), раздел C (дизайн: мотив «дом», no-filler,
сезы A2/A8/A9).

## PHASE 4 — Combat
Scope: weapon (1: BLADE, WEAPON_DESIGN §1: combo 3 + Riposte),
attack (hitbox-кадры), DamageResolver, player damage + death,
knockback, hit reaction, hit-stop, camera shake, impact VFX (пул),
SFX (генеративные заглушки, prototype-статус), 1-2 test-мишени
(статичные, не «временные враги» — test-объекты в tests/, не в игре).
(cannon/staff — Phase 6-8: после run-системы; FIRST BLADE — Phase 12.)
Unit: damage math, combo timing. Integration: hit → damage → death.
Manual: qa_phase4_combat.md (feel-матрица).
Exit: «бой ощущается хорошо» (чек-лист) — критерий, не мнение.
STATUS: COMPLETE (риг-часть) — см. отчёт ниже.
IMPLEMENTED: BLADE (data/weapons/blade.tres по WEAPON_DESIGN §1:
25/25/30 dmg, 1.2/1.2/1.5 s, U3-thrust 2.6 m, Riposte 0.5 s окно /
30 s CD / stun 1.5 s / 15 dmg) + WeaponData/WeaponHit (schema
покрывает все 3 архетипа + FIRST BLADE — новые оружия = data),
WeaponLogic (чистая combo-машина: buffer, combo-окно 0.5 s, special;
reset на respawn), WeaponController (held-edge input, sector-hitbox
на активных тиках — АDR-023, per-swing hit set, stamina-косты,
riposte-counter), DamageResolver (единственная точка урона:
DamageRequest → DamageResult, registry, i-frame/dead/unknown
guards, EventBus.target_killed), CombatTarget (hp/invuln/stun,
сигналы), HitStop (delta-scaler: движение+оружие.freeze вместе,
камера живёт), VfxPool (8 flash-инстансов, reuse без роста),
SfxLibrary (процедурные WAV: swing/hit/riposte/hurt — детерм.,
prototype-статус) + SfxBus (пул 3 player), HurtVignette (fade),
EventBus-autoload (player_died/player_spawned/target_killed —
ADR-023), CameraRig.add_shake (impulse + exp decay), PlayerController:
CombatTarget + can_act/get_facing/spend_stamina + смерть → EventBus
→ auto-respawn 2 s (RunManager заберёт в Phase 8) + weapon-reset на
respawn + spawn-позиция игрока из CampLayout (починка Phase 3:
игрок стоял в origin, не на спавне), input: action `special`
(R/тач SPC, 5-я кнопка touch_layout), MovementLogic.spend_stamina.
TESTED: риг — 325/325 PASS (43 smoke + EventBus + special-action;
player_data 16 + movement_logic 29 + camera_rig 14 + touch_layout
4 + camp_layout 15 + weapon_data 14 + weapon_logic 13 +
damage_resolver 11 + combat_utils 14 (hitstop/vfx-pool/SFX-байты) +
player_scene 15 + camp_scene 14 + combat_scene 37: одиночный удар
25 (source/target/result/сигнал), full combo 80 (buffer-цепочка),
урон по игроку (hp/hitstun/vignette/hurt-cue), i-frame block
(no hp loss), Riposte (stun 1.5 s + 15 counter + CD 30 s + cues),
смерть (EventBus.player_died 1x) → respawn (hp 100, spawn-pos,
player_spawned 1x), stun-блок атак). Риг поймал production-баги:
combo-окно/CD утекали через respawn (→ weapon reset), игрок не
ставился на spawn (→ main_scene).
KNOWN ISSUES: риг без рендера/звука/физики: feel-матрица
(hit-stop/shake/vignette/звук по каждому удару), 60 fps в бою,
тач-эргоника SPC — только редактор/устройство (ADR-021);
test-мишени не в игре (Phase 5 — живые враги); HP-UI/death screen
— Phase 8/13; SFX/VFX — prototype (Phase 13/14); feel-цифры —
baseline (blade.tres), тюнинг по feel-матрице.
NEXT: чек-лист qa_phase4_combat.md владельцу (ПК + Android +
feel-матрица), затем Phase 5 (Enemy system).
**Чек-лист Phase 4 для владельца:** tests/qa/qa_phase4_combat.md —
раздел A (редактор: U1/U2/U3/combo/reset, Riposte-тайминг, урон по
игроку + i-frames, смерть/respawn; test-цель через debugger —
референс combat_scene_test.gd), раздел B (Android: тач ATK/SPC/
DODGE, 60 fps, звук, thermal), раздел C (feel-матрица — заполнить
и зафиксировать в PERF_REPORT Phase 16).

## PHASE 5 — Enemy system (5 архетипов v2)
Scope: EnemyController FSM-base + navigation (injectable navmesh-source,
pathfinder в чистом коде) + 5 архетипов (Hollow/Remnant/Watcher/Mimic/
Forgotten, ENEMY_DESIGN) по EnemyData; aggro/targeting; staggered
updates; telegraphs (0.4–0.8 s); memory_stats-агрессия (slayer/
runner/explorer, ENEMY_DESIGN §7). Специфика: Remnant builder (run-
данные, ADR-004/ADR-011); Watcher: наблюдение → memory anchor
(WORLD_STATE); Mimic: зеркало dominant_style (punish-паттерн);
Forgotten: шёпот (фразы из истории игрока, data pool).
Unit: FSM transitions, per-archetype invariants, Remnant builder,
Mimic-style resolve, anchor-set.
Integration: spawn-таблица, staggered slots.
Manual: qa_phase5_enemies.md (15-мин сессия/архетип).
Exit: 5 разных на поведение врагов; AI-бюджет ≤4ms.
STATUS: COMPLETE (2026-09-15). ADR-024 (code-built визуал +
staggered-бюджет).
IMPLEMENTED: `scripts/gameplay/enemies/` — EnemyData (11 .tres:
3 Hollow + 2 Remnant + 1 Watcher + 3 Mimic + 2 Forgotten),
EnemyLogic (чистая FSM: IDLE/CHASE/WINDUP/ACTIVE/RECOVERY/HURT +
OBSERVING/FOLLOW/VANISH (Watcher) + WANDER (Forgotten) +
RETREAT/LEAVE/SPEAK, telegraph-пол 0.3 s, EPS на float-границах),
EnemyController (визуал-примитив + combat-target + атаки через
DamageResolver + Label3D-реплики), EnemyDirector (staggered-
бюджет: 10 Hz/враг, шаг = фактическое игровое время, якорь
count*period без дрейфа, spawn-таблица, anchor ≤2/run,
remnant_met, enemy_killed → EventBus), NavGraph (A* на графе
лагеря 17 узлов/32 рёбер из camp_nav.tres), MemoryPath
(ring-buffer); `scripts/gameplay/memory_stats*.gd` —
dominance-статистика (slayer/runner/explorer, ENEMY_DESIGN §7) +
пороги-данные + tracker (kills/fled/style); data:
data/enemies/*.tres + attacks/*.tres + camp_spawn_table.tres
(`Array[SpawnEntry]` — ADR-022/024) + camp_nav.tres +
memory_stats_thresholds.tres; main_scene: `_setup_enemies`
(director + tracker + nav + player-noise подписки).
TESTED: риг — 478/478 PASS, из них новые 193 (enemy_data 46 +
enemy_logic 65 + nav_memory 23 + memory_stats 28 + enemy_scene
31: spawn 5/5, stagger ≤2/кадр, Hollow chase+hit 15, i-frames
блок вражеской атаки, Watcher 999/anchor, Remnant encounter→
leave→flag, Forgotten wander, kill→bus→MemoryStats→despawn).
Риг поймал production-баги: enemy-логика шла в 1/6 времени
(stagger-шаг = кадр-дельта, не бюджет врага), дрейф фазы
`next += period`, i-frame-пуш игрока на тик устаревший (→ push
после logic-update), EV_SPEECH не эмитился, memory_path ring
терял данные на wrap, preload-путь enemy_state.gd.
KNOWN ISSUES: визуал = примитивы (ADR-024; финальный облик +
feel-телеграфы — Phase 13/feel-матрица); AI ≤4 ms — риг не
меряет устройство: замера нет, чек-лист C (qa_phase5_enemies) —
обязательный device-шаг; шёпот Forgotten — data-pool (3 фразы),
история-контекст — Phase 10 (world memory); Remnant-builder
(run-данные) — данные + builder-ядро есть (memory_stats),
«бьёт как игрок» — Phase 9 (best-run); nav-граф — Phase 3 layout
(navmesh-источник injectable).
NEXT: чек-лист qa_phase5_enemies.md владельцу (ПК + Android +
AI-бюджет §C), затем Phase 6 (Progression, no currency).
**Чек-лист Phase 5 для владельца:** tests/qa/qa_phase5_enemies.md —
раздел A (редактор: 5 архетипов по одному, telegraphs, i-frames
vs враг, Watcher-наблюдение, kill→MemoryStats), раздел B (Android:
60 fps с 5 врагами, thermal, тач), раздел C (AI-бюджет ≤4 ms —
замер ОБЯЗАТЕЛЕН, цифры в PERF_REPORT Phase 16).

## PHASE 6 — Progression (no currency)
Scope: inventory (12 slots + equipment), weapons ×3 (BLADE/HAND
CANNON/ECHO STAFF, data, scripted pickup — WEAPON_DESIGN §5),
Inheritances (15: MVP-pool 12 = 8 базовых + 4 NPC-gated; death
screen: 1 из 3, UX ≤10 s; PROGRESSION_DESIGN §1), NPC trust (0–2,
gift = Inheritance), NPC death = perma-цена (наследие недоступно),
consumables (3 костра). **Нет валюты** (GDD v2.0 §6.5).
Unit: inventory, upgrade resolve (1/3, perma, NPC-gate), trust.
Integration: pickup-scripted (weapon), death→inheritance flow.
Exit: полный прогресс-цикл работает; data-driven (новый
Inheritance = .tres); NPC-gate проверен (смерть NPC → наследие ×).
STATUS: COMPLETE (2026-09-17). ADR-025 (уровни 2–3 = эскалация в
данных) + P0-регрессия тач-слоя (Control._input_event не
существует в Godot 4 — wiring через gui_input, touch_scene-тест).
IMPLEMENTED: WorldState (data/npcs/npc_state.tres, flags,
inheritance levels 0–3, weapon_X_found, npc-записи alive/trust/
interactions/help_done) + InheritanceManager (пул = 12 basic +
4 NPC-gated (NPC жив и trust ≥ 1) + post-MVP (поведенческие
гейты, в MVP data-disabled); roll «1 из 3»: до 2 новых + повторы
(макс. 2 на Inheritance); перманентный apply) + InheritanceEffects
(эффективные статы: blade/cannon/staff/player/world — ADR-025
таблица уровней) + NpcTrust (0–2: 2 разговора + help → 1; 4 +
help + memory-stat → 2; kill → 0, навсегда) + InventoryLogic
(12 слотов, кап 3 костра, use/first_of) + ItemData (camp_fire.tres:
heal 30, use_line). Оружие ×3: BLADE (Phase 4) + HAND CANNON
(windup 1.8 s, снаряд 15 m / 3° spread, 5 патрон + 1 reload 1.5 s,
Break 2×dmg CD 40/30/25, шум будит врагов) + ECHO STAFF (Shatter
40 / Read 12 м маркеры / Soothe 5–7 с (EnemyLogic.SOOOTHED, новый
state) / Disrupt — честный 0 до Phase 9; каст 1.5 s, отмена
уроном) — WeaponData-расширение (ranged/staff поля + validate),
RangedWeaponController (детерм. spread seed), StaffController,
WeaponLoadout (adopt BLADE, add на pickup, Q-switch, update
только equipped, reset_all per run). Сцена: 4 NpcNode (капсулы по
NPCData, Mara = её Phase-3 модель (MaraAnchor-reparent),
killable 50 hp, trust-флоу, death = флаг + trust 0 + EventBus
npc_died, реплики на Label3D), 2 WeaponPickup (cannon/staff,
демо-позиции лагеря; боевые зоны — Phase 7; перманентно),
костёр (EMBER: heal vs холодная реплика), CampDrop (1/10, 3/run),
DeathScreen (3 карточки: имя + строка без цифр; touch + mouse;
8 с → seeded-выбор мира; death_choice_pending держит respawn —
UX ≤ 10 s), InventoryPanel (4×3, touch-tap слота), Toast (3 s),
EchoStep (afterimage 0.5 s + стазн смотревших), SECOND CHANCE
(CombatTarget.guard_charges: смертельный удар → HP 1 + free-dodge
с i-frame 0.5 s, per run), SfxLibrary +shot +pickup
(процедурные). Тач-регрессия: gui_input (Control._input_event не
существует в Godot 4 — CollisionObject-виртуаль; Phase 3 wiring
бы мёртв на устройстве).
TESTED: риг — 620/620 PASS (unit 473 + integration 147). Unit:
inheritance 37 (пул/roll/повторы/уровни/NPC-gate), inventory 15,
inheritance_effects 29 (композиции: sharp+flow, slow_burn+
quiet_step, perma). Integration: progression_scene 33
(pickup-scripted: prompt→(E)→loadout+2/WorldState/флаг/BLADE
equipped/Q-switch/повтор без дублей; NPC trust: 2 разговора ≠
trust 1, help → 1 → EMBER в пуле; смерть: флаг/trust 0/EMBER из
пули навсегда; костёр cold vs EMBER full-heal; костёр-предмет
bag→tap→+30→consumed), combat_scene death flow (экран ждёт
выбора, press(0) → owned+1 перманентно, respawn на спавне),
touch_scene 6 (регрессия gui_input: press/release/far/drag/
orbit), camp_scene/combat_scene/enemy_scene/player_scene —
без регрессий. Manual: tests/qa/qa_phase6_progression.md
(A: ПК-редактор; B: touch-устройство; C: замеры).

## PHASE 7 — Procedural rooms (13 modular)
Scope: AreaGraph (camp-hub + 8 зон, DAG), 13 modular rooms
(GDD v2.0 §11; no-filler чек-лист ENV_STORYTELLING §3 — ≥1 из 5
целей per room), RoomData/variants (2–3 варианта на локацию, общие
doorway-якоря, ADR-003), генератор (seed, weights, connections),
валидатор (по TECHNICAL_DESIGN §6), fallback-раскладка. Handcrafted
(не процедурные): camp, Undercroft (boss-арена), gate-подножие.
Unit: детерминизм, изоляты, двери, spawn-пробы.
Integration: room transitions (прохождение графа).
Exit: 100 сгенерированных seeds проходят валидацию (тест-прогон),
нет «невозможных» раскладок; no-filler чек-лист пройден (13 rooms).
STATUS: COMPLETE (2026-09-17). ADR-026 (геометрический
спавн-проф + walk-through-двери в headless-риге; generator =
чистая функция (seed, ws, pool) → RunLayout).
IMPLEMENTED: RngStreams (4 независимых потока world/encounter/
loot/event от master-seed, splitmix64 — signed-децимальные
константы: GDScript не принимает hex > INT64_MAX) + данные:
35 RoomData (9 handcrafted: camp-hub с 8 круговыми гейтами,
8 zone-entries, boss-арена + **13 modular × 2 варианта** —
коридоры/перекрёстки/комнаты боя/лута/загадок/укрытий;
ADR-003: doorway-якоря идентичны между вариантами, варианты
дифференцируются obstacle/ambient; no-filler: ≥1 из 5 полей
gameplay/visual/narrative/discovery/interaction на каждую —
GDD §9) + 9 AreaData (pool + weights + connections; DAG:
camp → 7 зон → undercroft (единственный sink); mine/gate →
undercroft, camp-гейт подcroft sealed — ADR-016) + 7
spawn-таблиц зон. RunGenerator: 1–3 комнаты на зону
(взвешенный сэмпл по room-id без повтора; вариант по
world-потоку), цепочка entry→exit, все двери RESOLVED
(кросс-зона: to_area+entry / to_room+to_room_area — boss
entry-двери на последнюю комнату источника), раскладка вдоль
−Z (door_b↔door_a совпадают), spawны = КОПИИ таблиц (.tres
неизменяемы) по encounter-потоку на enemy_spots.
LayoutValidator (обязательный): hub+boss, двери резолвятся,
BFS-достижимость (boss IFF открыт вход; sealed undercroft =
валидно), изоляты, **геометрический spawn-проф** (footprint/
obstacle/дверной проём — ADR-026), монотонность сложности
(нет шортката в boss из camp), no-filler в глубину.
Fail → seed+1 ≤8 → reference layout + log. Сцена: RoomNode
(примитивы: пол/стены с проёмами/монолитные рамы/obstacles/
ролевая прореха/PointLight без теней — мобильный бюджет) +
ZoneWorld (уровень = цепочка комнат уровня; nav = центры +
точки дверей; **walk-through** триггер: дистанция до проёма
<1.05 м + cooldown 1 с — ADR-026) + main: _enter_level
(director.clear → load_nav → start(таблица уровня) →
визуалы → fixed_loot-оружие → туман зоны); **production
оружие: cannon → Mine, staff → Old Shrine (fixed_loot;
демо-позиции лагеря удалены)**; CampLayer (NPC/костёр/drops —
скрыты в зонах); respawn → camp.
TESTED: риг — **668/668 PASS** (unit 506 + integration 162).
Unit: rooms сьют — RngStreams (детерминизм/независимость/
interleave), данные (35 комнат валидны, 13×2 варианта,
ADR-003-якоря, no-filler, 9 зон), генератор (seed-1 валиден,
детерминизм A/B/A', **100/100 сидов валидны, 0 fallback**,
ws-механизм условных рёбер, spawны на спотах, .tres
неизменяемы), валидатор (отказы: сломанная дверь, спот в
obstacle, no-filler). Integration: progression_scene —
zone transitions (camp→Mine walk-through → camp_exit → Mine;
**Mine→Undercroft forward-дверь → entry_mine назад**;
nav-радиус 26→~33 м при смене; explored_pct = 2/8 = 25),
cannon pickup в Mine
(данные + сцена, перманентно, выход → пьедестал исчезает),
staff — данные Shrine; camp/NPC/костёр/touch — без
регрессий. Exit-критерии: 100 сидов ✓ (unit-прогон),
no-filler 13 ✓ (валидатор + данные), transitions ✓. Manual:
tests/qa/qa_phase7_rooms.md.
KNOWN ISSUES: seed сессии фиксирован (20260917) — RunManager
принесёт seed ранa (Phase 8); loot_spots кроме fixed_loot —
пусты до LootTable (Phase 8); event_spots — визуальные
(Phase 8/10); физ-проф по collision-mesh — в реальном
движке (ADR-026 п.1).
NEXT: PHASE 8 — Run system (scripted first 10 min).

## PHASE 8 — Run system (scripted first 10 min)
Scope: RunManager (states), RunRecorder (EventBus → RunEvent[],
14 байт, ≤4096), RunHistory (все runs, MVP ~150 КБ; RunSummary для
старых — post-MVP, ADR-004), RunSummary, death flow (death screen:
Inheritance 1/3 + «Что изменилось» ≤5 строк, WORLD_STATE_DESIGN §9.2),
respawn в camp (≤2s hard / ≤10s UX, GDD §12), `last_death_pos` (→
мумия #5), first death window ~20 мин (A19, не таймер), RUN 02
door-open (`run_02_door_open`), **scripted first 10 min по
FIRST_30_MINUTES** (A1–A17: pillar, blade, Hollow, camp+note,
figure, combat, sealed door).
Unit: recorder limits, events roundtrip, A-якоря (triggers).
Integration: death→save→resume; A-якоря по таймлайну (window).
Exit: забег → смерть → новый забег: полный цикл; «Что изменилось»
читается; A1–A17 срабатывают (playtest по FIRST_30_MINUTES).
STATUS: COMPLETE (2026-09-18). ADR-027 (seed ранa: RUN 1 =
session-seed, run N>1 = derive_seed; реконструкция на respawn
синхронная, 41 ms в риге; «Что изменилось» = 5 самых свежих
изменений).
IMPLEMENTED: RunEvent (14 байт, 19 типов) + RunRecorder
(≤4096, pin/сэмплирование, JSON [t,type,room,x,y,z,ry,target,
data]) + RunRecord/RunHistory (все runs, 5 МБ-кэп → RunSummary)
+ RunManager (states PLAYING/DEAD/RESPAWNING; seed-политика
ADR-027; last_death_pos; changed_lines) + death flow:
bus.player_died → RUN 02 availability-флаги (cannon/staff/
kettle) → on_player_died → death screen 1/3 (P6) →
request_respawn → **синхронная реконструкция** (begin_next_run
→ генератор+валидатор → zone_world.setup (NPC → holding) →
_enter_level(camp) → on_run_started → spawn) +
FirstRunDirector (A1–A17 event-driven: столб A2, первый взмах
A3 (swing_started), первый Hollow A5 (след = first_kill_pos,
метка в лагере RUN 02+), лагерь+note A7, фигура A10 (30 м,
0.6 с голова, 1 s fade, 10 следов), Ния A11, костёр деревни
A12, шахта-note A14, святилище A15, gate-seal A16 (+3
footnotes), озеро-note A17; B1 кетл, B2 «That wasn't there.»;
«Again?» A19 — один раз за сессию) + «Что изменилось» overlay
(≤5 строк, 3 s, пропускаемый, layer 30) + run-запись в
world_state.runs (P15-формат) + recorder-мост
(RunManager.bind: enemy_killed→ENEMY_KILLED, weapon_found→
ITEM_PICKED, swing→ATTACK (перепривязка на weapon_changed),
damage_applied→ATTACK_HIT, npc.talked→NPC_TALKED,
level-entered→ENTER_ROOM, notes→NOTE_WRITTEN).
TESTED: риг — **823/823 PASS** (unit 584 + integration 239).
Unit: run_system (recorder limits/roundtrip, derive_seed,
changed_lines newest-first, history 5 МБ-кэп/summary),
world_flags (таблица строк). Integration: run_cycle —
полный цикл: RUN 1 (A2/A3/A5/A7/A10/A11/A12/A14/A15/A16/A17)
→ смерть (A19: флаги, run-запись, death screen, выбор) →
respawn (41 ms < 2 s; RUN 02: новый seed, новая раскладка,
дверь подвала открыта, «что изменилось» с дверью+канном,
«Again?», след A5 на месте) → RUN 02 (канон → loadout +
ITEM_PICKED, подвал туда/обратно, B2, посох, Ния в деревне)
→ run-запись (RUN 1: PLAYER_DIED/ENEMY_KILLED/ATTACK/
ENTER_ROOM/NPC_TALKED/EVENT_COMPLETED/NOTE_WRITTEN, kills≥1,
RUN 2: PLAYER_SPAWNED first). Regression: progression_scene
(RUN 1 = note-станды, не оружие; seal-двери; explored_pct),
combat/camp/enemy/touch — без изменений.
KNOWN ISSUES: B4 (первый Echo «You're early.») и мумия #5 —
Phase 9/10 (last_death_pos уже хранится); playtest A-якорей
на железе — тест/qa/qa_phase8_run.md (владелец); 5-строчный
пул «что изменилось» — лимит Q-WD2 (старейшие флаги
выпадают при >5).
NEXT: PHASE 9 — Ghost/Echo (budget per ADR-014).

## PHASE 9 — Ghost/Echo (budget per ADR-014)
Scope: GhostDirector/GhostReplay/GhostController по TECHNICAL_DESIGN
§5; **Passive Echo** (replay последнего забега, layer «Echo»:
desaturated + emissive) + маркеры старых runs (3–5); **Combat Echo
(Remnant)** — enemy (Phase 5) + builder (Phase 5) — в Phase 9
интеграция (spawn «где игрок был», реплики #1: «You're early.» —
и уходит, B4); **Memory Echo** (scripted locations + Watcher anchor,
Phase 5/10).
Unit: timeline build, remap, interpolation, budget (≤3/run).
Integration: recording → passive ghost; RUN 02: #1 (B4) + Passive (C1).
Exit: ghost бегает по хабу, повторяет действия, читается как «прошлый
я», ≤ 0.5ms/frame; #1 (B4) воспроизводится (playtest).
STATUS: COMPLETE (2026-09-18). ADR-028 (бюджет = data + world-state
+ per-run счётчики; ghost = pure timeline + визуальный контроллер
без физики; remap по room id; часы ранa: накопление дробных
deciseconds; stagger-якорь t0).
IMPLEMENTED: data/echo (echo_budget.tres rows: RUN 1 = 0, RUN 02/03 =
1 Passive + 1 Combat, RUN 04+ = +1 «special»; passive_echo.tres:
opacity 0.5, max_speed 4 м/с, fade_dist 20 м, fade 3 с, tint) +
GhostKeyframe/GhostTimeline (pure: build из RunRecord, remap
старая→новая раскладка по room id (ADR-003 якоря), Catmull-Rom,
ry angle-wrap, action-at-t) + EchoBudgetData/EchoBudgetState
(per-run счётчики; EnemyDirector опрашивает) + GhostController
(копия силуэта игрока, без физики: chase сэмпла с max_speed,
action-pulse, dissolve-pulse на «перематке», fade-out на конце
реплея/отрыве >20 м, footprints) + GhostDirector (prepare_run:
бюджет + timeline пред. ранa + маркеры ≤5 last_death_pos
(remap); per-level ghost; combat spawn-override «где игрок был»)
+ EnemyDirector: condition-тип flag:<id> (remnant-гейт
first_death_done — RUN 1 echo-free), spawn_overrides (one-shot),
budget-гейт REMNANT (1 Combat/run), stagger-якорь t0 (рестарт
уровня не бьёт слоты в кадр) + enemy: полная канон-секвенция #1
(«You're early.» → «You usually take longer.», в порядке),
leave_fade (dissolve-уход, EnemyData), ECHO_TRIGGER в run-записи
(bus echo_triggered) + RUN-часы: накопление дробных deciseconds
(баг: int(round(1/60×10)) == 0 — все события t=0, playtime 0).
TESTED: риг — **886/886 PASS** (unit 615 + integration 271).
Unit: echo (budget rows/plateau, budget-state, timeline build
(decis→s, сортировка, dup-t), remap (origin delta, missing-room
rewind, camp-ring keep, identity), Catmull-Rom (концы/срединная
точка, no-extrapolation), ry-wrap 350→10, action-at-t),
run_system (+регрессия: часы идут при 60 Гц). Integration:
echo_scene — полный цикл (RUN 1: 4 врага без remnant, ghost нет,
запись ≥4 событий; смерть → RUN 02: replay вооружён, маркер в
точке смерти RUN 1, remnant на пути игрока (override), ghost
движется, B4: обе реплики канона → dissolve-уход, ECHO_TRIGGER
(combat=1) в записи, бюджет combat исчерпан, реплей завершается
dissolve); enemy_scene: RUN 1 = 4 (без remnant), RUN 02-
симуляция = 5 (remnant спавнится: бюджет + флаг); regression:
progression/run_cycle/combat/camp/touch — без изменений.
KNOWN ISSUES: финальный dissolve/rim-шейдер ghost — Phase 13
(MVP: transparency + tint + faint emissive); маркеры старейших
runs сжимаются с логами (summary без позиции, 5 МБ-кэп);
«специальные» эхо (Memory/Forgotten/False) — контент Phase 10/11
(бюджетный слот уже зарезервирован в data).
NEXT: PHASE 10 — World memory.

## PHASE 10 — World memory
Scope: WorldState persist (в save, ADR-008), WorldDirector apply
(flags: doors/notes/corpse/trace/transformation, WORLD_STATE_DESIGN
§2), «мемориальные» маркеры (шиммер, 1 с) + UI «Что изменилось»
(§9.2, ≤5 строк), **notes** (4 note stands, 5-line pool, no free
text, WORLD_STATE_DESIGN §4), **memory_stats** (10 счётчиков, §3),
NPC state (trust/death, §5), mummy #5 (`last_death_pos`), K7
transformation (post-boss, §6 — триггер, не реализация босса).
Unit: world state changes, notes roundtrip, memory_stats aggregation.
Integration: drop-in-world → следующий забег; note → RUN N+1;
shortcut perma-open.
Exit: «мир помнит» — 10+ различимых перманентных изменений в работе;
«Что изменилось» замечено (qa-метрика GDD §12).
STATUS: COMPLETE (2026-09-18). ADR-029 (WorldDirector = слой
постоянных объектов; WorldState: notes + полный to_dict/load_dict
— контракт Phase 15; MemoryStats persist; K7 = data-таблица
трансформации + триггер-флаг; #6 = extra line в Remnant-
секвенции).
IMPLEMENTED: data (note_lines.tres — пул 5 строк;
player_note_stands.tres — 4 stand-а camp/village/shrine/
undercroft; world_transform_post_boss.tres — K7-таблица: fog
×0.375, light 5500K, gate glow, city, echo «тише» 0/1/0,
footprint permanent, npc_calm) + WorldState (notes: write_note
(4 канон-stand-а, перезапись), get_note/note_line/last_note
(последняя по t — руки мумии); **полный to_dict/load_dict**:
flags (включая Vector3), inheritances, weapons, npcs, notes,
runs (RunHistory); load_dict — защита от битого сейва: clamp +
unknown-stand-отброс) + MemoryStats (to_dict/load_dict: 10
счётчиков + 3 aggregates) + WorldDirector (prepare_run /
on_level_entered / update: stand-ы (camp → CampWorld, зоны →
комната раскладки), мумия (run_id ≥ 3, last_death_pos пред.
ранa, remap; комната пропала → warning + skip), K7-визуал
(gate glow + city silhouette за дверью), шиммер: 1-с emissive
пульс на первом подходе, O(1) ≤5 targets) + PlayerNoteStand
(Interactable: write → NotePanel → ws + notes_written +
NOTE_WRITTEN; read в RUN N+1 → ECHO_NOTE_READ first time) +
WorldMummy (examine → линия + corpse_seen + MUMMY_EXAMINED;
записка в руках) + NotePanel (code-built Controls, CanvasLayer
25, `press(idx)`, паттерн DeathScreen) + K7-применение
(_set_fog ×fog_factor, GhostDirector.prepare_run бюджет-
override «тише», ghost-отпечатки permanent (reparent на fade),
NpcData.post_boss_line (4 NPC-реплики), world_flags.tres
corpse_seen) + #6 (FirstRunDirector: echo_triggered(combat) +
ран ≥ 3 + записка → enemy add_encounter_line «…I forgot that.»;
enemy_logic extra_lines — канон-секвенция + 1 строка, данные
не мутируются).
TESTED: риг — **986/986 PASS** (unit 672 + integration 314).
Unit: world_memory (note pool 5 canonical, stands ×4, K7-
таблица, notes write/overwrite/last_note, WorldState
round-trip (Vector3-флаг, NPC-state, runs, битый сейв: clamp +
unknown-stand), MemoryStats round-trip + clamp, mummy rule,
K7 бюджет-офсет), enemy_logic (#6: extra line = 3-я строка,
LEAVE после). Integration: world_memory_scene — полный цикл
(RUN 1: stand в лагере, панель-пул, запись строки 2,
NOTE_WRITTEN (line в data), notes_written +1, свежая записка не
readable; смерть → RUN 02: записка readable (текст = строка),
ECHO_NOTE_READ first time, мумии нет; смерть + boss_defeated →
RUN 03: мумия в точке смерти RUN 02 (3.5/4.5), записка в руках
(последняя), examine → corpse_seen + MUMMY_EXAMINED,
corpse_seen-линия; K7: бюджет «тише» (0 passive/0 special),
gate-fog 0.0338→0.0127 (×0.375), gate glow + city в gate-
уровне, stand per-area, мумия в лагере, Mara — post-boss-
реплика); regression: все сьюты Phase 1–9 без изменений.
KNOWN ISSUES: K7 без босса — триггер флаг, «после босса» игрок
увидит в Phase 12 (тесты эмулируют флагом); #6 = реплика, не
хореография «прерывает бой» (MVP-лимит, ADR-029); мумия/
маркеры в перекрывающихся footprint-ах зон (пространственная
консистентность — правило P9-маркеров); шиммер = emissive-
пульс без частиц (visual pass Phase 13); файл сейва (I/O/CRC/
миграции) = Phase 15 (SaveManager обёрнёт WorldState.to_dict).
NEXT: PHASE 11 — Mystery system (4 mystery × 4 stages).

## PHASE 11 — Mystery system (4 mystery × 4 stages)
Scope: M1–M4 stages 1–3 (MVP, MYSTERY_REVEAL_MAP §1) + trigger-
система (flag-gating: stage N+1 только после flag N) + dialogue
(5 NPC + Archivist whispers (5, seedy), DIALOGUE_GUIDELINES) +
signature #1–#7 + K1–K7 (NARRATIVE_STRUCTURE §4) + reveal rules
(1 stage/run, ambiguity-бюджет, no early reveal).
Unit: triggers, stages, flag-gating. Integration: dialogue flow,
choice → state; FIRST_3_RUNS-маршрут (RUN 1–03).
Exit: #1–#7 + K1–K7 достижимы (playtest-маршрут по FIRST_3_RUNS);
M2 stages 1–3 «собираются» (главная MVP-линия, GDD v2.0 §11);
ambiguity сохранена (тест: ни одна реплика не «отвечает»).

STATUS: **ЗАКРЫТА** (2026-09-18, ADR-030).
IMPLEMENTED: MysteryDirector (gameplay/mystery/, RefCounted:
can_reveal/run_min/stage-порядок/flag_req/1-на-run, reveal =
прогресс+флаг, reset_run, progress_view) + data (mystery_stages
13: m1_k1/m1_passive/m1_book/m1_page, m2_trace/m2_gate/m2_first,
m3_first_echo/m3_note/m3_lake, m4_gate/m4_child/m4_city;
child_spawns RUN 04–05 village deaths≥3) + WorldState
mystery_progress (forward-only, persist clamp 0–4, тот же
JSON-раундтрип ADR-029) + dialogue-таблица
(data/dialogue/npc_mystery_lines.tres: 6 линий, for_char-
приоритет char/run/flag/trust, repeat; NpcNode._line_for перед
trust-линией, mystery_line_spoken → m4_city в main) + K4
WorldBook (страница = состояние: blank/имя/filled, Label3D 6 c,
page_read → m1_book/m1_page) + K5 lake reflection (RUN 05+,
силуэт 2 c, once → m3_lake) + Child (village RUN 04–05,
инвульнерабелен, RUN 04 линия без стадии, RUN 05 «217» →
m4_child, attempt_hit → child_hit) + Veyra-map board (camp,
veyra_city_told, «VEYRA B») + Archivist whispers #2/#3/#5
(#1 — P8, #4 — триггер фазы 12, флаг gate_welcome_whisper) +
реплики A3/A5/B2/passive-ghost/child-спик в FirstRunDirector/
main (m1_k1, m2_trace, m2_gate, m1_passive, m3_first_echo +
whisper #2) + **P9-дефект фикс** (ADR-030 (6): #6-встреча
недостижима — remnant_note_met + note_encounter в момент зрения
+ CHASE→SPEAK) + world_flags.tres +15 (30 всего).
TESTED: риг — **1094/1094 PASS** (unit 717 + integration 377).
Unit: mystery (stage-таблица, gate, persist/clamp, dialogue,
child-spawns, ambiguity-скан — ни одна реплика не «отвечает»).
Integration: mystery_scene — полный маршрут RUN 1–06 на живой
сцене: RUN 1 (K1→M1.1, след→M2.1, A16-печать) → RUN 02
(passive→M1.2, #1→M3.1 + whisper #2, B2→M2.2) → RUN 03
(записка, #6 «…I forgot that.»→M3.2, K4→M1.3 + страница
показана, аннотации→M4.1; итог M1:3 M2:2 M3:2 M4:1) → RUN 04
(Child: линия без стадии) → RUN 05 (K5→M3.3, Child «217»→M4.2,
filled page→M1.4, город сказан но **стадия смещена** — assert)
→ RUN 06 (смещённая стадия ложится; MVP-финал M1:4 M2:2 M3:3
M4:3). Regression: все сьюты Phase 1–10 без изменений.
KNOWN ISSUES: M2.3-реплика — **закрыто Phase 12** (boss line
#6 = линия m2_first, reveal на phase-shift); whisper #4
триггер = boss_defeated — **закрыто Phase 12** (флаг
boss_defeated, паттерн K7 ADR-029); Child-хореография/K5-
визуал/шиммер-частицы — Phase 13; «1 стадия на mystery в
run» может сдвинуть
графику MYSTERY_REVEAL_MAP на +1 run (поведение зафиксировано
тестом RUN 05/06 — «мир не торопится»).
NEXT: PHASE 12 — Boss: THE FIRST (Undercroft).

## PHASE 12 — Boss: THE FIRST (Undercroft)
Scope: THE FIRST (BOSS_DESIGN): 2 фазы (Wandering/Workshop),
паттерн-память (threshold 3, parry), core-hit («печать», окно
2/4 s; FIRST BLADE take/leave, WEAPON_DESIGN §4.3), Remnant-
миниион (best run, Phase 5 builder), telegraphs (0.5/0.8 s),
boss-условие (событийное: ADR-019), death sequence (K6: «let them
go») → K7 transformation (WORLD_STATE_DESIGN §6: туман/свет/город/
echo-тише/следы-навсегда/NPC-calm).
Unit: phase transitions, pattern-memory resolve, core-hit window.
Integration: encounter flow (door → pre-boss notes → take/leave →
fight → death → transform).
Manual: boss feel (telegraph readability ≥70% на тесте).
Exit: boss побеждаем (оба варианта: с/без FIRST BLADE); K7
трансформация видна (qa-чек-лист); «достаточно качественный»
по чек-листу.

STATUS: **ЗАКРЫТА** (2026-09-18, ADR-031).
IMPLEMENTED: модуль босса (gameplay/boss/: BossData
(data/boss_the_first.tres: hp 600, melee 20/2.8/telegraph 0.5
с, slam 35/3.5/0.8 с, pattern 3/3, break 3, parry 25/0.4 с,
core 30/50 окно 2/4 с, фаза 2 @60% + миньон 80/15, dissolve
3 с), PatternMemory (чистая: LEARNED/PARRY_TRIGGER/BROKEN,
шаги «weapon_id:hit_index»), BossSense, BossLogic (FSM 13
состояний, только решения), BossGate (композит-правило
mine3 + 3 смерти + traces -> ОДИН флаг boss_door_open,
«once open»), BossController (Node3D-мост: визуал worn-ELI
(примитивы, общий material) + фонарь, печать (torus,
emission в окне), Label3D-реплики #1–#10, steering-полоса
1.5–3.0 м, melee/slam через DamageResolver, parry =
invulnerable на всё окно (active-фаза пришедшего удара
блокируется), core one-shot (swing_started, range+0.5),
миньон = duplicate remnant_mirror через EnemyController
(LEAVE при <=50%: gentle_leave, без kill-записи), death K6
(dissolve + #9 -> #10 -> defeated -> boss_defeated +
toasts))) + main-wiring (boss_door_open оценивается ДО
run_generator.generate; sealed-дверь «The door is closed.
(stone)»; Undercroft: 3 записки The First + FIRST BLADE
(WeaponPickup: take/leave = first_blade_taken, #5/#7,
respect Echoes: enemy_director.respects_first_blade гейтит
REMNANT-aggro, «...that was mine.») + босс на event_spot)
+ первые следы (first_run_director.place_first_traces: 3
ovala + его фонарь, RUN 05+; _check_mine_deep:
mine_level_3_explored + first_traces_seen) + world_flags
(35 строк: +boss_defeated, boss_door_open,
mine_level_3_explored, first_traces_seen,
first_blade_taken) + the_mine.tres condition =
boss_door_open.
TESTED: unit 767 (boss: 49 — data/pm/FSM/core/death/gate,
parry window-hold + once-only counter), integration 422
(boss_scene: 40 — арена-контент, melee, learn (#4), parry
(блок + counter 25), core (30 + #8 + one-shot), фаза 2
(миньон 80/15, LEAVE @50%, M2.3-сигнал + RUN-гейт: стадия
не ложится при RUN <5), blade take (флаг + #5 + respect),
death (#9/#10/boss_defeated/одноразовая дверь); run_cycle:
RUN 02 дверь sealed — поведение P7 «дверь открыта в RUN 02»
заменено правилом окна (BOSS_DESIGN §2.1)). MVP-end:
M1:4 M2:3 M3:3 M4:3 (m2_first закрывает M2).
KNOWN ISSUES: (1) визуал босса — prototype (капсула+голова,
примитивы) — P13 (visual pass, ASSET_GUIDE); (2) босс
атакует по distance-to-seal — издалека FSM «махать» может
(удар не достаёт): принятый trade-off (телеграф всегда у
ядра, ADR-031 #3); (3) телеграф-читабельность >=70% —
ручной тест владельца (qa_phase12_boss.md B1, ____/30);
(4) K7-визуал — на следующем входе в gate (flag-driven,
паттерн P10).
NEXT: P13 (Visual polish: финальные материалы/свет
включая босса, mobile-графика: ASTC, draw calls <=150,
lights <=6, UI mobile-вёрстка).

## PHASE 13 — Visual polish
Scope: визуальный pass по всем сценам (материалы/свет/композиция),
замена prototype-элементов (по ASSET_STATUS.md — все «prototype»
закрыты или явно приняты), UI-отделка (все экраны, не Godot-дефолт,
**mobile-вёрстка: aspect 16:9–20:9, safe area, thumb-зоны — ADR-021**),
**mobile-графика: ASTC-текстуры, texture-atlas (draw calls ≤150),
локальные источники света ≤6/preset, no heavy post (TECH_DESIGN §12)**,
camera polish, color grade.
Manual: qa_phase13_visual.md (+ мобильные чек-листы).
Exit: «никаких prototype-элементов» (чек по списку); mobile-графика
в бюджете §12 (ASTC, draw calls, lights).

STATUS: done (2026-09-20, ADR-032).
IMPLEMENTED: VisualPalette (data-driven мир-цвета, WORLD_BIBLE §1),
QualityPreset low/medium/high + QualityManager (F8, тир-бюджеты §12),
light-бюджет = жизненный цикл RoomLight-узлов (medium 4 / high 6),
генеративные текстуры (8 × 64×64 tileable, seed, 15 КБ) + TextureBank
(tint-модель), CharacterVisual — один язык каста (Eli/4 NPC/Child/
THE FIGURE FRESH-копия/враги-архетипы/босс worn-Eli/Remnant),
color grade (холодный ambient + лёгкий adjustment, filmic, fog),
UI-kit UiTheme (4 экрана: toast/note/inventory/death), camera polish
(aspect-aware base FOV 60→68° + damped sprint-kick), ASSET_STATUS.md
(prototype = 0).
TESTED: unit visual_pass/ui_theme (палитра/качество/ткань/tint/kit),
integration: camp_scene (ткань+каст), rooms (свет-бюджет по тиру),
combat (Remnant/EliFigure), boss (Remnant), ghost (THE FIGURE),
death (kit), touch_layout (20:9); regression 819/451.
KNOWN ISSUES: риг не валидирует рендер-свойства (msaa/render_scale/
atlas/enabled — production-only, device-check P16); ASTC — export
preset post-MVP; camp-листва flat; Ghost-визуал «явно принят».
NEXT: Phase 14 (Audio).

## PHASE 14 — Audio polish
Scope: все категории по GDD §8 (финальные лицензии или осознанные
заглушки), AudioManager (buses/pool/levels), music: **одна мелодия «The Wound» ×5
вариаций** (Normal/Memory/Echo/Archivist/Ending) + ambient-слои +
1 stinger (boss reveal), GDD v2.0 §7; звуковой язык слоёв (WORLD_BIBLE §1.1).
Manual: qa_phase14_audio.md (LUFS, no clipping).
Exit: полный audio pass; volumes/mute в settings работают.

STATUS: done (2026-09-22, ADR-033).
IMPLEMENTED: «The Wound» ×5 (Normal/Memory/Echo/Archivist/Ending,
одна мелодия, 5 тембров+времени) офлайн-генерацией (gen_audio.py,
seed, 11025 Hz, ~4.8 MB) + MusicLibrary-банк; 6 ambient-слоёв по
зонам (16 s loop, seam crossfade) + stinger (boss reveal, 4 s);
MusicDirector (чистая цепочка ENDING>ARCHIVIST>ECHO>MEMORY>NORMAL
на фактах сцены, crossfade 1.5 s); AudioManager (буса Music/SFX/
Ambient, A/B crossfade-голоса, ambient-swap, stinger, settings
master/music/sfx/ambient + mute в dB); SfxBus 12 кью (P4/P6 +
door/seal/death/note/ui/echo) на SFX-бусе; SettingsPanel
(kit-вёрстка, F9, живые слайдеры + mute); wiring по seams
(zone/door/death/note/echo/boss).
TESTED: unit audio_env (контракт AudioServer в риге),
music_library (12 файлов: длины/пики/loop/отличия), music_
director (приоритеты), audio_manager (буса/crossfade/settings/
mute/round-trip); integration audio_scene (буса в main scene,
пул на SFX, bed по зонам, 12 кью, панель на бусах), boss_scene
(stinger + ARCHIVIST + ENDING); regression 945/501.
KNOWN ISSUES: headless не валидирует восприятие (LUFS,
тембр, mix) — device-QA P16; persistence настроек — P15
(дикт get_settings() готов); Voice-буса нет (MVP без голосовых
реплик — текст); F9 = debug (release — settings-меню P15).
NEXT: Phase 15 (Save/load/recovery).

## PHASE 15 — Save/load/recovery
Scope: SaveManager (atomic, crc, versions, migration, recovery) по
TECHNICAL_DESIGN §3; save-матрица (тест №8) + kill-mid-write симуляция;
settings в save.
Unit: migration, corrupt matrix. Integration: death→save→reload.
Exit: crash/invalid/old-version/missing-asset — без loss core-
прогрессии, без crash (матрица 100%).

STATUS: done (2026-09-22, ADR-034).
IMPLEMENTED: SaveData (envelope {format,version,saved_at,
engine,world,settings,crc32}, canonical JSON, CRC32-IEEE,
verify-матрица) + SaveMigrator (цепочка шагов, «newer»/gap —
именованные, no-loop guard) + SaveManager (user://save/ay_
save.json, atomic .tmp->rename, .bak, 5 MB cap, матрица:
ok/empty/recovered_bak/fresh/newer, quarantine .corrupt_* —
данные пользователя никогда не удаляются); settings в save
(quality tier + audio: master/music/sfx/ambient/mute); точки
автосейва: смерть+выбор (тост), safe-hub (лагерь), WM_CLOSE;
изоляция тестов (main != current_scene -> уникальный save,
seam save_path_override).
TESTED: unit save_data (CRC-вектор 0xCBF43926, round-trip,
tamper, envelope), save_migrator (цепочка, newer, gap, no-
loop, null-step), save_manager (всё на реальном user:// I/O:
round-trip, .bak, corrupt->recovered_bak, both-corrupt->fresh
+ quarantine, newer-не-тронут, kill-mid-write partial .tmp);
integration save_scene (смерть через реальный путь -> выбор ->
save -> 2-я сцена: flags/inheritance/note/NPC-death/run-history/
audio-setting — всё на месте); regression 995/523.
KNOWN ISSUES: нумерация ран сессионная (новый старт = run 1;
персистентны рекорды — ADR-034 #7); ENOSPC не симулируется;
физический Android-файловик + crash-тесты — device-QA P16.
NEXT: Phase 16 (Performance).

## PHASE 16 — Performance (mobile-first) · done (P16)
Scope: audit по TEST_PLAN §7 + fixes + quality presets Low/Med/High/Ultra
(PERF_REPORT.md).
- **Песочница (ADR-035):** структура (nodes/bodies/fx/lights vs §12) +
  frame CPU P50/P95 + save write — camp 281 nodes / p95 0.16 ms /
  save 1 ms, mine 340 (4 lights = Medium-бюджет), boss-арена 334 —
  всё в §12 с запасом.
- **Аудит-фиксы:** High tex 1024→2048 (§12-дрейф), Ultra создан
  (soft_shadows + atlas + 125% VFX), 4 тира validate-чистые.
- **Инструменты (debug-only, release off):** F1 DebugOverlay
  (fps/P50/P95/budgets), F6 PerfBenchmark → user://perf_<area>.txt
  (adb pull), F8 цикл +Ultra.
- **GPU/thermal/RAM/texmem** — device-чек-лист (PERF_REPORT §2,
  владелец, референс SD7/8GB High 60 fps, SD6xx/4GB Low 30 fps).
Exit: песочница-части в §12 (закрыто); GPU-бюджеты §12 —
device-чек-лист PERF_REPORT §2 (владелец, до P17 device-QA).
1012/547 pass.

## PHASE 17 — QA
Scope: полный sweep по TEST_PLAN §5/§6 (включая edge-cases матрицу),
**mobile-QA на устройстве (ADR-021): touch-эргоника, aspect 16:9–20:9,
safe area (notch), rotation-lock (landscape), battery/thermal-наблюдение,
connectivity-пауза/резюме, low-memory-поведение (save-устойчивость)**,
fixes, regression-прогон.
Exit: 0 known critical; 0 known non-critical без решения; mobile-QA
чек-лист пройден (на устройстве).

## PHASE 18 — Release build (Android)
Scope: export presets (**Android release — primary (ADR-021)**; Windows —
dev/QA-экспорт, по решению владельца), Release-feature (без DebugTools),
проверка: нет debug/overlay/test-ассетов/placeholder UI/broken refs;
icon; version strings; **APK-size ≤ ~2 GB (TECH_DESIGN §15.2)**;
landscape-lock; safe area в финальном APK.
Ограничение (ADR-012/§15.5): Android-тулчейн (SDK/gradle) в песочнице
не гарантирован → финальный экспорт APK выполняет владелец (по
инструкции в docs/RELEASE_BUILD.md, создаётся в этой фазе).
Exit: APK стартует на устройстве, проигрывает, save/load OK,
0 debug-остатков; ADB-QA-прогон пройден.

## PHASE 19 — Final review
Scope: независимый review (роль senior reviewer), FINAL_REVIEW.md по
секциям (Architecture/Gameplay/UX/Visuals/Audio/Performance/Persistence/
Security/Licensing/Known Bugs/Release Risks), fixes critical.
Exit: review закрыт; known limitations задокументированы.
