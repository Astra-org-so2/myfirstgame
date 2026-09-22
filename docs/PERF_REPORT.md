# AFTER YOU — PERF_REPORT (Phase 16)

Дата: 2026-09-22. Протокол — TEST_PLAN §7, бюджеты — TECHNICAL_DESIGN
§12. Честное деление: **песочница (wasm-риг)** меряет структуру и
CPU-логику; **GPU-метрики (draw calls, tex memory, RAM, frame
wall-time, thermal)** — только на устройстве (владелец, ADR-021).

## 1. Замеры в песочнице (wasm, CPU-логика + структура)

Сценарии из perf_scene_test (integration, каждый прогон = замер):

| Сценарий | Nodes (≤2000) | Bodies (≤40) | FX (≤200) | Local lights (≤6) | Frame CPU p50/p95 (ms) |
|---|---|---|---|---|---|
| Camp (idle-хаб) | 281 | 6 | 8 | 1 (medium: ≤4) | 0.06 / 0.16 |
| The Mine + spawn table (2 врага живы) | 340 | 6 | 8 | 4 (medium: ≤4) | 0.04 / 0.07 |
| Boss-арена (Undercroft, THE FIRST) | 334 | 6 | 8 | 2 | 0.06 / 0.09 (с боссом в цепи) |

- **Всё в §12-бюджете с большим запасом** (nodes < 17% бюджета).
- Frame CPU = CPU-логика кадра (player + director + boss) в wasm —
  wasm-центр slower, чем Snapdragon 7; p95 < 0.1 ms = игровой CPU
  не bottleneck, на устройстве потолок = GPU-рендер.
- **Save write: 1 ms** (wasm; бюджет ≤50 ms) — атомарная запись
  .tmp->rename + CRC32 + ~100 KB JSON.
- Light-бюджет тира работает: в level максимум = `tier.light_budget`
  (medium=4, проверено: mine=4).

### Аудит-фиксы P16 (до/после)

| # | Проблема | Фикс | Результат |
|---|---|---|---|
| 1 | `high.tres`: texture_max_size 1024 (§12: 2048) | data-фикс | §12-таблица согласована (quality_preset_test) |
| 2 | Ultra-пресет отсутствует (§12: High + soft + VFX 125%) | `ultra.tres` + поле `soft_shadows` + apply в QualityManager | 4 тира, validate() чистые, F8-цикл low→med→high→ultra |
| 3 | Замеров не существовало (F1-overlay, benchmark-файл) | DebugOverlay (F1) + PerfBenchmark (F6 → user://perf_<area>.txt) | цифры вместо «на глаз»; файл под adb pull |

GPU-составляющие (draw calls, texmem) в песочнице не меряются —
ниже, в чек-листе владельца.

## 2. Device-чек-лист (владелец, ADR-021)

Референс: mid-range Android (SD 7-класс, 8 GB, 1080×2400) = High
60 fps; low-end (SD 6xx, 4 GB, 720×1600) = Low 30 fps floor.

### Протокол (по TEST_PLAN §7)
1. `adb install` debug-экспорт (export/ — Android debug).
2. F1 — HUD (fps, P50/P95, nodes, bodies, fx, lights, draw_calls,
   ram — на device строки draw_calls/ram появляются).
3. F6 — benchmark 10 c → `user://perf_<area>.txt` → `adb pull`.
4. Сценарии (30–60 c каждый): хаб (idle), бой (spawn table),
   boss-арена; затем **thermal-сессия 30 мин** (беспрерывный бой
   + движение, fps-кривая для drop-анализа).

### Бюджеты (§12, на device)
- [ ] **High, mid-range:** frame ≤16.6 ms (60 fps), P95 ≤22 ms;
      draw calls ≤150 (env ≤90 / chars ≤30 / vfx ≤30);
      AI ≤4 ms/frame; physics ≤40; particles ≤200; nodes ≤2000;
      tex mem ≤256 MB; RAM ≤1.2 GB.
- [ ] **Low, low-end:** frame ≤33.3 ms (30 fps), P95 ≤45 ms;
      draw calls ≤120; AI ≤5 ms; tex mem ≤192 MB; RAM ≤1.0 GB.
- [ ] **Thermal 30 мин:** без drop ниже 60 fps (High) / 55 (Med) /
      30 (Low) — fps-кривая из F1-HUD/benchmark-файлов.
- [ ] **Cold start:** ≤8 s (High) / ≤10 s (Low) до playable.
- [ ] **Death→respawn:** ≤2 s hard (RunManager) / ≤10 s UX.
- [ ] **Save write:** ≤50/80 ms (F1-замер или logcat).
- [ ] **Render scale 0.75** — при просадках (Low/Med performance
      mode: уже в low.tres).
- [ ] **Preset-рекомендация по GPU** (GPU-name → preset) —
      post-MVP (§12), на MVP: выбор игрока + F8.

### Известные mobile-факторы (архитектурно закрыты)
- Lights: ≤3/4/6/6 по тирам (жизненный цикл узлов, P13) —
  самая дорогая статья Forward+ под контролем.
- Текстуры: 8 × 64 px (15 КБ) + 12 WAV 11025 Hz (4.8 МБ) —
  tex mem/RAM на device в разы ниже бюджета.
- VFX: mesh-пул 8 слотов (no GPU particles) — draw calls VFX
  ≤ 8 активных.
- AI: staggered (phase-shift по слотам, EnemyDirector) —
  пиковых кадров нет; p95 wasm 0.09 ms (с боссом).
- Пост: только MSAA ≤2x (High/Ultra) + filmic — no heavy post.

## 3. Что песочница НЕ валидирует (честно)

- GPU: draw calls, texture memory, RAM процесса, frame wall-time,
  thermal, батарею — только device (риг: Dummy physics, no GPU
  bridge; OS.get_used_memory_bytes/get_render_info в риге пусты).
- Физический файловик Android (атомарность rename, ENOSPC) — P15
  device-часть.
- wasm-CPU ≠ Snapdragon-7-CPU: wasm-замеры CPU — относительные
  (доказывают, что логика не bottleneck), абсолютные ms — device.

## 4. Инструменты (debug builds)

- **F1** — DebugOverlay: fps, P50/P95 (rolling), nodes/bodies/fx/
  lights (+ draw_calls/ram на device), budget-строки.
- **F6** — PerfBenchmark: 10 c замера текущей области →
  `user://perf_<area>.txt` (P50/P95/peak frame, counts, budgets).
- **F8** — Low → Medium → High → Ultra → Low (toast).
- Release: все debug-инструменты off (OS.is_debug_build guard).
