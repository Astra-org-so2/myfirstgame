# QA Phase 17 — Full sweep (TEST_PLAN §5/§6)

Дата: 2026-09-22. Состояние: unit 1019 / integration 597 — 0 failed.
Sandbox-строки закрыты тестами (edge_cases_test + суиты фаз);
device-строки — чек-лист владельца (ADR-021/035).

## A. §6 edge-cases матрица (полное покрытие)

Смерть:
- [x] **double-death** (удар + scripted hitstun после смерти) —
      второе death-событие не возникает; take_hit мёртвого
      игнорируется (fix P17: guard в player_controller);
      request_respawn на живом — no-op. (edge_cases: death rows)
- [x] **в transition между комнатами** — смерть сразу после
      _enter_level: экран смерти, respawn, мир цел (уровень
      построен, враги живы).
- [x] **в dialogue** — NPC-реплика активна (3-с окно), смерть —
      экран смерти поверх, выбор работает, окно реплики цело.
- [x] **в boss-фазе** — THE FIRST в бою (start_fight, state !=
      IDLE), смерть игрока — respawn; босс жив, его HP/state
      не сбросились.
- [x] **в upgrade-выборе / сразу после respawn** — выбор на
      экране смерти блокирует respawn до press; второй удар
      в момент respawns = НОВАЯ учтённая смерть (не flapping).

Save:
- [x] **kill -9 во время записи** (partial .tmp) — P15
      (save_manager_test: .tmp→rename, старый файл выигрывает).
- [x] **full disk / ENOSPC** — P15 (mock-файлик, статусы).
- [x] **параллельный запуск** — N/A по платформе (Android
      single-instance, lock-файл не нужен); in-process аналог
      (два save подряд): оба ok, .tmp-осколка нет, envelope
      валиден. (edge_cases: saves)
- [x] **БИТЫЙ save руками** — quarantine (.corrupt_*),
      recovered_bak/fresh, документированный исход, .tmp-осколка
      нет. (edge_cases: world)
- [x] **NEW (P17): int64 > 2^53 в world (derived seeds)** —
      до фикса: после нескольких ранов save «корrupt» (false
      crc_mismatch, float64-потеря точности). Фикс формата:
      «i64:<цифры>» marker + строгий is_valid_int guard.
      Unit: точное возвращение (3569610106698308992 и минус),
      граница 2^53-1 plain, CRC жив. (save_data_test, ADR-036)

Inventory:
- [x] **дубликат** — per-run cap (3) держится; over-cap add =
      -1 (no hidden overflow).
- [x] **полный инвентарь (12/12)** — оба add rejected.
- [x] **pickup отказ + feedback** — drop при полном баге →
      тост «No room in the bag.» (видимо игроку).
- [x] **drop-гейт** — при cap убийство не дропает loot.
- [x] **mёртвый игрок + drop рядом** — когерентное состояние,
      no crash.
- [x] **drop в world во время смерти** — N/A: player-side drop
      не существует (items found/used, never dropped); enemy
      loot покрывается выше.
- [x] **NEW (P17): CampDrop был непикабелен** — сигнал
      `interacted` обещан docstring-ом, но не объявлен (сцена
      connect-илась в никуда) + target = scene root без
      get_body_position. Фикс: сигнал объявлен/форвардится,
      target = player. (ADR-037)

World:
- [x] **enemy spawn outside the map** — validate() ловит
      non-finite position (data net) + director guard (runtime:
      log + skip, врага нет).
- [x] **missing asset** — texture bank = null: комнаты строятся
      flat-color (meshes present, no crash); mystery-lines =
      null: NPC говорит trust-линией (guard в _mystery_line).
- [x] **invalid world state (ручной битый save)** — см. Save.

Ghost:
- [x] **ghost без лога (null record)** — gracefully: no ghost,
      no crash.
- [x] **record < 2 events** — gracefully: no ghost.
- [x] **ghost с несовпадающим seed/layout** — old-layout rooms
      исчезли из new: remap lands finite (missing-room
      fallback); record всё равно replays. (unit: echo_test)
- [x] **ghost в паузе / ghost + пауза + save** — паузы в MVP
      нет (8-с run loop); mobile-аналог = app backgrounding
      (engine auto-pause): subtree DISABLED на 0.5 с реального
      времени — run clock не сдвинулся; после resume clock +5
      deciseconds ровно за 30 ticks (no jump, no lost time);
      враги/ghost когерентны. (edge_cases: background)

## B. Gameplay (sweep по суитам фаз)

- [x] Movement/dodge i-frames — player_scene (P2).
- [x] Combat: hit-stop/telegraph/parry — combat_scene (P4).
- [x] Enemies per-archetype + stagger — enemy_scene (P5), perf.
- [x] Progression: death-choice, inheritances, NPC trust —
      progression_scene (P6).
- [x] Run cycle: anchors, death screen, respawn, RUN 02 —
      run_cycle (P8).
- [x] Echo/ghost replay + budget — echo_scene (P9), P11.
- [x] Mystery lines + Child — mystery_scene (P11), cast_scene.
- [x] Boss: phases, parry, core, K6 — boss_scene (P12).
- [x] World memory (notes, mummy, remnant) — world_memory_scene.
- [x] Visual consistency (5+ сцен, color grade) — visual_scene
      (P13).
- [x] Audio: buses, stingers, variations, footstep — audio_scene
      (P14) + audio_manager unit.
- [x] Save/load — save_scene + 3 unit (P15).
- [x] Perf budgets §12 (sandbox-часть) — perf_scene (P16).

## C. UI (sandbox: code-built, headless-проверяемы)

- [x] Death screen: 1-of-3, levels, unblock respawn.
- [x] Toast: одна строка, replace, life.
- [x] Inventory panel: 12 slots, use, quick-use.
- [x] Touch layer: buttons → Input actions (touch_scene, P2).
- [ ] **Device**: aspect 16:9–20:9, safe area (notch),
      landscape-lock, touch-эргоника (P17 device-часть, ADR-021).

## D. Persistence (device)

- [ ] Save write на Android-файловике (≤50/80 ms), atomicity,
      ENOSPC в реальности.
- [ ] Kill процесса во время записи (adb).
- [ ] Save после int64-ранов: открыть файл, проверить, что
      seeds целы (формат «i64:», ADR-036).

## E. Mobile (device, ADR-021/035)

- [ ] Touch-эргоника + aspect/safe area (C).
- [ ] Battery/thermal-наблюдение (30-мин сессия, P16 чек-лист).
- [ ] Connectivity-пауза/резюме = app backgrounding: run clock
      не прыгает (sandbox-прокси пройден, device — подтвердить).
- [ ] Low-memory: OOM-поведение Godot-процесса (save-устойчивость
      — матрица A покрывает логику).

## F. Найденные в свипе дефекты (закрыты)

| # | Дефект | Фикс | Regression |
|---|---|---|---|
| 1 | int64 > 2^53 (seeds) ломали CRC после нескольких ранов — valid save quarantined | формат: «i64:» marker (save_data.gd) | save_data_test (exact round-trip) + edge_cases saves |
| 2 | CampDrop: сигнал interacted не объявлен + target = scene root — camp item непикабелен | сигнал + форвард, target = player (camp_drop.gd) | edge_cases inventory (pickup + «No room») |
| 3 | player.take_hit без _dead guard — scripted hitstun на трупе | guard (player_controller.gd) | edge_cases double-death |
| 4 | spawn position без bounds/finiteness — враг off-map | validate() + director guard (spawn_entry, enemy_director) | edge_cases world |
