# QA Phase 11 — Mystery system (4 mystery × 4 stages)

Цель: «#1–#7 + K1–K7 достижимы (playtest-маршрут по
FIRST_3_RUNS), M2 stages 1–3 «собираются», ambiguity сохранена»
(ROADMAP Phase 11 exit). Риг-покрытие: **1094 проверки** (unit
717 + integration 377; новые сьюты: mystery — stage-таблица
(13), gate-правила (run_min/stage-порядок/flag_req/1-на-run),
WorldState mystery_progress (forward-only, persist/clamp),
dialogue-таблица (for_char-приоритет, repeat), child-spawns,
ambiguity-скан; mystery_scene — **полный MVP-маршрут** на живой
сцене: RUN 1–06, 61 проверка).

Важно: (1) MVP = стадии 1–3 (4-я стадия и twist-раскрытие —
post-MVP; GDD v2.0 §11: «twist только в seeds»); (2) M2.3
(the_first_seen) — данные + флаг, **реплика — Phase 12** (boss
THE FIRST); (3) правило «1 стадия на mystery в run» сильнее
графика: линия может быть сказана, а стадия — сдвинута на +1
run («мир не торопится»); (4) ни одна реплика не «отвечает»
(unit-скан: в репликах/стадиях нет answer-слов — финальная
амбивалентность кадра сохранена).

## A. RUN 1 (M1.1, M2.1, A16)

1. Первый удар — blade_found + **M1 стадия 1** (K1, «клинок в
   руке»).
2. Первый убитый Hollow — first_hollow_killed + **M2 стадия 1**
   (след, A5; метка visible в RUN 02+).
3. Врата (A16): gate_seal_seen + три «аннотации предыдущих
   версий» у подножия (M4-seed) + фигура (A10, первый
   non-camp-уровень).

## B. RUN 02 (M1.2, M3.1, M2.2)

1. **Passive Echo** (лагерь, путь RUN 1) → **M1 стадия 2**
   (passive_echo_seen).
2. **Первая встреча Ремнанта (#1)**: *«You're early.»* → *«You
   usually take longer.»* → dissolve-уход; **M3 стадия 1**
   (first_echo_seen) + Archivist whisper #2: *«He is kept. He is
   counted.»* (once).
3. Врата снова — **B2**: *«That wasn't there.»* → **M2 стадия 2**
   (run_02_door_open — мир «отвечает»).

## C. RUN 03 (M1.3, M3.2, M4.1)

1. Записка в лагере (stand, 5-line pool, без free text).
2. **Ремнант читает записку (#6)**: канон-секвенция +
   **третья строка** *«…I forgot that.»* → **M3 стадия 2**
   (echo_decision_seen). Встреча останавливает бой
   (CHASE→SPEAK, ADR-030: встреча — нарративный момент).
3. **K4 — книга Нии** (деревня, trust 1): «Look (E)» → страница
   на 6 c: *«Eli. Profession: —. Home: —. First seen: —.»* →
   **M1 стадия 3** (nia_name_seen). Страница = состояние мира
   (blank → имя → filled).
4. **Аннотации у врат** (3 строки, разные почерка): «not all of
   us are one» → **M4 стадия 1** (gate_notes_seen).

   Итог RUN 03: **M1:3 M2:2 M3:2 M4:1** (assert — «равномерно»,
   не скопом).

## D. RUN 04 (Child, линия без стадии)

1. Смерти ≥ 3 подсчитаны. Деревня: **Child** (силуэт ~0.8 m,
   «eyes too calm», инвульнерабелен).
2. Разговор: *«You died again. I watched. It was the third
   time.»* — **стадия НЕ сдвигается** (m4_child run_min = 5).

## E. RUN 05 (M1.4, M3.3, M4.2 + смещение M4.3)

1. **K5 — отражение в озере**: не отражение — Архивист (2 c,
   once) → **M3 стадия 3** (lake_reflection_seen).
2. **Child «217»**: *«You're number two-one-seven…»* + *«Some of
   you stayed…»* → **M4 стадия 2** (child_number_seen).
3. **Filled page** (книга): *«Eli. Profession: the one who
   forgets. Home: the forest. First seen: —.»* → **M1 стадия 4**
   (nia_page_filled).
4. **Картограф (город)**: trust-flow честный (2 разговора trust
   0 → scripted help → trust 1 → реплика): *«I drew the city
   yesterday. I haven't been there yet. ...yet.»* (veyra_city_told).
   **Но M4 стадия 3 НЕ ложится** — в этом run M4 уже двигалась
   (Child): 1-на-run. **Assert смещения** (M4 остаётся 2).

## F. RUN 06 (смещённая стадия ложится)

1. Картограф говорит снова (repeat: он одержим) → **M4 стадия 3**
   (veyra_b_seen).
2. **MVP-финал: M1 4/4, M2 2/3, M3 3/3, M4 3/3** (assert).

## G. Archivist whispers (5, seedy)

| # | Момент | Реплика | Статус |
|---|--------|---------|--------|
| 1 | Камень-святилище (A15) | (P8) | wired P8 |
| 2 | Первое эхо (RUN 02) | *«He is kept. He is counted.»* | integration |
| 3 | Озеро (K5, RUN 05) | (LINE_ARCHIVIST_LAKE) | integration |
| 4 | Врата post-boss | (LINE_ARCHIVIST_GATE) | флаг + триггер — Phase 12 (паттерн K7, ADR-029) |
| 5 | Убитый NPC (bus npc_died) | *«Remembered. Kept. Always.»* | wired (main), unit-данные |

## Known issues / MVP-лимиты

1. M2.3 — реплика после босса (Phase 12); данные+флаг готовы
   (the_first_seen).
2. Whisper #4 — триггер = boss_defeated (фазы 12); тесты
   эмулируют флагом (паттерн K7, ADR-029).
3. Child: «attempt_hit → мягкий пенальти» = флаг (child_hit) +
   toast; «инвульнерабельность» — нет damage-пути (часть
   мистики, GDD §11); хореография — Phase 13.
4. #6 = реплика + встреча; «прерывает бой, идёт читать» =
   CHASE→SPEAK при player_seen (ADR-030); полная хореография —
   Phase 13.
5. K5 reflection = белый силуэт 2 c (visual pass Phase 13).
6. П9-дефект (обнаружен P11, зафиксирован ADR-030 (6)): #6
   недостижим — remnant_met гасил встречу, а SPEAK был только из
   IDLE (записка пишется после спавна). Фикс + регресс-тест в
   mystery_scene (RUN 03).
