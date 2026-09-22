# QA Phase 10 — World memory (WorldState persist + WorldDirector)

Цель: «10+ identifiable permanent changes working; «что
изменилось» noticed» (ROADMAP Phase 10 exit). Риг-покрытие:
**986 проверок** (unit 672 + integration 314; новые сьюты:
world_memory — note pool/stands/transform-данные, WorldState
notes + полный to_dict/load_dict (включая Vector3-флаги,
NPC-state, runs; защита от битого сейва), MemoryStats
round-trip, K7-бюджет-офсет; world_memory_scene — полный цикл:
RUN 1 запись записки (панель-пул, NOTE_WRITTEN, статистика) →
смерть → RUN 02 чтение (текст = сохранённая строка,
ECHO_NOTE_READ first time, мумии ещё нет) → смерть (флаг
boss_defeated вручную — триггер босса Phase 12) → RUN 03: мумия
в точке смерти RUN 02 (remap), записка в руках, examine →
corpse_seen + MUMMY_EXAMINED, K7: бюджет «тише», gate-fog
×0.375, gate glow + city silhouette, Mara — post-boss-реплика;
enemy_logic — #6: extra line = третья строка Remnant-секвенции).

Важно: (1) заметки — **пул из 5 строк, без free text** (ADR-018);
1 на stand, перезапись заменяет; readable **с RUN N+1**;
(2) мумия — из RUN 03, в `last_death_pos` пред. ранa; комната
смерти исчезла из новой раскладки → мумия skip (push_warning —
честное ограничение, мир держит то, что layout ещё имеет);
мумия следует run-space точке: видна в любой зоне, чей footprint
содержит точку (то же правило, что P9 death-маркеры);
(3) K7-триггер = флаг `boss_defeated`, **сам босс — Phase 12**
(тесты ставят флаг вручную);
(4) #6 = реплика («…I forgot that.»), а не хореография
«прерывает бой, подходит» — MVP-лимит (ADR-029);
(5) файл сейва (I/O/CRC/миграции) — Phase 15; это фаза —
чистый to_dict/load_dict-контракт, который SaveManager обёрнёт.

## A. Заметки (4 stand-а: camp / village / shrine / undercroft)

1. Подойти к stand-у: prompt «Write a note (E)».
2. E → панель: 5 строк пула (короткие «двери», без free text) +
   «— close —». Выбрать строку → «The note is saved.».
3. В том же ране stand- снова «Write a note» (перезапись до
   конца ранa; свежая записка НЕ readable в этом ране).
4. Следующий ран: prompt «Read your note (E)» → текст =
   сохранённая строка.
5. Статистика: notes_written +1 (trust Mara >2 — линия #2);
   NOTE_WRITTEN в run-записи (data = line index).

## B. Мумия (#5, RUN 03 D2)

1. RUN 01/02: мумии нет.
2. RUN 03: мумия в точке смерти RUN 02 (remap на текущую
   раскладку; лагерь стабилен — тождественно).
3. В руках — последняя записка игрока (если она была).
4. «Look (E)» → *«You died here. The world kept you.»* (+
   «"строка записки"») → flag `corpse_seen` → в «что
   изменилось»: «A mummy waits where you fell.» +
   MUMMY_EXAMINED в логе.

## C. K7 (после босса; триггер = `boss_defeated`, Phase 12)

1. Туман зон: ×0.375 (0.8 → 0.3), свет теплее (данные
   world_transform_post_boss.tres).
2. Gate: glow-маркер у двери + силуэт города за ней
   (5 тёмных коробов).
3. Эхо «тише» (ECHO §8): passive 0 / combat 1 / special 0.
4. Отпечатки passive-ghost'а остаются на уровне навсегда (reparent на
fade-finish — не умирают с ghost-ом).
5. NPC-спокойствие: post-boss-реплики (Mara: «The fire is
   brighter. I don't like it.», Orren/Nia/Cartographer —
   в npc_state.tres) вместо обычных.

## D. #6 (RUN 03, Ремнант читает записку)

1. RUN 03 + записка игрока существует: Remnant (Combat Echo)
   говорит канон-две реплики + **третья**: *«…I forgot that.»* —
   и уходит.
2. Без записки — только канон-две (beat не срабатывает).

## E. «Что изменилось» (metric, GDD §12 / risk R2)

- Корпус постоянных изменений фазы: (1) записки ×4 stand-а,
  (2) мумия, (3) corpse_seen-линия, (4) K7-fog, (5) K7-gate
  glow, (6) K7-city, (7) K7-echo «тише», (8) K7-отпечатки,
  (9) npc_calm-реплики, (10) NOTE_WRITTEN/MUMMY_EXAMINED в
  логах, (11) notes_written-статистика — **11 identifiable
  permanent changes** (exit: ≥10).
- Шиммер: 1-с emissive-пульс на первом подходе к stand-у/мумии
  в ран — визуальная подсказка «здесь что-то изменилось».
- Метрика (ручной playtest, владелец): заметил ли игрок ≥3
  изменения к концу RUN 03 без подсказок (GDD §12).

## F. Измерения (обязательно, «no fine without numbers»)

- WorldDirector.update: ≤5 shimmer-targets, distance-only
  (O(1)); замер — в rиге вместе с ghost-update (Phase 16 —
  на железе).
- Persist-размер: WorldState.to_dict() после 3 ранов с 4
  записками — в unit-тесте round-trip (JSON-стабильность),
  5 МБ-кэп applies к runs-секции (неchanged, ADR-027).
- UI: NotePanel — code-built Controls (3 Panel + 6 Label),
  1 панель в сцене (CanvasLayer 25), нет кэша-текстур.

## G. Честные лимиты фазы

1. K7 без босса: триггер — флаг; «после босса» мир игрок
   увидит только в Phase 12 (тесты эмулируют флагом).
2. #6 — реплика, не хореография (ADR-029).
3. Мумия в перекрывающихся footprint-ах (см. Важное 2).
4. Шиммер — emissive-пульс материала (без частиц/shader —
   Phase 13 visual pass).
