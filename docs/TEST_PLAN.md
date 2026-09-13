# AFTER YOU — Test Plan

Версия: 0.2 (Phase 0, GDD v2.0). Связанные: ARCHITECTURE.md §3 (порты),
TECHNICAL_DESIGN.md §13 (риг).

---

## 1. Принципы

1. **Каждая фаза имеет exit-criteria с тестами.** Не тестировано — не
   завершено (даже если «работает в редакторе у разработчика»).
2. **Автотесты живут в песочнице** (headless-риг) — воспроизводимы,
   быстро, без ручного участия.
3. **Всё, что нельзя автоматизировать в песочнице** (physics-feel,
   визуал, аудио, геймплей-баланс) — ручной QA с чек-листом + (когда
   возможно) замеры/видео.
4. **Детерминизм:** все автотесты — с фиксированным seed.
5. **Регрессия:** тесты прошлых фаз не удаляются; прогон — полный
   (`run_tests.sh`), не выборочный (быстро: риг стартует <1s, тесты —
   секунды).

## 2. Headless-риг (инфраструктура)

**Что:** `tools/godot-node/` — Godot 4.7.2 (wasm-сборка через npm
`@ringozz/godot`) на Node 22. `bootstrap.mjs` (idempotent: install +
patch + bundles), `harness.mjs` (boot → stage проекта в MEMFS → pump
frames 60fps → exit code).

**Возможности (проверено, Phase 0 spike):**
- запуск движка ~0.5 c; загрузка проекта; сцены; GDScript; ресурсы
  (текстовые форматы: .tscn/.tres/.gd); сигналы; таймеры (нужен явный
  `start()`); `_ready`/`_process`/`_physics_process` (фикс. 60 Гц);
  math; File I/O (MEMFS); quit() с exit code.

**Ограничения (проверено):**
- нет 3D-физики (Dummy server): гравитация/коллизии/move_and_slide не
  работают → логики движения тестируются через `MockMovementPort`
  (ARCHITECTURE §3.4);
- навигация частично недоступна (классы NavMesh* не в API-сборке) →
  pathfinding-логика выносится в чистый код (graph-based) с
  injectable navmesh-source;
- нет рендера/аудио-вывода (ожидаемо).

**Тестовый прогон (main-scene swap):** тесты живут в основном проекте
(`tests/runner.tscn` + `tests/runner.gd`), чтобы видеть весь game-code
через `res://`. Harness в режиме `--tests`:
1. backup `project.godot` → `project.godot.aybak` (при обнаружении
   оставшегося .bak от упавшего прогона — сначала восстановление);
2. записывает `run/main_scene="res://tests/runner.tscn"`;
3. stage + run + **restore project.godot в finally** (в т.ч. по crash).
В release-экспорте `tests/` исключается (export filter), поэтому
test-код не попадает в билд.

Runner:
- собирает тесты (классы, зарегистрированные в `TestRegistry`),
- запускает каждый (установка → тело → разбор),
- печатает `TESTS_DONE rc=<N>` (маркер harness'а), `quit(N)`.
- Ассерты: `expect_eq/expect_true/expect_near/expect_gt` с
  человекочитаемыми сообщениями (push_error + счётчик).

**Запуск:** `./tools/run_tests.sh [unit|integration|all]` (bash):
1. `node tools/godot-node/bootstrap.mjs` (idempotent);
2. `node tools/godot-node/harness.mjs --tests` (cwd = корень проекта);
3. exit code = число падений (CI-friendly).

## 3. Unit-тесты (по системам)

| Система | Тесты (минимум) | Фаза |
|---|---|---|
| Damage/health | урон/крит/блок; death; multiple hits; heal clamp; status | 4 |
| Inventory | add/stack/remove; capacity; equipment slots; drop-in-world flag | 6 |
| Loot | seeded table: распределение, rarity, dup-правила; determinism | 6 |
| Inheritance | resolve 1/3 (perma, unique); NPC-gate (NPC dead → недоступно);
  behavior-gate (RUNNER: fled>10); «gameplay, не +5%» (эффект =
  WEAPON_DESIGN-таблица); UX ≤10 s (timeout → random) | 6 |
| Save/Load | roundtrip; version migration v1→v2; corrupt JSON → recovery; crc mismatch → .bak; missing keys → defaults; atomic (kill mid-write — симуляция: tmp-файл остаётся, основной валиден) | 15 (первые в 8) |
| RNG streams | splitmix64 determinism; independence streams; seed range | 7 |
| Room gen | seed A/B/A' детерминизм; нет изолятов; нет «дверь без цели»; spawn-пробы; difficulty-монотонность; fallback после 8 fail | 7 |
| Run recorder | event capture по EventBus; лимит 4096 (sampling); size cap; run-summary компактность | 8 |
| Run events | сериализация/десериализация (roundtrip 14-байтовая запись,
  int32-t); quantization bounds; sampling при >4096 | 8 |
| World state | apply_change validation; idempotency; unknown-id → skip+log;
  dropped_items cap; **notes roundtrip** (write → RUN N+1 → read,
  4 stands, 5-line pool); **memory_stats** (агрегация, dominant_style);
  «Что изменилось» (≤5 строк, 1 строка = 1 flag) | 10 |
| Ghost replay | timeline build (keyframes); room remap (совпадает/отсутствует); interpolation monotonic speed; navmesh clamp | 9 |
| FSM (враг) | transition table (allowed/denied); state timing; interrupt rules;
  per-archetype invariants (5: Hollow/Remnant/Watcher/Mimic/Forgotten) | 5 |
| Echo builder | Remnant: из RunEvent/RunSummary (path/weapon/style, best run);
  Mimic: dominant_style resolve (punish-паттерн); Watcher: anchor set
  (≤2/run) → Memory Echo (следующий забег); Forgotten: whisper pool
  (история игрока: notes/replicas); edge: пустая история → default | 5/9/10 |
| Mystery triggers | condition evaluation (flag-gating: stage N+1 только после flag N;
  run_count, choice); stage progression; **ambiguity-тест** (ни одна
  реплика/событие не «отвечает» «запись или живой» — проверка по
  DIALOGUE_GUIDELINES §7) | 11 |
| UI state machine | screen stack push/pop; input-routing per screen; pause/resume | 13 (часть с 1-й UI-фазы) |
| Quality presets | apply preset → значения сессов (shadow/fog/particles) | 16 |
| Scripted anchors | A1–A17 (FIRST_30_MINUTES): триггеры срабатывают (window,
  не таймер); pillar/blade/Hollow/camp+note/figure/combat/sealed door;
  first death window ~20 мин (A19); RUN 02: door-open + #1 (B4) | 8/11 |
| Boss (The First) | phase transitions (Wandering/Workshop); паттерн-память
  (threshold 3, parry, reset 3); core-hit window (2/4 s, FIRST BLADE);
  take/leave choice; death → K7 transformation (flags) | 12 |

## 4. Integration-тесты (end-to-end в риге)

1. **Death → save → reload** (Phase 15): старт забега (seed) → действие →
   смерть → save → kill process → reload → world-state и run-history
   идентичны (по данным, не по памяти).
2. **Run recording → ghost** (Phase 9): забег N с событиями → смерть →
   забег N+1 (другой seed) → ghost существует, таймлайн = события N,
   позиция в хабе валидна (в пределах комнаты), actions воспроизведены
   (счётчики).
3. **Room transitions** (Phase 7): забег по графу: каждая переходимая
   дверь — переход; нет тупиков (кроме задуманных); boss-арена достигима.
4. **Enemy spawning** (Phase 5): spawn-таблица: состав по difficulty,
   нет спавна в стене (probe), нет >N врагов в локации, staggered
   update-слоты распределены.
5. **Item pickup** (Phase 6): pickup → inventory; drop-in-world → объект в
   комнате; следующий забег: объект на месте (world memory).
6. **Dialogue** (Phase 11): условия world-state меняют ветку; choice →
   world_state_changed.
7. **Boss encounter** (Phase 12): спавн по condition; фазы; death sequence
   → event_completed → world state.
8. **Save corruption matrix** (Phase 15): (a) битый JSON, (b) битый CRC,
   (c) старый version (v1 test fixture), (d) отсутствующие поля, (e)
   foreign world_id, (f) пустой файл → поведение: recovery/backup/fresh +
   UI-состояние; НИКАКОГО crash.
9. **Edge: смерть в transition / в dialogue** (Phase 17): scripted kill
   (DebugTools F5) в моменте → состояние консистентно (save не ломается,
   ghost-лог завершён, respawn корректен).

## 5. Ручной QA (чек-листы; ведутся в `tests/qa/`)

- `qa_phase2_movement.md` — feel: acceleration, dodge i-frames (timing
  window vs telegraph 0.5s), camera (lag ≤ 1 frame, no jitter), slope/
  step-up, no clipping.
- `qa_phase3_world.md` — визуал хаба, landmarks, туман/свет, performance
  (FPS на референс-ПК), load times.
- `qa_phase4_combat.md` — feel-матрица: hit-stop/shake/particles/audio
  по каждому типу удара; telegraph readability (новый игрок уклоняется
  ≥50%); damage numbers? (нет — по hit-flash).
- `qa_phase5_enemies.md` — per-archetype: поведение по spec, нет «зацикливаний»
  (15-мин сессия на каждого), AI-бюджет (overlay).
- `qa_phase8_run.md` — run-flow: start/death/summary; «что изменилось»
  читается ≤10 c; ghost presence.
- `qa_phase13_visual.md` — полный visual pass: consistency (5+ сцен
  подряд), «prototype-элементов» нет (чек по ASSET_STATUS.md), color
  grade, UI-отделка.
- `qa_phase14_audio.md` — buses, levels (LUFS-замер музыки -16/-14),
  footstep-surfaces, no clipping, no double-playback.
- `qa_phase17_full.md` — полный sweep (по списку из задачи: gameplay/world/
  UI/persistence/edge-cases — §6).

## 6. Edge-cases матрица (Phase 17, но отслеживается с фазы 8)

Смерть: в transition между комнатами / в dialogue / в boss-фазе / в
upgrade-выборе / сразу после respawn (double-death).
Save: закрытие игры во время записи (kill -9 на tmp-файле), full disk?
(симуляция через mock FS), параллельный запуск (lock-файл).
Inventory: полный инвентарь (pickup отказ + feedback), duplicate item,
drop в world во время смерти.
World: enemy spawn outside map (guard), ghost missing (нет логов →
graceful: no ghost + log), missing asset (отсутствующая сцена в .tres →
fallback + log), invalid world state (ручной битый save → recovery).
Ghost: ghost без лога; ghost с несовпадающим seed (remap-путь); ghost
в паузе; ghost + пауза + save.

## 7. Performance-протокол (Phase 16)

- Замер: F1-overlay + `--benchmark` (60-с сессия в хабе / в бою / в
  boss-арене; P50/P95 frame time, draw calls, AI budget, nodes, phys).
- Референс-железо: GTX 1060-класс (цель High 60fps); iGPU-класс (цель
  Low 30fps) — замеры у владельца (песочница без GPU).
- Report: `docs/PERF_REPORT.md` — до/после оптимизаций; каждый fix —
  с замером (не «должно стать быстрее»).

## 8. Статус-отчёты (по задаче)

Каждая фаза завершается блоком в `docs/ROADMAP.md` у фазы:
STATUS / IMPLEMENTED / TESTED / KNOWN ISSUES / NEXT.
