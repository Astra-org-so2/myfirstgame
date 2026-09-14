# AFTER YOU — Roadmap (фазы, вехи, exit-criteria)

Версия: 0.2 (Phase 0, GDD v2.0). Формат статуса фазы (обязателен при закрытии):
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

## PHASE 14 — Audio polish
Scope: все категории по GDD §8 (финальные лицензии или осознанные
заглушки), AudioManager (buses/pool/levels), music: **одна мелодия «The Wound» ×5
вариаций** (Normal/Memory/Echo/Archivist/Ending) + ambient-слои +
1 stinger (boss reveal), GDD v2.0 §7; звуковой язык слоёв (WORLD_BIBLE §1.1).
Manual: qa_phase14_audio.md (LUFS, no clipping).
Exit: полный audio pass; volumes/mute в settings работают.

## PHASE 15 — Save/load/recovery
Scope: SaveManager (atomic, crc, versions, migration, recovery) по
TECHNICAL_DESIGN §3; save-матрица (тест №8) + kill-mid-write симуляция;
settings в save.
Unit: migration, corrupt matrix. Integration: death→save→reload.
Exit: crash/invalid/old-version/missing-asset — без loss core-
прогрессии, без crash (матрица 100%).

## PHASE 16 — Performance (mobile-first)
Scope: audit по TEST_PLAN §7 (**замеры на референс-устройстве — ADR-021**:
ADB + F1 overlay → файл), fixes (draw calls, AI, particles, textures,
nodes, RAM), quality presets (Low/Med/High/Ultra, data-driven) проверены
на mid-range (High, 60 fps) + low-end (Low, 30 fps floor),
**thermal-сессия 30 мин (без drop)**, cold start ≤8 c, save write,
PERF_REPORT.md.
Exit: бюджет §12 TECH_DESIGN по High (mid-range) И Low (low-end) —
замеры на устройстве (владелец).

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
