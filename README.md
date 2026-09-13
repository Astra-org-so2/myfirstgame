# AFTER YOU

3D third-person action roguelite: **мир помнит ваши предыдущие забеги**.

PC first (Godot 4.7.2). Маленькая, но отполированная игра: один биом
(Forgotten Forest), 5 врагов, 3 оружия, run-recording + ghost-система,
world memory, boss, 5 mystery-событий.

## Статус

**Phase 0 (pre-production) — завершается.** Стек документов в `docs/`:
- `GDD.md` — гейм-дизайн и MVP-объём
- `ARCHITECTURE.md` — модульная архитектура, autoload'ы, слои, правила
- `TECHNICAL_DESIGN.md` — data model, save-формат, RunEvent, ghost-replay,
  процедурные комнаты, performance-бюджеты
- `ASSET_GUIDE.md` — источники/лицензии/пайплайн (CC0: Poly Haven, Quaternius,
  Kenney, + Freesound/CM для аудио)
- `TEST_PLAN.md` — headless-риг, unit/integration, ручные QA-чеклисты
- `ROADMAP.md` — фазы 0–19 с exit-criteria
- `DECISIONS.md` — ADR + реестр рисков

## Development tooling (песочница)

- `tools/godot-node/` — headless Godot 4.7.2 (wasm) на Node: автотесты
  игровой логики без GPU (см. `tools/godot-node/README.md`).
- `./tools/run_tests.sh` — прогон тестов.

## Конвенции

GDScript 2.0, строгая типизация; data-driven (`.tres` в `data/`);
структура — `docs/ARCHITECTURE.md` §2.
