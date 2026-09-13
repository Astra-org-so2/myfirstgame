# AFTER YOU — Roadmap (фазы, вехи, exit-criteria)

Версия: 0.1 (Phase 0). Формат статуса фазы (обязателен при закрытии):
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
Exit: документы согласованы; открытые вопросы (GDD §7) — на решении
владельца; инструментальный вопрос (движок в песочнице) решён (ADR-002).
STATUS: IN PROGRESS (этот документ — часть Phase 0).

## PHASE 1 — Empty runnable project
Scope: project.godot (4.7.2, input map, layers, rendering defaults,
fog), main scene (пустой хаб-заглушка с камерой), структура папок;
`tools/run_tests.sh` + `tests/runner.tscn|gd` + 1 smoke-тест (runner
стартует, печатает, quit(0)); harness-режим `--tests` (main-scene swap).
Autoload'ы НЕ создаются заранее — каждый появляется с фазой своей
системы (ADR-009).
Exit: проект стартует в редакторе (владелец) И в риге (песочница) без
ошибок; input map полный; структура по ARCHITECTURE.
Risks: — (инфраструктура проверена в Phase 0 spike).

## PHASE 2 — Player
Scope: PlayerController + camera rig (orbit, collision, distance FOV),
movement (run/sprint/dodge со stamina, MockMovementPort + EngineMovementPort),
CharacterBody3D, animation state machine (idle/walk/run/dodge/hurt),
placeholder-персонаж (примитивы, ADR-005) или rigged-CC0 (если найден —
ASSET_GUIDE §4).
Unit: movement logic (ускорение/затухание, dodge-окна, stamina-косты),
camera math. Integration: respawn-позиция.
Manual: qa_phase2_movement.md.
Exit: движение «приятное» (чек-лист), dodge i-frames работают
(замер окна), 60fps в риге-тиках, 0 ошибок.

## PHASE 3 — First environment
Scope: хаб-поляна (Clearing): floor, paths, 8–12 деревьев (Multimesh),
ruins-обломки, бrazier-факелы (2–3), туман + sky/HDRI (CC0 или
генеративный sky), DirectionalLight, landmark (stone circle), NPC-
заглушка (The Keeper placeholder), interact-заглушка (подход → prompt).
Unit: room/area data-валидация.
Manual: qa_phase3_world.md (визуал, FPS, load).
Exit: «выглядит красиво» за 30 c (скриншоты-референсы), FPS по бюджету.

## PHASE 4 — Combat
Scope: weapon (1: sword), attack (hitbox-кадры), DamageResolver,
player damage + death, knockback, hit reaction, hit-stop, camera shake,
impact VFX (пул), SFX (генеративные заглушки, prototype-статус),
1-2 test-мишени (статичные, не «временные враги» — test-объекты в
tests/, не в игре).
Unit: damage math, combo timing. Integration: hit → damage → death.
Manual: qa_phase4_combat.md (feel-матрица).
Exit: «бой ощущается хорошо» (чек-лист) — критерий, не мнение.

## PHASE 5 — Enemy system
Scope: EnemyController FSM-base + navigation (injectable navmesh-source,
pathfinder в чистом коде) + 5 архетипов (Stalker/Brute/Watcher/Mimic/
Echo) по EnemyData; aggro/targeting; staggered updates; telegraphs.
Unit: FSM transitions, per-archetype invariants, Echo builder.
Integration: spawn-таблица, staggered slots.
Manual: qa_phase5_enemies.md (15-мин сессия/архетип).
Exit: 5 разных на поведение врагов; AI-бюджет ≤4ms.

## PHASE 6 — Loot and progression
Scope: LootTable (seeded), inventory (12 slots + equipment 3), items
(зелья/осколки), weapons ×3 (data), legacy upgrades 10–15 (meta-
shop на death screen: выбор 1/3), RunState (inventory/weapon per run).
Unit: inventory, loot determinism, upgrade resolve.
Integration: pickup/drop-in-world flow.
Exit: полный лут-цикл работает; data-driven (новый item = .tres).

## PHASE 7 — Procedural rooms
Scope: AreaGraph (хаб + 8 локаций, DAG), RoomData/variants (2–3
варианта на локацию, общие doorway-якоря), генератор (seed, weights,
connections), валидатор (по TECHNICAL_DESIGN §6), fallback-раскладка.
Unit: детерминизм, изоляты, двери, spawn-пробы.
Integration: room transitions (прохождение графа).
Exit: 100 сгенерированных seeds проходят валидацию (тест-прогон),
нет «невозможных» раскладок.

## PHASE 8 — Run system
Scope: RunManager (states), RunRecorder (EventBus → RunEvent[]),
RunHistory (3 full + summaries), RunSummary, death flow (death screen +
«что изменилось» ≤3 строки), respawn в хабе (≤2s hard / ≤10s UX).
Unit: recorder limits, events roundtrip. Integration: death→save→
resume.
Exit: забег → смерть → новый забег: полный цикл; «что изменилось»
читается.

## PHASE 9 — Ghost
Scope: GhostDirector/GhostReplay/GhostController по TECHNICAL_DESIGN §5;
ghost-визуал (shader, placeholder-mesh), действия (attack/interact
имитация), маркеры старых runs (3–5).
Unit: timeline build, remap, interpolation. Integration: recording →
ghost (тест №2).
Exit: ghost бегает по хабу, повторяет действия, читается как «прошлый
я», ≤ 0.5ms/frame.

## PHASE 10 — World memory
Scope: WorldState persist (в save), WorldDirector apply (doors/NPCs/
chests/dropped items/shortcuts), «мемориальные» маркеры (шиммер),
committed events per GDD §4.6.
Unit: world state changes. Integration: drop-in-world → следующий
забег; shortcut perma-open.
Exit: «мир помнит» — 10+ различимых перманентных изменений в работе.

## PHASE 11 — Mystery system
Scope: 5 mystery-событий (GDD §4.8) + trigger-система + journal
(«Памяти») + dialogue (The Keeper, ветки по world-state).
Unit: triggers, stages. Integration: dialogue flow, choice → state.
Exit: все 5 достижимы (playtest-маршрут в qa-доке); нарратив
«собирается» по 2–3 фрагмента.

## PHASE 12 — Boss
Scope: Heartgrove boss: 2 фазы, 4–6 attack patterns (telegraphs),
guard-break vulnerability, VFX/audio cues, death sequence (event →
world state → финальный выбор M5).
Unit: phase transitions. Integration: encounter flow.
Manual: boss feel (telegraph readability ≥70% на тесте).
Exit: boss побеждаем; «достаточно качественный» по чек-листу.

## PHASE 13 — Visual polish
Scope: визуальный pass по всем сценам (материалы/свет/композиция),
замена prototype-элементов (по ASSET_STATUS.md — все «prototype»
закрыты или явно приняты), UI-отделка (все экраны, не Godot-дефолт),
camera polish, color grade.
Manual: qa_phase13_visual.md.
Exit: «никаких prototype-элементов» (чек по списку).

## PHASE 14 — Audio polish
Scope: все категории по GDD §8 (финальные лицензии или осознанные
заглушки), AudioManager (buses/pool/levels), music (2 трека + stinger),
ambience per area.
Manual: qa_phase14_audio.md (LUFS, no clipping).
Exit: полный audio pass; volumes/mute в settings работают.

## PHASE 15 — Save/load/recovery
Scope: SaveManager (atomic, crc, versions, migration, recovery) по
TECHNICAL_DESIGN §3; save-матрица (тест №8) + kill-mid-write симуляция;
settings в save.
Unit: migration, corrupt matrix. Integration: death→save→reload.
Exit: crash/invalid/old-version/missing-asset — без loss core-
прогрессии, без crash (матрица 100%).

## PHASE 16 — Performance
Scope: audit по TEST_PLAN §7 (замеры: до/после), fixes (draw calls,
AI, particles, textures, nodes), quality presets (Low/Med/High/Ultra)
проверены, PERF_REPORT.md.
Exit: бюджет §12 TECH_DESIGN по High; Low floor — замер (владелец,
референс-железо).

## PHASE 17 — QA
Scope: полный sweep по TEST_PLAN §5/§6 (включая edge-cases матрицу),
fixes, regression-прогон.
Exit: 0 known critical; 0 known non-critical без решения.

## PHASE 18 — Release build
Scope: export presets (Windows x86_64; Linux если Q2 «да»),
Release-feature (без DebugTools), проверка: нет debug/overlay/test-
ассетов/placeholder UI/broken refs; icon; version strings.
Ограничение (ADR-012): export-templates недоступны в песочнице →
финальный экспорт выполняет владелец (по инструкции в
docs/RELEASE_BUILD.md, создаётся в этой фазе).
Exit: exe стартует, проигрывает, save/load OK, 0 debug-остатков.

## PHASE 19 — Final review
Scope: независимый review (роль senior reviewer), FINAL_REVIEW.md по
секциям (Architecture/Gameplay/UX/Visuals/Audio/Performance/Persistence/
Security/Licensing/Known Bugs/Release Risks), fixes critical.
Exit: review закрыт; known limitations задокументированы.
