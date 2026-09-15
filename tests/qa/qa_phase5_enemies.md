# QA Phase 5 — Enemy system (5 архетипов)

Цель: «5 врагов — 5 РАЗНЫХ на поведение» (exit-criterion), telegraphs
читаемы (0.4–0.8 s), AI не съедает бюджет. Риг-покрытие: 193 новые
проверки (unit: enemy_data 46 — все 11 вариантов валидны +
telegraph-пол 0.3 s; enemy_logic 65 — FSM-переходы, инварианты
архетипов, Remnant first-encounter, Watcher observe/anchor ≤2/run,
Mimic mirror+punish, Forgotten whisper/dissolve, retreat/leash,
float-границы EPS; nav_memory 23 — nav-граф лагеря 17 узлов,
A*-path, memory-path ring; memory_stats 28 — dominance-решение
4/10→NONE, 6/4→MELEE, 5/5→MELEE, 4/4/4→NONE, пороги + tracker) +
integration enemy_scene 31 (spawn-таблица 5/5 архетипов,
staggered slots ≤2 тика/кадр и ~10 Hz на врага, Hollow chase+hit
15 dmg, dodge i-frames блокуют атаки врага (тот же
DamageResolver-путь), Watcher unkillable (hp 999, hit blocked),
eye-line 2 s → memory anchor (позиция игрока), Remnant
first-encounter: реплика → уход → remnant_met, Forgotten wander,
guard-вариант стоит (wander 0), kill → EventBus.enemy_killed →
MemoryStats.kills → despawn). Риг без рендера/звука/физики
(ADR-002/022/023): визуал врагов, feel телеграфов, 60 fps с AI —
только редактор/устройство.

Важно: демо-лагерь спавнит 5 врагов (camp_spawn_table.tres:
hollow_base (6,-6), remnant_mirror (-6,-4), watcher_base (8,6),
mimic_combo (-8,2), forgotten_wanderer (0,-9)). Визуал — примитивы
(ADR-024): капсула + цвет по EnemyData + Label3D-реплика; это
prototype-визуал, финальный облик — Phase 13.

## A. ПК-редактор (Godot 4.7.2, F5)

- [ ] Запуск без ошибок в Output (вкл. отсутствие скрипт-ошибок;
      враги появляются в лагере: 5 капсул разных цветов/размеров).
- [ ] **Hollow** (серая, средняя): подойди в ~8 m — замечает,
      поворачивается, идёт за игроком. Удар: windup ~0.5 s
      (читаемая задержка — телеграф), урон 15, у игрока hitstun.
      Убегает из-под удара → враг не «зацикливается»: после ~5 s
      без цели возвращается к месту спавна.
- [ ] **Remnant** (тёмная, у западной стены): первая встреча —
      останавливается, произносит реплику (Label3D), через ~1 s
      уходит (despawn), больше в этом run не появляется
      (remnant_met). Повторный run (respawn/перезапуск) — встречает
      снова (флаг run-scoped).
- [ ] **Watcher** (высокая, восток): уязвимости нет — бей сколько
      хочешь, hp 999, hits блокируются. Стой и смотри на него ~2 s
      (взгляд = facing в камеру-районе): «наблюдение» → после
      реплики запоминает позицию (memory anchor; отладка:
      director.anchors.size() = 1). Приближаешься — следует
      медленно; отойдешь за 12 m — исчезает и телепортируется
      ближе (vanish 1.0 s).
- [ ] **Mimic** (у северной стены): на спавне произносит реплику
      «I know how you do it.» (~3 s). Атакует — паттерн зависит от
      dominant_style игрока (в demo — по умолчанию melee-зеркало:
      3 удара в окно 0.5 s).
- [ ] **Forgotten** (большая, юг): гуляет по южной части лагеря
      (wander 15 m), не замечает игрока (sight 5 m). Боевой: если
      всё-таки добьёшься (999 dmg — debugger) — dissolve 3.0 s
      (медленное исчезновение, не мгновенный despawn).
- [ ] Атака врага по игроку БЛОКИРУЕТСЯ dodge i-frames [0.05, 0.25]:
      урон в этом окне не снимает hp.
- [ ] Смерть врага (debugger: resolver.resolve по combat-мишени
      врага, 999 dmg): death-фаза → despawn, EventBus.enemy_killed
      (слушатель в debugger), MemoryStats.kills +1 (debugger:
      main.tracker.stats.kills).
- [ ] Telegraf-чек: каждый windup врага — НЕ менее 0.4 s между
      «начал замах» и «урон» (если feel-команда скажет — до 0.8 s;
      пол 0.3 s гарантируется данными — enemy_data-тесты).
- [ ] Regression Phase 2/3/4: движение/камера/тач, лагерь-интеракты,
      свой combo/riposte/i-frames — не сломаны.

## B. Android-устройство (debug-экспорт)

- [ ] 5 врагов активны одновременно: 60 fps стабильно (без
      просадок на подходах; reference: Adreno, ADR-021).
- [ ] Thermal: 10-мин сессия в лагере с врагами — температура не
      уходит в красную зону (AI + навигация — новый расход;
      ADR-021 §thermal).
- [ ] Бой с Hollow на таче: windup читается без задержек; dodge в
      окне i-frames блокирует (SPC/DODGE-кнопки).
- [ ] Никаких фризов на спавне/деспауне (Remnant-уход, Watcher-
      vanish, dissolve Forgotten).
- [ ] Звук: вражеские hits по игроку — тот же hurt-cue (Phase 4),
      новых вражеских SFX в Phase 5 нет (сознательно).

## C. AI-бюджет (измерение — ОБЯЗАТЕЛЬНО, «no fine without
measuring»)

- [ ] Device: DevTools/Profiler → GDScript-время кадра в лагере
      со всеми 5 врагами: AI-часть (EnemyDirector.update) ≤4 ms
      (бюджет TECHNICAL_DESIGN). Способ: временный
      OS.get_ticks_usec() до/после director.update в main_scene
      (удалить после замера) ИЛИ profiler-frame capture.
- [ ] Кросс-чек с телеметрией: ticks_run (controller) — 5 врагов ×
      ~10 Hz = ~50 логик-тиков/с, разнесённых по кадрам
      (integration гарантирует ≤2/кадр; на 60 fps это ≤2/30 кадров
      с тиками врагов).
- [ ] Зафиксировать цифры в PERF_REPORT (Phase 16) с железом/
      драйвером. Если >4 ms — не тюнинговать feel: снизить
      update_hz в EnemyData (данные!), проверить nav-граф (17
      узлов — A* дешёв), и только потом код.
