# AFTER YOU

3D third-person action roguelite: **мир помнит ваши предыдущие забеги**.

PC first (Godot 4.7.2). Маленькая, но отполированная игра: один биом
(The Forgotten Forest), 5 NPC, 5 архетипов врагов, 3 архетипа оружия,
boss (THE FIRST), run-recording + Echo-система (5 типов), world memory
+ memory_stats, 4 mystery-линии, 6 актов (MVP = Act I + начало Act II).

> AFTER YOU — это не «roguelite, у которого есть сюжет».
> Это **мир, который помнит тебя, замаскированный под roguelite**.

## Статус

**Phase 0 (pre-production) — завершена** (технический + креативный
дизайн, v2.0). **Дизайн-фаза (Story & World) — завершена** (15
документов + критический self-review). Следующая — **Phase 1**
(runnable project) по `docs/ROADMAP.md`.

Документы в `docs/`:
- `GDD.md` — GDD v2.0: концепт, геймплей-ядро, MVP-объём, метрики
- `design/` — 14 дизайн-документов: CHARACTER_BIBLE, WORLD_BIBLE,
  NARRATIVE_STRUCTURE, ENEMY_DESIGN, WEAPON_DESIGN, PROGRESSION_DESIGN,
  ECHO_SYSTEM_DESIGN, WORLD_STATE_DESIGN, FIRST_30_MINUTES,
  FIRST_3_RUNS, BOSS_DESIGN, MYSTERY_REVEAL_MAP, DIALOGUE_GUIDELINES,
  ENV_STORYTELLING_GUIDE + `DESIGN_REVIEW.md` (self-review)
- `ARCHITECTURE.md` — модульная архитектура, autoload'ы, слои, правила
- `TECHNICAL_DESIGN.md` — data model v2, save-формат, RunEvent (14 B),
  ghost/Echo-replay, процедурные комнаты, performance-бюджеты,
  boss/ending-схемы
- `ASSET_GUIDE.md` — источники/лицензии/пайплайн (CC0)
- `TEST_PLAN.md` — headless-риг, unit/integration, ручные QA-чеклисты
- `ROADMAP.md` — фазы 0–19 с exit-criteria (v0.2, v2-контент)
- `DECISIONS.md` — ADR-001…020 + реестр рисков

## Development tooling (песочница)

- `tools/godot-node/` — headless Godot 4.7.2 (wasm) на Node: автотесты
  игровой логики без GPU (см. `tools/godot-node/README.md`).
- `./tools/run_tests.sh` — прогон тестов.

## Конвенции

GDScript 2.0, строгая типизация; data-driven (`.tres` в `data/`);
структура — `docs/ARCHITECTURE.md` §2.
